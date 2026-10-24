import { afterEach, describe, expect, it, vi } from 'vitest';
import { hasStoreSubscription } from './subscription.server';

const NOW = 1_800_000_000_000;
function store(items: unknown[]) {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue(Response.json({ items })));
}
afterEach(() => vi.unstubAllGlobals());
describe('server subscription enforcement', () => {
  it('rejects expired premium and exact expiry', async () => {
    store([{ entitlement_id: 'entlb9fd785fdc', expires_at: NOW }]);
    expect(await hasStoreSubscription('learner', 'test-only', NOW)).toBe(false);
  });
  it('allows renewed premium until the new expiry', async () => {
    store([{ entitlement_id: 'entlb9fd785fdc', expires_at: NOW + 30 * 86400000 }]);
    expect(await hasStoreSubscription('learner', 'test-only', NOW)).toBe(true);
  });
  it('rejects signed-in accounts without any purchase', async () => {
    store([]);
    expect(await hasStoreSubscription('learner', 'test-only', NOW)).toBe(false);
  });
  it('does not unlock from another entitlement or malformed expiry', async () => {
    store([{ entitlement_id: 'other', expires_at: NOW + 1 }, { entitlement_id: 'entlb9fd785fdc', expires_at: 'tomorrow' }]);
    expect(await hasStoreSubscription('learner', 'test-only', NOW)).toBe(false);
  });
  it('fails closed when verification is unavailable', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('', { status: 503 })));
    await expect(hasStoreSubscription('learner', 'test-only', NOW)).rejects.toThrow('503');
  });
});