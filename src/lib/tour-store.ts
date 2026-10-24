// Welcome-tour state: which step is showing (not persisted — a reload replays the tour from
// the start until it's finished or skipped). Mirrors the Tour controller in
// mobile/lib/widgets/tour.dart.
import { create } from "zustand";

import { useApp } from "@/lib/store";
import { TOUR_CARD_STEPS, TOUR_STEPS, tourIndexOf, type TourEvent } from "@/lib/tour";

type TourState = {
  /** Current step index, or null when the tour isn't running. */
  index: number | null;
  /** Bumped when the tour closes the open word card / Ask Kizuki for the learner (ClipView and WordCard listen). */
  closeSignal: number;
  start: () => void;
  goTo: (i: number) => void;
  next: () => void;
  /** The step's target never showed up: jump over the steps that depend on it. */
  skipStep: () => void;
  /** The learner tapped the tip's button (Next, Back to the video, Back to videos…). */
  advance: () => void;
  /** Ends the tour (finished or skipped) and remembers it. */
  finish: () => void;
  reset: () => void;
  emit: (e: TourEvent) => void;
  route: (path: string) => void;
  closeSheets: () => void;
};

/** Opens a route (registered by TourHost with the router; the last step goes back to the feed). */
let navigateTo: ((path: string) => void) | null = null;
export function setTourNavigator(fn: ((path: string) => void) | null) {
  navigateTo = fn;
}

export const useTour = create<TourState>((set, get) => ({
  index: null,
  closeSignal: 0,
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
  advance: () => {
    const s = currentStep();
    if (!s) return;
    if (s.kind === "finish") {
      get().finish();
      if (s.endRoute) navigateTo?.(s.endRoute);
      return;
    }
    if (s.kind === "action") return get().skipStep();
    // Move first, so the closing sheets' events land on the next step and change nothing.
    get().next();
    if (s.closesSheets) get().closeSheets();
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
    // Closed the word card or Ask Kizuki by hand: carry on after the card steps and close the
    // other card too — never wait for a card that's gone.
    if ((e === "cardClosed" || e === "askClosed") && TOUR_CARD_STEPS.includes(s.id)) {
      get().goTo(tourIndexOf("legend"));
      get().closeSheets();
    }
  },
  route: (path) => {
    const s = currentStep();
    if (s && s.untilRoute === path) get().next();
  },
  closeSheets: () => set((st) => ({ closeSignal: st.closeSignal + 1 })),
}));

export function currentStep() {
  const i = useTour.getState().index;
  return i == null ? null : TOUR_STEPS[i] ?? null;
}

export const tourEmit = (e: TourEvent) => useTour.getState().emit(e);
