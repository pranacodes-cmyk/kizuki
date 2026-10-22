import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AnimatePresence, motion } from "motion/react";
import { Star } from "lucide-react";
import { useEffect, useState } from "react";

import { Mascot } from "@/components/mimi/Mascot";
import { Screen } from "@/components/mimi/ui";
import { useContent } from "@/lib/feed";
import { reviews } from "@/lib/onboarding";
import { useApp } from "@/lib/store";

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

const DURATION = 6500;
const RING_R = 109; // (232 - 14) / 2
const RING_C = 2 * Math.PI * RING_R;

function Building() {
  const navigate = useNavigate();
  const jlpt = useApp((s) => s.profile.jlpt);
  const minutes = useApp((s) => s.profile.dailyMinutes);
  useContent(); // warm the library while the plan "builds"
  const [pct, setPct] = useState(0);
  const [review, setReview] = useState(0);
  const steps = ["Matching clips to your interests…", `Picking scenes at your level (${jlpt})…`, `Fitting it into ${minutes} minutes a day…`, "Setting up your reminders…"];

  useEffect(() => {
    const t0 = performance.now();
    let raf = 0;
    const tick = (t: number) => {
      const p = Math.min(1, (t - t0) / DURATION);
      setPct(Math.round((1 - Math.pow(1 - p, 2.2)) * 100));
      if (p < 1) raf = requestAnimationFrame(tick);
      else setTimeout(() => void navigate({ to: "/plan", replace: true }), 450);
    };
    raf = requestAnimationFrame(tick);
    const r = setInterval(() => setReview((x) => (x + 1) % reviews.length), 2200);
    return () => { cancelAnimationFrame(raf); clearInterval(r); };
  }, [navigate]);

  const r = reviews[review] ?? reviews[0]!;
  const step = steps[Math.min(steps.length - 1, Math.floor((pct / 100) * steps.length))];

  return (
    <Screen scroll={false} className="px-6">
      <div className="flex flex-1 flex-col items-center justify-center text-center">
        {/* Progress ring with the fox bobbing inside (building.dart ProgressRingPainter). */}
        <div className="relative h-[232px] w-[232px]">
          <svg viewBox="0 0 232 232" className="absolute inset-0 h-full w-full -rotate-90" aria-hidden>
            <circle cx="116" cy="116" r={RING_R} fill="none" strokeWidth="14" className="stroke-surface-2" />
            <circle cx="116" cy="116" r={RING_R} fill="none" strokeWidth="14" strokeLinecap="round" className="stroke-primary transition-[stroke-dashoffset] duration-100" strokeDasharray={RING_C} strokeDashoffset={RING_C * (1 - pct / 100)} style={{ opacity: pct > 0 ? 1 : 0 }} />
          </svg>
          <div className="absolute inset-0 flex items-center justify-center">
            <motion.div animate={{ y: [0, -8, 0] }} transition={{ repeat: Infinity, duration: 1.4, ease: "easeInOut" }}>
              <Mascot pose="listen" className="h-[140px] w-[140px]" />
            </motion.div>
          </div>
        </div>
        <p className="tabular mt-3 text-[2.125rem] font-black leading-none text-primary" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100} aria-label="Plan progress">{pct}%</p>
        <h1 className="mt-2 text-[1.625rem] font-black leading-tight">Building your personal plan</h1>
        <p className="mt-2 h-6 text-[0.9375rem] font-bold text-muted-foreground">{step}</p>
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
