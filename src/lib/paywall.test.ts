import { describe, expect, it } from "vitest";
import { PLANS, priceLine, TRIAL_DAYS } from "./paywall";

describe("paywall plans", () => {
  it("yearly is $54.99 with a 7-day free trial", () => {
    expect(PLANS.yearly.price).toBe("$54.99");
    expect(TRIAL_DAYS).toBe(7);
    expect(priceLine(PLANS.yearly)).toBe("7 days free, then $54.99/year");
  });
  it("monthly is $10.99 and has no trial", () => {
    expect(PLANS.monthly.price).toBe("$10.99");
    expect(priceLine(PLANS.monthly)).toBe("$10.99/month, billed today");
    expect(priceLine(PLANS.yearly, false)).toBe("$54.99/year, billed today");
  });
});
