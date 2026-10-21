import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/onboarding.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';

/// "A message from the founder" — mirrors src/routes/founder.tsx. Until the real founder
/// recording is added, an animated Kizuki speaks the captioned script.
class FounderScreen extends StatefulWidget {
  const FounderScreen({super.key});
  @override
  State<FounderScreen> createState() => _FounderScreenState();
}

class _FounderScreenState extends State<FounderScreen> with TickerProviderStateMixin {
  double t = 0;
  bool playing = true;
  Timer? _timer;
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (playing && t < founderSeconds) setState(() => t = (t + 0.1).clamp(0, founderSeconds.toDouble()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wave.dispose();
    _float.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => playing = !playing);
    if (playing) {
      _wave.repeat(reverse: true);
      _float.repeat(reverse: true);
    } else {
      _wave.stop();
      _float.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = founderLines.lastWhere((l) => l.t <= t, orElse: () => founderLines.first);
    final left = (founderSeconds - t).ceil().clamp(0, founderSeconds);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 16),
            Text.rich(TextSpan(children: [const TextSpan(text: 'A message from the '), TextSpan(text: 'founder', style: txt(24, w: FontWeight.w900, c: T.primary))]), style: txt(24, w: FontWeight.w900)),
            const SizedBox(height: 20),
            Expanded(
              child: GestureDetector(
                onTap: _toggle,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.3), radius: 0.9, colors: [T.primaryDim, T.surface])),
                    child: Stack(children: [
                      Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedBuilder(
                            animation: _float,
                            builder: (_, child) => Transform.translate(offset: Offset(0, -6 * Curves.easeInOut.transform(_float.value)), child: child),
                            child: const Mascot(MascotPose.wave, size: 176),
                          ),
                          const SizedBox(height: 16),
                          AnimatedBuilder(
                            animation: _wave,
                            builder: (_, _) => SizedBox(
                              height: 32,
                              child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                for (var i = 0; i < 14; i++)
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    width: 6,
                                    height: playing ? 6 + (10 + (i * 7) % 22) * ((_wave.value + i * 0.13) % 1) : 6,
                                    decoration: BoxDecoration(color: T.primary, borderRadius: BorderRadius.circular(99)),
                                  ),
                              ]),
                            ),
                          ),
                        ]),
                      ),
                      Positioned(
                        right: 16,
                        top: 16,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: T.stage.withValues(alpha: playing ? 0.4 : 0.7), shape: BoxShape.circle),
                          child: Icon(playing ? LucideIcons.pause : LucideIcons.play, size: 20),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 24,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              key: ValueKey(line.t),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: T.stage.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
                              child: Text(line.text, textAlign: TextAlign.center, style: txt(16, w: FontWeight.w800, h: 1.3)),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Row(children: [
                Ring(value: 1 - t / founderSeconds, color: T.primary, size: 56, stroke: 5, child: Text('$left', style: txt(15, w: FontWeight.w900))),
                const SizedBox(width: 16),
                Expanded(child: Button3D(label: 'Continue', onPressed: () => context.push('/trial'))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
