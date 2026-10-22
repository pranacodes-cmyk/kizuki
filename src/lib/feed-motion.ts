// While the feed is mid-swipe or snapping, clips hold their time-driven re-renders.
// Why: browsers re-snap a scroll-snap container to the clip it was on whenever its content
// re-lays out during the snap animation, so a playing clip (karaoke ticks every ~100 ms)
// kept bouncing swipes back to the same clip.

/** No scroll events for this long = the feed has settled on a clip. */
export const FEED_SETTLE_MS = 140;

let movingUntil = 0;

export function markFeedMoving(now: number = performance.now()): void {
  movingUntil = now + FEED_SETTLE_MS;
}

export function feedMoving(now: number = performance.now()): boolean {
  return now < movingUntil;
}
