// Welcome-tour state: which step is showing (not persisted — a reload replays the tour from
// the start until it's finished or skipped). Mirrors the Tour controller in
// mobile/lib/widgets/tour.dart.
import { create } from "zustand";

import { useApp } from "@/lib/store";
import { TOUR_STEPS, tourIndexOf, type TourEvent } from "@/lib/tour";

type TourState = {
  /** Current step index, or null when the tour isn't running. */
  index: number | null;
  start: () => void;
  goTo: (i: number) => void;
  next: () => void;
  /** The step's target never showed up: jump over the steps that depend on it. */
  skipStep: () => void;
  /** Ends the tour (finished or skipped) and remembers it. */
  finish: () => void;
  reset: () => void;
  emit: (e: TourEvent) => void;
  route: (path: string) => void;
};

export const useTour = create<TourState>((set, get) => ({
  index: null,
  start: () => set({ index: 0 }),
  goTo: (i) => {
    if (get().index == null) return;
    if (i >= TOUR_STEPS.length) return get().finish();
    set({ index: i });
  },
  next: () => {
    const i = get().index;
    if (i != null) get().goTo(i + 1);
  },
  skipStep: () => {
    const s = currentStep();
    if (!s) return;
    if (s.skipTo) get().goTo(tourIndexOf(s.skipTo));
    else get().next();
  },
  finish: () => {
    if (get().index == null) return;
    set({ index: null });
    useApp.getState().completeTutorial("feed");
  },
  reset: () => set({ index: null }),
  emit: (e) => {
    const s = currentStep();
    if (!s) return;
    if (s.kind === "action" && s.until === e) return get().next();
    if (e === "askClosed" && ["askInfo", "askClose"].includes(s.id)) { get().goTo(tourIndexOf("askClose")); return; }
    if (e === "cardClosed" && ["explain", "askOpen", "askInfo", "askClose"].includes(s.id)) { get().goTo(tourIndexOf("legend")); return; }
    // Closed the word card before tapping Explain → carry on after the card steps.
    if (e === "cardClosed" && s.target === "cardExplain") get().skipStep();
  },
  route: (path) => {
    const s = currentStep();
    if (s && s.untilRoute === path) get().next();
  },
}));

export function currentStep() {
  const i = useTour.getState().index;
  return i == null ? null : TOUR_STEPS[i] ?? null;
}

export const tourEmit = (e: TourEvent) => useTour.getState().emit(e);
