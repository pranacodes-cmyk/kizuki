import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logic/logic.dart';
import '../services/auth_links.dart';
import '../services/native_auth.dart';
import '../widgets/provider_icon.dart';
import '../services/analytics.dart';
import '../services/sync_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Save progress / sign in — mirrors src/routes/account.tsx. Sign-in is social only:
/// Google on Android, Google and Apple on iOS. Always uses the native account sheet;
/// failures stay here with a retry, never silently launch the browser.
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
  bool busy = false; // native sheet or restoring a legacy handed-back session
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
    });
    if (!await _backend()) return;
    if (!mounted) return;
    final method = signInMethod(provider);
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
        Analytics.track('sign_in_failed', {'category': 'native'});
        if (mounted) {
          setState(() {
            busy = false;
            error = friendlyAuthError(e);
          });
        }
      }
      return;
    }
    if (mounted) setState(() { busy = false; error = 'This sign-in method is not available on this device.'; });
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

  /// Provider tile: rounded icon chip + label + chevron (mirrors account.tsx).
  Widget _providerTile(String provider) => Semantics(
        button: true,
        label: 'Continue with ${_label(provider)}',
        child: Button3D(
          key: ValueKey('account-$provider'),
          onPressed: () => _oauth(provider),
          variant: BtnVariant.surface,
          height: 68,
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: T.surface3, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: ProviderIcon(provider),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text('Continue with ${_label(provider)}', style: txt(16, w: FontWeight.w800))),
            const Icon(Icons.chevron_right, color: T.faint),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final signin = widget.signInMode;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (!requiredAccount) Align(alignment: Alignment.centerLeft, child: TopBar(onBack: () => context.canPop() ? context.pop() : context.go('/'))),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Mascot on a soft orange glow, so the screen feels alive, not empty.
                  Align(
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [T.primary.withValues(alpha: 0.22), T.primary.withValues(alpha: 0)]),
                        ),
                      ),
                      const Mascot(MascotPose.wave, size: 104),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: signin ? 'Welcome ' : 'Save your '),
                      TextSpan(text: signin ? 'back' : 'progress', style: txt(24, w: FontWeight.w900, c: T.primary)),
                    ]),
                    textAlign: TextAlign.center,
                    style: txt(24, w: FontWeight.w900, h: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(signin ? 'Sign in to pick up where you left off.' : 'Keep your words, streak and reviews safe on every device.', textAlign: TextAlign.center, style: txt(15, w: FontWeight.w400, c: T.muted)),
                  const SizedBox(height: 28),
                  if (error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: T.dangerSoft, borderRadius: BorderRadius.circular(12)),
                      child: Text(error!, textAlign: TextAlign.center, style: txt(14, w: FontWeight.w700, c: T.danger)),
                    ),
                  if (busy)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                  else
                    for (final provider in signInProviders(_platform)) ...[
                      _providerTile(provider),
                      const SizedBox(height: 12),
                    ],
                  if (!busy)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(LucideIcons.shieldCheck, size: 16, color: T.faint),
                      const SizedBox(width: 6),
                      Text('One tap · no passwords · progress stays safe', style: txt(13, w: FontWeight.w700, c: T.faint)),
                    ]),
                ]),
              ),
            ),
          ),
          if (!busy && !requiredAccount)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextButton(onPressed: _later, child: Text(fromWelcome ? 'Back' : 'Maybe later', style: txt(14, w: FontWeight.w700, c: T.faint))),
            ),
        ]),
      ),
    );
  }
}
