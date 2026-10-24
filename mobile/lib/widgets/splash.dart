import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/mascot_motion.dart';
import '../theme/tokens.dart';
import 'lively_mascot.dart';
import 'ui.dart';

/// Animated splash over the first screen on a cold start — mirrors Splash in AppFrame.tsx.
/// It starts on exactly what the phone's own launch screen shows (the fox face, [splashFace]
/// points, centred on black), so the hand-off is seamless, then plays the shared
/// [splashFrame] choreography and fades away.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key});
  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  double _ms = 0;
  bool _reduced = false;
  bool _started = false;
  bool _gone = false;

  int get _hold => _reduced ? splashReducedMs : splashMs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    SplashGate.visible.value = true;
    _ticker.start();
  }

  void _tick(Duration e) {
    _ms = e.inMicroseconds / 1000;
    // Screens start their entrances as the splash begins to fade, so the two overlap.
    if (_ms >= _hold && SplashGate.visible.value) SplashGate.visible.value = false;
    if (_ms >= _hold + splashFadeMs) {
      _ticker.stop();
      setState(() => _gone = true);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (SplashGate.visible.value) SplashGate.visible.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    final f = splashFrame(math.min(_ms, _hold.toDouble()), _reduced);
    final out = easeOutCubic((_ms - _hold) / splashFadeMs);
    final letters = splashWord.split('');
    return IgnorePointer(
      ignoring: out > 0,
      child: Opacity(
        opacity: (1 - out).clamp(0.0, 1.0),
        // Material gives the texts their theme (this sits above the Navigator).
        child: Material(
          color: T.background,
          child: Transform.scale(
            scale: 1 + 0.04 * out,
            child: Stack(fit: StackFit.expand, children: [
              Center(child: SizedBox(width: 320, height: 320, child: CustomPaint(painter: _SplashPainter(f)))),
              Center(
                child: Transform.translate(
                  offset: Offset(0, f.faceDy),
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(f.faceSx, f.faceSy, 1),
                    child: const Mascot(MascotPose.face, size: splashFace),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: const Offset(0, 112),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < letters.length; i++)
                        Opacity(
                          opacity: f.letters[i].opacity.clamp(0.0, 1.0),
                          child: Transform.translate(offset: Offset(0, f.letters[i].dy), child: Text(letters[i], style: txt(40, w: FontWeight.w900, h: 1))),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: f.tagline.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, f.taglineDy),
                        child: Text.rich(
                          TextSpan(children: [TextSpan(text: '気づき', style: jp(14, c: T.primary)), const TextSpan(text: '  ·  the moment it clicks')]),
                          style: txt(14, w: FontWeight.w700, c: T.muted),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  final SplashFrame f;
  _SplashPainter(this.f);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (f.glow > 0) {
      const r = 96.0;
      canvas.drawCircle(
        c,
        r,
        Paint()..shader = RadialGradient(colors: [T.primary.withValues(alpha: 0.3 * f.glow), T.primary.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    for (final r in f.ripples) {
      if (r.opacity <= 0) continue;
      canvas.drawCircle(c, r.r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width
        ..color = T.primaryGlow.withValues(alpha: r.opacity));
    }
  }

  @override
  bool shouldRepaint(_SplashPainter old) => true;
}
