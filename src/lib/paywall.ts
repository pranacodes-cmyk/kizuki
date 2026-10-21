// Plans + trial copy — mirrored in mobile/lib/data/paywall.dart. Prices are placeholders
// until the Play Console products exist; the Android app reads real prices from billing.
export type Plan = { id: "yearly" | "monthly"; label: string; sub: string; price: string; perMonth: string; period: string; badge?: string };

export const PLANS: Record<"yearly" | "monthly", Plan> = {
  yearly: { id: "yearly", label: "Yearly", sub: "12 months · $59.99", price: "$59.99", perMonth: "$5.00", period: "year", badge: "Save 58%" },
  monthly: { id: "monthly", label: "Monthly", sub: "Billed monthly", price: "$11.99", perMonth: "$11.99", period: "month" },
};

export const priceLine = (p: Plan) => `7 days free, then ${p.price}/${p.period}`;

export const TRIAL_DAYS = 7;
export const REMINDER_DAY = 5;

export const trialTimeline = () => [
  { title: "Today", body: "Unlock every clip, word explanation and review." },
  { title: `Day ${REMINDER_DAY}`, body: "We'll send you a reminder that your trial is ending." },
  { title: `Day ${TRIAL_DAYS}`, body: "Your subscription starts. Cancel anytime before." },
];

/** Free learners can watch this many clips per day before the upgrade prompt. */
export const FREE_DAILY_CLIPS = 10;

/** Free learners can ask Kizuki this many questions per day. */
export const FREE_DAILY_ASKS = 5;
