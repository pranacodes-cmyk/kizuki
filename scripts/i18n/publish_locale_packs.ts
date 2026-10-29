#!/usr/bin/env bun
/**
 * Publishes the language packs built by scripts/i18n/build_locale_packs.py (/tmp/locale-packs/<lang>/)
 * to two mirrors — the backend's public `content` storage and the Cloudflare R2 bucket
 * `kizuki-packs` — and points the apps at them through content_settings.locale_packs.
 * Apps (src/lib/locale-pack.ts, mobile/lib/services/locale_pack.dart) download a pack only for a
 * non-English language once the learner has trial/Premium access, verify every file (sha-256,
 * size, the shared parse rules), and use it from the next start; English and the bundled starter
 * translations are always the fallback.
 *
 *   bun scripts/i18n/publish_locale_packs.ts --lang vi            dry run: every check, nothing uploaded
 *   bun scripts/i18n/publish_locale_packs.ts --lang vi --upload   upload both mirrors + read back (not live)
 *   bun scripts/i18n/publish_locale_packs.ts --lang vi --activate upload, read back, then go live
 *   bun scripts/i18n/publish_locale_packs.ts --lang vi --off      that language back to bundled starter only
 *   bun scripts/i18n/publish_locale_packs.ts --status             live pointers
 *   --primary r2   list R2 first (only once the bucket has a custom domain; r2.dev is rate limited)
 *   --min-clips N  refuse to publish a pack with fewer translated clips (default 40)
 *
 * Needs EXT_SB_ACCESS_TOKEN (or KIZUKI_BACKEND_SECRET_KEY) and the linked Cloudflare connection
 * (LOVABLE_API_KEY + CLOUDFLARE_API_KEY) for uploads.
 */
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { gzipSync } from "node:zlib";

import { BACKEND_URL } from "../../src/lib/backend-config";
import {
  clipLocaleSig, contentObjectUrl, isLangCode, localeFileProblem, localeNoteShard, localePackManifest, localePackPointer,
  type LangCode, type LocalePackFile,
} from "../../src/lib/logic";

const ROOT = path.resolve(import.meta.dir, "../..");
const DATA = path.join(ROOT, "public/data");
const PACKS = process.env.KIZUKI_LOCALE_OUT ?? "/tmp/locale-packs";
const PROJECT_REF = new URL(BACKEND_URL).hostname.split(".")[0]!;
const BUCKET = "content";
const R2_BUCKET = "kizuki-packs";
const R2_PUBLIC = process.env.KIZUKI_R2_PUBLIC ?? "https://pub-52ccebc96d0d4f50a033b9595a6739ae.r2.dev";
const CF_API = `${(process.env.CONNECTOR_GATEWAY_BASE_URL ?? "https://connector-gateway.lovable.dev").replace(/\/$/, "")}/cloudflare/client/v4`;

const args = process.argv.slice(2);
const flag = (f: string) => args.includes(f);
const opt = (f: string) => { const i = args.indexOf(f); return i >= 0 ? args[i + 1] : undefined; };
const die = (msg: string): never => { console.error(`✗ ${msg}`); process.exit(1); };

async function serviceKey(): Promise<string> {
  if (process.env.KIZUKI_BACKEND_SECRET_KEY) return process.env.KIZUKI_BACKEND_SECRET_KEY;
  const token = process.env.EXT_SB_ACCESS_TOKEN ?? die("set EXT_SB_ACCESS_TOKEN or KIZUKI_BACKEND_SECRET_KEY");
  const r = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/api-keys?reveal=true`, { headers: { Authorization: `Bearer ${token}` } });
  if (!r.ok) die(`could not read the service key (${r.status})`);
  const keys = (await r.json()) as { name: string; type: string; api_key: string }[];
  return (keys.find((k) => k.type === "secret" && k.name === "default") ?? keys.find((k) => k.type === "secret") ?? keys.find((k) => k.name === "service_role"))?.api_key
    ?? die("no secret key on the project");
}
const auth = (key: string): Record<string, string> => (key.startsWith("sb_") ? { apikey: key } : { apikey: key, Authorization: `Bearer ${key}` });

async function readPointers(key: string): Promise<Record<string, unknown>> {
  const r = await fetch(`${BACKEND_URL}/rest/v1/content_settings?id=eq.1&select=locale_packs`, { headers: auth(key) });
  if (!r.ok) die(`content_settings read failed (${r.status}): ${await r.text()}`);
  const row = ((await r.json()) as { locale_packs: Record<string, unknown> }[])[0] ?? die("content_settings row 1 is missing");
  return row.locale_packs ?? {};
}

async function writePointers(key: string, next: Record<string, unknown>) {
  const r = await fetch(`${BACKEND_URL}/rest/v1/content_settings?id=eq.1`, {
    method: "PATCH",
    headers: { ...auth(key), "Content-Type": "application/json", Prefer: "return=representation" },
    body: JSON.stringify({ locale_packs: next, updated_at: new Date().toISOString() }),
  });
  if (!r.ok) die(`content_settings update failed (${r.status}): ${await r.text()}`);
  console.log("live pointers:", JSON.stringify((await r.json())[0].locale_packs));
}

const sbPublic = (p: string) => `${BACKEND_URL}/storage/v1/object/public/${BUCKET}/${p}`;
const r2Public = (p: string) => `${R2_PUBLIC}/${p}`;

async function sbUpload(key: string, objectPath: string, body: Uint8Array, type: string, cache: string, upsert: boolean) {
  const r = await fetch(`${BACKEND_URL}/storage/v1/object/${BUCKET}/${objectPath}`, {
    method: "POST",
    headers: { ...auth(key), "Content-Type": type, "cache-control": cache, "x-upsert": upsert ? "true" : "false" },
    body: Buffer.from(body),
  });
  if (!r.ok) die(`backend upload ${objectPath} failed (${r.status}): ${await r.text()}`);
}

let cfAccount: string | null = null;
function cfHeaders(): Record<string, string> {
  const lovable = process.env.LOVABLE_API_KEY, cf = process.env.CLOUDFLARE_API_KEY;
  if (!lovable || !cf) die("the Cloudflare connection is not linked (LOVABLE_API_KEY / CLOUDFLARE_API_KEY missing)");
  return { Authorization: `Bearer ${lovable}`, "X-Connection-Api-Key": cf! };
}
async function r2Upload(objectPath: string, body: Uint8Array, type: string) {
  if (!cfAccount) {
    const r = await fetch(`${CF_API}/accounts`, { headers: cfHeaders() });
    const j = (await r.json()) as { success: boolean; result: { id: string }[]; errors: { message: string }[] };
    if (!r.ok || !j.success || !j.result[0]) die(`Cloudflare accounts failed (${r.status}): ${j.errors?.[0]?.message ?? ""}`);
    cfAccount = j.result[0]!.id;
  }
  const r = await fetch(`${CF_API}/accounts/${cfAccount}/r2/buckets/${R2_BUCKET}/objects/${objectPath}`, {
    method: "PUT", headers: { ...cfHeaders(), "Content-Type": type }, body: Buffer.from(body),
  });
  if (r.status === 403) die(`R2 upload refused (403): the Cloudflare token needs "Workers R2 Storage Edit" — ${await r.text()}`);
  if (!r.ok) die(`R2 upload ${objectPath} failed (${r.status}): ${await r.text()}`);
}

// ---------------------------------------------------------------------------

type Clip = { id: string; title: string; grammar: string[]; lines: { ja: string; en: string; words: { s: string; d?: string | null }[] }[] };
type Dict = Record<string, { m: unknown[]; ex: unknown[] }>;

function library() {
  const index = JSON.parse(fs.readFileSync(path.join(DATA, "content.json"), "utf8")) as { parts: string[] };
  const clips = index.parts.flatMap((p) => (JSON.parse(fs.readFileSync(path.join(DATA, p), "utf8")) as { clips: Clip[] }).clips);
  const dict = JSON.parse(fs.readFileSync(path.join(DATA, "dict.json"), "utf8")) as Dict;
  return { byId: new Map(clips.map((c) => [c.id, c])), grammar: new Set(clips.flatMap((c) => c.grammar)), dict };
}

/** Everything the apps check, plus that every translation belongs to this exact library. */
function checkPack(lang: LangCode, lib: ReturnType<typeof library>, texts: Map<string, string>, minClips: number): string[] {
  const problems: string[] = [];
  const parsed = new Map<string, unknown>();
  for (const [name, text] of texts) {
    let j: unknown;
    try { j = JSON.parse(text); } catch { problems.push(`${name}: not JSON`); continue; }
    const p = localeFileProblem(name, j);
    // An empty notes file is fine (no clip of that group has explanations yet).
    if (p) problems.push(`${name}: ${p}`);
    parsed.set(name, j);
  }
  const lines = (parsed.get("lines.json") ?? {}) as Record<string, { s: string; t: string; l: string[] }>;
  if (Object.keys(lines).length < minClips) problems.push(`only ${Object.keys(lines).length} clips translated (minimum ${minClips})`);
  for (const [id, e] of Object.entries(lines)) {
    const c = lib.byId.get(id);
    if (!c) { problems.push(`lines: ${id} is not in the library`); continue; }
    if (e.s !== clipLocaleSig(c.lines)) problems.push(`lines: ${id} was made for other text`);
    if (e.l.length !== c.lines.length) problems.push(`lines: ${id} has ${e.l.length} lines, clip has ${c.lines.length}`);
    if (!e.t.trim() || e.l.some((x) => !x.trim())) problems.push(`lines: ${id} has an empty translation`);
  }
  for (const [id, e] of Object.entries((parsed.get("dict.json") ?? {}) as Record<string, { m: string[]; ex: string[] }>)) {
    const d = lib.dict[id];
    if (!d) problems.push(`dict: ${id} is not in the dictionary`);
    else if (d.m.length !== e.m.length || d.ex.length !== e.ex.length) problems.push(`dict: ${id} counts differ`);
  }
  for (const g of Object.keys((parsed.get("grammar.json") ?? {}) as Record<string, string>)) {
    if (!lib.grammar.has(g)) problems.push(`grammar: "${g.slice(0, 40)}" is not used by any clip`);
  }
  for (let i = 0; i < 32; i++) {
    const name = `notes-${String(i).padStart(2, "0")}.json`;
    for (const [id, n] of Object.entries((parsed.get(name) ?? {}) as Record<string, { s: string }>)) {
      const c = lib.byId.get(id);
      if (!c) problems.push(`${name}: ${id} is not in the library`);
      else if (localeNoteShard(id) !== i) problems.push(`${name}: ${id} belongs in another notes file`);
      else if (n.s !== clipLocaleSig(c.lines)) problems.push(`${name}: ${id} was made for other text`);
      else if (!lines[id]) problems.push(`${name}: ${id} has notes but no line translations`);
    }
  }
  if (lang === "en") problems.push("English has no pack");
  return problems;
}

async function readBack(manifestUrl: string, lang: LangCode, version: number, files: LocalePackFile[]) {
  const back = await fetch(manifestUrl, { cache: "no-store" });
  const checked = localePackManifest(back.ok ? await back.json() : null, lang, version) ?? die(`${manifestUrl} does not read back`);
  if (JSON.stringify(checked.files) !== JSON.stringify(files)) die(`${manifestUrl} lists other files`);
  for (const f of checked.files) {
    const r = await fetch(contentObjectUrl(manifestUrl, f.sha256), { cache: "no-store" });
    const buf = Buffer.from(await r.arrayBuffer());
    const plain = buf[0] === 0x1f && buf[1] === 0x8b ? Bun.gunzipSync(buf) : buf;
    if (!r.ok || plain.byteLength !== f.bytes || createHash("sha256").update(plain).digest("hex") !== f.sha256) die(`${f.name} does not read back intact from ${new URL(manifestUrl).host}`);
  }
}

// ---------------------------------------------------------------------------

const needsKey = flag("--upload") || flag("--activate") || flag("--off") || flag("--status");
const key = needsKey ? await serviceKey() : "";

if (flag("--status")) { console.log(JSON.stringify(await readPointers(key), null, 1)); process.exit(0); }

const langs = (opt("--lang") ?? die("--lang vi[,id,…] is required")).split(",");
for (const l of langs) if (!isLangCode(l) || l === "en") die(`not a pack language: ${l}`);

if (flag("--off")) {
  const live = await readPointers(key);
  for (const l of langs) delete live[l];
  await writePointers(key, live);
  console.log(`✓ ${langs.join(", ")}: apps use English + the bundled starter translations from their next start`);
  process.exit(0);
}

const lib = library();
const minClips = Number(opt("--min-clips") ?? 40);
const mb = (n: number) => `${(n / 1e6).toFixed(2)} MB`;

for (const lang of langs as LangCode[]) {
  const dir = path.join(PACKS, lang);
  if (!fs.existsSync(path.join(dir, "pack.json"))) die(`${dir}/pack.json missing — run scripts/i18n/build_locale_packs.py --lang ${lang}`);
  const built = JSON.parse(fs.readFileSync(path.join(dir, "pack.json"), "utf8")) as { clips: number; dict: number; grammar: number; files: LocalePackFile[] };
  const texts = new Map<string, string>();
  const files: (LocalePackFile & { gz: Uint8Array })[] = [];
  for (const f of built.files) {
    const raw = fs.readFileSync(path.join(dir, f.name));
    const sha = createHash("sha256").update(raw).digest("hex");
    if (sha !== f.sha256 || raw.byteLength !== f.bytes) die(`${lang}/${f.name} changed after the build`);
    texts.set(f.name, raw.toString("utf8"));
    files.push({ name: f.name, sha256: sha, bytes: raw.byteLength, gz: gzipSync(raw, { level: 9 }) });
  }
  const list = files.map(({ name, sha256, bytes }) => ({ name, sha256, bytes }));
  const problems = checkPack(lang, lib, texts, minClips);
  if (problems.length) die(`${lang} pack failed the checks:\n  ${problems.slice(0, 25).join("\n  ")}${problems.length > 25 ? `\n  …${problems.length - 25} more` : ""}`);
  console.log(`[${lang}] ${built.clips} clips, ${built.dict} words, ${built.grammar} grammar lines — ${mb(files.reduce((s, f) => s + f.bytes, 0))} raw → ${mb(files.reduce((s, f) => s + f.gz.byteLength, 0))} download; all checks pass`);
  if (!flag("--upload") && !flag("--activate")) continue;

  // Same files as the live pack → keep its version; otherwise the next one.
  const live = await readPointers(key);
  const current = localePackPointer(live, lang);
  let version = (current?.version ?? 0) + 1;
  if (current) {
    const r = await fetch(current.urls[0]!, { cache: "no-store" });
    const m = r.ok ? localePackManifest(await r.json(), lang, current.version) : null;
    if (m && JSON.stringify(m.files) === JSON.stringify(list)) version = current.version;
  }
  // Never overwrite an earlier upload of this version with different files (a test upload, or a pack
  // someone already downloaded): CDN caches could serve the old manifest. Take the next free version.
  for (;;) {
    const r = await fetch(sbPublic(`locale/${lang}/v${version}.json`), { cache: "no-store" });
    if (!r.ok) break;
    const m = localePackManifest(await r.json().catch(() => null), lang, version);
    if (m && JSON.stringify(m.files) === JSON.stringify(list)) break;
    version++;
  }
  const manifestPath = `locale/${lang}/v${version}.json`;
  const manifestText = JSON.stringify({ lang, version, generatedAt: new Date().toISOString().slice(0, 10), clips: built.clips, dict: built.dict, files: list });
  let up = 0;
  for (const f of files) {
    const objectPath = `locale/objects/${f.sha256}.json.gz`;
    if (!(await fetch(sbPublic(objectPath), { method: "HEAD" })).ok) { await sbUpload(key, objectPath, f.gz, "application/gzip", "max-age=31536000", false); up++; }
    if (!(await fetch(r2Public(objectPath), { method: "HEAD" })).ok) { await r2Upload(objectPath, f.gz, "application/gzip"); up++; }
  }
  await sbUpload(key, manifestPath, Buffer.from(manifestText), "application/json", "max-age=60", true);
  await r2Upload(manifestPath, Buffer.from(manifestText), "application/json");
  console.log(`  ✓ uploaded ${up} new object(s) + ${manifestPath} to both mirrors`);
  const urls = flag("--primary") && opt("--primary") === "r2" ? [r2Public(manifestPath), sbPublic(manifestPath)] : [sbPublic(manifestPath), r2Public(manifestPath)];
  for (const u of urls) await readBack(u, lang, version, list);
  console.log(`  ✓ every file reads back intact from ${urls.map((u) => new URL(u).host).join(" and ")}`);
  if (flag("--activate")) {
    const next = { ...(await readPointers(key)), [lang]: { v: version, urls } };
    if (!localePackPointer(next, lang)) die("pointer failed validation");
    await writePointers(key, next);
    console.log(`  ✓ live: v${version} — learners with ${lang} and trial/Premium download it in the background`);
  } else console.log(`  not live yet — add --activate (manifest ${urls[0]})`);
}
