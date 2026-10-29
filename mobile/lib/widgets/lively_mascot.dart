import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/haptics.dart';
import '../theme/mascot_motion.dart';
import '../theme/tokens.dart';
import 'ui.dart';
import '../i18n/i18n.dart';

/// Motion widgets — mirrored from LivelyMascot / Pop / FadeUp in src/components/mimi/Mascot.tsx.
/// Every frame comes from the shared math in theme/mascot_motion.dart.

/// True from launch until the splash starts to fade; entrances wait for it so they are seen.
class SplashGate {
  static final visible = ValueNotifier<bool>(false);
}

/// Kizuki the fox, alive: an idle loop (breathe / float / groove), an optional spring entrance,
/// a squash-and-stretch hop whenever [hopKey] changes or [hopAfterMs] passes, and a "boop"
/// hop with a light tap when [tappable]. Reduced motion shows the still fox.
class LivelyMascot extends StatefulWidget {
  final MascotPose pose;
  final double size;
  final MascotIdle idle;
  final bool entrance;
  final int entranceDelayMs;
  final Object? hopKey;
  final int? hopAfterMs;
  final bool tappable;
  final bool halo;
  const LivelyMascot(
    this.pose, {
    super.key,
    this.size = 96,
    this.idle = MascotIdle.breathe,
    this.entrance = false,
    this.entranceDelayMs = 0,
    this.hopKey,
    this.hopAfterMs,
    this.tappable = false,
    this.halo = false,
  });
  @override
  State<LivelyMascot> createState() => _LivelyMascotState();
}

class _LivelyMascotState extends State<LivelyMascot> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late final ValueNotifier<MascotFrame> _frame = ValueNotifier(widget.entrance ? const MascotFrame(opacity: 0) : MascotFrame.rest);
  double _base = 0; // idle clock carried over from before the ticker last stopped
  double _ms = 0; // ticker time since it last started
  bool _setUp = false;
  bool _reduced = false;
  late bool _enterWaiting = widget.entrance;
  bool _enterRequested = false;
  double? _enterAt;
  bool _hopRequested = false;
  double? _hopAt;
  double? _hopPlannedAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_setUp && reduced == _reduced) return;
    final first = !_setUp;
    _setUp = true;
    _reduced = reduced;
    if (reduced) {
      SplashGate.visible.removeListener(_maybeEnter);
      _ticker.stop();
      _enterWaiting = _enterRequested = _hopRequested = false;
      _enterAt = _hopAt = _hopPlannedAt = null;
      _frame.value = MascotFrame.rest;
      return;
    }
    if (first && _enterWaiting) {
      SplashGate.visible.addListener(_maybeEnter);
      _maybeEnter();
    } else if (first && widget.hopAfterMs != null) {
      _hopPlannedAt = widget.hopAfterMs!.toDouble();
    }
    _ensureTicking();
  }

  void _maybeEnter() {
    if (!_enterWaiting || SplashGate.visible.value) return;
    SplashGate.visible.removeListener(_maybeEnter);
    _enterWaiting = false;
    _enterRequested = true;
    _ensureTicking();
  }

  void _hop() {
    if (_reduced) return;
    _hopRequested = true;
    _ensureTicking();
  }

  void _ensureTicking() {
    if (_reduced || _ticker.isActive || !_busy) return;
    _ticker.start();
  }

  bool get _busy =>
      widget.idle != MascotIdle.none || _enterRequested || _enterAt != null || _hopRequested || _hopAt != null || _hopPlannedAt != null;

  void _onTick(Duration elapsed) {
    _ms = elapsed.inMicroseconds / 1000;
    if (_enterRequested) {
      _enterRequested = false;
      _enterAt = _ms + widget.entranceDelayMs;
      if (widget.hopAfterMs != null) _hopPlannedAt = _enterAt! + widget.hopAfterMs!;
    }
    if (_hopRequested) {
      _hopRequested = false;
      _hopAt = _ms;
    }
    if (_hopPlannedAt != null && _ms >= _hopPlannedAt!) {
      _hopAt = _hopPlannedAt;
      _hopPlannedAt = null;
    }
    var enter = 1.0;
    if (_enterWaiting) {
      enter = 0;
    } else if (_enterAt != null) {
      enter = ((_ms - _enterAt!) / enterMs).clamp(0.0, 1.0);
      if (enter >= 1) _enterAt = null;
    }
    double? hop;
    if (_hopAt != null) {
      hop = (_ms - _hopAt!) / hopMs;
      if (hop >= 1) {
        _hopAt = null;
        hop = null;
      }
    }
    _frame.value = mascotFrame(widget.idle, _base + _ms, enter, hop, widget.size);
    if (!_busy) {
      _ticker.stop();
      _base += _ms;
      _ms = 0;
    }
  }

  @override
  void didUpdateWidget(LivelyMascot old) {
    super.didUpdateWidget(old);
    if (widget.hopKey != old.hopKey) _hop();
    if (widget.idle != old.idle) _ensureTicking();
  }

  @override
  void dispose() {
    SplashGate.visible.removeListener(_maybeEnter);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final image = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), alignment: Alignment.bottomCenter, child: c),
      ),
      child: Mascot(widget.pose, key: ValueKey(widget.pose), size: s),
    );
    Widget body = SizedBox(
      width: s,
      height: s,
      child: ValueListenableBuilder<MascotFrame>(
        valueListenable: _frame,
        child: image,
        builder: (_, f, child) => Stack(clipBehavior: Clip.none, children: [
          if (widget.halo)
            Positioned(
              left: s * 0.08,
              right: s * 0.08,
              top: s * 0.08,
              bottom: s * 0.08,
              child: IgnorePointer(
                child: Opacity(
                  opacity: (f.halo * f.opacity).clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [T.primary.withValues(alpha: 0.3), T.primary.withValues(alpha: 0)], stops: const [0, 1]),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Opacity(
              opacity: f.opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, f.dy),
                child: Transform.rotate(
                  angle: f.rot,
                  alignment: Alignment.bottomCenter,
                  child: Transform(alignment: Alignment.bottomCenter, transform: Matrix4.diagonal3Values(f.sx, f.sy, 1), child: child),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
    if (widget.tappable) {
      body = Semantics(
        button: true,
        label: tr('Kizuki the fox'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.light();
            _hop();
          },
          child: body,
        ),
      );
    }
    return body;
  }
}

/// Pops its child (1 → 1.25 → 0.95 → 1) each time [active] turns on — answer cards' emoji.
class Pop extends StatefulWidget {
  final bool active;
  final Widget child;
  const Pop({super.key, required this.active, required this.child});
  @override
  State<Pop> createState() => _PopState();
}

class _PopState extends State<Pop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: popMs));
  @override
  void didUpdateWidget(Pop old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !MediaQuery.disableAnimationsOf(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => Transform.scale(scale: _c.isAnimating ? popScale(_c.value) : 1, child: child),
      );
}

/// Fades its child up into place after [delayMs] — once the splash has gone.
class FadeUp extends StatefulWidget {
  final int delayMs;
  final double dy;
  final Widget child;
  const FadeUp({super.key, this.delayMs = 0, this.dy = 10, required this.child});
  @override
  State<FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<FadeUp> with SingleTickerProviderStateMixin {
  static const _ms = 360;
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.delayMs + _ms));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Interval(widget.delayMs / (widget.delayMs + _ms), 1, curve: Curves.easeOutCubic));
  bool _setUp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_setUp) return;
    _setUp = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (SplashGate.visible.value) {
      SplashGate.visible.addListener(_go);
    } else {
      _c.forward();
    }
  }

  void _go() {
    if (SplashGate.visible.value) return;
    SplashGate.visible.removeListener(_go);
    _c.forward();
  }

  @override
  void dispose() {
    SplashGate.visible.removeListener(_go);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (_, child) => Opacity(opacity: _a.value, child: Transform.translate(offset: Offset(0, widget.dy * (1 - _a.value)), child: child)),
      );
}
