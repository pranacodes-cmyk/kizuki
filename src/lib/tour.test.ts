// Welcome tour step machine — same rules as mobile/test/tour_test.dart.
import { beforeEach, describe, expect, it } from "vitest";

import { useApp } from "@/lib/store";
import { TOUR_CARD_STEPS, TOUR_LEGEND, TOUR_STEPS, tourIndexOf, tourText, type TourEvent } from "@/lib/tour";
import { setTourNavigator, useTour } from "@/lib/tour-store";

const id = () => {
  const i = useTour.getState().index;
  return i == null ? "none" : TOUR_STEPS[i]!.id;
};
const t = () => useTour.getState();
const closes = () => t().closeSignal;
let went: string[] = [];

describe("welcome tour", () => {
  beforeEach(() => {
    t().reset();
    useTour.setState({ closeSignal: 0 });
    went = [];
    setTourNavigator((p) => went.push(p));
  });

  it("is a short do-what-I-point tour: word card, Ask Kizuki, swipe, Vocab, first review, back to videos", () => {
expect(TOUR_STEPS.map((s) => s.id)).toEqual(["hello", "controls", "tapWord", "meaning", "askOpen", "askInfo", "legend", "swipe", "vocabTab", "kanaDecks", "review", "reveal", "grade", "done"]);
    expect(TOUR_STEPS.length).toBeLessThanOrEqual(14);
    expect(new Set(TOUR_STEPS.flatMap((s) => s.screens))).toEqual(new Set(["/feed", "/explore", "/vocab", "/review"]));
    // No step points at the whole transcript, the button row or Explore any more.
    const targets = new Set<string>(TOUR_STEPS.map((s) => s.target).filter((x): x is NonNullable<typeof x> => !!x));
    for (const gone of ["transcript", "player", "exploreTab", "exploreSearch"]) expect(targets.has(gone)).toBe(false);
    for (const s of TOUR_STEPS) if (s.skipTo) expect(tourIndexOf(s.skipTo)).toBeLessThan(TOUR_STEPS.length);
  });

  it("action steps only move on the thing they ask for", () => {
    t().start();
    t().goTo(tourIndexOf("tapWord"));
    t().emit("swipe");
    expect(id()).toBe("tapWord");
    t().emit("word");
    expect(id()).toBe("meaning");
    t().emit("explain");
    expect(id()).toBe("askOpen");
    t().emit("askOpened");
    expect(id()).toBe("askInfo");
    expect(closes()).toBe(0);
  });

  it('"Back to the video" closes both cards for the learner and moves on', () => {
    t().start();
    t().goTo(tourIndexOf("askInfo"));
    expect(TOUR_STEPS[tourIndexOf("askInfo")]!.button).toBe("Back to the video");
    t().advance();
    expect(id()).toBe("legend");
    expect(closes()).toBe(1);
    // The closing sheets' own events arrive afterwards and change nothing.
    t().emit("askClosed");
    t().emit("cardClosed");
    expect(id()).toBe("legend");
    expect(closes()).toBe(1);
  });

  it("closing a card by hand never gets stuck: it skips the card steps and closes the other card", () => {
    for (const step of TOUR_CARD_STEPS) {
      for (const e of ["cardClosed", "askClosed"] as TourEvent[]) {
        t().reset();
        useTour.setState({ closeSignal: 0 });
        t().start();
        t().goTo(tourIndexOf(step));
        t().emit(e);
        expect(id(), `${step} + ${e}`).toBe("legend");
        expect(closes(), `${step} + ${e}`).toBe(1);
      }
    }
  });

  it("route steps move when the learner opens Vocab and the review", () => {
    t().start();
    t().goTo(tourIndexOf("swipe"));
    t().emit("swipe");
    expect(id()).toBe("vocabTab");
    t().route("/explore");
    expect(id()).toBe("vocabTab");
    t().route("/vocab");
    expect(id()).toBe("kanaDecks");
    t().advance();
    expect(id()).toBe("review");
    t().route("/review");
    expect(id()).toBe("reveal");
    t().emit("reveal");
    expect(id()).toBe("grade");
    t().emit("graded");
    expect(id()).toBe("done");
  });

  it("the last button finishes the tour, remembers it and goes back to the feed", () => {
    useApp.getState().resetTutorial();
    t().start();
    t().goTo(tourIndexOf("done"));
    expect(TOUR_STEPS[TOUR_STEPS.length - 1]!.button).toBe("Back to videos");
    t().advance();
    expect(t().index).toBeNull();
    expect(useApp.getState().tutorial.feed).toBe(true);
    expect(went).toEqual(["/feed"]);
  });

  it("a missing target jumps over the steps that depend on it", () => {
    t().start();
    t().goTo(tourIndexOf("tapWord"));
    t().skipStep();
    expect(id()).toBe("legend");
    t().goTo(tourIndexOf("review"));
    t().advance(); // "Next" on an action step whose target never showed
    expect(id()).toBe("done");
  });

  it("tips never cover what they explain", () => {
    const s = (id: string) => TOUR_STEPS[tourIndexOf(id)]!;
    // Word card: the whole card stays lit (the meaning is readable), the hand points at the button.
    expect([s("meaning").target, s("meaning").handAt, s("meaning").place, s("meaning").fullHole]).toEqual(["card", "cardExplain", "top", true]);
    expect([s("askOpen").target, s("askOpen").handAt, s("askOpen").place, s("askOpen").fullHole]).toEqual(["card", "askButton", "top", true]);
    // Flashcard: the whole card is the target, the tip rests on its empty lower part, the hand below the word.
    expect([s("reveal").target, s("reveal").place, s("reveal").fullHole]).toEqual(["reviewCard", "bottom", true]);
    expect(s("reveal").handY! > 0.5).toBe(true);
    // Three plain underline rows, no "green box" talk.
    expect(TOUR_LEGEND.map((l) => l.id)).toEqual(["new", "learning", "known"]);
    expect(TOUR_STEPS.some((x) => x.text.toLowerCase().includes("green"))).toBe(false);
    expect(TOUR_STEPS.some((x) => (x.hint ?? "").includes("above each card"))).toBe(false);
  });

  it("text is personal", () => {
    expect(tourText(TOUR_STEPS[0]!, "Mohit", 10).startsWith("Hi Mohit!")).toBe(true);
    expect(tourText(TOUR_STEPS[0]!, " ", 10).startsWith("Hi!")).toBe(true);
    expect(tourText(TOUR_STEPS[TOUR_STEPS.length - 1]!, "", 15)).toContain("15 minutes a day");
  });
});
