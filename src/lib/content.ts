// Loads the shared clip library + dictionary (public/data, same files bundled in Flutter
// mobile/assets/data). Written by scripts/content/build.ts — never hand-edit the JSON.
import type { RankClip } from "./logic";

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
};

let contentPromise: Promise<Content> | null = null;
let loaded: Content | null = null;
const notesCache = new Map<string, Promise<ClipNotes>>();

export function loadContent(): Promise<Content> {
  if (!contentPromise) {
    contentPromise = Promise.all([
      fetch("/data/content.json").then((r) => { if (!r.ok) throw new Error(`content ${r.status}`); return r.json(); }),
      fetch("/data/dict.json").then((r) => { if (!r.ok) throw new Error(`dict ${r.status}`); return r.json(); }),
    ]).then(([c, d]) => {
      loaded = { videos: c.videos, clips: c.clips, byId: Object.fromEntries(c.clips.map((x: Clip) => [x.id, x])), dict: d };
      return loaded;
    }).catch((e) => { contentPromise = null; throw e; });
  }
  return contentPromise;
}

export const getContent = () => loaded;

export function loadNotes(clipId: string): Promise<ClipNotes> {
  let p = notesCache.get(clipId);
  if (!p) {
    p = fetch(`/data/explain/${clipId}.json`).then((r) => (r.ok ? r.json() : { w: {}, l: {} })).catch(() => ({ w: {}, l: {} }));
    notesCache.set(clipId, p);
  }
  return p;
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
