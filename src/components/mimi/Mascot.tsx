import { AnimatePresence, motion, useAnimationFrame, useReducedMotion } from "motion/react";
import { useEffect, useRef, type ReactNode } from "react";

import brave from "@/assets/mascot/mimi-brave.png";
import cheer from "@/assets/mascot/mimi-cheer.png";
import face from "@/assets/mascot/mimi-face.png";
import heart from "@/assets/mascot/mimi-heart.png";
import listen from "@/assets/mascot/mimi-listen.png";
import read from "@/assets/mascot/mimi-read.png";
import think from "@/assets/mascot/mimi-think.png";
import wave from "@/assets/mascot/mimi-wave.png";
import { haptic } from "@/lib/haptics";
import { ENTER_MS, HOP_MS, mascotFrame, POP_MS, POP_SCALES, POP_TIMES, type MascotIdle } from "@/lib/mascot-motion";
import { useUI } from "@/lib/ui-store";
import { cn } from "@/lib/utils";
import { tr } from "@/lib/i18n";

export const mascots = { wave, cheer, listen, brave, read, heart, think, face } as const;
export type MascotPose = keyof typeof mascots;

export function Mascot({ pose = "wave", className, alt = "" }: { pose?: MascotPose; className?: string; alt?: string }) {
  return <img src={mascots[pose]} alt={alt} width={512} height={512} draggable={false} className={cn("select-none object-contain", className)} />;
}

const EASE_OUT_CUBIC = [0.33, 1, 0.68, 1] as const;
const clamp01 = (t: number) => (t < 0 ? 0 : t > 1 ? 1 : t);

/**
 * Kizuki the fox, alive — mirrored by LivelyMascot in mobile/lib/widgets/lively_mascot.dart.
 * An idle loop (breathe / float / groove), an optional spring entrance (after the splash),
 * a squash-and-stretch hop whenever `hopKey` changes or `hopAfter` ms pass, and a "boop" hop
 * with a light tap when `tappable`. Every frame comes from the shared mascotFrame math.
 */
export function LivelyMascot({
  pose, size, idle = "breathe", entrance = false, entranceDelay = 0, hopKey, hopAfter, tappable = false, halo = false, className, alt = "",
}: {
  pose: MascotPose; size: number; idle?: MascotIdle; entrance?: boolean; entranceDelay?: number; hopKey?: unknown; hopAfter?: number;
  tappable?: boolean; halo?: boolean; className?: string; alt?: string;
}) {
  const reduced = !!useReducedMotion();
  const splashing = useUI((s) => s.splashing);
  const splashingRef = useRef(splashing);
  splashingRef.current = splashing;
  const body = useRef<HTMLDivElement>(null);
  const glow = useRef<HTMLDivElement>(null);
  const st = useRef({
    enterWaiting: entrance,
    enterAt: null as number | null,
    hopRequested: false,
    hopAt: null as number | null,
    hopPlannedAt: !entrance && hopAfter != null ? hopAfter : (null as number | null),
  });

  const first = useRef(true);
  useEffect(() => {
    if (first.current) { first.current = false; return; }
    st.current.hopRequested = true;
  }, [hopKey]);

  useAnimationFrame((t) => {
    const el = body.current;
    if (!el) return;
    const s = st.current;
    if (reduced) {
      el.style.transform = "none";
      el.style.opacity = "1";
      if (glow.current) glow.current.style.opacity = "1";
      return;
    }
    if (s.enterWaiting && !splashingRef.current) {
      s.enterWaiting = false;
      s.enterAt = t + entranceDelay;
      if (hopAfter != null) s.hopPlannedAt = s.enterAt + hopAfter;
    }
    if (s.hopRequested) { s.hopRequested = false; s.hopAt = t; }
    if (s.hopPlannedAt != null && t >= s.hopPlannedAt) { s.hopAt = s.hopPlannedAt; s.hopPlannedAt = null; }
    let enter = 1;
    if (s.enterWaiting) enter = 0;
    else if (s.enterAt != null) { enter = clamp01((t - s.enterAt) / ENTER_MS); if (enter >= 1) s.enterAt = null; }
    let hop: number | null = null;
    if (s.hopAt != null) { hop = (t - s.hopAt) / HOP_MS; if (hop >= 1) { s.hopAt = null; hop = null; } }
    const f = mascotFrame(idle, t, enter, hop, size);
    el.style.transform = `translateY(${f.dy}px) rotate(${f.rot}rad) scale(${f.sx}, ${f.sy})`;
    el.style.opacity = String(clamp01(f.opacity));
    if (glow.current) glow.current.style.opacity = String(clamp01(f.halo * f.opacity));
  });

  const inner = (
    <>
      {halo && (
        <div
          ref={glow}
          aria-hidden
          className="pointer-events-none absolute inset-[8%] rounded-full"
          style={{ opacity: entrance && !reduced ? 0 : 1, background: "radial-gradient(closest-side, color-mix(in oklab, var(--primary) 30%, transparent), transparent)" }}
        />
      )}
      <div ref={body} className="absolute inset-0 origin-bottom will-change-transform" style={{ opacity: entrance && !reduced ? 0 : 1 }}>
        <AnimatePresence initial={false}>
          <motion.img
            key={pose}
            src={mascots[pose]}
            alt={alt}
            width={512}
            height={512}
            draggable={false}
            className="absolute inset-0 h-full w-full origin-bottom select-none object-contain"
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.22 }}
          />
        </AnimatePresence>
      </div>
    </>
  );
  const style = { width: size, height: size };
  if (tappable) {
    return (
      <button
        type="button"
        aria-label={tr("Kizuki the fox")}
        onClick={() => { haptic("light"); st.current.hopRequested = true; }}
        className={cn("relative block shrink-0", className)}
        style={style}
      >
        {inner}
      </button>
    );
  }
  return <div aria-hidden={alt ? undefined : true} className={cn("relative shrink-0", className)} style={style}>{inner}</div>;
}

/** Pops its child (1 → 1.25 → 0.95 → 1) each time `active` turns on — answer cards' emoji. */
export function Pop({ active, children, className }: { active: boolean; children: ReactNode; className?: string }) {
  const reduced = useReducedMotion();
  return (
    <motion.span
      className={cn("inline-flex", className)}
      initial={false}
      animate={active && !reduced ? { scale: [...POP_SCALES] } : { scale: 1 }}
      transition={{ duration: POP_MS / 1000, times: [...POP_TIMES], ease: "easeInOut" }}
    >
      {children}
    </motion.span>
  );
}

/** Fades its child up into place after `delay` ms — once the splash has gone. */
export function FadeUp({ delay = 0, dy = 10, children, className }: { delay?: number; dy?: number; children: ReactNode; className?: string }) {
  const reduced = useReducedMotion();
  const splashing = useUI((s) => s.splashing);
  return (
    <motion.div
      className={className}
      initial={reduced ? false : { opacity: 0, y: dy }}
      animate={splashing && !reduced ? { opacity: 0, y: dy } : { opacity: 1, y: 0 }}
      transition={{ delay: delay / 1000, duration: 0.36, ease: EASE_OUT_CUBIC }}
    >
      {children}
    </motion.div>
  );
}
