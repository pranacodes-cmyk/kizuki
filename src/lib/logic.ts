// Business rules for Kizuki. Kept 1:1 with mobile/lib/logic/logic.dart (mirrored tests in
// src/lib/logic.test.ts and mobile/test/logic_test.dart). UI code calls these helpers
// instead of re-deriving rules.

// ---------------------------------------------------------------------------
// Onboarding answers
// ---------------------------------------------------------------------------

export const reasons = ["travel", "anime", "work", "fun", "friends", "family", "romance", "culture"] as const;
export const challenges = ["listening", "start", "motivation", "grammar", "speaking", "vocab"] as const;
export const studyWindows = ["morning", "afternoon", "evening", "night"] as const;
export const streakGoals = [7, 14, 30, 50] as const;
export const jlptLevels = ["N5", "N4", "N3", "N2", "N1"] as const;

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
  return `${monthNames[total % 12]} ${now.getFullYear() + Math.floor(total / 12)}`;
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
    case "morning": return "in the morning";
    case "afternoon": return "in the afternoon";
    case "evening": return "in the evening";
    default: return "at night";
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
    case "motivation": return { icon: "🔥", title: `A ${streakGoal}-day streak goal`, body: `Friendly reminders ${windowLabel(window)}` };
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
    { icon: "⏰", title: `${o.dailyMinutes}-minute daily sessions`, body: `Bite-sized clips ${windowLabel(o.window)}` },
    reasonItem(o.reasonList[0] ?? "fun"),
    challengeItem(o.challengeList[0] ?? "listening", o.streakGoal, o.window),
    { icon: "📈", title: `${wordsPerMonth(o.dailyMinutes)} new words a month`, body: `At ${o.dailyMinutes} minutes a day` },
    { icon: "🎬", title: `${o.clipCount} clips picked for you`, body: `Matched to your level (${o.jlpt}) and interests` },
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
  const norm = (x: string) => x.toLowerCase().replace(/\([^)]*\)/g, " ").replace(/[^a-z0-9' ]+/g, " ").replace(/\s+/g, " ").trim();
  const g = norm(gloss);
  if (!g) return true;
  if (!sense) return false;
  return norm(sense) === g || sense.split(/[;,]/).some((p) => norm(p) === g);
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

/** Free learners get `freeLimit` clips a day; premium (incl. trial) is unlimited. */
export const canWatchClip = (premiumActive: boolean, clipsToday: number, freeLimit: number) => premiumActive || clipsToday < freeLimit;

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

/** Free learners get `freeLimit` questions a day; premium (incl. trial) is unlimited. */
export const canAsk = (premiumActive: boolean, asked: number, freeLimit: number) => premiumActive || asked < freeLimit;

/** Free questions left today, or null when unlimited. */
export const asksLeft = (premiumActive: boolean, asked: number, freeLimit: number): number | null => (premiumActive ? null : Math.max(0, freeLimit - asked));

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
