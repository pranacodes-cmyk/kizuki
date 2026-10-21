// App state — mirrors mobile/lib/state/app_state.dart (same JSON shape, defaults and
// actions, same storage key `mimi-state-v1`).
import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";

import {
  currentStreak, dayKey, dayMs, dueWordKeys, emptyDay, newCard, wordCounts, wordKeyOf, wordStatus,
  type Card, type DayActivity, type Stats, type WordLite,
} from "./logic";

export const STORAGE_KEY = "mimi-state-v1";

export type Profile = {
  name: string; reasons: string[]; level: number; jlpt: string; challenges: string[]; source: string;
  fluencyMonths: number; dailyMinutes: number; window: string; streakGoal: number;
};
export type Premium = { active: boolean; plan: string | null; since: number | null; trialEndsAt: number | null };
export type WordStatusValue = "learning" | "known" | "ignored" | "removed";
export type SavedWord = {
  key: string; dictId: string | null; word: string; reading: string; romaji: string; gloss: string; pos: string;
  jlpt: number | null; surface: string; clipId: string; line: number; idx: number; note: string;
  status: WordStatusValue; card: Card; addedAt: number; updatedAt: number;
};
export type WordInput = {
  dictId: string | null; base: string; word: string; reading: string; romaji: string; gloss: string; pos: string;
  jlpt: number | null; surface: string; clipId: string; line: number; idx: number;
};
export type Settings = {
  furigana: boolean; romaji: boolean; translation: boolean; spacing: boolean; highlight: boolean; autoSave: boolean;
  textSize: number; speed: number; flashFront: "jp" | "en"; flashFurigana: boolean; flashRomaji: boolean;
  reminders: boolean; reminderFreq: "standard" | "minimal";
};
export type HistoryEntry = { clipId: string; at: number };

export type PersistedState = {
  version: 1;
  onboarded: boolean;
  profile: Profile;
  premium: Premium;
  words: Record<string, SavedWord>;
  kana: Record<string, Card>;
  seen: Record<string, number>;
  history: HistoryEntry[];
  savedClips: string[];
  activity: Record<string, DayActivity>;
  totals: { clips: number; seconds: number; reviews: number };
  settings: Settings;
  tutorial: { feed: boolean; review: boolean };
  achievementsSeen: string[];
  feedSeed: string;
  reviewSessions: number;
  ratingAsked: boolean;
  planModalSeen: boolean;
  updatedAt: number;
};

export const defaultProfile: Profile = {
  name: "", reasons: [], level: 0, jlpt: "N5", challenges: [], source: "", fluencyMonths: 12, dailyMinutes: 15, window: "evening", streakGoal: 14,
};
export const defaultSettings: Settings = {
  furigana: true, romaji: true, translation: true, spacing: true, highlight: true, autoSave: true, textSize: 1, speed: 1,
  flashFront: "jp", flashFurigana: false, flashRomaji: false, reminders: true, reminderFreq: "standard",
};

export const initialState = (): PersistedState => ({
  version: 1,
  onboarded: false,
  profile: { ...defaultProfile },
  premium: { active: false, plan: null, since: null, trialEndsAt: null },
  words: {},
  kana: {},
  seen: {},
  history: [],
  savedClips: [],
  activity: {},
  totals: { clips: 0, seconds: 0, reviews: 0 },
  settings: { ...defaultSettings },
  tutorial: { feed: false, review: false },
  achievementsSeen: [],
  feedSeed: Date.now().toString(36),
  reviewSessions: 0,
  ratingAsked: false,
  planModalSeen: false,
  updatedAt: 0,
});

type Actions = {
  setProfile: (patch: Partial<Profile>) => void;
  completeOnboarding: () => void;
  startTrial: (plan: string) => void;
  cancelPremium: () => void;
  saveWord: (i: WordInput) => void;
  markKnown: (inputs: WordInput[]) => void;
  setWordStatus: (key: string, status: WordStatusValue) => void;
  removeWord: (key: string) => void;
  setWordNote: (key: string, note: string) => void;
  answerWord: (key: string, updated: Card) => Card;
  answerKana: (id: string, updated: Card) => void;
  finishReviewSession: () => void;
  addWatchSeconds: (sec: number) => void;
  markClipWatched: (clipId: string) => void;
  toggleSavedClip: (clipId: string) => void;
  setSettings: (patch: Partial<Settings>) => void;
  completeTutorial: (which: "feed" | "review") => void;
  resetTutorial: () => void;
  markAchievementsSeen: (ids: string[]) => void;
  setRatingAsked: () => void;
  setPlanModalSeen: () => void;
  replaceAll: (s: PersistedState) => void;
  reset: () => void;
};

export type AppStore = PersistedState & Actions;

/** Called after every change that should reach the cloud (wired by sync.ts). */
export const syncHook: { onChanged: (() => void) | null } = { onChanged: null };

const today = () => dayKey(new Date());
const bump = (a: Record<string, DayActivity>, patch: Partial<DayActivity>) => {
  const k = today();
  const d = a[k] ?? emptyDay();
  return { ...a, [k]: { sec: d.sec + (patch.sec ?? 0), clips: d.clips + (patch.clips ?? 0), reviews: d.reviews + (patch.reviews ?? 0), words: d.words + (patch.words ?? 0) } };
};

const makeWord = (i: WordInput, status: WordStatusValue, t: number): SavedWord => ({
  key: wordKeyOf(i.dictId, i.base), dictId: i.dictId, word: i.word, reading: i.reading, romaji: i.romaji, gloss: i.gloss, pos: i.pos,
  jlpt: i.jlpt, surface: i.surface, clipId: i.clipId, line: i.line, idx: i.idx, note: "", status, card: newCard(t), addedAt: t, updatedAt: t,
});

export const useApp = create<AppStore>()(
  persist(
    (set, get) => {
      const commit = (patch: Partial<PersistedState>, sync = true) => {
        set({ ...patch, updatedAt: Date.now() });
        if (sync) syncHook.onChanged?.();
      };
      return {
        ...initialState(),
        setProfile: (patch) => commit({ profile: { ...get().profile, ...patch } }),
        completeOnboarding: () => commit({ onboarded: true }),
        startTrial: (plan) => {
          const t = Date.now();
          commit({ premium: { active: true, plan, since: t, trialEndsAt: t + 7 * dayMs } });
        },
        cancelPremium: () => commit({ premium: { active: false, plan: null, since: null, trialEndsAt: null } }),
        saveWord: (i) => {
          const key = wordKeyOf(i.dictId, i.base);
          const existing = get().words[key];
          if (existing && existing.status !== "removed") return;
          commit({ words: { ...get().words, [key]: makeWord(i, "learning", Date.now()) }, activity: bump(get().activity, { words: 1 }) });
        },
        markKnown: (inputs) => {
          const t = Date.now();
          const words = { ...get().words };
          for (const i of inputs) {
            const key = wordKeyOf(i.dictId, i.base);
            if (words[key] && words[key].status !== "removed") continue;
            words[key] = makeWord(i, "known", t);
          }
          commit({ words });
        },
        setWordStatus: (key, status) => {
          const w = get().words[key];
          if (!w) return;
          commit({ words: { ...get().words, [key]: { ...w, status, updatedAt: Date.now() } } });
        },
        removeWord: (key) => get().setWordStatus(key, "removed"),
        setWordNote: (key, note) => {
          const w = get().words[key];
          if (!w) return;
          commit({ words: { ...get().words, [key]: { ...w, note, updatedAt: Date.now() } } });
        },
        answerWord: (key, updated) => {
          const w = get().words[key];
          const words = w ? { ...get().words, [key]: { ...w, card: updated, updatedAt: Date.now() } } : get().words;
          commit({ words, totals: { ...get().totals, reviews: get().totals.reviews + 1 }, activity: bump(get().activity, { reviews: 1 }) });
          return updated;
        },
        answerKana: (id, updated) =>
          commit({ kana: { ...get().kana, [id]: updated }, totals: { ...get().totals, reviews: get().totals.reviews + 1 }, activity: bump(get().activity, { reviews: 1 }) }),
        finishReviewSession: () => commit({ reviewSessions: get().reviewSessions + 1 }),
        addWatchSeconds: (sec) => {
          if (sec <= 0) return;
          commit({ totals: { ...get().totals, seconds: get().totals.seconds + sec }, activity: bump(get().activity, { sec }) }, false);
        },
        markClipWatched: (clipId) =>
          commit({
            seen: { ...get().seen, [clipId]: (get().seen[clipId] ?? 0) + 1 },
            history: [{ clipId, at: Date.now() }, ...get().history].slice(0, 200),
            totals: { ...get().totals, clips: get().totals.clips + 1 },
            activity: bump(get().activity, { clips: 1 }),
          }),
        toggleSavedClip: (clipId) => {
          const s = get().savedClips;
          commit({ savedClips: s.includes(clipId) ? s.filter((x) => x !== clipId) : [clipId, ...s] });
        },
        setSettings: (patch) => commit({ settings: { ...get().settings, ...patch } }),
        completeTutorial: (which) => commit({ tutorial: { ...get().tutorial, [which]: true } }),
        resetTutorial: () => commit({ tutorial: { feed: false, review: false } }),
        markAchievementsSeen: (ids) => commit({ achievementsSeen: [...new Set([...get().achievementsSeen, ...ids])] }),
        setRatingAsked: () => commit({ ratingAsked: true }),
        setPlanModalSeen: () => commit({ planModalSeen: true }),
        replaceAll: (s) => set({ ...initialState(), ...s }),
        reset: () => set({ ...initialState(), feedSeed: Date.now().toString(36) }),
      };
    },
    {
      name: STORAGE_KEY,
      storage: createJSONStorage(() => localStorage),
      partialize: (s) => pickPersisted(s),
    },
  ),
);

export function pickPersisted(s: PersistedState): PersistedState {
  return {
    version: 1, onboarded: s.onboarded, profile: s.profile, premium: s.premium, words: s.words, kana: s.kana, seen: s.seen,
    history: s.history, savedClips: s.savedClips, activity: s.activity, totals: s.totals, settings: s.settings, tutorial: s.tutorial,
    achievementsSeen: s.achievementsSeen, feedSeed: s.feedSeed, reviewSessions: s.reviewSessions, ratingAsked: s.ratingAsked,
    planModalSeen: s.planModalSeen, updatedAt: s.updatedAt,
  };
}

// ---- selectors (same as AppState getters) ----
export const wordLites = (s: PersistedState): WordLite[] => Object.values(s.words).map((w) => ({ key: w.key, status: w.status, card: w.card, addedAt: w.addedAt }));
export const countsOf = (s: PersistedState) => wordCounts(wordLites(s), Date.now());
export const dueKeysOf = (s: PersistedState) => dueWordKeys(wordLites(s), Date.now());
export const streakOf = (s: PersistedState) => currentStreak(s.activity, new Date());
export const todayOf = (s: PersistedState): DayActivity => s.activity[today()] ?? emptyDay();
export const statsOf = (s: PersistedState): Stats => {
  const c = countsOf(s);
  return { clips: s.totals.clips, seconds: s.totals.seconds, words: c.saved, known: c.known, reviews: s.totals.reviews, streak: streakOf(s) };
};
/** Underline status for a word in a transcript: new | learning | known | ignored. */
export function tokenStatus(s: PersistedState, key: string): "new" | "learning" | "known" | "ignored" {
  const w = s.words[key];
  if (!w || w.status === "removed") return "new";
  return wordStatus({ status: w.status, card: w.card });
}
