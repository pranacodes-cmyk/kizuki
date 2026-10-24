// Guards the generated clip data (scripts/content/build.ts) that both apps ship.
import fs from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";
import exclusions from "../../scripts/content/excluded-clips.json";

type W = { s: string; b: string; p: string; d: string | null };
type Data = { clips: { id: string; lines: { words: W[] }[] }[] };
type Dict = Record<string, { w: string; r: string; j: number | null; m: { pos: string[]; g: string }[] }>;

const root = path.resolve(__dirname, "../..");
const read = (p: string) => fs.readFileSync(path.join(root, p), "utf8");
const meta = JSON.parse(read("public/data/content.json")) as { parts: string[] };
const content = { clips: meta.parts.flatMap((p) => (JSON.parse(read(`public/data/${p}`)) as Data).clips) } as Data;
const dict = JSON.parse(read("public/data/dict.json")) as Dict;
const words = content.clips.flatMap((c) => c.lines.flatMap((l) => l.words));
const glossOf = (surface: string) => {
  const w = words.find((x) => x.s === surface && x.d);
  return w?.d ? dict[w.d]?.m[0]?.g ?? "" : "";
};

/** Headword + JLPT level the word card shows for the most common token with this surface and part of speech. */
const shown = (surface: string, pos?: string) => {
  const hits = new Map<string, number>();
  for (const w of words) if (w.s === surface && (!pos || w.p === pos)) hits.set(String(w.d), (hits.get(String(w.d)) ?? 0) + 1);
  const top = [...hits.entries()].sort((a, b) => b[1] - a[1])[0]?.[0];
  const e = top && top !== "null" ? dict[top] : undefined;
  return e ? { w: e.w, j: e.j, g: e.m[0]?.g ?? "" } : null;
};

describe("word levels and grammar words (word card badge)", () => {
  it("everyday greetings and first-lesson words are N5, not N3/N2/N1", () => {
    for (const s of ["おはよう", "こんにちは", "ありがとう", "すみません", "これ", "それ", "さん", "だけ", "日本"]) {
      expect(shown(s)?.j, s).toBe(5);
    }
    expect(shown("お願いします")?.j).toBe(5);
  });
  it("grammar words never borrow a kanji noun's entry", () => {
    expect(shown("の", "particle")).toMatchObject({ w: "の" }); // not 野 "field"
    expect(shown("た", "auxiliary")).toMatchObject({ w: "た" }); // not 田 "rice field"
    expect(shown("ます", "auxiliary")?.g).toMatch(/politeness/); // not 増す "to increase"
    expect(shown("いっぱい", "adverb")?.w).toBe("一杯"); // not 一敗 "one defeat"
    expect(shown("なん", "pronoun")?.w).toBe("何"); // not 難 "difficulty"
    expect(shown("しよう", "verb")?.g).toMatch(/^to do/); // not 仕様 / 使用
    expect(shown("いる", "verb")?.g).toMatch(/^to be/); // 居る, not 要る "to need"
  });
});

describe("clip word meanings", () => {
  it("never ships editorially excluded invalid clip windows", () => {
    expect(content.clips.some((c) => c.id === "-M5HGD6fhy4-303")).toBe(false);
    expect(content.clips.filter((c) => Object.hasOwn(exclusions, c.id))).toHaveLength(0);
  });
  it("katakana loanwords get their loanword meaning", () => {
    expect(glossOf("ホテル")).toMatch(/^hotel/);
    expect(glossOf("クラス")).toMatch(/^class/);
    expect(glossOf("チョコ")).toMatch(/^chocolate/);
    expect(glossOf("ペット")).toMatch(/^pet/);
    expect(glossOf("ハンドタオル")).toMatch(/^hand-towel/);
  });

  it("katakana spellings of Japanese words keep the Japanese word", () => {
    expect(glossOf("ダメ")).toMatch(/no good/);
    expect(glossOf("オラ")).toMatch(/^I; me/);
  });

  it("no katakana word is explained as a verb (クラス is never 暮らす)", () => {
    const kataOnly = /^[\u30a1-\u30fa\u30fc]+$/;
    const verbs = words.filter((w) => w.d && kataOnly.test(w.b) && (dict[w.d]?.m[0]?.pos ?? []).some((p) => /^(godan|ichidan|auxiliary|くる) verb$/.test(p)));
    expect(verbs.map((w) => `${w.s} → ${dict[w.d!]?.w}`)).toEqual([]);
  });

  it("katakana words the tokenizer splits stay one word (Gundam is not 'cancer' + 'dam')", () => {
    const surfaces = new Set(words.map((w) => w.s));
    for (const whole of ["ガンダム", "イヤホン", "サブウェイ", "ブルーレイ", "カンフー"]) expect(surfaces.has(whole), whole).toBe(true);
    expect(glossOf("ガンダム")).toMatch(/^Gundam/);
    expect(glossOf("イヤホン")).toMatch(/^earphone/);
    for (const piece of ["ガン", "ダム", "イヤ", "ホン", "ウェイ"]) {
      expect(content.clips.some((c) => c.lines.some((l) => l.words.some((w, i) => w.s === piece && /^[\u30a1-\u30fa\u30fc]+$/.test(l.words[i + 1]?.s ?? "") && ["ガンダム", "イヤホン", "サブウェイ"].includes(w.s + l.words[i + 1]!.s)))), piece).toBe(false);
    }
  });

  it("every clip ships its word explanations, written for its exact word split", () => {
    const missing = content.clips.filter((c) => !fs.existsSync(path.join(root, "public/data/explain", `${c.id}.json`)));
    expect(missing.map((c) => c.id)).toEqual([]);
  });

  it("every word's dictionary id exists", () => {
    expect(words.filter((w) => w.d && !dict[w.d]).length).toBe(0);
  });

  it("the Android app ships exactly the same data", () => {
    for (const f of ["content.json", "dict.json", ...meta.parts]) expect(read(`mobile/assets/data/${f}`)).toBe(read(`public/data/${f}`));
  });
});
