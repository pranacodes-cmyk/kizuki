// Welcome tour — mirrored by mobile/lib/data/tour.dart. A short "do what I point at" walk through
// the whole loop: tap a word → its meaning + Ask Kizuki → swipe → Vocab → first review → back to
// the videos. Shown the first time the feed opens, and again after Settings → Replay the tour.
import type { MascotPose } from "@/components/mimi/Mascot";

/** Things the learner does that move an "action" step forward. */
export type TourEvent = "word" | "explain" | "cardClosed" | "askOpened" | "askClosed" | "swipe" | "reveal" | "graded";

export type TourTarget = "player" | "controls" | "word" | "cardExplain" | "card" | "askButton" | "askPanel" | "vocabTab" | "kanaDecks" | "reviewButton" | "reviewCard" | "grade";

export type TourStep = {
  id: string;
  /** Routes the step shows on. Empty = any route. */
  screens: string[];
  /** Spotlight target (data-tour attribute), or null for a centered card. */
  target: TourTarget | null;
  text: string;
  pose: MascotPose;
  /** tap = Next (or tap anywhere) · action = do the highlighted thing · legend = underline key · finish = last card. */
  kind?: "tap" | "action" | "controls" | "legend" | "finish";
  /** Action steps: the event that completes the step… */
  until?: TourEvent;
  /** …or the route that completes it. */
  untilRoute?: string;
  /** Animated hand. */
  hand?: "tap" | "swipe";
  /** The target the tap hand points at when it isn't the whole spotlight (e.g. Explain on the lit word card). */
  handAt?: TourTarget;
  /** The whole screen stays usable (no blocking layer), e.g. swiping the feed. */
  passThrough?: boolean;
  /** What to do, shown under action steps. */
  hint?: string;
  /** If the target never appears, "Next" jumps here (later steps depend on this one). */
  skipTo?: string;
  /** top = the tip sits above the spotlight (above a bottom sheet), else pinned to the top · bottom = pinned to the bottom of the screen. */
  place?: "top" | "bottom";
  /** Spotlight the whole target, even when it's taller than TOUR_MAX_HOLE_HEIGHT. */
  fullHole?: boolean;
  /** Where the tap hand's fingertip sits on the target (0 top … 1 bottom); default TOUR_HAND_TIP_Y. */
  handY?: number;
  /** Button label on tap / finish steps (default "Next" / "Let's go!"). */
  button?: string;
  /** Moving on closes the open word card and Ask Kizuki for the learner (no "close it yourself"). */
  closesSheets?: boolean;
  /** Finish step: where the learner lands after the last button. */
  endRoute?: "/feed";
};

export const TOUR_STEPS: TourStep[] = [
  { id: "hello", screens: ["/feed"], target: null, text: "Hi{name}! I'll show you how Kizuki works. It takes one minute — just tap what I point at.", pose: "wave", button: "Show me" },
  { id: "controls", screens: ["/feed"], target: "controls", text: "Slow down, replay or save a clip.", pose: "listen", kind: "controls", button: "Try a word" },
  { id: "tapWord", screens: ["/feed"], target: "word", text: "Real Japanese, with subtitles. Tap this word to see what it means.", pose: "think", kind: "action", until: "word", hand: "tap", hint: "Tap the highlighted word", skipTo: "legend" },
  { id: "meaning", screens: ["/feed"], target: "card", text: "That's what it means. It's saved for you, so you can practice it later.", pose: "read", kind: "action", until: "explain", hand: "tap", handAt: "cardExplain", hint: "Now tap Explain", skipTo: "legend", place: "top", fullHole: true },
  { id: "askOpen", screens: ["/feed"], target: "card", text: "This explains the word in this exact sentence. Still have a question?", pose: "think", kind: "action", until: "askOpened", hand: "tap", handAt: "askButton", hint: "Tap Ask Kizuki", skipTo: "legend", place: "top", fullHole: true },
  { id: "askInfo", screens: ["/feed"], target: "askPanel", text: "Here is an example. Your question stays about the word and sentence you just watched.", pose: "heart", button: "Back to the video", closesSheets: true, place: "top" },
  { id: "legend", screens: ["/feed"], target: null, text: "The line under each word tells you:", pose: "think", kind: "legend" },
  { id: "swipe", screens: ["/feed"], target: "controls", text: "Swipe up for the next clip.", pose: "cheer", kind: "action", until: "swipe", hand: "swipe", passThrough: true, hint: "Swipe up anywhere" },
  { id: "vocabTab", screens: ["/feed", "/explore"], target: "vocabTab", text: "Every word you tap is saved in Vocab.", pose: "heart", kind: "action", untilRoute: "/vocab", hand: "tap", hint: "Tap Vocab", skipTo: "done" },
  { id: "kanaDecks", screens: ["/vocab"], target: "kanaDecks", text: "Japanese ABCs\nHiragana あ and Katakana ア write the same sounds in two ways. Start with Hiragana. Both decks are optional.", pose: "read", button: "Got it" },
  { id: "review", screens: ["/vocab"], target: "reviewButton", text: "Your new word is waiting here. Let's practice it once.", pose: "cheer", kind: "action", untilRoute: "/review", hand: "tap", hint: "Tap the orange button", skipTo: "done" },
  { id: "reveal", screens: ["/review"], target: "reviewCard", text: "Do you remember what it means? Tap the card to check.", pose: "think", kind: "action", until: "reveal", hand: "tap", hint: "Tap anywhere on the card", skipTo: "done", place: "bottom", fullHole: true, handY: 0.62 },
  { id: "grade", screens: ["/review"], target: "grade", text: "Remembered it? Tap Remembered. If not, tap Forgot — the word just comes back sooner.", pose: "read", kind: "action", until: "graded", hint: "Tap one of the two buttons", skipTo: "done" },
  { id: "done", screens: [], target: null, text: "That's it: watch, tap new words, practice them. {minutes} minutes a day is all you need!", pose: "brave", kind: "finish", button: "Back to videos", endRoute: "/feed" },
];

/** Steps that happen on the open word card / Ask Kizuki: closing a card by hand skips the rest. */
export const TOUR_CARD_STEPS = ["meaning", "askOpen", "askInfo"];

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
  { id: "new", label: "Blue line · new word", hint: "Tap it to see what it means" },
  { id: "learning", label: "Orange line · saved word", hint: "You're learning it" },
  { id: "known", label: "No line · known word", hint: "You already know it" },
] as const;

/** Delay before the legend's "Got it" button enables (so it's actually read). */
export const TOUR_LEGEND_DELAY_MS = 1200;

/** A step whose target hasn't appeared after this long offers "Next" instead (never stuck). */
export const TOUR_TARGET_WAIT_MS = 2500;

/** Tall targets are spotlit only at the top, so the bubble fits (unless the step lights it whole). */
export const TOUR_MAX_HOLE_HEIGHT = 300;

/** The tap hand's fingertip sits this far down the target (0 = top, 1 = bottom), below the word. */
export const TOUR_HAND_TIP_Y = 0.8;

/** Estimated tip height used to decide whether it fits above / below a spotlight. */
export const TOUR_TIP_EST_HEIGHT = 150;
