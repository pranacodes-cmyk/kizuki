// Official YouTube IFrame Player API loader. Clips always play through YouTube's own embedded
// player (never downloaded or re-hosted); the Flutter app uses youtube_player_iframe, which
// wraps the same API.

export type YTPlayer = {
  playVideo(): void;
  pauseVideo(): void;
  seekTo(seconds: number, allowSeekAhead: boolean): void;
  getCurrentTime(): number;
  getPlayerState(): number;
  getDuration?(): number;
  setPlaybackRate(rate: number): void;
  mute(): void;
  unMute(): void;
  destroy(): void;
};

type YTNamespace = {
  Player: new (
    el: HTMLElement,
    opts: {
      videoId: string;
      width?: string | number;
      height?: string | number;
      host?: string;
      playerVars?: Record<string, string | number>;
      events?: {
        onReady?: (e: { target: YTPlayer }) => void;
        onStateChange?: (e: { data: number; target: YTPlayer }) => void;
        onError?: (e: { data: number }) => void;
      };
    },
  ) => YTPlayer;
};

declare global {
  interface Window {
    YT?: YTNamespace & { loaded?: number };
    onYouTubeIframeAPIReady?: () => void;
  }
}

export const YT_STATE = { UNSTARTED: -1, ENDED: 0, PLAYING: 1, PAUSED: 2, BUFFERING: 3, CUED: 5 } as const;

let apiPromise: Promise<YTNamespace> | null = null;

export function loadYouTubeApi(): Promise<YTNamespace> {
  if (typeof window === "undefined") return Promise.reject(new Error("YouTube API needs a browser"));
  if (window.YT?.Player) return Promise.resolve(window.YT);
  if (!apiPromise) {
    apiPromise = new Promise<YTNamespace>((resolve, reject) => {
      const prev = window.onYouTubeIframeAPIReady;
      window.onYouTubeIframeAPIReady = () => {
        prev?.();
        if (window.YT) resolve(window.YT);
      };
      const s = document.createElement("script");
      s.src = "https://www.youtube.com/iframe_api";
      s.async = true;
      s.onerror = () => {
        apiPromise = null;
        reject(new Error("Couldn't reach YouTube"));
      };
      document.head.appendChild(s);
    });
  }
  return apiPromise;
}

/** YouTube player error codes → learner-facing message. */
export function playerErrorMessage(code: number) {
  if (code === 101 || code === 150 || code === 153) return "The owner doesn't allow this video to play here.";
  if (code === 100) return "This video was removed from YouTube.";
  return "This clip couldn't load. Check your connection.";
}

export const watchUrl = (videoId: string, start: number) => `https://www.youtube.com/watch?v=${videoId}&t=${Math.floor(start)}s`;
