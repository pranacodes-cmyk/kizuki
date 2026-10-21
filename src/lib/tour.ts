// Welcome tour steps — mirrored by mobile/lib/data/tour.dart. Shown on the feed the first
// time (and again after Settings → Replay the welcome tour).
import type { MascotPose } from "@/components/mimi/Mascot";

export type TourStep = {
  id: string;
  /** Spotlight target (data-tour attribute), or null for a centered card. */
  target: "player" | "transcript" | "controls" | "tabs" | null;
  text: string;
  pose: MascotPose;
  kind?: "normal" | "legend" | "swipe";
};

export const TOUR_STEPS: TourStep[] = [
  { id: "hello", target: null, text: "Let me show you around! It'll only take a minute.", pose: "wave" },
  { id: "player", target: "player", text: "Learn by watching short, fun clips from real Japanese videos.", pose: "listen" },
  { id: "words", target: "transcript", text: "Subtitles light up as people speak. Tap any word to see its meaning — and why it's used in this sentence.", pose: "read" },
  { id: "legend", target: null, text: "Underlines show what you know.", pose: "think", kind: "legend" },
  { id: "controls", target: "controls", text: "Replay a line, loop it, slow it down, or change what you see with Aa.", pose: "think" },
  { id: "swipe", target: null, text: "Swipe up for the next clip.", pose: "cheer", kind: "swipe" },
  { id: "vocab", target: "tabs", text: "Words you tap are saved in Vocab. Review them each day with the original audio.", pose: "heart" },
];

/** Word underline legend (Transcript colours). */
export const TOUR_LEGEND = [
  { id: "new", label: "New word", hint: "Tap it to look it up" },
  { id: "learning", label: "Learning", hint: "Saved — in your reviews" },
  { id: "known", label: "Known", hint: "No underline, out of your way" },
] as const;

/** Delay before the legend's "Got it" button enables (so it's actually read). */
export const TOUR_LEGEND_DELAY_MS = 1500;

/** Tall targets (the scrolling transcript) are spotlit only at the top, so the bubble fits. */
export const TOUR_MAX_HOLE_HEIGHT = 300;
