// Mirrors mobile/test/logic_test.dart — keep cases and expected values identical.
import { describe, expect, it } from "vitest";

import {
  purchaseNeedsAccount, ReviewSession, SUPPORT_TOPICS, supportMessageError, answerCard, bestStreak, clipScore, currentStreak, dayKey, dayMs, fnv1a, formatInterval, goalDateLabel,
  heatLevel, heatmapWeeks, kanaDeck, levelToJlpt, mergeActivity, mergeByUpdatedAt, minuteMs, minutesLeft, newCard,
  newlyUnlocked, nextIntervalLabel, normalizeQuery, planItems, rankFeed, recommendedMinutes, toKatakana, wordStatus, wordsPerMonth,
  searchClips, clipWordKeys, wordKeyOf, dueWordKeys, wordCounts, mergeState, canWatchClip, clipsWithWord, kanaQueue, kanaLearned, customStudyKeys,
  asksToday, canAsk, asksLeft, cleanQuestion, askHistory, type AskTurn,
  wordLevel, cardAtLevel, withWordLevel, WORD_LEVELS, repeatsSense, pickTourWord,
  type RankClip,
} from "./logic";

const NOW = 1_800_000_000_000;

describe("onboarding rules", () => {
  it("purchase requires verified login", () => {
    expect(purchaseNeedsAccount(true, false)).toBe(true);
    expect(purchaseNeedsAccount(true, true)).toBe(false);
    expect(purchaseNeedsAccount(false, false)).toBe(false);
  });
  it("pending account stays local during sync", () => {
    expect(mergeState({ purchaseAccountPending: true }, { purchaseAccountPending: false, updatedAt: 10 }).purchaseAccountPending).toBe(true);
  });
  it("maps self-reported level to JLPT band", () => {
    expect([0, 1, 2, 3, 4].map(levelToJlpt)).toEqual(["N5", "N5", "N4", "N3", "N2"]);
  });
  it("estimates words per month from daily minutes", () => {
    expect(wordsPerMonth(25)).toBe(510);
    expect(wordsPerMonth(5)).toBe(102);
  });
  it("recommends daily minutes for a fluency goal", () => {
    expect(recommendedMinutes(9)).toBe(25);
    expect(recommendedMinutes(12)).toBe(20);
    expect(recommendedMinutes(3)).toBe(60);
    expect(recommendedMinutes(36)).toBe(5);
  });
  it("labels the goal month", () => {
    expect(goalDateLabel(new Date(2026, 9, 21), 9)).toBe("Jul 2027");
    expect(goalDateLabel(new Date(2026, 0, 5), 12)).toBe("Jan 2027");
  });
  it("plan reflects the chosen minutes, reason and level", () => {
    const items = planItems({ reasonList: ["anime"], challengeList: ["motivation"], dailyMinutes: 25, window: "night", streakGoal: 14, jlpt: "N4", clipCount: 120 });
    expect(items[0]!.title).toBe("25-minute daily sessions");
    expect(items[1]!.title).toBe("Understand anime without subtitles");
    expect(items[2]!.title).toBe("A 14-day streak goal");
    expect(items[2]!.body).toBe("Friendly reminders at night");
    expect(items[3]!.title).toBe("510 new words a month");
    expect(items[4]!.body).toBe("Matched to your level (N4) and interests");
  });
});

describe("feed ranking", () => {
  it("hashes like the Dart client", () => {
    expect(fnv1a("a")).toBe(3826002220);
    expect(fnv1a("mimi:abc-12")).toBe(fnv1a("mimi:abc-12"));
  });
  const clips: RankClip[] = [
    { id: "a-1", videoId: "a", level: "N5", topics: ["anime"], quality: 5 },
    { id: "a-2", videoId: "a", level: "N5", topics: ["anime"], quality: 5 },
    { id: "b-1", videoId: "b", level: "N3", topics: ["work"], quality: 4 },
    { id: "c-1", videoId: "c", level: "N5", topics: ["travel"], quality: 3 },
  ];
  const ctx = { reasonList: ["anime"], jlpt: "N5", seen: {}, seed: "s1" };
  it("prefers clips that match interests and level", () => {
    expect(clipScore(clips[0]!, ctx)).toBeGreaterThan(clipScore(clips[2]!, ctx));
  });
  it("never plays the same video twice in a row when it can avoid it", () => {
    const order = rankFeed(clips, ctx);
    expect(order.length).toBe(4);
    for (let i = 1; i < order.length; i++) expect(order[i]!.split("-")[0]).not.toBe(order[i - 1]!.split("-")[0]);
  });
  it("a still-picture (podcast) clip ranks below the same clip as real video", () => {
    const pair: RankClip[] = [
      { id: "p-1", videoId: "p", level: "N5", topics: ["anime"], quality: 5, still: true },
      { id: "v-1", videoId: "v", level: "N5", topics: ["anime"], quality: 5 },
    ];
    for (const seed of ["s1", "s2", "s3", "x"]) expect(rankFeed(pair, { ...ctx, seed })).toEqual(["v-1", "p-1"]);
    expect(clipScore(pair[1]!, { ...ctx, seed: "none" }) - clipScore(pair[0]!, { ...ctx, seed: "none" })).toBeCloseTo(
      6 + ((fnv1a("none:v-1") % 1000) / 1000) * 2.5 - ((fnv1a("none:p-1") % 1000) / 1000) * 2.5, 9);
  });
  it("pushes already-seen clips down", () => {
    const order = rankFeed(clips, { ...ctx, seen: { "a-1": 2, "a-2": 2 } });
    expect(order[0]).toBe("c-1");
  });
});

describe("spaced repetition", () => {
  it("new card: again → 1 minute, good → 10 minutes", () => {
    const c = newCard(NOW);
    expect(answerCard(c, "again", NOW).due).toBe(NOW + minuteMs);
    const g = answerCard(c, "good", NOW);
    expect(g.state).toBe("learning");
    expect(g.due).toBe(NOW + 10 * minuteMs);
  });
  it("learning card graduates to 1 day, then grows by ease", () => {
    const l = answerCard(answerCard(newCard(NOW), "good", NOW), "good", NOW);
    expect(l.state).toBe("review");
    expect(l.interval).toBe(1);
    expect(l.due).toBe(NOW + dayMs);
    const r = answerCard(l, "good", NOW);
    expect(r.interval).toBe(3); // max(1 + 1, round(1 × 2.5))
    const r2 = answerCard(r, "good", NOW);
    expect(r2.interval).toBe(8); // round(3 × 2.5)
  });
  it("lapse lowers ease and relearns at half the interval", () => {
    const review = { ...newCard(NOW), state: "review" as const, interval: 10, ease: 2.5 };
    const lapsed = answerCard(review, "again", NOW);
    expect(lapsed.state).toBe("relearning");
    expect(lapsed.ease).toBeCloseTo(2.3);
    expect(lapsed.lapses).toBe(1);
    const back = answerCard(lapsed, "good", NOW);
    expect(back.state).toBe("review");
    expect(back.interval).toBe(5);
  });
  it("labels intervals", () => {
    expect(formatInterval(30_000)).toBe("<1m");
    expect(formatInterval(10 * minuteMs)).toBe("10m");
    expect(formatInterval(3 * 3600_000)).toBe("3h");
    expect(formatInterval(3 * dayMs)).toBe("3d");
    expect(formatInterval(60 * dayMs)).toBe("2mo");
    expect(nextIntervalLabel(newCard(NOW), "again", NOW)).toBe("1m");
    expect(nextIntervalLabel(newCard(NOW), "good", NOW)).toBe("10m");
  });
  it("words become known automatically after 21 days interval", () => {
    const c = { ...newCard(NOW), state: "review" as const, interval: 21 };
    expect(wordStatus({ status: "learning", card: c })).toBe("known");
    expect(wordStatus({ status: "learning", card: { ...c, interval: 20 } })).toBe("learning");
    expect(wordStatus({ status: "ignored", card: c })).toBe("ignored");
  });
  it("word levels rise with reviews: 1 New, 2 Recognized, 3 Familiar, 4 Almost known, 5 Known", () => {
    let c = newCard(NOW);
    expect(wordLevel({ status: "learning", card: c })).toBe(1);
    c = answerCard(c, "good", NOW); // learning, back in 10 minutes
    expect(wordLevel({ status: "learning", card: c })).toBe(2);
    c = answerCard(c, "good", NOW); // review, 1 day
    expect(wordLevel({ status: "learning", card: c })).toBe(3);
    expect(wordLevel({ status: "learning", card: { ...c, interval: 6 } })).toBe(3);
    expect(wordLevel({ status: "learning", card: { ...c, interval: 7 } })).toBe(4);
    expect(wordLevel({ status: "learning", card: { ...c, interval: 20 } })).toBe(4);
    expect(wordLevel({ status: "learning", card: { ...c, interval: 21 } })).toBe(5);
    expect(wordLevel({ status: "learning", card: answerCard(c, "again", NOW) })).toBe(2);
    expect(wordLevel({ status: "known", card: newCard(NOW) })).toBe(5);
    expect(wordLevel({ status: "ignored", card: c })).toBe(0);
    expect(WORD_LEVELS.map((l) => `${l.level} ${l.label}`)).toEqual(["1 New", "2 Recognized", "3 Familiar", "4 Almost known", "5 Known", "0 Ignored"]);
  });
  it("picking a level reschedules the card to match", () => {
    const base = { ...newCard(NOW - dayMs), ease: 2.1, reps: 4, lapses: 1 };
    expect(cardAtLevel(base, 1, NOW)).toMatchObject({ state: "new", interval: 0, due: NOW, ease: 2.1, reps: 4, lapses: 1 });
    expect(cardAtLevel(base, 2, NOW)).toMatchObject({ state: "learning", step: 1, due: NOW + 10 * minuteMs });
    expect(cardAtLevel(base, 3, NOW)).toMatchObject({ state: "review", interval: 3, due: NOW + 3 * dayMs });
    expect(cardAtLevel(base, 4, NOW)).toMatchObject({ state: "review", interval: 10, due: NOW + 10 * dayMs });
    for (const l of [1, 2, 3, 4]) expect(wordLevel({ status: "learning", card: cardAtLevel(base, l, NOW) })).toBe(l);
    expect(withWordLevel({ status: "learning", card: base }, 5, NOW)).toEqual({ status: "known", card: base });
    expect(withWordLevel({ status: "learning", card: base }, 0, NOW)).toEqual({ status: "ignored", card: base });
    // Known (auto, 21+ days) → back to New: due now again.
    const known = { ...base, state: "review" as const, interval: 30, due: NOW + 30 * dayMs };
    expect(withWordLevel({ status: "learning", card: known }, 1, NOW)).toEqual({ status: "learning", card: { ...known, state: "new", step: 0, interval: 0, due: NOW } });
    // Same level keeps the schedule.
    const fam = cardAtLevel(base, 3, NOW - dayMs);
    expect(withWordLevel({ status: "learning", card: fam }, 3, NOW).card).toBe(fam);
    expect(withWordLevel({ status: "ignored", card: fam }, 3, NOW).card.due).toBe(NOW + 3 * dayMs);
  });
  it("a card shows the meaning once when the clip meaning repeats the dictionary", () => {
    expect(repeatsSense("every day", "every day; daily")).toBe(true);
    expect(repeatsSense("Every day.", "every day; daily")).toBe(true);
    expect(repeatsSense("daily", "every day, daily")).toBe(true);
    expect(repeatsSense("to eat", "to eat (food)")).toBe(true);
    expect(repeatsSense("", "anything")).toBe(true);
    expect(repeatsSense("ate", "to eat")).toBe(false);
    expect(repeatsSense("the samurai", null)).toBe(false);
  });
  it("the tour asks you to tap a new content word, never a filler like ん", () => {
    const w = (p: string, d: string | null = "1") => ({ p, d });
    const lines = [
      { words: [w("interjection"), w("punct", null), w("noun"), w("particle")] },
      { words: [w("particle"), w("verb")] },
    ];
    const allNew = () => true;
    expect(pickTourWord(lines, 0, allNew)).toEqual({ line: 0, idx: 2 });
    // The noun is already known: the first new word of the line instead (still this line).
    expect(pickTourWord(lines, 0, (li, wi) => !(li === 0 && wi === 2))).toEqual({ line: 0, idx: 0 });
    // A noun without a dictionary entry doesn't count as a content word.
    expect(pickTourWord([{ words: [w("particle"), w("noun", null)] }], 0, allNew)).toEqual({ line: 0, idx: 0 });
    // Starts at the playing line.
    expect(pickTourWord(lines, 1, allNew)).toEqual({ line: 1, idx: 1 });
    // Nothing new: any word on the line, so the step still has a target.
    expect(pickTourWord(lines, 1, () => false)).toEqual({ line: 1, idx: 0 });
    expect(pickTourWord([], 0, allNew)).toBeNull();
  });
  it("session keeps a card until it graduates", () => {
    const s = new ReviewSession(["x", "y"]);
    let x = newCard(NOW);
    x = s.answer(x, "good", NOW); // x → learning, requeued
    expect(s.queue).toEqual(["y", "x"]);
    s.answer(newCard(NOW), "again", NOW); // y requeued
    x = s.answer(x, "good", NOW); // x graduates
    expect(x.state).toBe("review");
    expect(s.queue).toEqual(["y"]);
    expect(s.answered).toBe(3);
  });
});

describe("streaks and goals", () => {
  const today = new Date(2026, 9, 21);
  const act = (keys: string[]) => Object.fromEntries(keys.map((k) => [k, { sec: 120, clips: 1, reviews: 0, words: 0 }]));
  it("counts consecutive days including today", () => {
    expect(currentStreak(act(["2026-10-19", "2026-10-20", "2026-10-21"]), today)).toBe(3);
  });
  it("keeps yesterday's streak alive until today ends", () => {
    expect(currentStreak(act(["2026-10-19", "2026-10-20"]), today)).toBe(2);
  });
  it("breaks after a missed day", () => {
    expect(currentStreak(act(["2026-10-18", "2026-10-19"]), today)).toBe(0);
  });
  it("less than a minute without clips or reviews is not an active day", () => {
    expect(currentStreak({ "2026-10-21": { sec: 30, clips: 0, reviews: 0, words: 0 } }, today)).toBe(0);
  });
  it("best streak across month boundary", () => {
    expect(bestStreak(act(["2026-09-29", "2026-09-30", "2026-10-01", "2026-10-05"]))).toBe(3);
  });
  it("goal minutes left rounds up", () => {
    expect(minutesLeft(25, 0)).toBe(25);
    expect(minutesLeft(25, 61)).toBe(24);
    expect(minutesLeft(25, 1500)).toBe(0);
    expect(minutesLeft(25, 9999)).toBe(0);
  });
  it("heat levels", () => {
    expect([0, 100, 600, 1200, 1500].map((s) => heatLevel(s, 25))).toEqual([0, 1, 2, 3, 4]);
  });
  it("heatmap ends on the current week, Monday first", () => {
    const w = heatmapWeeks(today, 3); // 2026-10-21 is a Wednesday
    expect(w.length).toBe(3);
    expect(w[2]![0]).toBe("2026-10-19");
    expect(w[0]![0]).toBe("2026-10-05");
    expect(dayKey(today)).toBe("2026-10-21");
  });
});

describe("achievements, search, kana, sync", () => {
  it("unlocks only new achievements", () => {
    const s = { clips: 10, seconds: 0, words: 0, known: 0, reviews: 0, streak: 0 };
    expect(newlyUnlocked(s, ["first-clip"]).map((a) => a.id)).toEqual(["clips-10"]);
  });
  it("normalizes queries across scripts", () => {
    expect(normalizeQuery("ネコ")).toBe("ねこ");
    expect(normalizeQuery(" Neko ")).toBe("neko");
  });
  it("builds kana decks", () => {
    expect(kanaDeck("hiragana").length).toBe(71);
    expect(kanaDeck("katakana")[0]).toEqual({ id: "k:ア", kana: "ア", romaji: "a" });
    expect(toKatakana("きゃ")).toBe("キャ");
  });
  it("merges saved words by newest update", () => {
    const m = mergeByUpdatedAt({ a: { v: 1, updatedAt: 5 }, b: { v: 1, updatedAt: 5 } }, { a: { v: 2, updatedAt: 9 }, b: { v: 2, updatedAt: 5 }, c: { v: 2, updatedAt: 1 } });
    expect(m).toEqual({ a: { v: 2, updatedAt: 9 }, b: { v: 1, updatedAt: 5 }, c: { v: 2, updatedAt: 1 } });
  });
  it("merges activity by max counter", () => {
    const m = mergeActivity({ d: { sec: 100, clips: 2, reviews: 0, words: 1 } }, { d: { sec: 50, clips: 3, reviews: 4, words: 0 } });
    expect(m["d"]).toEqual({ sec: 100, clips: 3, reviews: 4, words: 1 });
  });
});

describe("clip search", () => {
  const w = (s: string, b: string, r: string, ro: string, d: string | null = null) => ({ s, b, r, ro, p: "noun", d });
  const clips = [
    { id: "x-1", level: "N4", topics: ["animals"], grammar: ["〜てる — ongoing action"], lines: [{ ja: "猫が歩いてる。", en: "The cat is walking.", words: [w("猫", "猫", "ねこ", "neko", "1467640"), w("歩いてる", "歩く", "あるいてる", "aruiteru", "1514320")] }] },
    { id: "y-1", level: "N5", topics: ["food"], grammar: ["〜たい — want to"], lines: [{ ja: "ラーメンが食べたい。", en: "I want to eat ramen.", words: [w("ラーメン", "ラーメン", "", "raamen"), w("食べたい", "食べる", "たべたい", "tabetai")] }] },
  ];
  it("finds a word by kanji, kana, katakana or romaji", () => {
    expect(searchClips(clips, "猫")).toEqual(["x-1"]);
    expect(searchClips(clips, "ネコ")).toEqual(["x-1"]);
    expect(searchClips(clips, "neko")).toEqual(["x-1"]);
    expect(searchClips(clips, "歩く")).toEqual(["x-1"]);
  });
  it("finds English text and applies filters", () => {
    expect(searchClips(clips, "ramen")).toEqual(["y-1"]);
    expect(searchClips(clips, "", { level: "N5" })).toEqual(["y-1"]);
    expect(searchClips(clips, "", { grammar: "〜てる" })).toEqual(["x-1"]);
    expect(searchClips(clips, "", {})).toEqual(["y-1", "x-1"]);
  });
  it("word keys prefer dictionary ids", () => {
    expect(clipWordKeys(clips[0]!)).toEqual(["d1467640", "d1514320"]);
    expect(wordKeyOf(null, "よし")).toBe("bよし");
  });
  it("hear it again: other clips with the word, best level fit first", () => {
    const more = [...clips, { id: "z-1", level: "N2", topics: [], grammar: [], lines: [{ ja: "猫だ", en: "A cat", words: [w("猫", "猫", "ねこ", "neko", "1467640")] }] }];
    expect(clipsWithWord(more, "d1467640", "none", "N2")).toEqual(["z-1", "x-1"]);
    expect(clipsWithWord(more, "d1467640", "x-1", "N5")).toEqual(["z-1"]);
  });
});

describe("free tier", () => {
  it("free learners get 10 clips a day, premium is unlimited", () => {
    expect(canWatchClip(false, 9, 10)).toBe(true);
    expect(canWatchClip(false, 10, 10)).toBe(false);
    expect(canWatchClip(true, 500, 10)).toBe(true);
  });
});

describe("saved words", () => {
  const card = (due: number, interval = 0) => ({ ...newCard(due), state: (interval ? "review" : "new") as "review" | "new", interval });
  const words = [
    { key: "a", status: "learning" as const, card: card(NOW - 10), addedAt: 1 },
    { key: "b", status: "learning" as const, card: card(NOW - 50), addedAt: 2 },
    { key: "c", status: "learning" as const, card: card(NOW + 1000, 30), addedAt: 3 },
    { key: "d", status: "known" as const, card: card(NOW - 99), addedAt: 4 },
    { key: "e", status: "ignored" as const, card: card(NOW - 99), addedAt: 5 },
    { key: "f", status: "removed" as const, card: card(NOW - 99), addedAt: 6 },
  ];
  it("reviews only due learning words, oldest first", () => {
    expect(dueWordKeys(words, NOW)).toEqual(["b", "a"]);
  });
  it("counts saved, learning, known and due", () => {
    expect(wordCounts(words, NOW)).toEqual({ saved: 4, learning: 2, known: 2, due: 2 });
  });
  it("keep studying offers learning words that aren't due yet", () => {
    expect(customStudyKeys(words, NOW)).toEqual(["c"]);
  });
  it("kana sessions: due first, then 10 new characters", () => {
    const deck = kanaDeck("hiragana");
    const cards = { "h:い": { ...newCard(NOW - 5), state: "review" as const, interval: 3 }, "h:う": { ...newCard(NOW + 999), state: "learning" as const } };
    const q = kanaQueue(deck, cards, NOW);
    expect(q[0]).toBe("h:い");
    expect(q.length).toBe(11);
    expect(q.slice(1, 3)).toEqual(["h:あ", "h:え"]);
    expect(kanaLearned(deck, cards)).toBe(1);
    expect(deck.length).toBe(71);
  });
});

describe("cloud merge", () => {
  const local = {
    updatedAt: 10, onboarded: true, profile: { name: "Local" },
    words: { a: { updatedAt: 5, status: "learning" } }, seen: { c1: 1 }, history: [{ clipId: "c1", at: 3 }],
    activity: { "2026-10-21": { sec: 100, clips: 1, reviews: 0, words: 0 } }, totals: { clips: 1, seconds: 100, reviews: 0 },
    achievementsSeen: ["first-clip"], kana: { "h:あ": { reps: 1 } }, reviewSessions: 0,
  };
  const remote = {
    updatedAt: 20, onboarded: false, profile: { name: "Remote" },
    words: { a: { updatedAt: 9, status: "known" }, b: { updatedAt: 1, status: "learning" } }, seen: { c1: 3, c2: 1 },
    history: [{ clipId: "c2", at: 7 }, { clipId: "c1", at: 3 }], activity: { "2026-10-21": { sec: 40, clips: 2, reviews: 5, words: 1 } },
    totals: { clips: 3, seconds: 40, reviews: 5 }, achievementsSeen: ["clips-10"], kana: { "h:あ": { reps: 4 } }, reviewSessions: 2,
  };
  it("merges words, counters and history; newer single values win", () => {
    const m = mergeState(local, remote);
    expect(m.profile.name).toBe("Remote");
    expect(m.onboarded).toBe(true);
    expect(m.words.a.status).toBe("known");
    expect(Object.keys(m.words).sort()).toEqual(["a", "b"]);
    expect(m.seen).toEqual({ c1: 3, c2: 1 });
    expect(m.history.map((h: { clipId: string }) => h.clipId)).toEqual(["c2", "c1"]);
    expect(m.activity["2026-10-21"]).toEqual({ sec: 100, clips: 2, reviews: 5, words: 1 });
    expect(m.totals).toEqual({ clips: 3, seconds: 100, reviews: 5 });
    expect(m.achievementsSeen).toEqual(["clips-10", "first-clip"]);
    expect(m.kana["h:あ"].reps).toBe(4);
    expect(m.reviewSessions).toBe(2);
    expect(m.updatedAt).toBe(20);
  });
  it("premium stays the device's own, even when the cloud copy is newer", () => {
    const m = mergeState({ ...local, premium: { active: false } }, { ...remote, premium: { active: true, plan: "yearly" } });
    expect(m.premium).toEqual({ active: false });
    const m2 = mergeState({ ...local, premium: { active: true, plan: "monthly" } }, { ...remote, premium: { active: false } });
    expect(m2.premium).toEqual({ active: true, plan: "monthly" });
  });
});

describe("ask kizuki", () => {
  it("counts questions per day", () => {
    expect(asksToday("2026-10-21", 3, "2026-10-21")).toBe(3);
    expect(asksToday("2026-10-20", 3, "2026-10-21")).toBe(0);
  });
  it("free learners get 5 questions a day, premium unlimited", () => {
    expect(canAsk(false, 4, 5)).toBe(true);
    expect(canAsk(false, 5, 5)).toBe(false);
    expect(canAsk(true, 99, 5)).toBe(true);
    expect(asksLeft(false, 3, 5)).toBe(2);
    expect(asksLeft(false, 7, 5)).toBe(0);
    expect(asksLeft(true, 7, 5)).toBe(null);
  });
  it("cleans typed questions and caps them at 400 characters", () => {
    expect(cleanQuestion("  why   is\nit  ")).toBe("why is it");
    expect(cleanQuestion("a".repeat(450)).length).toBe(400);
    expect(cleanQuestion("   ")).toBe("");
  });
  it("sends the last 10 non-empty turns, starting with a question", () => {
    const msgs: AskTurn[] = Array.from({ length: 12 }, (_, i) => ({ role: i % 2 === 0 ? "user" : "assistant", text: `m${i}` }));
    expect(askHistory(msgs).map((m) => m.text)).toEqual(["m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10", "m11"]);
    const odd = askHistory<AskTurn>([{ role: "assistant", text: "hi" }, { role: "user", text: "q" }, { role: "assistant", text: "" }, { role: "user", text: "q2" }]);
    expect(odd.map((m) => m.text)).toEqual(["q", "q2"]);
    expect(askHistory(msgs, 3).map((m) => m.text)).toEqual(["m10", "m11"]);
  });
  it("accepts a support message only with a reply email and 5–2000 characters", () => {
    expect(supportMessageError("aiko@example.com", "The clip will not play")).toBe(null);
    expect(supportMessageError("aiko@example", "The clip will not play")).toBe("Enter the email we should reply to.");
    expect(supportMessageError("", "The clip will not play")).toBe("Enter the email we should reply to.");
    expect(supportMessageError("aiko@example.com", "  hi  ")).toBe("Tell us a little more (at least 5 characters).");
    expect(supportMessageError("aiko@example.com", "a".repeat(2000))).toBe(null);
    expect(supportMessageError("aiko@example.com", "a".repeat(2001))).toBe("Keep it under 2000 characters.");
    expect(SUPPORT_TOPICS).toEqual(["subscription", "account", "bug", "content", "feedback", "other"]);
  });
});
