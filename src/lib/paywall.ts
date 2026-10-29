// Plans + trial copy — mirrored in mobile/lib/data/paywall.dart. Prices are placeholders
// until the Play Console products exist; the Android app reads real prices from billing.
// Trial wording follows the server trial experiment (onboarding_settings via logic.trialDays);
// `days` 0 = direct paywall with no trial promises.
import { tr, trn } from "./i18n-core";

export type Plan = { id: "yearly" | "monthly"; label: string; sub: string; price: string; perMonth: string; period: string; badge?: string };

export const PLANS: Record<"yearly" | "monthly", Plan> = {
  yearly: { id: "yearly", label: "Yearly", sub: "12 months · $54.99", price: "$54.99", perMonth: "$4.58", period: "year", badge: "Save 58%" },
  monthly: { id: "monthly", label: "Monthly", sub: "Billed monthly", price: "$10.99", perMonth: "$10.99", period: "month" },
};

/** Shipped default when no server trial setting has loaded yet (logic.DEFAULT_TRIAL_DAYS). */
export const TRIAL_DAYS = 7;

export const priceLine = (p: Plan, days: number = TRIAL_DAYS) =>
  p.id === "yearly" && days > 0
    ? p.period === "year" ? tr("{days} days free, then {price}/year", { days, price: p.price }) : tr("{days} days free, then {price}/month", { days, price: p.price })
    : p.period === "year" ? tr("{price}/year, billed today", { price: p.price }) : tr("{price}/month, billed today", { price: p.price });

/** The plan's second line in the learner's language (live store price included). */
export const planSub = (p: Plan) => (p.id === "yearly" ? tr("12 months · {price}", { price: p.price }) : tr("Billed monthly"));

/** "Save 58%" in the learner's language. */
export const planBadge = (p: Plan) => (p.badge ? tr("Save {n}%", { n: p.badge.match(/\d+/)?.[0] ?? "" }) : undefined);

export const trialTimeline = (days: number = TRIAL_DAYS) => [
  { title: tr("Today"), body: tr("Unlock every clip, word explanation and review.") },
  { title: tr("Day {n}", { n: Math.max(days - 2, 1) }), body: tr("We'll send you a reminder that your trial is ending.") },
  { title: tr("Day {n}", { n: days }), body: tr("Your subscription starts. Cancel anytime before.") },
];

/** Footer reassurance above the start button. */
export const trialBadge = (days: number) => (days > 0 ? trn(days, "{n} day free · Cancel anytime", "{n} days free · Cancel anytime") : tr("No commitment · Cancel anytime"));

/** Primary button label for the yearly plan. */
export const trialCta = (days: number) => (days === 7 ? tr("Start my free week") : days > 0 ? tr("Start my free trial") : tr("Start learning today"));

/** Headline for the first paywall step: [prefix, highlighted, suffix]. */
export const trialHeadline = (days: number): [string, string, string] =>
  days > 0 ? ["Try Kizuki ", "free", ` for ${days} days`] : ["Learn with Kizuki ", "Premium", ""];

/** Success toast title after a confirmed purchase. */
export const purchaseToast = (days: number) => (days > 0 ? tr("Your free trial has started") : tr("Welcome to Premium"));

/** Free learners can watch this many clips per day before the upgrade prompt. */
export const FREE_DAILY_CLIPS = 10;

/** Free learners can ask Kizuki this many questions per day. */
export const FREE_DAILY_ASKS = 5;
