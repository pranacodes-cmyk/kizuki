import { loadContent, thumbOf } from './content';
import { loadYouTubeApi } from './youtube';

let pending: Promise<void> | null = null;
export function preloadTrial(): Promise<void> {
  return pending ??= (async () => {
    const bootstrap = loadYouTubeApi().catch(() => {});
    const content = await loadContent();
    const first = content.starter[0];
    const clip = first ? content.byId[first.id] : null;
    if (!clip) return;
    const image = new Image();
    image.src = thumbOf(clip.videoId);
    const { loadNotes } = await import('./content');
    await loadNotes(clip.id);
    await bootstrap;
  })().catch(() => { pending = null; });
}