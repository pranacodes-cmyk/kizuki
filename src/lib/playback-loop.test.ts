import { describe, expect, it } from "vitest";
import { PlaybackLoopGuard } from "./playback-loop";

describe("YouTube asynchronous playback (mirrors Flutter)", () => {
  it("startup zero/early keyframes never trigger a seek for either affected clip", () => {
    for (const start of [142.6, 12.4]) {
      const guard = new PlaybackLoopGuard(start);
      for (const t of [0, 0.1, start - 3, start - 2, start - 1, start, start + 1]) {
        expect(guard.shouldLoop(t, start, start + 14, true)).toBe(false);
      }
      expect(guard.shouldLoop(start + 14, start, start + 14, true)).toBe(true);
    }
  });
  it("one loop seek until its new timestamp is acknowledged, even after 250ms", () => {
    const guard = new PlaybackLoopGuard(142.6);
    expect(guard.shouldLoop(142.6, 142.6, 156.6, true)).toBe(false);
    expect(guard.shouldLoop(156.6, 142.6, 156.6, true)).toBe(true);
    for (let i = 0; i < 30; i++) expect(guard.shouldLoop(156.6, 142.6, 156.6, true)).toBe(false);
    expect(guard.shouldLoop(142.6, 142.6, 156.6, true)).toBe(false);
    expect(guard.shouldLoop(156.6, 142.6, 156.6, true)).toBe(true);
  });
  it("poll and ended event cannot double-loop; buffering and pause cannot loop", () => {
    const guard = new PlaybackLoopGuard(12.4);
    guard.shouldLoop(12.4, 12.4, 26.4, true);
    expect(guard.shouldLoop(26.4, 12.4, 26.4, false)).toBe(false);
    expect(guard.shouldLoop(26.4, 12.4, 26.4, true)).toBe(true);
    expect(guard.shouldLoop(26.4, 12.4, 26.4, false, true)).toBe(false);
  });
  it("manual line replay rejects stale timestamps and allows the next sentence loop", () => {
    const guard = new PlaybackLoopGuard(12.4);
    guard.beginSeek(18);
    expect(guard.shouldLoop(26.4, 18, 20, true)).toBe(false);
    expect(guard.shouldLoop(18, 18, 20, true)).toBe(false);
    expect(guard.shouldLoop(20, 18, 20, true)).toBe(true);
  });
});