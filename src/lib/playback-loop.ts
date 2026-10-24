/** Mirrors Flutter: correct only demonstrably advancing out-of-range playback. */
export class PlaybackStartGuard {
  private first: number | null = null;
  private corrected = false;
  shouldCorrect(time: number, start: number, playing: boolean): boolean {
    if (this.corrected || !playing || !Number.isFinite(time)) return false;
    if (time >= start - 1.5) { this.first = null; return false; }
    if (this.first === null || time < this.first) { this.first = time; return false; }
    if (time - this.first < 0.25) return false;
    this.corrected = true;
    return true;
  }
}

/** Mirrors Flutter PlaybackLoopGuard: acknowledge asynchronous seeks, not a timer. */
export class PlaybackLoopGuard {
  private target: number | null;
  private progress = false;

  constructor(start: number) { this.target = start; }

  beginSeek(target: number) {
    this.target = target;
    this.progress = false;
  }

  shouldLoop(time: number, start: number, end: number, playing: boolean, ended = false): boolean {
    if (!Number.isFinite(time)) return false;
    if (this.target !== null) {
      if (Math.abs(time - this.target) <= 1.5 && time < end - 0.05) {
        this.target = null;
        this.progress = true;
      }
      return false;
    }
    if (time < end - 0.05) this.progress = true;
    if (!this.progress || (!playing && !ended) || time < end - (ended ? 0.5 : 0.05)) return false;
    this.beginSeek(start);
    return true;
  }
}