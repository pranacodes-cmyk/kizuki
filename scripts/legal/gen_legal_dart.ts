// Regenerates mobile/lib/data/legal.dart from src/lib/legal.ts: bun scripts/legal/gen_legal_dart.ts
import { PRIVACY, TERMS, type LegalDoc } from "../../src/lib/legal";
const q = (s: string) => "'" + s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$") + "'";
const doc = (name: string, d: LegalDoc) => {
  const secs = d.sections.map((s) => `    LegalSection(${q(s.h)}, [\n${s.body.map((b) => `      ${q(b)},`).join("\n")}\n    ]),`).join("\n");
  return `const ${name} = LegalDoc(\n  title: ${q(d.title)},\n  updated: ${q(d.updated)},\n  intro: ${q(d.intro)},\n  sections: [\n${secs}\n  ],\n);\n`;
};
const out = `// GENERATED from src/lib/legal.ts — the same Privacy Policy and Terms word for word.
// Edit src/lib/legal.ts, then run: bun scripts/legal/gen_legal_dart.ts (src/lib/legal.test.ts fails while they differ).
// Lines starting with "• " render as bullet points.

class LegalSection {
  final String h;
  final List<String> body;
  const LegalSection(this.h, this.body);
}

class LegalDoc {
  final String title, updated, intro;
  final List<LegalSection> sections;
  const LegalDoc({required this.title, required this.updated, required this.intro, required this.sections});
}

${doc("privacyDoc", PRIVACY)}
${doc("termsDoc", TERMS)}`;
await Bun.write(new URL("../../mobile/lib/data/legal.dart", import.meta.url).pathname, out);
console.log("written", out.length);
