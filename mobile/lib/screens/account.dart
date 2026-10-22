import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/config.dart';
import '../services/sync_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';
import 'onboarding.dart' show MimiField;

/// Save progress / sign in — mirrors src/routes/account.tsx. Android uses email + password
/// (the web preview also offers Google and Lovable sign-in through the web-only broker).
class AccountScreen extends StatefulWidget {
  final bool signInMode;
  const AccountScreen({super.key, this.signInMode = false});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Same messages as friendly() in account.tsx.
String friendlyAuthError(Object err) {
  final msg = err is AuthException ? err.message : err.toString();
  final m = msg.toLowerCase();
  if (m.contains('invalid login')) return "That email and password don't match.";
  if (m.contains('already registered') || m.contains('already exists')) return 'That email already has an account — try signing in.';
  if (m.contains('email not confirmed')) return 'Please confirm your email first — check your inbox.';
  if (m.contains('pwned') || m.contains('leaked') || m.contains('weak')) return 'That password is too common. Please pick another.';
  if (m.contains('socketexception') || m.contains('failed host lookup') || m.contains('clientexception')) return "You're offline. Check your connection and try again.";
  return msg.isEmpty ? 'Something went wrong. Please try again.' : msg;
}

class _AccountScreenState extends State<AccountScreen> {
  late String mode = widget.signInMode ? 'signin' : 'signup';
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool show = false, busy = false;
  String? error;
  String? sent; // confirm | reset

  bool get fromWelcome => widget.signInMode && !context.read<AppState>().onboarded;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final app = context.read<AppState>();
    final welcome = fromWelcome;
    await SyncService.I.syncNow();
    if (!mounted) return;
    if (welcome && !app.onboarded) {
      // Signed in on a fresh device without cloud progress → still needs a plan.
      context.go('/onboarding');
      return;
    }
    if (!app.onboarded) app.completeOnboarding();
    context.go('/feed');
  }

  String? _validate() {
    final em = _email.text.trim();
    if (em.isEmpty || em.length > 255 || !_emailRe.hasMatch(em)) return 'Enter a valid email';
    final pw = _password.text;
    if (pw.length < 8) return 'Use at least 8 characters';
    if (pw.length > 72) return 'Use at most 72 characters';
    return null;
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => error = _validate());
    if (error != null) return;
    setState(() => busy = true);
    final name = context.read<AppState>().profile.name;
    if (!await _backend()) return;
    final auth = Supabase.instance.client.auth;
    try {
      if (mode == 'signup') {
        final res = await auth.signUp(email: _email.text.trim(), password: _password.text, emailRedirectTo: AppConfig.webOrigin, data: name.isEmpty ? null : {'name': name});
        if (res.session == null) {
          if (mounted) setState(() => sent = 'confirm');
          return;
        }
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
        toast('Welcome back!', icon: '👋');
      }
      SyncService.I.session = auth.currentSession;
      if (!mounted) return;
      await _finish();
    } catch (e) {
      if (mounted) setState(() => error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _forgot() async {
    final em = _email.text.trim();
    if (!_emailRe.hasMatch(em)) {
      setState(() => error = 'Enter your email first, then tap “Forgot password”.');
      return;
    }
    setState(() => busy = true);
    if (!await _backend()) return;
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(em, redirectTo: '${AppConfig.webOrigin}/reset-password');
      if (mounted) setState(() => sent = 'reset');
    } catch (e) {
      if (mounted) setState(() => error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _later() {
    if (fromWelcome) {
      context.go('/');
      return;
    }
    context.read<AppState>().completeOnboarding();
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    if (sent != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(LucideIcons.mailCheck, size: 64, color: T.primary),
                  const SizedBox(height: 20),
                  Text('Check your inbox', style: txt(24, w: FontWeight.w900)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 300,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: sent == 'confirm' ? 'We sent a confirmation link to ' : 'We sent a password reset link to '),
                        TextSpan(text: _email.text.trim(), style: txt(15, w: FontWeight.w800)),
                        TextSpan(text: sent == 'confirm' ? '. Open it to finish creating your account — your progress is saved on this phone meanwhile.' : '.'),
                      ]),
                      textAlign: TextAlign.center,
                      style: txt(15, w: FontWeight.w400, c: T.muted),
                    ),
                  ),
                ]),
              ),
              sent == 'confirm'
                  ? Button3D(label: 'Continue to Kizuki', onPressed: _later)
                  : Button3D(label: 'Back to sign in', onPressed: () => setState(() {
                        sent = null;
                        mode = 'signin';
                      })),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      );
    }
    final signup = mode == 'signup';
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: TopBar(onBack: () => context.canPop() ? context.pop() : context.go('/'))),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  Mascot(signup ? MascotPose.heart : MascotPose.wave, size: 96),
                  const SizedBox(height: 8),
                  Text(signup ? 'Save your progress' : 'Welcome back', style: txt(24, w: FontWeight.w900, h: 1.2)),
                  const SizedBox(height: 6),
                  Text(signup ? 'Keep your words, streak and reviews safe on every device.' : 'Sign in to pick up where you left off.', textAlign: TextAlign.center, style: txt(15, w: FontWeight.w400, c: T.muted)),
                  const SizedBox(height: 24),
                  MimiField(controller: _email, hint: 'Email', keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email]),
                  const SizedBox(height: 12),
                  MimiField(
                    controller: _password,
                    hint: 'Password',
                    obscure: !show,
                    autofill: [signup ? AutofillHints.newPassword : AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      tooltip: show ? 'Hide password' : 'Show password',
                      onPressed: () => setState(() => show = !show),
                      icon: Icon(show ? LucideIcons.eyeOff : LucideIcons.eye, size: 20, color: T.muted),
                    ),
                  ),
                  if (error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: T.dangerSoft, borderRadius: BorderRadius.circular(12)),
                      child: Text(error!, style: txt(14, w: FontWeight.w700, c: T.danger)),
                    ),
                  const SizedBox(height: 12),
                  Button3D(label: busy ? 'One moment…' : (signup ? 'Create account' : 'Sign in'), onPressed: busy ? null : _submit),
                  if (!signup) TextButton(onPressed: busy ? null : _forgot, child: Text('Forgot password?', style: txt(14, w: FontWeight.w700, c: T.muted))),
                ]),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => setState(() {
                    mode = signup ? 'signin' : 'signup';
                    error = null;
                  }),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: signup ? 'Already have an account? ' : 'New here? '),
                      TextSpan(text: signup ? 'Sign in' : 'Create an account', style: txt(15, w: FontWeight.w700, c: T.primary)),
                    ]),
                    style: txt(15, w: FontWeight.w700, c: T.muted),
                  ),
                ),
                TextButton(onPressed: _later, child: Text(fromWelcome ? 'Back' : 'Maybe later', style: txt(14, w: FontWeight.w700, c: T.faint))),
                const SizedBox(height: 8),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
