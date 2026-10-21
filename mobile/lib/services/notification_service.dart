import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/logic.dart';

/// Daily study reminder at the learner's window — the web prototype mirrors the flow in
/// src/lib/reminders.ts. One repeating notification; rescheduled whenever settings change.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;
  static const _dailyId = 1001;

  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (e) {
      debugPrint('timezone init failed: $e');
    }
    try {
      const android = AndroidInitializationSettings('@drawable/ic_stat_mimi');
      await _plugin.initialize(settings: const InitializationSettings(android: android));
      _ready = true;
    } catch (e) {
      debugPrint('notifications unavailable: $e');
    }
  }

  static bool _ready = false;

  /// Ask for notification permission (Android 13+). Never throws — reminders are optional.
  static Future<bool> requestPermission() async {
    await init();
    if (!_ready) return false;
    try {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await a?.requestNotificationsPermission() ?? false;
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
    const details = NotificationDetails(
      android: AndroidNotificationDetails('daily', 'Daily reminder', channelDescription: 'A friendly nudge to keep your streak', importance: Importance.defaultImportance),
    );
    try {
      await _plugin.zonedSchedule(
        id: _dailyId,
        title: minimal ? 'Keep your streak alive 🔥' : 'Time for Japanese! 🦊',
        body: minimal ? 'One short clip saves your streak today.' : '$minutes minutes of real Japanese — Kizuki picked new clips for you.',
        scheduledDate: at,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('reminder schedule failed: $e');
    }
  }
}
