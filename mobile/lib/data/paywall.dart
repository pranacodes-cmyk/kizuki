// Plans + trial copy — mirrored from src/lib/paywall.ts. These are fallback prices; the
// app swaps in live store prices from RevenueCat (services/billing.dart) when available.
// Trial wording follows the server trial experiment (onboarding_settings via logic.trialDays);
// `days` 0 = direct paywall with no trial promises.

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

String priceLine(Plan p, {int days = defaultPaywallTrialDays}) =>
    p.id == 'yearly' && days > 0 ? '$days days free, then ${p.price}/${p.period}' : '${p.price}/${p.period}, billed today';

List<(String, String)> trialTimeline([int days = defaultPaywallTrialDays]) => [
      ('Today', 'Unlock every clip, word explanation and review.'),
      ('Day ${days - 2 > 1 ? days - 2 : 1}', "We'll send you a reminder that your trial is ending."),
      ('Day $days', 'Your subscription starts. Cancel anytime before.'),
    ];

/// Footer reassurance above the start button.
String trialBadge(int days) => days > 0 ? '$days days free · Cancel anytime' : 'No commitment · Cancel anytime';

/// Primary button label for the yearly plan.
String trialCta(int days) => days == 7 ? 'Start my free week' : (days > 0 ? 'Start my free trial' : 'Start learning today');

/// Success toast title after a confirmed purchase.
String purchaseToast(int days) => days > 0 ? 'Your free trial has started' : 'Welcome to Premium';

/// Free learners can watch this many clips per day before the upgrade prompt.
const freeDailyClips = 10;

/// Free learners can ask Kizuki this many questions per day.
const freeDailyAsks = 5;
