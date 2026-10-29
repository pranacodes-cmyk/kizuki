// Language packs: the whole clip library, dictionary and explanations in the learner's language.
// Mirrors mobile/lib/services/locale_pack.dart (shared rules in logic.ts / logic.dart).
//
// English is the library itself and the curated starter clips come translated inside the app
// (public/data/locale/<lang>.json), so nothing has to download before learning starts. The rest
// downloads in the background only for a non-English language once the learner has trial or
// Premium access (localePackDue). The public content_settings.locale_packs row names each
// language's manifest on two mirrors; every file is checked (sha-256 + size) as it arrives, the
// whole pack is then parsed with the shared rules (re-reading every file, so it is checked twice),
// and only then is it recorded — used from the next load. Any failure keeps what the learner has
// (English + starter translations) and retries later with a growing wait. Pack files are
// content-addressed, so the browser's HTTP cache keeps them; localStorage keeps only the
// verified manifests.
import { BACKEND_PUBLISHABLE_KEY, BACKEND_URL } from "./backend-config";
import {
  contentObjectUrl, localeFileProblem, localePackDue, localePackManifest, localePackPointer, localeRetryDelayMs,
  type LangCode, type LocalePackManifest,
} from "./logic";

const KEY = "locale-pack-v1";
export type LocalePack = { lang: LangCode; version: number; url: string; manifest: LocalePackManifest };

function readAll(): Record<string, unknown> {
  try {
    const j: unknown = JSON.parse(localStorage.getItem(KEY) ?? "{}");
    return j && typeof j === "object" && !Array.isArray(j) ? (j as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

function writeAll(all: Record<string, unknown>) {
  try { localStorage.setItem(KEY, JSON.stringify(all)); } catch { /* storage full or blocked: stays on English */ }
}

/** The verified pack recorded for `lang`, or null. */
export function storedLocalePack(lang: LangCode): LocalePack | null {
  const j = readAll()[lang];
  if (!j || typeof j !== "object") return null;
  const { version, url, manifest } = j as { version?: unknown; url?: unknown; manifest?: unknown };
  if (typeof version !== "number" || typeof url !== "string" || !url.startsWith("https://")) return null;
  const m = localePackManifest(manifest, lang, version);
  return m ? { lang, version, url, manifest: m } : null;
}

/** Stops using `lang`'s downloaded pack from the next load (starter translations + English). */
export function dropLocalePack(lang: LangCode) {
  const all = readAll();
  if (!(lang in all)) return;
  delete all[lang];
  writeAll(all);
}

export class LocaleChecksumError extends Error {
  constructor(name: string) { super(`language pack checksum: ${name}`); }
}

const hex = (b: ArrayBuffer) => Array.from(new Uint8Array(b), (x) => x.toString(16).padStart(2, "0")).join("");

async function gunzip(buf: ArrayBuffer): Promise<ArrayBuffer> {
  const head = new Uint8Array(buf, 0, Math.min(2, buf.byteLength));
  if (head[0] !== 0x1f || head[1] !== 0x8b) return buf; // already plain (served decoded)
  return new Response(new Blob([buf]).stream().pipeThrough(new DecompressionStream("gzip"))).arrayBuffer();
}

/** One pack file as text, checked against its manifest every time it is read. */
export async function localeText(p: LocalePack, name: string, timeoutMs?: number): Promise<string> {
  const f = p.manifest.files.find((x) => x.name === name);
  if (!f) throw new Error(`language pack has no ${name}`);
  const r = await fetch(contentObjectUrl(p.url, f.sha256), { cache: "force-cache", signal: timeoutMs ? AbortSignal.timeout(timeoutMs) : null });
  if (!r.ok) throw new Error(`language pack ${r.status}`);
  const buf = await gunzip(await r.arrayBuffer());
  if (buf.byteLength !== f.bytes || hex(await crypto.subtle.digest("SHA-256", buf)) !== f.sha256) throw new LocaleChecksumError(name);
  return new TextDecoder().decode(buf);
}

/** Parses every file of a pack with the shared rules, one at a time. Null when usable. */
export async function checkLocalePack(p: LocalePack): Promise<string | null> {
  for (const f of p.manifest.files) {
    let j: unknown;
    try { j = JSON.parse(await localeText(p, f.name)); } catch (e) { if (e instanceof LocaleChecksumError) throw e; return "parse"; }
    const problem = localeFileProblem(f.name, j);
    if (problem) return problem;
  }
  return null;
}

async function pointerRow(): Promise<unknown | undefined> {
  try {
    const res = await fetch(`${BACKEND_URL}/rest/v1/content_settings?id=eq.1&select=locale_packs`, {
      headers: { apikey: BACKEND_PUBLISHABLE_KEY },
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok) return undefined;
    const rows: unknown = await res.json();
    if (!Array.isArray(rows) || !rows[0] || typeof rows[0] !== "object") return undefined;
    return (rows[0] as { locale_packs?: unknown }).locale_packs ?? {};
  } catch {
    return undefined;
  }
}

/** One mirror: manifest, then every file (checked on arrival), then the full parse check. */
async function fromMirror(lang: LangCode, version: number, url: string): Promise<LocalePack | string> {
  let manifest: LocalePackManifest | null;
  try {
    const r = await fetch(url, { cache: "no-cache", signal: AbortSignal.timeout(15000) });
    manifest = r.ok ? localePackManifest(await r.json(), lang, version) : null;
  } catch {
    return "failed:manifest";
  }
  if (!manifest) return "failed:manifest";
  const pack: LocalePack = { lang, version, url, manifest };
  try {
    for (const f of manifest.files) await localeText(pack, f.name, 90000);
    const problem = await checkLocalePack(pack);
    return problem ? `failed:${problem}` : pack;
  } catch (e) {
    return e instanceof LocaleChecksumError ? "failed:checksum" : "failed:download";
  }
}

/** One check for `lang`: 'skip' | 'offline' | 'none' | 'keep' | 'activated' | 'failed:<reason>'. */
export async function syncLocalePack(lang: LangCode, hasAccess: boolean): Promise<string> {
  if (lang === "en" || !hasAccess) return "skip";
  const row = await pointerRow();
  if (row === undefined) return "offline";
  const pointer = localePackPointer(row, lang);
  if (!pointer) {
    dropLocalePack(lang); // the founder switched this language off: starter translations + English
    return "none";
  }
  const installed = storedLocalePack(lang)?.version ?? 0;
  if (!localePackDue(lang, hasAccess, installed, pointer.version)) return "keep";
  setDownloading(lang);
  try {
    let outcome = "failed:download";
    for (const url of pointer.urls) {
      const got = await fromMirror(lang, pointer.version, url);
      if (typeof got === "string") { outcome = got; continue; }
      // Stored in manifest form so the next load re-validates it with the same rule.
      writeAll({ ...readAll(), [lang]: { version: got.version, url: got.url, manifest: got.manifest } });
      return "activated";
    }
    return outcome;
  } finally {
    setDownloading(null);
  }
}

let downloading: LangCode | null = null;
const stateListeners = new Set<() => void>();
function setDownloading(lang: LangCode | null) {
  downloading = lang;
  for (const l of stateListeners) l();
}

export function subscribeLocalePack(fn: () => void) {
  stateListeners.add(fn);
  return () => { stateListeners.delete(fn); };
}

/** Settings line for `lang`: 'ready' (full translation on this device), 'downloading' or
 * 'starter' (the bundled first-clip translations; the rest in English for now). */
export function localePackState(lang: LangCode): "ready" | "downloading" | "starter" {
  if (lang === "en") return "starter";
  if (downloading === lang) return "downloading";
  return storedLocalePack(lang) ? "ready" : "starter";
}

let running: { lang: LangCode; done: Promise<void> } | null = null;
let timer: ReturnType<typeof setTimeout> | null = null;
let pending: LangCode | null = null;
let failures = 0;
let settled = new Set<LangCode>();

/** Background check for the current language; failures retry with a growing wait (5 s → 30 min). */
export function scheduleLocaleSync(lang: LangCode, hasAccess: boolean, delayMs = 4000) {
  if (typeof window === "undefined" || lang === "en" || !hasAccess || settled.has(lang)) return;
  if (running?.lang === lang) return;
  if (timer && pending === lang) return; // already waiting for this language
  if (timer) clearTimeout(timer);
  pending = lang;
  timer = setTimeout(() => {
    timer = null;
    const done = syncLocalePack(lang, hasAccess).then((o) => {
      console.info(`[kizuki] language pack ${lang} ${o}`);
      if (o.startsWith("failed") || o === "offline") {
        running = null;
        scheduleLocaleSync(lang, hasAccess, localeRetryDelayMs(failures++));
        return;
      }
      failures = 0;
      settled = new Set([...settled, lang]);
      running = null;
    });
    running = { lang, done };
  }, delayMs);
}
