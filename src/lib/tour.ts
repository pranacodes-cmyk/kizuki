// Welcome tour — mirrored by mobile/lib/data/tour.dart. An interactive walk through the
// whole loop (watch → tap a word → explanation → swipe → Explore → Vocab → first review).
// Shown the first time the feed opens, and again after Settings → Replay the welcome tour.
import type { MascotPose } from "@/components/mimi/Mascot";

/** Things the learner does that move an "action" step forward. */
export type TourEvent = "word" | "explain" | "cardClosed" | "swipe" | "reveal" | "graded";

export type TourTarget = "player" | "transcript" | "word" | "cardExplain" | "card" | "controls" | "exploreTab" | "exploreSearch" | "vocabTab" | "reviewButton" | "reviewCard" | "grade";

export type TourStep = {
  id: string;
  /** Routes the step shows on. Empty = any route. */
  screens: string[];
  /** Spotlight target (data-tour attribute), or null for a centered card. */
  target: TourTarget | null;
  text: string;
  pose: MascotPose;
  /** tap = tap anywhere / Next · action = do the highlighted thing · legend = underline key · finish = last card. */
  kind?: "tap" | "action" | "legend" | "finish";
  /** Action steps: the event that completes the step… */
  until?: TourEvent;
  /** …or the route that completes it. */
  untilRoute?: string;
  /** Animated hand. */
  hand?: "tap" | "swipe";
  /** The whole screen stays usable (no blocking layer), e.g. swiping the feed or closing the card. */
  passThrough?: boolean;
  /** What to do, shown under action steps. */
  hint?: string;
  /** If the target never appears, "Next" jumps here (later steps depend on this one). */
  skipTo?: string;
};

export const TOUR_STEPS: TourStep[] = [
  { id: "hello", screens: ["/feed"], target: null, text: "Hi{name}! Let me show you how Kizuki works. It takes about a minute.", pose: "wave" },
  { id: "clip", screens: ["/feed"], target: "player", text: "Every clip is a short scene from a real Japanese video. It repeats, so you can hear it again and again.", pose: "listen" },
  { id: "subs", screens: ["/feed"], target: "transcript", text: "The subtitles follow along. The word being spoken gets a green box.", pose: "read" },
  { id: "tapWord", screens: ["/feed"], target: "word", text: "Tap this word to see what it means.", pose: "think", kind: "action", until: "word", hand: "tap", hint: "Tap the highlighted word", skipTo: "legend" },
  { id: "meaning", screens: ["/feed"], target: "cardExplain", text: "That's the meaning. Now tap Explain to see why it's used in this sentence.", pose: "read", kind: "action", until: "explain", hand: "tap", hint: "Tap Explain", skipTo: "legend" },
  { id: "explain", screens: ["/feed"], target: "card", text: "This explains the word in this exact sentence. It's already saved to your Vocab.", pose: "heart", kind: "action", until: "cardClosed", passThrough: true, hint: "Swipe the card down or tap above it", skipTo: "legend" },
  { id: "legend", screens: ["/feed"], target: null, text: "Underlines show what you know.", pose: "think", kind: "legend" },
  { id: "controls", screens: ["/feed"], target: "controls", text: "Replay the line, loop it, slow it down, or change what you see with Aa.", pose: "think" },
  { id: "swipe", screens: ["/feed"], target: null, text: "Swipe up for the next clip.", pose: "cheer", kind: "action", until: "swipe", hand: "swipe", passThrough: true, hint: "Swipe up anywhere" },
  { id: "explore", screens: ["/feed"], target: "exploreTab", text: "Tap Explore to find clips by word or topic.", pose: "think", kind: "action", untilRoute: "/explore", hand: "tap", hint: "Tap Explore", skipTo: "vocabTab" },
  { id: "search", screens: ["/explore"], target: "exploreSearch", text: "Search any word in Japanese, romaji or English and you'll get clips that use it. Or pick a topic below.", pose: "read" },
  { id: "vocabTab", screens: ["/explore", "/feed"], target: "vocabTab", text: "Now tap Vocab. Every word you tap is saved there.", pose: "heart", kind: "action", untilRoute: "/vocab", hand: "tap", hint: "Tap Vocab", skipTo: "done" },
  { id: "review", screens: ["/vocab"], target: "reviewButton", text: "The word you tapped is already here. Tap to review it.", pose: "cheer", kind: "action", untilRoute: "/review", hand: "tap", hint: "Tap the orange button", skipTo: "done" },
  { id: "reveal", screens: ["/review"], target: "reviewCard", text: "Try to remember what it means, then tap the card.", pose: "think", kind: "action", until: "reveal", hand: "tap", hint: "Tap the card", skipTo: "done" },
  { id: "grade", screens: ["/review"], target: "grade", text: "You'll hear it in the original clip. Knew it? Tap Good. Not yet? Tap Again and it comes back sooner.", pose: "read", kind: "action", until: "graded", hint: "Tap Good or Again", skipTo: "done" },
  { id: "done", screens: [], target: null, text: "That's the whole loop: watch, tap, review. {minutes} minutes a day and you'll surprise yourself!", pose: "brave", kind: "finish" },
];

/** Personal bits in the step text. */
export function tourText(s: TourStep, name: string, minutes: number) {
  return s.text.replace("{name}", name.trim() ? ` ${name.trim()}` : "").replace("{minutes}", String(minutes));
}

/** Index of a step id (TOUR_STEPS.length when missing, which ends the tour). */
export function tourIndexOf(id: string) {
  const i = TOUR_STEPS.findIndex((s) => s.id === id);
  return i < 0 ? TOUR_STEPS.length : i;
}

/** Word underline legend (Transcript colours). */
export const TOUR_LEGEND = [
  { id: "new", label: "New word", hint: "Tap it to look it up" },
  { id: "learning", label: "Learning", hint: "Saved — in your reviews" },
  { id: "known", label: "Known", hint: "No underline, out of your way" },
] as const;

/** Delay before the legend's "Got it" button enables (so it's actually read). */
export const TOUR_LEGEND_DELAY_MS = 1500;

/** A step whose target hasn't appeared after this long offers "Next" instead (never stuck). */
export const TOUR_TARGET_WAIT_MS = 2500;

/** Tall targets (the scrolling transcript, the word card) are spotlit only at the top, so the bubble fits. */
export const TOUR_MAX_HOLE_HEIGHT = 300;

/** The tap hand's fingertip sits this far down the target (0 = top, 1 = bottom), below the word. */
export const TOUR_HAND_TIP_Y = 0.8;
