import { motion, useReducedMotion } from "motion/react";
import { useMemo } from "react";

import { fnv1a } from "@/lib/logic";

const COLORS = ["bg-primary", "bg-gold", "bg-foreground"];

/** Deterministic burst of confetti pieces falling from the top. */
export function Confetti({ count = 18 }: { count?: number }) {
  const reducedMotion = useReducedMotion();
  const pieces = useMemo(
    () =>
      Array.from({ length: count }, (_, i) => {
        const h = fnv1a(`c${i}`);
        return { x: (h % 1000) / 10, delay: ((h >> 10) % 20) / 100, rot: (h >> 4) % 360, dur: 1.2 + ((h >> 14) % 40) / 100, color: COLORS[i % COLORS.length], w: 4 + ((h >> 20) % 3) };
      }),
    [count],
  );
  if (reducedMotion) return null;
  return (
    <div aria-hidden className="pointer-events-none absolute inset-x-0 top-0 h-[240px] overflow-hidden">
      {pieces.map((p, i) => (
        <motion.span
          key={i}
          className={`absolute top-0 rounded-[2px] ${p.color}`}
          style={{ left: `${p.x}%`, width: p.w, height: p.w * 1.6 }}
          initial={{ y: -12, rotate: p.rot, opacity: 1 }}
          animate={{ y: 240, rotate: p.rot + 138, opacity: [0.85, 0.85, 0] }}
          transition={{ duration: p.dur, delay: p.delay, ease: "easeIn" }}
        />
      ))}
    </div>
  );
}
