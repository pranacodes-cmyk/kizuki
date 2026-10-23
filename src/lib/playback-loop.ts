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