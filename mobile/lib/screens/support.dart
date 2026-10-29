import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/support.dart';
import '../logic/logic.dart';
import '../services/sync_service.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';
import 'onboarding.dart' show MimiField;

/// Help & support: common questions + a message form saved to public.support_messages.
/// Mirrors src/routes/support.tsx.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _email = TextEditingController();
  final _message = TextEditingController();
  String topic = 'other';
  int? open;
  bool busy = false;
  String? error;
  String? sentTo;

  @override
  void initState() {
    super.initState();
    _email.text = context.read<SyncService>().session?.user.email ?? '';
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  String get _platform => kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    final problem = supportMessageError(email, _message.text);
    if (problem != null) return setState(() => error = problem);
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final session = context.read<SyncService>().session;
      await Supabase.instance.client.from('support_messages').insert({
        'email': email,
        'topic': topic,
        'message': _message.text.trim(),
        'platform': _platform,
        'user_id': session?.user.id,
      });
      if (!mounted) return;
      setState(() {
        busy = false;
        sentTo = email;
        _message.clear();
      });
    } catch (e) {
      debugPrint('KIZUKI_ERROR support: $e');
      if (!mounted) return;
      setState(() {
        busy = false;
        error = "Couldn't send right now. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _message.text.trim().length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('Help & support'), onBack: () => context.canPop() ? context.pop() : context.go('/profile')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, children: [
              Row(children: [
                const Mascot(MascotPose.wave, size: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('How can we help?'), style: txt(22, w: FontWeight.w900, h: 1.2)),
                    const SizedBox(height: 2),
                    Text(tr('Quick answers first. A real person reads every message.'), style: txt(14, w: FontWeight.w400, c: T.muted, h: 1.4)),
                  ]),
                ),
              ]),
              SectionTitle(tr('Common questions')),
              Container(
                decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(T.rXl), border: Border.all(color: T.border)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (var i = 0; i < supportFaq.length; i++) ...[
                    if (i > 0) const Divider(height: 1, thickness: 1, color: T.border),
                    _Faq(q: supportFaq[i].$1, a: supportFaq[i].$2, open: open == i, onTap: () => setState(() => open = open == i ? null : i)),
                  ],
                ]),
              ),
              SectionTitle(tr(deleteAccountCopy.title)),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(T.rXl), border: Border.all(color: T.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(deleteAccountCopy.intro), style: txt(14, w: FontWeight.w400, c: T.muted, h: 1.5)),
                  const SizedBox(height: 12),
                  Text(tr(deleteAccountCopy.stepsTitle), style: txt(14, w: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(tr(deleteAccountCopy.steps), style: txt(14, w: FontWeight.w400, c: T.muted, h: 1.5)),
                  const SizedBox(height: 12),
                  Text(tr(deleteAccountCopy.webTitle), style: txt(14, w: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(tr(deleteAccountCopy.web), style: txt(14, w: FontWeight.w400, c: T.muted, h: 1.5)),
                  const SizedBox(height: 12),
                  Text(tr(deleteAccountCopy.kept), style: txt(12, w: FontWeight.w400, c: T.faint, h: 1.5)),
                ]),
              ),
              SectionTitle(tr('Send us a message')),
              if (sentTo != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: T.successSoft, borderRadius: BorderRadius.circular(T.rXl)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(LucideIcons.circleCheck, color: T.success, size: 22),
                      const SizedBox(width: 8),
                      Text(tr('Message sent'), style: txt(16, w: FontWeight.w900, c: T.success)),
                    ]),
                    const SizedBox(height: 6),
                    Text(tr('Thanks! We usually reply within 2 days to {sentTo}.', {'sentTo': sentTo}), style: txt(14, w: FontWeight.w400, c: T.foreground, h: 1.5)),
                    const SizedBox(height: 12),
                    Button3D(label: tr('Send another message'), variant: BtnVariant.surface, height: 48, onPressed: () => setState(() => sentTo = null)),
                  ]),
                )
              else ...[
                Text(tr('What is it about?'), style: txt(14, w: FontWeight.w700, c: T.muted)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in supportTopics)
                    _TopicChip(label: supportTopicLabels[t]!, selected: topic == t, onTap: () => setState(() => topic = t)),
                ]),
                const SizedBox(height: 16),
                MimiField(controller: _email, hint: tr('Your email'), keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], maxLength: 255),
                const SizedBox(height: 12),
                MimiField(controller: _message, hint: tr('Tell us what happened or what you would like…'), keyboard: TextInputType.multiline, minLines: 5, maxLines: 10, maxLength: supportMessageMax),
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 4),
                  child: Align(alignment: Alignment.centerRight, child: Text('$count / $supportMessageMax', style: txt(12, w: FontWeight.w700, c: T.faint))),
                ),
                if (error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: T.dangerSoft, borderRadius: BorderRadius.circular(12)),
                    child: Text(error!, style: txt(14, w: FontWeight.w700, c: T.danger)),
                  ),
                const SizedBox(height: 12),
                Button3D(label: busy ? tr('Sending…') : tr('Send message'), onPressed: busy ? null : _send),
              ],
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                GestureDetector(onTap: () => context.push('/terms'), child: Text(tr('Terms of Service'), style: txt(12, w: FontWeight.w400, c: T.faint).copyWith(decoration: TextDecoration.underline, decorationColor: T.faint))),
                Text('  ·  ', style: txt(12, w: FontWeight.w400, c: T.faint)),
                GestureDetector(onTap: () => context.push('/privacy'), child: Text(tr('Privacy Policy'), style: txt(12, w: FontWeight.w400, c: T.faint).copyWith(decoration: TextDecoration.underline, decorationColor: T.faint))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  final String q, a;
  final bool open;
  final VoidCallback onTap;
  const _Faq({required this.q, required this.a, required this.open, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(tr(q), style: txt(15, w: FontWeight.w800, h: 1.35))),
              const SizedBox(width: 8),
              AnimatedRotation(turns: open ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: const Icon(LucideIcons.chevronDown, size: 20, color: T.muted)),
            ]),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              child: open
                  ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr(a), style: txt(14, w: FontWeight.w400, c: T.muted, h: 1.55)))
                  : const SizedBox(width: double.infinity),
            ),
          ]),
        ),
      );
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TopicChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? T.primary.withValues(alpha: 0.15) : T.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? T.primary : T.border, width: 2),
          ),
          child: Text(tr(label), style: txt(14, w: FontWeight.w800, c: selected ? T.primary : T.foreground)),
        ),
      );
}
