import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/haptics.dart';
import '../services/analytics.dart';
import '../theme/mascot_motion.dart';
import '../theme/tokens.dart';
import 'lively_mascot.dart';

/// Shared UI primitives — mirrored from src/components/mimi/ui.tsx.

enum MascotPose { wave, cheer, listen, brave, read, heart, think, face }

class Mascot extends StatelessWidget {
  final MascotPose pose;
  final double size;
  const Mascot(this.pose, {super.key, this.size = 96});
  @override
  Widget build(BuildContext context) => Image.asset('assets/mascot/mimi-${pose.name}.png', width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
}

TextStyle txt(double size, {FontWeight w = FontWeight.w700, Color c = T.foreground, double? h, String? family, double? ls}) =>
    TextStyle(fontSize: size, fontWeight: w, color: c, height: h, fontFamily: family, letterSpacing: ls, fontFamilyFallback: T.fallback);

TextStyle jp(double size, {FontWeight w = FontWeight.w700, Color c = T.foreground, double? h}) =>
    TextStyle(fontSize: size, fontWeight: w, color: c, height: h, fontFamily: T.jp, fontFamilyFallback: const [T.sans]);

/// Small caps section label ("YOUR FIRST CLIPS").
Widget caps(String s, {Color c = T.muted}) => Text(s.toUpperCase(), style: txt(11, w: FontWeight.w900, c: c, ls: 1.4));

/// Scroll area whose bottom edge fades out above a pinned footer, hinting there is more to
/// scroll on small phones — the web `scroll-fade` utility in src/styles.css.
class FadedScroll extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const FadedScroll({super.key, required this.child, this.padding = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Mask alpha only (opaque → transparent), not a visible colour.
          colors: const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          stops: [0, r.height <= 24 ? 0 : (r.height - 24) / r.height, 1],
        ).createShader(r),
        child: SingleChildScrollView(padding: padding, child: child),
      );
}

enum BtnVariant { primary, surface, ghost, danger, success }

/// 3D press button (orange with darker bottom edge) — Button in ui.tsx.
class Button3D extends StatefulWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onPressed;
  final BtnVariant variant;
  final double height;
  final bool expand;
  const Button3D({super.key, this.label, this.child, required this.onPressed, this.variant = BtnVariant.primary, this.height = 56, this.expand = true});
  @override
  State<Button3D> createState() => _Button3DState();
}

class _Button3DState extends State<Button3D> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final v = widget.variant;
    Color bg, fg, edge;
    switch (v) {
      case BtnVariant.primary:
        bg = enabled ? T.primary : T.primaryDim;
        fg = enabled ? T.primaryFg : T.primaryDimFg;
        edge = enabled ? T.primaryDeep : T.primaryDim;
      case BtnVariant.surface:
        bg = T.surface2;
        fg = T.foreground;
        edge = T.border;
      case BtnVariant.ghost:
        bg = Colors.transparent;
        fg = T.muted;
        edge = Colors.transparent;
      case BtnVariant.danger:
        bg = Colors.transparent;
        fg = T.danger;
        edge = Colors.transparent;
      case BtnVariant.success:
        bg = T.success;
        fg = T.primaryFg;
        edge = T.successDeep;
    }
    final has3d = v == BtnVariant.primary || v == BtnVariant.surface || v == BtnVariant.success;
    final depth = has3d ? (_down ? 1.0 : 4.0) : 0.0;
    final content = widget.child ?? Text(widget.label ?? '', style: txt(widget.height >= 56 ? 17 : 15, w: FontWeight.w800, c: fg));
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              Haptics.tap();
              Analytics.track('control_tapped', {'control_type': 'button', 'variant': widget.variant.name});
              widget.onPressed!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: widget.height,
        width: widget.expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: EdgeInsets.only(top: has3d ? 4 - depth : 0),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: v == BtnVariant.danger ? Border.all(color: T.danger.withValues(alpha: 0.7), width: 2) : null,
          boxShadow: has3d ? [BoxShadow(color: edge, offset: Offset(0, depth))] : null,
        ),
        alignment: Alignment.center,
        child: DefaultTextStyle(style: txt(17, w: FontWeight.w800, c: fg), child: IconTheme(data: IconThemeData(color: fg, size: 20), child: content)),
      ),
    );
  }
}

/// Plain tappable with a slight press scale (".press").
class Press extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Press({super.key, required this.child, this.onTap});
  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                setState(() => _down = false);
                Analytics.track('control_tapped', {'control_type': 'press'});
                widget.onTap!();
              },
        child: AnimatedScale(scale: _down ? 0.97 : 1, duration: const Duration(milliseconds: 90), child: widget.child),
      );
}

/// Onboarding header: back chevron + orange progress with Kizuki riding the end — he hops
/// forward (or back) each time the progress changes.
class ProgressHeader extends StatelessWidget {
  final double progress;
  final VoidCallback? onBack;
  const ProgressHeader({super.key, required this.progress, this.onBack});
  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.06, 1.0);
    return SizedBox(
      height: 48,
      child: Row(children: [
        const SizedBox(width: 6),
        Opacity(
          opacity: onBack == null ? 0 : 1,
          child: IconButton(onPressed: onBack, icon: const Icon(LucideIcons.chevronLeft, size: 28, color: T.muted)),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            return SizedBox(
              height: 36,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
                Container(height: 14, decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(99))),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  height: 14,
                  width: c.maxWidth * p,
                  decoration: BoxDecoration(color: T.primary, borderRadius: BorderRadius.circular(99)),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  left: c.maxWidth * p - 18,
                  child: LivelyMascot(MascotPose.face, size: 36, idle: MascotIdle.none, hopKey: progress),
                ),
              ]),
            );
          }),
        ),
        const SizedBox(width: 28),
      ]),
    );
  }
}

class TopBar extends StatelessWidget {
  final String? title;
  final VoidCallback? onBack;
  final Widget? right;
  const TopBar({super.key, this.title, this.onBack, this.right});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: Row(children: [
          const SizedBox(width: 4),
          if (onBack != null) IconButton(onPressed: onBack, icon: const Icon(LucideIcons.chevronLeft, size: 28)) else const SizedBox(width: 48),
          Expanded(child: Text(title ?? '', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(17, w: FontWeight.w800))),
          SizedBox(width: 48, child: right),
          const SizedBox(width: 4),
        ]),
      );
}

class MimiChip extends StatelessWidget {
  final Widget child;
  final bool active;
  final VoidCallback? onTap;
  const MimiChip({super.key, required this.child, this.active = false, this.onTap});
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? T.primary.withValues(alpha: 0.15) : T.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: active ? T.primary : T.border, width: 2),
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle(style: txt(14, w: FontWeight.w700, c: active ? T.primary : T.muted), child: child),
        ),
      );
}

class MimiToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const MimiToggle({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          Haptics.select();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: value ? T.success : T.surface3, borderRadius: BorderRadius.circular(99)),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: T.foreground, shape: BoxShape.circle)),
        ),
      );
}

enum PillTone { surface, success, primary }

class Pill extends StatelessWidget {
  final String text;
  final PillTone tone;
  const Pill(this.text, {super.key, this.tone = PillTone.surface});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.surface => (T.surface2, T.muted),
      PillTone.success => (T.successSoft, T.success),
      PillTone.primary => (T.primary.withValues(alpha: 0.15), T.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, textAlign: TextAlign.center, style: txt(14, w: FontWeight.w700, c: fg)),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? right;
  const SectionTitle(this.text, {super.key, this.right});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
        child: Row(children: [Expanded(child: Text(text, style: txt(17, w: FontWeight.w800))), ?right]),
      );
}

/// Bottom sheet styled like the web Sheet.
Future<R?> showMimiSheet<R>(BuildContext context, WidgetBuilder builder, {double maxHeightFactor = 0.86}) {
  return showModalBottomSheet<R>(
    context: context,
    // Above the tab bar, like the web Sheet (z-50 over the z-40 TabBar) — otherwise the
    // floating tab bar covers the bottom of every card and steals its taps.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: T.surface,
    barrierColor: T.stage.withValues(alpha: 0.7),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * maxHeightFactor),
    // useSafeArea only keeps the sheet below the status bar: keep its content (e.g. the word
    // card's Ask Kizuki button) above the phone's own navigation bar too.
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 10, bottom: 4), width: 40, height: 6, decoration: BoxDecoration(color: T.surface3, borderRadius: BorderRadius.circular(99))),
        Flexible(child: builder(ctx)),
      ]),
    ),
  );
}

/// Centered modal like the web Modal.
Future<R?> showMimiModal<R>(BuildContext context, WidgetBuilder builder, {bool dismissible = true}) {
  return showGeneralDialog<R>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: T.stage.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Material(
            color: T.surface,
            borderRadius: BorderRadius.circular(28),
            child: Padding(padding: const EdgeInsets.all(24), child: builder(ctx)),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
    ),
  );
}

/// Bouncing mascot loader.
class MascotLoader extends StatefulWidget {
  final String label;
  const MascotLoader({super.key, this.label = 'Loading…'});
  @override
  State<MascotLoader> createState() => _MascotLoaderState();
}

class _MascotLoaderState extends State<MascotLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) => Transform.translate(offset: Offset(0, -14 * Curves.easeInOut.transform(_c.value)), child: child),
            child: const Mascot(MascotPose.listen, size: 96),
          ),
          const SizedBox(height: 12),
          Text(widget.label, style: txt(15, c: T.muted)),
        ]),
      );
}

class ErrorState extends StatelessWidget {
  final String title;
  final String? body;
  final VoidCallback? onRetry;
  const ErrorState({super.key, this.title = 'Something went wrong', this.body, this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Mascot(MascotPose.think, size: 96),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: txt(18, w: FontWeight.w900)),
            if (body != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(body!, textAlign: TextAlign.center, style: txt(15, w: FontWeight.w400, c: T.muted))),
            if (onRetry != null) Padding(padding: const EdgeInsets.only(top: 16), child: Button3D(label: 'Try again', onPressed: onRetry, variant: BtnVariant.surface, height: 48, expand: false)),
          ]),
        ),
      );
}

/// Rounded surface card.
class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final BoxBorder? border;
  const Surface({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = T.surface, this.radius = 20, this.border});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), border: border),
        child: child,
      );
}
