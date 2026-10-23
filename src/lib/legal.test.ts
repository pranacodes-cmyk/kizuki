import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

import { PRIVACY, TERMS } from "./legal";

// The Android/iPhone app shows the same policy: mobile/lib/data/legal.dart is generated from
// legal.ts (bun scripts/legal/gen_legal_dart.ts) and must not drift from it.
const dart = readFileSync(path.resolve(__dirname, "../../mobile/lib/data/legal.dart"), "utf8");
const dartQuote = (s: string) => "'" + s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$") + "'";

describe("legal copy", () => {
  it("phone app privacy policy and terms match the website word for word", () => {
    for (const doc of [PRIVACY, TERMS]) {
      for (const text of [doc.title, doc.updated, doc.intro, ...doc.sections.flatMap((s) => [s.h, ...s.body])]) {
        expect(dart).toContain(dartQuote(text));
      }
    }
  });

  it("privacy policy covers what the stores require", () => {
    const all = PRIVACY.sections.flatMap((s) => [s.h, ...s.body]).join("\n");
    expect(all).toContain("Settings → Delete account");
    expect(all).toContain("kiku-clip-word-garden.lovable.app/support");
    expect(all).toContain("pranacodes@gmail.com");
    for (const provider of ["RevenueCat", "Meta Platforms", "OpenAI", "YouTube", "Apple App Store and Google Play"]) {
      expect(all).toContain(provider);
    }
  });
});
