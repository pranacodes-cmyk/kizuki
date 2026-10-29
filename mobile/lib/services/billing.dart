import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/paywall.dart';
import 'analytics.dart';
import 'onboarding_settings.dart';
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
  static Future<void>? _initializing;
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
  static Timer? _expiry;

  /// Account the app wants purchases linked to, and the one the store SDK actually uses
  /// (null = anonymous). They differ while configuring or after a failed link, and are
  /// reconciled in order so a sign-in during startup is never lost.
  static String? _identity;
  static String? _applied;
  static Future<void> _identityWork = Future<void>.value();

  /// Link store purchases to the signed-in account used by the server tutor check.
  static Future<void> identify(String? userId) {
    _identity = userId;
    if (!ready) return _identityWork;
    return _reconcile();
  }

  static Future<void> _reconcile() {
    _identityWork = _identityWork.then((_) async {
      final want = _identity;
      if (want == _applied) return;
      try {
        if (want != null) {
          // A purchase made before signing in into an account that already existed stays
          // on the anonymous store user after logIn. Restoring moves it to this account
          // (same as the Restore button) so the learner is never sent back to the paywall.
          final hadAccess = _lastActive;
          final result = await Purchases.logIn(want);
          _applied = want;
          var info = result.customerInfo;
          if (hadAccess && !info.entitlements.active.containsKey(entitlement)) {
            try {
              info = await Purchases.restorePurchases();
            } catch (e) {
              _log('billing transfer', e);
            }
          }
          _apply(info);
        } else {
          final info = await Purchases.logOut();
          _applied = null;
          _apply(info);
        }
      } catch (e) {
        _log('billing identity', e);
        onPremium?.call(Premium());
      }
    });
    return _identityWork;
  }

  /// A purchase the store has not approved yet (e.g. pending payment). When it is
  /// approved later, the same mandatory account step as an instant purchase follows.
  static const _awaitingKey = 'kizuki-purchase-awaiting-store';
  static bool _awaiting = false;

  /// Called when a purchase that was waiting for store approval becomes active.
  static void Function()? onApprovedLater;

  static Future<void> _setAwaiting(bool v) async {
    _awaiting = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (v) {
        await prefs.setBool(_awaitingKey, true);
      } else {
        await prefs.remove(_awaitingKey);
      }
    } catch (e) {
      _log('pending purchase flag', e);
    }
  }

  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// A phone without a usable store (emulator, no Play services, purchases turned off) is an
  /// expected setup, not an app fault: logged as KIZUKI_WARN so crash checks don't trip on it.
  static bool storeUnavailable(Object e) {
    final text = e.toString();
    return text.contains('BILLING_UNAVAILABLE') || text.contains('PurchaseNotAllowedError') || text.contains('Billing is not available') || text.contains('StoreProblemError');
  }

  static void _log(String what, Object e) => debugPrint('${storeUnavailable(e) ? 'KIZUKI_WARN' : 'KIZUKI_ERROR'} $what: $e');
  static bool get available => _mobile && !simulate;

  static Future<void> init({String? userId}) {
    if (!available || ready) return Future<void>.value();
    return _initializing ??= _init(userId: userId).whenComplete(() => _initializing = null);
  }

  static Future<void> _init({String? userId}) async {
    if (!available || ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _awaiting = prefs.getBool(_awaitingKey) ?? false;
    } catch (e) {
      _log('pending purchase flag', e);
    }
    try {
      final id = _identity ?? userId;
      final cfg = PurchasesConfiguration(Platform.isIOS ? _iosKey : _androidKey)..appUserID = id;
      await Purchases.configure(cfg);
      _applied = id;
      ready = true;
    } catch (e) {
      _log('billing init', e);
      return;
    }
    // An account that signed in while the store was configuring is linked now.
    unawaited(_reconcile());
    Purchases.addCustomerInfoUpdateListener(_apply);
    _life ??= AppLifecycleListener(onResume: () => unawaited(refresh()));
    // Status and prices load independently: a price failure never hides a paid subscription.
    unawaited(refresh());
    unawaited(loadPlans().catchError((Object e) => _log('offerings', e)));
  }

  /// Sign-in cannot navigate until this account's live entitlement has been read.
  static Future<bool> verifyAccount(String userId) async {
    if (!available) return true; // explicitly simulated tests only
    await init();
    if (!ready) return false;
    await identify(userId);
    return refresh();
  }

  static Future<bool> refresh() async {
    if (!ready) return false;
    try {
      // Retries an account link that failed earlier (e.g. offline at sign-in). While the
      // store still uses another identity its purchases are not this account's: stay locked.
      await _reconcile();
      if (_identity != _applied) return false;
      final checking = _applied;
      await Purchases.invalidateCustomerInfoCache();
      final info = await Purchases.getCustomerInfo();
      if (checking != _identity || checking != _applied) return false;
      _apply(info);
      return true;
    } catch (e) {
      _log('customer info', e);
      return false;
    }
  }

  /// Whether the last store answer gave access (used to carry a purchase across sign-in).
  static bool _lastActive = false;

  static void _apply(CustomerInfo info) {
    managementUrl = info.managementURL;
    final premium = premiumFrom(info);
    _lastActive = premium.active;
    _expiry?.cancel();
    onPremium?.call(premium);
    if (premium.active && _awaiting) {
      unawaited(_setAwaiting(false));
      onApprovedLater?.call();
    }
    final end = premium.expiresAt;
    if (premium.active && end != null) {
      final remaining = end - DateTime.now().millisecondsSinceEpoch;
      // At the period end the store usually renews a moment later: ask the store first
      // instead of locking straight away, and check once more for a late renewal.
      _expiry = Timer(Duration(milliseconds: remaining > 0 ? remaining : 0), () async {
        if (!await refresh()) onPremium?.call(Premium());
        if (!_lastActive) {
          _expiry = Timer(const Duration(seconds: 45), () => unawaited(refresh()));
        }
      });
    }
  }

  /// Premium as the store reports it: plan from the product, real trial end only for trials.
  static Premium premiumFrom(CustomerInfo info) {
    final e = info.entitlements.active[entitlement];
    if (e == null) return Premium();
    final plan = e.productIdentifier.contains('monthly') ? 'monthly' : 'yearly';
    final since = DateTime.tryParse(e.originalPurchaseDate)?.millisecondsSinceEpoch;
    final expirationDate = e.expirationDate;
    final exp = expirationDate == null ? null : DateTime.tryParse(expirationDate)?.millisecondsSinceEpoch;
    if (exp != null && exp <= DateTime.now().millisecondsSinceEpoch) return Premium();
    return Premium(active: true, plan: plan, since: since, expiresAt: exp, trialEndsAt: e.periodType == PeriodType.trial ? exp : null);
  }

  /// Swaps the fallback prices for the store's local prices (currency + format per country).
  static Future<void> loadPlans() async {
    final cur = (await Purchases.getOfferings()).current;
    var y = cur?.annual;
    final m = cur?.monthly;
    // Server experiment: present a specific store product as the yearly plan (e.g. a 3-day
    // trial or no-trial variant) without an app build; unknown ids keep the default package.
    final want = OnboardingSettings.yearlyProduct;
    if (want != null && cur != null) {
      for (final p in cur.availablePackages) {
        // Package ids (yearly_3d / yearly_nt) are shared by Play and App Store; store ids differ.
        if (p.identifier == want || p.storeProduct.identifier == want) {
          y = p;
          break;
        }
      }
    }
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
      _log('trial eligibility', e);
    }
  }

  static Future<StoreResult> buy(String plan) async {
    Analytics.track('checkout_started', {'plan': plan, 'is_simulated': simulate});
    if (!ready) { Analytics.track('checkout_result', {'result': 'unavailable'}); return StoreResult.unavailable; }
    if (_packages[plan] == null) {
      try {
        await loadPlans();
      } catch (e) {
        _log('offerings retry', e);
      }
    }
    final pkg = _packages[plan];
    if (pkg == null) { Analytics.track('checkout_result', {'result': 'unavailable'}); return StoreResult.unavailable; }
    try {
      final info = (await Purchases.purchase(PurchaseParams.package(pkg))).customerInfo;
      final done = info.entitlements.active.containsKey(entitlement);
      // Not approved yet: remember it so a later approval still asks for the account.
      if (!done) await _setAwaiting(true);
      _apply(info);
      Analytics.track('checkout_result', {'result': done ? 'done' : 'pending', 'plan': plan});
      return done ? StoreResult.done : StoreResult.none;
    } on PlatformException catch (e) {
      final cancelled = PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError;
      Analytics.track('checkout_result', {'result': cancelled ? 'cancelled' : 'error'});
      if (cancelled) return StoreResult.cancelled;
      rethrow;
    }
  }

  static Future<StoreResult> restore() async {
    Analytics.track('restore_started');
    if (!ready) { Analytics.track('restore_result', {'result': 'unavailable'}); return StoreResult.unavailable; }
    try {
      final info = await Purchases.restorePurchases();
      _apply(info);
      final done = info.entitlements.active.containsKey(entitlement);
      Analytics.track('restore_result', {'result': done ? 'done' : 'none'});
      return done ? StoreResult.done : StoreResult.none;
    } catch (e) {
      Analytics.track('restore_result', {'result': 'error'});
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
