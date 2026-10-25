import { supabase } from '@/lib/backend';
import { founderVideoEnabled, founderVideoUrl } from './logic';

let enabled = true;
let pending: Promise<boolean> | null = null;
export function refreshOnboardingSettings(): Promise<boolean> {
  if (pending) return pending;
  pending = (async () => {
    try {
      const cached = localStorage.getItem('founder-video-enabled');
      if (cached === 'true' || cached === 'false') enabled = cached === 'true';
      videoUrl = founderVideoUrl(localStorage.getItem('founder-video-url'));
      const { data, error } = await supabase.from('onboarding_settings').select('founder_video_enabled,founder_video_url').eq('id', 1).abortSignal(AbortSignal.timeout(2000)).maybeSingle();
      if (!error && data) {
        enabled = founderVideoEnabled(data.founder_video_enabled, enabled);
        localStorage.setItem('founder-video-enabled', String(enabled));
        // The server's value wins, including a cleared one (back to the bundled clip).
        videoUrl = founderVideoUrl(data.founder_video_url);
        if (videoUrl) localStorage.setItem('founder-video-url', videoUrl);
        else localStorage.removeItem('founder-video-url');
      }
    } catch { /* Offline: retain last valid setting. */ }
    return enabled;
  })().finally(() => { pending = null; });
  return pending;
}

export const cachedFounderEnabled = () => enabled;

let videoUrl: string | null = null;

/** Server-sent founder video override (null = play the bundled clip). Reads the cached copy
 * instantly, so the founder screen picks it up on its first render. */
export function cachedFounderVideoUrl(): string | null {
  if (videoUrl) return videoUrl;
  try { videoUrl = founderVideoUrl(localStorage.getItem("founder-video-url")); } catch { /* SSR */ }
  return videoUrl;
}

/** Warms the server-sent video a few screens early (browser HTTP cache), so the founder slide
 * plays it without a stall. Mirrors FounderVideo.prefetch in mobile/lib/services/founder_video.dart. */
export function prefetchFounderVideo(): void {
  void refreshOnboardingSettings().then(() => {
    const u = videoUrl;
    if (!u) return;
    fetch(u, { cache: "force-cache" }).then((r) => r.arrayBuffer()).catch(() => { /* media loads work without CORS anyway */ });
  });
}
