import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/paywall.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';

/// 3-step free-trial pitch — mirrors src/routes/trial.tsx. Purchases are simulated until
/// Play Billing products exist.
class TrialScreen extends StatefulWidget {
  const TrialScreen({super.key});
  @override
  State<TrialScreen> createState() => _TrialScreenState();
}

class _TrialScreenState extends State<TrialScreen> {
  int step = 0;
  String plan = 'yearly';
  bool busy = false;

  Future<void> _start() async {
    setState(() => busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 900)); // store sheet stand-in
    if (!mounted) return;
    final app = context.read<AppState>();
    app.startTrial(plan);
    setState(() => busy = false);
    toast('Your free week has started', description: 'Everything in Kizuki is unlocked.', icon: '🎉');
    context.go(app.onboarded ? '/feed' : '/account');
  }

  void _skip() {
    final app = context.read<AppState>();
    if (app.onboarded) {
      context.pop();
    } else {
      context.push('/account');
    }
  }

  void _back() {
    if (step > 0) {
      setState(() => step--);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (step) {
      0 => _StepTry(onNext: () => setState(() => step = 1)),
      1 => _StepRemind(onNext: () => setState(() => step = 2)),
      _ => _StepPlans(plan: plan, setPlan: (p) => setState(() => plan = p), busy: busy, onStart: _start, onSkip: _skip),
    };
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            ProgressHeader(progress: (10 + step) / 13, onBack: _back),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(a), child: c)),
                child: KeyedSubtree(key: ValueKey(step), child: body),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

Widget _noPayment([String text = 'No payment due now']) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(LucideIcons.check, size: 20, color: T.success),
      const SizedBox(width: 8),
      Text(text, style: txt(15, w: FontWeight.w800)),
    ]);

class _StepTry extends StatelessWidget {
  final VoidCallback onNext;
  const _StepTry({required this.onNext});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(children: [const TextSpan(text: 'Try Kizuki '), TextSpan(text: 'free', style: txt(26, w: FontWeight.w900, c: T.primary)), const TextSpan(text: ' for 7 days')]),
            textAlign: TextAlign.center,
            style: txt(26, w: FontWeight.w900, h: 1.2),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 230,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: T.stage, borderRadius: BorderRadius.circular(32), border: Border.all(color: T.surface3, width: 6)),
                      clipBehavior: Clip.antiAlias,
                      child: LayoutBuilder(
                        builder: (_, c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            height: c.maxHeight * 0.44,
                            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [T.primaryDim, T.surface2])),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text.rich(
                                TextSpan(children: [
                                  TextSpan(text: '今日', style: jp(16, c: T.primary).copyWith(backgroundColor: T.primary.withValues(alpha: 0.25))),
                                  const TextSpan(text: 'は'),
                                  TextSpan(text: '楽しかった', style: jp(16).copyWith(decoration: TextDecoration.underline, decorationColor: T.learning, decorationThickness: 2)),
                                  const TextSpan(text: 'ね！'),
                                ]),
                                style: jp(16, h: 1.3),
                              ),
                              const SizedBox(height: 6),
                              Text("Today was fun, wasn't it!", style: txt(12, w: FontWeight.w400, c: T.muted)),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(16)),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text.rich(TextSpan(children: [TextSpan(text: '今日 ', style: jp(20, w: FontWeight.w900)), TextSpan(text: 'きょう', style: jp(12, c: T.muted))])),
                                  Text('today', style: txt(13, w: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('Said at the end of a happy day out with friends.', style: txt(11, w: FontWeight.w400, c: T.muted)),
                                ]),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const Positioned(right: -56, bottom: -12, child: Mascot(MascotPose.cheer, size: 96)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _noPayment(),
          const SizedBox(height: 12),
          Button3D(label: r'Try for $0.00', onPressed: onNext),
          const SizedBox(height: 12),
          Text(priceLine(plans['yearly']!), textAlign: TextAlign.center, style: txt(13, w: FontWeight.w400, c: T.muted)),
          const SizedBox(height: 8),
        ]),
      );
}

class _StepRemind extends StatefulWidget {
  final VoidCallback onNext;
  const _StepRemind({required this.onNext});
  @override
  State<_StepRemind> createState() => _StepRemindState();
}

class _StepRemindState extends State<_StepRemind> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) _ring.forward();
    });
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const icons = [LucideIcons.lock, LucideIcons.bell, LucideIcons.crown];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        const SizedBox(height: 16),
        Text("We'll remind you before your trial ends", textAlign: TextAlign.center, style: txt(26, w: FontWeight.w900, h: 1.2)),
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: _ring,
          builder: (_, child) {
            final v = _ring.value;
            final angle = v == 0 || v == 1 ? 0.0 : math.sin(v * math.pi * 5) * (1 - v) * 0.21;
            return Transform.rotate(angle: angle, child: child);
          },
          child: Stack(clipBehavior: Clip.none, children: [
            const Icon(LucideIcons.bell, size: 96, color: T.gold),
            Positioned(
              right: -4,
              top: 4,
              child: Container(width: 32, height: 32, alignment: Alignment.center, decoration: const BoxDecoration(color: T.danger, shape: BoxShape.circle), child: Text('1', style: txt(15, w: FontWeight.w900))),
            ),
          ]),
        ),
        const SizedBox(height: 40),
        for (var i = 0; i < trialTimeline.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: i == 0 ? T.primary : T.surface2, shape: BoxShape.circle),
                  child: Icon(icons[i], size: 20, color: i == 0 ? T.primaryFg : T.foreground),
                ),
                if (i < trialTimeline.length - 1) Expanded(child: Container(margin: const EdgeInsets.symmetric(vertical: 4), width: 4, decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(99)))),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(trialTimeline[i].$1, style: txt(16, w: FontWeight.w800)),
                    Text(trialTimeline[i].$2, style: txt(14, w: FontWeight.w400, c: T.muted)),
                  ]),
                ),
              ),
            ]),
          ),
        const Spacer(),
        _noPayment(),
        const SizedBox(height: 12),
        Button3D(label: 'Continue for free', onPressed: widget.onNext),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _StepPlans extends StatelessWidget {
  final String plan;
  final ValueChanged<String> setPlan;
  final bool busy;
  final VoidCallback onStart, onSkip;
  const _StepPlans({required this.plan, required this.setPlan, required this.busy, required this.onStart, required this.onSkip});
  static const perks = ['Unlimited clips, every level', 'Tap any word for an explanation in context', 'Unlimited questions to Kizuki, your AI tutor', 'Smart reviews with the original audio', 'Hiragana & katakana trainer', 'Streaks, goals and progress stats'];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                Row(children: [
                  const Mascot(MascotPose.heart, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [const TextSpan(text: 'Unlock everything in '), TextSpan(text: 'Kizuki', style: txt(24, w: FontWeight.w900, c: T.primary))]),
                      style: txt(24, w: FontWeight.w900, h: 1.2),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                for (final p in perks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [const Icon(LucideIcons.sparkles, size: 16, color: T.gold), const SizedBox(width: 10), Expanded(child: Text(p, style: txt(15, w: FontWeight.w700)))]),
                  ),
                const SizedBox(height: 12),
                for (final id in ['yearly', 'monthly'])
                  Padding(padding: const EdgeInsets.only(top: 12), child: _PlanCard(p: plans[id]!, active: plan == id, onTap: () => setPlan(id))),
                const Spacer(),
                const SizedBox(height: 20),
                _noPayment('7 days free · Cancel anytime'),
                const SizedBox(height: 8),
                Button3D(label: busy ? 'Starting…' : 'Start my free week', onPressed: busy ? null : onStart),
                const SizedBox(height: 8),
                Center(child: Text('${priceLine(plans[plan]!)}. Purchases are simulated in this preview.', textAlign: TextAlign.center, style: txt(12, w: FontWeight.w400, c: T.faint))),
                Center(child: TextButton(onPressed: onSkip, child: Text('Not now', style: txt(13, w: FontWeight.w700, c: T.muted)))),
              ]),
            ),
          ),
        ),
      );
}

class _PlanCard extends StatelessWidget {
  final Plan p;
  final bool active;
  final VoidCallback onTap;
  const _PlanCard({required this.p, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        selected: active,
        button: true,
        child: Press(
          onTap: onTap,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: active ? T.primary.withValues(alpha: 0.1) : T.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: active ? T.primary : T.border, width: 2),
              ),
              child: Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: active ? T.primary : null, border: Border.all(color: active ? T.primary : T.surface3, width: 2)),
                  child: active ? const Icon(LucideIcons.check, size: 16, color: T.primaryFg) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.label, style: txt(16, w: FontWeight.w800)),
                    Text(p.sub, style: txt(13, w: FontWeight.w400, c: T.muted)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(p.perMonth, style: txt(16, w: FontWeight.w900)),
                  Text('per month', style: txt(11, w: FontWeight.w700, c: T.muted)),
                ]),
              ]),
            ),
            if (p.badge != null)
              Positioned(
                right: 16,
                top: -12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: T.primary, borderRadius: BorderRadius.circular(99)),
                  child: Text(p.badge!.toUpperCase(), style: txt(11, w: FontWeight.w900, c: T.primaryFg, ls: 1)),
                ),
              ),
          ]),
        ),
      );
}
