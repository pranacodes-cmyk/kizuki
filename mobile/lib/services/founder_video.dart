import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/logic.dart';
import 'onboarding_settings.dart';

/// Server-replaceable founder video. The bundled clip is always the instant default; when
/// onboarding_settings carries a video URL it is downloaded a few screens early and then
/// played from the device like a bundled file (offline too). Clearing the URL server-side
/// returns everyone to the bundled clip. Mirrors prefetchFounderVideo/cachedFounderVideoUrl
/// in src/lib/onboarding-settings.ts (web streams instead of caching a file).
class FounderVideo {
  static Future<void>? _job;

  /// A downloaded copy of the server-sent video, when it still matches the cached setting.
  static Future<File?> readyFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = founderVideoUrl(prefs.getString('founder-video-url'));
      final path = prefs.getString('founder-video-file');
      if (url == null || path == null || prefs.getString('founder-video-src') != url) return null;
      final f = File(path);
      return f.existsSync() ? f : null;
    } catch (_) {
      return null;
    }
  }

  /// Background download; safe to call on every early onboarding screen (runs once at a time).
  static void prefetch() { _job ??= _run().whenComplete(() => _job = null); }

  static Future<void> _run() async {
    try {
      await OnboardingSettings.refresh();
      final url = OnboardingSettings.videoUrl;
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getString('founder-video-file');
      if (url == null) {
        // Override removed on the server: fall back to the bundled clip everywhere.
        if (old != null) {
          try { await File(old).delete(); } catch (_) {}
          await prefs.remove('founder-video-file');
          await prefs.remove('founder-video-src');
        }
        return;
      }
      if (old != null && prefs.getString('founder-video-src') == url && File(old).existsSync()) return;
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return;
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/founder_${_stableHash(url)}.mp4');
      await f.writeAsBytes(res.bodyBytes, flush: true);
      if (old != null && old != f.path) {
        try { await File(old).delete(); } catch (_) {}
      }
      await prefs.setString('founder-video-file', f.path);
      await prefs.setString('founder-video-src', url);
    } catch (_) { /* Offline or a bad URL: the bundled clip stays. */ }
  }

  /// Stable across launches (String.hashCode is not), so the cached file is found again.
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) { h = ((h ^ c) * 0x01000193) & 0xffffffff; }
    return h;
  }
}
