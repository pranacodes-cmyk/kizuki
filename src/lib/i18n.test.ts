// @vitest-environment jsdom
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";

import STRINGS from "./i18n-strings.json";
import { setLang, tr, trIn, trn } from "./i18n-core";
import { PLANS, planBadge, planSub, priceLine, trialBadge } from "./paywall";

const LANGS = ["vi", "id", "th", "ko", "pt"] as const;
const TABLES = STRINGS as Record<string, Record<string, string>>;
const KEYS = (JSON.parse(readFileSync(join(__dirname, "../../scripts/i18n/ui/keys.json"), "utf8")) as { key: string }[]).map((k) => k.key);
const placeholders = (s: string) => (s.match(/\{\w+\}/g) ?? []).sort();
const count = (s: string, m: string) => s.split(m).length - 1;

afterEach(() => setLang("en"));

describe("interface catalogs", () => {
  it("cover every interface string in all five languages", () => {
    expect(KEYS.length).toBeGreaterThan(700);
    for (const lang of LANGS) {
      const missing = KEYS.filter((k) => !TABLES[lang]?.[k]?.trim());
      expect(missing, lang).toEqual([]);
    }
  });

  it("keep placeholders, highlight brackets, bold markers and line breaks", () => {
    for (const lang of LANGS) {
      for (const [en, t] of Object.entries(TABLES[lang]!)) {
        expect(placeholders(t), `${lang}: ${en}`).toEqual(placeholders(en));
        for (const m of ["[", "]", "**", "\n"]) expect(count(t, m), `${lang} ${m}: ${en}`).toBe(count(en, m));
      }
    }
  });

  it("Thai and Korean text is written in its own script", () => {
    expect(TABLES["th"]!["Continue"]).toMatch(/[\u0e00-\u0e7f]/);
    expect(TABLES["ko"]!["Continue"]).toMatch(/[\uac00-\ud7af]/);
  });
});

describe("tr", () => {
  it("shows the chosen language and fills placeholders", () => {
    setLang("vi");
    expect(tr("Continue")).toBe(TABLES["vi"]!["Continue"]);
    expect(tr("Day {n}", { n: 5 })).toBe(TABLES["vi"]!["Day {n}"]!.replace("{n}", "5"));
  });

  it("falls back to English for text that has no translation", () => {
    setLang("ko");
    expect(tr("A sentence that is not in the catalog")).toBe("A sentence that is not in the catalog");
  });

  it("picks the singular or plural key by count", () => {
    setLang("pt");
    expect(trn(1, "{n} clip", "{n} clips")).toBe(TABLES["pt"]!["{n} clip"]!.replace("{n}", "1"));
    expect(trn(3, "{n} clip", "{n} clips")).toBe(TABLES["pt"]!["{n} clips"]!.replace("{n}", "3"));
  });

  it("previews another language without switching", () => {
    expect(trIn("id", "Continue")).toBe(TABLES["id"]!["Continue"]);
    expect(tr("Continue")).toBe("Continue");
  });
});

describe("paywall in the learner's language", () => {
  it("keeps the live store price inside translated plan text", () => {
    setLang("vi");
    expect(priceLine(PLANS.yearly, 7)).toContain("$54.99");
    expect(priceLine(PLANS.yearly, 7)).not.toContain("days free");
    expect(planSub(PLANS.yearly)).toContain("$54.99");
    expect(planBadge(PLANS.yearly)).toContain("58");
    expect(trialBadge(7)).not.toContain("Cancel anytime");
  });

  it("is unchanged in English", () => {
    expect(planSub(PLANS.yearly)).toBe("12 months · $54.99");
    expect(planBadge(PLANS.yearly)).toBe("Save 58%");
    expect(planSub(PLANS.monthly)).toBe("Billed monthly");
  });
});
