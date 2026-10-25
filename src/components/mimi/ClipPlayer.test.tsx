import { act, cleanup, render } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { Clip } from "@/lib/content";
import type { YTPlayer } from "@/lib/youtube";
import { createRef } from "react";
import { ClipPlayer, type ClipPlayerHandle } from "./ClipPlayer";

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
    expect(seekTo).not.toHaveBeenCalled(); // start is already passed to the official player
    act(() => { time = 142.6; emit?.(1); time = 140; vi.advanceTimersByTime(1000); });
    expect(seekTo).not.toHaveBeenCalled();
    act(() => { time = 142.6; vi.advanceTimersByTime(100); });
    act(() => { time = 156.6; vi.advanceTimersByTime(100); });
    expect(seekTo).toHaveBeenCalledTimes(1);
    expect(seekTo).toHaveBeenLastCalledWith(142.6, true);
    act(() => { vi.advanceTimersByTime(3000); emit?.(0); });
    expect(seekTo).toHaveBeenCalledTimes(1);
    expect(onLoop).toHaveBeenCalledTimes(1);
    act(() => { emit?.(1); time = 142.6; vi.advanceTimersByTime(100); });
    act(() => { time = 156.6; vi.advanceTimersByTime(100); });
    expect(seekTo).toHaveBeenCalledTimes(2);
    expect(onLoop).toHaveBeenCalledTimes(2);
  });

  it("pause() while the video is still loading never crashes, and pauses once playback starts", async () => {
    const pauseVideo = vi.fn();
    let ready: (() => void) | undefined;
    let emit: ((data: number) => void) | undefined;
    // Like the real IFrame player: no commands exist until onReady.
    class LoadingPlayer {
      constructor(_el: HTMLElement, opts: { events?: { onReady?: (e: {target: YTPlayer}) => void; onStateChange?: (e: {data: number; target: YTPlayer}) => void } }) {
        const self = this as unknown as Record<string, unknown>;
        ready = () => {
          Object.assign(self, {
            seekTo: vi.fn(), playVideo: vi.fn(), pauseVideo, setPlaybackRate: vi.fn(), mute: vi.fn(), unMute: vi.fn(),
            destroy: vi.fn(), getCurrentTime: () => 0, getPlayerState: () => 1,
          });
          opts.events?.onReady?.({ target: this as unknown as YTPlayer });
        };
        emit = (data) => opts.events?.onStateChange?.({ data, target: this as unknown as YTPlayer });
      }
      destroy() {}
    }
    window.YT = { Player: LoadingPlayer as never };
    const clip = { id: "0dBf_DAXNuc-6", videoId: "0dBf_DAXNuc", start: 6, end: 23 } as Clip;
    const ref = createRef<ClipPlayerHandle>();
    await act(async () => {
      render(<ClipPlayer ref={ref} clip={clip} active rate={1} onTime={vi.fn()} onPlayingChange={vi.fn()} onLoop={vi.fn()} />);
      await Promise.resolve();
    });
    expect(() => { ref.current!.pause(); ref.current!.toggle(); ref.current!.seek(8); ref.current!.time(); }).not.toThrow();
    expect(pauseVideo).not.toHaveBeenCalled();
    act(() => { ready!(); emit!(1); });
    expect(pauseVideo).toHaveBeenCalledTimes(1);
    act(() => emit!(1));
    expect(pauseVideo).toHaveBeenCalledTimes(1);
  });

  it("a pause queued before a clip was parked never blocks its next start", async () => {
    const pauseVideo = vi.fn();
    const playVideo = vi.fn();
    let ready: (() => void) | undefined;
    let emit: ((data: number) => void) | undefined;
    class LoadingPlayer {
      constructor(_el: HTMLElement, opts: { events?: { onReady?: (e: {target: YTPlayer}) => void; onStateChange?: (e: {data: number; target: YTPlayer}) => void } }) {
        const self = this as unknown as Record<string, unknown>;
        ready = () => {
          Object.assign(self, {
            seekTo: vi.fn(), playVideo, pauseVideo, setPlaybackRate: vi.fn(), mute: vi.fn(), unMute: vi.fn(),
            destroy: vi.fn(), getCurrentTime: () => 0, getPlayerState: () => 1,
          });
          opts.events?.onReady?.({ target: this as unknown as YTPlayer });
        };
        emit = (data) => opts.events?.onStateChange?.({ data, target: this as unknown as YTPlayer });
      }
      destroy() {}
    }
    window.YT = { Player: LoadingPlayer as never };
    const clip = { id: "0dBf_DAXNuc-6", videoId: "0dBf_DAXNuc", start: 6, end: 23 } as Clip;
    const ref = createRef<ClipPlayerHandle>();
    const props = { clip, rate: 1, onTime: vi.fn(), onPlayingChange: vi.fn(), onLoop: vi.fn() };
    let view: ReturnType<typeof render> | undefined;
    await act(async () => {
      view = render(<ClipPlayer ref={ref} {...props} active />);
      await Promise.resolve();
    });
    act(() => ref.current!.pause()); // queued: the player is still loading
    await act(async () => { view!.rerender(<ClipPlayer ref={ref} {...props} active={false} warm />); await Promise.resolve(); });
    await act(async () => { view!.rerender(<ClipPlayer ref={ref} {...props} active />); await Promise.resolve(); });
    act(() => { ready!(); emit!(1); });
    expect(playVideo).toHaveBeenCalled();
    expect(pauseVideo).not.toHaveBeenCalled();
  });

  it("warms up the next clip cued and silent, then starts it at once when it becomes active", async () => {
    const calls: string[] = [];
    let opts: { playerVars?: Record<string, unknown>; events?: { onReady?: (e: {target: YTPlayer}) => void; onStateChange?: (e: {data: number; target: YTPlayer}) => void } } = {};
    let self: YTPlayer | undefined;
    class WarmPlayer implements YTPlayer {
      constructor(_el: HTMLElement, o: typeof opts) { opts = o; self = this; queueMicrotask(() => o.events?.onReady?.({ target: this })); }
      seekTo = vi.fn((t: number) => { calls.push(`seek ${t}`); });
      playVideo = vi.fn(() => { calls.push("play"); });
      pauseVideo = vi.fn(() => { calls.push("pause"); });
      setPlaybackRate = vi.fn(); mute = vi.fn(); unMute = vi.fn(); destroy = vi.fn();
      getCurrentTime() { return 6; }
      getPlayerState() { return 5; }
    }
    window.YT = { Player: WarmPlayer };
    const clip = { id: "0dBf_DAXNuc-6", videoId: "0dBf_DAXNuc", start: 6, end: 23 } as Clip;
    const onPlayingChange = vi.fn();
    const props = { clip, rate: 1, onTime: vi.fn(), onPlayingChange, onLoop: vi.fn() };
    let view: ReturnType<typeof render> | undefined;
    await act(async () => {
      view = render(<ClipPlayer {...props} active={false} warm />);
      await Promise.resolve();
    });
    expect(opts.playerVars?.["autoplay"]).toBe(0);
    expect(opts.playerVars?.["start"]).toBe(6);
    expect(calls).toEqual([]); // ready, but never played
    act(() => opts.events?.onStateChange?.({ data: 1, target: self! })); // stray playback while waiting
    expect(calls).toEqual(["pause"]);
    expect(onPlayingChange).not.toHaveBeenCalledWith(true);
    calls.length = 0;
    await act(async () => { view!.rerender(<ClipPlayer {...props} active warm={false} />); await Promise.resolve(); });
    expect(calls).toEqual(["seek 6", "play"]); // same player, no reload
  });
});
