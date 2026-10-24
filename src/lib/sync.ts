// Cloud sync for signed-in learners — mirrors mobile/lib/services/sync_service.dart.
// The whole learner state lives in one row of public.learner_state (RLS: own row only);
// on sign-in we pull, merge with mergeState() and push; afterwards changes push debounced.
import type { Session } from "@supabase/supabase-js";

import { supabase } from "@/integrations/supabase/client";

import { localStateFor, mergeState } from "./logic";
import { analyticsIdentity } from './analytics';
import { pickPersisted, syncHook, useApp, type PersistedState } from "./store";

let session: Session | null = null;
let timer: ReturnType<typeof setTimeout> | null = null;
let started = false;
const listeners = new Set<(s: Session | null) => void>();

/** Bumped whenever the signed-in account changes (sign-in, sign-out, switch). A sync started
 * for one account discards its result if the account changed meanwhile, so one learner's
 * progress is never merged into or uploaded under another account (mirrors sync_service.dart). */
let generation = 0;
let userId: string | null = null;
let inflight: Promise<void> | null = null;

function applySession(s: Session | null) {
  const id = s?.user.id ?? null;
  if (id !== userId) {
    generation++;
    userId = id;
    analyticsIdentity(id);
    if (timer) clearTimeout(timer);
    timer = null;
    inflight = null;
  }
  session = s;
  listeners.forEach((l) => l(session));
}

const isCurrent = (gen: number, uid: string) => gen === generation && session?.user.id === uid;

export const getSession = () => session;
/** Session setter used right after sign-in so syncNow() can run before the auth event arrives. */
export function setSession(s: Session | null) {
  applySession(s);
}
export function onSession(fn: (s: Session | null) => void) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

/** Pull the cloud copy, merge it into this device and push the result back. */
export function syncNow(): Promise<void> {
  if (inflight) return inflight;
  const p = pullAndMerge().finally(() => {
    if (inflight === p) inflight = null;
  });
  inflight = p;
  return p;
}

async function pullAndMerge() {
  const s = session;
  if (!s) return;
  const gen = generation;
  const uid = s.user.id;
  const { data, error } = await supabase.from("learner_state").select("state").eq("user_id", uid).maybeSingle();
  if (error) {
    console.error("sync pull failed", error);
    return;
  }
  if (!isCurrent(gen, uid)) return; // account changed while the cloud copy loaded
  // Another account's progress on this device never merges into this account.
  const local = localStateFor(pickPersisted(useApp.getState()), uid) as PersistedState;
  const remote = (data?.state ?? null) as PersistedState | null;
  const merged = remote ? ({ ...mergeState(local, remote), owner: uid } as PersistedState) : local;
  useApp.getState().replaceAll(merged);
  await pushAs(s, gen, merged);
}

async function push(state?: PersistedState) {
  if (!session) return;
  await pushAs(session, generation, state);
}

async function pushAs(s: Session, gen: number, state?: PersistedState) {
  const uid = s.user.id;
  if (!isCurrent(gen, uid)) return;
  const payload = state ?? pickPersisted(useApp.getState());
  const { error } = await supabase.from("learner_state").upsert({ user_id: uid, state: payload as never });
  if (error) console.error("sync push failed", error);
  if (!isCurrent(gen, uid)) return;
  const metadata = s.user.user_metadata;
  const profile = payload.profile;
  const { error: profileError } = await supabase.from("profiles").upsert({
    id: uid,
    display_name: profile.name || metadata["full_name"] || metadata["name"] || "",
    avatar_url: metadata["avatar_url"] ?? null,
    preferences: profile,
    updated_at: new Date().toISOString(),
  });
  if (profileError) console.error("profile sync failed", profileError);
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
    applySession(data.session);
    if (session) void syncNow();
  });
  supabase.auth.onAuthStateChange((event, s) => {
    if (event !== "SIGNED_IN" && event !== "SIGNED_OUT" && event !== "USER_UPDATED" && event !== "TOKEN_REFRESHED") return;
    const wasSignedIn = !!session;
    applySession(s);
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
