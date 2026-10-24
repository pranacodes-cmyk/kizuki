/**
 * Semantic haptics — mirrored 1:1 by mobile/lib/services/haptics.dart (same kinds, same pulse
 * tables, same tests). Every vibration in Kizuki goes through here, so both clients feel the same
 * and Settings → Vibration feedback switches all of it off. On the web prototype this uses the
 * Vibration API where the browser has it (Android Chrome); elsewhere it is silent.
 */

export type HapticKind = "tap" | "select" | "tick" | "light" | "success" | "celebrate" | "error";
export type HapticStrength = "selection" | "light" | "medium" | "heavy";

/** Pulses per kind: [delay since the previous pulse in ms, strength]. */
export const HAPTIC_PATTERNS: Record<HapticKind, ReadonlyArray<readonly [number, HapticStrength]>> = {
  tap: [[0, "selection"]],
  select: [[0, "selection"]],
  tick: [[0, "selection"]],
  light: [[0, "light"]],
  success: [[0, "medium"], [110, "light"]],
  celebrate: [[0, "light"], [90, "light"], [90, "medium"]],
  error: [[0, "medium"], [70, "medium"]],
};

/** Web stand-in for the native strengths (vibration length in ms). */
export const VIBRATE_MS: Record<HapticStrength, number> = { selection: 8, light: 12, medium: 20, heavy: 30 };

/** navigator.vibrate pattern for a kind: [on, off, on, …]. */
export function vibratePattern(kind: HapticKind): number[] {
  const out: number[] = [];
  let prevOn = 0;
  for (const [delay, strength] of HAPTIC_PATTERNS[kind]) {
    if (out.length) out.push(Math.max(0, delay - prevOn));
    prevOn = VIBRATE_MS[strength];
    out.push(prevOn);
  }
  return out;
}

/**
 * Plan-building ring (0–100%): a soft ratchet tick every 5%, a light tap when each step's
 * caption changes (25/50/75%) and success on 100%. Null when nothing should be felt.
 */
export function buildingHaptic(prev: number, next: number): HapticKind | null {
  if (next <= prev) return null;
  if (next >= 100) return prev < 100 ? "success" : null;
  if (Math.floor(next / 25) > Math.floor(prev / 25)) return "light";
  if (Math.floor(next / 5) > Math.floor(prev / 5)) return "tick";
  return null;
}

/** Saved setting: missing (older saved state) counts as on. */
export const hapticsOn = (settings: { haptics?: boolean }) => settings.haptics !== false;

let enabled = true;
export function setHapticsEnabled(on: boolean) {
  enabled = on;
}

export function haptic(kind: HapticKind) {
  if (!enabled) return;
  if (typeof navigator === "undefined" || typeof navigator.vibrate !== "function") return;
  try {
    navigator.vibrate(vibratePattern(kind));
  } catch {
    // Some browsers throw without a user gesture; haptics are only ever a nicety.
  }
}
