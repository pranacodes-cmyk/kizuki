// Plans + trial copy — mirrored from src/lib/paywall.ts. These are fallback prices; the
// app swaps in live store prices from RevenueCat (services/billing.dart) when available.

class Plan {
  final String id, label, sub, price, perMonth, period;
  final String? badge;
  const Plan(this.id, this.label, this.sub, this.price, this.perMonth, this.period, [this.badge]);
}

var plans = <String, Plan>{
  'yearly': Plan('yearly', 'Yearly', '12 months · \$54.99', '\$54.99', '\$4.58', 'year', 'Save 58%'),
  'monthly': Plan('monthly', 'Monthly', 'Billed monthly', '\$10.99', '\$10.99', 'month'),
};

/// [trial] false = this store account already used its free week (no trial wording).
String priceLine(Plan p, {bool trial = true}) => p.id == 'yearly' && trial ? '7 days free, then ${p.price}/${p.period}' : '${p.price}/${p.period}, billed today';

const trialDays = 7;
const reminderDay = 5;

const trialTimeline = [
  ('Today', 'Unlock every clip, word explanation and review.'),
  ('Day $reminderDay', "We'll send you a reminder that your trial is ending."),
  ('Day $trialDays', 'Your subscription starts. Cancel anytime before.'),
];

/// Free learners can watch this many clips per day before the upgrade prompt.
const freeDailyClips = 10;

/// Free learners can ask Kizuki this many questions per day.
const freeDailyAsks = 5;
