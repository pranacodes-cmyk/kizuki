// Cloud sync for signed-in learners — mirrors mobile/lib/services/sync_service.dart.
// The whole learner state lives in one row of public.learner_state (RLS: own row only);
// on sign-in we pull, merge with mergeState() and push; afterwards changes push debounced.
import type { Session } from "@supabase/supabase-js";

import { supabase } from "@/integrations/supabase/client";

import { mergeState } from "./logic";
import { pickPersisted, syncHook, useApp, type PersistedState } from "./store";

let session: Session | null = null;
let timer: ReturnType<typeof setTimeout> | null = null;
let started = false;
const listeners = new Set<(s: Session | null) => void>();

export const getSession = () => session;
/** Session setter used right after sign-in so syncNow() can run before the auth event arrives. */
export function setSession(s: Session | null) {
  session = s;
  listeners.forEach((l) => l(session));
}
export function onSession(fn: (s: Session | null) => void) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

let inflight: Promise<void> | null = null;
/** Pull the cloud copy, merge it into this device and push the result back. */
export function syncNow(): Promise<void> {
  if (!inflight) inflight = pullAndMerge().finally(() => { inflight = null; });
  return inflight;
}

async function pullAndMerge() {
  if (!session) return;
  const { data, error } = await supabase.from("learner_state").select("state").eq("user_id", session.user.id).maybeSingle();
  if (error) {
    console.error("sync pull failed", error);
    return;
  }
  const local = pickPersisted(useApp.getState());
  const remote = (data?.state ?? null) as PersistedState | null;
  const merged = remote ? (mergeState(local, remote) as PersistedState) : local;
  if (remote) useApp.getState().replaceAll(merged);
  await push(merged);
}

async function push(state?: PersistedState) {
  if (!session) return;
  const payload = state ?? pickPersisted(useApp.getState());
  const { error } = await supabase.from("learner_state").upsert({ user_id: session.user.id, state: payload as never });
  if (error) console.error("sync push failed", error);
}

/** Wire auth + debounced push once, from the root (client only). */
export function startSync() {
  if (started) return;
  started = true;
  syncHook.onChanged = () => {
    if (!session) return;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => void push(), 2500);
  };
  void supabase.auth.getSession().then(({ data }) => {
    session = data.session;
    listeners.forEach((l) => l(session));
    if (session) void syncNow();
  });
  supabase.auth.onAuthStateChange((event, s) => {
    if (event !== "SIGNED_IN" && event !== "SIGNED_OUT" && event !== "USER_UPDATED" && event !== "TOKEN_REFRESHED") return;
    const wasSignedIn = !!session;
    session = s;
    listeners.forEach((l) => l(session));
    if (event === "SIGNED_IN" && !wasSignedIn) void syncNow();
  });
}

/** Push immediately (e.g. before sign-out). */
export const flushSync = () => push();

export async function signOut() {
  await flushSync();
  await supabase.auth.signOut();
  useApp.getState().reset();
}

/** Permanently deletes the account and its synced data, then clears this device. */
export async function deleteAccount() {
  const { error } = await supabase.rpc("delete_my_account");
  if (error) throw error;
  await supabase.auth.signOut();
  useApp.getState().reset();
}
