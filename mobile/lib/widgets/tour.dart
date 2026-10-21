import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/tour.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Spotlight targets registered by the feed (only the active clip carries them).
class TourTargets {
  static final player = GlobalKey(debugLabel: 'tour-player');
  static final transcript = GlobalKey(debugLabel: 'tour-transcript');
  static final controls = GlobalKey(debugLabel: 'tour-controls');
  static final tabs = GlobalKey(debugLabel: 'tour-tabs');
  static GlobalKey? of(String? id) => switch (id) {
        'player' => player,
        'transcript' => transcript,
        'controls' => controls,
        'tabs' => tabs,
        _ => null,
      };
}

MascotPose _pose(String p) => MascotPose.values.firstWhere((x) => x.name == p, orElse: () => MascotPose.wave);

/// Welcome tour over the feed: dim overlay with a spotlight on each target, Kizuki's speech
/// bubble, "Skip tour", tap to continue — mirrors WelcomeTour.tsx.
class WelcomeTour extends StatefulWidget {
  const WelcomeTour({super.key});
  @override
  State<WelcomeTour> createState() => _WelcomeTourState();
}

class _WelcomeTourState extends State<WelcomeTour> with TickerProviderStateMixin {
  int i = 0;
  Rect? hole;
  Timer? _measure;
  bool legendReady = false;
  Timer? _legendTimer;
  late final AnimationController _hand = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  TourStep get step => tourSteps[i];

  @override
  void initState() {
    super.initState();
    _measure = Timer.periodic(const Duration(milliseconds: 250), (_) => _updateHole());
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHole());
  }

  @override
  void dispose() {
    _measure?.cancel();
    _legendTimer?.cancel();
    _hand.dispose();
    super.dispose();
  }

  void _updateHole() {
    if (!mounted) return;
    final key = TourTargets.of(step.target);
    Rect? r;
    final box = key?.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.attached && me is RenderBox) {
      final tl = box.localToGlobal(Offset.zero, ancestor: me);
      r = (tl & box.size).inflate(6);
      final bounds = Offset.zero & me.size;
      r = r.intersect(bounds.deflate(4));
      if (r.height > tourMaxHoleHeight) r = Rect.fromLTWH(r.left, r.top, r.width, tourMaxHoleHeight);
      if (r.height < 24 || r.width < 24) r = null;
    }
    if (r != hole) setState(() => hole = r);
  }

  void _next() {
    if (step.kind == 'legend' && !legendReady) return;
    if (i == tourSteps.length - 1) {
      _finish();
      return;
    }
    setState(() {
      i++;
      hole = null;
      legendReady = false;
    });
    _updateHole();
    if (step.kind == 'legend') {
      _legendTimer?.cancel();
      _legendTimer = Timer(const Duration(milliseconds: tourLegendDelayMs), () {
        if (mounted) setState(() => legendReady = true);
      });
    }
  }

  void _finish() {
    _measure?.cancel();
    _legendTimer?.cancel();
    context.read<AppState>().completeTutorial('feed');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final h = hole;
    // Bubble goes below the spotlight when it's in the top half, otherwise above.
    final below = h != null && h.center.dy < size.height * 0.45;
    final last = i == tourSteps.length - 1;

    Widget bubble = _Bubble(
      key: ValueKey(step.id),
      step: step,
      legendReady: legendReady,
      onGotIt: _next,
      last: last,
      hand: step.kind == 'swipe' ? _hand : null,
    );

    return Semantics(
      label: 'Welcome tour',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: Stack(children: [
          Positioned.fill(
            child: TweenAnimationBuilder<Rect?>(
              tween: RectTween(end: h ?? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0)),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (_, r, _) => CustomPaint(painter: _DimPainter(r, h != null)),
            ),
          ),
          Positioned(
            top: pad.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: _finish,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(99), border: Border.all(color: T.border)),
                child: Text('Skip tour', style: txt(13, w: FontWeight.w800, c: T.muted)),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            left: 16,
            right: 16,
            top: h == null ? null : (below ? math.min(h.bottom + 12, size.height - 260) : null),
            bottom: h == null ? null : (below ? null : math.max(size.height - h.top + 12, pad.bottom + 16)),
            child: h == null
                ? SizedBox(height: size.height, child: Center(child: bubble))
                : bubble,
          ),
        ]),
      ),
    );
  }
}

class _DimPainter extends CustomPainter {
  final Rect? r;
  final bool show;
  _DimPainter(this.r, this.show);
  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final paint = Paint()..color = T.stage.withValues(alpha: 0.72);
    final rr = r;
    if (!show || rr == null || rr.isEmpty) {
      canvas.drawPath(full, paint);
      return;
    }
    final cut = Path()..addRRect(RRect.fromRectAndRadius(rr, const Radius.circular(18)));
    canvas.drawPath(Path.combine(PathOperation.difference, full, cut), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(rr, const Radius.circular(18)), Paint()
      ..color = T.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.r != r || old.show != show;
}

class _Bubble extends StatelessWidget {
  final TourStep step;
  final bool legendReady, last;
  final VoidCallback onGotIt;
  final AnimationController? hand;
  const _Bubble({super.key, required this.step, required this.legendReady, required this.onGotIt, required this.last, this.hand});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: T.foreground, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 12))]),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(step.text, style: txt(16, w: FontWeight.w800, c: T.background, h: 1.35)),
        if (step.kind == 'legend') ...[
          const SizedBox(height: 12),
          for (final (id, label, hint) in tourLegend)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 3),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: id == 'new' ? T.info : (id == 'learning' ? T.learning : Colors.transparent), width: 3))),
                  child: Text('言葉', style: jp(18, c: T.background)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: txt(14, w: FontWeight.w900, c: T.background)),
                    Text(hint, style: txt(12, w: FontWeight.w600, c: T.faint)),
                  ]),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: legendReady ? onGotIt : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: legendReady ? T.primary : T.primaryDimFg.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(14)),
              child: Text('Got it', style: txt(15, w: FontWeight.w900, c: T.primaryFg)),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(last ? "Tap to start learning" : 'Tap to continue', style: txt(12, w: FontWeight.w700, c: T.faint)),
        ],
      ]),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: 0.9 + 0.1 * v, child: child)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (hand != null)
          AnimatedBuilder(
            animation: hand!,
            builder: (_, _) {
              final t = Curves.easeInOut.transform(hand!.value);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Opacity(opacity: (1 - t) * 0.9 + 0.1, child: Transform.translate(offset: Offset(0, 40 - 80 * t), child: const Icon(LucideIcons.pointer, size: 48, color: T.foreground))),
              );
            },
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Mascot(_pose(step.pose), size: 72),
          const SizedBox(width: 8),
          Expanded(child: body),
        ]),
      ]),
    );
  }
}
