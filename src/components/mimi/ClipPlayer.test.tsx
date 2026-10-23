import { act, cleanup, render } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Clip } from "@/lib/content";
import type { YTPlayer } from "@/lib/youtube";
import { ClipPlayer } from "./ClipPlayer";

afterEach(() => { cleanup(); delete window.YT; vi.useRealTimers(); });

describe("feed player seek commands", () => {
  it("lets early startup progress, and issues only one seek across stale end ticks and ENDED", async () => {
    vi.useFakeTimers();
    let time = 0;
    let state = 3;
    const seekTo = vi.fn();
    const onLoop = vi.fn();
    let emit: ((data: number) => void) | undefined;
    class FakePlayer implements YTPlayer {
      constructor(_el: HTMLElement, opts: { events?: { onReady?: (e: {target: YTPlayer}) => void; onStateChange?: (e: {data: number; target: YTPlayer}) => void } }) {
        emit = (data) => { state = data; opts.events?.onStateChange?.({data, target: this}); };
        queueMicrotask(() => opts.events?.onReady?.({target: this}));
      }
      seekTo = seekTo;
      playVideo = vi.fn(); pauseVideo = vi.fn(); setPlaybackRate = vi.fn();
      mute = vi.fn(); unMute = vi.fn(); destroy = vi.fn();
      getCurrentTime() { return time; }
      getPlayerState() { return state; }
    }
    window.YT = { Player: FakePlayer };
    const clip = { id: "eRNz6UUkDOk-143", videoId: "eRNz6UUkDOk", start: 142.6, end: 156.6 } as Clip;
    await act(async () => {
      render(<ClipPlayer clip={clip} active rate={1} onTime={vi.fn()} onPlayingChange={vi.fn()} onLoop={onLoop} />);
      await Promise.resolve();
      vi.runAllTicks();
    });
    act(() => vi.advanceTimersByTime(3000));
    expect(seekTo).toHaveBeenCalledExactlyOnceWith(142.6, true);
    act(() => { time = 142.6; emit?.(1); time = 140; vi.advanceTimersByTime(1000); });
    expect(seekTo).toHaveBeenCalledTimes(1);
    act(() => { time = 142.6; vi.advanceTimersByTime(100); });
    act(() => { time = 156.6; vi.advanceTimersByTime(100); });
    expect(seekTo).toHaveBeenCalledTimes(2);
    expect(seekTo).toHaveBeenLastCalledWith(142.6, true);
    act(() => { vi.advanceTimersByTime(3000); emit?.(0); });
    expect(seekTo).toHaveBeenCalledTimes(2);
    expect(onLoop).toHaveBeenCalledTimes(1);
    act(() => { emit?.(1); time = 142.6; vi.advanceTimersByTime(100); });
    act(() => { time = 156.6; vi.advanceTimersByTime(100); });
    expect(seekTo).toHaveBeenCalledTimes(3);
    expect(onLoop).toHaveBeenCalledTimes(2);
  });
});