import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from "react";
import { Loader2, Play, RotateCw } from "lucide-react";

import type { Clip } from "@/lib/content";
import { thumbOf } from "@/lib/content";
import { loadYouTubeApi, playerErrorMessage, YT_STATE, type YTPlayer } from "@/lib/youtube";
import { PlaybackLoopGuard } from "@/lib/playback-loop";

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
  rate: number;
  /** Absolute video time, ~10×/s while mounted. */
  onTime: (t: number) => void;
  onPlayingChange: (playing: boolean) => void;
  /** Fired each time playback wraps from clip end back to start. */
  onLoop: () => void;
  loopRange?: { start: number; end: number } | null;
};

/**
 * One clip of a YouTube video through the official IFrame player. Mounted only for the active
 * feed item; inactive items show the YouTube thumbnail. Loops clip.start → clip.end.
 */
export const ClipPlayer = forwardRef<ClipPlayerHandle, Props>(function ClipPlayer({ clip, active, rate, onTime, onPlayingChange, onLoop, loopRange }, ref) {
  const host = useRef<HTMLDivElement>(null);
  const player = useRef<YTPlayer | null>(null);
  const loop = useRef(new PlaybackLoopGuard(clip.start));
  const [ready, setReady] = useState(false);
  const [state, setState] = useState<number>(YT_STATE.UNSTARTED);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [tapped, setTapped] = useState(false);
  const cb = useRef({ onTime, onPlayingChange, onLoop, loopRange, clip });
  cb.current = { onTime, onPlayingChange, onLoop, loopRange, clip };

  useImperativeHandle(ref, () => ({
    play: () => player.current?.playVideo(),
    pause: () => player.current?.pauseVideo(),
    toggle: () => {
      const p = player.current;
      if (!p) return;
      if (p.getPlayerState() === YT_STATE.PLAYING) p.pauseVideo();
      else p.playVideo();
    },
    seek: (t: number) => {
      const p = player.current;
      if (!p) return;
      loop.current.beginSeek(t);
      p.seekTo(t, true);
      p.playVideo();
    },
    time: () => player.current?.getCurrentTime() ?? clip.start,
  }), [clip.start]);

  // Create / destroy the player with the active state.
  useEffect(() => {
    if (!active || !host.current) return;
    let cancelled = false;
    let startupCorrectionIssued = false;
    setError(null);
    setReady(false);
    setTapped(false);
    setState(YT_STATE.UNSTARTED);
    loop.current = new PlaybackLoopGuard(clip.start);
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
            start: Math.floor(clip.start), end: Math.ceil(clip.end) + 1, autoplay: 1, controls: 0, playsinline: 1,
            rel: 0, modestbranding: 1, iv_load_policy: 3, cc_load_policy: 0, disablekb: 1, fs: 0, enablejsapi: 1,
            origin: window.location.origin,
          },
          events: {
            onReady: (e) => {
              if (cancelled) return;
              setReady(true);
              e.target.setPlaybackRate(rate);
              // Some players ignore playerVars.start: position once, never every tick.
              loop.current.beginSeek(clip.start);
              e.target.seekTo(clip.start, true);
              e.target.playVideo();
            },
            onStateChange: (e) => {
              if (cancelled) return;
              setState(e.data);
              // Hide YouTube's own captions (cc_load_policy is ignored when the viewer has CC on).
              if (e.data === YT_STATE.PLAYING || e.data === YT_STATE.BUFFERING) {
                const t = e.target as unknown as { unloadModule?: (m: string) => void; setOption?: (m: string, k: string, v: unknown) => void };
                try { t.unloadModule?.("captions"); t.unloadModule?.("cc"); t.setOption?.("captions", "track", {}); } catch { /* no captions */ }
              }
              cb.current.onPlayingChange(e.data === YT_STATE.PLAYING);
              const { clip: c, loopRange: lr } = cb.current;
              // A pre-play seek can be ignored; one playing-state correction is enough.
              if (e.data === YT_STATE.PLAYING && !startupCorrectionIssued) {
                startupCorrectionIssued = true;
                if (e.target.getCurrentTime() < c.start - 1.5) {
                  loop.current.beginSeek(c.start);
                  e.target.seekTo(c.start, true);
                }
              }
              const start = lr?.start ?? c.start;
              const end = lr?.end ?? c.end;
              if (e.data === YT_STATE.ENDED && loop.current.shouldLoop(e.target.getCurrentTime(), start, end, false, true)) {
                e.target.seekTo(start, true);
                e.target.playVideo();
                if (!lr) cb.current.onLoop();
              }
            },
            onError: (e) => setError(playerErrorMessage(e.data)),
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
  }, [active, clip.videoId, clip.start, attempt]);

  useEffect(() => {
    if (ready) player.current?.setPlaybackRate(rate);
  }, [rate, ready]);

  // Time polling + clip / line looping.
  useEffect(() => {
    if (!ready) return;
    const id = setInterval(() => {
      const p = player.current;
      if (!p) return;
      const t = p.getCurrentTime();
      const { clip: c, loopRange: lr } = cb.current;
      const end = lr ? lr.end : c.end;
      const start = lr ? lr.start : c.start;
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
  }, [ready]);

  // Thumbnail until playback starts; after one tap it steps aside so YouTube's own play button is reachable.
  const showThumb = !active || (!tapped && (!ready || state === YT_STATE.UNSTARTED || state === YT_STATE.CUED));

  return (
    <div className="relative aspect-video w-full overflow-hidden bg-stage">
      <div ref={host} className="absolute inset-0 [&>iframe]:h-full [&>iframe]:w-full" />
      {showThumb && !error && (
        <button
          aria-label="Play clip"
          onClick={() => { setTapped(true); player.current?.playVideo(); }}
          className="absolute inset-0 flex items-center justify-center bg-cover bg-center"
          style={{ backgroundImage: `url(${thumbOf(clip.videoId)})` }}
        >
          <span className="flex h-14 w-14 items-center justify-center rounded-full bg-stage/70">
            {active && !ready ? <Loader2 className="h-7 w-7 animate-spin" /> : <Play className="ml-1 h-7 w-7 fill-current" />}
          </span>
        </button>
      )}
      {error && (
        <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-stage/90 px-6 text-center">
          <p className="text-[0.9375rem] font-bold">{error}</p>
          <button onClick={() => setAttempt((a) => a + 1)} className="press inline-flex items-center gap-2 rounded-full bg-surface-2 px-4 py-2 text-[0.875rem] font-extrabold">
            <RotateCw className="h-4 w-4" /> Try again
          </button>
        </div>
      )}
    </div>
  );
});
