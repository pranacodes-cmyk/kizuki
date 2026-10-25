import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/paywall.dart';
import '../services/attribution.dart';
import '../services/analytics.dart';
import '../services/billing.dart';
import '../services/haptics.dart';
import '../services/notification_service.dart';
import '../services/onboarding_settings.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/feed_preview.dart';
import '../widgets/lively_mascot.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';

/// 3-step free-trial pitch — mirrors src/routes/trial.tsx. Purchases go through RevenueCat
/// (services/billing.dart); test builds simulate the store.
class TrialScreen extends StatefulWidget {
  const TrialScreen({super.key});
  @override
  State<TrialScreen> createState() => _TrialScreenState();
}

class _TrialScreenState extends State<TrialScreen> {
  int step = 0;
  String plan = 'yearly';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (context.read<AppState>().onboarded) step = 2;
    Analytics.track('paywall_viewed', {'step_index': step});
    // Pick up a server trial experiment that changed since startup.
    unawaited(OnboardingSettings.refresh().then((_) {
      if (mounted) setState(() {});
    }));
  }

  /// Store-verified purchase: the account step is required even if this screen was
  /// left while the store sheet was still open (the gate never depends on `mounted`).
  void _purchased(AppState app) => app.requirePurchaseAccount();

  Future<void> _start() async {
    final app = context.read<AppState>();
    setState(() => busy = true);
    final price = Billing.priceOf(plan);
    Attribution.checkoutStarted(plan: plan, price: price?.$1, currency: price?.$2);
    StoreResult r;
    try {
      r = await Billing.buy(plan);
    } catch (e) {
      debugPrint('KIZUKI_ERROR purchase: $e');
      if (mounted) setState(() => busy = false);
      toast('Purchase didn\'t go through', description: 'Nothing was charged. Please try again.', tone: ToastTone.error);
      return;
    }
    if (r == StoreResult.done) _purchased(app);
    if (!mounted) return;
    if (r == StoreResult.cancelled) return setState(() => busy = false); // closed the store sheet
    if (r == StoreResult.none) {
      setState(() => busy = false);
      toast('Purchase is pending', description: 'The store is still confirming it. Premium unlocks as soon as it does.');
      return;
    }
    if (r == StoreResult.unavailable) {
      if (!Billing.simulate && !kDebugMode) {
        setState(() => busy = false);
        toast('Store not available', description: 'Check your connection and store account, then try again.', tone: ToastTone.error);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 900)); // test builds: store stand-in
      app.startTrial(plan);
      _purchased(app);
      if (!mounted) return;
    }
    setState(() => busy = false);
    Haptics.celebrate();
    final trial = app.premium.trialEndsAt != null;
    toast(purchaseToast(trial ? OnboardingSettings.trialDayCount : 0), description: 'Everything in Kizuki is unlocked.', icon: '🎉');
    if (trial) unawaited(NotificationService.requestPermission());
    context.go('/account?mode=signin');
  }

  Future<void> _restore() async {
    final app = context.read<AppState>();
    setState(() => busy = true);
    final r = await Billing.restore();
    if (r == StoreResult.done) _purchased(app);
    if (!mounted) return;
    setState(() => busy = false);
    if (r == StoreResult.unavailable) {
      return toast('Couldn\'t reach the store', description: 'Check your connection and try again.', tone: ToastTone.error);
    }
    if (r != StoreResult.done) return toast('No subscription found', description: 'Use the same store account you bought with.');
    Haptics.success();
    toast('Purchase restored', icon: '🎉');
    context.go('/account?mode=signin');
  }

  void _skip() {
    Analytics.track('paywall_skipped');
    if (busy) return;
    final app = context.read<AppState>();
    if (app.onboarded) {
      context.pop();
    } else {
      context.push('/account');
    }
  }

  /// Trial days after the store's eligibility and the server experiment: 0 = direct paywall.
  static int get _days => Billing.trialEligible ? OnboardingSettings.trialDayCount : 0;

  void _back() {
    if (busy) return; // the store sheet is open; leaving now would lose its result
    if (step == 2 && _days == 0) {
      setState(() => step = 0);
    } else if (step > 0) {
      setState(() => step--);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        // Live store prices / trial eligibility can arrive while this screen is open.
        valueListenable: Billing.revision,
        builder: (context, _, _) {
          final days = _days;
          final trial = days > 0;
          final Widget body = switch (step) {
            0 => _StepTry(
                days: days,
                onNext: () {
                  if (!trial) Attribution.paywallViewed();
                  setState(() => step = trial ? 1 : 2);
                  Analytics.track('paywall_step_viewed', {'step_index': step});
                }),
            1 => _StepRemind(days: days, onNext: () {
                Attribution.paywallViewed();
                setState(() => step = 2);
                Analytics.track('paywall_step_viewed', {'step_index': step});
              }),
            _ => _StepPlans(plan: plan, setPlan: (p) { setState(() => plan = p); Analytics.track('plan_selected', {'plan': p}); }, busy: busy, onStart: _start, onSkip: _skip, onRestore: _restore),
          };
          return PopScope(
            canPop: step == 0 && !busy,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _back();
            },
            child: Scaffold(
              body: SafeArea(
                child: Column(children: [
                  ProgressHeader(progress: (9 + step) / 12, onBack: _back),
                  Expanded(
                    // Dispose the preview immediately. Keeping a live platform video in an
                    // outgoing slide can retain its surface/decoder during the next screen.
                    child: KeyedSubtree(key: ValueKey(step), child: body),
                  ),
                ]),
              ),
            ),
          );
        },
      );
}

/// Scrolling step content above a pinned footer: the main button, price and legal links
/// stay on screen on small phones and with large system text.
Widget _pinned({required List<Widget> body, required List<Widget> footer, CrossAxisAlignment align = CrossAxisAlignment.center}) => Column(children: [
      Expanded(
        child: FadedScroll(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: SizedBox(width: double.infinity, child: Column(crossAxisAlignment: align, children: body)),
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 8), child: Column(mainAxisSize: MainAxisSize.min, children: footer)),
    ]);

Widget _noPayment([String text = 'No payment due now']) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(LucideIcons.check, size: 20, color: T.success),
      const SizedBox(width: 8),
      Flexible(child: Text(text, textAlign: TextAlign.center, style: txt(15, w: FontWeight.w800))),
    ]);

class _StepTry extends StatelessWidget {
  /// 0 for store accounts that already used the free week or a server direct-paywall
  /// experiment: no free-trial promises.
  final int days;
  final VoidCallback onNext;
  const _StepTry({required this.days, required this.onNext});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          const SizedBox(height: 16),
          Text.rich(
            days > 0
                ? TextSpan(children: [const TextSpan(text: 'Try Kizuki '), TextSpan(text: 'free', style: txt(26, w: FontWeight.w900, c: T.primary)), TextSpan(text: ' for $days days')])
                : TextSpan(children: [const TextSpan(text: 'Learn with Kizuki '), TextSpan(text: 'Premium', style: txt(26, w: FontWeight.w900, c: T.primary))]),
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
                      child: context.watch<AppState>().onboarded
                          ? Center(child: Text('Renew Premium to keep learning', textAlign: TextAlign.center, style: txt(18, w: FontWeight.w800)))
                          : const FeedPreview(),
                    ),
                  ),
                  const Positioned(right: -56, bottom: -12, child: LivelyMascot(MascotPose.cheer, size: 96, tappable: true)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _noPayment(days > 0 ? 'No payment due now' : 'Cancel anytime'),
          const SizedBox(height: 12),
          Button3D(label: days > 0 ? r'Try for $0.00' : 'See plans', onPressed: onNext),
          const SizedBox(height: 12),
          Text(priceLine(plans['yearly']!, days: days), textAlign: TextAlign.center, style: txt(13, w: FontWeight.w400, c: T.muted)),
          const SizedBox(height: 8),
        ]),
      );
}

class _StepRemind extends StatefulWidget {
  final int days;
  final VoidCallback onNext;
  const _StepRemind({required this.days, required this.onNext});
  @override
  State<_StepRemind> createState() => _StepRemindState();
}

class _StepRemindState extends State<_StepRemind> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  Timer? _delay;
  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _ring.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const icons = [LucideIcons.lock, LucideIcons.bell, LucideIcons.crown];
    final items = trialTimeline(widget.days);
    return _pinned(
      body: [
        const SizedBox(height: 16),
        Text("We'll remind you before your trial ends", textAlign: TextAlign.center, style: txt(26, w: FontWeight.w900, h: 1.2)),
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: _ring,
          builder: (_, child) {
            final v = MediaQuery.disableAnimationsOf(context) ? 1.0 : _ring.value;
            final angle = v == 0 || v == 1 ? 0.0 : math.sin(v * math.pi * 5) * (1 - v) * 0.09;
            return Transform.rotate(angle: angle, child: child);
          },
          child: Stack(clipBehavior: Clip.none, children: [
            const Icon(LucideIcons.bell, size: 88, color: T.gold),
            Positioned(
              right: -4,
              top: 4,
              child: Container(width: 32, height: 32, alignment: Alignment.center, decoration: const BoxDecoration(color: T.danger, shape: BoxShape.circle), child: Text('1', style: txt(15, w: FontWeight.w900))),
            ),
          ]),
        ),
        const SizedBox(height: 32),
        for (var i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: i == 0 ? T.primary : T.surface2, shape: BoxShape.circle),
                  child: Icon(icons[i], size: 20, color: i == 0 ? T.primaryFg : T.foreground),
                ),
                if (i < items.length - 1) Expanded(child: Container(margin: const EdgeInsets.symmetric(vertical: 4), width: 4, decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(99)))),
              ]),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: i < items.length - 1 ? 24 : 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(items[i].$1, style: txt(16, w: FontWeight.w800)),
                    Text(items[i].$2, style: txt(14, w: FontWeight.w400, c: T.muted)),
                  ]),
                ),
              ),
            ]),
          ),
      ],
      footer: [
        _noPayment(),
        const SizedBox(height: 12),
        Button3D(label: 'Continue for free', onPressed: widget.onNext),
      ],
    );
  }
}

class _StepPlans extends StatelessWidget {
  final String plan;
  final ValueChanged<String> setPlan;
  final bool busy;
  final VoidCallback onStart, onSkip, onRestore;
  const _StepPlans({required this.plan, required this.setPlan, required this.busy, required this.onStart, required this.onSkip, required this.onRestore});
  static const perks = ['Unlimited clips, every level', 'Tap any word for an explanation in context', 'Unlimited questions to Kizuki, your AI tutor', 'Smart reviews with the original audio', 'Hiragana & katakana trainer', 'Streaks, goals and progress stats'];
  @override
  Widget build(BuildContext context) {
    final days = plan == 'yearly' && Billing.trialEligible ? OnboardingSettings.trialDayCount : 0;
    final trial = days > 0;
    final link = txt(12, w: FontWeight.w400, c: T.faint).copyWith(decoration: TextDecoration.underline, decorationColor: T.faint);
    final small = TextButton.styleFrom(minimumSize: const Size(44, 40), padding: const EdgeInsets.symmetric(horizontal: 10), tapTargetSize: MaterialTapTargetSize.shrinkWrap);
    return _pinned(
      align: CrossAxisAlignment.start,
      body: [
        const SizedBox(height: 8),
        Row(children: [
          const LivelyMascot(MascotPose.heart, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [const TextSpan(text: 'Unlock everything in '), TextSpan(text: 'Kizuki', style: txt(24, w: FontWeight.w900, c: T.primary))]),
              style: txt(24, w: FontWeight.w900, h: 1.2),
            ),
          ),
        ]),
        // Plans come first so the price is always visible on small phones; perks scroll below.
        const SizedBox(height: 6),
        for (final id in ['yearly', 'monthly'])
          Padding(padding: const EdgeInsets.only(top: 14), child: _PlanCard(p: plans[id]!, active: plan == id, onTap: () {
            if (plan != id) Haptics.select();
            setPlan(id);
          })),
        const SizedBox(height: 20),
        caps('Everything in Premium'),
        const SizedBox(height: 10),
        for (final p in perks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [const Icon(LucideIcons.sparkles, size: 16, color: T.gold), const SizedBox(width: 10), Expanded(child: Text(p, style: txt(15, w: FontWeight.w700)))]),
          ),
      ],
      footer: [
        _noPayment(trialBadge(days)),
        const SizedBox(height: 8),
        Button3D(label: busy ? 'Starting…' : trialCta(days), onPressed: busy ? null : onStart),
        const SizedBox(height: 8),
        Text('${priceLine(plans[plan]!, days: days)}. Renews automatically, cancel anytime in your store settings.', textAlign: TextAlign.center, style: txt(12, w: FontWeight.w400, c: T.faint)),
        // Wrap, not Row: with large system text sizes these lines must flow, never overflow.
        SizedBox(
          width: double.infinity,
          child: Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
            TextButton(style: small, onPressed: busy ? null : onRestore, child: Text('Restore purchase', style: txt(13, w: FontWeight.w700, c: T.muted))),
            TextButton(style: small, onPressed: busy ? null : onSkip, child: Text('Not now', style: txt(13, w: FontWeight.w700, c: T.muted))),
          ]),
        ),
        // Store rules: subscription screens link the Terms of Use and Privacy Policy.
        SizedBox(
          width: double.infinity,
          child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
            GestureDetector(onTap: () => context.push('/terms'), child: Text('Terms of Use', style: link)),
            Text('  ·  ', style: txt(12, w: FontWeight.w400, c: T.faint)),
            GestureDetector(onTap: () => context.push('/privacy'), child: Text('Privacy Policy', style: link)),
          ]),
        ),
      ],
    );
  }
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
