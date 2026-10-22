// Welcome tour step machine — same rules as mobile/test/tour_test.dart.
import { beforeEach, describe, expect, it } from "vitest";

import { useApp } from "@/lib/store";
import { TOUR_STEPS, tourIndexOf, tourText } from "@/lib/tour";
import { useTour } from "@/lib/tour-store";

const id = () => {
  const i = useTour.getState().index;
  return i == null ? "none" : TOUR_STEPS[i]!.id;
};
const t = () => useTour.getState();

describe("welcome tour", () => {
  beforeEach(() => t().reset());

  it("covers the whole loop: feed, word card, Explore, Vocab and the first review", () => {
    expect(TOUR_STEPS.map((s) => s.id)).toEqual(["hello", "clip", "subs", "tapWord", "meaning", "explain", "legend", "controls", "swipe", "explore", "search", "vocabTab", "review", "reveal", "grade", "done"]);
    expect(new Set(TOUR_STEPS.flatMap((s) => s.screens))).toEqual(new Set(["/feed", "/explore", "/vocab", "/review"]));
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
    expect(id()).toBe("explain");
    t().emit("cardClosed");
    expect(id()).toBe("legend");
  });

  it("closing the card before Explain skips the card steps", () => {
    t().start();
    t().goTo(tourIndexOf("meaning"));
    t().emit("cardClosed");
    expect(id()).toBe("legend");
  });

  it("route steps move when the learner opens Explore, Vocab and the review", () => {
    t().start();
    t().goTo(tourIndexOf("explore"));
    t().route("/vocab");
    expect(id()).toBe("explore");
    t().route("/explore");
    expect(id()).toBe("search");
    t().next();
    t().route("/vocab");
    expect(id()).toBe("review");
    t().route("/review");
    expect(id()).toBe("reveal");
    t().emit("reveal");
    t().emit("graded");
    expect(id()).toBe("done");
  });

  it("a missing target jumps over the steps that depend on it", () => {
    t().start();
    t().goTo(tourIndexOf("tapWord"));
    t().skipStep();
    expect(id()).toBe("legend");
    t().goTo(tourIndexOf("review"));
    t().skipStep();
    expect(id()).toBe("done");
  });

  it("finishing stops the tour and remembers it", () => {
    useApp.getState().resetTutorial();
    t().start();
    t().goTo(tourIndexOf("done"));
    t().next();
    expect(t().index).toBeNull();
    expect(useApp.getState().tutorial.feed).toBe(true);
  });

  it("text is personal", () => {
    expect(tourText(TOUR_STEPS[0]!, "Mohit", 10).startsWith("Hi Mohit!")).toBe(true);
    expect(tourText(TOUR_STEPS[0]!, " ", 10).startsWith("Hi!")).toBe(true);
    expect(tourText(TOUR_STEPS[TOUR_STEPS.length - 1]!, "", 15)).toContain("15 minutes a day");
  });
});
