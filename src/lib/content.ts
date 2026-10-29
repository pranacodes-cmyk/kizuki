// Loads the shared clip library + dictionary: the bundled files (public/data, same files bundled
// in Flutter mobile/assets/data, written by scripts/content/build.ts — never hand-edit the JSON),
// or a newer server pack once it was downloaded and verified (./content-pack.ts).
//
// The library is written in English. For another app language the same library is shown through
// a translation overlay (./locale-pack.ts): the starter clips' translations ship in the app
// (public/data/locale/<lang>.json), the full pack downloads for learners with access. A clip,
// word or explanation without a translation made for exactly it stays in English.
import { dropPack, hasStoredPack, packText, storedPack, syncContentPack, type ActivePack } from "./content-pack";
import { getLang } from "./i18n-core";
import { dropLocalePack, localeText, storedLocalePack, type LocalePack } from "./locale-pack";
import {
  clipLocaleSig, localeNoteShard, localizeClip, localizeEntry, localizeNotes, notesShard,
  type LangCode, type LocaleEntry, type LocaleLine, type LocaleNote, type RankClip, type StarterClip,
} from "./logic";

export type Word = {
  s: string; r: string; ro: string; b: string; p: string; d: string | null;
  f?: [string, string | null][]; t0: number; t1: number;
};
export type Line = { start: number; end: number; en: string; sp: string; ja: string; words: Word[] };
export type Clip = {
  id: string; videoId: string; title: string; level: string; start: number; end: number;
  topics: string[]; grammar: string[]; quality: number; lines: Line[];
  /** Audio-first video (a podcast): the picture is one still image, often a channel banner. */
  still?: boolean;
};
export type Video = { title: string; channel: string; channelUrl: string };
export type DictEntry = { w: string; r: string; j: number | null; c: boolean; m: { pos: string[]; g: string }[]; ex: { ja: string; en: string }[] };
export type ClipNotes = { w: Record<string, { m: string; n: string }>; l: Record<string, { lit: string; tip: string }> };

export type Content = {
  videos: Record<string, Video>;
  clips: Clip[];
  byId: Record<string, Clip>;
  dict: Record<string, DictEntry>;
  /** Curated first clips for everyone, in order (scripts/content/pick_starter.py). */
  starter: StarterClip[];
  /** Language the clips and dictionary are shown in. */
  lang: LangCode;
};

type Index = { version?: number; videos: Record<string, Video>; parts: string[]; starter?: string[] };
type Source = { index: Index; clips: Clip[]; dict: Record<string, DictEntry> };

const fetchJson = (u: string) => fetch(u).then((r) => { if (!r.ok) throw new Error(`content ${r.status}`); return r.json(); });

let contentPromise: Promise<Content> | null = null;
let base: Content | null = null;
let loaded: Content | null = null;
const notesCache = new Map<string, Promise<ClipNotes>>();
/** The verified server pack this load reads, or null for the bundled library. */
let activePack: ActivePack | null = null;
let syncScheduled = false;

async function fromPack(pack: ActivePack): Promise<Source> {
  const index = JSON.parse(await packText(pack, "content.json")) as Index;
  const [parts, dict] = await Promise.all([
    Promise.all(index.parts.map((p) => packText(pack, p).then((t) => JSON.parse(t) as { clips: Clip[] }))),
    packText(pack, "dict.json").then((t) => JSON.parse(t) as Record<string, DictEntry>),
  ]);
  return { index, clips: parts.flatMap((x) => x.clips), dict };
}

/** Checks for a newer pack once per page load, after start-up work has settled. */
function scheduleSync(bundledVersion: number) {
  if (syncScheduled || typeof window === "undefined") return;
  syncScheduled = true;
  window.setTimeout(() => { void syncContentPack(bundledVersion).then((o) => console.info(`[kizuki] content pack ${o}`)); }, 8000);
}

/** The library in English (as built). */
function loadBase(): Promise<Content> {
  if (!contentPromise) {
    contentPromise = (async () => {
      const packed = hasStoredPack();
      const indexP = fetchJson("/data/content.json") as Promise<Index>;
      // Without a downloaded pack the bundled dictionary loads alongside the index, as before.
      const dictP = packed ? null : (fetchJson("/data/dict.json") as Promise<Record<string, DictEntry>>);
      const index = await indexP;
      const bundledVersion = Number.isInteger(index.version) ? index.version! : 1;
      let src: Source | null = null;
      const pack = packed ? storedPack(bundledVersion) : null;
      if (pack) {
        try {
          src = await fromPack(pack);
          activePack = pack;
        } catch {
          // A pack that does not load is dropped for good; the bundle below takes over.
          activePack = null;
          dropPack();
        }
      } else if (packed) dropPack();
      if (!src) {
        // Clips are sharded (see scripts/content/build.ts); load every part in parallel.
        const [parts, dict] = await Promise.all([
          Promise.all(index.parts.map((p) => fetchJson(`/data/${p}`) as Promise<{ clips: Clip[] }>)),
          dictP ?? (fetchJson("/data/dict.json") as Promise<Record<string, DictEntry>>),
        ]);
        src = { index, clips: parts.flatMap((x) => x.clips), dict };
      }
      const byId: Record<string, Clip> = Object.fromEntries(src.clips.map((x) => [x.id, x]));
      const starter = (src.index.starter ?? []).filter((id) => byId[id]).map((id) => ({ id, level: byId[id]!.level }));
      base = { videos: src.index.videos, clips: src.clips, byId, dict: src.dict, starter, lang: "en" };
      scheduleSync(bundledVersion);
      return base;
    })().catch((e) => { contentPromise = null; throw e; });
  }
  return contentPromise;
}

type Overlay = {
  lines: Record<string, LocaleLine>;
  dict: Record<string, LocaleEntry>;
  grammar: Record<string, string>;
  /** Starter explanations bundled in the app. */
  notes: Record<string, LocaleNote>;
  pack: LocalePack | null;
};
const overlays = new Map<LangCode, Promise<Overlay>>();
const localized = new Map<LangCode, Promise<Content>>();

async function bundledOverlay(lang: LangCode): Promise<Omit<Overlay, "pack">> {
  try {
    const r = await fetch(`/data/locale/${lang}.json`);
    if (r.ok) {
      const j = (await r.json()) as Partial<Omit<Overlay, "pack">>;
      return { lines: j.lines ?? {}, dict: j.dict ?? {}, grammar: j.grammar ?? {}, notes: j.notes ?? {} };
    }
  } catch { /* offline or missing: English */ }
  return { lines: {}, dict: {}, grammar: {}, notes: {} };
}

function loadOverlay(lang: LangCode): Promise<Overlay> {
  let p = overlays.get(lang);
  if (!p) {
    p = (async () => {
      const bundled = await bundledOverlay(lang);
      const pack = storedLocalePack(lang);
      if (!pack) return { ...bundled, pack: null };
      try {
        const [lines, dict, grammar] = await Promise.all(["lines.json", "dict.json", "grammar.json"].map((n) => localeText(pack, n).then((t) => JSON.parse(t))));
        // The pack is newer than the app; the bundled starter translations fill anything it lacks.
        return { lines: { ...bundled.lines, ...lines }, dict: { ...bundled.dict, ...dict }, grammar: { ...bundled.grammar, ...grammar }, notes: bundled.notes, pack };
      } catch {
        // A pack that does not load (cache cleared, file changed) is dropped; it downloads again.
        dropLocalePack(lang);
        return { ...bundled, pack: null };
      }
    })();
    overlays.set(lang, p);
  }
  return p;
}

/** The library in `lang` (default: the app language). English is the library itself. */
export function loadContent(lang: LangCode = getLang()): Promise<Content> {
  let p = localized.get(lang);
  if (!p) {
    p = (async () => {
      const b = await loadBase();
      if (lang === "en") return b;
      const o = await loadOverlay(lang);
      const grammar = Object.keys(o.grammar).length ? o.grammar : null;
      const clips = b.clips.map((c) => localizeClip(c, o.lines[c.id], grammar));
      const dict: Record<string, DictEntry> = {};
      for (const [id, e] of Object.entries(b.dict)) dict[id] = localizeEntry(e, o.dict[id]);
      return { ...b, clips, byId: Object.fromEntries(clips.map((x) => [x.id, x])), dict, lang };
    })().catch((e) => { localized.delete(lang); throw e; });
    localized.set(lang, p);
  }
  return p.then((c) => {
    if (lang === getLang()) loaded = c;
    return c;
  });
}

export const getContent = () => loaded;

const EMPTY_NOTES: ClipNotes = { w: {}, l: {} };
/** Pack notes files; the two most recent stay in memory. */
const shards = new Map<string, Promise<Record<string, ClipNotes> | null>>();

function packShard(pack: ActivePack, name: string): Promise<Record<string, ClipNotes> | null> {
  const hit = shards.get(name);
  if (hit) { shards.delete(name); shards.set(name, hit); return hit; }
  const p = packText(pack, name).then((t) => JSON.parse(t) as Record<string, ClipNotes>).catch(() => null);
  shards.set(name, p);
  while (shards.size > 2) shards.delete(shards.keys().next().value!);
  return p;
}

const bundledNotes = (clipId: string): Promise<ClipNotes> =>
  fetch(`/data/explain/${clipId}.json`).then((r) => (r.ok ? r.json() : EMPTY_NOTES)).catch(() => EMPTY_NOTES);

/** Explanations as built (English). */
function baseNotes(clipId: string): Promise<ClipNotes> {
  let p = notesCache.get(clipId);
  if (!p) {
    const pack = activePack;
    const names = pack?.manifest.notes ?? [];
    p = pack && names.length
      ? packShard(pack, names[notesShard(clipId, names.length)]!).then((s) => s?.[clipId] ?? bundledNotes(clipId))
      : bundledNotes(clipId);
    notesCache.set(clipId, p);
  }
  return p;
}

/** A language pack's notes file; the two most recent stay in memory. */
const localeShards = new Map<string, Promise<Record<string, LocaleNote> | null>>();

function localeShard(pack: LocalePack, clipId: string): Promise<Record<string, LocaleNote> | null> {
  const name = `notes-${String(localeNoteShard(clipId)).padStart(2, "0")}.json`;
  const key = `${pack.lang}:${pack.version}:${name}`;
  const hit = localeShards.get(key);
  if (hit) { localeShards.delete(key); localeShards.set(key, hit); return hit; }
  const p = localeText(pack, name).then((t) => JSON.parse(t) as Record<string, LocaleNote>).catch(() => null);
  localeShards.set(key, p);
  while (localeShards.size > 2) localeShards.delete(localeShards.keys().next().value!);
  return p;
}

/** A clip's explanations in the app language (English where no translation was made for it). */
export async function loadNotes(clipId: string): Promise<ClipNotes> {
  const lang = getLang();
  const notes = await baseNotes(clipId);
  if (lang === "en") return notes;
  const clip = base?.byId[clipId];
  if (!clip) return notes;
  const o = await loadOverlay(lang);
  const fromPack = o.pack ? (await localeShard(o.pack, clipId))?.[clipId] : undefined;
  return localizeNotes(notes, fromPack ?? o.notes[clipId], clipLocaleSig(clip.lines));
}

export const thumbOf = (videoId: string) => `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
export const glossOf = (e?: DictEntry) => (e?.m[0]?.g.split(";")[0]?.trim() ?? "");
export const rankClips = (c: Content): RankClip[] => c.clips.map((x) => ({ id: x.id, videoId: x.videoId, level: x.level, topics: x.topics, quality: x.quality, still: x.still === true }));

/** All grammar patterns with how many clips use them, most common first. */
export function grammarIndex(c: Content): [string, number][] {
  const m = new Map<string, number>();
  for (const clip of c.clips) for (const g of clip.grammar) {
    const key = (g.split("—")[0] ?? g).trim();
    m.set(key, (m.get(key) ?? 0) + 1);
  }
  return [...m.entries()].sort((a, b) => (b[1] !== a[1] ? b[1] - a[1] : a[0] < b[0] ? -1 : 1));
}
