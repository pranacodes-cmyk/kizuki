import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../logic/logic.dart';
import '../services/auth_links.dart';
import '../services/config.dart';
import '../services/native_auth.dart';
import '../services/onboarding_settings.dart';
import '../widgets/provider_icon.dart';
import '../services/analytics.dart';
import '../services/sync_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Save progress / sign in — mirrors src/routes/account.tsx. Sign-in is social only:
/// Google on Android, Google and Apple on iOS. A provider uses its native account sheet
/// once its remote switch is on; otherwise — and whenever native sign-in fails — the
/// published site signs in through the browser and hands the session back (kizuki://auth).
class AccountScreen extends StatefulWidget {
  final bool signInMode;
  const AccountScreen({super.key, this.signInMode = false});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

/// Same messages as friendly() in account.tsx.
String friendlyAuthError(Object err) {
  final msg = err is AuthException ? err.message : err.toString();
  final m = msg.toLowerCase();
  if (m.contains('socketexception') || m.contains('failed host lookup') || m.contains('clientexception') || m.contains('network')) {
    return "You're offline. Check your connection and try again.";
  }
  return msg.isEmpty ? 'Something went wrong. Please try again.' : msg;
}

String get _platform => defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

class _AccountScreenState extends State<AccountScreen> {
  bool busy = false; // native sheet or restoring the handed-back session
  bool waiting = false; // browser is open, the learner signs in there
  String? waitingProvider;
  String? error;

  bool get requiredAccount => context.read<AppState>().purchaseAccountPending;
  bool get fromWelcome => widget.signInMode && !requiredAccount && !context.read<AppState>().onboarded;

  @override
  void initState() {
    super.initState();
    // Already signed in when a purchase/restore lands here (mirrors account.tsx): the
    // verified account completes the purchase step without asking to sign in again.
    SyncService.I.addListener(_autoFinish);
    AuthLinks.I.start();
    AuthLinks.I.onSession = _onHandoff;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFinish();
      final handoff = AuthLinks.I.takePending();
      if (handoff != null) _onHandoff(handoff);
    });
  }

  @override
  void dispose() {
    SyncService.I.removeListener(_autoFinish);
    if (AuthLinks.I.onSession == _onHandoff) AuthLinks.I.onSession = null;
    super.dispose();
  }

  void _autoFinish() {
    if (!mounted || !requiredAccount || SyncService.I.session == null) return;
    _finish();
  }

  bool _finishing = false;

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    try {
      final app = context.read<AppState>();
      final welcome = fromWelcome;
      final user = (await Supabase.instance.client.auth.getUser()).user;
      if (user == null || !mounted) return;
      await SyncService.I.syncNow();
      if (!mounted) return;
      if (welcome && !app.onboarded) {
        // Signed in on a fresh device without cloud progress → still needs a plan.
        context.go('/onboarding');
        return;
      }
      app.confirmPurchaseAccount();
      if (!app.onboarded) app.completeOnboarding();
      context.go('/feed');
    } catch (e) {
      Analytics.track('sign_in_failed', {'category': 'account_completion'});
      if (mounted) setState(() => error = friendlyAuthError(e));
    } finally {
      _finishing = false;
      if (mounted) setState(() => busy = false);
    }
  }

  /// Session came back from the browser (kizuki://auth hand-off).
  Future<void> _onHandoff(String sessionJson) async {
    if (!mounted) return;
    setState(() {
      waiting = false;
      waitingProvider = null;
      busy = true;
      error = null;
    });
    try {
      await SyncService.I.installHandoff(sessionJson);
      if (mounted) await _finish();
    } catch (e) {
      Analytics.track('sign_in_failed', {'category': 'browser_handoff'});
      if (mounted) {
        setState(() {
          error = friendlyAuthError(e);
          busy = false;
        });
      }
    }
  }

  /// Waits (briefly) for the background backend connection; shows the offline message
  /// instead of hanging when it can't start.
  Future<bool> _backend() async {
    final ok = await SyncService.I.ensureBackend().timeout(const Duration(seconds: 12), onTimeout: () => false);
    if (!ok && mounted) {
      setState(() {
        waiting = false;
        busy = false;
        error = "You're offline. Check your connection and try again.";
      });
    }
    return ok;
  }

  Future<void> _oauth(String provider) async {
    Analytics.track('sign_in_started', {'provider': provider});
    FocusScope.of(context).unfocus();
    setState(() {
      error = null;
      busy = true;
      waiting = false;
    });
    if (!await _backend()) return;
    // Fresh switch values; offline keeps the last valid ones.
    await OnboardingSettings.refresh().timeout(const Duration(seconds: 3), onTimeout: () {});
    if (!mounted) return;
    final method = signInMethod(provider, nativeGoogle: OnboardingSettings.nativeGoogle, nativeApple: OnboardingSettings.nativeApple);
    if (method == 'native') {
      try {
        await NativeAuth.signIn(provider);
        SyncService.I.setSession(Supabase.instance.client.auth.currentSession);
        if (mounted) await _finish();
        return;
      } catch (e) {
        if (NativeAuth.isCancel(e)) {
          if (mounted) setState(() => busy = false);
          return;
        }
        // Any other native failure (provider setup, backend rejected the token): the
        // browser hand-off still signs the learner in, so they are never stuck here.
        debugPrint('KIZUKI_WARN native sign-in failed, using browser: $e');
        Analytics.track('sign_in_failed', {'category': 'native_fallback'});
      }
    }
    if (mounted) await _browser(provider);
  }

  Future<void> _browser(String provider) async {
    setState(() {
      busy = false;
      waiting = true;
      waitingProvider = provider;
      error = null;
    });
    final url = Uri.parse('${AppConfig.webOrigin}/account?bridge=1&provider=$provider&platform=$_platform');
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        setState(() {
          waiting = false;
          error = "Couldn't open the browser. Please try again.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          waiting = false;
          error = friendlyAuthError(e);
        });
      }
    }
  }

  void _later() {
    if (requiredAccount) return;
    if (fromWelcome) {
      context.go('/');
      return;
    }
    context.read<AppState>().completeOnboarding();
    context.go('/feed');
  }

  String _label(String provider) => provider == 'google' ? 'Google' : 'Apple';

  @override
  Widget build(BuildContext context) {
    final signin = widget.signInMode;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(slivers: [
          if (!requiredAccount) SliverToBoxAdapter(child: TopBar(onBack: () => context.canPop() ? context.pop() : context.go('/'))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                Mascot(MascotPose.wave, size: 96),
                const SizedBox(height: 8),
                Text(signin ? 'Welcome back' : 'Save your progress', textAlign: TextAlign.center, style: txt(24, w: FontWeight.w900, h: 1.2)),
                const SizedBox(height: 6),
                Text(signin ? 'Sign in to pick up where you left off.' : 'Keep your words, streak and reviews safe on every device.', textAlign: TextAlign.center, style: txt(15, w: FontWeight.w400, c: T.muted)),
                const SizedBox(height: 24),
                if (error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: T.dangerSoft, borderRadius: BorderRadius.circular(12)),
                    child: Text(error!, textAlign: TextAlign.center, style: txt(14, w: FontWeight.w700, c: T.danger)),
                  ),
                if (waiting) ...[
                  Text('Finish signing in with ${_label(waitingProvider ?? 'google')} in your browser — Kizuki opens again as soon as you\u2019re done.',
                      key: const ValueKey('account-waiting'), textAlign: TextAlign.center, style: txt(15, w: FontWeight.w700, c: T.muted, h: 1.4)),
                  const SizedBox(height: 16),
                  Button3D(label: 'Open browser again', onPressed: waitingProvider == null ? null : () => _browser(waitingProvider!), variant: BtnVariant.surface),
                  const SizedBox(height: 8),
                  Button3D(
                    label: 'Cancel',
                    onPressed: () => setState(() {
                      waiting = false;
                      waitingProvider = null;
                    }),
                    variant: BtnVariant.ghost,
                    height: 48,
                  ),
                ] else if (busy) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ] else ...[
                  for (final provider in signInProviders(_platform)) ...[
                    Semantics(button: true, label: 'Continue with ${_label(provider)}', child: Button3D(
                      key: ValueKey('account-$provider'),
                      onPressed: () => _oauth(provider), variant: BtnVariant.surface,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        ProviderIcon(provider), const SizedBox(width: 12),
                        Text('Continue with ${_label(provider)}', style: txt(17, w: FontWeight.w800)),
                      ]),
                    )),
                    const SizedBox(height: 12),
                  ],
                ],
              ]),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (!busy && !waiting) ...[
                if (!requiredAccount) TextButton(onPressed: _later, child: Text(fromWelcome ? 'Back' : 'Maybe later', style: txt(14, w: FontWeight.w700, c: T.faint))),
                const SizedBox(height: 8),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
