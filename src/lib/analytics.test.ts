import { beforeEach, describe, expect, it, vi } from 'vitest';

const sdk = vi.hoisted(() => ({ init: vi.fn(), register: vi.fn(), capture: vi.fn(), identify: vi.fn(), reset: vi.fn(), opt_in_capturing: vi.fn(), opt_out_capturing: vi.fn() }));
vi.mock('posthog-js', () => ({ default: sdk }));

describe('PostHog privacy boundaries', () => {
  beforeEach(() => { localStorage.clear(); vi.resetModules(); vi.clearAllMocks(); });
  it('sends nothing before an explicit choice, including paywall activity', async () => {
    const a = await import('./analytics');
    const stop = a.startAnalytics(); a.track('paywall_viewed');
    expect(sdk.init).not.toHaveBeenCalled(); expect(sdk.capture).not.toHaveBeenCalled(); stop();
  });
  it('records real semantic events after acceptance and immediately blocks after withdrawal', async () => {
    const a = await import('./analytics');
    a.setAnalyticsChoice(true); a.track('word_saved', { clip_id: 'clip-42' });
    expect(sdk.capture).toHaveBeenCalledWith('word_saved', expect.objectContaining({ clip_id: 'clip-42' }));
    a.setAnalyticsChoice(false); sdk.capture.mockClear(); a.track('checkout_started');
    expect(sdk.capture).not.toHaveBeenCalled();
    expect(localStorage.getItem('kizuki-analytics-accepted-at')).toBeTruthy();
    expect(a.analyticsChoice()).toBe(false);
  });
  it('normalizes clip paths and never forwards OAuth query values', async () => {
    const a = await import('./analytics'); a.setAnalyticsChoice(true);
    a.analyticsScreen('/clip/clip-42');
    expect(sdk.capture).toHaveBeenLastCalledWith('screen_viewed', { screen: '/clip/:clipId' });
    const config = sdk.init.mock.calls[0]?.[1];
    const sanitized = config.sanitize_properties({ $current_url: 'https://example.test/account?session=private', $referrer: 'private', email: 'private', screen: '/account' });
    expect(sanitized).toEqual({ screen: '/account' });
  });
  it('resets identity before a different account signs in', async () => {
    const a = await import('./analytics'); a.setAnalyticsChoice(true);
    a.analyticsIdentity('account-a'); a.analyticsIdentity('account-b');
    expect(sdk.reset).toHaveBeenCalledTimes(1);
    expect(sdk.identify).toHaveBeenLastCalledWith('account-b');
  });
  it('honors withdrawal from another tab', async () => {
    const a = await import('./analytics'); a.setAnalyticsChoice(true); const stop = a.startAnalytics();
    localStorage.setItem('kizuki-analytics-choice', 'false');
    window.dispatchEvent(new StorageEvent('storage', { key: 'kizuki-analytics-choice' }));
    sdk.capture.mockClear(); a.track('onboarding_completed');
    expect(sdk.capture).not.toHaveBeenCalled(); expect(sdk.opt_out_capturing).toHaveBeenCalled(); stop();
  });
});