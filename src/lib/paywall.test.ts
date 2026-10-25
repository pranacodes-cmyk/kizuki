import { describe, expect, it } from "vitest";
import { PLANS, priceLine, purchaseToast, TRIAL_DAYS, trialBadge, trialCta, trialTimeline } from "./paywall";

describe("paywall plans", () => {
  it("yearly is $54.99 with a 7-day free trial by default", () => {
    expect(PLANS.yearly.price).toBe("$54.99");
    expect(TRIAL_DAYS).toBe(7);
    expect(priceLine(PLANS.yearly)).toBe("7 days free, then $54.99/year");
  });
  it("monthly is $10.99 and has no trial", () => {
    expect(PLANS.monthly.price).toBe("$10.99");
    expect(priceLine(PLANS.monthly)).toBe("$10.99/month, billed today");
  });
});

describe("trial experiment copy", () => {
  it("follows the server day count", () => {
    expect(priceLine(PLANS.yearly, 3)).toBe("3 days free, then $54.99/year");
    expect(trialBadge(3)).toBe("3 days free · Cancel anytime");
    expect(trialCta(3)).toBe("Start my free trial");
    expect(trialCta(7)).toBe("Start my free week");
    expect(purchaseToast(3)).toBe("Your free trial has started");
    expect(trialTimeline(3).map((x) => x.title)).toEqual(["Today", "Day 1", "Day 3"]);
  });
  it("0 days is a direct paywall with no trial wording", () => {
    expect(priceLine(PLANS.yearly, 0)).toBe("$54.99/year, billed today");
    expect(trialBadge(0)).toBe("No commitment · Cancel anytime");
    expect(trialCta(0)).toBe("Start learning today");
    expect(purchaseToast(0)).toBe("Welcome to Premium");
  });
});
