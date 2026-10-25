// Server-sent clip library: more clips without an app update. Mirrors
// mobile/lib/services/content_pack.dart. The bundled library (public/data) is always the
// default; the public `content_settings` row names a newer pack, which is fetched in the
// background, every file is checked (sha-256 + size) and parsed with the shared rules, and
// only then it is used — from the next load. The off switch, a cleared link, a failed check or
// a pack not newer than the bundle all mean the bundle. Pack files are content-addressed, so
// the browser's HTTP cache keeps them; localStorage keeps only the verified manifest.
import { BACKEND_PUBLISHABLE_KEY, BACKEND_URL } from "./backend-config";
import {
  contentClipProblem, contentDictProblem, contentIndexProblem, contentNotesProblem, contentObjectUrl, contentPackAction,
  contentPackManifest, CONTENT_PACK_FORMAT, founderVideoUrl, type ContentPackManifest,
} from "./logic";

const KEY = "content-pack-v1";
export type ActivePack = { version: number; url: string; manifest: ContentPackManifest };

/** The verified pack to load instead of the bundle, or null. */
export function storedPack(bundledVersion: number): ActivePack | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const j = JSON.parse(raw);
    if (!j || typeof j !== "object" || !Number.isInteger(j.version) || j.version <= bundledVersion || founderVideoUrl(j.url) === null) return null;
    const manifest = contentPackManifest(j.manifest, j.version);
    return manifest ? { version: j.version, url: j.url, manifest } : null;
  } catch {
    return null;
  }
}

export function hasStoredPack(): boolean {
  try { return localStorage.getItem(KEY) !== null; } catch { return false; }
}

/** Stops using the downloaded pack from the next load (the bundle takes over). */
export function dropPack(): void {
  try { localStorage.removeItem(KEY); } catch { /* storage unavailable */ }
}

const hex = (b: ArrayBuffer) => Array.from(new Uint8Array(b), (x) => x.toString(16).padStart(2, "0")).join("");

async function gunzip(buf: ArrayBuffer): Promise<ArrayBuffer> {
  const head = new Uint8Array(buf, 0, Math.min(2, buf.byteLength));
  if (head[0] !== 0x1f || head[1] !== 0x8b) return buf; // already plain (served decoded)
  const stream = new Blob([buf]).stream().pipeThrough(new DecompressionStream("gzip"));
  return new Response(stream).arrayBuffer();
}

/** One verified pack file as text (gzip on the server; checksum and size are of the plain JSON). */
export async function packText(p: ActivePack, name: string): Promise<string> {
  const f = p.manifest.files.find((x) => x.name === name);
  if (!f) throw new Error(`pack has no ${name}`);
  const r = await fetch(contentObjectUrl(p.url, f.sha256), { cache: "force-cache" });
  if (!r.ok) throw new Error(`pack ${r.status}`);
  const buf = await gunzip(await r.arrayBuffer());
  if (buf.byteLength !== f.bytes || hex(await crypto.subtle.digest("SHA-256", buf)) !== f.sha256) throw new PackChecksumError();
  return new TextDecoder().decode(buf);
}

class PackChecksumError extends Error {
  constructor() { super("pack checksum"); }
}

const parse = (t: string): unknown => JSON.parse(t);

/** Parses every file of a pack with the shared rules, one at a time. Null when usable. */
export async function checkPack(p: ActivePack): Promise<string | null> {
  let index: unknown;
  try { index = parse(await packText(p, "content.json")); } catch (e) { if (e instanceof PackChecksumError) throw e; return "index"; }
  const problem = contentIndexProblem(index, p.manifest);
  if (problem) return problem;
  const { videos, parts } = index as { videos: Record<string, unknown>; parts: string[] };
  const ids = new Set<string>();
  for (const part of parts) {
    let j: unknown;
    try { j = parse(await packText(p, part)); } catch (e) { if (e instanceof PackChecksumError) throw e; return "clip"; }
    const clips = (j as { clips?: unknown } | null)?.clips;
    if (!Array.isArray(clips)) return "part";
    for (const c of clips) {
      const cp = contentClipProblem(c, videos);
      if (cp) return cp;
      const id = (c as { id: string }).id;
      if (ids.has(id)) return "duplicate";
      ids.add(id);
    }
  }
  if (ids.size === 0) return "clips";
  try {
    const dp = contentDictProblem(parse(await packText(p, "dict.json")));
    if (dp) return dp;
  } catch (e) { if (e instanceof PackChecksumError) throw e; return "dict"; }
  for (const n of p.manifest.notes) {
    try {
      const np = contentNotesProblem(parse(await packText(p, n)));
      if (np) return np;
    } catch (e) { if (e instanceof PackChecksumError) throw e; return "notes"; }
  }
  return null;
}

let syncing: Promise<string> | null = null;

/** One update check against the server row: 'offline' | 'keep' | 'bundled' | 'activated' | 'failed:<reason>'. */
export function syncContentPack(bundledVersion: number): Promise<string> {
  return (syncing ??= runSync(bundledVersion).finally(() => { syncing = null; }));
}

async function runSync(bundledVersion: number): Promise<string> {
  let row: { updates_enabled?: unknown; pack_version?: unknown; pack_url?: unknown };
  try {
    const res = await fetch(`${BACKEND_URL}/rest/v1/content_settings?id=eq.1&select=updates_enabled,pack_version,pack_url`, {
      headers: { apikey: BACKEND_PUBLISHABLE_KEY },
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok) return "offline";
    const rows: unknown = await res.json();
    if (!Array.isArray(rows) || !rows[0] || typeof rows[0] !== "object") return "offline";
    row = rows[0] as typeof row;
  } catch {
    return "offline";
  }
  const current = storedPack(bundledVersion);
  const action = contentPackAction(row.updates_enabled, row.pack_version, row.pack_url, bundledVersion, current?.version ?? null);
  if (action === "keep") return "keep";
  if (action === "bundled") { dropPack(); return "bundled"; }
  const url = founderVideoUrl(row.pack_url)!;
  const version = row.pack_version as number;
  try {
    const r = await fetch(url, { cache: "no-cache", signal: AbortSignal.timeout(15000) });
    if (!r.ok) return "failed:manifest";
    const manifest = contentPackManifest(await r.json(), version);
    if (!manifest) return "failed:manifest";
    const pack: ActivePack = { version, url, manifest };
    const problem = await checkPack(pack);
    if (problem) return `failed:${problem}`;
    // Stored in manifest form so the next load re-validates it with the same rule.
    localStorage.setItem(KEY, JSON.stringify({ version, url, manifest: { format: CONTENT_PACK_FORMAT, ...manifest } }));
    return "activated";
  } catch (e) {
    return e instanceof PackChecksumError ? "failed:checksum" : "failed:download";
  }
}
