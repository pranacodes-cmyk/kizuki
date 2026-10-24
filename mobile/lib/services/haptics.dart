import 'dart:async';

import 'package:flutter/services.dart';

/// Semantic haptics — mirrored 1:1 from src/lib/haptics.ts (same kinds, same pulse tables,
/// same tests). Every vibration in Kizuki goes through here, so both clients feel the same and
/// Settings → Vibration feedback switches all of it off.
enum HapticKind { tap, select, tick, light, success, celebrate, error }

enum HapticStrength { selection, light, medium, heavy }

/// Pulses per kind: (delay since the previous pulse in ms, strength).
const hapticPatterns = <HapticKind, List<(int, HapticStrength)>>{
  HapticKind.tap: [(0, HapticStrength.selection)],
  HapticKind.select: [(0, HapticStrength.selection)],
  HapticKind.tick: [(0, HapticStrength.selection)],
  HapticKind.light: [(0, HapticStrength.light)],
  HapticKind.success: [(0, HapticStrength.medium), (110, HapticStrength.light)],
  HapticKind.celebrate: [(0, HapticStrength.light), (90, HapticStrength.light), (90, HapticStrength.medium)],
  HapticKind.error: [(0, HapticStrength.medium), (70, HapticStrength.medium)],
};

/// Plan-building ring (0–100%): a soft ratchet tick every 5%, a light tap when each step's
/// caption changes (25/50/75%) and success on 100%. Null when nothing should be felt.
HapticKind? buildingHaptic(int prev, int next) {
  if (next <= prev) return null;
  if (next >= 100) return prev < 100 ? HapticKind.success : null;
  if (next ~/ 25 > prev ~/ 25) return HapticKind.light;
  if (next ~/ 5 > prev ~/ 5) return HapticKind.tick;
  return null;
}

class Haptics {
  /// Follows Settings → Vibration feedback (kept in step by the app shell).
  static bool enabled = true;
  static final Set<Timer> _pending = {};

  static void play(HapticKind kind) {
    if (!enabled) return;
    var at = 0;
    for (final (delay, strength) in hapticPatterns[kind]!) {
      at += delay;
      if (at == 0) {
        _fire(strength);
        continue;
      }
      late final Timer t;
      t = Timer(Duration(milliseconds: at), () {
        _pending.remove(t);
        if (enabled) _fire(strength);
      });
      _pending.add(t);
    }
  }

  /// Drops the rest of any multi-pulse pattern (screen closed, tests).
  static void cancelPending() {
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
  }

  static void tap() => play(HapticKind.tap);
  static void select() => play(HapticKind.select);
  static void tick() => play(HapticKind.tick);
  static void light() => play(HapticKind.light);
  static void success() => play(HapticKind.success);
  static void celebrate() => play(HapticKind.celebrate);
  static void error() => play(HapticKind.error);

  static void _fire(HapticStrength s) {
    final Future<void> f = switch (s) {
      HapticStrength.selection => HapticFeedback.selectionClick(),
      HapticStrength.light => HapticFeedback.lightImpact(),
      HapticStrength.medium => HapticFeedback.mediumImpact(),
      HapticStrength.heavy => HapticFeedback.heavyImpact(),
    };
    unawaited(f.catchError((Object _) {}));
  }
}
