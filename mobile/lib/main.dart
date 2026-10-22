import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/content.dart';
import 'logic/logic.dart';
import 'router.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';
import 'widgets/common.dart' show ScreenError;
import 'widgets/toast.dart';
import 'widgets/tour.dart';

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
  };
  PlatformDispatcher.instance.onError = (error, stack) {
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
  final app = AppState();
  try {
    await app.load().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('KIZUKI_ERROR state load: $e');
  }
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: app),
      ChangeNotifierProvider.value(value: SyncService.I),
    ],
    child: KizukiApp(app: app),
  ));
  unawaited(Content.load().then<void>((_) {}, onError: (Object e) => debugPrint('KIZUKI_ERROR content: $e')));
  unawaited(NotificationService.init().catchError((Object e) => debugPrint('KIZUKI_ERROR reminders: $e')));
  unawaited(SyncService.I.boot(app));
}

class KizukiApp extends StatefulWidget {
  final AppState app;
  const KizukiApp({super.key, required this.app});
  @override
  State<KizukiApp> createState() => _KizukiAppState();
}

class _KizukiAppState extends State<KizukiApp> {
  late final router = buildRouter(widget.app);

  /// Current route path for the welcome tour (it lives above the Navigator).
  final _path = ValueNotifier<String>('/');

  void _syncPath() {
    try {
      _path.value = router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    router.routerDelegate.addListener(_syncPath);
    _syncPath();
    widget.app.addListener(_celebrate);
    widget.app.addListener(_reminders);
    _reminders();
  }

  @override
  void dispose() {
    router.routerDelegate.removeListener(_syncPath);
    _path.dispose();
    widget.app.removeListener(_celebrate);
    widget.app.removeListener(_reminders);
    super.dispose();
  }

  String? _reminderKey;

  /// Keep the daily reminder in step with settings (window, goal, on/off, frequency).
  void _reminders() {
    final a = widget.app;
    final on = a.onboarded && a.settings.reminders;
    final key = '$on|${a.profile.window}|${a.profile.dailyMinutes}|${a.settings.reminderFreq}';
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
      title: 'Kizuki',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
      builder: (context, child) => Stack(children: [
        child ?? const SizedBox(),
        // Above every route and sheet, so it can follow the learner and spotlight cards.
        Positioned.fill(child: TourHost(path: _path)),
        const Positioned.fill(child: ToastLayer()),
      ]),
    );
  }
}
