// Browser/backend client for the project-owned external backend.
import { createClient } from "@supabase/supabase-js";

import { BACKEND_PUBLISHABLE_KEY, BACKEND_URL } from "./backend-config";

// New-style publishable keys are opaque strings, not JWTs: send them as `apikey`
// only, never as an Authorization bearer token (the server rejects those).
function backendFetch(input: RequestInfo | URL, init?: RequestInit) {
  const headers = new Headers(typeof Request !== "undefined" && input instanceof Request ? input.headers : undefined);
  if (init?.headers) new Headers(init.headers).forEach((value, key) => headers.set(key, value));
  if (headers.get("Authorization") === `Bearer ${BACKEND_PUBLISHABLE_KEY}`) headers.delete("Authorization");
  headers.set("apikey", BACKEND_PUBLISHABLE_KEY);
  return fetch(input, { ...init, headers });
}

export const supabase = createClient(BACKEND_URL, BACKEND_PUBLISHABLE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  global: { fetch: backendFetch },
});
