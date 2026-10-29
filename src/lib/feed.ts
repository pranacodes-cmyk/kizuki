import { useQuery } from "@tanstack/react-query";

import { loadContent, rankClips, type Content } from "./content";
import { useLang } from "./i18n";
import { jlptIndex, rankFeed, starterFeedOrder, type LangCode } from "./logic";
import type { PersistedState } from "./store";

/** The library in one language (each loaded once). */
export const contentQuery = (lang: LangCode) => ({ queryKey: ["content", lang], queryFn: () => loadContent(lang), staleTime: Infinity, gcTime: Infinity }) as const;

/** Content library (clips + dictionary) in the app language. */
export function useContent() {
  return useQuery(contentQuery(useLang()));
}

const personalOrder = (c: Content, s: Pick<PersistedState, "profile" | "seen" | "feedSeed">) =>
  rankFeed(rankClips(c), { reasonList: s.profile.reasons, jlpt: s.profile.jlpt, seen: s.seen, seed: s.feedSeed });

/** For You order: the curated starter clips first (same for everyone, until watched), then the
 * personal ranking — shared rules starterFeedOrder + rankFeed (mirrors plan.dart feedOrder). */
export function feedOrder(c: Content, s: Pick<PersistedState, "profile" | "seen" | "feedSeed" | "totals">) {
  return starterFeedOrder(personalOrder(c, s), c.starter, { seen: s.seen, watched: s.totals.clips, jlpt: s.profile.jlpt });
}

/** The onboarding phone preview: the starter clips for everyone, in order (no level or history). */
export const previewOrder = (c: Content, s: Pick<PersistedState, "profile" | "seen" | "feedSeed">) => starterFeedOrder(personalOrder(c, s), c.starter);

/** Clips within one level of the learner — the "picked for you" count. */
export const levelFitCount = (c: Content, jlpt: string) => c.clips.filter((x) => Math.abs(jlptIndex(x.level) - jlptIndex(jlpt)) <= 1).length;
