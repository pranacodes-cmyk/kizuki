import { type Content } from './content';
import { widgetWords, type WidgetWord } from './logic';
import { glossIn, type PersistedState } from './store';

export function widgetPublicWords(c: Content): WidgetWord[] {
  const locations = new Map<string, string>();
  for (const clip of c.clips) for (const line of clip.lines) for (const w of line.words) {
    if (w.d && !locations.has(w.d)) locations.set(w.d, clip.id);
  }
  return Object.entries(c.dict).filter(([key, e]) => e.c && e.j !== null && locations.has(key)).map(([key, e]) => ({
    key, word: e.w, reading: e.r, meaning: e.m[0]?.g.split(';')[0]?.trim() ?? '', jlpt: e.j ?? 5, clipId: locations.get(key) ?? '', example: e.ex[0]?.ja ?? '', due: 0, status: 'public',
  }));
}
export function widgetPreviewWords(s: PersistedState, c: Content, now: number): WidgetWord[] {
  return widgetWords(widgetPublicWords(c), Object.values(s.words).map((w) => ({ key: w.key, word: w.word, reading: w.reading, meaning: glossIn(w, c), clipId: w.clipId, example: '', jlpt: w.jlpt ?? 5, due: w.card.due, status: w.status })), s.profile.jlpt, s.settings.widgetSaved === true, now);
}