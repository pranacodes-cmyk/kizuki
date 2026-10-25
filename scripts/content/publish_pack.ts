#!/usr/bin/env bun
/**
 * Publishes the clip library in public/data as a server content pack: more clips without an
 * app update. Apps check the public `content_settings` row, download a newer pack in the
 * background, verify every file and use it from their next start; the library bundled in each
 * build always stays the fallback. Clients: mobile/lib/services/content_pack.dart and
 * src/lib/content-pack.ts (shared rules in logic.ts / logic.dart).
 *
 *   bun scripts/content/publish_pack.ts                   dry run: sizes, checks, nothing uploaded
 *   bun scripts/content/publish_pack.ts --upload          upload files + manifest (not live yet)
 *   bun scripts/content/publish_pack.ts --activate        upload, then point every app at it
 *   bun scripts/content/publish_pack.ts --off             everyone back to their bundled library
 *   bun scripts/content/publish_pack.ts --pause|--resume  stop / allow update checks entirely
 *   bun scripts/content/publish_pack.ts --status          show the live setting
 *   --version N   publish as library version N (default: public/data/content.json "version")
 *   --force       replace an existing manifest of the same version / allow a lower version
 *
 * New clips: add them through the normal pipeline, bump scripts/content/content-version.json,
 * run build.ts + the content tests, then --activate. Apps take a pack only when its version is
 * higher than the library bundled in their build.
 *
 * Needs EXT_SB_ACCESS_TOKEN (Supabase personal access token; the service key is fetched with
 * it) or KIZUKI_BACKEND_SECRET_KEY.
 */
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { gzipSync } from "node:zlib";

import { BACKEND_URL } from "../../src/lib/backend-config";
import {
  CONTENT_PACK_FORMAT, contentClipProblem, contentDictProblem, contentIndexProblem, contentNotesProblem, contentObjectUrl,
  contentPackManifest, notesShard, type ContentPackFile,
} from "../../src/lib/logic";

const ROOT = path.resolve(import.meta.dir, "../..");
const DATA = path.join(ROOT, "public/data");
const PROJECT_REF = new URL(BACKEND_URL).hostname.split(".")[0]!;
const BUCKET = "content";
/** Explanations are grouped into this many files (clip → file by notesShard). */
const NOTES_FILES = 8;

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

/** New-style secret keys (sb_secret_…) are opaque: `apikey` only. Legacy JWT keys also go as bearer. */
const auth = (key: string): Record<string, string> => (key.startsWith("sb_") ? { apikey: key } : { apikey: key, Authorization: `Bearer ${key}` });

async function readSetting(key: string) {
  const r = await fetch(`${BACKEND_URL}/rest/v1/content_settings?id=eq.1&select=*`, { headers: auth(key) });
  if (!r.ok) die(`content_settings read failed (${r.status}): ${await r.text()}`);
  return ((await r.json()) as { updates_enabled: boolean; pack_version: number | null; pack_url: string | null; updated_at: string }[])[0]
    ?? die("content_settings row 1 is missing");
}

async function writeSetting(key: string, patch: Record<string, unknown>) {
  const r = await fetch(`${BACKEND_URL}/rest/v1/content_settings?id=eq.1`, {
    method: "PATCH",
    headers: { ...auth(key), "Content-Type": "application/json", Prefer: "return=representation" },
    body: JSON.stringify({ ...patch, updated_at: new Date().toISOString() }),
  });
  if (!r.ok) die(`content_settings update failed (${r.status}): ${await r.text()}`);
  console.log("live setting:", JSON.stringify((await r.json())[0]));
}

const publicUrl = (p: string) => `${BACKEND_URL}/storage/v1/object/public/${BUCKET}/${p}`;

async function upload(key: string, objectPath: string, body: Uint8Array, type: string, cache: string, upsert: boolean) {
  const r = await fetch(`${BACKEND_URL}/storage/v1/object/${BUCKET}/${objectPath}`, {
    method: "POST",
    headers: { ...auth(key), "Content-Type": type, "cache-control": cache, "x-upsert": upsert ? "true" : "false" },
    body: Buffer.from(body),
  });
  if (!r.ok) die(`upload ${objectPath} failed (${r.status}): ${await r.text()}`);
}

// ---------------------------------------------------------------------------

const key = flag("--upload") || flag("--activate") || flag("--off") || flag("--pause") || flag("--resume") || flag("--status") ? await serviceKey() : "";

if (flag("--status")) { console.log(JSON.stringify(await readSetting(key), null, 1)); process.exit(0); }
if (flag("--off")) { await writeSetting(key, { pack_version: null, pack_url: null }); console.log("✓ every app returns to its bundled library from its next start"); process.exit(0); }
if (flag("--pause")) { await writeSetting(key, { updates_enabled: false }); console.log("✓ update checks paused; apps use their bundled library"); process.exit(0); }
if (flag("--resume")) { await writeSetting(key, { updates_enabled: true }); console.log("✓ update checks resumed"); process.exit(0); }

// Build the pack from the generated library.
const read = (f: string) => fs.readFileSync(path.join(DATA, f), "utf8");
const bundledIndex = JSON.parse(read("content.json")) as { version: number; parts: string[]; videos: Record<string, unknown>; starter?: string[] };
const version = opt("--version") ? Number(opt("--version")) : bundledIndex.version;
if (!Number.isInteger(version) || version < 2) die(`pack version must be a whole number ≥ 2 (got ${opt("--version") ?? bundledIndex.version}); bump scripts/content/content-version.json`);

const texts = new Map<string, string>();
texts.set("content.json", version === bundledIndex.version ? read("content.json") : JSON.stringify({ ...bundledIndex, version }));
for (const p of bundledIndex.parts) texts.set(p, read(p));
texts.set("dict.json", read("dict.json"));
const clips = bundledIndex.parts.flatMap((p) => (JSON.parse(texts.get(p)!) as { clips: { id: string }[] }).clips);
const shards: Record<string, unknown>[] = Array.from({ length: NOTES_FILES }, () => ({}));
let withNotes = 0;
for (const c of [...clips].sort((a, b) => (a.id < b.id ? -1 : 1))) {
  const f = path.join(DATA, "explain", `${c.id}.json`);
  if (!fs.existsSync(f)) continue;
  shards[notesShard(c.id, NOTES_FILES)]![c.id] = JSON.parse(fs.readFileSync(f, "utf8"));
  withNotes++;
}
const notes = shards.map((_, i) => `notes-${i}.json`);
shards.forEach((s, i) => texts.set(notes[i]!, JSON.stringify(s)));

const files: (ContentPackFile & { gz: Uint8Array })[] = [...texts].map(([name, text]) => {
  const raw = Buffer.from(text, "utf8");
  return { name, sha256: createHash("sha256").update(raw).digest("hex"), bytes: raw.byteLength, gz: gzipSync(raw, { level: 9 }) };
});
const manifestJson = { format: CONTENT_PACK_FORMAT, version, generatedAt: new Date().toISOString().slice(0, 10), clips: clips.length, files: files.map(({ name, sha256, bytes }) => ({ name, sha256, bytes })), notes };

// The same checks every app runs before using a pack.
const manifest = contentPackManifest(manifestJson, version) ?? die("manifest failed validation");
const index = JSON.parse(texts.get("content.json")!);
const problems: string[] = [];
const ip = contentIndexProblem(index, manifest);
if (ip) problems.push(`index: ${ip}`);
const ids = new Set<string>();
for (const c of clips) {
  const cp = contentClipProblem(c, index.videos);
  if (cp) problems.push(`clip ${c.id}: ${cp}`);
  if (ids.has(c.id)) problems.push(`clip ${c.id}: duplicate`);
  ids.add(c.id);
}
const dp = contentDictProblem(JSON.parse(texts.get("dict.json")!));
if (dp) problems.push(dp);
for (const n of notes) { const np = contentNotesProblem(JSON.parse(texts.get(n)!)); if (np) problems.push(`${n}: ${np}`); }
if (problems.length) die(`pack failed the app checks:\n  ${problems.slice(0, 20).join("\n  ")}`);

const mb = (n: number) => `${(n / 1e6).toFixed(2)} MB`;
const raw = files.reduce((s, f) => s + f.bytes, 0), gz = files.reduce((s, f) => s + f.gz.byteLength, 0);
console.log(`pack v${version}: ${clips.length} clips, ${Object.keys(index.videos).length} videos, notes for ${withNotes}, ${files.length} files, ${mb(raw)} raw → ${mb(gz)} download`);
for (const f of files) console.log(`  ${f.name.padEnd(16)} ${mb(f.bytes).padStart(9)} → ${mb(f.gz.byteLength).padStart(8)}  ${f.sha256.slice(0, 12)}`);

if (!flag("--upload") && !flag("--activate")) { console.log("dry run — add --upload or --activate"); process.exit(0); }

const manifestPath = `packs/v${version}.json`;
const manifestUrl = publicUrl(manifestPath);
const existing = await fetch(manifestUrl, { cache: "no-store" });
const manifestText = JSON.stringify(manifestJson);
if (existing.ok) {
  const old = (await existing.json()) as { files: ContentPackFile[] };
  const same = JSON.stringify(old.files) === JSON.stringify(manifestJson.files);
  if (!same && !flag("--force")) die(`${manifestPath} already exists with different files; bump the version (or --force)`);
}

let uploaded = 0;
for (const f of files) {
  const objectPath = `objects/${f.sha256}.json.gz`;
  const head = await fetch(publicUrl(objectPath), { method: "HEAD" });
  if (head.ok) continue;
  await upload(key, objectPath, f.gz, "application/gzip", "max-age=31536000", false);
  uploaded++;
}
await upload(key, manifestPath, Buffer.from(manifestText), "application/json", "max-age=60", true);
console.log(`✓ uploaded ${uploaded} new file(s) (${files.length - uploaded} already there) + ${manifestPath}`);

// Read it back exactly as an app would.
const back = await fetch(manifestUrl, { cache: "no-store" });
const checked = contentPackManifest(back.ok ? await back.json() : null, version) ?? die("published manifest does not read back");
for (const f of checked.files) {
  const r = await fetch(contentObjectUrl(manifestUrl, f.sha256), { cache: "no-store" });
  const buf = Buffer.from(await r.arrayBuffer());
  const plain = buf[0] === 0x1f && buf[1] === 0x8b ? Bun.gunzipSync(buf) : buf;
  if (!r.ok || plain.byteLength !== f.bytes || createHash("sha256").update(plain).digest("hex") !== f.sha256) die(`${f.name} does not read back intact`);
}
console.log("✓ every file reads back intact");

if (flag("--activate")) {
  const live = await readSetting(key);
  if (live.pack_version != null && version < live.pack_version && !flag("--force")) die(`live pack is v${live.pack_version}; use --force to go back to v${version}`);
  await writeSetting(key, { pack_version: version, pack_url: manifestUrl, updates_enabled: true });
  console.log(`✓ live: apps with a bundled library older than v${version} download it in the background and use it from their next start`);
} else {
  console.log(`not live yet — run again with --activate (manifest: ${manifestUrl})`);
}
