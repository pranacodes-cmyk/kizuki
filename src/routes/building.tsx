import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { Star } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { LivelyMascot } from "@/components/mimi/Mascot";
import { Screen } from "@/components/mimi/ui";
import { useContent } from "@/lib/feed";
import { buildingHaptic, haptic } from "@/lib/haptics";
import { BUILD_DONE_MS, BUILD_MS, RING_PULSE_MS } from "@/lib/mascot-motion";
import { reviews } from "@/lib/onboarding";
import { useApp } from "@/lib/store";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/building")({
  head: () => ({
    meta: [
      { title: "Building your plan — Kizuki" },
      { name: "description", content: "Kizuki is matching real Japanese clips to your interests and level." },
      { property: "og:title", content: "Building your plan — Kizuki" },
      { property: "og:description", content: "Kizuki is matching real Japanese clips to your interests and level." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Building,
});

const STROKE = 14;
const RING_R = 109; // (232 - 14) / 2
const RING_C = 2 * Math.PI * RING_R;
const EASE_OUT_CUBIC = [0.33, 1, 0.68, 1] as const;

/**
 * "Building your personal plan" — mirrors building.dart. The fox grooves to its headphones
 * while the ring fills with soft ratchet ticks (buildingHaptic); on 100% it cheers, the ring
 * pulses once with a success tap, then the plan opens.
 */
function Building() {
  const navigate = useNavigate();
  const reducedMotion = useReducedMotion();
  const jlpt = useApp((s) => s.profile.jlpt);
  const minutes = useApp((s) => s.profile.dailyMinutes);
  useContent(); // warm the library while the plan "builds"
  const [pct, setPct] = useState(0);
  const [done, setDone] = useState(false);
  const [review, setReview] = useState(0);
  const last = useRef(0);
  const steps = ["Matching clips to your interests…", `Picking scenes at your level (${jlpt})…`, `Fitting it into ${minutes} minutes a day…`, "Setting up your reminders…"];

  useEffect(() => {
    const t0 = performance.now();
    let raf = 0;
    let leave: ReturnType<typeof setTimeout> | undefined;
    const tick = (t: number) => {
      // rAF timestamps can be a little earlier than t0; never go below 0%.
      const p = Math.min(1, Math.max(0, (t - t0) / BUILD_MS));
      const next = Math.round((1 - Math.pow(1 - p, 2.2)) * 100);
      const felt = buildingHaptic(last.current, next);
      if (felt) haptic(felt);
      last.current = next;
      setPct(next);
      // Done the moment the ring reads 100% (the eased fill gets there a little before the clock).
      if (next < 100) raf = requestAnimationFrame(tick);
      else {
        setDone(true);
        leave = setTimeout(() => void navigate({ to: "/plan", replace: true }), BUILD_DONE_MS);
      }
    };
    raf = requestAnimationFrame(tick);
    const r = setInterval(() => setReview((x) => (x + 1) % reviews.length), 2200);
    return () => { cancelAnimationFrame(raf); clearInterval(r); if (leave) clearTimeout(leave); };
  }, [navigate]);

  const r = reviews[review] ?? reviews[0];
  if (!r) return null;
  const step = done ? "All set — opening your plan" : steps[Math.min(steps.length - 1, Math.floor((pct / 100) * steps.length))];
  const v = pct / 100;
  const head = { x: 116 + RING_R * Math.cos(2 * Math.PI * v), y: 116 + RING_R * Math.sin(2 * Math.PI * v) };

  return (
    <Screen scroll={false} className="px-6">
      <div className="flex flex-1 flex-col items-center justify-center text-center">
        {/* Progress ring with a glowing head and the fox grooving inside (building.dart ProgressRingPainter). */}
        <div className="relative h-[232px] w-[232px]">
          <svg viewBox="0 0 232 232" className="absolute inset-0 h-full w-full -rotate-90 overflow-visible" aria-hidden>
            <circle cx="116" cy="116" r={RING_R} fill="none" strokeWidth={STROKE} className="stroke-surface-2" />
            <circle cx="116" cy="116" r={RING_R} fill="none" strokeWidth={STROKE} strokeLinecap="round" className="stroke-primary" strokeDasharray={RING_C} strokeDashoffset={RING_C * (1 - v)} style={{ opacity: pct > 0 ? 1 : 0 }} />
            {pct > 0 && pct < 100 && (
              <>
                <circle cx={head.x} cy={head.y} r={STROKE * 0.9} className="fill-primary-glow" style={{ opacity: 0.45, filter: "blur(6px)" }} />
                <circle cx={head.x} cy={head.y} r={STROKE / 2 - 2.5} className="fill-primary-glow" />
              </>
            )}
            {done && !reducedMotion && (
              <motion.circle
                cx="116" cy="116" r={RING_R} fill="none" className="stroke-primary"
                style={{ transformBox: "fill-box", transformOrigin: "center" }}
                initial={{ scale: 1, opacity: 0.5, strokeWidth: STROKE }}
                animate={{ scale: 1.14, opacity: 0, strokeWidth: STROKE * 0.4 }}
                transition={{ duration: RING_PULSE_MS / 1000, scale: { duration: RING_PULSE_MS / 1000, ease: EASE_OUT_CUBIC }, opacity: { duration: RING_PULSE_MS / 1000, ease: "linear" }, strokeWidth: { duration: RING_PULSE_MS / 1000, ease: "linear" } }}
              />
            )}
          </svg>
          <div className="absolute inset-0 flex items-center justify-center">
            <LivelyMascot pose={done ? "cheer" : "listen"} size={140} idle={done ? "breathe" : "groove"} hopKey={done} />
          </div>
        </div>
        <p className="tabular mt-3 text-[2.125rem] font-black leading-none text-primary" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100} aria-label="Plan progress">{pct}%</p>
        <h1 className="mt-2 text-[1.625rem] font-black leading-tight">Building your personal plan</h1>
        <div className="relative mt-2 h-11 w-full">
          <AnimatePresence initial={false}>
            <motion.p
              key={step}
              initial={{ opacity: 0, y: 11 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.26 }}
              className={cn("absolute inset-x-0 top-0 text-[0.9375rem] font-bold", done ? "text-success" : "text-muted-foreground")}
            >
              {step}
            </motion.p>
          </AnimatePresence>
        </div>
      </div>
      <div className="relative mb-4 h-[132px]">
        <AnimatePresence mode="wait">
          <motion.div key={review} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -16 }} transition={{ duration: 0.35 }} className="absolute inset-0 rounded-3xl bg-surface p-5">
            <div className="flex gap-0.5">{Array.from({ length: r.stars }).map((_, i) => <Star key={i} className="h-4 w-4 fill-gold text-gold" />)}</div>
            <p className="mt-2 text-[0.9375rem] font-bold leading-snug">“{r.text}”</p>
            <p className="mt-2 text-[0.8125rem] font-bold text-muted-foreground">— {r.name}</p>
          </motion.div>
        </AnimatePresence>
      </div>
    </Screen>
  );
}
