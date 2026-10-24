import { supabase } from '@/integrations/supabase/client';
import { founderVideoEnabled } from './logic';

let enabled = true;
let pending: Promise<boolean> | null = null;
export function refreshOnboardingSettings(): Promise<boolean> {
  if (pending) return pending;
  pending = (async () => {
    try {
      const cached = localStorage.getItem('founder-video-enabled');
      if (cached === 'true' || cached === 'false') enabled = cached === 'true';
      const { data, error } = await supabase.from('onboarding_settings').select('founder_video_enabled').eq('id', 1).abortSignal(AbortSignal.timeout(2000)).maybeSingle();
      if (!error && data) {
        enabled = founderVideoEnabled(data.founder_video_enabled, enabled);
        localStorage.setItem('founder-video-enabled', String(enabled));
      }
    } catch { /* Offline: retain last valid setting. */ }
    return enabled;
  })().finally(() => { pending = null; });
  return pending;
}

export const cachedFounderEnabled = () => enabled;