import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/onboarding.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// "Building your personal plan" — mirrors src/routes/building.tsx.
class BuildingScreen extends StatefulWidget {
  const BuildingScreen({super.key});
  @override
  State<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends State<BuildingScreen> with TickerProviderStateMixin {
  static const _duration = 6500;
  late final Ticker _ticker;
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  int pct = 0;
  int review = 0;
  Timer? _reviewTimer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    unawaited(Content.load());
    _ticker = createTicker((elapsed) {
      final p = (elapsed.inMilliseconds / _duration).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - p, 2.2);
      setState(() => pct = (eased * 100).round());
      if (p >= 1 && !_left) {
        _left = true;
        _ticker.stop();
        Timer(const Duration(milliseconds: 450), () {
          if (mounted) context.pushReplacement('/plan');
        });
      }
    })..start();
    _reviewTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) => setState(() => review = (review + 1) % reviews.length));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _bounce.dispose();
    _reviewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppState>().profile;
    final steps = ['Matching clips to your interests…', 'Picking scenes at your level (${p.jlpt})…', 'Fitting it into ${p.dailyMinutes} minutes a day…', 'Setting up your reminders…'];
    final step = steps[((pct / 100) * steps.length).floor().clamp(0, steps.length - 1)];
    final r = reviews[review];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                AnimatedBuilder(
                  animation: _bounce,
                  builder: (_, child) => Transform.translate(offset: Offset(0, -12 * Curves.easeInOut.transform(_bounce.value)), child: child),
                  child: const Mascot(MascotPose.listen, size: 160),
                ),
                const SizedBox(height: 16),
                Text('Building your personal plan', textAlign: TextAlign.center, style: txt(26, w: FontWeight.w900, h: 1.2)),
                const SizedBox(height: 8),
                SizedBox(height: 24, child: Text(step, style: txt(15, c: T.muted))),
                const SizedBox(height: 32),
                Row(children: [Text('Progress', style: txt(14, w: FontWeight.w800, c: T.muted)), const Spacer(), Text('$pct%', style: txt(14, w: FontWeight.w800, c: T.primary))]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: pct / 100, minHeight: 16, backgroundColor: T.surface2, color: T.primary),
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
                      Text('“${r.text}”', style: txt(15, h: 1.3)),
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
