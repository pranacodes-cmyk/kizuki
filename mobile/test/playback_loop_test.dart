import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/widgets/playback_loop.dart';

void main() {
  test('ignored start corrects once after real early playback, not stale zero events', () {
    final guard = PlaybackStartGuard();
    for (final t in [0.0, 0.0, 0.0, 0.1]) {
      expect(guard.shouldCorrect(t, 303.1, playing: true), false);
    }
    expect(guard.shouldCorrect(0.4, 303.1, playing: false), false);
    expect(guard.shouldCorrect(0.4, 303.1, playing: true), true);
    for (final t in [0.0, 1.0, 2.0, 303.1]) {
      expect(guard.shouldCorrect(t, 303.1, playing: true), false);
    }
  });
  test('startup zero/early keyframes never trigger a seek for either affected clip', () {
    for (final start in [142.6, 12.4]) {
      final guard = PlaybackLoopGuard(start);
      for (final t in [0.0, 0.1, start - 3, start - 2, start - 1, start, start + 1]) {
        expect(guard.shouldLoop(t, start, start + 14, playing: true), false);
      }
      expect(guard.shouldLoop(start + 14, start, start + 14, playing: true), true);
    }
  });
  test('one loop seek until its new timestamp is acknowledged, even after 250ms', () {
    final guard = PlaybackLoopGuard(142.6);
    expect(guard.shouldLoop(142.6, 142.6, 156.6, playing: true), false);
    expect(guard.shouldLoop(156.6, 142.6, 156.6, playing: true), true);
    for (var i = 0; i < 30; i++) {
      expect(guard.shouldLoop(156.6, 142.6, 156.6, playing: true), false);
    }
    expect(guard.shouldLoop(142.6, 142.6, 156.6, playing: true), false);
    expect(guard.shouldLoop(156.6, 142.6, 156.6, playing: true), true);
  });
  test('poll and ended event cannot double-loop; buffering and pause cannot loop', () {
    final guard = PlaybackLoopGuard(12.4);
    guard.shouldLoop(12.4, 12.4, 26.4, playing: true);
    expect(guard.shouldLoop(26.4, 12.4, 26.4, playing: false), false);
    expect(guard.shouldLoop(26.4, 12.4, 26.4, playing: true), true);
    expect(guard.shouldLoop(26.4, 12.4, 26.4, playing: false, ended: true), false);
  });
  test('manual line replay rejects stale timestamps and allows the next sentence loop', () {
    final guard = PlaybackLoopGuard(12.4);
    guard.beginSeek(18);
    expect(guard.shouldLoop(26.4, 18, 20, playing: true), false);
    expect(guard.shouldLoop(18, 18, 20, playing: true), false);
    expect(guard.shouldLoop(20, 18, 20, playing: true), true);
  });
}