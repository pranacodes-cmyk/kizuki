// Business rules for Kizuki. Kept 1:1 with mobile/lib/logic/logic.dart (mirrored tests in
// src/lib/logic.test.ts and mobile/test/logic_test.dart). UI code calls these helpers
// instead of re-deriving rules.

import { tr } from "./i18n-core";

export const WIDGET_SLOT_MS = 2 * 60 * 60 * 1000;
export type WidgetWord = { key: string; word: string; reading: string; meaning: string; clipId: string; example: string; jlpt: number; due: number; status: string };
export function widgetWords(publicWords: WidgetWord[], saved: WidgetWord[], level: string, shareSaved: boolean, now: number): WidgetWord[] {
  const n = Number(level.replace('N', '')) || 5;
  const eligible = publicWords.filter((w) => w.jlpt >= n && w.word && w.meaning).sort((a, b) => a.key < b.key ? -1 : a.key > b.key ? 1 : 0);
  const personal = shareSaved ? saved.filter((w) => w.status === 'learning' && w.word && w.meaning).sort((a, b) => a.due - b.due || (a.key < b.key ? -1 : a.key > b.key ? 1 : 0)) : [];
  const pool = personal.length ? personal : eligible;
  if (!pool.length) return [];
  const start = personal.length && (personal[0]?.due ?? Infinity) <= now ? 0 : Math.floor(now / WIDGET_SLOT_MS) % pool.length;
  return Array.from({ length: Math.min(12, pool.length) }, (_, i) => pool[(start + i) % pool.length]).filter((w): w is WidgetWord => w !== undefined);
}
export function widgetDestination(link: string): string | null {
  try {
    const uri = new URL(link);
    if (uri.protocol !== 'kizuki:' || uri.hostname !== 'widget') return null;
    if (uri.pathname === '/review') return '/review?deck=words';
    if (uri.pathname !== '/word') return null;
    const id = uri.searchParams.get('clip');
    return id && /^[A-Za-z0-9_-]+$/.test(id) ? `/clip/${id}` : '/vocab';
  } catch { return null; }
}

// ---------------------------------------------------------------------------
// Onboarding answers
// ---------------------------------------------------------------------------

export const reasons = ["travel", "anime", "work", "fun", "friends", "family", "romance", "culture"] as const;
export const challenges = ["listening", "start", "motivation", "grammar", "speaking", "vocab"] as const;
export const studyWindows = ["morning", "afternoon", "evening", "night"] as const;
export const streakGoals = [7, 14, 30, 50] as const;
export const jlptLevels = ["N5", "N4", "N3", "N2", "N1"] as const;

export const signInProviders = (platform: string): readonly ("google" | "apple")[] => platform === "android" ? ["google"] : ["google", "apple"];
export const founderVideoEnabled = (remote: unknown, cached = true): boolean => typeof remote === 'boolean' ? remote : cached;

/** Server-sent founder video override: only a clean https link counts; anything else keeps the bundled clip. */
export const founderVideoUrl = (remote: unknown): string | null => {
  if (typeof remote !== "string") return null;
  const u = remote.trim();
  return u.startsWith("https://") && u.length > 8 ? u : null;
};
export const onboardingAfterPlan = (enabled: boolean): '/founder' | '/trial' => enabled ? '/founder' : '/trial';

/** Remote native sign-in switch: off until the backend accepts this app's own provider
 * tokens; a missing/invalid value keeps the last valid one. */
export const nativeSignInEnabled = (remote: unknown, cached = false): boolean => typeof remote === 'boolean' ? remote : cached;

/** Server-sent trial experiment: `false` (or 0 days) = direct paywall with no trial wording;
 * a plausible day count (1–14) replaces the shipped default; anything missing/invalid keeps
 * the last valid value. */
export const DEFAULT_TRIAL_DAYS = 7;
export const trialDays = (remoteEnabled: unknown, remoteDays: unknown, cached = DEFAULT_TRIAL_DAYS): number => {
  const days = typeof remoteDays === 'number' && Number.isInteger(remoteDays) ? remoteDays : cached;
  if (remoteEnabled === false || days <= 0) return 0;
  return days <= 14 ? days : cached;
};

/** Phone sign-in never substitutes a browser for the requested native account sheet. */
export const signInMethod = (provider: string): 'native' | 'unavailable' =>
  provider === 'google' || provider === 'apple' ? 'native' : 'unavailable';

/** Learner progress on a device belongs to the account it last synced with (`owner`).
 * Progress made before any sign-in (no owner) joins the first account; signing into a
 * different account starts from a clean learner document that keeps only device-level
 * values, so one learner's words, history and profile never merge into another account. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function localStateFor(local: any, userId: string): any {
  const owner = local.owner ?? null;
  if (owner === null || owner === userId) return { ...local, owner: userId };
  return {
    version: local.version ?? 1,
    onboarded: local.onboarded === true,
    purchaseAccountPending: local.purchaseAccountPending === true,
    premium: local.premium,
    settings: local.settings,
    feedSeed: local.feedSeed,
    owner: userId,
    updatedAt: 0,
  };
}

const clamp = (n: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, n));

/** Self-reported level (0..4) → JLPT band used for content. */
export const levelToJlpt = (level: number): string => ["N5", "N5", "N4", "N3", "N2"][clamp(level, 0, 4)] ?? "N5";

/** JLPT band → index (N5 = 0 … N1 = 4). */
export function jlptIndex(jlpt: string) {
  const i = (jlptLevels as readonly string[]).indexOf(jlpt);
  return i < 0 ? 0 : i;
}

/** Words a learner meets per month at a daily study time. */
export const wordsPerMonth = (minutes: number) => Math.round(minutes * 20.4);

/** Daily minutes recommended for a fluency goal (months), rounded to 5, 5..60. */
export function recommendedMinutes(months: number) {
  const raw = 225 / Math.max(1, months);
  return clamp(Math.round(raw / 5) * 5, 5, 60);
}

const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

/** "Oct 2027" — the month the fluency goal lands on. */
export function goalDateLabel(now: Date, months: number) {
  const total = now.getMonth() + months;
  return tr("{month} {year}", { month: tr(monthNames[total % 12] ?? ""), year: now.getFullYear() + Math.floor(total / 12) });
}

/** Window → reminder hour (local time). */
export function windowHour(window: string) {
  switch (window) {
    case "morning": return 8;
    case "afternoon": return 13;
    case "evening": return 19;
    default: return 22;
  }
}

export function windowLabel(window: string) {
  switch (window) {
    case "morning": return tr("in the morning");
    case "afternoon": return tr("in the afternoon");
    case "evening": return tr("in the evening");
    default: return tr("at night");
  }
}

export function challengeBenefit(challenge: string) {
  switch (challenge) {
    case "listening": return "Real Japanese at natural speed, with every word subtitled";
    case "start": return "A simple daily path — watch, save words, review";
    case "motivation": return "Short, fun clips that keep you coming back";
    case "grammar": return "Every word explained in the sentence you heard";
    case "speaking": return "Hear how natives really talk, so you sound natural too";
    default: return "Words stick because you learn them in a real scene";
  }
}

/** Onboarding reason → content topics it unlocks. */
export function reasonTopics(reason: string): string[] {
  switch (reason) {
    case "travel": return ["travel", "food", "culture"];
    case "anime": return ["anime"];
    case "work": return ["work"];
    case "fun": return ["fun", "comedy", "animals"];
    case "friends": return ["friends", "daily"];
    case "family": return ["family", "daily"];
    case "romance": return ["romance"];
    default: return ["culture", "food", "travel"];
  }
}

export type PlanItem = { icon: string; title: string; body: string };

function reasonItem(reason: string): PlanItem {
  switch (reason) {
    case "travel": return { icon: "🌍", title: "Travel with confidence", body: "Real Japanese from trains, shops and restaurants" };
    case "anime": return { icon: "🎌", title: "Understand anime without subtitles", body: "Scenes from real shows, explained word by word" };
    case "work": return { icon: "💼", title: "Japanese for work", body: "Polite speech and office talk from real dramas" };
    case "fun": return { icon: "🎉", title: "Learning that feels like scrolling", body: "Funny, cute and surprising clips — no textbook" };
    case "friends": return { icon: "👫", title: "Chat naturally with friends", body: "Casual Japanese the way friends really talk" };
    case "family": return { icon: "🏡", title: "Talk with family", body: "Warm, everyday Japanese from home life" };
    case "romance": return { icon: "❤️", title: "Love, in Japanese", body: "Feelings and sweet talk from romance dramas" };
    default: return { icon: "🏯", title: "Live the culture", body: "Food, festivals and daily life in Japan" };
  }
}

function challengeItem(challenge: string, streakGoal: number, window: string): PlanItem {
  switch (challenge) {
    case "listening": return { icon: "👂", title: "Train your ear", body: "Natural-speed Japanese with word-by-word subtitles" };
    case "start": return { icon: "🧭", title: "A clear daily path", body: "Watch → save words → review. That's it." };
    case "motivation": return { icon: "🔥", title: tr("A {n}-day streak goal", { n: streakGoal }), body: tr("Friendly reminders {when}", { when: windowLabel(window) }) };
    case "grammar": return { icon: "🧩", title: "Grammar in context", body: "Every word explained in the sentence you heard" };
    case "speaking": return { icon: "🗣️", title: "Sound like a native", body: "Copy real rhythm and intonation, line by line" };
    default: return { icon: "📚", title: "Words that stick", body: "Smart reviews with the original clip audio" };
  }
}

/** The "Your plan is ready" list — every line reflects an answer. */
export function planItems(o: {
  reasonList: string[]; challengeList: string[]; dailyMinutes: number; window: string;
  streakGoal: number; jlpt: string; clipCount: number;
}): PlanItem[] {
  return [
    { icon: "⏰", title: tr("{n}-minute daily sessions", { n: o.dailyMinutes }), body: tr("Bite-sized clips {when}", { when: windowLabel(o.window) }) },
    reasonItem(o.reasonList[0] ?? "fun"),
    challengeItem(o.challengeList[0] ?? "listening", o.streakGoal, o.window),
    { icon: "📈", title: tr("{n} new words a month", { n: wordsPerMonth(o.dailyMinutes) }), body: tr("At {n} minutes a day", { n: o.dailyMinutes }) },
    { icon: "🎬", title: tr("{n} clips picked for you", { n: o.clipCount }), body: tr("Matched to your level ({jlpt}) and interests", { jlpt: o.jlpt }) },
  ];
}

// ---------------------------------------------------------------------------
// Deterministic hashing (identical in Dart: FNV-1a over UTF-16 units)
// ---------------------------------------------------------------------------

export function fnv1a(s: string) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

// ---------------------------------------------------------------------------
// Feed ranking
// ---------------------------------------------------------------------------

/** still: audio-first video (a podcast) whose picture is one still image — ranked well below real video. */
export type RankClip = { id: string; videoId: string; level: string; topics: string[]; quality: number; still?: boolean };

/** Score taken off a still-picture clip (more than the whole random jitter range). */
export const STILL_CLIP_PENALTY = 6;
/** The curated starter clips lead the feed until the learner has watched this many clips. */
export const STARTER_WATCH_LIMIT = 60;
/** Only yearly simulation has a trial; native dates always come from the store. */
export const simulatedTrialEnd = (plan: string, now: number): number | null => plan === "yearly" ? now + 7 * dayMs : null;
/** Expired trials/subscriptions never fall back to free learning. */
export function subscriptionAccess(active: boolean, expiresAt: number | null | undefined, trialEndsAt: number | null, now: number) {
  const end = expiresAt ?? trialEndsAt;
  return active && (end == null || end > now);
}
export const learningPath = (path: string) => !["/account", "/settings", "/language", "/widgets", "/support", "/terms", "/privacy", "/trial", "/profile", "/achievements"].includes(path);
export const onboardingPath = (path: string) => ["/", "/onboarding", "/building", "/plan", "/founder"].includes(path);
export const accountNeedsOnboarding = (fromWelcome: boolean, onboarded: boolean, premiumAccess: boolean) => fromWelcome && !onboarded && !premiumAccess;
export const subscriptionPhase = (active: boolean, plan: string | null, trialEndsAt: number | null, now: number) =>
  !active ? "free" : plan === "yearly" && trialEndsAt != null && trialEndsAt > now ? "trial" : "active";
/** YouTube reports zero until metadata arrives; allow only end-padding tolerance. */
export const clipWindowAvailable = (start: number, end: number, duration: number) =>
  duration <= 0 || (start < duration && end <= duration + 0.75);
/** A curated starter clip: id + JLPT level. */
export type StarterClip = { id: string; level: string };

/** Everyone's first clips: the curated starter list in its order (only clips that exist and are
 * not watched yet), then the personal ranking without them. Learners above N3 skip starters more
 * than two levels easier than theirs (jlpt null = the onboarding preview: same for everyone).
 * After STARTER_WATCH_LIMIT watched clips the feed is fully personal. Mirrors starterFeedOrder in logic.dart. */
export function starterFeedOrder(
  personalized: string[], starter: StarterClip[],
  { seen = {}, watched = 0, jlpt = null }: { seen?: Record<string, number>; watched?: number; jlpt?: string | null } = {},
): string[] {
  if (watched >= STARTER_WATCH_LIMIT) return personalized;
  const available = new Set(personalized);
  const lead: string[] = [];
  for (const s of starter) {
    if (!available.has(s.id) || (seen[s.id] ?? 0) > 0 || lead.includes(s.id)) continue;
    if (jlpt != null && jlptIndex(s.level) - jlptIndex(jlpt) < -2) continue;
    lead.push(s.id);
  }
  if (!lead.length) return personalized;
  const taken = new Set(lead);
  return [...lead, ...personalized.filter((id) => !taken.has(id))];
}
type RankCtx = { reasonList: string[]; jlpt: string; seen: Record<string, number>; seed: string };

export function clipScore(clip: RankClip, { reasonList, jlpt, seen, seed }: RankCtx) {
  const wanted = new Set<string>();
  for (const r of reasonList) for (const t of reasonTopics(r)) wanted.add(t);
  let topic = 0;
  for (const t of clip.topics) if (wanted.has(t)) topic += 3;
  topic = Math.min(topic, 6);
  const d = jlptIndex(clip.level) - jlptIndex(jlpt);
  const level = d === 0 ? 4 : d === -1 ? 3 : d === 1 ? 2 : d <= -2 ? 1 : -2;
  const quality = (clip.quality - 3) * 1.5;
  const seenPenalty = (seen[clip.id] ?? 0) * 8;
  const jitter = ((fnv1a(`${seed}:${clip.id}`) % 1000) / 1000) * 2.5;
  const still = clip.still ? STILL_CLIP_PENALTY : 0;
  return topic + level + quality - seenPenalty - still + jitter;
}

/** Ordered clip ids for the For You feed. Same video never plays twice in a row
 * when another choice exists within the next 5. */
export function rankFeed(clips: RankClip[], ctx: RankCtx): string[] {
  const pool = clips
    .map((c) => ({ c, s: clipScore(c, ctx) }))
    .sort((a, b) => (b.s !== a.s ? b.s - a.s : a.c.id < b.c.id ? -1 : a.c.id > b.c.id ? 1 : 0))
    .map((e) => e.c);
  const out: RankClip[] = [];
  while (pool.length) {
    let pick = 0;
    if (out.length) {
      for (let i = 0; i < Math.min(5, pool.length); i++) {
        if (pool[i]!.videoId !== out[out.length - 1]!.videoId) { pick = i; break; }
      }
    }
    out.push(pool.splice(pick, 1)[0]!);
  }
  return out.map((c) => c.id);
}

// ---------------------------------------------------------------------------
// Spaced repetition (two buttons: Again / Good)
// ---------------------------------------------------------------------------

export const minuteMs = 60 * 1000;
export const dayMs = 24 * 60 * minuteMs;
export const knownIntervalDays = 21;

export type CardState = "new" | "learning" | "review" | "relearning";
export type Card = { state: CardState; step: number; interval: number; ease: number; due: number; reps: number; lapses: number };
export type Grade = "again" | "good";

export const newCard = (now: number): Card => ({ state: "new", step: 0, interval: 0, ease: 2.5, due: now, reps: 0, lapses: 0 });

/** Apply an answer. Again → back in 1 minute. Good: new → 10 minutes,
 * learning → 1 day, review → interval × ease, relearning → half interval. */
export function answerCard(c: Card, grade: Grade, now: number): Card {
  if (grade === "again") {
    const wasReview = c.state === "review";
    return {
      ...c,
      state: wasReview || c.state === "relearning" ? "relearning" : "learning",
      step: 0,
      due: now + minuteMs,
      ease: wasReview ? Math.max(1.3, c.ease - 0.2) : c.ease,
      lapses: wasReview ? c.lapses + 1 : c.lapses,
      reps: c.reps + 1,
    };
  }
  switch (c.state) {
    case "new":
      return { ...c, state: "learning", step: 1, due: now + 10 * minuteMs, reps: c.reps + 1 };
    case "learning":
      return { ...c, state: "review", step: 0, interval: 1, due: now + dayMs, reps: c.reps + 1 };
    case "relearning": {
      const iv = Math.max(1, Math.round(c.interval * 0.5));
      return { ...c, state: "review", step: 0, interval: iv, due: now + Math.round(iv * dayMs), reps: c.reps + 1 };
    }
    default: {
      const iv = Math.max(c.interval + 1, Math.round(c.interval * c.ease));
      return { ...c, interval: iv, due: now + Math.round(iv * dayMs), reps: c.reps + 1 };
    }
  }
}

/** Compact label for how long until a card returns ("<1m", "10m", "3d", "2mo"). */
export function formatInterval(ms: number) {
  if (ms < minuteMs) return "<1m";
  if (ms < 60 * minuteMs) return `${Math.round(ms / minuteMs)}m`;
  if (ms < dayMs) return `${Math.round(ms / (60 * minuteMs))}h`;
  const days = ms / dayMs;
  if (days < 30) return `${Math.round(days)}d`;
  if (days < 365) return `${Math.round(days / 30)}mo`;
  return `${(days / 365).toFixed(1)}y`;
}

/** Plain-English time until the next practice ("now", "in 10 minutes", "tomorrow", "in 3 days")
 * for learner-facing text — mirrors formatWhen in logic.dart. */
export function formatWhen(ms: number) {
  const n = (v: number, one: string, other: string) => tr(v === 1 ? one : other, { n: v });
  if (ms <= 0) return tr("now");
  if (ms < minuteMs) return tr("in under a minute");
  if (ms < 60 * minuteMs) return n(Math.min(59, Math.max(1, Math.round(ms / minuteMs))), "in {n} minute", "in {n} minutes");
  if (ms < dayMs) {
    const h = Math.round(ms / (60 * minuteMs));
    return h >= 24 ? tr("tomorrow") : n(h, "in {n} hour", "in {n} hours");
  }
  const days = ms / dayMs;
  if (days < 1.5) return tr("tomorrow");
  if (days < 30) return n(Math.round(days), "in {n} day", "in {n} days");
  if (days < 365) return n(Math.round(days / 30), "in {n} month", "in {n} months");
  return n(Math.round(days / 365), "in {n} year", "in {n} years");
}

export const nextIntervalLabel = (c: Card, grade: Grade, now: number) =>
  grade === "again" ? "1m" : formatInterval(answerCard(c, grade, now).due - now);

export const isDue = (c: Card, now: number) => c.due <= now;

export type WordStatus = "learning" | "known" | "ignored";

/** Learner-facing status. Saved words move from learning → known automatically. */
export function wordStatus({ status, card }: { status: string; card: Card }): WordStatus {
  if (status === "ignored") return "ignored";
  if (status === "known") return "known";
  if (card.state === "review" && card.interval >= knownIntervalDays) return "known";
  return "learning";
}

// ---------------------------------------------------------------------------
// Word levels (Kiku-style familiarity badge): 1 New → 2 Recognized → 3 Familiar →
// 4 Almost known → 5 Known; 0 = ignored. They rise by themselves as reviews space out,
// and the learner can pick one, which reschedules the card to match.
// ---------------------------------------------------------------------------

/** A review interval of this many days or more counts as "Almost known" (level 4). */
export const almostKnownDays = 7;

export type WordLevel = 0 | 1 | 2 | 3 | 4 | 5;
export type WordLevelInfo = { level: WordLevel; label: string; hint: string };

/** Menu order: learning levels, Known, then Ignored (mirrors wordLevels in logic.dart). */
export const WORD_LEVELS: WordLevelInfo[] = [
  { level: 1, label: "New", hint: "Just saved. Reviews start now" },
  { level: 2, label: "Recognized", hint: "Starting to stick" },
  { level: 3, label: "Familiar", hint: "You remember it for days" },
  { level: 4, label: "Almost known", hint: "You remember it for a week or more" },
  { level: 5, label: "Known", hint: "No more reviews, no underline" },
  { level: 0, label: "Ignored", hint: "Never underlined or reviewed" },
];

export const wordLevelInfo = (level: number): WordLevelInfo => WORD_LEVELS.find((l) => l.level === level) ?? WORD_LEVELS[0]!;

/** The level a saved word is at now. */
export function wordLevel({ status, card }: { status: string; card: Card }): WordLevel {
  if (status === "ignored" || status === "removed") return 0;
  if (wordStatus({ status, card }) === "known") return 5;
  if (card.state === "new") return 1;
  if (card.state !== "review") return 2;
  return card.interval >= almostKnownDays ? 4 : 3;
}

/** Reschedule a card for a learning level the learner picked: 1 = review now,
 * 2 = in 10 minutes, 3 = in 3 days, 4 = in 10 days. Ease, reps and lapses are kept. */
export function cardAtLevel(c: Card, level: number, now: number): Card {
  switch (level) {
    case 1: return { ...c, state: "new", step: 0, interval: 0, due: now };
    case 2: return { ...c, state: "learning", step: 1, interval: 0, due: now + 10 * minuteMs };
    case 3: return { ...c, state: "review", step: 0, interval: 3, due: now + 3 * dayMs };
    default: return { ...c, state: "review", step: 0, interval: 10, due: now + 10 * dayMs };
  }
}

/** Parts of speech worth teaching first: the welcome tour asks you to tap one of these. */
export const TOUR_WORD_POS = ["noun", "verb", "adj", "i-adj", "na-adj", "adverb"];

/**
 * The word the welcome tour asks you to tap, from line `from` on: the first new content word
 * with a dictionary entry (never a filler like ん or a particle), else the first new word,
 * else any word. Looks at one line at a time so the target stays near what's playing.
 */
export function pickTourWord(lines: { words: { p: string; d: string | null }[] }[], from: number, isNew: (line: number, idx: number) => boolean): { line: number; idx: number } | null {
  for (let li = Math.max(0, from); li < lines.length; li++) {
    let firstNew: { line: number; idx: number } | null = null;
    let any: { line: number; idx: number } | null = null;
    const words = lines[li]!.words;
    for (let wi = 0; wi < words.length; wi++) {
      const w = words[wi]!;
      if (w.p === "punct") continue;
      any ??= { line: li, idx: wi };
      if (!isNew(li, wi)) continue;
      if (w.d && TOUR_WORD_POS.includes(w.p)) return { line: li, idx: wi };
      firstNew ??= { line: li, idx: wi };
    }
    if (firstNew) return firstNew;
    if (any) return any;
  }
  return null;
}

/** True when an in-clip meaning only repeats the dictionary's first sense ("every day" vs
 * "every day; daily"), so a card shows the meaning once. Empty meanings count as repeats. */
export function repeatsSense(gloss: string, sense: string | null | undefined) {
  // Letters, marks and digits of every script count (Thai vowels are marks; Vietnamese tones stay).
  const norm = (x: string) => x.toLowerCase().replace(/\([^)]*\)/g, " ").replace(/[^\p{L}\p{M}\p{N}' ]+/gu, " ").replace(/\s+/g, " ").trim();
  const g = norm(gloss);
  if (!g) return true;
  if (!sense) return false;
  return norm(sense) === g || sense.split(/[;,]/).some((p) => norm(p) === g);
}

/** Meaning shown for a saved word. It was saved in the app language of that moment (older saves:
 * English); after a language switch the dictionary's meaning in the current language replaces it,
 * and without one the saved meaning stays. */
export function savedGloss(gloss: string, glossLang: string | null | undefined, dictGloss: string | null | undefined, lang: string): string {
  if ((glossLang || "en") === lang) return gloss;
  return dictGloss ? dictGloss : gloss;
}

/** Status + card after the learner picks a level. Picking the level a learning word is
 * already at keeps its schedule. */
export function withWordLevel(w: { status: string; card: Card }, level: number, now: number): { status: "learning" | "known" | "ignored"; card: Card } {
  if (level <= 0) return { status: "ignored", card: w.card };
  if (level >= 5) return { status: "known", card: w.card };
  if (w.status === "learning" && wordLevel(w) === level) return { status: "learning", card: w.card };
  return { status: "learning", card: cardAtLevel(w.card, level, now) };
}

/** In-session queue: a card leaves only once it graduates or passes review. */
export class ReviewSession {
  queue: string[];
  answered = 0;
  constructor(ids: string[]) { this.queue = [...ids]; }
  get current() { return this.queue[0] ?? null; }
  get done() { return this.queue.length === 0; }
  /** Returns the updated card; requeues it at the end while still learning. */
  answer(card: Card, grade: Grade, now: number): Card {
    const id = this.queue.shift()!;
    this.answered++;
    const next = answerCard(card, grade, now);
    if (next.state === "learning" || next.state === "relearning") this.queue.push(id);
    return next;
  }
}

// ---------------------------------------------------------------------------
// Days, streaks, goals
// ---------------------------------------------------------------------------

const pad = (n: number, w = 2) => String(n).padStart(w, "0");
export const dayKey = (d: Date) => `${pad(d.getFullYear(), 4)}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
export function parseDayKey(key: string) {
  const [y = 1970, m = 1, d = 1] = key.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export type DayActivity = { sec: number; clips: number; reviews: number; words: number };
export const emptyDay = (): DayActivity => ({ sec: 0, clips: 0, reviews: 0, words: 0 });
export const isActiveDay = (a?: DayActivity) => !!a && (a.sec >= 60 || a.clips > 0 || a.reviews > 0);

/** Consecutive active days ending today (or yesterday while today is still open). */
export function currentStreak(activity: Record<string, DayActivity>, today: Date) {
  let d = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  if (!isActiveDay(activity[dayKey(d)])) d = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1);
  let n = 0;
  while (isActiveDay(activity[dayKey(d)])) {
    n++;
    d = new Date(d.getFullYear(), d.getMonth(), d.getDate() - 1);
  }
  return n;
}

export function bestStreak(activity: Record<string, DayActivity>) {
  const keys = Object.entries(activity).filter(([, v]) => isActiveDay(v)).map(([k]) => k).sort();
  let best = 0, run = 0;
  let prev: Date | null = null;
  for (const k of keys) {
    const d = parseDayKey(k);
    run = prev && new Date(prev.getFullYear(), prev.getMonth(), prev.getDate() + 1).getTime() === d.getTime() ? run + 1 : 1;
    best = Math.max(best, run);
    prev = d;
  }
  return best;
}

/** Minutes left in today's goal (rounded up, never negative). */
export const minutesLeft = (goalMinutes: number, secondsToday: number) => Math.max(0, Math.ceil((goalMinutes * 60 - secondsToday) / 60));

/** 0..1 progress toward today's goal. */
export const goalProgress = (goalMinutes: number, secondsToday: number) =>
  goalMinutes <= 0 ? 1 : Math.min(1, secondsToday / (goalMinutes * 60));

/** Heatmap intensity 0..4 for a day. */
export function heatLevel(sec: number, goalMinutes: number) {
  if (sec <= 0) return 0;
  const r = sec / Math.max(60, goalMinutes * 60);
  if (r < 0.25) return 1;
  if (r < 0.6) return 2;
  if (r < 1) return 3;
  return 4;
}

/** Day keys for a Monday-first heatmap of `weeks` columns ending this week. */
export function heatmapWeeks(today: Date, weeks: number): string[][] {
  const t = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const weekday = t.getDay() === 0 ? 7 : t.getDay();
  const monday = new Date(t.getFullYear(), t.getMonth(), t.getDate() - (weekday - 1));
  const start = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() - 7 * (weeks - 1));
  return Array.from({ length: weeks }, (_, w) =>
    Array.from({ length: 7 }, (_, d) => dayKey(new Date(start.getFullYear(), start.getMonth(), start.getDate() + w * 7 + d))),
  );
}

// ---------------------------------------------------------------------------
// Achievements
// ---------------------------------------------------------------------------

export type Stats = { clips: number; seconds: number; words: number; known: number; reviews: number; streak: number };
export type Achievement = { id: string; icon: string; title: string; desc: string; metric: "clips" | "minutes" | "words" | "known" | "reviews" | "streak"; goal: number };

export const achievements: Achievement[] = [
  { id: "first-clip", icon: "🎧", title: "First Listen", desc: "Watch your first clip", metric: "clips", goal: 1 },
  { id: "clips-10", icon: "🎬", title: "Ten Clips", desc: "Watch 10 clips", metric: "clips", goal: 10 },
  { id: "words-10", icon: "🔖", title: "Word Collector", desc: "Save 10 words", metric: "words", goal: 10 },
  { id: "review-1", icon: "🔁", title: "First Review", desc: "Answer your first flashcard", metric: "reviews", goal: 1 },
  { id: "streak-3", icon: "🔥", title: "On a Roll", desc: "Reach a 3-day streak", metric: "streak", goal: 3 },
  { id: "time-30", icon: "⏱️", title: "Half Hour Hero", desc: "Study for 30 minutes", metric: "minutes", goal: 30 },
  { id: "clips-50", icon: "🍿", title: "Binge Learner", desc: "Watch 50 clips", metric: "clips", goal: 50 },
  { id: "streak-7", icon: "📅", title: "One Week Strong", desc: "Reach a 7-day streak", metric: "streak", goal: 7 },
  { id: "words-50", icon: "📚", title: "Word Hoarder", desc: "Save 50 words", metric: "words", goal: 50 },
  { id: "time-60", icon: "⚡", title: "Hour of Power", desc: "Study for 60 minutes", metric: "minutes", goal: 60 },
  { id: "known-25", icon: "🌱", title: "Getting Fluent", desc: "Know 25 words", metric: "known", goal: 25 },
  { id: "streak-30", icon: "🏆", title: "Unstoppable", desc: "Reach a 30-day streak", metric: "streak", goal: 30 },
];

export function metricValue(s: Stats, metric: Achievement["metric"]) {
  switch (metric) {
    case "clips": return s.clips;
    case "minutes": return Math.floor(s.seconds / 60);
    case "words": return s.words;
    case "known": return s.known;
    case "reviews": return s.reviews;
    default: return s.streak;
  }
}

export const isUnlocked = (a: Achievement, s: Stats) => metricValue(s, a.metric) >= a.goal;

/** Achievements newly unlocked compared to the already-celebrated ids. */
export const newlyUnlocked = (s: Stats, seen: string[]) => achievements.filter((a) => isUnlocked(a, s) && !seen.includes(a.id));

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

/** Lower-case, katakana → hiragana, strip spaces — so "Neko", "ネコ", "ねこ" all match. */
export function normalizeQuery(s: string) {
  let out = "";
  for (const ch of s.toLowerCase()) {
    const c = ch.codePointAt(0)!;
    if (c >= 0x30a1 && c <= 0x30f6) out += String.fromCodePoint(c - 0x60);
    else if (c !== 0x20 && c !== 0x3000) out += ch;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Kana decks
// ---------------------------------------------------------------------------

export const hiraganaRows: [string, string][] = [
  ["あ", "a"], ["い", "i"], ["う", "u"], ["え", "e"], ["お", "o"],
  ["か", "ka"], ["き", "ki"], ["く", "ku"], ["け", "ke"], ["こ", "ko"],
  ["さ", "sa"], ["し", "shi"], ["す", "su"], ["せ", "se"], ["そ", "so"],
  ["た", "ta"], ["ち", "chi"], ["つ", "tsu"], ["て", "te"], ["と", "to"],
  ["な", "na"], ["に", "ni"], ["ぬ", "nu"], ["ね", "ne"], ["の", "no"],
  ["は", "ha"], ["ひ", "hi"], ["ふ", "fu"], ["へ", "he"], ["ほ", "ho"],
  ["ま", "ma"], ["み", "mi"], ["む", "mu"], ["め", "me"], ["も", "mo"],
  ["や", "ya"], ["ゆ", "yu"], ["よ", "yo"],
  ["ら", "ra"], ["り", "ri"], ["る", "ru"], ["れ", "re"], ["ろ", "ro"],
  ["わ", "wa"], ["を", "wo"], ["ん", "n"],
  ["が", "ga"], ["ぎ", "gi"], ["ぐ", "gu"], ["げ", "ge"], ["ご", "go"],
  ["ざ", "za"], ["じ", "ji"], ["ず", "zu"], ["ぜ", "ze"], ["ぞ", "zo"],
  ["だ", "da"], ["ぢ", "ji"], ["づ", "zu"], ["で", "de"], ["ど", "do"],
  ["ば", "ba"], ["び", "bi"], ["ぶ", "bu"], ["べ", "be"], ["ぼ", "bo"],
  ["ぱ", "pa"], ["ぴ", "pi"], ["ぷ", "pu"], ["ぺ", "pe"], ["ぽ", "po"],
];

/** Hiragana → katakana for the katakana deck. */
export const toKatakana = (s: string) =>
  Array.from(s).map((ch) => { const c = ch.codePointAt(0)!; return c >= 0x3041 && c <= 0x3096 ? String.fromCodePoint(c + 0x60) : ch; }).join("");

export type KanaCard = { id: string; kana: string; romaji: string };

export const kanaDeck = (deck: "hiragana" | "katakana"): KanaCard[] =>
  hiraganaRows.map(([k, r]) => (deck === "katakana" ? { id: `k:${toKatakana(k)}`, kana: toKatakana(k), romaji: r } : { id: `h:${k}`, kana: k, romaji: r }));

// ---------------------------------------------------------------------------
// Cloud sync merge
// ---------------------------------------------------------------------------

/** Merge two keyed maps of records that carry an `updatedAt` (ms). Newer wins;
 * ties keep the local copy. Used for saved words when syncing devices. */
export function mergeByUpdatedAt<T extends { updatedAt?: number }>(local: Record<string, T>, remote: Record<string, T>) {
  const out: Record<string, T> = { ...local };
  for (const [k, r] of Object.entries(remote)) {
    const l = out[k];
    if (!l || (r.updatedAt ?? 0) > (l.updatedAt ?? -1)) out[k] = r;
  }
  return out;
}

/** Merge per-day activity: keep the larger value of each counter. */
export function mergeActivity(a: Record<string, DayActivity>, b: Record<string, DayActivity>) {
  const out: Record<string, DayActivity> = { ...a };
  for (const [k, v] of Object.entries(b)) {
    const x = out[k];
    out[k] = x ? { sec: Math.max(x.sec, v.sec), clips: Math.max(x.clips, v.clips), reviews: Math.max(x.reviews, v.reviews), words: Math.max(x.words, v.words) } : v;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Words & clip search
// ---------------------------------------------------------------------------

export type SearchWord = { s: string; b: string; r: string; ro: string; p: string; d: string | null };
export type SearchClip = { id: string; level: string; topics: string[]; grammar: string[]; lines: { ja: string; en: string; words: SearchWord[] }[] };

/** Stable key for a saved word: dictionary id when known, else its dictionary form. */
export const wordKeyOf = (dictId: string | null | undefined, base: string) => (dictId != null ? `d${dictId}` : `b${base}`);

/** Unique word keys in a clip (punctuation skipped), in order of appearance. */
export function clipWordKeys(c: SearchClip) {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const l of c.lines) for (const w of l.words) {
    if (w.p === "punct") continue;
    const k = wordKeyOf(w.d, w.b || w.s);
    if (!seen.has(k)) { seen.add(k); out.push(k); }
  }
  return out;
}

export const grammarKey = (g: string) => (g.split("—")[0] ?? g).trim();

function matchScore(c: SearchClip, q: string, qLower: string) {
  let best = 0;
  for (const l of c.lines) {
    for (const w of l.words) {
      if (w.p === "punct") continue;
      const forms = [normalizeQuery(w.s), normalizeQuery(w.b), normalizeQuery(w.r), w.ro.toLowerCase()];
      if (forms.includes(q)) return 3;
      if (q.length >= 2 && forms.some((f) => f.startsWith(q))) best = Math.max(best, 2);
    }
    if (normalizeQuery(l.ja).includes(q)) best = Math.max(best, 1);
    if (qLower.length >= 3 && l.en.toLowerCase().includes(qLower)) best = Math.max(best, 1);
  }
  return best;
}

/** Clip ids matching a word/text query (Japanese, kana, romaji or English) and filters. */
export function searchClips(clips: SearchClip[], query: string, f: { level?: string | null; topic?: string | null; grammar?: string | null } = {}) {
  const q = normalizeQuery(query);
  const qLower = query.trim().toLowerCase();
  const hits: { c: SearchClip; s: number }[] = [];
  for (const c of clips) {
    if (f.level && c.level !== f.level) continue;
    if (f.topic && !c.topics.includes(f.topic)) continue;
    if (f.grammar && !c.grammar.some((g) => grammarKey(g) === f.grammar)) continue;
    const s = q === "" ? 1 : matchScore(c, q, qLower);
    if (s > 0) hits.push({ c, s });
  }
  hits.sort((a, b) => {
    if (a.s !== b.s) return b.s - a.s;
    const l = jlptIndex(a.c.level) - jlptIndex(b.c.level);
    return l !== 0 ? l : a.c.id < b.c.id ? -1 : a.c.id > b.c.id ? 1 : 0;
  });
  return hits.map((h) => h.c.id);
}

// ---------------------------------------------------------------------------
// Saved words: review queue + counts
// ---------------------------------------------------------------------------

export type WordLite = { key: string; status: "learning" | "known" | "ignored" | "removed"; card: Card; addedAt: number };

/** Saved words due for review now, oldest due first. Manually-known, ignored and
 * removed words are never reviewed. */
export function dueWordKeys(words: WordLite[], now: number) {
  return words
    .filter((w) => w.status === "learning" && isDue(w.card, now))
    .sort((a, b) => (a.card.due !== b.card.due ? a.card.due - b.card.due : a.key < b.key ? -1 : a.key > b.key ? 1 : 0))
    .map((w) => w.key);
}

export function wordCounts(words: WordLite[], now: number) {
  let learning = 0, known = 0, due = 0;
  for (const w of words) {
    if (w.status === "ignored" || w.status === "removed") continue;
    if (wordStatus({ status: w.status, card: w.card }) === "known") known++;
    else learning++;
    if (w.status === "learning" && isDue(w.card, now)) due++;
  }
  return { saved: learning + known, learning, known, due };
}

// ---------------------------------------------------------------------------
// Whole-state merge for cloud sync (JSON shape of store.ts / app_state.dart)
// ---------------------------------------------------------------------------

/* eslint-disable @typescript-eslint/no-explicit-any */
type Json = any;

/** Merge two saved learner states. Per-word newest wins, activity/seen/totals keep the
 * max, history/achievements union; profile, settings and other single values come
 * from whichever state changed last. */
export function mergeState(local: Json, remote: Json): Json {
  const newer = (remote.updatedAt ?? 0) > (local.updatedAt ?? 0) ? remote : local;
  const kana: Json = { ...(local.kana ?? {}) };
  for (const [k, c] of Object.entries((remote.kana ?? {}) as Record<string, Json>)) {
    if (!kana[k] || (c.reps ?? 0) > (kana[k].reps ?? 0)) kana[k] = c;
  }
  const seen: Json = { ...(local.seen ?? {}) };
  for (const [k, n] of Object.entries((remote.seen ?? {}) as Json)) seen[k] = Math.max(seen[k] ?? 0, n as number);
  const hist = new Map<string, Json>();
  for (const h of [...(local.history ?? []), ...(remote.history ?? [])]) hist.set(`${h.clipId}@${h.at}`, h);
  const history = [...hist.values()].sort((a, b) => b.at - a.at).slice(0, 200);
  const lt = local.totals ?? {}, rt = remote.totals ?? {};
  return {
    ...newer,
    onboarded: !!(local.onboarded || remote.onboarded),
    // Premium never syncs: each device keeps its own, verified by its store.
    premium: local.premium,
    purchaseAccountPending: !!local.purchaseAccountPending,
    words: mergeByUpdatedAt(local.words ?? {}, remote.words ?? {}),
    kana,
    seen,
    history,
    activity: mergeActivity(local.activity ?? {}, remote.activity ?? {}),
    totals: { clips: Math.max(lt.clips ?? 0, rt.clips ?? 0), seconds: Math.max(lt.seconds ?? 0, rt.seconds ?? 0), reviews: Math.max(lt.reviews ?? 0, rt.reviews ?? 0) },
    achievementsSeen: [...new Set([...(local.achievementsSeen ?? []), ...(remote.achievementsSeen ?? [])])].sort(),
    reviewSessions: Math.max(local.reviewSessions ?? 0, remote.reviewSessions ?? 0),
    updatedAt: Math.max(local.updatedAt ?? 0, remote.updatedAt ?? 0),
  };
}

// ---------------------------------------------------------------------------
// Free tier + "hear it again"
// ---------------------------------------------------------------------------

/** Only active trial/paid learners can watch; legacy quota arguments stay compatible. */
export const canWatchClip = (premiumActive: boolean, _clipsToday: number, _freeLimit: number) => premiumActive;

/** Other clips that contain a word key, best level-fit first, excluding the current clip. */
export function clipsWithWord(clips: SearchClip[], key: string, excludeId: string, jlpt: string, limit = 6) {
  const out: { id: string; d: number }[] = [];
  for (const c of clips) {
    if (c.id === excludeId) continue;
    if (!clipWordKeys(c).includes(key)) continue;
    out.push({ id: c.id, d: Math.abs(jlptIndex(c.level) - jlptIndex(jlpt)) });
  }
  out.sort((a, b) => (a.d !== b.d ? a.d - b.d : a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return out.slice(0, limit).map((x) => x.id);
}

// ---------------------------------------------------------------------------
// Review queues: kana decks + custom study
// ---------------------------------------------------------------------------

/** Kana session: due cards (soonest first), then up to `newLimit` unseen characters in deck order. */
export function kanaQueue(deck: KanaCard[], cards: Record<string, Card>, now: number, newLimit = 10) {
  const due = deck.filter((k) => cards[k.id] && isDue(cards[k.id]!, now)).sort((a, b) => cards[a.id]!.due - cards[b.id]!.due).map((k) => k.id);
  const fresh = deck.filter((k) => !cards[k.id]).slice(0, newLimit).map((k) => k.id);
  return [...due, ...fresh];
}

/** Characters that have graduated to review in a kana deck. */
export const kanaLearned = (deck: KanaCard[], cards: Record<string, Card>) => deck.filter((k) => cards[k.id]?.state === "review").length;

/** "Keep studying" after the due queue: learning words not yet due, soonest first. */
export function customStudyKeys(words: WordLite[], now: number, limit = 20) {
  return words
    .filter((w) => w.status === "learning" && !isDue(w.card, now))
    .sort((a, b) => (a.card.due !== b.card.due ? a.card.due - b.card.due : a.key < b.key ? -1 : 1))
    .slice(0, limit)
    .map((w) => w.key);
}

// ---------------------------------------------------------------------------
// Ask Kizuki — AI follow-up questions about a line or word
// ---------------------------------------------------------------------------

/** Longest question a learner can type. */
export const ASK_MAX_CHARS = 400;

/** How many chat messages are sent to the tutor with each question. */
export const ASK_MAX_MESSAGES = 10;

/** Questions asked today; the counter resets on a new day. */
export const asksToday = (day: string, n: number, today: string) => (day === today ? n : 0);

/** Only active trial/paid learners can ask; no free learning tier. */
export const canAsk = (premiumActive: boolean, _asked: number, _freeLimit: number) => premiumActive;

/** Free questions left today, or null when unlimited. */
export const asksLeft = (premiumActive: boolean, _asked: number, _freeLimit: number): number | null => (premiumActive ? null : 0);

/** Typed question → what gets sent: whitespace collapsed, trimmed, capped at ASK_MAX_CHARS. */
export function cleanQuestion(s: string) {
  const t = s.replace(/\s+/g, " ").trim();
  return t.length > ASK_MAX_CHARS ? t.slice(0, ASK_MAX_CHARS).trim() : t;
}

export type AskTurn = { role: "user" | "assistant"; text: string };

/** Chat history sent with a question: non-empty turns, the last `max`, starting with a user turn. */
export function askHistory<T extends AskTurn>(msgs: T[], max = ASK_MAX_MESSAGES): T[] {
  const kept = msgs.filter((m) => m.text.trim() !== "");
  let out = kept.length > max ? kept.slice(kept.length - max) : kept;
  while (out.length && out[0]!.role !== "user") out = out.slice(1);
  return out;
}

// ---------------------------------------------------------------------------
// Help & support messages (stored in public.support_messages; limits match its checks)
// ---------------------------------------------------------------------------

export const SUPPORT_MESSAGE_MIN = 5;
export const SUPPORT_MESSAGE_MAX = 2000;
export const SUPPORT_TOPICS = ["subscription", "account", "bug", "content", "feedback", "other"] as const;
export type SupportTopic = (typeof SUPPORT_TOPICS)[number];

/** Problem with a support message, or null when it can be sent. Email trimmed + lowercased by the caller. */
export function supportMessageError(email: string, message: string): string | null {
  const e = email.trim();
  if (e.length < 3 || e.length > 255 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) return "Enter the email we should reply to.";
  const m = message.trim();
  if (m.length < SUPPORT_MESSAGE_MIN) return "Tell us a little more (at least 5 characters).";
  if (m.length > SUPPORT_MESSAGE_MAX) return `Keep it under ${SUPPORT_MESSAGE_MAX} characters.`;
  return null;
}

/** Completed checkout must be followed by a verified account. */
export const purchaseNeedsAccount = (pending: boolean, verified: boolean) => pending && !verified;

// ---------------------------------------------------------------------------
// Server content packs: more clips without an app update. The bundled library always stays
// the default; a pack is used only after every file was downloaded and verified, from the
// next app start. Mirrors mobile/lib/logic/logic.dart.
// ---------------------------------------------------------------------------

export const CONTENT_PACK_FORMAT = 1;
export const CONTENT_PACK_MAX_FILES = 64;
export const CONTENT_PACK_MAX_FILE_BYTES = 40_000_000;
export type ContentPackFile = { name: string; sha256: string; bytes: number };
export type ContentPackManifest = { version: number; files: ContentPackFile[]; notes: string[] };
export type ContentPackAction = "bundled" | "keep" | "download";

const PACK_FILE_NAME = /^[a-z0-9][a-z0-9-]{0,40}\.json$/;
const SHA256_HEX = /^[0-9a-f]{64}$/;
const CLIP_ID = /^[A-Za-z0-9_-]{1,64}$/;
type PackField = "format" | "version" | "files" | "name" | "sha256" | "bytes" | "notes" | "videos" | "title" | "channel" | "channelUrl" | "parts" | "starter"
  | "id" | "level" | "topics" | "grammar" | "quality" | "videoId" | "start" | "end" | "lines" | "words" | "s" | "t0" | "t1" | "w" | "r" | "m" | "ex" | "l" | "n" | "lit" | "tip";
type PackRecord = { [K in PackField]?: unknown } & Record<string, unknown>;
const isRecord = (v: unknown): v is PackRecord => typeof v === "object" && v !== null && !Array.isArray(v);
const isWhole = (v: unknown): v is number => typeof v === "number" && Number.isInteger(v);
const isNum = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);
const hasKey = (o: Record<string, unknown>, k: string) => Object.prototype.hasOwnProperty.call(o, k);
const allStrings = (v: unknown) => Array.isArray(v) && v.every((x) => typeof x === "string");

/** What to do with the server's content row: stay on the bundled library, keep the pack
 * already downloaded, or fetch the newer one. Off switch, a missing link or a version that
 * is not newer than the bundle all mean the bundle. */
export function contentPackAction(enabled: unknown, version: unknown, url: unknown, bundledVersion: number, activeVersion: number | null): ContentPackAction {
  if (enabled === false) return "bundled";
  if (!isWhole(version) || version <= bundledVersion || founderVideoUrl(url) === null) return "bundled";
  return version === activeVersion ? "keep" : "download";
}

/** A pack manifest the app can trust, or null: known format, the advertised version, safe
 * file names, sha-256 checksums, bounded sizes, and the index + dictionary present. */
export function contentPackManifest(raw: unknown, expectedVersion: number): ContentPackManifest | null {
  if (!isRecord(raw) || raw.format !== CONTENT_PACK_FORMAT || !isWhole(raw.version) || raw.version !== expectedVersion) return null;
  const files = raw.files;
  if (!Array.isArray(files) || files.length < 1 || files.length > CONTENT_PACK_MAX_FILES) return null;
  const out: ContentPackFile[] = [];
  const names = new Set<string>();
  for (const f of files) {
    if (!isRecord(f)) return null;
    const { name, sha256, bytes } = f;
    if (typeof name !== "string" || !PACK_FILE_NAME.test(name) || names.has(name)) return null;
    if (typeof sha256 !== "string" || !SHA256_HEX.test(sha256)) return null;
    if (!isWhole(bytes) || bytes < 1 || bytes > CONTENT_PACK_MAX_FILE_BYTES) return null;
    names.add(name);
    out.push({ name, sha256, bytes });
  }
  if (!names.has("content.json") || !names.has("dict.json")) return null;
  const notes = raw.notes ?? [];
  if (!Array.isArray(notes) || notes.length > CONTENT_PACK_MAX_FILES) return null;
  if (notes.some((n) => typeof n !== "string" || !names.has(n) || n === "content.json" || n === "dict.json") || new Set(notes).size !== notes.length) return null;
  return { version: raw.version, files: out, notes: notes as string[] };
}

/** Pack files are stored once by checksum next to the manifests (…/packs/v2.json → …/objects/<sha>.json.gz). */
export const contentObjectUrl = (manifestUrl: string, sha256: string): string => new URL(`../objects/${sha256}.json.gz`, manifestUrl).href;

/** Which notes file holds a clip's explanations (FNV-1a over UTF-16 code units). */
export function notesShard(clipId: string, count: number): number {
  return count < 1 ? -1 : fnv1a(clipId) % count;
}

/** Problem with a pack's content.json, or null. */
export function contentIndexProblem(index: unknown, manifest: ContentPackManifest): string | null {
  if (!isRecord(index)) return "index";
  if (index.version !== manifest.version) return "version";
  const videos = index.videos;
  if (!isRecord(videos) || Object.keys(videos).length === 0) return "videos";
  for (const v of Object.values(videos)) if (!isRecord(v) || typeof v.title !== "string" || typeof v.channel !== "string" || typeof v.channelUrl !== "string") return "videos";
  const names = new Set(manifest.files.map((f) => f.name));
  const parts = index.parts;
  if (!Array.isArray(parts) || parts.length === 0 || new Set(parts).size !== parts.length) return "parts";
  for (const p of parts) if (typeof p !== "string" || !names.has(p) || p === "content.json" || p === "dict.json" || manifest.notes.includes(p)) return "parts";
  if (index.starter != null && !allStrings(index.starter)) return "starter";
  return null;
}

/** Problem with one clip of a pack, or null (fields every screen reads). */
export function contentClipProblem(clip: unknown, videos: Record<string, unknown>): string | null {
  if (!isRecord(clip) || typeof clip.id !== "string" || !CLIP_ID.test(clip.id) || typeof clip.title !== "string" || typeof clip.level !== "string") return "clip";
  if (!allStrings(clip.topics) || !allStrings(clip.grammar) || (clip.quality != null && !isNum(clip.quality))) return "clip";
  if (typeof clip.videoId !== "string" || !hasKey(videos, clip.videoId)) return "video";
  if (!isNum(clip.start) || !isNum(clip.end) || !(clip.end > clip.start)) return "window";
  const lines = clip.lines;
  if (!Array.isArray(lines) || lines.length === 0) return "lines";
  for (const l of lines) {
    if (!isRecord(l) || !isNum(l.start) || !isNum(l.end) || !Array.isArray(l.words)) return "lines";
    for (const w of l.words) if (!isRecord(w) || typeof w.s !== "string" || !isNum(w.t0) || !isNum(w.t1)) return "lines";
  }
  return null;
}

/** Problem with a pack's dictionary, or null. */
export function contentDictProblem(dict: unknown): string | null {
  if (!isRecord(dict) || Object.keys(dict).length === 0) return "dict";
  for (const e of Object.values(dict)) if (!isRecord(e) || typeof e.w !== "string" || typeof e.r !== "string" || !Array.isArray(e.m) || !Array.isArray(e.ex)) return "dict";
  return null;
}

/** Problem with a pack's notes file (clip id → explanations), or null. */
export function contentNotesProblem(shard: unknown): string | null {
  if (!isRecord(shard)) return "notes";
  for (const n of Object.values(shard)) {
    if (!isRecord(n)) return "notes";
    const w = n.w ?? {}, l = n.l ?? {};
    if (!isRecord(w) || !isRecord(l)) return "notes";
    for (const x of Object.values(w)) if (!isRecord(x) || typeof x.m !== "string" || typeof x.n !== "string") return "notes";
    for (const x of Object.values(l)) if (!isRecord(x) || typeof x.lit !== "string" || typeof x.tip !== "string") return "notes";
  }
  return null;
}

// ---------------------------------------------------------------- learner languages
// The app speaks the learner's language (interface + clip translations + explanations).
// English is bundled and always the fallback; mirrored in mobile/lib/logic/logic.dart.

export type LangCode = "en" | "vi" | "id" | "th" | "ko" | "pt";

export interface Language {
  code: LangCode;
  flag: string;
  /** Name in the language itself — what the picker shows. */
  native: string;
  /** English name, under the native one. */
  english: string;
}

export const LANGUAGES: Language[] = [
  { code: "en", flag: "🇺🇸", native: "English", english: "English" },
  { code: "vi", flag: "🇻🇳", native: "Tiếng Việt", english: "Vietnamese" },
  { code: "id", flag: "🇮🇩", native: "Bahasa Indonesia", english: "Indonesian" },
  { code: "th", flag: "🇹🇭", native: "ภาษาไทย", english: "Thai" },
  { code: "ko", flag: "🇰🇷", native: "한국어", english: "Korean" },
  { code: "pt", flag: "🇧🇷", native: "Português (Brasil)", english: "Portuguese (Brazil)" },
];

export function isLangCode(x: unknown): x is LangCode {
  return typeof x === "string" && LANGUAGES.some((l) => l.code === x);
}

/** Language suggested by the phone/browser locale ("vi-VN", "in_ID", "pt-PT"…); English otherwise. */
export function languageForLocale(tag: string | null | undefined): LangCode {
  const base = (tag ?? "").toLowerCase().replace(/_/g, "-").split("-")[0];
  if (base === "in") return "id"; // older Android code for Indonesian
  return isLangCode(base) ? base : "en";
}

/** Fills `{name}` placeholders of a translated string; unknown names stay as written. */
export function fillTemplate(text: string, vars?: Record<string, string | number>): string {
  if (!vars) return text;
  return text.replace(/\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k]) : m));
}

/** Splits text on its [highlighted] part, so each language can place the highlight where its
 * grammar puts it ("Try Kizuki [free] for 7 days"). Pairs are [text, highlighted]. */
export function highlightParts(text: string): [string, boolean][] {
  const out: [string, boolean][] = [];
  let i = 0;
  for (const m of text.matchAll(/\[([^[\]]*)\]/g)) {
    const start = m.index ?? 0;
    if (start > i) out.push([text.slice(i, start), false]);
    if (m[1]) out.push([m[1], true]);
    i = start + m[0].length;
  }
  if (i < text.length) out.push([text.slice(i), false]);
  return out;
}

/** Files that hold a language pack's explanation notes (clips spread by id). */
export const LOCALE_NOTE_SHARDS = 32;

export function localeNoteShard(clipId: string): number {
  return fnv1a(clipId) % LOCALE_NOTE_SHARDS;
}

/** Fingerprint of a clip's Japanese text + word split. A translation made for other words
 * (the clip was regenerated) never shows: the clip stays in English until re-translated. */
export function clipLocaleSig(lines: { ja: string; words: { s: string }[] }[]): string {
  return fnv1a(lines.map((l) => `${l.ja}|${l.words.map((w) => w.s).join(" ")}`).join("\n")).toString(16).padStart(8, "0");
}

/** Whether to download a language pack now: a non-English language, learning access (trial or
 * Premium — nobody downloads before deciding to learn) and a pack newer than the installed one. */
export function localePackDue(lang: LangCode, hasAccess: boolean, installed: number, latest: number | null): boolean {
  return lang !== "en" && hasAccess && latest != null && latest > installed;
}

/** Wait before the next download attempt after `failures` failed ones: 5 s doubling, max 30 min. */
export function localeRetryDelayMs(failures: number): number {
  return Math.min(30 * 60_000, 5_000 * 2 ** Math.max(0, Math.min(failures, 20)));
}

export interface LocalePackFile {
  name: string;
  sha256: string;
  bytes: number;
}

export interface LocalePackManifest {
  lang: LangCode;
  version: number;
  files: LocalePackFile[];
}

const LOCALE_FILE = /^(lines|dict|grammar|notes-\d{2})\.json$/;

/** The validated manifest of a language pack, or null: right language and version, every file
 * named once with a sha-256 and size, all required files present. */
export function localePackManifest(raw: unknown, lang: LangCode, version: number): LocalePackManifest | null {
  if (!isRecord(raw) || raw["lang"] !== lang || raw["version"] !== version || !Array.isArray(raw["files"])) return null;
  const files: LocalePackFile[] = [];
  const names = new Set<string>();
  for (const f of raw["files"]) {
    if (!isRecord(f) || typeof f["name"] !== "string" || !LOCALE_FILE.test(f["name"]) || names.has(f["name"])) return null;
    if (typeof f["sha256"] !== "string" || !/^[0-9a-f]{64}$/.test(f["sha256"])) return null;
    if (typeof f["bytes"] !== "number" || !Number.isInteger(f["bytes"]) || f["bytes"] <= 0) return null;
    names.add(f["name"]);
    files.push({ name: f["name"], sha256: f["sha256"], bytes: f["bytes"] });
  }
  for (const need of ["lines.json", "dict.json", "grammar.json"]) if (!names.has(need)) return null;
  for (let i = 0; i < LOCALE_NOTE_SHARDS; i++) if (!names.has(`notes-${String(i).padStart(2, "0")}.json`)) return null;
  return { lang, version, files };
}

/** Problem with a language pack file's parsed JSON, or null. */
export function localeFileProblem(name: string, j: unknown): string | null {
  if (!isRecord(j)) return "shape";
  const str = (x: unknown) => typeof x === "string";
  if (name === "lines.json") {
    for (const v of Object.values(j)) {
      if (!isRecord(v) || !str(v["s"]) || !str(v["t"]) || !Array.isArray(v["l"]) || !v["l"].every(str)) return "lines";
    }
    return Object.keys(j).length ? null : "lines";
  }
  if (name === "dict.json") {
    for (const v of Object.values(j)) {
      if (!isRecord(v) || !Array.isArray(v["m"]) || !v["m"].every(str) || !Array.isArray(v["ex"]) || !v["ex"].every(str)) return "dict";
    }
    return Object.keys(j).length ? null : "dict";
  }
  if (name === "grammar.json") {
    return Object.values(j).every(str) ? null : "grammar";
  }
  for (const v of Object.values(j)) {
    if (!isRecord(v) || !str(v["s"]) || !isRecord(v["w"]) || !isRecord(v["l"])) return "notes";
    for (const x of Object.values(v["w"])) if (!isRecord(x) || !str(x["m"]) || !str(x["n"])) return "notes";
    for (const x of Object.values(v["l"])) if (!isRecord(x) || !str(x["lit"]) || !str(x["tip"])) return "notes";
  }
  return null;
}

/** Where a language pack lives, from the public content_settings.locale_packs row:
 * `{ vi: { v: 3, urls: [primary manifest, mirror manifest] } }`. Null = no pack (English content). */
export interface LocalePackPointer {
  version: number;
  urls: string[];
}

export function localePackPointer(raw: unknown, lang: LangCode): LocalePackPointer | null {
  if (lang === "en" || !isRecord(raw)) return null;
  const e = raw[lang];
  if (!isRecord(e) || !isWhole(e["v"]) || e["v"] < 1 || !Array.isArray(e["urls"])) return null;
  const list = e["urls"] as unknown[];
  if (list.length < 1 || list.length > 3) return null;
  const urls = list.map((u) => founderVideoUrl(u));
  return urls.every((u): u is string => u !== null) ? { version: e["v"], urls } : null;
}

export type LocaleLine = { s: string; t: string; l: string[] };
export type LocaleEntry = { m: string[]; ex: string[] };
export type LocaleNote = { s: string; w: Record<string, { m: string; n: string }>; l: Record<string, { lit: string; tip: string }> };

/** A clip in the learner's language: title + line translations only when the pack was made for
 * exactly this clip (fingerprint and line count), grammar descriptions by their English text.
 * Anything missing or empty stays English. */
export function localizeClip<C extends { title: string; grammar: string[]; lines: { en: string; ja: string; words: { s: string }[] }[] }>(
  clip: C, entry: LocaleLine | undefined, grammar: Record<string, string> | null,
): C {
  const g = grammar ? clip.grammar.map((x) => grammar[x] || x) : clip.grammar;
  const fits = !!entry && entry.s === clipLocaleSig(clip.lines) && entry.l.length === clip.lines.length;
  if (!fits) return g === clip.grammar ? clip : { ...clip, grammar: g };
  return {
    ...clip,
    title: entry.t.trim() || clip.title,
    grammar: g,
    lines: clip.lines.map((l, i) => ({ ...l, en: entry.l[i]?.trim() || l.en })),
  };
}

/** A dictionary entry in the learner's language when sense and example counts match. */
export function localizeEntry<E extends { m: { pos: string[]; g: string }[]; ex: { ja: string; en: string }[] }>(e: E, d: LocaleEntry | undefined): E {
  if (!d || d.m.length !== e.m.length || d.ex.length !== e.ex.length) return e;
  return { ...e, m: e.m.map((s, i) => ({ ...s, g: d.m[i]?.trim() || s.g })), ex: e.ex.map((x, i) => ({ ...x, en: d.ex[i]?.trim() || x.en })) };
}

/** A clip's explanations in the learner's language, only for the clip they were made for. */
export function localizeNotes(
  notes: { w: Record<string, { m: string; n: string }>; l: Record<string, { lit: string; tip: string }> },
  n: LocaleNote | undefined, sig: string,
): { w: Record<string, { m: string; n: string }>; l: Record<string, { lit: string; tip: string }> } {
  if (!n || n.s !== sig) return notes;
  const w: Record<string, { m: string; n: string }> = {};
  for (const [k, v] of Object.entries(notes.w)) {
    const t = n.w[k];
    w[k] = t && t.m.trim() && t.n.trim() ? { m: t.m.trim(), n: t.n.trim() } : v;
  }
  const l: Record<string, { lit: string; tip: string }> = {};
  for (const [k, v] of Object.entries(notes.l)) {
    const t = n.l[k];
    l[k] = t ? { lit: v.lit ? t.lit.trim() || v.lit : v.lit, tip: v.tip ? t.tip.trim() || v.tip : v.tip } : v;
  }
  return { w, l };
}
