// Web feed paging: one swipe / wheel gesture / arrow key = exactly one clip.
// Why not CSS scroll-snap: browsers re-snap to the clip they were on whenever a playing clip
// re-lays out mid-snap, so swipes bounced back. Native scrolling is kept (a swipe that starts
// on the YouTube player still scrolls the feed); this code only decides where it settles.
// Android uses Flutter's PageView, which already behaves this way.
import { useEffect, useRef, type RefObject } from "react";

import { markFeedMoving } from "./feed-motion";

/** Drag past this fraction of the screen, or flick faster than this (px/ms), to change clips. */
export const SWIPE_DISTANCE = 0.18;
export const SWIPE_VELOCITY = 0.35;
/** Scrolling with no finger on the screen settles after this quiet gap. */
export const SETTLE_IDLE_MS = 90;
/** The settle animation is finished by force after this long. */
export const SETTLE_MAX_MS = 700;

/** Which clip to settle on after a release. offset/velocity are positive towards the next clip. */
export function pageAfterRelease(base: number, offset: number, velocity: number, pageHeight: number, count: number): number {
  let dir = 0;
  if (offset > pageHeight * SWIPE_DISTANCE || (offset > 0 && velocity > SWIPE_VELOCITY)) dir = 1;
  else if (offset < -pageHeight * SWIPE_DISTANCE || (offset < 0 && velocity < -SWIPE_VELOCITY)) dir = -1;
  return Math.min(Math.max(base + dir, 0), Math.max(count - 1, 0));
}

/**
 * Pages a full-height vertical scroller. Returns step(dir) for wheel/keyboard.
 * onPage fires once the feed has settled on a new clip.
 */
export function useFeedPager(box: RefObject<HTMLDivElement | null>, count: number, onPage: (page: number) => void): (dir: number) => void {
  const stepRef = useRef<(dir: number) => void>(() => {});
  const onPageRef = useRef(onPage);
  onPageRef.current = onPage;

  useEffect(() => {
    const el = box.current;
    if (!el || count <= 0) return;
    const pageH = () => el.clientHeight || 1;
    const clamp = (i: number) => Math.min(Math.max(i, 0), count - 1);
    let page = clamp(Math.round(el.scrollTop / pageH()));
    let target: number | null = null;
    let touching = false;
    let idle: ReturnType<typeof setTimeout> | undefined;
    let force: ReturnType<typeof setTimeout> | undefined;
    const samples: Array<[number, number]> = [];

    const finish = () => {
      if (target == null) return;
      clearTimeout(force);
      if (Math.abs(el.scrollTop - target * pageH()) > 1) el.scrollTop = target * pageH();
      const changed = target !== page;
      page = target;
      target = null;
      if (changed) onPageRef.current(page);
    };
    const go = (i: number) => {
      clearTimeout(idle);
      target = clamp(i);
      if (Math.abs(el.scrollTop - target * pageH()) <= 1) { finish(); return; }
      el.scrollTo({ top: target * pageH(), behavior: "smooth" });
      clearTimeout(force);
      force = setTimeout(finish, SETTLE_MAX_MS);
    };
    const release = () => {
      const now = performance.now();
      const recent = samples.filter(([t]) => now - t < 100);
      const first = recent[0];
      const last = recent[recent.length - 1];
      const velocity = first && last && last[0] > first[0] ? (last[1] - first[1]) / (last[0] - first[0]) : 0;
      go(pageAfterRelease(page, el.scrollTop - page * pageH(), velocity, pageH(), count));
    };

    const onScroll = () => {
      markFeedMoving();
      samples.push([performance.now(), el.scrollTop]);
      if (samples.length > 12) samples.shift();
      if (target != null) {
        if (Math.abs(el.scrollTop - target * pageH()) < 1.5) finish();
        return;
      }
      if (touching) return;
      // Scrolling we didn't see a finger for (a swipe that began on the YouTube player, or
      // momentum): never pass one clip, and settle as soon as it goes quiet.
      if (Math.abs(el.scrollTop - page * pageH()) >= pageH()) { release(); return; }
      clearTimeout(idle);
      idle = setTimeout(release, SETTLE_IDLE_MS);
    };
    const onTouchStart = () => {
      touching = true;
      clearTimeout(idle);
      if (target != null) { clearTimeout(force); page = clamp(Math.round(el.scrollTop / pageH())); target = null; }
    };
    const onTouchEnd = (e: TouchEvent) => {
      if (e.touches.length) return;
      touching = false;
      release();
    };
    const keepAligned = new ResizeObserver(() => { if (target == null && !touching) el.scrollTop = page * pageH(); });

    stepRef.current = (dir: number) => go((target ?? page) + dir);
    el.addEventListener("scroll", onScroll, { passive: true });
    el.addEventListener("touchstart", onTouchStart, { passive: true });
    el.addEventListener("touchend", onTouchEnd, { passive: true });
    el.addEventListener("touchcancel", onTouchEnd, { passive: true });
    keepAligned.observe(el);
    return () => {
      clearTimeout(idle);
      clearTimeout(force);
      keepAligned.disconnect();
      el.removeEventListener("scroll", onScroll);
      el.removeEventListener("touchstart", onTouchStart);
      el.removeEventListener("touchend", onTouchEnd);
      el.removeEventListener("touchcancel", onTouchEnd);
      stepRef.current = () => {};
    };
  }, [box, count]);

  return (dir: number) => stepRef.current(dir);
}
