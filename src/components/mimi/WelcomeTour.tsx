import { AnimatePresence, motion } from "motion/react";
import { Bookmark, Gauge, Play, Pointer, RotateCcw, Type } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { useNavigate, useRouterState } from "@tanstack/react-router";

import { useApp } from "@/lib/store";
import { TOUR_HAND_TIP_Y, TOUR_LEGEND, TOUR_LEGEND_DELAY_MS, TOUR_MAX_HOLE_HEIGHT, TOUR_STEPS, TOUR_TARGET_WAIT_MS, tourText, type TourStep } from "@/lib/tour";
import { setTourNavigator, useTour } from "@/lib/tour-store";
import { cn } from "@/lib/utils";

import { Mascot } from "./Mascot";
import { Button } from "./ui";

type Box = { x: number; y: number; w: number; h: number };

/** Visible box of a [data-tour] target inside the tour root: only the part inside every
 * scrolling / clipping parent counts, so a word scrolled out of the transcript is not a target
 * (it used to light the video above it). Mirrors TourAnchor.rectOf in tour.dart. */
function visibleBox(el: HTMLElement, root: DOMRect): Box | null {
  const r = el.getBoundingClientRect();
  let left = r.left, top = r.top, right = r.right, bottom = r.bottom;
  for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) {
    const cs = getComputedStyle(p);
    if (cs.overflowX === "visible" && cs.overflowY === "visible") continue;
    const c = p.getBoundingClientRect();
    left = Math.max(left, c.left); top = Math.max(top, c.top);
    right = Math.min(right, c.right); bottom = Math.min(bottom, c.bottom);
  }
  if (right - left < 8 || bottom - top < 8) return null;
  return { x: left - root.left, y: top - root.top, w: right - left, h: bottom - top };
}

/**
 * The welcome tour overlay. Portals above every screen and sheet (#tour-root), starts on the
 * feed for new learners, follows them to Vocab and their first review, spotlights the thing
 * to tap ([data-tour] targets) and brings them back to the feed. Mirrors TourHost in
 * mobile/lib/widgets/tour.dart.
 */
export function TourHost() {
  const [root, setRoot] = useState<HTMLElement | null>(null);
  useEffect(() => setRoot(document.getElementById("tour-root")), []);
  const path = useRouterState({ select: (s) => s.location.pathname });
  // The last step's "Back to videos" opens the feed.
  const navigate = useNavigate();
  useEffect(() => {
    setTourNavigator((to) => void navigate({ to }));
    return () => setTourNavigator(null);
  }, [navigate]);
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
  const [handBox, setHandBox] = useState<Box | null>(null);
  const [waitedOut, setWaitedOut] = useState(false);
  const [legendReady, setLegendReady] = useState(false);
  const [size, setSize] = useState({ w: root.clientWidth, h: root.clientHeight });
  const missing = useRef(0);
  const name = useApp((s) => s.profile.name);
  const minutes = useApp((s) => s.profile.dailyMinutes);
  const { advance, finish } = useTour.getState();

  const measure = useCallback(() => {
    const box = root.getBoundingClientRect();
    setSize((s) => (s.w === box.width && s.h === box.height ? s : { w: box.width, h: box.height }));
    if (!step.target) return;
    const els = Array.from(document.querySelectorAll<HTMLElement>(`[data-tour="${step.target}"]`));
    let found: Box | null = null;
    for (const el of els.reverse()) {
      const r = visibleBox(el, box);
      if (!r) continue;
      const pad = 6;
      const x = Math.max(4, r.x - pad);
      const y = Math.max(4, r.y - pad);
      const w = Math.min(box.width - 4, r.x + r.w + pad) - x;
      const full = Math.min(box.height - 4, r.y + r.h + pad) - y;
      const h = step.fullHole ? full : Math.min(TOUR_MAX_HOLE_HEIGHT, full);
      if (w >= 16 && h >= 16) { found = { x, y, w, h }; break; }
    }
    setHole((old) => (sameBox(old, found) ? old : found));
    // The hand points at handAt when the step lights a bigger card.
    let hand: Box | null = null;
    if (found && step.handAt) {
      for (const el of Array.from(document.querySelectorAll<HTMLElement>(`[data-tour="${step.handAt}"]`)).reverse()) {
        hand = visibleBox(el, box);
        if (hand) break;
      }
    }
    setHandBox((old) => (sameBox(old, hand) ? old : hand));
    if (!found) {
      missing.current += 200;
      if (missing.current >= TOUR_TARGET_WAIT_MS) setWaitedOut(true);
    } else {
      missing.current = 0;
      setWaitedOut(false);
    }
  }, [root, step.target, step.fullHole, step.handAt]);

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

  const handAt = step.handAt ? handBox : h;

  const onNext = () => {
    if (step.kind === "legend" && !legendReady) return;
    advance();
  };

  // Match Flutter: use the available region, never a guessed tip height.
  const safeTop = 60;
  const safeEnd = Math.max(safeTop, size.h - 16);
  const above = h ? Math.max(0, h.y - 14 - safeTop) : 0;
  const below = h ? Math.max(0, safeEnd - h.y - h.h - 14) : 0;
  const useAbove = !!h && step.place !== "bottom" && above >= below;
  const regionTop = h && step.place !== "bottom" && !useAbove ? safeEnd - below : safeTop;
  const regionEnd = h && step.place !== "bottom" && useAbove ? safeTop + above : safeEnd;
  const bubbleStyle: React.CSSProperties = { top: regionTop, height: Math.max(0, regionEnd - regionTop) };

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

      {step.hand === "tap" && h && handAt && action && (
        <div className="pointer-events-none absolute" style={{ left: handAt.x + handAt.w / 2 - 40, top: handAt.y + handAt.h * (step.handY ?? TOUR_HAND_TIP_Y) - 40, width: 80, height: 104 }}>
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
          // Action tips have no buttons: let taps through, so a tip resting on the card never blocks it.
          className={cn("absolute inset-x-4 flex flex-col", !h ? "justify-center" : useAbove || step.place === "bottom" ? "justify-end" : "justify-start", pass || action ? "pointer-events-none" : "pointer-events-auto")}
          style={bubbleStyle}
        >
          <AnimatePresence mode="wait">
            <motion.div className="min-h-0 overflow-y-auto" key={`${step.id}-${waitedOut}`} initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.95 }} transition={{ duration: 0.25 }}>
              <div className="flex items-end gap-2">
                {kind !== "controls" && <Mascot pose={step.pose} className={cn("shrink-0", step.place === "top" ? "h-10 w-10" : "h-12 w-12")} />}
                <div className="min-w-0 flex-1 rounded-[20px] bg-foreground px-4 pb-3.5 pt-3 shadow-[0_12px_30px_oklch(0_0_0/0.5)]">
                  <div className="h-1 w-full overflow-hidden rounded-full bg-background/10">
                    <div className="h-full rounded-full bg-primary" style={{ width: `${Math.max(5, ((index + 1) / TOUR_STEPS.length) * 100)}%` }} />
                  </div>
                  <p className="mt-2.5 whitespace-pre-line text-[1rem] font-extrabold leading-snug text-background">{tourText(step, name, minutes)}</p>
                  {kind === "controls" ? (
                    <>
                      <div className="mt-3 space-y-2">
                        {[[Play, "Play / pause"], [RotateCcw, "Replay · loop this line"], [Gauge, "1× · tap to change speed"], [Bookmark, "Save · Profile → Saved"], [Type, "Aa · subtitle display"]].map(([Icon, label]) => {
                          const ControlIcon = Icon as typeof Play;
                          return <div key={String(label)} className="flex items-center gap-2.5 text-[0.8125rem] font-extrabold text-background"><ControlIcon className="h-[18px] w-[18px] shrink-0 text-primary-deep" /><span>{String(label)}</span></div>;
                        })}
                      </div>
                      <Pill wide onClick={onNext}>{step.button ?? "Next"}</Pill>
                    </>
                  ) : kind === "legend" ? (
                    <>
                      <div className="mt-3 space-y-2.5">
                        {TOUR_LEGEND.map((l) => (
                          <div key={l.id} className="flex items-center gap-2">
                            <span className="flex w-14 shrink-0"><LegendWord look={l.id} /></span>
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
                    <Pill wide onClick={onNext}>{step.button ?? "Let's go!"}</Pill>
                  ) : kind === "action" ? (
                    step.hint && <p className="mt-2.5 flex items-center gap-1.5 text-[0.8125rem] font-black text-primary-deep"><Pointer className="h-4 w-4 shrink-0" />{step.hint}</p>
                  ) : step.button ? (
                    // A named button ("Back to the video") gets the full width, so it never squeezes.
                    <Pill wide onClick={onNext}>{step.button}</Pill>
                  ) : (
                    <NextRow label={`${index + 1} of ${TOUR_STEPS.length}`} onNext={onNext} />
                  )}
                </div>
              </div>
            </motion.div>
          </AnimatePresence>
        </div>
      )}

      <Button variant="ghost" size="sm"
        onClick={(e) => { e.stopPropagation(); finish(); }}
        className="press pointer-events-auto absolute right-4 top-[calc(var(--sat)+8px)] rounded-full border border-border bg-surface-2 px-3.5 py-2 text-[0.8125rem] font-extrabold text-muted-foreground"
      >
        Skip tour
      </Button>
    </div>
  );
}

function Pill({ children, onClick, disabled, wide }: { children: React.ReactNode; onClick: () => void; disabled?: boolean; wide?: boolean }) {
  return (
    <Button size="sm"
      disabled={disabled}
      onClick={(e) => { e.stopPropagation(); onClick(); }}
      className={cn("rounded-[14px] px-[18px] text-[0.9375rem] font-black text-primary-foreground transition-colors", wide ? "mt-3 h-11 w-full" : "h-9", disabled ? "bg-primary-dim-foreground/40" : "bg-primary")}
    >
      {children}
    </Button>
  );
}

function NextRow({ label, onNext }: { label: string; onNext: () => void }) {
  return (
    <div className="mt-2.5 flex items-center">
      <span className="text-[0.75rem] font-extrabold text-faint tabular">{label}</span>
      <span className="flex-1" />
      <Pill onClick={onNext}>Next</Pill>
    </div>
  );
}

/** A legend sample drawn exactly like a transcript word (Transcript Token): same font and
 * 3px underline in the status colour. */
function LegendWord({ look }: { look: (typeof TOUR_LEGEND)[number]["id"] }) {
  const underline = look === "new" ? "decoration-info" : look === "learning" ? "decoration-learning" : "decoration-transparent";
  return (
    <span className="px-0.5 leading-tight">
      <span className={cn("font-jp text-[1.3rem] font-bold text-background underline decoration-[3px] underline-offset-[6px]", underline)}>言葉</span>
    </span>
  );
}

function sameBox(a: Box | null, b: Box | null) {
  return a === b || (!!a && !!b && a.x === b.x && a.y === b.y && a.w === b.w && a.h === b.h);
}
