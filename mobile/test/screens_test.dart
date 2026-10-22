import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mimi/logic/logic.dart';
import 'package:mimi/screens/lists.dart';
import 'package:mimi/screens/legal.dart';
import 'package:mimi/screens/onboarding.dart';
import 'package:mimi/screens/trial.dart';
import 'package:mimi/screens/welcome.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/theme/tokens.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests: the screens that don't need the video player render on a phone-sized
/// screen without layout errors, and onboarding answers land in the learner profile.
Future<AppState> _pump(WidgetTester tester, String initial) async {
  SharedPreferences.setMockInitialValues({});
  final app = AppState();
  await app.load();
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/building', builder: (_, _) => const Scaffold(body: Text('building'))),
    GoRoute(path: '/trial', builder: (_, _) => const TrialScreen()),
    GoRoute(path: '/account', builder: (_, _) => const Scaffold(body: Text('account'))),
    GoRoute(path: '/achievements', builder: (_, _) => const AchievementsScreen()),
    GoRoute(path: '/terms', builder: (_, _) => const LegalScreen(kind: 'terms')),
  ]);
  await tester.pumpWidget(ChangeNotifierProvider.value(value: app, child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
  await tester.pump(const Duration(milliseconds: 800));
  return app;
}

void main() {
  testWidgets('welcome renders its call to action', (tester) async {
    await _pump(tester, '/');
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  testWidgets('onboarding saves reasons and level into the profile', (tester) async {
    final app = await _pump(tester, '/onboarding');
    expect(find.text('Why do you want to learn Japanese?'), findsOneWidget);
    await tester.tap(find.text('Anime & manga'));
    await tester.tap(find.text('Travel'));
    await tester.pump();
    expect(app.profile.reasons, ['anime', 'travel']);
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('How much Japanese do you know?'), findsOneWidget);
    await tester.tap(find.text('I can have simple chats'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(app.profile.level, 2);
    expect(app.profile.jlpt, 'N4');
    expect(find.text("What's hardest for you right now?"), findsOneWidget);
  });

  testWidgets('onboarding walks all ten steps and records every answer', (tester) async {
    final app = await _pump(tester, '/onboarding');
    Future<void> tap(String t, {int ms = 450}) async {
      await tester.tap(find.text(t).last);
      await tester.pump(Duration(milliseconds: ms));
      await tester.pump(const Duration(milliseconds: 400)); // let the step transition finish
    }

    await tap('Work', ms: 50);
    await tap('Continue');
    await tap("I'm new to Japanese", ms: 700);
    expect(app.profile.jlpt, 'N5');
    await tap('Understanding natives', ms: 50);
    expect(find.text(challengeBenefit('listening')), findsOneWidget);
    await tap('Continue');
    expect(find.text('Learn the way you learned your first language'), findsOneWidget);
    await tap('Continue', ms: 1200);
    await tap('YouTube', ms: 700);
    expect(app.profile.source, 'youtube');
    expect(find.text('When do you want to understand Japanese?'), findsOneWidget);
    await tap('Continue');
    expect(find.text('How much time can you give each day?'), findsOneWidget);
    await tap("I'm committed");
    await tap('Evening', ms: 100);
    await tap('Remind me in the evening', ms: 600);
    expect(app.profile.window, 'evening');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300))); // permission request is a real async platform call
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Make a promise to yourself'), findsOneWidget);
    await tap('30-day streak', ms: 100);
    expect(app.profile.streakGoal, 30);
    await tap('Commit to 30 days');
    await tester.enterText(find.byType(TextField), 'Mohit');
    await tester.pump();
    expect(app.profile.name, 'Mohit');
    await tap('Build my plan', ms: 600);
    expect(find.text('building'), findsOneWidget);
    expect(app.profile.reasons, ['work']);
    expect(app.profile.challenges, ['listening']);
  });

  testWidgets('name step: with the keyboard open on a small phone, the buttons stay fully on screen', (tester) async {
    final app = await _pump(tester, '/onboarding');
    Future<void> tap(String t, {int ms = 450}) async {
      await tester.tap(find.text(t).last);
      await tester.pump(Duration(milliseconds: ms));
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tap('Work', ms: 50);
    await tap('Continue');
    await tap("I'm new to Japanese", ms: 700);
    await tap('Understanding natives', ms: 50);
    await tap('Continue');
    await tap('Continue', ms: 1200);
    await tap('YouTube', ms: 700);
    await tap('Continue');
    await tap("I'm committed");
    await tap('Evening', ms: 100);
    await tap('Remind me in the evening', ms: 600);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 700));
    await tap('30-day streak', ms: 100);
    await tap('Commit to 30 days');
    expect(find.text('Last thing — what should Kizuki call you?'), findsOneWidget);

    // Small phone (360×640) with a 300 px keyboard.
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Mohit');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    const visibleBottom = 640.0 - 300.0;
    for (final label in ['Build my plan', 'Skip']) {
      final r = tester.getRect(find.text(label));
      expect(r.top, greaterThanOrEqualTo(0), reason: '$label top');
      expect(r.bottom, lessThanOrEqualTo(visibleBottom), reason: '$label is hidden behind the keyboard');
    }
    expect(tester.getRect(find.byType(TextField)).bottom, lessThanOrEqualTo(visibleBottom));
    await tap('Build my plan', ms: 600);
    expect(app.profile.name, 'Mohit');
    expect(find.text('building'), findsOneWidget);
  });

  testWidgets('trial pitch walks through its three steps', (tester) async {
    final app = await _pump(tester, '/trial');
    expect(find.text(r'Try for $0.00'), findsOneWidget);
    await tester.tap(find.text(r'Try for $0.00'));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text("We'll remind you before your trial ends"), findsOneWidget);
    await tester.tap(find.text('Continue for free'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Start my free week'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    await tester.tap(find.text('Start my free week'));
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('account'), findsOneWidget);
    expect(app.premium.active, isTrue);
    expect(tester.takeException(), isNull);
    // Let the trial-start toast and debounced local save finish before teardown.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('achievements and legal pages render', (tester) async {
    await _pump(tester, '/achievements');
    expect(find.text('First Listen'), findsOneWidget);
    await _pump(tester, '/terms');
    expect(find.text('Terms of Service'), findsOneWidget);
  });
}
