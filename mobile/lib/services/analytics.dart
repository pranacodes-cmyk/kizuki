import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Product analytics only. Never send account details, chat, notes, URLs or receipts.
class Analytics {
  static const token = 'phc_Ain5Fw59ZXuXJLR7dkqwc3Qswq3YXwsqRNfwczmCPkyu';
  static const host = 'https://us.i.posthog.com';
  static const noticeVersion = 'posthog-2026-10-24';
  static const notice = 'Allow usage analytics? PostHog receives screen visits, taps, learning and checkout activity, device information and a random ID linked to your account ID after sign-in. No passwords, messages, notes or payment details. Change your choice in Settings → Usage analytics.';
  static final choice = ValueNotifier<bool?>(null);
  static bool _ready = false;
  static String? _userId;
  static String _screen = '/';
  static DateTime _entered = DateTime.now();
  static AppLifecycleListener? _life;
  static Future<void> _work = Future<void>.value();

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    choice.value = prefs.getBool('kizuki-analytics-choice');
    if (choice.value == true) await _setup();
    _life ??= AppLifecycleListener(onResume: () => track('app_resumed'), onPause: () {
      track('app_backgrounded');
      if (_ready) _safe(() => Posthog().flush());
    });
  }

  static Future<void> _setup() async {
    if (_ready || choice.value != true || kIsWeb) return;
    try {
      final config = PostHogConfig(token)
        ..host = host
        ..sessionReplay = false
        ..captureApplicationLifecycleEvents = false
        ..preloadFeatureFlags = false
        ..surveys = false
        ..flushAt = 10
        ..flushInterval = const Duration(seconds: 10);
      await Posthog().setup(config);
      _ready = true;
      await Posthog().register('platform', defaultTargetPlatform.name);
      await Posthog().register('analytics_notice_version', noticeVersion);
      if (_userId != null) await Posthog().identify(userId: _userId ?? '');
    } catch (_) { _ready = false; }
  }

  static Future<void> setChoice(bool accepted) async {
    choice.value = accepted; // Immediately block all new events on withdrawal.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kizuki-analytics-choice', accepted);
    final at = DateTime.now().toUtc().toIso8601String();
    await prefs.setString('kizuki-analytics-choice-at', at);
    await prefs.setString('kizuki-analytics-notice', noticeVersion);
    if (accepted) {
      await prefs.setString('kizuki-analytics-accepted-at', at);
      await _setup();
      if (_ready) await Posthog().optIn();
      track('analytics_consent_granted');
      track('screen_viewed', {'screen': _screen});
    } else if (_ready) {
      await Posthog().optOut();
      await Posthog().reset();
      await Posthog().close();
      _ready = false;
    }
  }

  static void _safe(Future<void> Function() action) {
    _work = _work.then((_) async {
      if (choice.value != true || !_ready) return;
      try { await action(); } catch (_) { /* Analytics never interrupts learning. */ }
    });
  }

  static void track(String event, [Map<String, Object> properties = const {}]) {
    if (choice.value != true || !_ready) return;
    final payload = <String, Object>{
      'screen': _screen, 'is_test': !kReleaseMode, 'is_simulated': !kReleaseMode,
      ...properties,
    };
    _safe(() => Posthog().capture(eventName: event, properties: payload));
  }

  static void screen(String path) {
    if (path == _screen) return;
    track('screen_left', {'duration_seconds': DateTime.now().difference(_entered).inSeconds});
    _screen = path.startsWith('/clip/') ? '/clip/:clipId' : path;
    _entered = DateTime.now();
    track('screen_viewed');
    if (['/feed', '/explore', '/vocab', '/profile'].contains(path)) track('tab_selected', {'tab': path.substring(1)});
  }

  static void identity(String? id) {
    final previous = _userId;
    if (previous == id) return;
    _userId = id;
    _safe(() async {
      if (previous != null) await Posthog().reset();
      if (id != null) await Posthog().identify(userId: id);
      await Posthog().capture(eventName: id == null ? 'account_signed_out' : 'account_signed_in');
    });
  }
}