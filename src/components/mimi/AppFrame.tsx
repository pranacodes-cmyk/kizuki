import { useEffect, useRef, useState, type ReactNode } from "react";
import { AnimatePresence, motion, useAnimationFrame } from "motion/react";
import { BatteryFull, Signal, Wifi } from "lucide-react";

import { useHydrated } from "@/hooks/use-hydrated";
import { SPLASH_FACE, SPLASH_FADE_MS, SPLASH_MS, SPLASH_REDUCED_MS, SPLASH_WORD, splashFrame } from "@/lib/mascot-motion";
import { useUI } from "@/lib/ui-store";
import { cn } from "@/lib/utils";

import { Mascot } from "./Mascot";

/**
 * Renders the app inside an Android device frame on desktop, full-bleed on phones.
 * Overlays (sheets, modals, toasts) portal into #overlay-root so they stay inside the device.
 */
export function AppFrame({ children }: { children: ReactNode }) {
  const hydrated = useHydrated();
  const [splashDone, setSplashDone] = useState(false);

  useEffect(() => {
    if (!hydrated) return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    // Screens start their entrances as the splash begins to fade, so the two overlap.
    const t = setTimeout(() => { setSplashDone(true); useUI.getState().setSplashing(false); }, reduced ? SPLASH_REDUCED_MS : SPLASH_MS);
    return () => clearTimeout(t);
  }, [hydrated]);

  return (
    <div className="relative flex min-h-dvh w-full items-center justify-center overflow-hidden bg-stage">
      <StageBackdrop />
      <div
        id="device"
        className={cn(
          "relative z-10 h-dvh w-full overflow-hidden bg-background [--sat:env(safe-area-inset-top)] [--sab:env(safe-area-inset-bottom)]",
          "sm:h-[min(874px,calc(100dvh-48px))] sm:w-[402px] sm:rounded-[54px] sm:[--sab:12px] sm:[--sat:34px]",
          "sm:shadow-[0_0_0_10px_oklch(0.13_0.005_270),0_0_0_11px_oklch(0.32_0.01_270),0_60px_120px_-30px_oklch(0_0_0/0.7)]",
        )}
      >
        <StatusBar />
        <div className="absolute inset-0">{hydrated ? children : null}</div>
        <div id="overlay-root" className="pointer-events-none absolute inset-0 z-[60]" />
        {/* Welcome tour: above sheets so it can spotlight the word card, below toasts. */}
        <div id="tour-root" className="pointer-events-none absolute inset-0 z-[65]" />
        <Toasts />
        <AnimatePresence>{!splashDone && <Splash key="splash" />}</AnimatePresence>
      </div>
      <StageCaption />
    </div>
  );
}

function StageBackdrop() { return null; }

function StageCaption() {
  return (
    <div className="pointer-events-none absolute left-10 top-1/2 z-0 hidden w-[300px] -translate-y-1/2 xl:block">
      <Mascot pose="listen" className="mb-4 h-28 w-28" />
      <p className="text-[2.75rem] font-black leading-none tracking-tight text-foreground">Kizuki</p>
      <p className="mt-2 text-[1.2rem] font-bold text-primary">Learn Japanese from real clips.</p>
      <p className="mt-5 text-[0.9375rem] leading-relaxed text-muted-foreground">
        Short scenes from anime, dramas, vlogs and street interviews — tap any word for its meaning, save it, and review it with the original audio. Interactive Android app prototype.
      </p>
    </div>
  );
}

function StatusBar() {
  const [time, setTime] = useState<Date | null>(null);
  useEffect(() => {
    setTime(new Date());
    const id = setInterval(() => setTime(new Date()), 20000);
    return () => clearInterval(id);
  }, []);
  return (
    <div className="pointer-events-none absolute inset-x-0 top-0 z-[70] hidden h-[34px] items-center justify-between px-8 pt-1 text-[0.8125rem] font-bold text-foreground tabular sm:flex">
      <span className="min-w-[2.5rem]">{time ? time.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }).replace(/\s?[AP]M/i, "") : ""}</span>
      <span className="absolute left-1/2 top-2.5 h-[22px] w-[22px] -translate-x-1/2 rounded-full bg-stage" />
      <span className="flex items-center gap-1.5">
        <Signal className="h-3.5 w-3.5" strokeWidth={2.5} />
        <Wifi className="h-3.5 w-3.5" strokeWidth={2.5} />
        <BatteryFull className="h-4 w-4" strokeWidth={2.2} />
      </span>
    </div>
  );
}

const EASE_OUT_CUBIC = [0.33, 1, 0.68, 1] as const;

/**
 * Cold-start splash — mirrors SplashOverlay in mobile/lib/widgets/splash.dart. Starts on the
 * plain fox face (what the phone's launch screen shows), then plays the shared splashFrame
 * choreography: squash-and-pop, two orange "click" ripples, the wordmark letter by letter.
 */
function Splash() {
  const reduced = useRef(false);
  const face = useRef<HTMLDivElement>(null);
  const glow = useRef<HTMLDivElement>(null);
  const ripples = useRef<(SVGCircleElement | null)[]>([]);
  const letters = useRef<(HTMLSpanElement | null)[]>([]);
  const tagline = useRef<HTMLParagraphElement>(null);
  const f0 = splashFrame(0, false);
  useEffect(() => { reduced.current = window.matchMedia("(prefers-reduced-motion: reduce)").matches; }, []);
  useAnimationFrame((t) => {
    const f = splashFrame(Math.min(t, reduced.current ? SPLASH_REDUCED_MS : SPLASH_MS), reduced.current);
    if (face.current) face.current.style.transform = `translateY(${f.faceDy}px) scale(${f.faceSx}, ${f.faceSy})`;
    if (glow.current) glow.current.style.opacity = String(f.glow);
    f.ripples.forEach((r, i) => {
      const el = ripples.current[i];
      if (!el) return;
      el.setAttribute("r", String(Math.max(0, r.r)));
      el.style.opacity = String(r.opacity);
      el.style.strokeWidth = String(r.width);
    });
    f.letters.forEach((l, i) => {
      const el = letters.current[i];
      if (!el) return;
      el.style.transform = `translateY(${l.dy}px)`;
      el.style.opacity = String(l.opacity);
    });
    if (tagline.current) { tagline.current.style.opacity = String(f.tagline); tagline.current.style.transform = `translateY(${f.taglineDy}px)`; }
  });
  return (
    <motion.div
      initial={{ opacity: 1 }}
      exit={{ opacity: 0, scale: 1.04 }}
      transition={{ duration: SPLASH_FADE_MS / 1000, ease: EASE_OUT_CUBIC }}
      className="absolute inset-0 z-[80] bg-background"
      aria-hidden
    >
      <svg viewBox="0 0 320 320" className="absolute left-1/2 top-1/2 h-[320px] w-[320px] -translate-x-1/2 -translate-y-1/2 overflow-visible">
        {[0, 1].map((i) => (
          <circle key={i} ref={(el) => { ripples.current[i] = el; }} cx="160" cy="160" r="0" fill="none" className="stroke-primary-glow" style={{ opacity: 0 }} />
        ))}
      </svg>
      <div
        ref={glow}
        className="absolute left-1/2 top-1/2 h-48 w-48 -translate-x-1/2 -translate-y-1/2 rounded-full"
        style={{ opacity: f0.glow, background: "radial-gradient(closest-side, color-mix(in oklab, var(--primary) 30%, transparent), transparent)" }}
      />
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2" style={{ width: SPLASH_FACE, height: SPLASH_FACE }}>
        <div ref={face} className="h-full w-full origin-bottom">
          <Mascot pose="face" className="h-full w-full" />
        </div>
      </div>
      <div className="absolute left-1/2 top-1/2 flex flex-col items-center" style={{ transform: "translate(-50%, calc(-50% + 112px))" }}>
        <p className="flex text-[2.5rem] font-black leading-none">
          {SPLASH_WORD.split("").map((ch, i) => (
            <span key={i} ref={(el) => { letters.current[i] = el; }} className="inline-block" style={{ opacity: 0, transform: `translateY(${f0.letters[i]?.dy ?? 0}px)` }}>{ch}</span>
          ))}
        </p>
        <p ref={tagline} className="mt-2 whitespace-nowrap text-[0.875rem] font-bold text-muted-foreground" style={{ opacity: 0 }}>
          <span className="font-jp text-primary">気づき</span>&nbsp;&nbsp;·&nbsp;&nbsp;the moment it clicks
        </p>
      </div>
    </motion.div>
  );
}

function Toasts() {
  const toasts = useUI((s) => s.toasts);
  const dismiss = useUI((s) => s.dismiss);
  return (
    <div className="pointer-events-none absolute inset-x-0 top-[calc(var(--sat)+10px)] z-[75] flex flex-col items-center gap-2 px-4">
      <AnimatePresence>
        {toasts.map((t) => (
          <motion.button
            key={t.id}
            layout
            initial={{ opacity: 0, y: -24, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -16, scale: 0.96 }}
            transition={{ type: "spring", stiffness: 380, damping: 30 }}
            onClick={() => dismiss(t.id)}
            className={cn(
              "pointer-events-auto flex w-full max-w-[360px] items-center gap-3 rounded-2xl px-4 py-3 text-left shadow-[0_12px_30px_-12px_oklch(0_0_0/0.6)]",
              t.tone === "achievement" ? "border-2 border-gold/60 bg-surface-2" : t.tone === "error" ? "bg-danger-soft" : "bg-surface-3",
            )}
          >
            {t.icon && <span className="text-[1.6rem] leading-none">{t.icon}</span>}
            <span className="min-w-0 flex-1">
              {t.tone === "achievement" && <span className="block text-[0.6875rem] font-black uppercase tracking-[0.12em] text-gold">Achievement unlocked</span>}
              <span className="block text-[0.9375rem] font-extrabold">{t.title}</span>
              {t.description && <span className="mt-0.5 block text-[0.8125rem] text-muted-foreground">{t.description}</span>}
            </span>
          </motion.button>
        ))}
      </AnimatePresence>
    </div>
  );
}
