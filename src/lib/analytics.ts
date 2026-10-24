import posthog from 'posthog-js';

export const ANALYTICS_TOKEN = 'phc_Ain5Fw59ZXuXJLR7dkqwc3Qswq3YXwsqRNfwczmCPkyu';
export const ANALYTICS_HOST = 'https://us.i.posthog.com';
export const ANALYTICS_NOTICE_VERSION = 'posthog-2026-10-24';
export const ANALYTICS_NOTICE = 'Allow usage analytics? PostHog receives screen visits, taps, learning and checkout activity, device information and a random ID linked to your account ID after sign-in. No passwords, messages, notes or payment details. Change your choice in Settings → Usage analytics.';
const KEY = 'kizuki-analytics-choice';
let ready = false;
let userId: string | null = null;
let screen = '/';
let entered = 0;

export function analyticsChoice(): boolean | null {
  if (typeof window === 'undefined') return null;
  try { const value = localStorage.getItem(KEY); return value == null ? null : value === 'true'; } catch { return false; }
}

function setup() {
  if (ready || analyticsChoice() !== true) return;
  posthog.init(ANALYTICS_TOKEN, {
    api_host: ANALYTICS_HOST,
    autocapture: false, capture_pageview: false, capture_pageleave: false,
    disable_session_recording: true, disable_surveys: true,
    capture_dead_clicks: false, capture_performance: false, capture_exceptions: false,
    disable_product_tours: true, disable_conversations: true,
    request_batching: false,
    advanced_disable_feature_flags: true,
    persistence: 'localStorage', person_profiles: 'identified_only',
    sanitize_properties: (properties) => {
      // The OAuth bridge URL can contain a session; never forward URLs/referrers or DOM text.
      for (const key of Object.keys(properties)) {
        if (/url|referrer|pathname|query|host|text|email|name|token|session|password/i.test(key) && !['token', '$session_id', 'analytics_notice_version'].includes(key)) delete properties[key];
      }
      return properties;
    },
  });
  ready = true;
  posthog.register({ platform: 'web', is_simulated: true, is_test: window.location.hostname === 'localhost', analytics_notice_version: ANALYTICS_NOTICE_VERSION });
  if (userId) posthog.identify(userId);
}

export function track(event: string, properties: Record<string, string | number | boolean> = {}) {
  if (!ready || analyticsChoice() !== true) return;
  posthog.capture(event, { screen, ...properties });
}

export function setAnalyticsChoice(accepted: boolean) {
  localStorage.setItem(KEY, String(accepted));
  const at = new Date().toISOString();
  localStorage.setItem('kizuki-analytics-choice-at', at);
  localStorage.setItem('kizuki-analytics-notice', ANALYTICS_NOTICE_VERSION);
  if (accepted) {
    localStorage.setItem('kizuki-analytics-accepted-at', at);
    setup(); posthog.opt_in_capturing();
    track('analytics_consent_granted'); track('screen_viewed');
  } else if (ready) { posthog.opt_out_capturing(); posthog.reset(); }
  window.dispatchEvent(new Event('kizuki-analytics-choice'));
}

export function analyticsIdentity(id: string | null) {
  if (id === userId) return;
  if (ready && userId) posthog.reset();
  userId = id;
  if (!ready || analyticsChoice() !== true) return;
  if (id) posthog.identify(id);
  track(id ? 'account_signed_in' : 'account_signed_out');
}

export function analyticsScreen(path: string) {
  if (entered && path === screen) return;
  if (entered) track('screen_left', { duration_seconds: Math.round((Date.now() - entered) / 1000) });
  screen = path.startsWith('/clip/') ? '/clip/:clipId' : path;
  entered = Date.now();
  track('screen_viewed');
  if (['/feed', '/explore', '/vocab', '/profile'].includes(path)) track('tab_selected', { tab: path.slice(1) });
}

export function startAnalytics() {
  setup();
  const changed = () => {
    if (analyticsChoice() === true) { setup(); if (ready) posthog.opt_in_capturing(); }
    else if (ready) { posthog.opt_out_capturing(); posthog.reset(); }
  };
  const storage = (e: StorageEvent) => { if (e.key === KEY || e.key === null) changed(); };
  const visibility = () => track(document.hidden ? 'app_backgrounded' : 'app_resumed');
  const error = () => track('app_error', { category: 'browser_runtime' });
  const click = (e: MouseEvent) => {
    const element = e.target instanceof Element ? e.target.closest('button, a, [role="tab"], [role="switch"]') : null;
    if (!element || element.closest('[aria-labelledby="analytics-title"]')) return;
    // Stable position/type only. Never collect element text, link URLs or input contents.
    const controls = Array.from(document.querySelectorAll('button, a, [role="tab"], [role="switch"]'));
    track('control_tapped', { control_type: element.getAttribute('role') ?? element.tagName.toLowerCase(), control_index: controls.indexOf(element) });
  };
  window.addEventListener('storage', storage);
  window.addEventListener('kizuki-analytics-choice', changed);
  window.addEventListener('error', error);
  window.addEventListener('unhandledrejection', error);
  document.addEventListener('visibilitychange', visibility);
  document.addEventListener('click', click, true);
  return () => {
    window.removeEventListener('storage', storage);
    window.removeEventListener('kizuki-analytics-choice', changed);
    window.removeEventListener('error', error);
    window.removeEventListener('unhandledrejection', error);
    document.removeEventListener('visibilitychange', visibility);
    document.removeEventListener('click', click, true);
  };
}