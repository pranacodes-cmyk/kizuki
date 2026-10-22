// Guards the generated clip data (scripts/content/build.ts) that both apps ship.
import fs from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

type W = { s: string; b: string; p: string; d: string | null };
type Data = { clips: { id: string; lines: { words: W[] }[] }[] };
type Dict = Record<string, { w: string; r: string; m: { pos: string[]; g: string }[] }>;

const root = path.resolve(__dirname, "../..");
const read = (p: string) => fs.readFileSync(path.join(root, p), "utf8");
const content = JSON.parse(read("public/data/content.json")) as Data;
const dict = JSON.parse(read("public/data/dict.json")) as Dict;
const words = content.clips.flatMap((c) => c.lines.flatMap((l) => l.words));
const glossOf = (surface: string) => {
  const w = words.find((x) => x.s === surface && x.d);
  return w?.d ? dict[w.d]?.m[0]?.g ?? "" : "";
};

describe("clip word meanings", () => {
  it("katakana loanwords get their loanword meaning", () => {
    expect(glossOf("ホテル")).toMatch(/^hotel/);
    expect(glossOf("クラス")).toMatch(/^class/);
    expect(glossOf("チョコ")).toMatch(/^chocolate/);
    expect(glossOf("ペット")).toMatch(/^pet/);
    expect(glossOf("タオル")).toMatch(/^towel/);
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

  it("every word's dictionary id exists", () => {
    expect(words.filter((w) => w.d && !dict[w.d]).length).toBe(0);
  });

  it("the Android app ships exactly the same data", () => {
    for (const f of ["content.json", "dict.json"]) expect(read(`mobile/assets/data/${f}`)).toBe(read(`public/data/${f}`));
  });
});
