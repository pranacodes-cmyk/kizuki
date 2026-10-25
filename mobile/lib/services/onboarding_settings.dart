import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/logic.dart';
import 'config.dart';

/// Public presentation switches (founder screen, its optional server-sent video, native
/// sign-in); no user data or client write permission. Each value keeps its last valid copy
/// offline.
class OnboardingSettings {
  static bool enabled = true;
  static bool nativeGoogle = false;
  static bool nativeApple = false;

  /// Server-sent founder video override (null = play the bundled clip).
  static String? videoUrl;
  static Future<void>? _loading;
  static Future<void> refresh() => _loading ??= _refresh().whenComplete(() => _loading = null);
  static Future<void> _refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool('founder-video-enabled') ?? enabled;
      nativeGoogle = prefs.getBool('native-google-sign-in') ?? nativeGoogle;
      nativeApple = prefs.getBool('native-apple-sign-in') ?? nativeApple;
      videoUrl = founderVideoUrl(prefs.getString('founder-video-url'));
      final response = await http.get(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/onboarding_settings?id=eq.1&select=founder_video_enabled,founder_video_url,native_google_sign_in,native_apple_sign_in'),
        headers: {'apikey': AppConfig.supabasePublishableKey},
      ).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return;
      final rows = jsonDecode(response.body);
      if (rows is! List || rows.isEmpty || rows.first is! Map) return;
      final row = rows.first as Map;
      enabled = founderVideoEnabled(row['founder_video_enabled'], enabled);
      nativeGoogle = nativeSignInEnabled(row['native_google_sign_in'], nativeGoogle);
      nativeApple = nativeSignInEnabled(row['native_apple_sign_in'], nativeApple);
      // The server's value wins, including a cleared one (back to the bundled clip).
      videoUrl = founderVideoUrl(row['founder_video_url']);
      await prefs.setBool('founder-video-enabled', enabled);
      await prefs.setBool('native-google-sign-in', nativeGoogle);
      await prefs.setBool('native-apple-sign-in', nativeApple);
      if (videoUrl == null) {
        await prefs.remove('founder-video-url');
      } else {
        await prefs.setString('founder-video-url', videoUrl!);
      }
    } catch (_) { /* Offline: retain the last valid setting. */ }
  }
}
