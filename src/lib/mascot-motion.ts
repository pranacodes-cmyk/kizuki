/**
 * Motion math for the living fox, the splash and small "pop" moments — pure functions, mirrored
 * 1:1 in mobile/lib/theme/mascot_motion.dart (same numbers, same tests). Each client only renders
 * the frames these return, so the choreography is identical on web and in the app.
 */

export type MascotIdle = "none" | "breathe" | "float" | "groove";

/** One rendered frame of the fox: offsets in px, scales anchored at the feet, rotation in radians. */
export type MascotFrame = { dy: number; sx: number; sy: number; rot: number; opacity: number; halo: number };

export const ENTER_MS = 700;
export const HOP_MS = 560;
export const POP_MS = 320;

export const SPLASH_MS = 1250;
export const SPLASH_REDUCED_MS = 500;
export const SPLASH_FADE_MS = 320;
export const SPLASH_WORD = "kizuki";
/** The fox face on the splash (and on the native launch screens) — same size in both clients. */
export const SPLASH_FACE = 112;

/** Plan-building ring: fill time and the pause on 100% before the plan opens. */
export const BUILD_MS = 6500;
export const BUILD_DONE_MS = 950;
export const RING_PULSE_MS = 700;

const clamp01 = (t: number) => (t < 0 ? 0 : t > 1 ? 1 : t);
const deg = (d: number) => (d * Math.PI) / 180;
export const easeOutCubic = (t: number) => 1 - Math.pow(1 - clamp01(t), 3);
export function easeOutBack(t: number) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  const x = clamp01(t) - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

/** Keyframes with a sine ease-in-out inside each segment (like CSS/motion keyframes). */
export function keyframe(times: readonly number[], values: readonly number[], t: number): number {
  const at = (i: number) => times[i] ?? 0;
  const val = (i: number) => values[i] ?? 0;
  if (t <= at(0)) return val(0);
  for (let i = 1; i < times.length; i++) {
    if (t <= at(i)) {
      const span = at(i) - at(i - 1);
      const local = span <= 0 ? 1 : (t - at(i - 1)) / span;
      const e = -(Math.cos(Math.PI * local) - 1) / 2;
      return val(i - 1) + (val(i) - val(i - 1)) * e;
    }
  }
  return val(values.length - 1);
}

// Squash → take-off stretch → apex → fall → landing squash → rest.
const HOP_T = [0, 0.16, 0.32, 0.58, 0.84, 0.92, 1];
const HOP_SY = [1, 0.88, 1.08, 1, 0.98, 0.92, 1];
const HOP_SX = [1, 1.08, 0.94, 1, 1.01, 1.06, 1];
const HOP_DY = [0, 0, -0.12, -0.18, 0, 0, 0];

/**
 * The fox at a moment in time. `idleMs` is the endless idle clock; `enter` and `hop` are 0..1
 * progress (enter 1 = fully in, hop null = not hopping). `size` is the fox's box in px.
 */
export function mascotFrame(idle: MascotIdle, idleMs: number, enter: number, hop: number | null, size: number): MascotFrame {
  let dy = 0, sx = 1, sy = 1, rot = 0, halo = 1;
  const s = idleMs / 1000;
  if (idle === "breathe") {
    const b = (1 - Math.cos((2 * Math.PI * s) / 3.2)) / 2;
    sy = 1 + 0.022 * b;
    sx = 1 - 0.008 * b;
    rot = deg(1.2) * Math.sin((2 * Math.PI * s) / 6.4);
    halo = 0.8 + 0.2 * b;
  } else if (idle === "float") {
    const f = (1 - Math.cos((2 * Math.PI * s) / 3)) / 2;
    dy = -0.035 * size * f;
    rot = deg(1.5) * Math.sin((2 * Math.PI * s) / 6);
    halo = 1 - 0.2 * f;
  } else if (idle === "groove") {
    // Nodding along to the music in its headphones: a bounce on every beat (~112 BPM),
    // tilting right, then left, on alternate beats.
    const beat = 0.536;
    const p = Math.abs(Math.sin((Math.PI * s) / beat));
    dy = -0.03 * size * p;
    sy = 1 + 0.012 * p;
    sx = 1 - 0.006 * p;
    rot = deg(3) * Math.sin((Math.PI * s) / beat);
    halo = 0.85 + 0.15 * p;
  }
  const e = clamp01(enter);
  const opacity = clamp01(e / 0.35);
  if (e < 1) {
    const k = 0.6 + 0.4 * easeOutBack(e);
    sx *= k;
    sy *= k;
    dy += (1 - easeOutCubic(e)) * 0.12 * size;
  }
  if (hop !== null) {
    const h = clamp01(hop);
    sy *= keyframe(HOP_T, HOP_SY, h);
    sx *= keyframe(HOP_T, HOP_SX, h);
    const lift = keyframe(HOP_T, HOP_DY, h);
    dy += lift * size;
    halo *= 1 + lift * 1.5;
  }
  return { dy, sx, sy, rot, opacity, halo };
}

/** Answer-card emoji pop (1 → 1.25 → 0.95 → 1) over POP_MS. */
export const POP_TIMES = [0, 0.35, 0.7, 1] as const;
export const POP_SCALES = [1, 1.25, 0.95, 1] as const;
export const popScale = (t: number) => keyframe(POP_TIMES, POP_SCALES, clamp01(t));

/** The orange ring pulsing outward once when the plan reaches 100%. */
export function ringPulse(t: number): { scale: number; opacity: number } {
  const p = clamp01(t);
  return { scale: 1 + 0.14 * easeOutCubic(p), opacity: 0.5 * (1 - p) };
}

export type SplashFrame = {
  faceDy: number; faceSx: number; faceSy: number; glow: number;
  ripples: { r: number; opacity: number; width: number }[];
  letters: { dy: number; opacity: number }[];
  tagline: number; taglineDy: number;
};

/**
 * Splash choreography at `ms`: the fox face squashes and pops, two orange "click" ripples
 * spread from it, "kizuki" rises letter by letter, then the tagline fades in.
 * Reduced motion shows the finished state.
 */
export function splashFrame(ms: number, reduced: boolean): SplashFrame {
  const letters = SPLASH_WORD.split("");
  if (reduced) {
    return {
      faceDy: 0, faceSx: 1, faceSy: 1, glow: 1,
      ripples: [0, 1].map(() => ({ r: 0, opacity: 0, width: 0 })),
      letters: letters.map(() => ({ dy: 0, opacity: 1 })),
      tagline: 1, taglineDy: 0,
    };
  }
  const ft = [0, 180, 420, 700];
  const ripples = [0, 1].map((i) => {
    const p = (ms - (300 + 140 * i)) / 760;
    if (p <= 0 || p >= 1) return { r: 0, opacity: 0, width: 0 };
    return { r: 58 + 100 * easeOutCubic(p), opacity: 0.55 * (1 - p), width: 4 - 3 * p };
  });
  const tag = easeOutCubic((ms - 700) / 250);
  return {
    faceDy: keyframe(ft, [0, 0, -12, 0], ms),
    faceSx: keyframe(ft, [1, 1.06, 0.96, 1], ms),
    faceSy: keyframe(ft, [1, 0.9, 1.1, 1], ms),
    glow: easeOutCubic((ms - 250) / 350),
    ripples,
    letters: letters.map((_, i) => {
      const e = easeOutCubic((ms - (380 + 45 * i)) / 360);
      return { dy: 14 * (1 - e), opacity: e };
    }),
    tagline: tag,
    taglineDy: 6 * (1 - tag),
  };
}
