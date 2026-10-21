import { AnimatePresence, motion } from "motion/react";
import { Pointer } from "lucide-react";
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";

import { useApp } from "@/lib/store";
import { TOUR_LEGEND, TOUR_LEGEND_DELAY_MS, TOUR_MAX_HOLE_HEIGHT, TOUR_STEPS } from "@/lib/tour";
import { cn } from "@/lib/utils";

import { Mascot } from "./Mascot";

type Box = { x: number; y: number; w: number; h: number };

/**
 * Welcome tour over the feed: dim overlay with a spotlight on each target ([data-tour]),
 * Kizuki's speech bubble, "Skip tour", tap to continue — mirrored by WelcomeTour in
 * mobile/lib/widgets/tour.dart.
 */
export function WelcomeTour() {
  const root = useRef<HTMLDivElement>(null);
  const [i, setI] = useState(0);
  const [hole, setHole] = useState<Box | null>(null);
  const [legendReady, setLegendReady] = useState(false);
  const completeTutorial = useApp((s) => s.completeTutorial);
  const step = TOUR_STEPS[i]!;
  const last = i === TOUR_STEPS.length - 1;

  const measure = useCallback(() => {
    const box = root.current?.getBoundingClientRect();
    const el = step.target ? document.querySelector<HTMLElement>(`[data-tour="${step.target}"]`) : null;
    if (!box || !el) return setHole(null);
    const r = el.getBoundingClientRect();
    const pad = 6;
    const x = Math.max(4, r.left - box.left - pad);
    const y = Math.max(4, r.top - box.top - pad);
    const w = Math.min(box.width - 4, r.right - box.left + pad) - x;
    const h = Math.min(TOUR_MAX_HOLE_HEIGHT, Math.min(box.height - 4, r.bottom - box.top + pad) - y);
    setHole(w < 24 || h < 24 ? null : { x, y, w, h });
  }, [step.target]);

  useLayoutEffect(() => { measure(); }, [measure]);
  useEffect(() => {
    const id = setInterval(measure, 250);
    return () => clearInterval(id);
  }, [measure]);
  useEffect(() => {
    if (step.kind !== "legend") return;
    setLegendReady(false);
    const t = setTimeout(() => setLegendReady(true), TOUR_LEGEND_DELAY_MS);
    return () => clearTimeout(t);
  }, [step.kind, i]);

  const finish = () => completeTutorial("feed");
  const next = () => {
    if (step.kind === "legend" && !legendReady) return;
    if (last) return finish();
    setHole(null);
    setI(i + 1);
  };

  const height = root.current?.clientHeight ?? 800;
  const below = !!hole && hole.y + hole.h / 2 < height * 0.45;

  return (
    <div ref={root} role="dialog" aria-label="Welcome tour" onClick={next} className="absolute inset-0 z-50 cursor-pointer select-none">
      <svg className="pointer-events-none absolute inset-0 h-full w-full" aria-hidden>
        <defs>
          <mask id="tour-hole">
            <rect width="100%" height="100%" fill="white" />
            {hole && <motion.rect initial={false} animate={{ x: hole.x, y: hole.y, width: hole.w, height: hole.h }} transition={{ duration: 0.32, ease: [0.22, 1, 0.36, 1] }} rx={18} fill="black" />}
          </mask>
        </defs>
        <rect width="100%" height="100%" className="fill-stage/70" mask="url(#tour-hole)" />
        {hole && <motion.rect initial={false} animate={{ x: hole.x, y: hole.y, width: hole.w, height: hole.h }} transition={{ duration: 0.32, ease: [0.22, 1, 0.36, 1] }} rx={18} fill="none" className="stroke-primary" strokeWidth={2.5} />}
      </svg>

      <button
        onClick={(e) => { e.stopPropagation(); finish(); }}
        className="press absolute right-4 top-[calc(var(--sat)+8px)] rounded-full border border-border bg-surface-2 px-3.5 py-2 text-[0.8125rem] font-extrabold text-muted-foreground"
      >
        Skip tour
      </button>

      <div
        className={cn("absolute inset-x-4 transition-[top,bottom] duration-300", !hole && "top-1/2 -translate-y-1/2")}
        style={hole ? (below ? { top: Math.min(hole.y + hole.h + 12, height - 260) } : { bottom: Math.max(height - hole.y + 12, 16) }) : undefined}
      >
        <AnimatePresence mode="wait">
          <motion.div key={step.id} initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.95 }} transition={{ duration: 0.25 }}>
            {step.kind === "swipe" && (
              <motion.div className="mb-4 flex justify-center" animate={{ y: [40, -40], opacity: [1, 0.1] }} transition={{ duration: 1.4, repeat: Infinity, ease: "easeInOut" }}>
                <Pointer className="h-12 w-12 text-foreground" />
              </motion.div>
            )}
            <div className="flex items-end gap-2">
              <Mascot pose={step.pose} className="h-[72px] w-[72px] shrink-0" />
              <div className="min-w-0 flex-1 rounded-[20px] bg-foreground px-4 py-3.5 shadow-[0_12px_30px_oklch(0_0_0/0.5)]">
                <p className="text-[1rem] font-extrabold leading-snug text-background">{step.text}</p>
                {step.kind === "legend" ? (
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
                    <button
                      disabled={!legendReady}
                      onClick={(e) => { e.stopPropagation(); next(); }}
                      className={cn("mt-3 h-11 w-full rounded-[14px] text-[0.9375rem] font-black text-primary-foreground transition-colors", legendReady ? "bg-primary" : "bg-primary-dim-foreground/40")}
                    >
                      Got it
                    </button>
                  </>
                ) : (
                  <p className="mt-2 text-[0.75rem] font-bold text-faint">{last ? "Tap to start learning" : "Tap to continue"}</p>
                )}
              </div>
            </div>
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}
