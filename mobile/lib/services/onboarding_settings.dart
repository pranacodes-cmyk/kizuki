import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/logic.dart';
import 'config.dart';

/// Public presentation switches (founder screen, native sign-in); no user data or client
/// write permission. Each value keeps its last valid copy offline.
class OnboardingSettings {
  static bool enabled = true;
  static bool nativeGoogle = false;
  static bool nativeApple = false;
  static Future<void>? _loading;
  static Future<void> refresh() => _loading ??= _refresh().whenComplete(() => _loading = null);
  static Future<void> _refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool('founder-video-enabled') ?? enabled;
      nativeGoogle = prefs.getBool('native-google-sign-in') ?? nativeGoogle;
      nativeApple = prefs.getBool('native-apple-sign-in') ?? nativeApple;
      final response = await http.get(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/onboarding_settings?id=eq.1&select=founder_video_enabled,native_google_sign_in,native_apple_sign_in'),
        headers: {'apikey': AppConfig.supabasePublishableKey},
      ).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return;
      final rows = jsonDecode(response.body);
      if (rows is! List || rows.isEmpty || rows.first is! Map) return;
      final row = rows.first as Map;
      enabled = founderVideoEnabled(row['founder_video_enabled'], enabled);
      nativeGoogle = nativeSignInEnabled(row['native_google_sign_in'], nativeGoogle);
      nativeApple = nativeSignInEnabled(row['native_apple_sign_in'], nativeApple);
      await prefs.setBool('founder-video-enabled', enabled);
      await prefs.setBool('native-google-sign-in', nativeGoogle);
      await prefs.setBool('native-apple-sign-in', nativeApple);
    } catch (_) { /* Offline: retain the last valid setting. */ }
  }
}
