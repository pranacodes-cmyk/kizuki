import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AnimatePresence, motion } from "motion/react";
import { BookOpen, Headphones, Pause, Play, Repeat, RotateCcw, Volume2, VolumeX } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { Mascot } from "@/components/mimi/Mascot";
import { Button, Hi, Screen } from "@/components/mimi/ui";
import { FOUNDER_POSTER_URL, FOUNDER_SECONDS, FOUNDER_VIDEO_URL, FOUNDER_VIDEO_WEBM_URL, founderLines } from "@/lib/onboarding";
import { cachedFounderVideoUrl, refreshOnboardingSettings } from '@/lib/onboarding-settings';
import { preloadTrial } from '@/lib/trial-preload';
import { tr } from "@/lib/i18n";

export const Route = createFileRoute("/founder")({
  head: () => ({
    meta: [
      { title: "A quick hello before you start — Kizuki" },
      { name: "description", content: "The story behind Kizuki and learning through real Japanese clips." },
      { property: "og:title", content: "A quick hello before you start — Kizuki" },
      { property: "og:description", content: "The story behind Kizuki and learning through real Japanese clips." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Founder,
});

/** The short welcome message before the trial (a presenter from the Kizuki team, with
 * captions) — mirrors mobile/lib/screens/founder.dart. If the video can't play, the
 * animated fox "speaks" the same captions instead. */
function Founder() {
  const navigate = useNavigate();
  const videoRef = useRef<HTMLVideoElement>(null);
  const remoteVideo = cachedFounderVideoUrl();
  const [t, setT] = useState(0);
  const [total, setTotal] = useState(FOUNDER_SECONDS);
  const [playing, setPlaying] = useState(true);
  const [muted, setMuted] = useState(false);
  const [failed, setFailed] = useState(false);
  /** True once the video reports real playback; until then the poster stays on top so the
   * swap from poster to decoded frames never shows a black flash. */
  const [started, setStarted] = useState(false);

  // Start with sound; if the browser blocks that, start muted and offer the sound button.
  useEffect(() => {
    const v = videoRef.current;
    if (!v) return;
    void preloadTrial();
    // Play immediately; the settings check runs alongside and only ever cuts the slide short
    // (before, the first frame waited on that network round-trip).
    v.muted = false;
    v.play().catch(() => {
      v.muted = true;
      setMuted(true);
      v.play().catch(() => setPlaying(false));
    });
    void refreshOnboardingSettings().then((enabled) => {
      if (!enabled) { v.pause(); void navigate({ to: '/trial', replace: true }); }
    });
  }, []);

  // Fallback (no video): a timer drives the captions.
  useEffect(() => {
    if (!failed || !playing) return;
    const id = setInterval(() => setT((x) => Math.min(FOUNDER_SECONDS, x + 0.1)), 100);
    return () => clearInterval(id);
  }, [failed, playing]);

  const fail = () => { setFailed(true); setPlaying(true); };
  const ended = t >= total - 0.2;
  const toggle = () => {
    const v = videoRef.current;
    if (failed || !v) {
      if (t >= FOUNDER_SECONDS) setT(0);
      setPlaying((p) => !p);
      return;
    }
    if (ended) { v.currentTime = 0; void v.play(); }
    else if (v.paused) void v.play();
    else v.pause();
  };
  const toggleMute = (e: React.MouseEvent) => {
    e.stopPropagation();
    const v = videoRef.current;
    if (!v) return;
    v.muted = !v.muted;
    setMuted(v.muted);
    if (v.paused && !ended) void v.play();
  };
  const next = () => {
    videoRef.current?.pause();
    void navigate({ to: "/trial", replace: true });
  };

  const left = Math.max(0, Math.ceil(total - t));
  const line = [...founderLines].reverse().find((l) => l.t <= t) ?? founderLines[0];
  const r = 22, c = 2 * Math.PI * r;

  return (
    <Screen scroll={false} className="px-6">
      <h1 className="pt-4 text-center text-[1.5rem] font-black"><Hi text={tr("A quick [hello] before you start")} className="text-primary" /></h1>
      <div className="mt-5 flex min-h-0 flex-1 items-center justify-center">
      <div className="relative h-full max-h-80 w-[180px] overflow-hidden rounded-lg bg-stage">
        <button className="absolute inset-0" onClick={toggle} aria-label={ended ? tr("Play again") : playing ? tr("Pause") : tr("Play")}>
          {!failed ? (
            <video
              ref={videoRef}
              poster={FOUNDER_POSTER_URL}
              playsInline
              preload="auto"
              className="h-full w-full bg-stage object-contain"
              onTimeUpdate={(e) => setT(e.currentTarget.currentTime)}
              onLoadedMetadata={(e) => { if (Number.isFinite(e.currentTarget.duration)) setTotal(e.currentTarget.duration); }}
              onPlay={() => setPlaying(true)}
              onPlaying={() => setStarted(true)}
              onPause={() => setPlaying(false)}
              onEnded={() => setPlaying(false)}
              onError={(e) => {
                // React bubbles a <source>'s error up here: only give up once the last source fails.
                const el = e.target as HTMLElement;
                if (el.tagName === "SOURCE" && el.nextElementSibling) return;
                fail();
              }}
            >
              {/* Approved video includes captions, keeping web and Flutter identical. A
                  server-sent video leads when set; the bundled clip follows if it fails. */}
              {remoteVideo && <source src={remoteVideo} type="video/mp4" />}
              <source src={FOUNDER_VIDEO_URL} type="video/mp4" />
              <source src={FOUNDER_VIDEO_WEBM_URL} type="video/webm" onError={fail} />
            </video>
          ) : (
            <span className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="absolute inset-0 bg-[radial-gradient(circle_at_50%_35%,var(--primary-dim),transparent_65%)]" />
              <motion.span className="relative" animate={playing ? { y: [0, -6, 0] } : {}} transition={{ repeat: Infinity, duration: 2.2 }}>
                <Mascot pose="wave" className="h-44 w-44" />
              </motion.span>
              <span className="relative mt-4 flex h-8 items-end gap-1">
                {Array.from({ length: 14 }).map((_, i) => (
                  <motion.span key={i} className="w-1.5 rounded-full bg-primary" animate={playing ? { height: [6, 10 + ((i * 7) % 22), 6] } : { height: 6 }} transition={{ repeat: Infinity, duration: 0.6 + (i % 4) * 0.12, delay: i * 0.04 }} />
                ))}
              </span>
            </span>
          )}
          <span className={`absolute right-4 top-4 flex h-10 w-10 items-center justify-center rounded-full ${playing ? "bg-stage/40" : "bg-stage/70"}`}>
            {playing ? <Pause className="h-5 w-5" /> : <Play className="h-5 w-5" />}
          </span>
          {ended && (
            <span className="absolute inset-0 flex items-center justify-center">
              <span className="flex h-[72px] w-[72px] items-center justify-center rounded-full bg-stage/60"><RotateCcw className="h-8 w-8" /></span>
            </span>
          )}
        </button>
        {!started && !failed && (
          <img src={FOUNDER_POSTER_URL} alt="" aria-hidden className="pointer-events-none absolute inset-0 h-full w-full bg-stage object-contain" />
        )}
        {!failed && (
          <button onClick={toggleMute} aria-label={muted ? tr("Turn sound on") : tr("Mute")} className="absolute left-4 top-4 flex h-10 items-center justify-center gap-1.5 rounded-full bg-stage/50 px-2.5">
            {muted ? <VolumeX className="h-5 w-5" /> : <Volume2 className="h-5 w-5" />}
          </button>
        )}
        {failed && <div className="pointer-events-none absolute inset-x-4 bottom-6 flex justify-center">
          <AnimatePresence mode="wait">
            <motion.p key={line?.t} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={{ duration: 0.25 }} className="rounded-xl bg-stage/80 px-3 py-2 text-center text-[1.125rem] font-extrabold leading-snug">
              {line?.text}
            </motion.p>
          </AnimatePresence>
        </div>}
      </div>
      </div>
      <h2 className="mt-4 text-center text-[1.0625rem] font-black">{tr("Ten minutes a day. Then it just clicks.")}</h2>
      <div className="mt-3 grid grid-cols-3 gap-2">
        {[{ icon: Headphones, label: tr("Real voices") }, { icon: BookOpen, label: tr("Words in context") }, { icon: Repeat, label: tr("Lasting recall") }].map(({ icon: Icon, label }) => (
          <div key={label} className="flex flex-col items-center gap-1.5 text-center"><Icon className="h-5 w-5 text-primary" /><span className="text-xs text-foreground/70">{label}</span></div>
        ))}
      </div>
      <div className="flex items-center gap-4 pb-1 pt-5">
        <div className="relative h-14 w-14 shrink-0">
          <svg viewBox="0 0 56 56" className="h-full w-full -rotate-90">
            <circle cx="28" cy="28" r={r} fill="none" strokeWidth="5" className="stroke-surface-2" />
            <circle cx="28" cy="28" r={r} fill="none" strokeWidth="5" strokeLinecap="round" className="stroke-primary" strokeDasharray={c} strokeDashoffset={c * Math.min(1, t / total)} />
          </svg>
          <span className="absolute inset-0 flex items-center justify-center text-[0.9375rem] font-black tabular">{left}</span>
        </div>
        <Button onClick={next}>{tr("Continue")}</Button>
      </div>
    </Screen>
  );
}
