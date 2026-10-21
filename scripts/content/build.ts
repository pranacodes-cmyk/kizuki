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
import fs from "node:fs";
import path from "node:path";
import kuromoji from "kuromoji";
import * as wanakana from "wanakana";

const ROOT = path.resolve(import.meta.dir, "../..");
const HERE = import.meta.dir;
const RAW = path.join(HERE, "raw");
const EXPLAIN = path.join(HERE, "explain");
const PROOF = path.join(HERE, "proof");
const DICT_SRC = process.env.JMDICT ?? "/tmp/kiku/dict/jmdict-examples-eng-3.6.2.json";
const JLPT_DIR = process.env.JLPT_DIR ?? "/tmp/kiku/dict";
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

/** Merge kuromoji morphemes into learner-sized words (歩い+てる → 歩いてる, お+座り → お座り). */
function group(tokens: kuromoji.IpadicFeatures[]) {
  const out: { parts: kuromoji.IpadicFeatures[]; head: kuromoji.IpadicFeatures }[] = [];
  for (const t of tokens) {
    const prev = out[out.length - 1];
    const prevLast = prev?.parts[prev.parts.length - 1];
    const prevIsPred = prev && (prev.head.pos === "動詞" || prev.head.pos === "形容詞");
    let merge = false;
    if (prev && !isPunct(t)) {
      if (prevLast!.pos === "接頭詞" && (t.pos === "名詞" || t.pos === "動詞" || t.pos === "形容詞")) merge = true;
      else if (prevIsPred && (t.pos === "助動詞" || t.pos_detail_1 === "非自立" && (t.pos === "動詞" || t.pos === "形容詞") || t.pos_detail_1 === "接尾")) merge = true;
      else if (prevIsPred && t.pos === "助詞" && t.pos_detail_1 === "接続助詞" && ["て", "で", "ちゃ", "じゃ", "ば"].includes(t.surface_form)) merge = true;
      else if (prev.head.pos === "名詞" && prev.head.pos_detail_1 === "サ変接続" && t.pos === "動詞" && t.basic_form === "する") merge = true;
      else if (prev.head.pos === "名詞" && t.pos === "名詞" && t.pos_detail_1 === "接尾" && !["さん", "ちゃん", "くん", "君", "たち", "達"].includes(t.surface_form)) merge = true;
    }
    if (merge) {
      prev!.parts.push(t);
      // a prefix group takes the following content word as its head
      if (prev!.head.pos === "接頭詞") prev!.head = t;
      // サ変 noun + する behaves like a verb for further merging
      if (t.pos === "動詞" && t.basic_form === "する" && prev!.head.pos === "名詞") prev!.head = { ...prev!.head, pos: "動詞" } as kuromoji.IpadicFeatures;
    } else out.push({ parts: [t], head: t });
  }
  return out;
}

/** Split a word into [text, ruby] segments so ruby sits only above kanji. */
export function furigana(surface: string, reading: string): [string, string | null][] | undefined {
  if (!KANJI.test(surface) || !reading) return undefined;
  const segs: { text: string; kanji: boolean }[] = [];
  for (const ch of surface) {
    const k = KANJI.test(ch);
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
for (const w of jm.words) {
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

function lookup(base: string, readingHira: string): JmWord | undefined {
  const hasKanji = KANJI.test(base);
  let cands = hasKanji ? byKanji.get(base) ?? [] : byKana.get(kata2hira(base)) ?? byKana.get(base) ?? [];
  if (!cands.length && !hasKanji) cands = byKanji.get(base) ?? [];
  if (!cands.length) return undefined;
  let best: JmWord | undefined; let bestScore = -1;
  cands.forEach((w, i) => {
    let s = 0;
    const kanaHit = w.kana.find((k) => k.text === readingHira || k.text === kata2hira(base));
    if (kanaHit) s += 8;
    if (w.kanji.some((k) => k.common) || w.kana.some((k) => k.common)) s += 10;
    if (jlpt.has(w.id)) s += 5;
    if (!hasKanji && (w.kanji.length === 0 || w.sense[0]?.misc.includes("uk"))) s += 6;
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
const rawFiles = fs.readdirSync(RAW).filter((f) => f.endsWith(".json"));
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
    const outLines = lines.map((l) => {
      const toks = tokenizer.tokenize(l.ja.trim());
      const groups = group(toks);
      const weights = groups.map((g) => (g.parts.every(isPunct) ? 0 : mora(g.parts.map((p) => p.reading ?? p.surface_form).join(""))));
      const total = weights.reduce((a, b) => a + b, 0) || 1;
      const span = (l.end - l.start) * 0.95;
      let t = l.start;
      const words: Word[] = groups.map((g, i) => {
        const surface = g.parts.map((p) => p.surface_form).join("");
        const punct = g.parts.every(isPunct);
        const readingKata = g.parts.map((p) => (p.reading && p.reading !== "*" ? p.reading : p.surface_form)).join("");
        const reading = punct ? "" : kata2hira(readingKata);
        const head = g.head;
        const base = head.basic_form && head.basic_form !== "*" ? head.basic_form : head.surface_form;
        // try the whole merged surface (お得意様, 勉強する) before the head's dictionary form
        const prefix = g.parts[0].pos === "接頭詞" ? g.parts[0].surface_form : "";
        const tries = [surface, prefix + base, base];
        let entry: JmWord | undefined; let usedBase = base;
        if (!punct) for (const tryBase of tries) {
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
          b: punct ? "" : usedBase,
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
      id, videoId: v.videoId, start: round(start), end: round(end), title: c.title.slice(0, 48), level, topics,
      grammar: (c.grammar ?? []).slice(0, 3), quality: c.quality, lines: outLines,
    };
    kept.push(clip);
  }
  if (kept.length) { videos[v.videoId] = m; clips.push(...kept); }
}
fs.writeFileSync(metaFile, JSON.stringify(meta, null, 1));

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
    if (fs.existsSync(ef)) fs.copyFileSync(ef, path.join(dir, "explain", `${c.id}.json`));
  }
}
const perLevel = Object.fromEntries(LEVELS.map((l) => [l, clips.filter((c) => c.level === l).length]));
const perTopic: Record<string, number> = {};
for (const c of clips) for (const t of c.topics) perTopic[t] = (perTopic[t] ?? 0) + 1;
console.log(`clips ${clips.length} (dropped ${dropped}) videos ${Object.keys(videos).length} dict ${Object.keys(dictOut).length}`);
console.log("levels", perLevel);
console.log("topics", perTopic);
