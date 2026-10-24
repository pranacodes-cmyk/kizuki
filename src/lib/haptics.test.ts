import { afterEach, describe, expect, it, vi } from "vitest";

import { buildingHaptic, haptic, HAPTIC_PATTERNS, hapticsOn, setHapticsEnabled, vibratePattern } from "./haptics";

// Mirrored by mobile/test/haptics_test.dart — same tables, same expected values.
describe("haptic patterns", () => {
  it("uses one soft pulse for taps and choices, and short sequences for moments", () => {
    expect(HAPTIC_PATTERNS).toEqual({
      tap: [[0, "selection"]],
      select: [[0, "selection"]],
      tick: [[0, "selection"]],
      light: [[0, "light"]],
      success: [[0, "medium"], [110, "light"]],
      celebrate: [[0, "light"], [90, "light"], [90, "medium"]],
      error: [[0, "medium"], [70, "medium"]],
    });
  });

  it("turns patterns into web vibration on/off lengths", () => {
    expect(vibratePattern("tap")).toEqual([8]);
    expect(vibratePattern("light")).toEqual([12]);
    expect(vibratePattern("success")).toEqual([20, 90, 12]);
    expect(vibratePattern("celebrate")).toEqual([12, 78, 12, 78, 20]);
    expect(vibratePattern("error")).toEqual([20, 50, 20]);
  });
});

describe("plan-building ring", () => {
  it("ticks every 5%, taps at each step and succeeds once at 100%", () => {
    expect(buildingHaptic(0, 4)).toBeNull();
    expect(buildingHaptic(4, 5)).toBe("tick");
    expect(buildingHaptic(7, 8)).toBeNull();
    expect(buildingHaptic(24, 25)).toBe("light");
    expect(buildingHaptic(49, 51)).toBe("light");
    expect(buildingHaptic(99, 100)).toBe("success");
    expect(buildingHaptic(100, 100)).toBeNull();
    expect(buildingHaptic(10, 9)).toBeNull();
  });

  it("feels 16 ticks, 3 step taps and 1 success over a full fill", () => {
    const felt: string[] = [];
    for (let p = 1; p <= 100; p++) { const k = buildingHaptic(p - 1, p); if (k) felt.push(k); }
    expect(felt.filter((k) => k === "tick")).toHaveLength(16);
    expect(felt.filter((k) => k === "light")).toHaveLength(3);
    expect(felt.filter((k) => k === "success")).toHaveLength(1);
  });
});

describe("vibration setting", () => {
  afterEach(() => { setHapticsEnabled(true); vi.unstubAllGlobals(); });

  it("counts a missing setting (older saved state) as on", () => {
    expect(hapticsOn({})).toBe(true);
    expect(hapticsOn({ haptics: true })).toBe(true);
    expect(hapticsOn({ haptics: false })).toBe(false);
  });

  it("vibrates only while enabled", () => {
    const vibrate = vi.fn(() => true);
    vi.stubGlobal("navigator", { vibrate });
    haptic("success");
    expect(vibrate).toHaveBeenCalledWith([20, 90, 12]);
    setHapticsEnabled(false);
    haptic("tap");
    expect(vibrate).toHaveBeenCalledTimes(1);
  });
});
