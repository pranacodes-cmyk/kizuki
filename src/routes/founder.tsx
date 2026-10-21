import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AnimatePresence, motion } from "motion/react";
import { Pause, Play } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { Mascot } from "@/components/mimi/Mascot";
import { Button, Screen } from "@/components/mimi/ui";
import { FOUNDER_SECONDS, founderLines } from "@/lib/onboarding";

/** When the real founder recording is added (public/founder.mp4) set this to its URL. */
const FOUNDER_VIDEO_URL: string | null = null;

export const Route = createFileRoute("/founder")({
  head: () => ({
    meta: [
      { title: "A message from the founder — Kizuki" },
      { name: "description", content: "Why Kizuki exists, in under a minute." },
      { property: "og:title", content: "A message from the founder — Kizuki" },
      { property: "og:description", content: "Why Kizuki exists, in under a minute." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Founder,
});

function Founder() {
  const navigate = useNavigate();
  const [t, setT] = useState(0);
  const [playing, setPlaying] = useState(true);
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    if (FOUNDER_VIDEO_URL || !playing) return;
    const id = setInterval(() => setT((x) => Math.min(FOUNDER_SECONDS, x + 0.1)), 100);
    return () => clearInterval(id);
  }, [playing]);

  const left = Math.max(0, Math.ceil(FOUNDER_SECONDS - t));
  const line = [...founderLines].reverse().find((l) => l.t <= t) ?? founderLines[0]!;
  const r = 22, c = 2 * Math.PI * r;

  return (
    <Screen scroll={false} className="px-6">
      <h1 className="pt-4 text-center text-[1.5rem] font-black">A message from the <span className="text-primary">founder</span></h1>
      <div className="relative mt-5 flex-1 overflow-hidden rounded-[28px] bg-surface">
        {FOUNDER_VIDEO_URL ? (
          <video ref={videoRef} src={FOUNDER_VIDEO_URL} autoPlay playsInline className="h-full w-full object-cover" onTimeUpdate={(e) => setT(e.currentTarget.currentTime)} />
        ) : (
          <button className="absolute inset-0 flex flex-col items-center justify-center" onClick={() => setPlaying((p) => !p)} aria-label={playing ? "Pause" : "Play"}>
            <div className="absolute inset-0 bg-[radial-gradient(circle_at_50%_35%,var(--primary-dim),transparent_65%)]" />
            <motion.div animate={playing ? { y: [0, -6, 0] } : {}} transition={{ repeat: Infinity, duration: 2.2 }}>
              <Mascot pose="wave" className="relative h-44 w-44" />
            </motion.div>
            <div className="relative mt-4 flex h-8 items-end gap-1">
              {Array.from({ length: 14 }).map((_, i) => (
                <motion.span key={i} className="w-1.5 rounded-full bg-primary" animate={playing ? { height: [6, 10 + ((i * 7) % 22), 6] } : { height: 6 }} transition={{ repeat: Infinity, duration: 0.6 + (i % 4) * 0.12, delay: i * 0.04 }} />
              ))}
            </div>
            {!playing && <span className="absolute right-4 top-4 flex h-10 w-10 items-center justify-center rounded-full bg-stage/70"><Play className="h-5 w-5" /></span>}
            {playing && <span className="absolute right-4 top-4 flex h-10 w-10 items-center justify-center rounded-full bg-stage/40 opacity-60"><Pause className="h-5 w-5" /></span>}
          </button>
        )}
        <div className="pointer-events-none absolute inset-x-4 bottom-6 flex justify-center">
          <AnimatePresence mode="wait">
            <motion.p key={line.t} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={{ duration: 0.3 }} className="rounded-xl bg-stage/80 px-3 py-2 text-center text-[1rem] font-extrabold leading-snug">
              {line.text}
            </motion.p>
          </AnimatePresence>
        </div>
      </div>
      <div className="flex items-center gap-4 pb-1 pt-5">
        <div className="relative h-14 w-14 shrink-0">
          <svg viewBox="0 0 56 56" className="h-full w-full -rotate-90">
            <circle cx="28" cy="28" r={r} fill="none" strokeWidth="5" className="stroke-surface-2" />
            <circle cx="28" cy="28" r={r} fill="none" strokeWidth="5" strokeLinecap="round" className="stroke-primary" strokeDasharray={c} strokeDashoffset={c * (t / FOUNDER_SECONDS)} />
          </svg>
          <span className="absolute inset-0 flex items-center justify-center text-[0.9375rem] font-black tabular">{left}</span>
        </div>
        <Button onClick={() => navigate({ to: "/trial" })}>Continue</Button>
      </div>
    </Screen>
  );
}
