import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from "react";
import { Loader2, Play, RotateCw } from "lucide-react";

import type { Clip } from "@/lib/content";
import { thumbOf } from "@/lib/content";
import { loadYouTubeApi, playerErrorMessage, YT_STATE, type YTPlayer } from "@/lib/youtube";
import { PlaybackLoopGuard, PlaybackStartGuard } from "@/lib/playback-loop";
import { track } from '@/lib/analytics';
import { clipWindowAvailable } from "@/lib/logic";
import { Button } from "./ui";

export type ClipPlayerHandle = {
  play(): void;
  pause(): void;
  toggle(): void;
  seek(t: number): void;
  time(): number;
};

type Props = {
  clip: Clip;
  active: boolean;
  /** Next clip in the feed: load the player and cue the clip (never plays) ahead of the swipe. */
  warm?: boolean;
  rate: number;
  /** Absolute video time, ~10×/s while mounted. */
  onTime: (t: number) => void;
  onPlayingChange: (playing: boolean) => void;
  /** Fired each time playback wraps from clip end back to start. */
  onLoop: () => void;
  loopRange?: { start: number; end: number } | null;
};

/**
 * One clip of a YouTube video through the official IFrame player. Created for the active feed
 * item and, cued but never playing, for the next one (`warm`) so a swipe starts at once; other
 * items show the YouTube thumbnail. Loops clip.start → clip.end. Mirrors clip_player.dart.
 */
export const ClipPlayer = forwardRef<ClipPlayerHandle, Props>(function ClipPlayer({ clip, active, warm = false, rate, onTime, onPlayingChange, onLoop, loopRange }, ref) {
  const wanted = active || warm;
  const activeRef = useRef(active);
  activeRef.current = active;
  const host = useRef<HTMLDivElement>(null);
  const player = useRef<YTPlayer | null>(null);
  /** The IFrame player only takes commands after onReady. */
  const apiReady = useRef(false);
  /** pause() asked before onReady: pause as soon as playback starts (mirrors clip_player.dart). */
  const wantPause = useRef(false);
  const loop = useRef(new PlaybackLoopGuard(clip.start));
  const startup = useRef(new PlaybackStartGuard());
  const [ready, setReady] = useState(false);
  const [state, setState] = useState<number>(YT_STATE.UNSTARTED);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  /** Still not playing a while after becoming active: offer a retry instead of an endless spinner. */
  const [slow, setSlow] = useState(false);
  const cb = useRef({ onTime, onPlayingChange, onLoop, loopRange, clip });
  cb.current = { onTime, onPlayingChange, onLoop, loopRange, clip };

  const live = () => (apiReady.current ? player.current : null);
  useImperativeHandle(ref, () => ({
    play: () => {
      wantPause.current = false;
      live()?.playVideo();
    },
    pause: () => {
      const p = live();
      if (p) p.pauseVideo();
      else wantPause.current = true;
    },
    toggle: () => {
      const p = live();
      if (!p) return;
      if (p.getPlayerState() === YT_STATE.PLAYING) p.pauseVideo();
      else p.playVideo();
    },
    seek: (t: number) => {
      const p = live();
      if (!p) return; // not ready: a queued pause stays
      // Replay / tapping a line on a ready player is an explicit play: it cancels a queued pause.
      wantPause.current = false;
      loop.current.beginSeek(t);
      p.seekTo(t, true);
      p.playVideo();
    },
    time: () => live()?.getCurrentTime() ?? clip.start,
  }), [clip.start]);

  // Create / destroy the player: for the active clip and the warmed-up next one.
  useEffect(() => {
    if (!wanted || !host.current) return;
    let cancelled = false;
    setError(null);
    setReady(false);
    setState(YT_STATE.UNSTARTED);
    apiReady.current = false;
    wantPause.current = false;
    loop.current = new PlaybackLoopGuard(clip.start);
    startup.current = new PlaybackStartGuard();
    const mount = document.createElement("div");
    host.current.appendChild(mount);
    loadYouTubeApi()
      .then((YT) => {
        if (cancelled) return;
        player.current = new YT.Player(mount, {
          videoId: clip.videoId,
          width: "100%",
          height: "100%",
          host: "https://www.youtube-nocookie.com",
          playerVars: {
            // The next clip is only cued at its start (autoplay 0): no playback, no sound.
            start: Math.floor(clip.start), end: Math.ceil(clip.end) + 1, autoplay: activeRef.current ? 1 : 0, controls: 0, playsinline: 1,
            rel: 0, modestbranding: 1, iv_load_policy: 3, cc_load_policy: 0, disablekb: 1, fs: 0, enablejsapi: 1,
            origin: window.location.origin,
          },
          events: {
            onReady: (e) => {
              if (cancelled) return;
              apiReady.current = true;
              setReady(true);
              e.target.setPlaybackRate(rate);
              if (!activeRef.current) return; // warmed up: stays cued until it becomes active
              // playerVars.start already positions the clip. A second seek here
              // interrupts startup; PlaybackStartGuard handles a genuinely ignored start.
              e.target.playVideo();
            },
            onStateChange: (e) => {
              if (cancelled) return;
              setState(e.data);
              // The next clip only waits, cued; it never plays or reports playback.
              if (!activeRef.current) {
                if (e.data === YT_STATE.PLAYING || e.data === YT_STATE.BUFFERING) e.target.pauseVideo();
                return;
              }
              if (wantPause.current && (e.data === YT_STATE.PLAYING || e.data === YT_STATE.BUFFERING)) {
                wantPause.current = false;
                e.target.pauseVideo();
              }
              // Hide YouTube's own captions (cc_load_policy is ignored when the viewer has CC on).
              if (e.data === YT_STATE.PLAYING || e.data === YT_STATE.BUFFERING) {
                const t = e.target as unknown as { unloadModule?: (m: string) => void; setOption?: (m: string, k: string, v: unknown) => void };
                try { t.unloadModule?.("captions"); t.unloadModule?.("cc"); t.setOption?.("captions", "track", {}); } catch { /* no captions */ }
              }
              cb.current.onPlayingChange(e.data === YT_STATE.PLAYING);
              const { clip: c, loopRange: lr } = cb.current;
              const start = lr?.start ?? c.start;
              const end = lr?.end ?? c.end;
              if (e.data === YT_STATE.ENDED && loop.current.shouldLoop(e.target.getCurrentTime(), start, end, false, true)) {
                e.target.seekTo(start, true);
                e.target.playVideo();
                if (!lr) cb.current.onLoop();
              }
            },
            onError: (e) => {
              if (cancelled) return;
              cb.current.onPlayingChange(false);
              setState(YT_STATE.PAUSED);
              if (activeRef.current) track('clip_failed', { category: String(e.data), clip_id: clip.id });
              setError(playerErrorMessage(e.data));
            },
          },
        });
      })
      .catch((e: Error) => !cancelled && setError(e.message));
    return () => {
      cancelled = true;
      try { player.current?.destroy(); } catch { /* already gone */ }
      player.current = null;
      mount.remove();
      setReady(false);
      setState(YT_STATE.UNSTARTED);
      cb.current.onPlayingChange(false);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wanted, clip.videoId, clip.start, attempt]);

  // A warmed-up clip becomes active: start it now. Swiped back past it: pause, stay loaded.
  const wasActive = useRef(active);
  useEffect(() => {
    if (wasActive.current === active) return;
    wasActive.current = active;
    // A pause queued during an earlier activation never blocks a new start.
    if (active) wantPause.current = false;
    const p = live();
    if (!p) return; // still loading: onReady starts it (activeRef)
    if (active) {
      loop.current = new PlaybackLoopGuard(clip.start);
      startup.current = new PlaybackStartGuard();
      loop.current.beginSeek(clip.start);
      p.setPlaybackRate(rate);
      p.seekTo(clip.start, true);
      if (!wantPause.current) p.playVideo();
    } else {
      p.pauseVideo();
      cb.current.onPlayingChange(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active]);

  // Slow network: after 9 s without playback, say so and offer a fresh start.
  useEffect(() => {
    setSlow(false);
    if (!active || error || state === YT_STATE.PLAYING) return;
    const id = setTimeout(() => { track('clip_loading_slow', { clip_id: clip.id }); setSlow(true); }, 9000);
    return () => clearTimeout(id);
  }, [active, error, state === YT_STATE.PLAYING, attempt]);

  useEffect(() => {
    if (active) track('clip_speed_changed', { speed: rate });
    if (ready) player.current?.setPlaybackRate(rate);
  }, [rate, ready]);

  // Time polling + clip / line looping (the on-screen clip only).
  useEffect(() => {
    if (!ready || error || !active) return;
    const id = setInterval(() => {
      const p = player.current;
      if (!p) return;
      const t = p.getCurrentTime();
      const { clip: c, loopRange: lr } = cb.current;
      if (!clipWindowAvailable(c.start, c.end, p.getDuration?.() ?? 0)) {
        p.pauseVideo();
        cb.current.onPlayingChange(false);
        setState(YT_STATE.PAUSED);
        setError("This clip is no longer available. Choose another clip.");
        return;
      }
      const end = lr ? lr.end : c.end;
      const start = lr ? lr.start : c.start;
      if (startup.current.shouldCorrect(t, c.start, p.getPlayerState() === YT_STATE.PLAYING)) {
        loop.current.beginSeek(c.start);
        p.seekTo(c.start, true);
        cb.current.onTime(c.start);
        return;
      }
      if (loop.current.shouldLoop(t, start, end, p.getPlayerState() === YT_STATE.PLAYING)) {
        p.seekTo(start, true);
        if (!lr) cb.current.onLoop();
        cb.current.onTime(start);
        return;
      }
      // Zero/early timestamps during startup are not a request to restart.
      cb.current.onTime(Math.max(c.start, Math.min(c.end, t)));
    }, 100);
    return () => clearInterval(id);
  }, [ready, error, active]);

  // A mounted official player must stay unobstructed, including while buffering.
  const showThumb = !wanted;

  return (
    <>
    <div className="relative aspect-video w-full overflow-hidden bg-stage">
      <div ref={host} className="absolute inset-0 [&>iframe]:h-full [&>iframe]:w-full" />
      {showThumb && !error && (
        <Button
          aria-label="Play clip"
          // Before onReady the player can't take commands; onReady starts playback itself.
          onClick={() => { wantPause.current = false; live()?.playVideo(); }}
          className="absolute inset-0 flex items-center justify-center bg-cover bg-center"
          style={{ backgroundImage: `url(${thumbOf(clip.videoId)})` }}
        >
          <span className="flex h-14 w-14 items-center justify-center rounded-full bg-stage/70">
            {active && (!ready || state === YT_STATE.BUFFERING) ? <Loader2 className="h-7 w-7 animate-spin" /> : <Play className="ml-1 h-7 w-7 fill-current" />}
          </span>
        </Button>
      )}
      {error && (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-stage/90 px-6 text-center">
          <p className="text-[0.9375rem] font-bold">{error}</p>
          <Button onClick={() => setAttempt((a) => a + 1)} className="press inline-flex items-center gap-2 rounded-full bg-surface-2 px-4 py-2 text-[0.875rem] font-extrabold">
            <RotateCw className="h-4 w-4" /> Try again
          </Button>
        </div>
      )}
    </div>
    {active && slow && !error && <Button onClick={() => setAttempt((a) => a + 1)} size="sm" variant="ghost" className="mt-2"><RotateCw className="h-4 w-4" /> Slow connection · Tap to retry</Button>}
    </>
  );
});
