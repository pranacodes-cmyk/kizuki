import { subscriptionAccess } from '@/lib/logic';

// Verified Kizuki RevenueCat project and Premium entitlement; identifiers are not secrets.
const PROJECT = 'projb7f8afb6';
const PREMIUM = 'entlb9fd785fdc';

export async function hasStoreSubscription(userId: string, key: string, now = Date.now()): Promise<boolean> {
  const response = await fetch(`https://api.revenuecat.com/v2/projects/${PROJECT}/customers/${encodeURIComponent(userId)}/active_entitlements?limit=100`, {
    headers: { Authorization: `Bearer ${key}` },
    signal: AbortSignal.timeout(8000),
  });
  if (response.status === 404) return false;
  if (!response.ok) throw new Error(`Subscription verification failed (${response.status})`);
  const data: unknown = await response.json();
  if (!data || typeof data !== 'object' || !('items' in data) || !Array.isArray(data.items)) throw new Error('Invalid subscription response');
  return data.items.some((item: unknown) => {
    if (!item || typeof item !== 'object' || !('entitlement_id' in item) || item.entitlement_id !== PREMIUM || !('expires_at' in item)) return false;
    const end = item.expires_at;
    if (end !== null && (typeof end !== 'number' || !Number.isFinite(end))) return false;
    return subscriptionAccess(true, end, null, now);
  });
}