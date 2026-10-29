import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/logic.dart';
import '../i18n/i18n.dart';

/// Daily study reminder at the learner's window — the web prototype mirrors the flow in
/// src/lib/reminders.ts. One repeating notification; rescheduled whenever settings change.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _dailyId = 1001;
  static const _trialId = 1002;
  static const _darwin = DarwinNotificationDetails(presentAlert: true, presentSound: true);

  /// One shared start-up: every caller (launch, reminder scheduling, trial reminder)
  /// awaits the same future, so a schedule() racing the first init() waits instead of
  /// silently skipping. A failed start clears it so the next call can retry.
  static Future<void>? _initializing;
  static Future<void> init() => _initializing ??= _initialize();

  static Future<void> _initialize() async {
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (e) {
      debugPrint('timezone init failed: $e');
    }
    try {
      const android = AndroidInitializationSettings('@drawable/ic_stat_mimi');
      // iOS asks for permission only when the learner turns reminders on (requestPermission).
      const ios = DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false);
      await _plugin.initialize(settings: const InitializationSettings(android: android, iOS: ios));
      _ready = true;
    } catch (e) {
      debugPrint('notifications unavailable: $e');
      _initializing = null;
    }
  }

  static bool _ready = false;

  /// Widget tests run each case in its own fake clock, so a start-up begun in one test never
  /// finishes; tests reset it instead of inheriting a stuck future.
  @visibleForTesting
  static void resetForTest() {
    _initializing = null;
    _ready = false;
  }

  /// Ask for notification permission (Android 13+). Never throws — reminders are optional.
  static Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (a != null) return await a.requestNotificationsPermission() ?? false;
      final i = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await i?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('notification permission failed: $e');
      return false;
    }
  }

  /// Schedule (or cancel) the daily reminder. [minimal] = only a gentle streak-saver.
  static Future<void> schedule({required bool enabled, required String window, required int minutes, required bool minimal}) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _dailyId);
    } catch (_) {}
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, windowHour(window));
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    final details = NotificationDetails(
      android: AndroidNotificationDetails('daily', tr('Daily reminder'), channelDescription: 'A friendly nudge to keep your streak', importance: Importance.defaultImportance),
      iOS: _darwin,
    );
    try {
      await _plugin.zonedSchedule(
        id: _dailyId,
        title: minimal ? tr('Keep your streak alive 🔥') : tr('Time for Japanese! 🦊'),
        body: minimal ? tr('One short clip saves your streak today.') : tr('{minutes} minutes of real Japanese — Kizuki picked new clips for you.', {'minutes': minutes}),
        scheduledDate: at,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('reminder schedule failed: $e');
    }
  }

  /// The promised "your trial ends soon" reminder: 2 days before the store's trial end.
  /// [trialEndsAt] null cancels it (trial converted, cancelled or not a trial).
  static Future<void> scheduleTrialReminder(int? trialEndsAt) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _trialId);
    } catch (_) {}
    if (trialEndsAt == null) return;
    final at = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, trialEndsAt).subtract(const Duration(days: 2));
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
    try {
      await _plugin.zonedSchedule(
        id: _trialId,
        title: tr('Your free week ends in 2 days'),
        body: tr('Keep Kizuki Premium, or cancel anytime in your store settings. No surprises.'),
        scheduledDate: at,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails('trial', tr('Trial reminder'), channelDescription: 'Tells you before your free trial ends', importance: Importance.high),
          iOS: _darwin,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('trial reminder failed: $e');
    }
  }
}
