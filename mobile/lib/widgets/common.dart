import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Loads the bundled clip library once, with loader + error states.
class ContentBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, Content content) builder;
  final String loadingLabel;
  const ContentBuilder({super.key, required this.builder, this.loadingLabel = 'Loading…'});
  @override
  State<ContentBuilder> createState() => _ContentBuilderState();
}

class _ContentBuilderState extends State<ContentBuilder> {
  late Future<Content> _f = Content.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<Content>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasData) return widget.builder(context, snap.data!);
          if (snap.hasError) return ErrorState(title: "Couldn't load clips", body: 'Please restart Kizuki.', onRetry: () => setState(() => _f = Content.load()));
          return MascotLoader(label: widget.loadingLabel);
        },
      );
}

/// Shown in place of a widget that failed to build (ErrorWidget.builder), so a bug never
/// leaves an empty grey screen. Self-contained: works even above MaterialApp.
class ScreenError extends StatelessWidget {
  final String? message;
  const ScreenError({super.key, this.message});
  static const _base = TextStyle(fontFamily: T.sans, decoration: TextDecoration.none);
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(builder: (context, c) {
          if (c.maxHeight < 160 || c.maxWidth < 160) return const ColoredBox(color: T.surface2, child: SizedBox.expand());
          return ColoredBox(
            color: T.background,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🦊', style: TextStyle(fontSize: 40, decoration: TextDecoration.none)),
                  const SizedBox(height: 12),
                  Text('Something went wrong here', textAlign: TextAlign.center, style: _base.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: T.foreground)),
                  const SizedBox(height: 6),
                  Text(message ?? 'Go back and try again. If it keeps happening, restart Kizuki.', textAlign: TextAlign.center, style: _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: T.muted)),
                ]),
              ),
            ),
          );
        }),
      );
}

/// Deterministic burst of confetti — mirrors Confetti.tsx.
class Confetti extends StatefulWidget {
  final int count;
  const Confetti({super.key, this.count = 36});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_c.value, widget.count), size: Size.infinite)),
      );
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final int count;
  _ConfettiPainter(this.t, this.count);
  static const colors = [T.primary, T.gold, T.success, T.info, T.danger];
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < count; i++) {
      final h = fnv1a('c$i');
      final x = (h % 1000) / 1000 * size.width;
      final delay = ((h >> 10) % 60) / 100;
      final dur = 1.8 + ((h >> 14) % 100) / 80;
      final local = ((t * 3.2 - delay) / dur).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -30 + local * local * (size.height + 60);
      final rot = ((h >> 4) % 360) * math.pi / 180 + local * 9.4;
      final w = 6.0 + ((h >> 20) % 6);
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: local > 0.8 ? (1 - local) * 5 : 1);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: w * 1.6), const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Circular progress ring with centered content (onboarding sliders, founder countdown).
class Ring extends StatelessWidget {
  final double value, size, stroke;
  final Color color;
  final Widget child;
  const Ring({super.key, required this.value, required this.color, required this.child, this.size = 190, this.stroke = 14});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => CustomPaint(size: Size(size, size), painter: _RingPainter(v, color, stroke)),
          ),
          child,
        ]),
      );
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  final double stroke;
  _RingPainter(this.v, this.color, this.stroke);
  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, r, Paint()
      ..color = T.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * v, false, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color;
}

/// Network thumbnail with a dark placeholder.
class ClipThumb extends StatelessWidget {
  final String url;
  final double radius;
  const ClipThumb(this.url, {super.key, this.radius = 0});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: T.surface2), loadingBuilder: (_, child, p) => p == null ? child : Container(color: T.surface2)),
        ),
      );
}
