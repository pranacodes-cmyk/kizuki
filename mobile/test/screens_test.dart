import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mimi/data/legal.dart';
import 'package:mimi/logic/logic.dart';
import 'package:mimi/screens/lists.dart';
import 'package:mimi/screens/legal.dart';
import 'package:mimi/screens/onboarding.dart';
import 'package:mimi/screens/trial.dart';
import 'package:mimi/screens/welcome.dart';
import 'package:mimi/services/notification_service.dart';
import 'package:mimi/state/app_state.dart';
import 'package:mimi/theme/tokens.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests: the screens that don't need the video player render on a phone-sized
/// screen without layout errors, and onboarding answers land in the learner profile.
Future<AppState> _pump(WidgetTester tester, String initial, {Size size = const Size(402, 874), double textScale = 1}) async {
  SharedPreferences.setMockInitialValues({});
  NotificationService.resetForTest();
  final app = AppState();
  await app.load();
  tester.view.physicalSize = size * 3;
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
    GoRoute(path: '/privacy', builder: (_, _) => const LegalScreen(kind: 'privacy')),
  ]);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: app,
    child: MaterialApp.router(
      theme: buildTheme(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
    ),
  ));
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

  testWidgets('onboarding walks all nine steps and records every answer', (tester) async {
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
    expect(find.text('building'), findsOneWidget);
    expect(app.profile.reasons, ['work']);
    expect(app.profile.challenges, ['listening']);
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
    expect(app.purchaseAccountPending, isTrue);
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

  // Small phones (360×640) with large system text: every onboarding step and paywall step keeps
  // its main button on screen (content scrolls above a pinned footer), with no layout overflow.
  const small = Size(360, 640);
  bool onScreen(WidgetTester tester, Finder f) {
    final r = tester.getRect(f.last);
    return r.top >= 0 && r.bottom <= small.height;
  }

  testWidgets('onboarding fits a small phone with large text', (tester) async {
    final app = await _pump(tester, '/onboarding', size: small, textScale: 1.3);
    Future<void> tap(String t, {int ms = 450}) async {
      await tester.ensureVisible(find.text(t).last);
      await tester.pump();
      await tester.tap(find.text(t).last);
      await tester.pump(Duration(milliseconds: ms));
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tap('Work', ms: 50);
    expect(onScreen(tester, find.text('Continue')), isTrue);
    await tap('Continue');
    await tap("I'm new to Japanese", ms: 700);
    await tap('Understanding natives', ms: 50);
    await tap('Continue');
    expect(find.text('Learn the way you learned your first language'), findsOneWidget);
    expect(onScreen(tester, find.text('Continue')), isTrue);
    await tap('Continue', ms: 1200);
    await tap('YouTube', ms: 700);
    expect(onScreen(tester, find.text('Continue')), isTrue);
    await tap('Continue');
    expect(onScreen(tester, find.text("I'm committed")), isTrue);
    await tap("I'm committed");
    await tap('Evening', ms: 100);
    expect(onScreen(tester, find.text('Remind me in the evening')), isTrue);
    await tap('Remind me in the evening', ms: 600);
    // The permission request is a real async platform call; give it real time to settle.
    for (var i = 0; i < 30 && find.text('Make a promise to yourself').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Make a promise to yourself'), findsOneWidget);
    await tap('50-day streak', ms: 100);
    expect(app.profile.streakGoal, 50);
    expect(onScreen(tester, find.text('Commit to 50 days')), isTrue);
    await tap('Commit to 50 days');
    expect(find.text('building'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paywall keeps its button, price and legal links on a small phone', (tester) async {
    await _pump(tester, '/trial', size: small, textScale: 1.3);
    expect(onScreen(tester, find.text(r'Try for $0.00')), isTrue);
    await tester.tap(find.text(r'Try for $0.00'));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(onScreen(tester, find.text('Continue for free')), isTrue);
    await tester.tap(find.text('Continue for free'));
    await tester.pump(const Duration(milliseconds: 400));
    for (final t in ['Start my free week', 'Restore purchase', 'Not now', 'Terms of Use', 'Privacy Policy']) {
      expect(onScreen(tester, find.text(t)), isTrue, reason: '$t must be visible without scrolling');
    }
    expect(find.textContaining('7 days free, then'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('privacy policy shows its date and every section', (tester) async {
    await _pump(tester, '/privacy');
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Last updated: ${privacyDoc.updated}'), findsOneWidget);
    for (final s in privacyDoc.sections) {
      await tester.scrollUntilVisible(find.text(s.h), 300, scrollable: find.byType(Scrollable).last);
      expect(find.text(s.h), findsOneWidget);
    }
  });
}
