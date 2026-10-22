import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useMemo, useRef, useState } from "react";

import { ClipView } from "@/components/mimi/ClipView";
import { FeedHeader } from "@/components/mimi/FeedHeader";
import { Mascot } from "@/components/mimi/Mascot";
import { Button, ErrorState, MascotLoader } from "@/components/mimi/ui";
import { feedOrder, useContent } from "@/lib/feed";
import { canWatchClip } from "@/lib/logic";
import { FREE_DAILY_CLIPS } from "@/lib/paywall";
import { todayOf, useApp } from "@/lib/store";
import { useFeedPager } from "@/lib/feed-pager";
import { tourEmit } from "@/lib/tour-store";

/** Wheel distance that counts as "next clip", and the quiet gap that ends one wheel gesture. */
const WHEEL_STEP_PX = 40;
const WHEEL_GESTURE_GAP_MS = 200;

export const Route = createFileRoute("/_app/feed")({
  head: () => ({
    meta: [
      { title: "For You — Kizuki" },
      { name: "description", content: "Your personal feed of short Japanese clips with tap-to-translate subtitles." },
      { property: "og:title", content: "For You — Kizuki" },
      { property: "og:description", content: "Your personal feed of short Japanese clips with tap-to-translate subtitles." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Feed,
});

function Feed() {
  const { data, error, refetch, isLoading } = useContent();
  const premium = useApp((s) => s.premium.active);
  const clipsToday = useApp((s) => todayOf(s).clips);
  const [active, setActive] = useState(0);
  const scroller = useRef<HTMLDivElement>(null);

  // Order fixed for this visit (re-ranked on the next one, so it never reshuffles under you).
  const order = useMemo(() => (data ? feedOrder(data, useApp.getState()) : []), [data]);
  // Free-tier lock is decided when you arrive on a clip, so the clip you're watching never locks mid-way.
  const [lockedFrom, setLockedFrom] = useState<number | null>(null);
  useEffect(() => {
    if (lockedFrom == null && !canWatchClip(premium, clipsToday, FREE_DAILY_CLIPS)) setLockedFrom(active + 1);
    if (premium) setLockedFrom(null);
  }, [premium, clipsToday, active, lockedFrom]);

  // One swipe / wheel gesture / arrow key = one clip; the active clip is set once it settles.
  const step = useFeedPager(scroller, order.length, setActive);

  // Moving to another clip completes the tour's "swipe up" step.
  const firstActive = useRef(true);
  useEffect(() => {
    if (firstActive.current) { firstActive.current = false; return; }
    tourEmit("swipe");
  }, [active]);

  // Mouse wheel / trackpad on the desktop preview: one gesture = one clip.
  const hasData = !!data;
  const stepRef = useRef(step);
  stepRef.current = step;
  useEffect(() => {
    const box = scroller.current;
    if (!box) return;
    let acc = 0, locked = false, idle: ReturnType<typeof setTimeout> | undefined;
    const onWheel = (e: WheelEvent) => {
      if (e.ctrlKey || Math.abs(e.deltaY) < Math.abs(e.deltaX)) return; // pinch-zoom / sideways
      e.preventDefault();
      clearTimeout(idle);
      idle = setTimeout(() => { acc = 0; locked = false; }, WHEEL_GESTURE_GAP_MS);
      if (locked) return; // trackpad momentum of the gesture that already moved
      acc += e.deltaMode === 1 ? e.deltaY * 40 : e.deltaY;
      if (Math.abs(acc) < WHEEL_STEP_PX) return;
      stepRef.current(acc > 0 ? 1 : -1);
      acc = 0;
      locked = true;
    };
    box.addEventListener("wheel", onWheel, { passive: false });
    return () => { clearTimeout(idle); box.removeEventListener("wheel", onWheel); };
  }, [hasData]);

  // Keyboard ↑/↓ on desktop preview.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return;
      if (!scroller.current) return;
      e.preventDefault();
      stepRef.current(e.key === "ArrowDown" ? 1 : -1);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  return (
    <div className="absolute inset-0 flex flex-col bg-background pt-[calc(var(--sat)+6px)]">
      <FeedHeader tab="foryou" />
      {isLoading && <MascotLoader className="flex-1" label="Finding clips for you…" />}
      {error && <div className="flex flex-1 items-center"><ErrorState title="Couldn't load clips" body="Check your connection and try again." onRetry={() => void refetch()} /></div>}
      {data && (
        <div ref={scroller} className="min-h-0 flex-1 overflow-y-scroll overscroll-contain no-scrollbar">
          {order.map((id, i) => (
            <section key={id} data-index={i} className="relative h-full">
              {Math.abs(i - active) <= 1 ? (
                lockedFrom != null && i >= lockedFrom ? <LimitCard /> : data.byId[id] ? <ClipView clip={data.byId[id]} content={data} active={i === active} tourTargets inFeed /> : null
              ) : null}
            </section>
          ))}
        </div>
      )}
    </div>
  );
}

function LimitCard() {
  const navigate = useNavigate();
  return (
    <div className="flex h-full flex-col items-center justify-center px-8 pb-24 text-center">
      <Mascot pose="heart" className="h-32 w-32" />
      <h2 className="mt-3 text-[1.5rem] font-black leading-tight">You watched your {FREE_DAILY_CLIPS} free clips today!</h2>
      <p className="mt-2 text-[0.9375rem] text-muted-foreground">Great work. Review your words now, or unlock unlimited clips with a free week of Premium.</p>
      <div className="mt-6 w-full space-y-3">
        <Button onClick={() => navigate({ to: "/trial" })}>Try Premium free</Button>
        <Button variant="surface" onClick={() => navigate({ to: "/vocab" })}>Review my words</Button>
      </div>
    </div>
  );
}
