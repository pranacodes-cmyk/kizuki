import { supabase } from '@/lib/backend';
import { founderVideoEnabled, founderVideoUrl, trialDays as trialDaysRule, DEFAULT_TRIAL_DAYS } from './logic';

let enabled = true;
let trialDayCount = DEFAULT_TRIAL_DAYS;
/** Server switch for the store-review email sign-in; off = the form is not rendered at all. */
let reviewSignIn = false;
let pending: Promise<boolean> | null = null;
export function refreshOnboardingSettings(): Promise<boolean> {
  if (pending) return pending;
  pending = (async () => {
    try {
      const cached = localStorage.getItem('founder-video-enabled');
      if (cached === 'true' || cached === 'false') enabled = cached === 'true';
      videoUrl = founderVideoUrl(localStorage.getItem('founder-video-url'));
      trialDayCount = parseTrialDays(localStorage.getItem('trial-days'), trialDayCount);
      reviewSignIn = localStorage.getItem('review-sign-in') === 'true';
      const { data, error } = await supabase.from('onboarding_settings').select('founder_video_enabled,founder_video_url,trial_enabled,trial_days,review_sign_in').eq('id', 1).abortSignal(AbortSignal.timeout(2000)).maybeSingle();
      if (!error && data) {
        enabled = founderVideoEnabled(data.founder_video_enabled, enabled);
        localStorage.setItem('founder-video-enabled', String(enabled));
        // The server's value wins, including a cleared one (back to the bundled clip).
        videoUrl = founderVideoUrl(data.founder_video_url);
        if (videoUrl) localStorage.setItem('founder-video-url', videoUrl);
        else localStorage.removeItem('founder-video-url');
        trialDayCount = trialDaysRule(data.trial_enabled, data.trial_days, trialDayCount);
        localStorage.setItem('trial-days', String(trialDayCount));
        // A missing column or value hides the review form (never shown by accident).
        reviewSignIn = data.review_sign_in === true;
        localStorage.setItem('review-sign-in', String(reviewSignIn));
      }
    } catch { /* Offline: retain last valid setting. */ }
    return enabled;
  })().finally(() => { pending = null; });
  return pending;
}

function parseTrialDays(raw: string | null, cached: number): number {
  const n = raw === null ? NaN : Number(raw);
  return Number.isInteger(n) && n >= 0 && n <= 14 ? n : cached;
}

export const cachedFounderEnabled = () => enabled;
export const cachedReviewSignIn = () => reviewSignIn;

/** Server trial experiment, last valid value: 0 = direct paywall without trial wording. */
export const cachedTrialDays = () => trialDayCount;

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
