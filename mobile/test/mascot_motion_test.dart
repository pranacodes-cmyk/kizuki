import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/theme/mascot_motion.dart';

// Mirrors src/lib/mascot-motion.test.ts — same inputs, same expected numbers.
void close(double a, double b) => expect(a, closeTo(b, 1e-4));

void main() {
  group('living fox', () {
    test('breathes in place: taller and a touch narrower at the top of a breath', () {
      final f = mascotFrame(MascotIdle.breathe, 1600, 1, null, 100);
      close(f.sy, 1.022);
      close(f.sx, 0.992);
      close(f.dy, 0);
      close(f.rot, 0.020944);
      close(f.halo, 1);
    });

    test('floats up 3.5% of its size halfway through a float', () {
      final f = mascotFrame(MascotIdle.float, 1500, 1, null, 200);
      close(f.dy, -7);
      close(f.rot, 0.02618);
      close(f.halo, 0.8);
    });

    test('grooves on the beat with a 3° head tilt', () {
      final f = mascotFrame(MascotIdle.groove, 268, 1, null, 140);
      close(f.dy, -4.2);
      close(f.sy, 1.012);
      close(f.sx, 0.994);
      close(f.rot, 0.05236);
    });

    test('springs in from 60% size, invisible at the start, overshooting halfway', () {
      final a = mascotFrame(MascotIdle.none, 0, 0, null, 100);
      close(a.opacity, 0);
      close(a.sx, 0.6);
      close(a.dy, 12);
      final b = mascotFrame(MascotIdle.none, 0, 0.5, null, 100);
      close(b.opacity, 1);
      close(b.sx, 1.035079);
      close(b.dy, 1.5);
    });

    test('hops with squash, stretch, an 18% apex and lands back at rest', () {
      final squash = mascotFrame(MascotIdle.none, 0, 1, 0.16, 100);
      close(squash.sy, 0.88);
      close(squash.sx, 1.08);
      close(squash.dy, 0);
      final apex = mascotFrame(MascotIdle.none, 0, 1, 0.58, 100);
      close(apex.dy, -18);
      close(apex.halo, 0.73);
      final rising = mascotFrame(MascotIdle.none, 0, 1, 0.45, 100);
      close(rising.dy, -15);
      close(rising.sy, 1.04);
      close(rising.sx, 0.97);
      final end = mascotFrame(MascotIdle.none, 0, 1, 1, 100);
      close(end.dy, 0);
      close(end.sy, 1);
      close(end.sx, 1);
    });
  });

  group('small moments', () {
    test('keyframes ease in and out inside a segment', () => close(keyframe(const [0, 1], const [0, 10], 0.25), 1.464466));
    test('answer pops peak at 125% and settle at 100%', () {
      close(popScale(0.35), 1.25);
      close(popScale(0.5), 1.133378);
      close(popScale(1), 1);
    });
    test('ring pulse is 12% larger and half faded halfway', () {
      final p = ringPulse(0.5);
      close(p.scale, 1.1225);
      close(p.opacity, 0.25);
    });
    test('timings stay in step with the web', () {
      expect([splashMs, splashReducedMs, splashFadeMs, splashFace, buildMs, buildDoneMs], [1250, 500, 320, 112, 6500, 950]);
    });
  });

  group('splash', () {
    test("starts on the plain fox face (same as the phone's launch screen)", () {
      final f = splashFrame(0, false);
      close(f.faceSx, 1);
      close(f.faceSy, 1);
      close(f.glow, 0);
      expect(f.letters.every((l) => l.opacity == 0), isTrue);
      expect(f.ripples.every((r) => r.opacity == 0), isTrue);
    });

    test('pops the face, sends the first ripple and starts the wordmark at 420ms', () {
      final f = splashFrame(420, false);
      close(f.faceDy, -12);
      close(f.faceSy, 1.1);
      close(f.faceSx, 0.96);
      close(f.glow, 0.863977);
      close(f.ripples[0].r, 98.28284);
      close(f.ripples[0].opacity, 0.463158);
      close(f.ripples[1].opacity, 0);
      close(f.letters[0].opacity, 0.297668);
      close(f.letters[1].opacity, 0);
    });

    test('has both ripples out and letters rising in order at 600ms', () {
      final f = splashFrame(600, false);
      close(f.ripples[1].r, 108.794576);
      close(f.letters[2].opacity, 0.739219);
      close(f.letters[5].opacity, 0);
    });

    test('is fully settled at the end, and reduced motion shows the end state at once', () {
      for (final f in [splashFrame(1250, false), splashFrame(0, true)]) {
        close(f.faceSy, 1);
        close(f.glow, 1);
        close(f.tagline, 1);
        expect(f.letters, hasLength(6));
        expect(f.letters.every((l) => l.opacity == 1 && l.dy == 0), isTrue);
      }
    });
  });
}
