import { describe, expect, it } from "vitest";

import { keyframe, mascotFrame, popScale, ringPulse, splashFrame, SPLASH_MS, SPLASH_REDUCED_MS, SPLASH_FADE_MS, SPLASH_FACE, BUILD_MS, BUILD_DONE_MS } from "./mascot-motion";

// Mirrored by mobile/test/mascot_motion_test.dart — same inputs, same expected numbers.
const close = (a: number, b: number) => expect(a).toBeCloseTo(b, 4);

describe("living fox", () => {
  it("breathes in place: taller and a touch narrower at the top of a breath", () => {
    const f = mascotFrame("breathe", 1600, 1, null, 100);
    close(f.sy, 1.022); close(f.sx, 0.992); close(f.dy, 0); close(f.rot, 0.020944); close(f.halo, 1);
  });

  it("floats up 3.5% of its size halfway through a float", () => {
    const f = mascotFrame("float", 1500, 1, null, 200);
    close(f.dy, -7); close(f.rot, 0.02618); close(f.halo, 0.8);
  });

  it("grooves on the beat with a 3° head tilt", () => {
    const f = mascotFrame("groove", 268, 1, null, 140);
    close(f.dy, -4.2); close(f.sy, 1.012); close(f.sx, 0.994); close(f.rot, 0.05236);
  });

  it("springs in from 60% size, invisible at the start, overshooting halfway", () => {
    const a = mascotFrame("none", 0, 0, null, 100);
    close(a.opacity, 0); close(a.sx, 0.6); close(a.dy, 12);
    const b = mascotFrame("none", 0, 0.5, null, 100);
    close(b.opacity, 1); close(b.sx, 1.035079); close(b.dy, 1.5);
  });

  it("hops with squash, stretch, an 18% apex and lands back at rest", () => {
    const squash = mascotFrame("none", 0, 1, 0.16, 100);
    close(squash.sy, 0.88); close(squash.sx, 1.08); close(squash.dy, 0);
    const apex = mascotFrame("none", 0, 1, 0.58, 100);
    close(apex.dy, -18); close(apex.halo, 0.73);
    const rising = mascotFrame("none", 0, 1, 0.45, 100);
    close(rising.dy, -15); close(rising.sy, 1.04); close(rising.sx, 0.97);
    const end = mascotFrame("none", 0, 1, 1, 100);
    close(end.dy, 0); close(end.sy, 1); close(end.sx, 1);
  });
});

describe("small moments", () => {
  it("keyframes ease in and out inside a segment", () => close(keyframe([0, 1], [0, 10], 0.25), 1.464466));
  it("answer pops peak at 125% and settle at 100%", () => { close(popScale(0.35), 1.25); close(popScale(0.5), 1.133378); close(popScale(1), 1); });
  it("ring pulse is 12% larger and half faded halfway", () => { const p = ringPulse(0.5); close(p.scale, 1.1225); close(p.opacity, 0.25); });
  it("timings stay in step with the app", () => {
    expect([SPLASH_MS, SPLASH_REDUCED_MS, SPLASH_FADE_MS, SPLASH_FACE, BUILD_MS, BUILD_DONE_MS]).toEqual([1250, 500, 320, 112, 6500, 950]);
  });
});

describe("splash", () => {
  it("starts on the plain fox face (same as the phone's launch screen)", () => {
    const f = splashFrame(0, false);
    close(f.faceSx, 1); close(f.faceSy, 1); close(f.glow, 0);
    expect(f.letters.every((l) => l.opacity === 0)).toBe(true);
    expect(f.ripples.every((r) => r.opacity === 0)).toBe(true);
  });

  it("pops the face, sends the first ripple and starts the wordmark at 420ms", () => {
    const f = splashFrame(420, false);
    close(f.faceDy, -12); close(f.faceSy, 1.1); close(f.faceSx, 0.96); close(f.glow, 0.863977);
    close(f.ripples[0]!.r, 98.28284); close(f.ripples[0]!.opacity, 0.463158); close(f.ripples[1]!.opacity, 0);
    close(f.letters[0]!.opacity, 0.297668); close(f.letters[1]!.opacity, 0);
  });

  it("has both ripples out and letters rising in order at 600ms", () => {
    const f = splashFrame(600, false);
    close(f.ripples[1]!.r, 108.794576);
    close(f.letters[2]!.opacity, 0.739219); close(f.letters[5]!.opacity, 0);
  });

  it("is fully settled at the end, and reduced motion shows the end state at once", () => {
    for (const f of [splashFrame(1250, false), splashFrame(0, true)]) {
      close(f.faceSy, 1); close(f.glow, 1); close(f.tagline, 1);
      expect(f.letters).toHaveLength(6);
      expect(f.letters.every((l) => l.opacity === 1 && l.dy === 0)).toBe(true);
    }
  });
});
