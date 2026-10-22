import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/tour.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Welcome-tour state: which step is showing (not persisted — a restart replays the tour
/// from the start until it's finished or skipped). Mirrors useTour in src/lib/tour-store.ts.
class Tour extends ChangeNotifier {
  static final I = Tour._();
  Tour._();

  int? _i;

  /// Called once when the tour ends (finished or skipped).
  VoidCallback? onFinish;

  bool get running => _i != null;
  int get index => _i ?? -1;
  TourStep? get step => (_i != null && _i! < tourSteps.length) ? tourSteps[_i!] : null;

  void start() {
    _i = 0;
    _notify();
  }

  void goTo(int i) {
    if (_i == null) return;
    if (i >= tourSteps.length) return finish();
    _i = i;
    _notify();
  }

  void next() {
    if (_i != null) goTo(_i! + 1);
  }

  /// The step's target never showed up: jump over the steps that depend on it.
  void skipStep() {
    final s = step;
    if (s == null) return;
    s.skipTo != null ? goTo(tourIndexOf(s.skipTo!)) : next();
  }

  void finish() {
    if (_i == null) return;
    _i = null;
    _notify();
    onFinish?.call();
  }

  /// Reset without completing (tests, sign-out).
  void reset() {
    _i = null;
    _notify();
  }

  /// Something the learner did. Moves on when it's what the current step asked for.
  void emit(TourEvent e) {
    final s = step;
    if (s == null) return;
    if (s.kind == 'action' && s.until == e) return next();
    // Closed the word card before tapping Explain → carry on after the card steps.
    if (e == TourEvent.cardClosed && s.target == 'cardExplain') skipStep();
  }

  /// The route changed.
  void route(String path) {
    final s = step;
    if (s != null && s.untilRoute == path) next();
  }

  void _notify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}

/// Marks a widget as a tour spotlight target (the web uses data-tour="id"). Several may be
/// mounted at once (route transitions); the most recently mounted visible one wins.
class TourAnchor extends StatefulWidget {
  final String id;
  final bool enabled;
  final Widget child;
  const TourAnchor({super.key, required this.id, required this.child, this.enabled = true});
  @override
  State<TourAnchor> createState() => _TourAnchorState();

  static final Map<String, List<State>> _live = {};

  /// Rect of the target in [ancestor]'s coordinates, or null when it isn't on screen.
  static Rect? rectOf(String id, RenderBox ancestor) {
    final list = _live[id];
    if (list == null) return null;
    for (final s in list.reversed) {
      final box = s.mounted ? s.context.findRenderObject() : null;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final r = box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
      if (r.width < 8 || r.height < 8) continue;
      return r;
    }
    return null;
  }

  @visibleForTesting
  static bool has(String id) => (_live[id] ?? const []).isNotEmpty;
}

class _TourAnchorState extends State<TourAnchor> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) _add(widget.id);
  }

  @override
  void didUpdateWidget(covariant TourAnchor old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.enabled != widget.enabled) {
      if (old.enabled) _remove(old.id);
      if (widget.enabled) _add(widget.id);
    }
  }

  @override
  void dispose() {
    if (widget.enabled) _remove(widget.id);
    super.dispose();
  }

  void _add(String id) => (TourAnchor._live[id] ??= []).add(this);
  void _remove(String id) => TourAnchor._live[id]?.remove(this);

  @override
  Widget build(BuildContext context) => widget.child;
}

MascotPose _pose(String p) => MascotPose.values.firstWhere((x) => x.name == p, orElse: () => MascotPose.wave);

/// The tour overlay. Sits above every route and sheet (MaterialApp.builder), starts on the
/// feed for new learners, follows them to Explore, Vocab and their first review, and
/// spotlights the thing to tap. Mirrors TourHost in src/components/mimi/WelcomeTour.tsx.
class TourHost extends StatefulWidget {
  /// Current route path (/feed, /explore, /vocab, /review…).
  final ValueListenable<String> path;
  const TourHost({super.key, required this.path});
  @override
  State<TourHost> createState() => _TourHostState();
}

class _TourHostState extends State<TourHost> with TickerProviderStateMixin {
  Rect? hole;
  Timer? _measure;
  int _missingMs = 0;
  bool waitedOut = false;
  bool legendReady = false;
  Timer? _legendTimer;
  int _shownIndex = -1;
  String _lastPath = '';
  late final AnimationController _hand = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  AppState get _app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    Tour.I.addListener(_onTour);
    widget.path.addListener(_onPath);
    Tour.I.onFinish = () {
      if (mounted) _app.completeTutorial('feed');
    };
    _lastPath = widget.path.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void didUpdateWidget(covariant TourHost old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      old.path.removeListener(_onPath);
      widget.path.addListener(_onPath);
    }
  }

  @override
  void dispose() {
    Tour.I.removeListener(_onTour);
    widget.path.removeListener(_onPath);
    _measure?.cancel();
    _legendTimer?.cancel();
    _hand.dispose();
    super.dispose();
  }

  void _onPath() {
    final p = widget.path.value;
    if (p == _lastPath) return;
    _lastPath = p;
    Tour.I.route(p);
    _maybeStart();
    if (mounted) setState(() {});
  }

  void _maybeStart() {
    if (!mounted || Tour.I.running) return;
    final app = _app;
    if (app.onboarded && !app.tutorialFeed && widget.path.value == '/feed') Tour.I.start();
  }

  void _onTour() {
    if (!mounted) return;
    if (Tour.I.index != _shownIndex) {
      _shownIndex = Tour.I.index;
      hole = null;
      _missingMs = 0;
      waitedOut = false;
      legendReady = false;
      _legendTimer?.cancel();
      final s = Tour.I.step;
      if (s?.kind == 'legend') {
        _legendTimer = Timer(const Duration(milliseconds: tourLegendDelayMs), () {
          if (mounted) setState(() => legendReady = true);
        });
      }
      _measure?.cancel();
      if (Tour.I.running) {
        _measure = Timer.periodic(const Duration(milliseconds: 200), (_) => _updateHole());
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateHole());
      }
    }
    setState(() {});
  }

  bool get _onScreen {
    final s = Tour.I.step;
    return s != null && (s.screens.isEmpty || s.screens.contains(widget.path.value));
  }

  void _updateHole() {
    if (!mounted) return;
    final s = Tour.I.step;
    final me = context.findRenderObject();
    if (s == null || me is! RenderBox || !me.hasSize) return;
    Rect? r;
    if (s.target != null && _onScreen) {
      r = TourAnchor.rectOf(s.target!, me);
      if (r != null) {
        r = r.inflate(6).intersect((Offset.zero & me.size).deflate(4));
        if (r.height > tourMaxHoleHeight) r = Rect.fromLTWH(r.left, r.top, r.width, tourMaxHoleHeight);
        if (r.width < 16 || r.height < 16) r = null;
      }
      if (r == null) {
        _missingMs += 200;
        if (_missingMs >= tourTargetWaitMs && !waitedOut) setState(() => waitedOut = true);
      } else {
        _missingMs = 0;
        if (waitedOut) setState(() => waitedOut = false);
      }
    }
    if (r != hole) setState(() => hole = r);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on profile / tutorial changes (start + text).
    final app = context.watch<AppState>();
    if (!Tour.I.running && app.onboarded && !app.tutorialFeed && widget.path.value == '/feed') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
    }
    final s = Tour.I.step;
    if (s == null || !_onScreen) return const SizedBox.shrink();

    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final h = (s.target != null && !waitedOut) ? hole : null;
    final waitingForTarget = s.target != null && h == null && !waitedOut;
    final action = s.kind == 'action' && !waitedOut;
    final pass = s.passThrough && !waitedOut;
    final text = tourText(s, name: app.profile.name, minutes: app.profile.dailyMinutes);
    final total = tourSteps.length;

    void onNext() {
      if (s.kind == 'legend' && !legendReady) return;
      if (s.kind == 'finish') return Tour.I.finish();
      if (s.kind == 'action') return Tour.I.skipStep();
      Tour.I.next();
    }

    final bubble = _Bubble(
      key: ValueKey('${s.id}-$waitedOut'),
      pose: _pose(s.pose),
      text: text,
      progress: (Tour.I.index + 1) / total,
      kind: waitedOut && s.kind == 'action' ? 'tap' : s.kind,
      hint: s.hint,
      legendReady: legendReady,
      onNext: onNext,
    );

    // Bubble placement: under a spotlight in the top half, above one lower down, else centered.
    Widget placed;
    const estH = 200.0;
    if (h != null) {
      final below = h.center.dy < size.height * 0.45;
      final spaceBelow = size.height - h.bottom - pad.bottom;
      final spaceAbove = h.top - pad.top - 48;
      if (below && spaceBelow >= estH) {
        placed = Positioned(left: 16, right: 16, top: h.bottom + 14, child: bubble);
      } else if (!below && spaceAbove >= estH) {
        placed = Positioned(left: 16, right: 16, bottom: size.height - h.top + 14, child: bubble);
      } else {
        placed = Positioned(left: 16, right: 16, top: pad.top + 56, child: bubble);
      }
    } else if (s.hand == 'swipe' && !waitedOut) {
      placed = Positioned(left: 16, right: 16, top: size.height * 0.2, child: bubble);
    } else {
      placed = Positioned.fill(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Center(child: bubble)));
    }

    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: 'Welcome tour',
        child: Stack(children: [
          // Blocking layer: tap steps advance on any tap; action steps only let the spotlight through.
          if (!pass)
            Positioned.fill(
              child: action
                  ? _HoleBarrier(hole: h)
                  : GestureDetector(behavior: HitTestBehavior.opaque, onTap: waitingForTarget ? null : onNext),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: h ?? Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0)),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (_, r, _) => CustomPaint(painter: _DimPainter(r, h != null, dim: pass ? 0 : (waitingForTarget ? 0.35 : 0.72))),
              ),
            ),
          ),
          if (s.hand == 'tap' && h != null && action) _TapHand(anim: _hand, at: h),
          if (s.hand == 'swipe' && !waitedOut) _SwipeHand(anim: _hand, center: Offset(size.width / 2, size.height * 0.62)),
          if (!waitingForTarget) (pass ? placedChild(placed) : placed),
          Positioned(
            top: pad.top + 8,
            right: 16,
            child: Semantics(
              button: true,
              label: 'Skip tour',
              child: GestureDetector(
                onTap: Tour.I.finish,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(99), border: Border.all(color: T.border)),
                  child: Text('Skip tour', style: txt(13, w: FontWeight.w800, c: T.muted)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// IgnorePointer must wrap the Positioned's child, not the Positioned itself.
  Widget placedChild(Widget placed) {
    if (placed is Positioned) {
      return Positioned(left: placed.left, right: placed.right, top: placed.top, bottom: placed.bottom, width: placed.width, height: placed.height, child: IgnorePointer(child: placed.child));
    }
    return IgnorePointer(child: placed);
  }
}

/// Absorbs taps everywhere except inside the spotlight, so only the highlighted thing works.
class _HoleBarrier extends LeafRenderObjectWidget {
  final Rect? hole;
  const _HoleBarrier({required this.hole});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHoleBarrier(hole);
  @override
  void updateRenderObject(BuildContext context, _RenderHoleBarrier renderObject) => renderObject.hole = hole;
}

class _RenderHoleBarrier extends RenderBox {
  Rect? hole;
  _RenderHoleBarrier(this.hole);
  @override
  bool get sizedByParent => true;
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;
  @override
  bool hitTestSelf(Offset position) => hole == null || !hole!.contains(position);
}

class _DimPainter extends CustomPainter {
  final Rect? r;
  final bool show;
  final double dim;
  _DimPainter(this.r, this.show, {required this.dim});
  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final paint = Paint()..color = T.stage.withValues(alpha: dim);
    final rr = r;
    if (!show || rr == null || rr.isEmpty) {
      if (dim > 0) canvas.drawPath(full, paint);
      return;
    }
    final rrect = RRect.fromRectAndRadius(rr, const Radius.circular(18));
    if (dim > 0) canvas.drawPath(Path.combine(PathOperation.difference, full, Path()..addRRect(rrect)), paint);
    canvas.drawRRect(rrect, Paint()
      ..color = T.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.r != r || old.show != show || old.dim != dim;
}

/// Pulsing ring + bobbing finger on the thing to tap.
class _TapHand extends StatelessWidget {
  final Animation<double> anim;
  final Rect at;
  const _TapHand({required this.anim, required this.at});
  @override
  Widget build(BuildContext context) {
    // Fingertip on the lower part of the target, so the word itself stays readable
    // (WelcomeTour.tsx: TOUR_HAND_TIP_Y).
    final c = Offset(at.center.dx, at.top + at.height * tourHandTipY);
    return Positioned(
      left: c.dx - 40,
      top: c.dy - 40,
      width: 80,
      height: 104,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: anim,
          builder: (_, _) {
            final v = anim.value;
            final press = math.sin(v * math.pi * 2) * 0.5 + 0.5;
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 40 - 18 - 14 * v,
                top: 40 - 18 - 14 * v,
                child: Container(
                  width: 36 + 28 * v,
                  height: 36 + 28 * v,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: T.primary.withValues(alpha: 1 - v), width: 3)),
                ),
              ),
              Positioned(
                left: 34,
                top: 34 + 8 * press,
                child: const Icon(LucideIcons.pointer, size: 44, color: T.foreground, shadows: [Shadow(color: Color(0xCC000000), blurRadius: 12)]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _SwipeHand extends StatelessWidget {
  final Animation<double> anim;
  final Offset center;
  const _SwipeHand({required this.anim, required this.center});
  @override
  Widget build(BuildContext context) => Positioned(
        left: center.dx - 28,
        top: center.dy - 60,
        width: 56,
        height: 160,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, _) {
              final t = Curves.easeInOut.transform(anim.value);
              return Stack(children: [
                Positioned(
                  left: 4,
                  top: 90 - 90 * t,
                  child: Opacity(
                    opacity: (1 - t) * 0.9 + 0.1,
                    child: const Icon(LucideIcons.pointer, size: 48, color: T.foreground, shadows: [Shadow(color: Color(0xCC000000), blurRadius: 12)]),
                  ),
                ),
              ]);
            },
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final MascotPose pose;
  final String text;
  final double progress;
  final String kind;
  final String? hint;
  final bool legendReady;
  final VoidCallback onNext;
  const _Bubble({super.key, required this.pose, required this.text, required this.progress, required this.kind, required this.hint, required this.legendReady, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(color: T.foreground, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 12))]),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // progress through the tour
        Container(
          height: 4,
          decoration: BoxDecoration(color: T.background.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: progress.clamp(0.05, 1.0), child: Container(decoration: BoxDecoration(color: T.primary, borderRadius: BorderRadius.circular(99)))),
        ),
        const SizedBox(height: 10),
        Text(text, style: txt(16, w: FontWeight.w800, c: T.background, h: 1.35)),
        if (kind == 'legend') ...[
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
          _Pill(label: 'Got it', enabled: legendReady, onTap: onNext, wide: true),
        ] else if (kind == 'finish') ...[
          const SizedBox(height: 12),
          _Pill(label: "Let's go!", enabled: true, onTap: onNext, wide: true),
        ] else if (kind == 'action') ...[
          if (hint != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(LucideIcons.pointer, size: 16, color: T.primaryDeep),
              const SizedBox(width: 6),
              Flexible(child: Text(hint!, style: txt(13, w: FontWeight.w900, c: T.primaryDeep))),
            ]),
          ],
        ] else ...[
          const SizedBox(height: 10),
          Row(children: [
            Text('Tap anywhere', style: txt(12, w: FontWeight.w700, c: T.faint)),
            const Spacer(),
            _Pill(label: 'Next', enabled: true, onTap: onNext),
          ]),
        ],
      ]),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: 0.9 + 0.1 * v, child: child)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Mascot(pose, size: 64),
        const SizedBox(width: 8),
        Expanded(child: body),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool enabled, wide;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.enabled, required this.onTap, this.wide = false});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: wide ? 44 : 36,
            width: wide ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: enabled ? T.primary : T.primaryDimFg.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(14)),
            child: Text(label, style: txt(15, w: FontWeight.w900, c: T.primaryFg)),
          ),
        ),
      );
}
