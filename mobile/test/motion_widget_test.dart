import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mimi/screens/building.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/theme/mascot_motion.dart';
import 'package:mimi/theme/tokens.dart';
import 'package:mimi/widgets/lively_mascot.dart';
import 'package:mimi/widgets/splash.dart';
import 'package:mimi/widgets/ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The premium-motion moments: splash hand-off, fox entrances waiting for it, and the
/// plan-building ring's haptics (the user asked for a gentle vibration while it fills).
List<String> _captureHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

double _opacityOf(WidgetTester tester, Finder f) =>
    tester.widgetList<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity))).fold(1.0, (a, o) => a * o.opacity);

void main() {
  testWidgets('splash plays over the app, lets entrances start as it fades, then removes itself', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => Stack(children: [child!, const Positioned.fill(child: SplashOverlay())]),
      home: Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LivelyMascot(MascotPose.listen, key: ValueKey('fox'), size: 120, entrance: true),
            TextButton(onPressed: () => tapped++, child: const Text('Get started')),
          ]),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 16));
    expect(SplashGate.visible.value, isTrue);
    expect(find.text('z'), findsOneWidget); // the wordmark, letter by letter
    // While the splash covers the screen the fox waits, invisible, and taps don't go through.
    expect(_opacityOf(tester, find.descendant(of: find.byKey(const ValueKey('fox')), matching: find.byType(Image))), 0);
    await tester.tap(find.text('Get started'), warnIfMissed: false);
    expect(tapped, 0);

    await tester.pump(const Duration(milliseconds: splashMs));
    expect(SplashGate.visible.value, isFalse);
    await tester.pump(const Duration(milliseconds: splashFadeMs + 50));
    expect(find.text('z'), findsNothing);
    await tester.pump(const Duration(milliseconds: enterMs));
    expect(_opacityOf(tester, find.descendant(of: find.byKey(const ValueKey('fox')), matching: find.byType(Image))), closeTo(1, 1e-6));
    await tester.tap(find.text('Get started'));
    expect(tapped, 1);
  });

  testWidgets('reduced motion: a short still splash and a still fox', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: Stack(children: [child!, const Positioned.fill(child: SplashOverlay())]),
      ),
      home: const Scaffold(body: Center(child: LivelyMascot(MascotPose.listen, key: ValueKey('fox'), size: 120, entrance: true, idle: MascotIdle.groove))),
    ));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('z'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: splashReducedMs + splashFadeMs + 50));
    expect(find.text('z'), findsNothing);
    expect(_opacityOf(tester, find.descendant(of: find.byKey(const ValueKey('fox')), matching: find.byType(Image))), 1);
    final t = tester.widget<Transform>(find.descendant(of: find.byKey(const ValueKey('fox')), matching: find.byType(Transform)).first);
    expect(t.transform.getTranslation().y, 0);
  });

  testWidgets('plan ring ticks softly as it fills, succeeds on 100%, then opens the plan', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState();
    await app.load();
    final calls = _captureHaptics(tester);
    final router = GoRouter(initialLocation: '/building', routes: [
      GoRoute(path: '/building', builder: (_, _) => const BuildingScreen()),
      GoRoute(path: '/plan', builder: (_, _) => const Scaffold(body: Text('plan'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: app, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    for (var ms = 0; ms < buildMs + 100; ms += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('All set — opening your plan'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150)); // the second pulse of "success"
    // 16 ratchet ticks + 3 step taps + success (medium, then light).
    expect(calls.where((c) => c == 'HapticFeedbackType.selectionClick'), hasLength(16));
    expect(calls.where((c) => c == 'HapticFeedbackType.lightImpact'), hasLength(4));
    expect(calls.where((c) => c == 'HapticFeedbackType.mediumImpact'), hasLength(1));
    expect(calls.last, 'HapticFeedbackType.lightImpact');
    await tester.pump(const Duration(milliseconds: buildDoneMs));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('plan'), findsOneWidget);
  });
}
