import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/account.dart';
import 'screens/building.dart';
import 'screens/clip_screen.dart';
import 'screens/explore.dart';
import 'screens/feed.dart';
import 'screens/founder.dart';
import 'screens/language.dart';
import 'screens/legal.dart';
import 'screens/support.dart';
import 'screens/lists.dart';
import 'screens/onboarding.dart';
import 'screens/plan.dart';
import 'screens/profile.dart';
import 'screens/review.dart';
import 'screens/settings.dart';
import 'screens/home_widgets.dart';
import 'screens/trial.dart';
import 'screens/vocab.dart';
import 'screens/welcome.dart';
import 'state/app_state.dart';
import 'logic/logic.dart';
import 'widgets/tab_bar.dart';
import 'widgets/onboarding_back.dart';
import 'widgets/ui.dart' show confirmAppExit;
import 'i18n/i18n.dart';

/// Same paths as the web prototype (src/routes).
GoRouter buildRouter(AppState app) {
  const tabs = ['/feed', '/explore', '/vocab', '/profile'];
  CustomTransitionPage<void> fade(GoRouterState s, Widget child) => CustomTransitionPage(
        key: s.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: c),
      );
  return GoRouter(
    initialLocation: app.onboarded ? '/feed' : '/',
    refreshListenable: app,
    redirect: (context, state) {
      final p = state.uri.path;
      if (purchaseNeedsAccount(app.purchaseAccountPending, false) && !['/account', '/terms', '/privacy', '/support'].contains(p)) return '/account?mode=signin';
      if (p == '/trial' && app.onboarded && subscriptionAccess(app.premium.active, app.premium.expiresAt, app.premium.trialEndsAt, DateTime.now().millisecondsSinceEpoch)) return '/feed';
      if ((app.onboarded || !onboardingPath(p)) && learningPath(p) && !subscriptionAccess(app.premium.active, app.premium.expiresAt, app.premium.trialEndsAt, DateTime.now().millisecondsSinceEpoch)) return '/trial';
      if (!app.onboarded && tabs.contains(p)) return '/';
      // First run: pick the app language before the welcome screen.
      if (!app.onboarded && !I18n.chosen && p == '/') return '/language';
      if (app.onboarded && p == '/') return '/feed';
      return null;
    },
    routes: [
      GoRoute(path: '/', pageBuilder: (c, s) => fade(s, const WelcomeScreen())),
      GoRoute(path: '/onboarding', pageBuilder: (c, s) => fade(s, const OnboardingScreen())),
      GoRoute(path: '/building', pageBuilder: (c, s) => fade(s, OnboardingBack(onBack: () => c.canPop() ? c.pop() : c.go('/onboarding'), child: const BuildingScreen()))),
      GoRoute(path: '/plan', pageBuilder: (c, s) => fade(s, OnboardingBack(onBack: () => c.canPop() ? c.pop() : c.go('/onboarding'), child: const PlanScreen()))),
      GoRoute(path: '/founder', pageBuilder: (c, s) => fade(s, OnboardingBack(onBack: () => c.canPop() ? c.pop() : c.go('/plan'), child: const FounderScreen()))),
      GoRoute(path: '/trial', builder: (c, s) => const TrialScreen()),
      GoRoute(path: '/account', builder: (c, s) => OnboardingBack(
        onBack: () {
          if (app.purchaseAccountPending) {
            confirmAppExit(c);
          } else if (c.canPop()) {
            c.pop();
          } else {
            c.go(app.onboarded ? '/profile' : '/');
          }
        },
        child: AccountScreen(signInMode: s.uri.queryParameters['mode'] == 'signin'),
      )),
      ShellRoute(
        builder: (c, s, child) => TabShell(child: child),
        routes: [
          GoRoute(path: '/feed', pageBuilder: (c, s) => fade(s, const FeedScreen())),
          GoRoute(path: '/explore', pageBuilder: (c, s) => fade(s, const ExploreScreen())),
          GoRoute(path: '/vocab', pageBuilder: (c, s) => fade(s, const VocabScreen())),
          GoRoute(path: '/profile', pageBuilder: (c, s) => fade(s, const ProfileScreen())),
        ],
      ),
      GoRoute(path: '/clip/:clipId', builder: (c, s) => ClipScreen(clipId: s.pathParameters['clipId']!)),
      GoRoute(
        path: '/review',
        builder: (c, s) => ReviewScreen(
          key: ValueKey('${s.uri.queryParameters['deck']}-${s.uri.queryParameters['mode']}'),
          deck: switch (s.uri.queryParameters['deck']) { 'hiragana' => 'hiragana', 'katakana' => 'katakana', _ => 'words' },
          extra: s.uri.queryParameters['mode'] == 'extra',
        ),
      ),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/language', builder: (c, s) => LanguageScreen(fromSettings: s.uri.queryParameters['from'] == 'settings')),
      GoRoute(path: '/widgets', builder: (c, s) => const HomeWidgetsScreen()),
      GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
      GoRoute(path: '/saved', builder: (c, s) => const SavedScreen()),
      GoRoute(path: '/achievements', builder: (c, s) => const AchievementsScreen()),
      GoRoute(path: '/terms', builder: (c, s) => const LegalScreen(kind: 'terms')),
      GoRoute(path: '/privacy', builder: (c, s) => const LegalScreen(kind: 'privacy')),
      GoRoute(path: '/support', builder: (c, s) => const SupportScreen()),
    ],
  );
}
