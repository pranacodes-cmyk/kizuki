// App interface text catalog for the learner languages.
//
//   bun scripts/i18n/gen_strings.ts extract   # list every English interface string → scripts/i18n/ui/keys.json
//   bun scripts/i18n/gen_strings.ts build     # reviewed translations → src/lib/i18n-strings.json + mobile/lib/i18n/strings.g.dart
//   bun scripts/i18n/gen_strings.ts check     # fails when a key is untranslated or the generated files drifted
//
// Interface text is written in English in both clients and wrapped in tr()/trn()/trSpans()/trIn();
// shared data (onboarding answers, topics, tour, plan items, achievements, word levels…) is shown
// through tr() where it is displayed, so its English strings are collected from the web data
// modules (the Flutter data mirrors them 1:1). Translations live in scripts/i18n/ui/<lang>.json,
// written by translate_ui.py (translate + independent review + deterministic checks).
import { readdirSync, readFileSync, statSync, writeFileSync, existsSync } from "node:fs";
import { join, relative } from "node:path";
import ts from "typescript";

const ROOT = join(import.meta.dir, "..", "..");
const UI = join(ROOT, "scripts", "i18n", "ui");
const LANGS = ["vi", "id", "th", "ko", "pt"] as const;
const OUT_JSON = join(ROOT, "src", "lib", "i18n-strings.json");
const OUT_DART = join(ROOT, "mobile", "lib", "i18n", "strings.g.dart");

type Key = { key: string; files: string[]; note?: string };

function walk(dir: string, ok: (f: string) => boolean, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const f = join(dir, name);
    if (statSync(f).isDirectory()) walk(f, ok, out);
    else if (ok(f)) out.push(f);
  }
  return out;
}

const TR_FUNCS = new Set(["tr", "trSpans", "trIn"]);
// Data modules whose strings are shown through tr() at the display point.
const DATA_MODULES = ["onboarding.ts", "topics.ts", "tour.ts", "logic.ts", "paywall.ts", "support.ts", "achievements.ts"];
const DATA_PROPS = new Set(["label", "hint", "title", "body", "desc", "description", "text", "sub", "badge", "button", "q", "a", "tagline", "cta", "intro", "stepsTitle", "steps", "webTitle", "web", "kept"]);
// Arrays of display strings inside data modules (always strings people read).
const DATA_ARRAYS = new Set(["monthNames", "PERKS", "TABS"]);

function addKey(keys: Map<string, Key>, key: string, file: string) {
  if (!/[A-Za-z]/.test(key)) return;
  const rel = relative(ROOT, file);
  const k = keys.get(key) ?? { key, files: [] };
  if (!k.files.includes(rel)) k.files.push(rel);
  keys.set(key, k);
}

function literal(n: ts.Node | undefined): string | null {
  if (!n) return null;
  if (ts.isStringLiteral(n) || ts.isNoSubstitutionTemplateLiteral(n)) return n.text;
  return null;
}

function extractTs(keys: Map<string, Key>, file: string, data: boolean) {
  const src = readFileSync(file, "utf8");
  const sf = ts.createSourceFile(file, src, ts.ScriptTarget.Latest, true, file.endsWith(".tsx") ? ts.ScriptKind.TSX : ts.ScriptKind.TS);
  const visit = (n: ts.Node) => {
    if (ts.isCallExpression(n)) {
      const callee = n.expression.getText(sf);
      if (TR_FUNCS.has(callee)) {
        const arg = callee === "trIn" ? n.arguments[1] : n.arguments[0];
        const s = literal(arg);
        if (s != null) addKey(keys, s, file);
        // tr(cond ? "A" : "B")
        if (arg && ts.isConditionalExpression(arg)) for (const b of [arg.whenTrue, arg.whenFalse]) { const v = literal(b); if (v) addKey(keys, v, file); }
      } else if (callee === "trn") {
        for (const a of n.arguments.slice(1, 3)) { const s = literal(a); if (s != null) addKey(keys, s, file); }
      }
    }
    if (ts.isVariableDeclaration(n) && DATA_ARRAYS.has(n.name.getText(sf)) && n.initializer) {
      const arr = ts.isAsExpression(n.initializer) ? n.initializer.expression : n.initializer;
      if (ts.isArrayLiteralExpression(arr)) for (const e of arr.elements) { const s = literal(e); if (s) addKey(keys, s, file); }
    }
    if (data) {
      // Founder story captions ({ t, text }) follow the English video, so they stay English.
      const timedCaption = ts.isPropertyAssignment(n) && ts.isObjectLiteralExpression(n.parent) && n.parent.properties.some((p) => p.name?.getText(sf) === "t");
      if (ts.isPropertyAssignment(n) && !timedCaption && DATA_PROPS.has(n.name.getText(sf).replace(/["']/g, ""))) {
        const s = literal(n.initializer);
        if (s && /[A-Za-z]{2,}/.test(s)) addKey(keys, s, file);
        if (ts.isConditionalExpression(n.initializer)) for (const b of [n.initializer.whenTrue, n.initializer.whenFalse]) { const v = literal(b); if (v) addKey(keys, v, file); }
      }
      // Record<string, string> display maps: POS_NAMES, LEVEL_HINT, …
      if (ts.isVariableDeclaration(n) && /^(POS_NAMES|LEVEL_HINT|[A-Z_]*LABELS?)$/.test(n.name.getText(sf)) && n.initializer && ts.isObjectLiteralExpression(n.initializer)) {
        for (const p of n.initializer.properties) if (ts.isPropertyAssignment(p)) { const s = literal(p.initializer); if (s) addKey(keys, s, file); }
      }
    }
    ts.forEachChild(n, visit);
  };
  visit(sf);
}

// Dart string literal right after `tr(` / `trn(n, ` / `trSpans(` / `trIn(x, `.
const DART_STR = String.raw`(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")`;
function dartUnescape(s: string): string {
  return s.replace(/\\(u\{[0-9a-fA-F]+\}|u[0-9a-fA-F]{4}|.)/g, (_, c: string) => {
    if (c === "n") return "\n";
    if (c === "t") return "\t";
    if (c.startsWith("u{")) return String.fromCodePoint(parseInt(c.slice(2, -1), 16));
    if (c.startsWith("u") && c.length === 5) return String.fromCharCode(parseInt(c.slice(1), 16));
    return c;
  });
}

function extractDart(keys: Map<string, Key>, file: string, problems: string[]) {
  const src = readFileSync(file, "utf8");
  const take = (raw1: string | undefined, raw2: string | undefined, where: number) => {
    const raw = raw1 ?? raw2 ?? "";
    if (/(^|[^\\])\$/.test(raw)) {
      problems.push(`${relative(ROOT, file)}:${src.slice(0, where).split("\n").length}: interpolation inside tr(): ${raw.slice(0, 60)}`);
      return;
    }
    addKey(keys, dartUnescape(raw), file);
  };
  for (const m of src.matchAll(new RegExp(String.raw`\b(?:tr|trSpans)\(\s*` + DART_STR, "g"))) take(m[1], m[2], m.index ?? 0);
  for (const m of src.matchAll(new RegExp(String.raw`\btrIn\([^,]+,\s*` + DART_STR, "g"))) take(m[1], m[2], m.index ?? 0);
  for (const m of src.matchAll(new RegExp(String.raw`\btrn\([^,]+,\s*` + DART_STR + String.raw`\s*,\s*` + DART_STR, "g"))) {
    take(m[1], m[2], m.index ?? 0);
    take(m[3], m[4], m.index ?? 0);
  }
  // tr(cond ? 'A' : 'B')
  for (const m of src.matchAll(new RegExp(String.raw`\btr\([^()'"]*\?\s*` + DART_STR + String.raw`\s*:\s*` + DART_STR, "g"))) {
    take(m[1], m[2], m.index ?? 0);
    take(m[3], m[4], m.index ?? 0);
  }
}

function extract(): { keys: Key[]; problems: string[] } {
  const keys = new Map<string, Key>();
  const problems: string[] = [];
  const web = [
    ...walk(join(ROOT, "src", "routes"), (f) => /\.tsx?$/.test(f) && !f.includes(`${join("routes", "api")}`)),
    ...walk(join(ROOT, "src", "components", "mimi"), (f) => /\.tsx?$/.test(f) && !/\.test\./.test(f)),
    ...walk(join(ROOT, "src", "lib"), (f) => /\.ts$/.test(f) && !/\.test\./.test(f) && !/legal\.ts$/.test(f)),
  ];
  for (const f of web) extractTs(keys, f, DATA_MODULES.some((m) => f.endsWith(join("lib", m))));
  for (const f of walk(join(ROOT, "mobile", "lib"), (f) => f.endsWith(".dart") && !f.endsWith(".g.dart") && !f.endsWith(join("data", "legal.dart")))) extractDart(keys, f, problems);
  // Dictionary part-of-speech labels (shown through tr() on word cards and reviews).
  const dict = JSON.parse(readFileSync(join(ROOT, "public", "data", "dict.json"), "utf8")) as Record<string, { m?: { pos?: string[] }[] }>;
  for (const e of Object.values(dict)) for (const m of e.m ?? []) for (const p of m.pos ?? []) addKey(keys, p, join(ROOT, "public", "data", "dict.json"));
  // Brand-only and code-like strings need no translation.
  for (const k of ["Kizuki", "kizuki", "Kizuki Premium", "OK", "N5", "N4", "N3", "N2", "N1", "JLPT", "Google", "Apple", "YouTube", "PostHog"]) keys.delete(k);
  const notes = existsSync(join(UI, "notes.json")) ? (JSON.parse(readFileSync(join(UI, "notes.json"), "utf8")) as Record<string, string>) : {};
  const list = [...keys.values()].sort((a, b) => a.key.localeCompare(b.key));
  for (const k of list) if (notes[k.key]) k.note = notes[k.key];
  return { keys: list, problems };
}

function readLang(lang: string): Record<string, string> {
  const f = join(UI, `${lang}.json`);
  return existsSync(f) ? (JSON.parse(readFileSync(f, "utf8")) as Record<string, string>) : {};
}

function dartString(s: string): string {
  return "'" + s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$").replace(/\n/g, "\\n") + "'";
}

function generated(keys: string[]) {
  const tables: Record<string, Record<string, string>> = {};
  const missing: Record<string, number> = {};
  for (const lang of LANGS) {
    const t = readLang(lang);
    const table: Record<string, string> = {};
    let miss = 0;
    for (const k of keys) {
      if (typeof t[k] === "string" && t[k].trim()) table[k] = t[k];
      else miss++;
    }
    tables[lang] = table;
    missing[lang] = miss;
  }
  const json = JSON.stringify(tables, null, 0).replace(/^\{/, "{\n").replace(/\},"/g, '},\n"') + "\n";
  let dart = "// GENERATED by scripts/i18n/gen_strings.ts from scripts/i18n/ui/*.json — do not edit.\n// ignore_for_file: lines_longer_than_80_chars\n\nconst Map<String, Map<String, String>> uiStrings = {\n";
  for (const lang of LANGS) {
    dart += `  '${lang}': {\n`;
    for (const [k, v] of Object.entries(tables[lang]!)) dart += `    ${dartString(k)}: ${dartString(v)},\n`;
    dart += "  },\n";
  }
  dart += "};\n";
  return { json, dart, missing };
}

const cmd = process.argv[2];
if (cmd === "extract") {
  const { keys, problems } = extract();
  writeFileSync(join(UI, "keys.json"), JSON.stringify(keys, null, 1) + "\n");
  console.log(`${keys.length} interface strings → scripts/i18n/ui/keys.json`);
  for (const p of problems) console.log("PROBLEM", p);
  if (problems.length) process.exit(1);
} else if (cmd === "build" || cmd === "check") {
  const keys = (JSON.parse(readFileSync(join(UI, "keys.json"), "utf8")) as Key[]).map((k) => k.key);
  const { json, dart, missing } = generated(keys);
  if (cmd === "build") {
    writeFileSync(OUT_JSON, json);
    writeFileSync(OUT_DART, dart);
    console.log(`${keys.length} keys; missing per language:`, missing);
  } else {
    const fresh = extract().keys.map((k) => k.key);
    const stale = fresh.filter((k) => !keys.includes(k));
    const drift = readFileSync(OUT_JSON, "utf8") !== json || readFileSync(OUT_DART, "utf8") !== dart;
    console.log({ keys: keys.length, newKeys: stale.length, missing, drift });
    if (stale.length) console.log("new (run extract + translate_ui.py):", stale.slice(0, 30));
    if (stale.length || drift || Object.values(missing).some((n) => n > 0)) process.exit(1);
  }
} else {
  console.log("usage: gen_strings.ts extract|build|check");
  process.exit(2);
}
