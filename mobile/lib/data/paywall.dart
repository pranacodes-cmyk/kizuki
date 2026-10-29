// Plans + trial copy — mirrored from src/lib/paywall.ts. These are fallback prices; the
// app swaps in live store prices from RevenueCat (services/billing.dart) when available.
// Trial wording follows the server trial experiment (onboarding_settings via logic.trialDays);
// `days` 0 = direct paywall with no trial promises.

import '../i18n/i18n.dart';

class Plan {
  final String id, label, sub, price, perMonth, period;
  final String? badge;
  const Plan(this.id, this.label, this.sub, this.price, this.perMonth, this.period, [this.badge]);
}

var plans = <String, Plan>{
  'yearly': Plan('yearly', 'Yearly', '12 months · \$54.99', '\$54.99', '\$4.58', 'year', 'Save 58%'),
  'monthly': Plan('monthly', 'Monthly', 'Billed monthly', '\$10.99', '\$10.99', 'month'),
};

/// Shipped default when no server trial setting has loaded yet (logic.defaultTrialDays).
const defaultPaywallTrialDays = 7;

String priceLine(Plan p, {int days = defaultPaywallTrialDays}) => p.id == 'yearly' && days > 0
    ? (p.period == 'year' ? tr('{days} days free, then {price}/year', {'days': days, 'price': p.price}) : tr('{days} days free, then {price}/month', {'days': days, 'price': p.price}))
    : (p.period == 'year' ? tr('{price}/year, billed today', {'price': p.price}) : tr('{price}/month, billed today', {'price': p.price}));

/// The plan's second line in the learner's language (live store price included).
String planSub(Plan p) => p.id == 'yearly' ? tr('12 months · {price}', {'price': p.price}) : tr('Billed monthly');

/// "Save 58%" in the learner's language.
String? planBadge(Plan p) => p.badge == null ? null : tr('Save {n}%', {'n': RegExp(r'\d+').firstMatch(p.badge!)?.group(0) ?? ''});

List<(String, String)> trialTimeline([int days = defaultPaywallTrialDays]) => [
      (tr('Today'), tr('Unlock every clip, word explanation and review.')),
      (tr('Day {n}', {'n': days - 2 > 1 ? days - 2 : 1}), tr("We'll send you a reminder that your trial is ending.")),
      (tr('Day {n}', {'n': days}), tr('Your subscription starts. Cancel anytime before.')),
    ];

/// Footer reassurance above the start button.
String trialBadge(int days) => days > 0 ? trn(days, '{n} day free · Cancel anytime', '{n} days free · Cancel anytime') : tr('No commitment · Cancel anytime');

/// Primary button label for the yearly plan.
String trialCta(int days) => days == 7 ? tr('Start my free week') : (days > 0 ? tr('Start my free trial') : tr('Start learning today'));

/// Success toast title after a confirmed purchase.
String purchaseToast(int days) => days > 0 ? tr('Your free trial has started') : tr('Welcome to Premium');

/// Free learners can watch this many clips per day before the upgrade prompt.
const freeDailyClips = 10;

/// Free learners can ask Kizuki this many questions per day.
const freeDailyAsks = 5;
