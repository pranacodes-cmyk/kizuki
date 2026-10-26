import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/logic.dart';
import 'config.dart';

/// Public presentation switches (founder screen, its optional server-sent video, native
/// sign-in, trial experiment); no user data or client write permission. Each value keeps
/// its last valid copy offline.
class OnboardingSettings {
  static bool enabled = true;
  static bool nativeGoogle = false;
  static bool nativeApple = false;

  /// Server switch for the store-review email sign-in; off = the form is not rendered at all.
  static bool reviewSignIn = false;

  /// Server trial experiment, last valid value: 0 = direct paywall without trial wording.
  static int trialDayCount = defaultTrialDays;

  /// Optional server-picked store product for the yearly plan (experiments without a build).
  static String? yearlyProduct;

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
      reviewSignIn = prefs.getBool('review-sign-in') ?? reviewSignIn;
      videoUrl = founderVideoUrl(prefs.getString('founder-video-url'));
      final cachedDays = prefs.getInt('trial-days');
      if (cachedDays != null && cachedDays >= 0 && cachedDays <= 14) trialDayCount = cachedDays;
      yearlyProduct = _productId(prefs.getString('trial-yearly-product'));
      final response = await http.get(
        Uri.parse('${AppConfig.supabaseUrl}/rest/v1/onboarding_settings?id=eq.1&select=founder_video_enabled,founder_video_url,native_google_sign_in,native_apple_sign_in,review_sign_in,trial_enabled,trial_days,yearly_product'),
        headers: {'apikey': AppConfig.supabasePublishableKey},
      ).timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return;
      final rows = jsonDecode(response.body);
      if (rows is! List || rows.isEmpty || rows.first is! Map) return;
      final row = rows.first as Map;
      enabled = founderVideoEnabled(row['founder_video_enabled'], enabled);
      nativeGoogle = nativeSignInEnabled(row['native_google_sign_in'], nativeGoogle);
      nativeApple = nativeSignInEnabled(row['native_apple_sign_in'], nativeApple);
      // A missing column or value hides the review form (never shown by accident).
      reviewSignIn = row['review_sign_in'] == true;
      // The server's value wins, including a cleared one (back to the bundled clip).
      videoUrl = founderVideoUrl(row['founder_video_url']);
      trialDayCount = trialDays(row['trial_enabled'], row['trial_days'], trialDayCount);
      yearlyProduct = _productId(row['yearly_product']);
      await prefs.setBool('founder-video-enabled', enabled);
      await prefs.setBool('native-google-sign-in', nativeGoogle);
      await prefs.setBool('native-apple-sign-in', nativeApple);
      await prefs.setBool('review-sign-in', reviewSignIn);
      await prefs.setInt('trial-days', trialDayCount);
      if (yearlyProduct == null) {
        await prefs.remove('trial-yearly-product');
      } else {
        await prefs.setString('trial-yearly-product', yearlyProduct!);
      }
      if (videoUrl == null) {
        await prefs.remove('founder-video-url');
      } else {
        await prefs.setString('founder-video-url', videoUrl!);
      }
    } catch (_) { /* Offline: retain the last valid setting. */ }
  }

  /// Only a plain store product identifier counts; anything else keeps the default package.
  static String? _productId(Object? remote) {
    if (remote is! String) return null;
    final v = remote.trim();
    return RegExp(r'^[A-Za-z0-9_.\-]{3,64}$').hasMatch(v) ? v : null;
  }
}
