import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/content.dart';
import '../data/onboarding.dart';
import '../logic/logic.dart';
import '../services/locale_pack.dart';
import '../services/billing.dart';
import '../services/analytics.dart';
import '../services/export_service.dart';
import '../services/haptics.dart';
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/toast.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

const _levelHint = {
  'N5': 'Complete beginner — greetings and simple phrases',
  'N4': 'Basic — everyday words and short sentences',
  'N3': 'Intermediate — everyday conversations at natural speed',
  'N2': 'Upper-intermediate — dramas, news and fast talk',
  'N1': 'Advanced — almost everything',
};

/// Settings — mirrors src/routes/settings.tsx.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool busy = false;
  bool restoring = false;

  /// Same store restore as the paywall (trial.dart), for people who reinstalled or switched
  /// phones — including its account step: a restored purchase needs a verified account
  /// (signed-in learners pass straight through on the account screen).
  Future<void> _restore() async {
    final app = context.read<AppState>();
    setState(() => restoring = true);
    final r = await Billing.restore();
    if (r == StoreResult.done) app.requirePurchaseAccount();
    if (!mounted) return;
    setState(() => restoring = false);
    if (r == StoreResult.unavailable) {
      return toast(tr("Couldn't reach the store"), description: tr('Check your connection and try again.'), tone: ToastTone.error);
    }
    if (r != StoreResult.done) return toast(tr('No subscription found'), description: tr('Use the same store account you bought with.'));
    toast(tr('Purchase restored'), icon: '🎉');
    context.go('/account?mode=signin');
  }

  Future<void> _signOut() async {
    await SyncService.I.signOut();
    toast(tr('Signed out'), description: tr('Your progress stays on this device.'), icon: '👋');
  }

  Future<void> _deleteAccount(BuildContext modal) async {
    final app = context.read<AppState>();
    final router = GoRouter.of(context);
    setState(() => busy = true);
    try {
      await Supabase.instance.client.rpc('delete_my_account');
    } catch (e) {
      if (mounted) setState(() => busy = false);
      toast(tr("Couldn't delete your account"), description: e is PostgrestException ? e.message : e.toString(), tone: ToastTone.error);
      return;
    }
    await Supabase.instance.client.auth.signOut();
    await app.reset();
    if (modal.mounted) Navigator.of(modal).pop();
    if (mounted) setState(() => busy = false);
    router.go('/');
  }

  Future<void> _export() async {
    final app = context.read<AppState>();
    if (!app.words.values.any((w) => w.status != 'removed')) {
      toast(tr('No saved words yet'));
      return;
    }
    final c = await Content.load();
    await shareWordsCsv(app.words.values, c);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final session = context.watch<SyncService>().session;
    final s = app.settings;
    final p = app.profile;
    final premium = app.premium;
    final phase = subscriptionPhase(premium.active, premium.plan, premium.trialEndsAt, DateTime.now().millisecondsSinceEpoch);

    Widget toggle(String label, bool value, void Function(Settings, bool) set, {String? hint}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(label), style: txt(15, w: FontWeight.w700)),
                if (hint != null) Text(tr(hint), style: txt(12, w: FontWeight.w400, c: T.muted)),
              ]),
            ),
            Semantics(label: tr(label), toggled: value, child: MimiToggle(value: value, onChanged: (v) => app.setSettings((x) => set(x, v)))),
          ]),
        );

    Widget seg<V>(List<(V, String)> opts, V value, ValueChanged<V> pick, {double height = 40}) => Row(children: [
          for (var i = 0; i < opts.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Press(
                onTap: () => pick(opts[i].$1),
                child: Container(
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: value == opts[i].$1 ? T.primary : T.surface2, borderRadius: BorderRadius.circular(12)),
                  child: Text(tr(opts[i].$2), textAlign: TextAlign.center, style: txt(13, w: FontWeight.w800, c: value == opts[i].$1 ? T.primaryFg : T.muted)),
                ),
              ),
            ),
          ],
        ]);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('Settings'), onBack: () => context.canPop() ? context.pop() : context.go('/profile')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              _Group(title: tr('Learning'), children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Japanese level'), style: txt(15, w: FontWeight.w700)),
                    const SizedBox(height: 8),
                    seg<String>([for (final l in jlptLevels) (l, l)], p.jlpt, (l) => app.setProfile((x) => x.jlpt = l)),
                    const SizedBox(height: 8),
                    Text(_levelHint[p.jlpt] ?? '', style: txt(13, w: FontWeight.w400, c: T.muted)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(children: [
                    Row(children: [Expanded(child: Text(tr('Daily goal'), style: txt(15, w: FontWeight.w700))), Text(tr('{minutes} min', {'minutes': p.dailyMinutes}), style: txt(15, w: FontWeight.w900, c: T.primary))]),
                    Semantics(
                      label: tr('Daily goal minutes'),
                      child: SliderTheme(
                        data: const SliderThemeData(activeTrackColor: T.primary, inactiveTrackColor: T.surface2, thumbColor: T.primary, trackHeight: 6, showValueIndicator: ShowValueIndicator.never),
                        child: Slider(value: p.dailyMinutes.toDouble().clamp(5, 60), min: 5, max: 60, divisions: 11, onChanged: (v) => app.setProfile((x) => x.dailyMinutes = v.round())),
                      ),
                    ),
                  ]),
                ),
              ]),
              _Group(title: tr('Display'), children: [
                _LanguageRow(onTap: () => context.push('/language?from=settings')),
                toggle(tr('Show furigana'), s.furigana, (x, v) => x.furigana = v),
                toggle(tr('Show romaji'), s.romaji, (x, v) => x.romaji = v),
                toggle(tr('Show translation'), s.translation, (x, v) => x.translation = v),
                toggle(tr('Space between words'), s.spacing, (x, v) => x.spacing = v, hint: tr('Turn off for natural Japanese text')),
                toggle(tr('Highlight the spoken word'), s.highlight, (x, v) => x.highlight = v),
                toggle(tr('Save words I tap'), s.autoSave, (x, v) => x.autoSave = v, hint: tr('Off: save only with the Save button')),
                toggle(tr('Vibration feedback'), s.haptics, (x, v) {
                  x.haptics = v;
                  Haptics.enabled = v;
                  if (v) Haptics.light(); // a gentle tap to show it's back on
                }, hint: tr('Gentle taps for buttons and milestones')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Text size'), style: txt(15, w: FontWeight.w700)),
                    const SizedBox(height: 8),
                    seg<double>([(0.85, tr('Small')), (1.0, tr('Medium')), (1.2, tr('Large'))], s.textSize, (v) => app.setSettings((x) => x.textSize = v)),
                  ]),
                ),
              ]),
              _Group(title: tr('Flashcards'), children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Card front'), style: txt(15, w: FontWeight.w700)),
                    const SizedBox(height: 8),
                    seg<String>([('jp', tr('Japanese → English')), ('en', tr('English → Japanese'))], s.flashFront, (v) => app.setSettings((x) => x.flashFront = v)),
                  ]),
                ),
                toggle(tr('Furigana on the front'), s.flashFurigana, (x, v) => x.flashFurigana = v),
                toggle(tr('Romaji on the front'), s.flashRomaji, (x, v) => x.flashRomaji = v),
              ]),
              _Group(title: tr('Reminders'), children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Expanded(child: Text(tr('Daily reminder'), style: txt(15, w: FontWeight.w700))),
                    Semantics(
                      label: tr('Daily reminder'),
                      toggled: s.reminders,
                      child: MimiToggle(
                        value: s.reminders,
                        onChanged: (v) async {
                          if (v) await NotificationService.requestPermission();
                          app.setSettings((x) => x.reminders = v);
                        },
                      ),
                    ),
                  ]),
                ),
                if (s.reminders) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text.rich(TextSpan(children: trSpans('Study window [· {when}]', txt(15, w: FontWeight.w400, c: T.muted), {'when': windowLabel(p.window)})), style: txt(15, w: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(children: [
                        for (var i = 0; i < windowOptions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Press(
                              onTap: () => app.setProfile((x) => x.window = windowOptions[i].id),
                              child: Container(
                                height: 56,
                                decoration: BoxDecoration(color: p.window == windowOptions[i].id ? T.primary : T.surface2, borderRadius: BorderRadius.circular(12)),
                                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(windowOptions[i].emoji, style: const TextStyle(fontSize: 18)),
                                  Text(tr(windowOptions[i].label), style: txt(12, w: FontWeight.w800, c: p.window == windowOptions[i].id ? T.primaryFg : T.muted)),
                                ]),
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('How often'), style: txt(15, w: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(children: [
                        for (final (v, l, h) in [('standard', tr('Daily'), tr('A friendly nudge each day')), ('minimal', tr('Minimal'), tr('Only to save your streak'))]) ...[
                          if (v == 'minimal') const SizedBox(width: 6),
                          Expanded(
                            child: Press(
                              onTap: () => app.setSettings((x) => x.reminderFreq = v),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: s.reminderFreq == v ? T.primary : T.surface2, borderRadius: BorderRadius.circular(12)),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(l, style: txt(14, w: FontWeight.w800, c: s.reminderFreq == v ? T.primaryFg : T.muted)),
                                  Text(h, style: txt(11, w: FontWeight.w400, c: (s.reminderFreq == v ? T.primaryFg : T.muted).withValues(alpha: 0.8))),
                                ]),
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                ],
              ]),
              _Group(title: tr('Your data'), children: [
                ValueListenableBuilder<bool?>(valueListenable: Analytics.choice, builder: (context, choice, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr('Usage analytics'), style: txt(15)), Text(tr('Share activity with PostHog. No messages or payment details.'), style: txt(12, c: T.muted))])),
                    Semantics(label: tr('Usage analytics'), child: MimiToggle(value: choice == true, onChanged: (v) => Analytics.setChoice(v))),
                  ]),
                )),
                _ActionRow(label: tr('Export saved words (.csv)'), onTap: _export),
                _ActionRow(
                  label: tr('Replay the welcome tour'),
                  onTap: () {
                    app.resetTutorial();
                    toast(tr('Tour reset'), description: tr('Kizuki will show you around on the feed.'), icon: '🦊');
                    context.go('/feed');
                  },
                ),
              ]),
              _Group(title: tr('Subscription'), children: premium.active
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('Kizuki Premium · {plan}', {'plan': premium.plan == 'monthly' ? tr('Monthly') : tr('Yearly')}), style: txt(15, w: FontWeight.w700)),
                          Text(
                            phase == 'trial' ? tr('Premium active · Trial ends {date}', {'date': DateFormat.yMd().format(DateTime.fromMillisecondsSinceEpoch(premium.trialEndsAt ?? 0))}) : tr('Premium active'),
                            style: txt(13, w: FontWeight.w400, c: T.muted),
                          ),
                        ]),
                      ),
                      _ActionRow(
                        label: tr('Manage subscription'),
                        onTap: () {
                          if (!Billing.available) {
                            // Test builds have no store: the simulated plan can be ended here.
                            app.cancelPremium();
                            toast(tr('Premium ended (test build)'));
                            return;
                          }
                          launchUrl(Uri.parse(Billing.manageUrl()), mode: LaunchMode.externalApplication);
                        },
                      ),
                    ]
                  : [
                      _ActionRow(label: tr('View Premium plans'), onTap: () => context.push('/trial')),
                      _ActionRow(label: restoring ? tr('Restoring…') : tr('Restore purchase'), onTap: () => restoring ? null : _restore()),
                    ]),
              _Group(title: tr('Account'), children: session != null
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text.rich(TextSpan(children: trSpans('Signed in as [{email}]', txt(14, w: FontWeight.w800, c: T.foreground), {'email': session.user.email ?? ''})), style: txt(14, w: FontWeight.w400, c: T.muted)),
                      ),
                      _ActionRow(label: tr('Sign out'), onTap: _signOut),
                      _ActionRow(
                        label: tr('Delete account'),
                        danger: true,
                        onTap: () => showMimiModal<void>(
                          context,
                          (ctx) => StatefulBuilder(
                            builder: (ctx, setLocal) => _Confirm(
                              title: tr('Delete your account?'),
                              body: tr("This permanently deletes your account and cloud progress. It can't be undone."),
                              yes: busy ? tr('Deleting…') : tr('Delete forever'),
                              no: 'Keep my account',
                              onYes: busy
                                  ? null
                                  : () async {
                                      setLocal(() {});
                                      await _deleteAccount(ctx);
                                    },
                            ),
                          ),
                        ),
                      ),
                    ]
                  : [_ActionRow(label: tr('Sign in or create an account'), onTap: () => context.push('/account?mode=signin'))]),
              _Group(title: tr('Help'), children: [_ActionRow(label: tr('Help & support'), onTap: () => context.push('/support'))]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GestureDetector(onTap: () => context.push('/terms'), child: Text(tr('Terms of Service'), style: txt(12, w: FontWeight.w400, c: T.faint).copyWith(decoration: TextDecoration.underline, decorationColor: T.faint))),
                    Text('  ·  ', style: txt(12, w: FontWeight.w400, c: T.faint)),
                    GestureDetector(onTap: () => context.push('/privacy'), child: Text(tr('Privacy Policy'), style: txt(12, w: FontWeight.w400, c: T.faint).copyWith(decoration: TextDecoration.underline, decorationColor: T.faint))),
                  ]),
                  const SizedBox(height: 8),
                  Text(tr('Videos play through YouTube and belong to their creators. Dictionary data: JMdict (EDRDG), CC BY-SA 4.0. Example sentences: Tatoeba, CC BY 2.0 FR.'), textAlign: TextAlign.center, style: txt(12, w: FontWeight.w400, c: T.faint, h: 1.5)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: caps(title)),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: T.border),
                children[i],
              ],
            ]),
          ),
        ]),
      );
}

/// Settings → App language: the current language, opening the picker.
class _LanguageRow extends StatelessWidget {
  final VoidCallback onTap;
  const _LanguageRow({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final l = I18n.language;
    return Press(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('App language'), style: txt(15, w: FontWeight.w700)),
              if (l.code != 'en') _LanguagePackLine(lang: l.code),
            ]),
          ),
          Text('${l.flag}  ${l.native}', style: txt(14, w: FontWeight.w700, c: T.muted)),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronRight, size: 18, color: T.faint),
        ]),
      ),
    );
  }
}

/// Whether the clips are fully translated on this device — mirrors LanguagePackLine in settings.tsx.
class _LanguagePackLine extends StatelessWidget {
  final String lang;
  const _LanguagePackLine({required this.lang});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: LocalePacks.downloading,
        builder: (context, _, _) => FutureBuilder<String>(
          future: LocalePacks.state(lang),
          builder: (context, snap) {
            final st = snap.data;
            if (st == null) return const SizedBox(height: 18);
            final text = st == 'ready' ? tr('Translations downloaded') : st == 'downloading' ? tr('Downloading translations…') : tr('First clips translated');
            return Padding(padding: const EdgeInsets.only(top: 2), child: Text(text, style: txt(12.5, w: FontWeight.w600, c: st == 'ready' ? T.success : T.faint)));
          },
        ),
      );
}

class _ActionRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _ActionRow({required this.label, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(tr(label), style: txt(15, w: FontWeight.w700, c: danger ? T.danger : T.foreground)),
        ),
      );
}

class _Confirm extends StatelessWidget {
  final String title, body, yes, no;
  final VoidCallback? onYes;
  const _Confirm({required this.title, required this.body, required this.yes, required this.no, required this.onYes});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(title), style: txt(20, w: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(tr(body), style: txt(15, w: FontWeight.w400, c: T.muted)),
        const SizedBox(height: 20),
        Button3D(label: yes, variant: BtnVariant.danger, onPressed: onYes),
        const SizedBox(height: 8),
        Button3D(label: no, variant: BtnVariant.ghost, height: 48, onPressed: () => Navigator.of(context).pop()),
      ]);
}
