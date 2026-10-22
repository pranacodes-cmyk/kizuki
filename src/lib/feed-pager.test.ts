import { describe, expect, it } from "vitest";

import { pageAfterRelease } from "./feed-pager";

const H = 800;

describe("feed paging: one swipe = one clip", () => {
  it("a slow drag past 18% of the screen goes to the next clip", () => {
    expect(pageAfterRelease(3, 150, 0, H, 10)).toBe(4);
  });

  it("a short slow drag springs back to the same clip", () => {
    expect(pageAfterRelease(3, 100, 0.1, H, 10)).toBe(3);
    expect(pageAfterRelease(3, -100, -0.1, H, 10)).toBe(3);
  });

  it("a quick flick changes clips even when it is short", () => {
    expect(pageAfterRelease(3, 40, 0.5, H, 10)).toBe(4);
    expect(pageAfterRelease(3, -40, -0.5, H, 10)).toBe(2);
  });

  it("never moves more than one clip, even after a long drag", () => {
    expect(pageAfterRelease(3, 1500, 3, H, 10)).toBe(4);
  });

  it("stays inside the feed at both ends", () => {
    expect(pageAfterRelease(0, -300, -1, H, 10)).toBe(0);
    expect(pageAfterRelease(9, 300, 1, H, 10)).toBe(9);
  });
});
