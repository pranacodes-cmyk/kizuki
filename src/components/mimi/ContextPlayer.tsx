import { Loader2, Play, Volume2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import type { Clip } from "@/lib/content";
import { thumbOf } from "@/lib/content";
import { loadYouTubeApi, YT_STATE, type YTPlayer } from "@/lib/youtube";

/**
 * Plays just one line of the original clip (the "original audio" on a flashcard) through the
 * official YouTube player. Visible at ≥200px tall as YouTube's embed policy requires.
 */
export function ContextPlayer({ clip, line, autoplay, replayKey = 0 }: { clip: Clip; line: number; autoplay: boolean; replayKey?: number }) {
  const host = useRef<HTMLDivElement>(null);
  const player = useRef<YTPlayer | null>(null);
  const [ready, setReady] = useState(false);
  const [started, setStarted] = useState(false);
  const [playing, setPlaying] = useState(false);
  const [failed, setFailed] = useState(false);
  const l = clip.lines[line] ?? clip.lines[0] ?? { start: clip.start, end: clip.end };
  const from = Math.max(clip.start, l.start - 0.15);
  const to = Math.min(clip.end + 0.3, l.end + 0.25);

  useEffect(() => {
    if (!host.current) return;
    let cancelled = false;
    const mount = document.createElement("div");
    host.current.appendChild(mount);
    loadYouTubeApi().then((YT) => {
      if (cancelled) return;
      player.current = new YT.Player(mount, {
        videoId: clip.videoId, width: "100%", height: "100%", host: "https://www.youtube-nocookie.com",
        playerVars: { start: Math.floor(from), autoplay: 0, controls: 0, playsinline: 1, rel: 0, modestbranding: 1, iv_load_policy: 3, cc_load_policy: 0, disablekb: 1, fs: 0, origin: window.location.origin },
        events: {
          onReady: () => !cancelled && setReady(true),
          onStateChange: (e) => {
            setPlaying(e.data === YT_STATE.PLAYING);
            // Hide YouTube's own captions (cc_load_policy is ignored when the viewer has CC on) —
            // the card already shows the sentence and its translation.
            if (e.data === YT_STATE.PLAYING || e.data === YT_STATE.BUFFERING) {
              const t = e.target as unknown as { unloadModule?: (m: string) => void; setOption?: (m: string, k: string, v: unknown) => void };
              try { t.unloadModule?.("captions"); t.unloadModule?.("cc"); t.setOption?.("captions", "track", {}); } catch { /* no captions */ }
            }
          },
          onError: () => setFailed(true),
        },
      });
    }).catch(() => setFailed(true));
    return () => {
      cancelled = true;
      try { player.current?.destroy(); } catch { /* gone */ }
      player.current = null;
      mount.remove();
    };
  }, [clip.videoId, from]);

  const play = () => {
    const p = player.current;
    if (!p || !ready) return;
    setStarted(true);
    p.seekTo(from, true);
    p.playVideo();
  };

  useEffect(() => {
    if (ready && autoplay) play();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, autoplay, replayKey]);

  useEffect(() => {
    if (!playing) return;
    const id = setInterval(() => {
      const p = player.current;
      if (p && p.getCurrentTime() >= to) p.pauseVideo();
    }, 80);
    return () => clearInterval(id);
  }, [playing, to]);

  return (
    <div className="relative min-h-[200px] w-full overflow-hidden rounded-2xl bg-stage" style={{ aspectRatio: "16 / 9" }}>
      <div ref={host} className="absolute inset-0 [&>iframe]:h-full [&>iframe]:w-full" />
      {!started && (
        <button onClick={play} aria-label="Play the original line" className="absolute inset-0 flex items-center justify-center bg-cover bg-center" style={{ backgroundImage: `url(${thumbOf(clip.videoId)})` }}>
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-stage/75">{ready ? <Play className="ml-0.5 h-6 w-6 fill-current" /> : <Loader2 className="h-6 w-6 animate-spin" />}</span>
        </button>
      )}
      {started && !playing && !failed && (
        <button onClick={play} aria-label="Replay the original line" className="absolute bottom-2 right-2 flex h-10 items-center gap-1.5 rounded-full bg-stage/80 px-3 text-[0.8125rem] font-extrabold">
          <Volume2 className="h-4 w-4" /> Replay
        </button>
      )}
      {failed && <div className="absolute inset-0 flex items-center justify-center bg-stage/85 px-4 text-center text-[0.875rem] font-bold">The original clip isn't available right now.</div>}
    </div>
  );
}
