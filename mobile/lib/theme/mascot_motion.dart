import 'dart:math' as math;

/// Motion math for the living fox, the splash and small "pop" moments — pure functions,
/// mirrored 1:1 from src/lib/mascot-motion.ts (same numbers, same tests). Each client only
/// renders the frames these return, so the choreography is identical on web and in the app.

enum MascotIdle { none, breathe, float, groove }

/// One rendered frame of the fox: offsets in px, scales anchored at the feet, rotation in radians.
class MascotFrame {
  final double dy, sx, sy, rot, opacity, halo;
  const MascotFrame({this.dy = 0, this.sx = 1, this.sy = 1, this.rot = 0, this.opacity = 1, this.halo = 1});
  static const rest = MascotFrame();
}

const enterMs = 700;
const hopMs = 560;
const popMs = 320;

const splashMs = 1250;
const splashReducedMs = 500;
const splashFadeMs = 320;
const splashWord = 'kizuki';

/// The fox face on the splash (and on the native launch screens) — same size in both clients.
const splashFace = 112.0;

/// Plan-building ring: fill time and the pause on 100% before the plan opens.
const buildMs = 6500;
const buildDoneMs = 950;
const ringPulseMs = 700;

double _clamp01(double t) => t < 0 ? 0 : (t > 1 ? 1 : t);
double _deg(double d) => d * math.pi / 180;
double easeOutCubic(double t) => 1 - math.pow(1 - _clamp01(t), 3).toDouble();
double easeOutBack(double t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  final x = _clamp01(t) - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

/// Keyframes with a sine ease-in-out inside each segment (like CSS/motion keyframes).
double keyframe(List<double> times, List<double> values, double t) {
  if (t <= times.first) return values.first;
  for (var i = 1; i < times.length; i++) {
    if (t <= times[i]) {
      final span = times[i] - times[i - 1];
      final local = span <= 0 ? 1.0 : (t - times[i - 1]) / span;
      final e = -(math.cos(math.pi * local) - 1) / 2;
      return values[i - 1] + (values[i] - values[i - 1]) * e;
    }
  }
  return values.last;
}

// Squash → take-off stretch → apex → fall → landing squash → rest.
const _hopT = [0.0, 0.16, 0.32, 0.58, 0.84, 0.92, 1.0];
const _hopSy = [1.0, 0.88, 1.08, 1.0, 0.98, 0.92, 1.0];
const _hopSx = [1.0, 1.08, 0.94, 1.0, 1.01, 1.06, 1.0];
const _hopDy = [0.0, 0.0, -0.12, -0.18, 0.0, 0.0, 0.0];

/// The fox at a moment in time. [idleMs] is the endless idle clock; [enter] and [hop] are 0..1
/// progress (enter 1 = fully in, hop null = not hopping). [size] is the fox's box in px.
MascotFrame mascotFrame(MascotIdle idle, double idleMs, double enter, double? hop, double size) {
  double dy = 0, sx = 1, sy = 1, rot = 0, halo = 1;
  final s = idleMs / 1000;
  switch (idle) {
    case MascotIdle.breathe:
      final b = (1 - math.cos(2 * math.pi * s / 3.2)) / 2;
      sy = 1 + 0.022 * b;
      sx = 1 - 0.008 * b;
      rot = _deg(1.2) * math.sin(2 * math.pi * s / 6.4);
      halo = 0.8 + 0.2 * b;
    case MascotIdle.float:
      final f = (1 - math.cos(2 * math.pi * s / 3)) / 2;
      dy = -0.035 * size * f;
      rot = _deg(1.5) * math.sin(2 * math.pi * s / 6);
      halo = 1 - 0.2 * f;
    case MascotIdle.groove:
      // Nodding along to the music in its headphones: a bounce on every beat (~112 BPM),
      // tilting right, then left, on alternate beats.
      const beat = 0.536;
      final p = math.sin(math.pi * s / beat).abs();
      dy = -0.03 * size * p;
      sy = 1 + 0.012 * p;
      sx = 1 - 0.006 * p;
      rot = _deg(3) * math.sin(math.pi * s / beat);
      halo = 0.85 + 0.15 * p;
    case MascotIdle.none:
      break;
  }
  final e = _clamp01(enter);
  final opacity = _clamp01(e / 0.35);
  if (e < 1) {
    final k = 0.6 + 0.4 * easeOutBack(e);
    sx *= k;
    sy *= k;
    dy += (1 - easeOutCubic(e)) * 0.12 * size;
  }
  if (hop != null) {
    final h = _clamp01(hop);
    sy *= keyframe(_hopT, _hopSy, h);
    sx *= keyframe(_hopT, _hopSx, h);
    final lift = keyframe(_hopT, _hopDy, h);
    dy += lift * size;
    halo *= 1 + lift * 1.5;
  }
  return MascotFrame(dy: dy, sx: sx, sy: sy, rot: rot, opacity: opacity, halo: halo);
}

/// Answer-card emoji pop (1 → 1.25 → 0.95 → 1) over [popMs].
const popTimes = [0.0, 0.35, 0.7, 1.0];
const popScales = [1.0, 1.25, 0.95, 1.0];
double popScale(double t) => keyframe(popTimes, popScales, _clamp01(t));

/// The orange ring pulsing outward once when the plan reaches 100%.
({double scale, double opacity}) ringPulse(double t) {
  final p = _clamp01(t);
  return (scale: 1 + 0.14 * easeOutCubic(p), opacity: 0.5 * (1 - p));
}

class SplashRipple {
  final double r, opacity, width;
  const SplashRipple(this.r, this.opacity, this.width);
}

class SplashLetter {
  final double dy, opacity;
  const SplashLetter(this.dy, this.opacity);
}

class SplashFrame {
  final double faceDy, faceSx, faceSy, glow, tagline, taglineDy;
  final List<SplashRipple> ripples;
  final List<SplashLetter> letters;
  const SplashFrame({required this.faceDy, required this.faceSx, required this.faceSy, required this.glow, required this.ripples, required this.letters, required this.tagline, required this.taglineDy});
}

/// Splash choreography at [ms]: the fox face squashes and pops, two orange "click" ripples
/// spread from it, "kizuki" rises letter by letter, then the tagline fades in.
/// Reduced motion shows the finished state.
SplashFrame splashFrame(double ms, bool reduced) {
  final n = splashWord.length;
  if (reduced) {
    return SplashFrame(
      faceDy: 0, faceSx: 1, faceSy: 1, glow: 1,
      ripples: const [SplashRipple(0, 0, 0), SplashRipple(0, 0, 0)],
      letters: List.filled(n, const SplashLetter(0, 1)),
      tagline: 1, taglineDy: 0,
    );
  }
  const ft = [0.0, 180.0, 420.0, 700.0];
  final ripples = [
    for (var i = 0; i < 2; i++)
      () {
        final p = (ms - (300 + 140 * i)) / 760;
        if (p <= 0 || p >= 1) return const SplashRipple(0, 0, 0);
        return SplashRipple(58 + 100 * easeOutCubic(p), 0.55 * (1 - p), 4 - 3 * p);
      }(),
  ];
  final tag = easeOutCubic((ms - 700) / 250);
  return SplashFrame(
    faceDy: keyframe(ft, const [0, 0, -12, 0], ms),
    faceSx: keyframe(ft, const [1, 1.06, 0.96, 1], ms),
    faceSy: keyframe(ft, const [1, 0.9, 1.1, 1], ms),
    glow: easeOutCubic((ms - 250) / 350),
    ripples: ripples,
    letters: [
      for (var i = 0; i < n; i++)
        () {
          final e = easeOutCubic((ms - (380 + 45 * i)) / 360);
          return SplashLetter(14 * (1 - e), e);
        }(),
    ],
    tagline: tag,
    taglineDy: 6 * (1 - tag),
  );
}
