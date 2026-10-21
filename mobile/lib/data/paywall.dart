// Plans + trial copy — mirrored from src/lib/paywall.ts. Prices are placeholders until the
// Play Console products exist; purchases are simulated.

class Plan {
  final String id, label, sub, price, perMonth, period;
  final String? badge;
  const Plan(this.id, this.label, this.sub, this.price, this.perMonth, this.period, [this.badge]);
}

const plans = {
  'yearly': Plan('yearly', 'Yearly', '12 months · \$59.99', '\$59.99', '\$5.00', 'year', 'Save 58%'),
  'monthly': Plan('monthly', 'Monthly', 'Billed monthly', '\$11.99', '\$11.99', 'month'),
};

String priceLine(Plan p) => '7 days free, then ${p.price}/${p.period}';

const trialDays = 7;
const reminderDay = 5;

const trialTimeline = [
  ('Today', 'Unlock every clip, word explanation and review.'),
  ('Day $reminderDay', "We'll send you a reminder that your trial is ending."),
  ('Day $trialDays', 'Your subscription starts. Cancel anytime before.'),
];

/// Free learners can watch this many clips per day before the upgrade prompt.
const freeDailyClips = 10;
