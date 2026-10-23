import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../data/paywall.dart';
import '../state/app_state.dart' show Premium;

/// Outcome of a store action, so the paywall never shows the wrong message.
enum StoreResult { done, cancelled, none, unavailable }

/// Real App Store / Google Play subscriptions through RevenueCat.
/// Products: kizuki_premium_yearly (7-day trial) + kizuki_premium_monthly, entitlement `premium`.
/// RevenueCat is the only source of truth for Premium in the shipped app: the store status is
/// re-read at launch, on every return to the app and whenever RevenueCat pushes a change.
class Billing {
  // Public SDK keys (publishable, safe in the app).
  static const _androidKey = 'goog_iCcbbkTcxXwMpUUoyXBwVvlzVkW';
  static const _iosKey = 'appl_pgzLIQZPjmocIVBawDqNWokzNPO';
  static const entitlement = 'premium';

  /// Test builds (`--dart-define=KIZUKI_SIMULATE_PURCHASES=true`) skip the store.
  static const simulate = bool.fromEnvironment('KIZUKI_SIMULATE_PURCHASES');

  static bool ready = false;
  static final Map<String, Package> _packages = {};

  /// Whether this store account can still get the yearly free week (false for returning
  /// subscribers who already used it). Unknown → true, the store has the final say.
  static bool trialEligible = true;

  /// Bumped when live prices or trial eligibility arrive, so an open paywall redraws
  /// with the store's local prices instead of keeping the fallback ones.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// Where the learner manages or cancels (App Store / Play subscriptions page).
  static String? managementUrl;

  /// Called with the store-verified Premium state whenever it is known or changes.
  static void Function(Premium premium)? onPremium;

  static AppLifecycleListener? _life;

  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get available => _mobile && !simulate;

  static Future<void> init({String? userId}) async {
    if (!available || ready) return;
    try {
      final cfg = PurchasesConfiguration(Platform.isIOS ? _iosKey : _androidKey)..appUserID = userId;
      await Purchases.configure(cfg);
      ready = true;
    } catch (e) {
      debugPrint('KIZUKI_ERROR billing init: $e');
      return;
    }
    Purchases.addCustomerInfoUpdateListener(_apply);
    _life ??= AppLifecycleListener(onResume: () => unawaited(refresh()));
    // Status and prices load independently: a price failure never hides a paid subscription.
    unawaited(refresh());
    unawaited(loadPlans().catchError((Object e) => debugPrint('KIZUKI_ERROR offerings: $e')));
  }

  static Future<void> refresh() async {
    if (!ready) return;
    try {
      _apply(await Purchases.getCustomerInfo());
    } catch (e) {
      debugPrint('KIZUKI_ERROR customer info: $e');
    }
  }

  static void _apply(CustomerInfo info) {
    managementUrl = info.managementURL;
    onPremium?.call(premiumFrom(info));
  }

  /// Premium as the store reports it: plan from the product, real trial end only for trials.
  static Premium premiumFrom(CustomerInfo info) {
    final e = info.entitlements.active[entitlement];
    if (e == null) return Premium();
    final plan = e.productIdentifier.contains('monthly') ? 'monthly' : 'yearly';
    final since = DateTime.tryParse(e.originalPurchaseDate)?.millisecondsSinceEpoch;
    final exp = e.expirationDate == null ? null : DateTime.tryParse(e.expirationDate!)?.millisecondsSinceEpoch;
    return Premium(active: true, plan: plan, since: since, trialEndsAt: e.periodType == PeriodType.trial ? exp : null);
  }

  /// Swaps the fallback prices for the store's local prices (currency + format per country).
  static Future<void> loadPlans() async {
    final cur = (await Purchases.getOfferings()).current;
    final y = cur?.annual, m = cur?.monthly;
    if (y != null) _packages['yearly'] = y;
    if (m != null) _packages['monthly'] = m;
    final next = Map<String, Plan>.of(plans);
    if (y != null) {
      final yp = y.storeProduct;
      final perMonth = NumberFormat.simpleCurrency(name: yp.currencyCode).format(yp.price / 12);
      final mPrice = m?.storeProduct.price ?? 0;
      final save = mPrice > 0 ? (100 * (1 - yp.price / (mPrice * 12))).round() : 0;
      next['yearly'] = Plan('yearly', 'Yearly', '12 months · ${yp.priceString}', yp.priceString, perMonth, 'year', save > 0 ? 'Save $save%' : null);
      await _checkTrial(yp);
    }
    if (m != null) {
      final mp = m.storeProduct;
      next['monthly'] = Plan('monthly', 'Monthly', 'Billed monthly', mp.priceString, mp.priceString, 'month');
    }
    plans = next;
    revision.value++;
  }

  static Future<void> _checkTrial(StoreProduct yp) async {
    try {
      if (Platform.isAndroid) {
        // Google Play only offers the free phase to accounts that can still use it.
        trialEligible = yp.defaultOption?.freePhase != null;
      } else {
        final r = await Purchases.checkTrialOrIntroductoryPriceEligibility([yp.identifier]);
        trialEligible = r[yp.identifier]?.status != IntroEligibilityStatus.introEligibilityStatusIneligible;
      }
    } catch (e) {
      debugPrint('KIZUKI_ERROR trial eligibility: $e');
    }
  }

  static Future<StoreResult> buy(String plan) async {
    if (!ready) return StoreResult.unavailable;
    if (_packages[plan] == null) {
      try {
        await loadPlans();
      } catch (e) {
        debugPrint('KIZUKI_ERROR offerings retry: $e');
      }
    }
    final pkg = _packages[plan];
    if (pkg == null) return StoreResult.unavailable;
    try {
      final info = (await Purchases.purchase(PurchaseParams.package(pkg))).customerInfo;
      _apply(info);
      return info.entitlements.active.containsKey(entitlement) ? StoreResult.done : StoreResult.none;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError) return StoreResult.cancelled;
      rethrow;
    }
  }

  static Future<StoreResult> restore() async {
    if (!ready) return StoreResult.unavailable;
    try {
      final info = await Purchases.restorePurchases();
      _apply(info);
      return info.entitlements.active.containsKey(entitlement) ? StoreResult.done : StoreResult.none;
    } catch (e) {
      debugPrint('KIZUKI_ERROR restore: $e');
      return StoreResult.unavailable;
    }
  }

  /// Live price + currency of a plan (null until the store answered).
  static (double, String)? priceOf(String plan) {
    final p = _packages[plan]?.storeProduct;
    return p == null ? null : (p.price, p.currencyCode);
  }

  /// Store page where the subscription is changed or cancelled.
  static String manageUrl() => managementUrl ??
      (!kIsWeb && Platform.isIOS ? 'https://apps.apple.com/account/subscriptions' : 'https://play.google.com/store/account/subscriptions?package=com.kizukijapan.app');
}
