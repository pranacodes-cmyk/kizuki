import { motion } from "motion/react";
import { useMemo } from "react";

import { fnv1a } from "@/lib/logic";

const COLORS = ["bg-primary", "bg-gold", "bg-success", "bg-info", "bg-danger"];

/** Deterministic burst of confetti pieces falling from the top. */
export function Confetti({ count = 36 }: { count?: number }) {
  const pieces = useMemo(
    () =>
      Array.from({ length: count }, (_, i) => {
        const h = fnv1a(`c${i}`);
        return { x: (h % 1000) / 10, delay: ((h >> 10) % 60) / 100, rot: (h >> 4) % 360, dur: 1.8 + ((h >> 14) % 100) / 80, color: COLORS[i % COLORS.length], w: 6 + ((h >> 20) % 6) };
      }),
    [count],
  );
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 overflow-hidden">
      {pieces.map((p, i) => (
        <motion.span
          key={i}
          className={`absolute top-0 rounded-[2px] ${p.color}`}
          style={{ left: `${p.x}%`, width: p.w, height: p.w * 1.6 }}
          initial={{ y: -30, rotate: p.rot, opacity: 1 }}
          animate={{ y: 900, rotate: p.rot + 540, opacity: [1, 1, 0] }}
          transition={{ duration: p.dur, delay: p.delay, ease: "easeIn" }}
        />
      ))}
    </div>
  );
}
