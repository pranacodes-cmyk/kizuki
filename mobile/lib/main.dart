import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/content.dart';
import 'logic/logic.dart';
import 'router.dart';
import 'services/attribution.dart';
import 'services/analytics.dart';
import 'services/auth_links.dart';
import 'services/billing.dart';
import 'services/content_pack.dart';
import 'services/locale_pack.dart';
import 'services/haptics.dart';
import 'services/home_widgets.dart';
import 'services/notification_service.dart';
import 'services/onboarding_settings.dart';
import 'services/trial_preload.dart';
import 'services/sync_service.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';
import 'widgets/common.dart' show ScreenError;
import 'widgets/lively_mascot.dart' show SplashGate;
import 'widgets/splash.dart';
import 'widgets/toast.dart';
import 'widgets/tracking_explainer.dart';
import 'widgets/tour.dart';
import 'i18n/i18n.dart';
import 'services/error_report.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();
  await startApp();
}

/// Errors never leave a blank screen: a broken widget shows a readable card instead of
/// release mode's plain grey box, and uncaught async errors are logged, not fatal.
void installErrorHandlers() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint('KIZUKI_ERROR ${details.exceptionAsString()}\n${details.stack}');
    previous?.call(details);
    Analytics.track('app_error', {'category': 'flutter_widget'});
    ErrorReport.send('flutter_widget', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Analytics.track('app_error', {'category': 'uncaught_async'});
    ErrorReport.send('uncaught_async', error, stack);
    debugPrint('KIZUKI_ERROR $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (details) => ScreenError(message: kReleaseMode ? null : details.exceptionAsString());
}

/// Shows the first frame as soon as local state is read; the clip library, reminders and
/// the backend connection all start in the background.
Future<void> startApp() async {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: T.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
  // The app language is a device choice; read it before the first frame.
  await I18n.load().timeout(const Duration(seconds: 2), onTimeout: () {});
  final app = AppState();
  try {
    await app.load().timeout(const Duration(seconds: 5));
  } catch (e) {
    // A late load merges in when it finishes; it never replaces live state or Premium.
    app.loadIsLate = true;
    debugPrint('KIZUKI_ERROR state load: $e');
  }
  Haptics.enabled = app.settings.haptics;
  HomeWidgets.start(app);
  // Analytics never holds up the first frame; setup continues in the background.
  try {
    await Analytics.load().timeout(const Duration(seconds: 2));
  } catch (e) {
    debugPrint('KIZUKI_WARN analytics load: $e');
  }
  // Saved flags are not proof of a subscription. Launch locked until the store verifies it.
  if (!Billing.simulate && kReleaseMode) app.applyPremium(Premium());
  // A browser sign-in that opens the app must be caught from the very first moment.
  AuthLinks.I.onUnclaimed = SyncService.I.installHandoff;
  AuthLinks.I.start();
  // The animated splash covers the first screen; entrances wait until it fades.
  SplashGate.visible.value = true;
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: app),
      ChangeNotifierProvider.value(value: SyncService.I),
    ],
    child: KizukiApp(app: app),
  ));
  // A newer server clip pack (if any) downloads in the background and is used from the next start.
  unawaited(Content.load().then<void>((_) => ContentPack.scheduleSync(Content.bundledVersion, Content.pack), onError: (Object e) => debugPrint('KIZUKI_ERROR content: $e')));
  unawaited(OnboardingSettings.refresh());
  unawaited(NotificationService.init().catchError((Object e) => debugPrint('KIZUKI_ERROR reminders: $e')));
  unawaited(SyncService.I.boot(app));
  // Live store prices + subscription status (App Store / Google Play via RevenueCat).
  // The store is the only source of Premium; the trial-ending reminder follows it.
  Billing.onPremium = (p) {
    app.applyPremium(p);
    unawaited(NotificationService.scheduleTrialReminder(p.trialEndsAt));
  };
  // A purchase the store approved later gets the same mandatory account step.
  Billing.onApprovedLater = app.requirePurchaseAccount;
  unawaited(Billing.init().then((_) => Attribution.linkRevenueCat()));
}

class KizukiApp extends StatefulWidget {
  final AppState app;
  const KizukiApp({super.key, required this.app});
  @override
  State<KizukiApp> createState() => _KizukiAppState();
}

/// Path of the screen on top, including pushed ones (/review, /settings).
/// routerDelegate.currentConfiguration.uri stays on the screen underneath a push, so the
/// welcome tour never saw the review open.
String? topPath(GoRouter router) {
  try {
    return router.state.uri.path;
  } catch (_) {
    try {
      return router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return null;
    }
  }
}

class _KizukiAppState extends State<KizukiApp> {
  late final router = buildRouter(widget.app);

  /// Current route path for the welcome tour (it lives above the Navigator).
  final _path = ValueNotifier<String>('/');

  void _syncPath() {
    final p = topPath(router);
    if (p != null) { _path.value = p; ErrorReport.route = p; Analytics.screen(p); }
    final a = widget.app;
    if (a.onboarded && !subscriptionAccess(a.premium.active, a.premium.expiresAt, a.premium.trialEndsAt, DateTime.now().millisecondsSinceEpoch)) {
      Tour.I.reset();
      router.routerDelegate.navigatorKey.currentState?.popUntil((r) => r is! PopupRoute);
    }
  }

  @override
  void initState() {
    super.initState();
    router.routerDelegate.addListener(_syncPath);
    _syncPath();
    widget.app.addListener(_celebrate);
    widget.app.addListener(_reminders);
    widget.app.addListener(_haptics);
    widget.app.addListener(_localePack);
    I18n.lang.addListener(_onLanguage);
    _reminders();
    _haptics();
    _localePack();
    HomeWidgets.onOpen = (p) => router.go(p);
    final widgetLink = HomeWidgets.pending;
    HomeWidgets.pending = null;
    if (widgetLink != null) WidgetsBinding.instance.addPostFrameCallback((_) => router.go(widgetLink));
    // Meta install/open + Apple's tracking question, once the first screen is showing.
    Attribution.explainTracking = () async {
      final ctx = router.routerDelegate.navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) await showTrackingExplainer(ctx);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(Attribution.start()));
    WidgetsBinding.instance.addPostFrameCallback((_) => TrialPreload.start(context));
  }

  @override
  void dispose() {
    router.routerDelegate.removeListener(_syncPath);
    _path.dispose();
    widget.app.removeListener(_celebrate);
    widget.app.removeListener(_reminders);
    widget.app.removeListener(_haptics);
    widget.app.removeListener(_localePack);
    I18n.lang.removeListener(_onLanguage);
    HomeWidgets.dispose();
    super.dispose();
  }

  /// A new app language redraws every screen (tr() reads the language while building),
  /// switches the clip library to that language (then redraws again) and reschedules
  /// reminders so their text follows.
  void _onLanguage() {
    _rebuildAll();
    final code = I18n.lang.value;
    unawaited(Content.useLanguage(code).then((_) {
      if (I18n.lang.value == code) _rebuildAll();
      HomeWidgets.refresh();
    }));
    _reminderKey = null;
    _reminders();
    _localePack();
  }

  void _rebuildAll() {
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }
    if (mounted) {
      setState(() {});
      (context as Element).visitChildren(rebuild);
    }
  }

  /// The full language pack downloads only once learning access exists (trial or Premium).
  void _localePack() {
    final a = widget.app;
    LocalePacks.schedule(I18n.lang.value, subscriptionAccess(a.premium.active, a.premium.expiresAt, a.premium.trialEndsAt, DateTime.now().millisecondsSinceEpoch),
        inUse: Content.localeFilesInUse);
  }

  /// Settings → Vibration feedback switches every haptic in the app.
  void _haptics() => Haptics.enabled = widget.app.settings.haptics;

  String? _reminderKey;

  /// Keep the daily reminder in step with settings (window, goal, on/off, frequency).
  void _reminders() {
    final a = widget.app;
    final on = a.onboarded && a.settings.reminders;
    final key = '$on|${a.profile.window}|${a.profile.dailyMinutes}|${a.settings.reminderFreq}|${I18n.lang.value}';
    if (key == _reminderKey) return;
    _reminderKey = key;
    unawaited(NotificationService.schedule(enabled: on, window: a.profile.window, minutes: a.profile.dailyMinutes, minimal: a.settings.reminderFreq == 'minimal')
        .catchError((Object e) => debugPrint('KIZUKI_ERROR reminder schedule: $e')));
  }

  /// Achievement toasts — mirrors AppEffects.tsx.
  void _celebrate() {
    final a = widget.app;
    if (!a.onboarded) return;
    final fresh = newlyUnlocked(a.stats, a.achievementsSeen);
    if (fresh.isEmpty) return;
    scheduleMicrotask(() => a.markAchievementsSeen(fresh.map((x) => x.id).toList()));
    for (final x in fresh) {
      toast(x.title, description: x.desc, icon: x.icon, tone: ToastTone.achievement);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: tr('Kizuki'),
      debugShowCheckedModeBanner: false,
      // System text (copy/paste menus, screen-reader hints) follows the app language.
      locale: Locale(I18n.lang.value),
      supportedLocales: [for (final l in languages) Locale(l.code)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(),
      routerConfig: router,
      builder: (context, child) => Stack(children: [
        child ?? const SizedBox(),
        // Above every route and sheet, so it can follow the learner and spotlight cards.
        Positioned.fill(
          child: TourHost(
            path: _path,
            go: (p) => router.go(p),
            // Word card + Ask Kizuki are sheets on the root navigator (showMimiSheet).
            closeSheets: () => router.routerDelegate.navigatorKey.currentState?.popUntil((r) => r is! PopupRoute),
          ),
        ),
        const Positioned.fill(child: ToastLayer()),
        // Cold-start splash above everything; it removes itself after ~1.6 s.
        const Positioned.fill(child: SplashOverlay()),
      ]),
    );
  }
}
