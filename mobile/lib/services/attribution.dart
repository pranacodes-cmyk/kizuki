import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener, WidgetsBinding, AppLifecycleState;
import 'package:purchases_flutter/purchases_flutter.dart';

import 'billing.dart';

/// Meta SDK app events + RevenueCat attribution.
///
/// Who sends what (never both, so nothing is counted twice):
///  - this SDK: install / app open (activateApp), CompleteRegistration (onboarding done),
///    fb_mobile_tutorial_completion (welcome tour), ViewContent (paywall plans seen),
///    InitiatedCheckout (tapped start trial / subscribe), achievement unlocked.
///  - RevenueCat → Meta Conversions API (server side): StartTrial, Subscribe/Purchase,
///    renewals and cancellations. Automatic SDK purchase logging is off in the manifest /
///    Info.plist for this reason.
///
/// iOS: the App Tracking Transparency question is asked once, after the first screen is on
/// display and the app is active (iOS ignores requests made earlier), behind a short Kizuki
/// explainer. Install/open is logged after the answer, so the install carries the IDFA when
/// the learner allows it. RevenueCat receives the device identifiers after the answer too.
class Attribution {
  static final _fb = FacebookAppEvents();
  static bool _started = false;
  static AppLifecycleListener? _life;

  /// Shown before Apple's tracking question (iOS only). Returns when the learner taps Continue.
  static Future<void> Function()? explainTracking;

  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Starts after the first frame. Safe to call more than once.
  static Future<void> start() async {
    if (!_mobile || _started) return;
    _started = true;
    try {
      await _fb.setAutoLogAppEventsEnabled(false);
      if (Platform.isIOS) await _askTracking();
      await _fb.setAdvertiserIdCollectionEnabled(Platform.isAndroid || await _trackingAllowed());
      await _fb.activateApp();
      _life ??= AppLifecycleListener(onResume: () => unawaited(_fb.activateApp().catchError((Object _) {})));
      await linkRevenueCat();
    } catch (e) {
      debugPrint('KIZUKI_ERROR attribution: $e');
    }
  }

  static Future<bool> _trackingAllowed() async =>
      await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.authorized;

  static Future<void> _askTracking() async {
    try {
      if (await AppTrackingTransparency.trackingAuthorizationStatus != TrackingStatus.notDetermined) return;
      await _whenActive();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final explain = explainTracking;
      if (explain != null) await explain();
      await _whenActive();
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (e) {
      debugPrint('KIZUKI_ERROR tracking prompt: $e');
    }
  }

  static Future<void> _whenActive() async {
    for (var i = 0; i < 40; i++) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  /// Lets RevenueCat match trials and purchases to the Facebook/Instagram ad that brought
  /// the learner (Meta anonymous ID + IDFA/GAID when allowed).
  static Future<void> linkRevenueCat() async {
    if (!Billing.ready) return;
    try {
      final anon = await _fb.getAnonymousId();
      if (anon != null && anon.isNotEmpty) await Purchases.setFBAnonymousID(anon);
      await Purchases.collectDeviceIdentifiers();
      if (Platform.isIOS) await Purchases.enableAdServicesAttributionTokenCollection();
    } catch (e) {
      debugPrint('KIZUKI_ERROR revenuecat attribution: $e');
    }
  }

  static void _safe(Future<void> Function() f) {
    if (!_mobile) return;
    unawaited(f().catchError((Object e) => debugPrint('KIZUKI_ERROR meta event: $e')));
  }

  static void onboardingDone() => _safe(() => _fb.logCompletedRegistration(registrationMethod: 'onboarding'));

  static void tourDone() => _safe(() => _fb.logEvent(name: FacebookAppEvents.eventNameCompletedTutorial, parameters: {'fb_success': '1', 'fb_content_id': 'welcome_tour'}));

  static void paywallViewed() => _safe(() => _fb.logViewContent(id: 'paywall', type: 'paywall'));

  /// Tapped the subscribe button. Value = the plan's price, so Meta can see intent by plan.
  static void checkoutStarted({required String plan, double? price, String? currency}) => _safe(() => _fb.logInitiatedCheckout(
        totalPrice: price,
        currency: currency,
        contentType: 'subscription',
        contentId: plan == 'monthly' ? 'kizuki_premium_monthly' : 'kizuki_premium_yearly',
        numItems: 1,
        paymentInfoAvailable: true,
      ));

  static void achievement(String id) => _safe(() => _fb.logEvent(name: FacebookAppEvents.eventNameUnlockedAchievement, parameters: {'fb_description': id}));
}
