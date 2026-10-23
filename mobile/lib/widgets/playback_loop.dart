/// YouTube seeks finish asynchronously. Never re-seek stale end timestamps.
/// Mirrors src/lib/playback-loop.ts (player mechanics, not learner rules).
class PlaybackLoopGuard {
  double? _target;
  bool _progress = false;

  PlaybackLoopGuard(double start) : _target = start;

  void beginSeek(double target) {
    _target = target;
    _progress = false;
  }

  bool shouldLoop(double time, double start, double end, {required bool playing, bool ended = false}) {
    if (!time.isFinite) return false;
    final target = _target;
    if (target != null) {
      if ((time - target).abs() <= 1.5 && time < end - 0.05) {
        _target = null;
        _progress = true;
      }
      return false;
    }
    if (time < end - 0.05) _progress = true;
    if (!_progress || (!playing && !ended) || time < end - (ended ? 0.5 : 0.05)) return false;
    beginSeek(start);
    return true;
  }
}