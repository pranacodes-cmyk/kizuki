import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/services/haptics.dart';
import 'package:mimi/state/app_state.dart';

// Mirrors src/lib/haptics.test.ts — same tables, same expected values.
void main() {
  test('uses one soft pulse for taps and choices, and short sequences for moments', () {
    expect(hapticPatterns, {
      HapticKind.tap: [(0, HapticStrength.selection)],
      HapticKind.select: [(0, HapticStrength.selection)],
      HapticKind.tick: [(0, HapticStrength.selection)],
      HapticKind.light: [(0, HapticStrength.light)],
      HapticKind.success: [(0, HapticStrength.medium), (110, HapticStrength.light)],
      HapticKind.celebrate: [(0, HapticStrength.light), (90, HapticStrength.light), (90, HapticStrength.medium)],
      HapticKind.error: [(0, HapticStrength.medium), (70, HapticStrength.medium)],
    });
  });

  test('plan ring ticks every 5%, taps at each step and succeeds once at 100%', () {
    expect(buildingHaptic(0, 4), isNull);
    expect(buildingHaptic(4, 5), HapticKind.tick);
    expect(buildingHaptic(7, 8), isNull);
    expect(buildingHaptic(24, 25), HapticKind.light);
    expect(buildingHaptic(49, 51), HapticKind.light);
    expect(buildingHaptic(99, 100), HapticKind.success);
    expect(buildingHaptic(100, 100), isNull);
    expect(buildingHaptic(10, 9), isNull);
  });

  test('a full fill feels 16 ticks, 3 step taps and 1 success', () {
    final felt = <HapticKind>[];
    for (var p = 1; p <= 100; p++) {
      final k = buildingHaptic(p - 1, p);
      if (k != null) felt.add(k);
    }
    expect(felt.where((k) => k == HapticKind.tick), hasLength(16));
    expect(felt.where((k) => k == HapticKind.light), hasLength(3));
    expect(felt.where((k) => k == HapticKind.success), hasLength(1));
  });

  test('vibration setting defaults to on, also for older saved settings', () {
    expect(Settings().haptics, isTrue);
    expect(Settings.fromJson(const {}).haptics, isTrue);
    expect(Settings.fromJson(const {'haptics': false}).haptics, isFalse);
    expect(Settings(haptics: false).toJson()['haptics'], isFalse);
  });

  testWidgets('plays native feedback in order, and nothing while switched off', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
      return null;
    });
    addTearDown(() {
      Haptics.enabled = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Haptics.success();
    expect(calls, ['HapticFeedbackType.mediumImpact']);
    await tester.pump(const Duration(milliseconds: 120));
    expect(calls, ['HapticFeedbackType.mediumImpact', 'HapticFeedbackType.lightImpact']);

    calls.clear();
    Haptics.enabled = false;
    Haptics.tap();
    Haptics.celebrate();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, isEmpty);
  });
}
