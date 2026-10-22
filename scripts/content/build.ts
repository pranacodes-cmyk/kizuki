/**
 * Step 3 of the content pipeline (run with `bun scripts/content/build.ts`).
 *
 * Reads the AI clip windows (scripts/content/raw), the per-clip AI word explanations
 * (scripts/content/explain), YouTube oEmbed metadata and the open JMdict + JLPT lists, then
 * writes the shared data files used by BOTH clients:
 *   public/data/content.json      clips + tokenised interactive transcripts
 *   public/data/dict.json         dictionary entries for every word that appears
 *   public/data/explain/<id>.json AI "meaning in this sentence" notes per clip
 * and mirrors them into mobile/assets/data/ (Flutter). Never edit those outputs by hand.
 */
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import kuromoji from "kuromoji";
import * as wanakana from "wanakana";

const ROOT = path.resolve(import.meta.dir, "../..");
const HERE = import.meta.dir;
const RAW = path.join(HERE, "raw");
const EXPLAIN = path.join(HERE, "explain");
const PROOF = path.join(HERE, "proof");
const DICT_SRC = process.env.JMDICT ?? path.join(HERE, ".dict/jmdict-examples-eng-3.6.2.json"); // scripts/content/fetch_dict.sh
const JLPT_DIR = process.env.JLPT_DIR ?? path.join(HERE, ".dict");
const OUT_DIRS = [path.join(ROOT, "public/data"), path.join(ROOT, "mobile/assets/data")];
const BLOCKLIST = new Set(
  fs.existsSync(path.join(HERE, "blocklist.txt"))
    ? fs.readFileSync(path.join(HERE, "blocklist.txt"), "utf8").split(/\s+/).filter(Boolean)
    : [],
);

type RawLine = { start: number; end: number; ja: string; en: string; speaker?: string };
type RawClip = {
  start: number; end: number; title: string; level: string; topics: string[];
  grammar: string[]; quality: number; lines: RawLine[];
};
type RawVideo = { videoId: string; speech?: string; clips?: RawClip[]; pickTopics: string[] };

export type Word = {
  s: string; // surface as spoken
  r: string; // reading (hiragana), "" when same as surface or punctuation
  ro: string; // romaji
  b: string; // dictionary form
  p: string; // simple part of speech
  d: string | null; // dictionary id
  f?: [string, string | null][]; // furigana segments [text, ruby]
  t0: number; t1: number; // seconds (absolute video time)
};

const LEVELS = ["N5", "N4", "N3", "N2", "N1"];
const TOPICS = new Set(["travel", "anime", "work", "fun", "friends", "family", "romance", "culture", "food", "daily", "animals", "school", "comedy", "sports", "music"]);
const JP = /[\u3040-\u30ff\u4e00-\u9faf\u3400-\u4dbf々〆ヵヶ]/;
const KANJI = /[\u4e00-\u9faf\u3400-\u4dbf々〆ヵヶ]/;
const KATA = /[\u30a1-\u30fa]/;
const round = (n: number) => Math.round(n * 100) / 100;

// ---------- tokeniser ----------
const tokenizer: kuromoji.Tokenizer<kuromoji.IpadicFeatures> = await new Promise((res, rej) =>
  kuromoji.builder({ dicPath: path.join(ROOT, "node_modules/kuromoji/dict") }).build((e, t) => (e ? rej(e) : res(t))),
);

const hira = (s: string) => wanakana.toHiragana(s, { passRomaji: true });
const kata2hira = (s: string) => s.replace(/[\u30a1-\u30f6]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0x60));

function simplePos(t: kuromoji.IpadicFeatures): string {
  switch (t.pos) {
    case "名詞": return t.pos_detail_1 === "代名詞" ? "pronoun" : "noun";
    case "動詞": return "verb";
    case "形容詞": return "adjective";
    case "副詞": return "adverb";
    case "助詞": return "particle";
    case "助動詞": return "auxiliary";
    case "感動詞": return "interjection";
    case "連体詞": return "adnominal";
    case "接続詞": return "conjunction";
    case "接頭詞": return "prefix";
    case "記号": return "punct";
    default: return "other";
  }
}

const isPunct = (t: kuromoji.IpadicFeatures) => t.pos === "記号" || !JP.test(t.surface_form) && !/[A-Za-z0-9０-９]/.test(t.surface_form);

const LONG_VOWEL = /^[ーｰ]+$/;
const DIGITS = /^[0-9０-９]+$/;
const NUM_SEP = /^[.,．，]$/;
const BIG_UNITS = ["万", "億", "兆"];
const isNumberGroup = (parts: kuromoji.IpadicFeatures[]) =>
  parts.some((p) => DIGITS.test(p.surface_form)) && parts.every((p) => DIGITS.test(p.surface_form) || NUM_SEP.test(p.surface_form) || BIG_UNITS.includes(p.surface_form));

const KATA_ONLY = /^[ァ-ヺー]+$/;
const surfaceOf = (parts: kuromoji.IpadicFeatures[]) => parts.map((p) => p.surface_form).join("");
/** A katakana loanword JMdict knows as a whole (byKana is filled before the first group() call). */
const kataWord = (s: string) => s.length >= 3 && KATA_ONLY.test(s) && byKana.has(s);

/**
 * Merge kuromoji morphemes into learner-sized words (歩い+てる → 歩いてる, お+座り → お座り).
 * Also: a stretched vowel joins its word (分かる+ー → 分かるー, く+ー+ん → くーん) and numbers stay
 * whole (３+０+０+０+年 → ３０００年, 1000+万+円 → 1000万円, 1+.+5+倍 → 1.5倍).
 */
function group(tokens: kuromoji.IpadicFeatures[]) {
  const out: { parts: kuromoji.IpadicFeatures[]; head: kuromoji.IpadicFeatures }[] = [];
  tokens.forEach((t, i) => {
    const prev = out[out.length - 1];
    const prevLast = prev?.parts[prev.parts.length - 1];
    const prevIsPred = prev && (prev.head.pos === "動詞" || prev.head.pos === "形容詞");
    const next = tokens[i + 1];
    const s = t.surface_form;
    let merge = false;
    if (prev && !prev.parts.every(isPunct) && LONG_VOWEL.test(s)) merge = true;
    // A katakana word kuromoji split in pieces joins back up when the whole is a dictionary
    // word (ガン+ダム → ガンダム, not "cancer" + "dam"; イヤ+ホン → イヤホン; サブ+ウェイ → サブウェイ).
    else if (prev && KATA_ONLY.test(s) && prev.parts.every((p) => KATA_ONLY.test(p.surface_form)) && (kataWord(surfaceOf(prev.parts) + s) || (!!next && KATA_ONLY.test(next.surface_form) && kataWord(surfaceOf(prev.parts) + s + next.surface_form)))) merge = true;
    else if (prev && prevLast && LONG_VOWEL.test(prevLast.surface_form) && /^[ぁ-ん]$/.test(s) && (t.pos !== "助詞" || s === "ん")) merge = true;
    else if (prev && isNumberGroup(prev.parts) && (DIGITS.test(s) || BIG_UNITS.includes(s) || (NUM_SEP.test(s) && !!next && DIGITS.test(next.surface_form)))) merge = true;
    else if (prev && !isPunct(t)) {
      if (prevLast!.pos === "接頭詞" && (t.pos === "名詞" || t.pos === "動詞" || t.pos === "形容詞")) merge = true;
      else if (prevIsPred && (t.pos === "助動詞" || t.pos_detail_1 === "非自立" && (t.pos === "動詞" || t.pos === "形容詞") || t.pos_detail_1 === "接尾")) merge = true;
      else if (prevIsPred && t.pos === "助詞" && t.pos_detail_1 === "接続助詞" && ["て", "で", "ちゃ", "じゃ", "ば"].includes(s)) merge = true;
      else if (prev.head.pos === "名詞" && prev.head.pos_detail_1 === "サ変接続" && t.pos === "動詞" && t.basic_form === "する") merge = true;
      else if (prev.head.pos === "名詞" && t.pos === "名詞" && t.pos_detail_1 === "接尾" && !["さん", "ちゃん", "くん", "君", "たち", "達"].includes(s)) merge = true;
    }
    if (merge) {
      prev!.parts.push(t);
      // a prefix group takes the following content word as its head
      if (prev!.head.pos === "接頭詞") prev!.head = t;
      // サ変 noun + する behaves like a verb for further merging
      if (t.pos === "動詞" && t.basic_form === "する" && prev!.head.pos === "名詞") prev!.head = { ...prev!.head, pos: "動詞" } as kuromoji.IpadicFeatures;
    } else out.push({ parts: [t], head: t });
  });
  return out;
}

// ---------- number readings (３０００年 → さんぜんねん) ----------
const ONES = ["", "いち", "に", "さん", "よん", "ご", "ろく", "なな", "はち", "きゅう"];
function under10k(n: number): string {
  const th = Math.floor(n / 1000), h = Math.floor(n / 100) % 10, te = Math.floor(n / 10) % 10, o = n % 10;
  let s = "";
  if (th) s += ({ 1: "せん", 3: "さんぜん", 8: "はっせん" } as Record<number, string>)[th] ?? ONES[th] + "せん";
  if (h) s += ({ 1: "ひゃく", 3: "さんびゃく", 6: "ろっぴゃく", 8: "はっぴゃく" } as Record<number, string>)[h] ?? ONES[h] + "ひゃく";
  if (te) s += (te === 1 ? "" : ONES[te]) + "じゅう";
  if (o) s += ONES[o];
  return s;
}
export function numberReading(n: number): string {
  if (n === 0) return "ぜろ";
  let s = "", rest = n;
  for (const [unit, value] of [["ちょう", 1e12], ["おく", 1e8], ["まん", 1e4]] as const) {
    const q = Math.floor(rest / value);
    if (!q) continue;
    let r = q === 1 ? "いち" : under10k(q);
    if (q >= 1000 && q < 2000) r = "いっ" + r; // 1000万 → いっせんまん
    if (unit === "ちょう") r = r.replace(/いち$/, "いっ").replace(/はち$/, "はっ").replace(/じゅう$/, "じゅっ");
    s += r + unit;
    rest -= q * value;
  }
  return s + (rest ? under10k(rest) : "");
}
// Counter sound changes (１分 → いっぷん, ３本 → さんぼん, ２人 → ふたり, ４年 → よねん).
const GEMINATE = new Set(["回", "個", "歳", "才", "冊", "軒", "箇所", "か所", "ヶ所", "カ所", "週間", "階", "曲", "件", "点", "頭", "足", "杯", "匹", "分", "本", "kg", "キロ", "センチ", "ページ", "カップ"]);
const H_TO_P: Record<string, [string, string, string]> = { 分: ["ふん", "ぷん", "ぷん"], 本: ["ほん", "ぽん", "ぼん"], 杯: ["はい", "ぱい", "ばい"], 匹: ["ひき", "ぴき", "びき"] };
const TSU = ["", "ひとつ", "ふたつ", "みっつ", "よっつ", "いつつ", "むっつ", "ななつ", "やっつ", "ここのつ", "とお"];
const DAYS: Record<number, string> = { 2: "ふつか", 3: "みっか", 4: "よっか", 5: "いつか", 6: "むいか", 7: "なのか", 8: "ようか", 9: "ここのか", 10: "とおか", 14: "じゅうよっか", 20: "はつか", 24: "にじゅうよっか" };
function withCounter(n: number, counter: string, counterReading: string): string | null {
  if (!Number.isInteger(n) || n <= 0) return null;
  if (counter === "つ" && n <= 10) return TSU[n];
  if (counter === "人") return n === 1 ? "ひとり" : n === 2 ? "ふたり" : null;
  if (counter === "日" && DAYS[n]) return DAYS[n];
  if (counter === "月" && n <= 12 && [4, 7, 9].includes(n)) return { 4: "しがつ", 7: "しちがつ", 9: "くがつ" }[n]!;
  if (counter === "時" && n % 10 && [4, 7, 9].includes(n % 10)) return numberReading(n - (n % 10)) + { 4: "よじ", 7: "しちじ", 9: "くじ" }[n % 10]!;
  const last = n % 10;
  const head = n - last > 0 ? numberReading(n - last) : "";
  if (last === 4 && ["人", "年", "時間", "円"].includes(counter)) return head + "よ" + counterReading;
  if (!GEMINATE.has(counter)) return null;
  const hp = H_TO_P[counter];
  if (last === 0) {
    if (!head.endsWith("じゅう")) return null;
    return head.slice(0, -"じゅう".length) + "じゅっ" + (hp ? hp[1] : counterReading);
  }
  const lastReading = numberReading(last);
  if (hp) {
    if (last === 3) return head + "さん" + hp[2];
    if (last === 4 && counter === "分") return head + "よん" + hp[1];
    if ([1, 6, 8].includes(last)) return head + { 1: "いっ", 6: "ろっ", 8: "はっ" }[last]! + hp[1];
    return head + lastReading + hp[0];
  }
  if ([1, 6, 8].includes(last)) return head + { 1: "いっ", 6: "ろっ", 8: "はっ" }[last]! + counterReading;
  if (last === 3 && ["軒", "階", "足"].includes(counter)) return head + "さん" + counterReading.replace(/^け/, "げ").replace(/^か/, "が").replace(/^そ/, "ぞ");
  return null;
}
const halfDigits = (x: string) => x.replace(/[０-９]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0xfee0));
/** Hiragana reading of a number group plus any counter/suffix after it. */
function numberGroupReading(parts: kuromoji.IpadicFeatures[]): string {
  let out = "", buf = "", total = 0, open = false;
  const flush = () => {
    if (!open) return;
    const [int, dec] = halfDigits(buf).replace(/[,，]/g, "").replace(/[．]/g, ".").split(".");
    const whole = total + (int ? Number(int) : 0);
    out += numberReading(whole) + (dec ? "てん" + [...dec].map((d) => (d === "0" ? "ぜろ" : ONES[Number(d)])).join("") : "");
    buf = ""; total = 0; open = false;
  };
  for (const p of parts) {
    const s = p.surface_form;
    const r = kata2hira(p.reading && p.reading !== "*" ? p.reading : s);
    if (DIGITS.test(s) || NUM_SEP.test(s)) { buf += s; open = true; }
    else if (open && BIG_UNITS.includes(s)) {
      total += Number(halfDigits(buf).replace(/[,，]/g, "") || "1") * ({ 万: 1e4, 億: 1e8, 兆: 1e12 } as Record<string, number>)[s];
      buf = "";
    } else {
      const n = total + Number(halfDigits(buf).replace(/[,，]/g, "") || "0");
      const special = open && !buf.includes(".") && !buf.includes("．") ? withCounter(n, s, r) : null;
      if (special) { out += special; buf = ""; total = 0; open = false; }
      else { flush(); out += r; }
    }
  }
  flush();
  return out;
}

/** Split a word into [text, ruby] segments so ruby sits only above kanji. */
export function furigana(surface: string, reading: string): [string, string | null][] | undefined {
  const needsRuby = (ch: string) => KANJI.test(ch) || /[0-9０-９]/.test(ch);
  if (![...surface].some(needsRuby) || !reading) return undefined;
  const segs: { text: string; kanji: boolean }[] = [];
  for (const ch of surface) {
    const k = needsRuby(ch);
    const last = segs[segs.length - 1];
    if (last && last.kanji === k) last.text += ch;
    else segs.push({ text: ch, kanji: k });
  }
  const pattern = segs.map((s) => (s.kanji ? "(.+?)" : `(${escapeRe(kata2hira(s.text))})`)).join("");
  const m = new RegExp(`^${pattern}$`).exec(kata2hira(reading));
  if (!m) return [[surface, reading]];
  return segs.map((s, i) => [s.text, s.kanji ? m[i + 1] : null]);
}
const escapeRe = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

function mora(reading: string) {
  return kata2hira(reading).replace(/[ゃゅょぁぃぅぇぉゎ]/g, "").length || 1;
}

// ---------- dictionary ----------
type JmWord = {
  id: string;
  kanji: { common: boolean; text: string }[];
  kana: { common: boolean; text: string; appliesToKanji: string[] }[];
  sense: { partOfSpeech: string[]; misc: string[]; gloss: { text: string }[]; examples?: { sentences: { lang: string; text: string }[] }[] }[];
};
console.time("dict");
const jm: { words: JmWord[]; tags: Record<string, string> } = JSON.parse(fs.readFileSync(DICT_SRC, "utf8"));
console.timeEnd("dict");
const byKanji = new Map<string, JmWord[]>();
const byKana = new Map<string, JmWord[]>();
const jmById = new Map<string, JmWord>();
for (const w of jm.words) {
  jmById.set(w.id, w);
  for (const k of w.kanji) (byKanji.get(k.text) ?? byKanji.set(k.text, []).get(k.text)!).push(w);
  for (const k of w.kana) (byKana.get(k.text) ?? byKana.set(k.text, []).get(k.text)!).push(w);
}
const jlpt = new Map<string, number>();
for (const n of [5, 4, 3, 2, 1]) {
  const f = path.join(JLPT_DIR, `n${n}.csv`);
  if (!fs.existsSync(f)) continue;
  for (const line of fs.readFileSync(f, "utf8").split("\n").slice(1)) {
    const id = line.split(",")[0]?.trim();
    if (id && !jlpt.has(id)) jlpt.set(id, n);
  }
}

const isCommon = (w: JmWord) => w.kanji.some((k) => k.common) || w.kana.some((k) => k.common);
const wellKnown = (w: JmWord) => isCommon(w) || jlpt.has(w.id);
const firstPos = (w: JmWord) => w.sense[0]?.partOfSpeech ?? [];
const isAffix = (w: JmWord) => firstPos(w).length > 0 && firstPos(w).every((p) => /^(n-)?(pref|suf)$/.test(p));
const isVerbish = (w: JmWord) => firstPos(w).some((p) => p.startsWith("v") || p.startsWith("aux"));

/** Katakana words that mean something else in Japanese clips than their loanword entry (JMdict ids). */
const KATA_OVERRIDE: Record<string, string> = {
  オラ: "2080360", // Shin-chan's "I" (己/俺), not Spanish "hola"
  ワン: "2844785", // a dog's "woof", not "one"
};

function lookup(base: string, readingHira: string): JmWord | undefined {
  const hasKanji = KANJI.test(base);
  const forced = KATA_OVERRIDE[base];
  if (forced) {
    const hit = jmById.get(forced);
    if (hit) return hit;
  }
  let cands: JmWord[];
  if (hasKanji) cands = byKanji.get(base) ?? [];
  else if (KATA.test(base)) {
    // Katakana: the spelling as written first — ホテル is "hotel", never 火照る (ほてる) "to feel hot".
    // A lone katakana character or a rare prefix/suffix is almost always a sound or a fragment.
    const plausible = (w: JmWord) => ([...base].length > 1 || wellKnown(w) || firstPos(w).includes("int")) && (!isAffix(w) || wellKnown(w));
    // A rare kanji word that merely lists this katakana as a variant (ガオガオ → 高考) is not a match.
    cands = (byKana.get(base) ?? []).filter((w) => plausible(w) && (w.kanji.length === 0 || w.kana[0]?.text === base || w.sense[0]?.misc.includes("uk") || wellKnown(w)));
    // Katakana spelling of a native word (フグ → ふぐ, ダメ → だめ) — never a verb (クラス ≠ 暮らす).
    if (!cands.length && kata2hira(base) !== base) cands = (byKana.get(kata2hira(base)) ?? []).filter((w) => plausible(w) && !isVerbish(w));
    if (!cands.length) cands = byKanji.get(base) ?? [];
  } else {
    cands = byKana.get(base) ?? [];
    if (!cands.length) cands = byKanji.get(base) ?? [];
  }
  if (!cands.length) return undefined;
  let best: JmWord | undefined; let bestScore = -Infinity;
  cands.forEach((w, i) => {
    let s = 0;
    const kanaHit = w.kana.find((k) => k.text === base || k.text === readingHira || k.text === kata2hira(base));
    if (kanaHit) s += 8;
    if (isCommon(w)) s += 10;
    if (jlpt.has(w.id)) s += 5;
    if (!hasKanji && (w.kanji.length === 0 || w.sense[0]?.misc.includes("uk"))) s += 6;
    if (!hasKanji && KATA.test(base) && w.sense[0]?.misc.includes("abbr")) s -= 3; // オウム: the parrot, not the abbreviation
    s -= i * 0.01;
    if (s > bestScore) { bestScore = s; best = w; }
  });
  return best;
}

const POS_LABEL: Record<string, string> = {
  n: "noun", pn: "pronoun", "adj-i": "い-adjective", "adj-na": "な-adjective", "adj-no": "の-adjective", "adj-pn": "pre-noun adjective",
  adv: "adverb", "adv-to": "adverb (と)", aux: "auxiliary", "aux-v": "auxiliary verb", "aux-adj": "auxiliary adjective", conj: "conjunction",
  cop: "copula", ctr: "counter", exp: "expression", int: "interjection", prt: "particle", pref: "prefix", suf: "suffix", num: "numeric",
  vs: "する verb", "vs-i": "する verb", "vs-s": "する verb", vi: "intransitive", vt: "transitive", v1: "ichidan verb", "v5k-s": "godan verb",
  vk: "くる verb", "n-suf": "suffix", "n-pref": "prefix", "n-adv": "adverbial noun", "n-t": "time noun",
};
const posLabel = (p: string) => POS_LABEL[p] ?? (p.startsWith("v5") ? "godan verb" : p.startsWith("v1") ? "ichidan verb" : null);

export type DictEntry = {
  w: string; r: string; j: number | null; c: boolean;
  m: { pos: string[]; g: string }[];
  ex: { ja: string; en: string }[];
};
const dictOut: Record<string, DictEntry> = {};
// Family-friendly dictionary: drop vulgar / X-rated senses and crude example sentences.
const BAD_MISC = new Set(["vulg", "X", "derog"]);
const CRUDE = /\b(sex\w*|penis|vagina|genital\w*|crotch|breasts?|nipples?|fuck\w*|shit\w*|bitch\w*|whore|porn\w*|rape\w*|naked|nude|masturbat\w*|condom|erection|orgasm|suicide|kill(ed|ing)? (him|her)self|cocaine|heroin)\b/i;
const cleanSense = (s: JmWord["sense"][number]) => !s.misc.some((m) => BAD_MISC.has(m)) && !s.gloss.some((g) => CRUDE.test(g.text));
function toEntry(w: JmWord, base: string): DictEntry {
  const kanjiText = w.kanji.find((k) => k.text === base)?.text ?? w.kanji[0]?.text;
  const usuallyKana = w.sense[0]?.misc.includes("uk") || !kanjiText;
  const senses = w.sense.filter(cleanSense);
  const ex: { ja: string; en: string }[] = [];
  for (const s of senses) for (const e of s.examples ?? []) {
    const ja = e.sentences.find((x) => x.lang === "jpn")?.text; const en = e.sentences.find((x) => x.lang === "eng")?.text;
    if (ja && en && ex.length < 3 && ja.length <= 40 && !CRUDE.test(en)) ex.push({ ja, en });
  }
  return {
    w: usuallyKana && !KANJI.test(base) ? w.kana[0].text : kanjiText ?? w.kana[0].text,
    r: w.kana[0].text,
    j: jlpt.get(w.id) ?? null,
    c: w.kanji.some((k) => k.common) || w.kana.some((k) => k.common),
    m: (senses.length ? senses : w.sense.slice(0, 1)).slice(0, 4).map((s) => ({
      pos: [...new Set(s.partOfSpeech.map(posLabel).filter(Boolean) as string[])].slice(0, 2),
      g: s.gloss.slice(0, 4).map((g) => g.text).join("; "),
    })),
    ex,
  };
}

// ---------- video metadata (oEmbed) ----------
const metaFile = path.join(HERE, "videos.json");
const meta: Record<string, { title: string; channel: string; channelUrl: string }> = fs.existsSync(metaFile) ? JSON.parse(fs.readFileSync(metaFile, "utf8")) : {};
async function oembed(id: string) {
  if (meta[id]) return meta[id];
  const r = await fetch(`https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v=${id}`);
  if (!r.ok) return null;
  const j = await r.json();
  meta[id] = { title: j.title, channel: j.author_name, channelUrl: j.author_url };
  return meta[id];
}

// ---------- build ----------
/** Audio-first videos (podcasts, radio) usually show one still picture — often a channel's
 * Patreon / course banner — so the feed ranks them well below real video (logic.ts clipScore). */
const STILL_VIDEO = /podcast|ポッドキャスト|ラジオ|\bradio\b/i;
/** Lines that only finish the sentence before them (です！…, ですので、…). */
const OPENS_MID_SENTENCE = /^(です|でした|でしょう|ます|ました)/;
const rawFiles = fs.readdirSync(RAW).filter((f) => f.endsWith(".json")).sort(); // sorted: dictionary display forms must not depend on directory order
const clips: any[] = [];
const videos: Record<string, { title: string; channel: string; channelUrl: string }> = {};
let dropped = 0;
for (const f of rawFiles) {
  const v: RawVideo = JSON.parse(fs.readFileSync(path.join(RAW, f), "utf8"));
  if (BLOCKLIST.has(v.videoId) || !v.clips?.length) continue;
  const m = await oembed(v.videoId);
  if (!m) { console.warn("not embeddable:", v.videoId); continue; }
  const kept: any[] = [];
  for (const c of v.clips) {
    const lines = (c.lines ?? []).filter((l) => l.ja && JP.test(l.ja) && l.end > l.start).sort((a, b) => a.start - b.start);
    // A line never runs into the next one (the AI timing sometimes overshoots an end time).
    for (let i = 0; i + 1 < lines.length; i++) {
      if (lines[i].end > lines[i + 1].start) lines[i] = { ...lines[i], end: Math.max(lines[i].start + 0.3, lines[i + 1].start - 0.05) };
    }
    if (lines.length < 2 || (c.quality ?? 0) < 3) { dropped++; continue; }
    const start = Math.max(0, lines[0].start - 0.4);
    const end = lines[lines.length - 1].end + 0.6;
    if (end - start < 5 || end - start > 45) { dropped++; continue; }
    if (kept.some((k) => start < k.end && end > k.start)) { dropped++; continue; }
    const id = `${v.videoId}-${Math.round(start)}`;
    const proofFile = path.join(PROOF, `${id}.json`);
    if (fs.existsSync(proofFile)) {
      for (const fix of JSON.parse(fs.readFileSync(proofFile, "utf8")).fixes as { line: number; ja: string; en: string }[]) {
        if (lines[fix.line]) lines[fix.line] = { ...lines[fix.line], ja: fix.ja, en: fix.en || lines[fix.line].en };
      }
    }
    // A clip never opens on the tail of the previous sentence (です！はい。…); the id keeps the
    // original start so cached proofs and notes still find the clip.
    let first = 0;
    while (lines.length - first > 2 && OPENS_MID_SENTENCE.test(lines[first].ja.trim())) first++;
    const clipStart = first ? Math.max(0, lines[first].start - 0.4) : start;
    const outLines = lines.slice(first).map((l) => {
      const toks = tokenizer.tokenize(l.ja.trim());
      const groups = group(toks);
      const weights = groups.map((g) => (g.parts.every(isPunct) ? 0 : mora(g.parts.some((p) => DIGITS.test(p.surface_form)) ? numberGroupReading(g.parts) : g.parts.map((p) => p.reading ?? p.surface_form).join(""))));
      const total = weights.reduce((a, b) => a + b, 0) || 1;
      const span = (l.end - l.start) * 0.95;
      let t = l.start;
      const words: Word[] = groups.map((g, i) => {
        const surface = g.parts.map((p) => p.surface_form).join("");
        const punct = g.parts.every(isPunct);
        const numeric = !punct && g.parts.some((p) => DIGITS.test(p.surface_form));
        const readingKata = numeric ? numberGroupReading(g.parts) : g.parts.map((p) => (p.reading && p.reading !== "*" ? p.reading : p.surface_form)).join("");
        const reading = punct ? "" : kata2hira(readingKata);
        const head = g.head;
        const base = head.basic_form && head.basic_form !== "*" ? head.basic_form : head.surface_form;
        // try the whole merged surface (お得意様, 勉強する) before the head's dictionary form
        const prefix = g.parts[0].pos === "接頭詞" ? g.parts[0].surface_form : "";
        const stretched = g.parts.some((p) => LONG_VOWEL.test(p.surface_form)) && g.parts.length > 1;
        const unstretched = surface.replace(/[ーｰ]/g, "");
        const tries = [...(stretched && unstretched.length >= 2 ? [unstretched] : []), surface, prefix + base, base];
        let entry: JmWord | undefined; let usedBase = base;
        // numbers have no useful dictionary entry ("5" would look up 五); the Explain tab covers them
        if (!punct && !numeric) for (const tryBase of tries) {
          const baseReading = kata2hira(tokenizer.tokenize(tryBase).map((x) => x.reading ?? x.surface_form).join(""));
          entry = lookup(tryBase, baseReading);
          if (entry) { usedBase = tryBase; break; }
        }
        if (entry && !dictOut[entry.id]) dictOut[entry.id] = toEntry(entry, usedBase);
        const t0 = t; t += (weights[i] / total) * span;
        return {
          s: surface,
          r: punct || kata2hira(surface) === reading ? "" : reading,
          ro: punct ? "" : wanakana.toRomaji(readingKata),
          b: punct ? "" : numeric ? surface : usedBase,
          p: punct ? "punct" : simplePos(head),
          d: entry?.id ?? null,
          ...(punct ? {} : { f: furigana(surface, reading) }),
          t0: round(t0), t1: round(punct ? t0 : t),
        };
      });
      return { start: round(l.start), end: round(l.end), en: l.en, sp: l.speaker ?? "", ja: l.ja.trim(), words };
    });
    const level = LEVELS.includes(c.level) ? c.level : "N4";
    const topics = [...new Set([...(c.topics ?? []), ...v.pickTopics].filter((t) => TOPICS.has(t)))].slice(0, 4);
    const clip = {
      id, videoId: v.videoId, start: round(clipStart), end: round(end), title: c.title.slice(0, 48), level, topics,
      grammar: (c.grammar ?? []).slice(0, 3), quality: c.quality, lines: outLines,
      ...(STILL_VIDEO.test(m.title) ? { still: true } : {}),
    };
    kept.push(clip);
  }
  if (kept.length) { videos[v.videoId] = m; clips.push(...kept); }
}
fs.writeFileSync(metaFile, JSON.stringify(meta, null, 1));

/** Fingerprint of a clip's word split; explain notes record it (scripts/content/explain.py token_sig). */
export const tokenSig = (c: { lines: { words: { s: string }[] }[] }) =>
  crypto.createHash("sha1").update(c.lines.map((l) => l.words.map((w) => w.s).join("|")).join("\n")).digest("hex").slice(0, 12);
const stale = new Set<string>();

// stable, deterministic order: by id
clips.sort((a, b) => (a.id < b.id ? -1 : 1));
const content = { version: 1, generatedAt: new Date().toISOString().slice(0, 10), videos, clips };

for (const dir of OUT_DIRS) {
  if (dir.includes("mobile") && !fs.existsSync(path.join(ROOT, "mobile"))) continue;
  fs.mkdirSync(path.join(dir, "explain"), { recursive: true });
  fs.writeFileSync(path.join(dir, "content.json"), JSON.stringify(content));
  fs.writeFileSync(path.join(dir, "dict.json"), JSON.stringify(dictOut));
  for (const c of clips) {
    const ef = path.join(EXPLAIN, `${c.id}.json`);
    const target = path.join(dir, "explain", `${c.id}.json`);
    if (!fs.existsSync(ef)) { fs.rmSync(target, { force: true }); continue; }
    // notes are keyed by "line.word" index — only ship them for the tokenisation they were written for
    const sig = JSON.parse(fs.readFileSync(ef, "utf8")).sig;
    if (sig && sig !== tokenSig(c)) { stale.add(c.id); fs.rmSync(target, { force: true }); continue; }
    fs.copyFileSync(ef, target);
  }
}
if (stale.size) console.warn(`stale explain notes (re-run explain.py): ${stale.size}`);
const perLevel = Object.fromEntries(LEVELS.map((l) => [l, clips.filter((c) => c.level === l).length]));
const perTopic: Record<string, number> = {};
for (const c of clips) for (const t of c.topics) perTopic[t] = (perTopic[t] ?? 0) + 1;
console.log(`clips ${clips.length} (dropped ${dropped}) videos ${Object.keys(videos).length} dict ${Object.keys(dictOut).length}`);
console.log("levels", perLevel);
console.log("topics", perTopic);
