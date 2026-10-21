import { useQuery } from "@tanstack/react-query";

import { loadContent, rankClips, type Content } from "./content";
import { jlptIndex, rankFeed } from "./logic";
import type { PersistedState } from "./store";

export const contentQuery = { queryKey: ["content"], queryFn: loadContent, staleTime: Infinity, gcTime: Infinity } as const;

/** Content library (clips + dictionary), loaded once. */
export function useContent() {
  return useQuery(contentQuery);
}

/** For You order for this learner (shared rankFeed rule). */
export function feedOrder(c: Content, s: Pick<PersistedState, "profile" | "seen" | "feedSeed">) {
  return rankFeed(rankClips(c), { reasonList: s.profile.reasons, jlpt: s.profile.jlpt, seen: s.seen, seed: s.feedSeed });
}

/** Clips within one level of the learner — the "picked for you" count. */
export const levelFitCount = (c: Content, jlpt: string) => c.clips.filter((x) => Math.abs(jlptIndex(x.level) - jlptIndex(jlpt)) <= 1).length;
