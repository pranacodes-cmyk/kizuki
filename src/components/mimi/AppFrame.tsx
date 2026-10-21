import { useEffect, useState, type ReactNode } from "react";
import { AnimatePresence, motion } from "motion/react";
import { BatteryFull, Signal, Wifi } from "lucide-react";

import { useHydrated } from "@/hooks/use-hydrated";
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
    const t = setTimeout(() => setSplashDone(true), 1000);
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
        <Toasts />
        <AnimatePresence>{!splashDone && <Splash key="splash" />}</AnimatePresence>
      </div>
      <StageCaption />
    </div>
  );
}

function StageBackdrop() {
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 hidden sm:block">
      <div className="absolute -left-40 -top-40 h-[520px] w-[520px] rounded-full bg-primary/10 blur-3xl" />
      <div className="absolute -bottom-48 -right-32 h-[560px] w-[560px] rounded-full bg-primary-deep/10 blur-3xl" />
    </div>
  );
}

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

function Splash() {
  return (
    <motion.div
      initial={{ opacity: 1 }}
      exit={{ opacity: 0, scale: 1.04 }}
      transition={{ duration: 0.5, ease: [0.22, 1, 0.36, 1] }}
      className="absolute inset-0 z-[80] flex flex-col items-center justify-center bg-background"
    >
      <motion.div initial={{ opacity: 0, scale: 0.6, y: 20 }} animate={{ opacity: 1, scale: 1, y: 0 }} transition={{ type: "spring", stiffness: 260, damping: 18 }}>
        <Mascot pose="face" className="h-28 w-28" />
      </motion.div>
      <motion.p initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="mt-4 text-[2.25rem] font-black tracking-tight">
        kizuki
      </motion.p>
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
