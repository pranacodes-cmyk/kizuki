// Welcome tour — mirrored by mobile/lib/data/tour.dart. An interactive walk through the
// whole loop (watch → tap a word → explanation → swipe → Explore → Vocab → first review).
// Shown the first time the feed opens, and again after Settings → Replay the welcome tour.
import type { MascotPose } from "@/components/mimi/Mascot";

/** Things the learner does that move an "action" step forward. */
export type TourEvent = "word" | "explain" | "cardClosed" | "askOpened" | "askClosed" | "swipe" | "reveal" | "graded";

export type TourTarget = "player" | "transcript" | "word" | "cardExplain" | "card" | "askButton" | "askPanel" | "controls" | "exploreTab" | "exploreSearch" | "vocabTab" | "reviewButton" | "reviewCard" | "grade";

export type TourStep = {
  id: string;
  /** Routes the step shows on. Empty = any route. */
  screens: string[];
  /** Spotlight target (data-tour attribute), or null for a centered card. */
  target: TourTarget | null;
  text: string;
  pose: MascotPose;
  /** tap = Next (or tap anywhere) · action = do the highlighted thing · legend = underline key · controls = what each player button does · finish = last card. */
  kind?: "tap" | "action" | "legend" | "controls" | "finish";
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
  /** Pin the tip to the top (above a bottom sheet) or bottom of the screen instead of next to the spotlight. */
  place?: "top" | "bottom";
  /** Spotlight the whole target, even when it's taller than TOUR_MAX_HOLE_HEIGHT. */
  fullHole?: boolean;
  /** Where the tap hand's fingertip sits on the target (0 top … 1 bottom); default TOUR_HAND_TIP_Y. */
  handY?: number;
};

export const TOUR_STEPS: TourStep[] = [
  { id: "hello", screens: ["/feed"], target: null, text: "Hi{name}! Let me show you how Kizuki works. It takes about a minute.", pose: "wave" },
  { id: "clip", screens: ["/feed"], target: "player", text: "Every clip is a short scene from a real Japanese video. It repeats, so you can hear it again and again.", pose: "listen" },
  { id: "subs", screens: ["/feed"], target: "transcript", text: "The subtitles follow along. The word being said gets a green box.", pose: "read" },
  { id: "tapWord", screens: ["/feed"], target: "word", text: "Tap this word to see what it means.", pose: "think", kind: "action", until: "word", hand: "tap", hint: "Tap the highlighted word", skipTo: "legend" },
  { id: "meaning", screens: ["/feed"], target: "cardExplain", text: "That's the meaning. Now tap Explain to see why it's used in this sentence.", pose: "read", kind: "action", until: "explain", hand: "tap", hint: "Tap Explain", skipTo: "legend", place: "top" },
  { id: "explain", screens: ["/feed"], target: "card", text: "This explains the word in this exact sentence. It's already saved to your Vocab.", pose: "heart", place: "top", fullHole: true },
  { id: "askOpen", screens: ["/feed"], target: "askButton", text: "Want to understand more? Tap Ask Kizuki.", pose: "think", kind: "action", until: "askOpened", hand: "tap", hint: "Tap Ask Kizuki", skipTo: "legend", place: "top" },
  { id: "askInfo", screens: ["/feed"], target: "askPanel", text: "Kizuki already knows this word and sentence. Ask about grammar, meaning or more examples.", pose: "read", place: "bottom" },
  { id: "askClose", screens: ["/feed"], target: null, text: "You can come back whenever you have a question. Close Ask Kizuki and the word card to continue.", pose: "wave", kind: "action", until: "cardClosed", passThrough: true, hint: "Tap above each card to close it", skipTo: "legend", place: "top" },
  { id: "legend", screens: ["/feed"], target: null, text: "Underlines show what you know.", pose: "think", kind: "legend" },
  { id: "controls", screens: ["/feed"], target: "controls", text: "These buttons help you listen:", pose: "think", kind: "controls" },
  { id: "swipe", screens: ["/feed"], target: null, text: "Swipe up for the next clip.", pose: "cheer", kind: "action", until: "swipe", hand: "swipe", passThrough: true, hint: "Swipe up anywhere" },
  { id: "explore", screens: ["/feed"], target: "exploreTab", text: "Tap Explore to find clips by word or topic.", pose: "think", kind: "action", untilRoute: "/explore", hand: "tap", hint: "Tap Explore", skipTo: "vocabTab" },
  { id: "search", screens: ["/explore"], target: "exploreSearch", text: "Search any word in Japanese, romaji or English and you'll get clips that use it. Or pick a topic below.", pose: "read" },
  { id: "vocabTab", screens: ["/explore", "/feed"], target: "vocabTab", text: "Now tap Vocab. Every word you tap is saved there.", pose: "heart", kind: "action", untilRoute: "/vocab", hand: "tap", hint: "Tap Vocab", skipTo: "done" },
  { id: "review", screens: ["/vocab"], target: "reviewButton", text: "The word you tapped is already here. Tap to review it.", pose: "cheer", kind: "action", untilRoute: "/review", hand: "tap", hint: "Tap the orange button", skipTo: "done" },
  { id: "reveal", screens: ["/review"], target: "reviewCard", text: "Try to remember what it means, then tap the card to check.", pose: "think", kind: "action", until: "reveal", hand: "tap", hint: "Tap anywhere on the card", skipTo: "done", place: "bottom", fullHole: true, handY: 0.62 },
  { id: "grade", screens: ["/review"], target: "grade", text: "Remembered it? Tap Remembered. Otherwise, tap Forgot.", pose: "read", kind: "action", until: "graded", hint: "Or swipe the card right or left", skipTo: "done" },
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

/** Word underline legend — drawn exactly like transcript words (Transcript colours). */
export const TOUR_LEGEND = [
  { id: "new", label: "New word", hint: "Tap it to see what it means" },
  { id: "learning", label: "Learning", hint: "Saved. The line fades as you learn it" },
  { id: "known", label: "Known", hint: "No underline, out of your way" },
  { id: "speaking", label: "Being said now", hint: "The green box follows the audio" },
] as const;

/** What each player button does (the controls step) — same order as the buttons. */
export const TOUR_CONTROLS = [
  { id: "replay", label: "Replay the line" },
  { id: "loop", label: "Loop the line" },
  { id: "speed", label: "Slow it down" },
  { id: "save", label: "Save the clip" },
  { id: "display", label: "Subtitles and text size" },
] as const;

/** Delay before the legend's "Got it" button enables (so it's actually read). */
export const TOUR_LEGEND_DELAY_MS = 1500;

/** A step whose target hasn't appeared after this long offers "Next" instead (never stuck). */
export const TOUR_TARGET_WAIT_MS = 2500;

/** Tall targets (the scrolling transcript, the word card) are spotlit only at the top, so the bubble fits. */
export const TOUR_MAX_HOLE_HEIGHT = 300;

/** The tap hand's fingertip sits this far down the target (0 = top, 1 = bottom), below the word. */
export const TOUR_HAND_TIP_Y = 0.8;
