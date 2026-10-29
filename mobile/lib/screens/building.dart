import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/onboarding.dart';
import '../services/founder_video.dart';
import '../services/haptics.dart';
import '../state/app_state.dart';
import '../theme/mascot_motion.dart';
import '../theme/tokens.dart';
import '../widgets/lively_mascot.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

/// "Building your personal plan" — mirrors src/routes/building.tsx. The fox grooves to its
/// headphones while the ring fills with soft ratchet ticks (buildingHaptic); on 100% it
/// cheers, the ring pulses once with a success tap, then the plan opens.
class BuildingScreen extends StatefulWidget {
  const BuildingScreen({super.key});
  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen> with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: ringPulseMs));
  int pct = 0;
  int review = 0;
  bool done = false;
  Timer? _reviewTimer;
  Timer? _leave;

  @override
  void initState() {
    super.initState();
    unawaited(Content.load());
    FounderVideo.prefetch();
    _ticker = createTicker((elapsed) {
      final p = (elapsed.inMilliseconds / buildMs).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - p, 2.2);
      final next = (eased * 100).round();
      final felt = buildingHaptic(pct, next);
      if (felt != null) Haptics.play(felt);
      setState(() => pct = next);
      // Done the moment the ring reads 100% (the eased fill gets there a little before the clock).
      if (next >= 100 && !done) {
        _ticker.stop();
        setState(() => done = true);
        if (!MediaQuery.disableAnimationsOf(context)) _pulse.forward(from: 0);
        _leave = Timer(const Duration(milliseconds: buildDoneMs), () {
          if (mounted) context.pushReplacement('/plan');
        });
      }
    })..start();
    _reviewTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) => setState(() => review = (review + 1) % reviews.length));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulse.dispose();
    _reviewTimer?.cancel();
    _leave?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().profile;
    final steps = [tr('Matching clips to your interests…'), tr('Picking scenes at your level ({jlpt})…', {'jlpt': p.jlpt}), tr('Fitting it into {minutes} minutes a day…', {'minutes': p.dailyMinutes}), tr('Setting up your reminders…')];
    final step = done ? tr('All set — opening your plan') : steps[((pct / 100) * steps.length).floor().clamp(0, steps.length - 1)];
    final r = reviews[review];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Progress ring with the fox grooving inside.
                SizedBox(
                  width: 232,
                  height: 232,
                  child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, _) => TweenAnimationBuilder<double>(
                          tween: Tween(end: pct / 100),
                          duration: const Duration(milliseconds: 120),
                          builder: (_, v, _) => CustomPaint(painter: ProgressRingPainter(v, pulse: _pulse.isAnimating ? _pulse.value : null)),
                        ),
                      ),
                    ),
                    LivelyMascot(done ? MascotPose.cheer : MascotPose.listen, size: 140, idle: done ? MascotIdle.breathe : MascotIdle.groove, hopKey: done),
                  ]),
                ),
                const SizedBox(height: 12),
                Text('$pct%', style: txt(34, w: FontWeight.w900, c: T.primary, h: 1.1).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 8),
                Text(tr('Building your personal plan'), textAlign: TextAlign.center, style: txt(26, w: FontWeight.w900, h: 1.2)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: c)),
                    child: Text(step, key: ValueKey(step), textAlign: TextAlign.center, style: txt(15, c: done ? T.success : T.muted)),
                  ),
                ),
              ]),
            ),
            SizedBox(
              height: 132,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a), child: c)),
                child: Surface(
                  key: ValueKey(review),
                  padding: const EdgeInsets.all(20),
                  radius: 24,
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [for (var i = 0; i < r.stars; i++) const Icon(LucideIcons.star, size: 16, color: T.gold)]),
                      const SizedBox(height: 8),
                      Text('“${tr(r.text)}”', style: txt(15, h: 1.3)),
                      const SizedBox(height: 8),
                      Text('— ${r.name}', style: txt(13, c: T.muted)),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }
}

/// Round progress ring (building screen) with a glowing head and a one-off pulse on 100%.
/// Mirrors the SVG ring in src/routes/building.tsx.
class ProgressRingPainter extends CustomPainter {
  final double value;
  final double? pulse;
  ProgressRingPainter(this.value, {this.pulse});
  static const double stroke = 14;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final c = rect.center;
    final radius = rect.width / 2;
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..color = T.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    final v = value.clamp(0.0, 1.0);
    if (v <= 0) return;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, Paint()
      ..color = T.primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke);
    if (v < 1) {
      final a = -math.pi / 2 + math.pi * 2 * v;
      final head = c + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawCircle(head, stroke * 0.9, Paint()
        ..color = T.primaryGlow.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(head, stroke / 2 - 2.5, Paint()..color = T.primaryGlow);
    }
    if (pulse != null) {
      final p = ringPulse(pulse!);
      canvas.drawCircle(c, radius * p.scale, Paint()
        ..color = T.primary.withValues(alpha: p.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * (1 - pulse! * 0.6));
    }
  }

  @override
  bool shouldRepaint(ProgressRingPainter old) => old.value != value || old.pulse != pulse;
}
