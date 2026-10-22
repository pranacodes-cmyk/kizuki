import { AnimatePresence, motion } from "motion/react";
import { Pointer } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { useRouterState } from "@tanstack/react-router";

import { useApp } from "@/lib/store";
import { TOUR_HAND_TIP_Y, TOUR_LEGEND, TOUR_LEGEND_DELAY_MS, TOUR_MAX_HOLE_HEIGHT, TOUR_STEPS, TOUR_TARGET_WAIT_MS, tourText, type TourStep } from "@/lib/tour";
import { useTour } from "@/lib/tour-store";
import { cn } from "@/lib/utils";

import { Mascot } from "./Mascot";

type Box = { x: number; y: number; w: number; h: number };

/**
 * The welcome tour overlay. Portals above every screen and sheet (#tour-root), starts on the
 * feed for new learners, follows them to Explore, Vocab and their first review, and
 * spotlights the thing to tap ([data-tour] targets). Mirrors TourHost in
 * mobile/lib/widgets/tour.dart.
 */
export function TourHost() {
  const [root, setRoot] = useState<HTMLElement | null>(null);
  useEffect(() => setRoot(document.getElementById("tour-root")), []);
  const path = useRouterState({ select: (s) => s.location.pathname });
  const index = useTour((s) => s.index);
  const onboarded = useApp((s) => s.onboarded);
  const done = useApp((s) => s.tutorial.feed);

  // Start on the feed for anyone who hasn't finished (or skipped) it.
  useEffect(() => {
    if (index == null && onboarded && !done && path === "/feed") useTour.getState().start();
  }, [index, onboarded, done, path]);

  // Route-completed steps (Explore / Vocab / Review).
  const lastPath = useRef(path);
  useEffect(() => {
    if (lastPath.current === path) return;
    lastPath.current = path;
    useTour.getState().route(path);
  }, [path]);

  const step = index == null ? null : TOUR_STEPS[index] ?? null;
  if (!root || !step || index == null) return null;
  if (step.screens.length && !step.screens.includes(path)) return null;
  return createPortal(<TourOverlay key={step.id} step={step} index={index} root={root} />, root);
}

function TourOverlay({ step, index, root }: { step: TourStep; index: number; root: HTMLElement }) {
  const [hole, setHole] = useState<Box | null>(null);
  const [waitedOut, setWaitedOut] = useState(false);
  const [legendReady, setLegendReady] = useState(false);
  const [size, setSize] = useState({ w: root.clientWidth, h: root.clientHeight });
  const missing = useRef(0);
  const name = useApp((s) => s.profile.name);
  const minutes = useApp((s) => s.profile.dailyMinutes);
  const { next, skipStep, finish } = useTour.getState();

  const measure = useCallback(() => {
    const box = root.getBoundingClientRect();
    setSize((s) => (s.w === box.width && s.h === box.height ? s : { w: box.width, h: box.height }));
    if (!step.target) return;
    const els = Array.from(document.querySelectorAll<HTMLElement>(`[data-tour="${step.target}"]`));
    let found: Box | null = null;
    for (const el of els.reverse()) {
      const r = el.getBoundingClientRect();
      if (r.width < 8 || r.height < 8) continue;
      const pad = 6;
      const x = Math.max(4, r.left - box.left - pad);
      const y = Math.max(4, r.top - box.top - pad);
      const w = Math.min(box.width - 4, r.right - box.left + pad) - x;
      const h = Math.min(TOUR_MAX_HOLE_HEIGHT, Math.min(box.height - 4, r.bottom - box.top + pad) - y);
      if (w >= 16 && h >= 16) { found = { x, y, w, h }; break; }
    }
    setHole((old) => (old && found && old.x === found.x && old.y === found.y && old.w === found.w && old.h === found.h ? old : found));
    if (!found) {
      missing.current += 200;
      if (missing.current >= TOUR_TARGET_WAIT_MS) setWaitedOut(true);
    } else {
      missing.current = 0;
      setWaitedOut(false);
    }
  }, [root, step.target]);

  useEffect(() => {
    measure();
    const id = setInterval(measure, 200);
    return () => clearInterval(id);
  }, [measure]);

  useEffect(() => {
    if (step.kind !== "legend") return;
    const t = setTimeout(() => setLegendReady(true), TOUR_LEGEND_DELAY_MS);
    return () => clearTimeout(t);
  }, [step.kind]);

  const h = step.target && !waitedOut ? hole : null;
  const waitingForTarget = !!step.target && !h && !waitedOut;
  const action = step.kind === "action" && !waitedOut;
  const pass = !!step.passThrough && !waitedOut;
  const kind = waitedOut && step.kind === "action" ? "tap" : step.kind ?? "tap";
  const dim = pass ? 0 : waitingForTarget ? 0.35 : 0.72;

  const onNext = () => {
    if (step.kind === "legend" && !legendReady) return;
    if (step.kind === "finish") return finish();
    if (step.kind === "action") return skipStep();
    next();
  };

  // Bubble placement: under a spotlight in the top half, above one lower down, else centered.
  const EST_H = 200;
  let bubbleStyle: React.CSSProperties | undefined;
  let centered = false;
  if (h) {
    const below = h.y + h.h / 2 < size.h * 0.45;
    const spaceBelow = size.h - (h.y + h.h);
    const spaceAbove = h.y - 48;
    if (below && spaceBelow >= EST_H) bubbleStyle = { top: h.y + h.h + 14 };
    else if (!below && spaceAbove >= EST_H) bubbleStyle = { bottom: size.h - h.y + 14 };
    else bubbleStyle = { top: 56 };
  } else if (step.hand === "swipe" && !waitedOut) {
    bubbleStyle = { top: size.h * 0.2 };
  } else centered = true;

  return (
    <div role="dialog" aria-label="Welcome tour" className="absolute inset-0 select-none">
      {/* Blocking layer: tap steps advance on any tap; action steps only let the spotlight through. */}
      {!pass && !action && <div className="pointer-events-auto absolute inset-0 cursor-pointer" onClick={waitingForTarget ? undefined : onNext} />}
      {!pass && action && (h ? (
        <>
          <div className="pointer-events-auto absolute inset-x-0 top-0" style={{ height: h.y }} />
          <div className="pointer-events-auto absolute inset-x-0 bottom-0" style={{ top: h.y + h.h }} />
          <div className="pointer-events-auto absolute left-0" style={{ top: h.y, height: h.h, width: h.x }} />
          <div className="pointer-events-auto absolute right-0" style={{ top: h.y, height: h.h, left: h.x + h.w }} />
        </>
      ) : <div className="pointer-events-auto absolute inset-0" />)}

      <svg className="pointer-events-none absolute inset-0 h-full w-full" aria-hidden>
        <defs>
          <mask id="tour-hole">
            <rect width="100%" height="100%" fill="white" />
            {h && <motion.rect initial={false} animate={{ x: h.x, y: h.y, width: h.w, height: h.h }} transition={{ duration: 0.32, ease: [0.22, 1, 0.36, 1] }} rx={18} fill="black" />}
          </mask>
        </defs>
        {dim > 0 && <rect width="100%" height="100%" className="fill-stage" style={{ opacity: dim }} mask="url(#tour-hole)" />}
        {h && <motion.rect initial={false} animate={{ x: h.x, y: h.y, width: h.w, height: h.h }} transition={{ duration: 0.32, ease: [0.22, 1, 0.36, 1] }} rx={18} fill="none" className="stroke-primary" strokeWidth={3} />}
      </svg>

      {step.hand === "tap" && h && action && (
        <div className="pointer-events-none absolute" style={{ left: h.x + h.w / 2 - 40, top: h.y + h.h * TOUR_HAND_TIP_Y - 40, width: 80, height: 104 }}>
          <motion.span className="absolute left-1/2 top-[40px] block rounded-full border-[3px] border-primary" style={{ x: "-50%", y: "-50%" }} animate={{ width: [36, 64], height: [36, 64], opacity: [1, 0] }} transition={{ duration: 1.4, repeat: Infinity, ease: "easeOut" }} />
          <motion.span className="absolute left-[34px] top-[34px]" animate={{ y: [0, 8, 0] }} transition={{ duration: 1.4, repeat: Infinity, ease: "easeInOut" }}>
            <Pointer className="h-11 w-11 text-foreground drop-shadow-[0_0_12px_oklch(0_0_0/0.8)]" />
          </motion.span>
        </div>
      )}
      {step.hand === "swipe" && !waitedOut && (
        <motion.div className="pointer-events-none absolute left-1/2 -translate-x-1/2" style={{ top: size.h * 0.62 - 60 }} animate={{ y: [90, 0], opacity: [1, 0.1] }} transition={{ duration: 1.4, repeat: Infinity, ease: "easeInOut" }}>
          <Pointer className="h-12 w-12 text-foreground drop-shadow-[0_0_12px_oklch(0_0_0/0.8)]" />
        </motion.div>
      )}

      {!waitingForTarget && (
        <div
          className={cn("absolute inset-x-4", centered && "top-1/2 -translate-y-1/2", pass ? "pointer-events-none" : "pointer-events-auto")}
          style={bubbleStyle}
        >
          <AnimatePresence mode="wait">
            <motion.div key={`${step.id}-${waitedOut}`} initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.95 }} transition={{ duration: 0.25 }}>
              <div className="flex items-end gap-2">
                <Mascot pose={step.pose} className="h-16 w-16 shrink-0" />
                <div className="min-w-0 flex-1 rounded-[20px] bg-foreground px-4 pb-3.5 pt-3 shadow-[0_12px_30px_oklch(0_0_0/0.5)]">
                  <div className="h-1 w-full overflow-hidden rounded-full bg-background/10">
                    <div className="h-full rounded-full bg-primary" style={{ width: `${Math.max(5, ((index + 1) / TOUR_STEPS.length) * 100)}%` }} />
                  </div>
                  <p className="mt-2.5 text-[1rem] font-extrabold leading-snug text-background">{tourText(step, name, minutes)}</p>
                  {kind === "legend" ? (
                    <>
                      <div className="mt-3 space-y-2.5">
                        {TOUR_LEGEND.map((l) => (
                          <div key={l.id} className="flex items-center gap-3">
                            <span className={cn("font-jp text-[1.125rem] font-bold text-background underline decoration-[3px] underline-offset-[6px]", l.id === "new" ? "decoration-info" : l.id === "learning" ? "decoration-learning" : "decoration-transparent")}>言葉</span>
                            <span className="min-w-0">
                              <span className="block text-[0.875rem] font-black text-background">{l.label}</span>
                              <span className="block text-[0.75rem] font-semibold text-faint">{l.hint}</span>
                            </span>
                          </div>
                        ))}
                      </div>
                      <Pill wide disabled={!legendReady} onClick={onNext}>Got it</Pill>
                    </>
                  ) : kind === "finish" ? (
                    <Pill wide onClick={onNext}>Let's go!</Pill>
                  ) : kind === "action" ? (
                    step.hint && <p className="mt-2.5 flex items-center gap-1.5 text-[0.8125rem] font-black text-primary-deep"><Pointer className="h-4 w-4 shrink-0" />{step.hint}</p>
                  ) : (
                    <div className="mt-2.5 flex items-center">
                      <span className="text-[0.75rem] font-bold text-faint">Tap anywhere</span>
                      <span className="flex-1" />
                      <Pill onClick={onNext}>Next</Pill>
                    </div>
                  )}
                </div>
              </div>
            </motion.div>
          </AnimatePresence>
        </div>
      )}

      <button
        onClick={(e) => { e.stopPropagation(); finish(); }}
        className="press pointer-events-auto absolute right-4 top-[calc(var(--sat)+8px)] rounded-full border border-border bg-surface-2 px-3.5 py-2 text-[0.8125rem] font-extrabold text-muted-foreground"
      >
        Skip tour
      </button>
    </div>
  );
}

function Pill({ children, onClick, disabled, wide }: { children: React.ReactNode; onClick: () => void; disabled?: boolean; wide?: boolean }) {
  return (
    <button
      disabled={disabled}
      onClick={(e) => { e.stopPropagation(); onClick(); }}
      className={cn("rounded-[14px] px-[18px] text-[0.9375rem] font-black text-primary-foreground transition-colors", wide ? "mt-3 h-11 w-full" : "h-9", disabled ? "bg-primary-dim-foreground/40" : "bg-primary")}
    >
      {children}
    </button>
  );
}
