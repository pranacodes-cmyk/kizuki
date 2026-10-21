import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/ask.dart';
import '../data/models.dart' as m;
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'ask_sheet.dart';
import 'toast.dart';
import 'ui.dart';

const speeds = [1.0, 0.75, 0.5];

String speedLabel(double s) => s == 1 ? '1×' : '$s×';

/// Line options sheet — mirrors LineMenu in ClipSheets.tsx.
Future<void> showLineMenu(BuildContext context, {required m.Clip clip, required int line, required m.ClipNotes? notes, required VoidCallback onReplay, required VoidCallback onLoop, required bool looping}) {
  final l = clip.lines[line];
  final n = notes?.lines['$line'];
  return showMimiSheet<void>(
    context,
    (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.ja, style: jp(20, h: 1.35)),
        const SizedBox(height: 4),
        Text(l.en, style: txt(15, w: FontWeight.w400, c: T.muted)),
        if (n != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: T.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(LucideIcons.sparkles, size: 14, color: T.primary), const SizedBox(width: 6), caps('Explained', c: T.primary)]),
              const SizedBox(height: 4),
              Text.rich(TextSpan(children: [TextSpan(text: 'Literally: ', style: txt(15, w: FontWeight.w400, c: T.muted)), TextSpan(text: n.lit)]), style: txt(15, w: FontWeight.w400)),
              if (n.tip.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('💡 ${n.tip}', style: txt(15, w: FontWeight.w400))),
            ]),
          ),
        const SizedBox(height: 16),
        _MenuRow(key: const ValueKey('line-ask'), icon: LucideIcons.messageCircleQuestion, iconColor: T.primary, label: 'Ask Kizuki about this line', onTap: () {
          final level = context.read<AppState>().profile.jlpt;
          Navigator.pop(ctx);
          showAskSheet(context, AskContext(clipId: clip.id, title: clip.title, level: clip.level, learnerLevel: level, ja: l.ja, en: l.en));
        }),
        _MenuRow(icon: LucideIcons.rotateCcw, label: 'Replay this line', onTap: () {
          Navigator.pop(ctx);
          onReplay();
        }),
        _MenuRow(icon: LucideIcons.repeat1, iconColor: looping ? T.primary : T.muted, label: looping ? 'Stop looping this line' : 'Loop this line', onTap: () {
          Navigator.pop(ctx);
          onLoop();
        }),
        _MenuRow(icon: LucideIcons.copy, label: 'Copy Japanese', onTap: () async {
          Navigator.pop(ctx);
          try {
            await Clipboard.setData(ClipboardData(text: l.ja));
            toast('Copied', icon: '📋');
          } catch (_) {
            toast("Couldn't copy", tone: ToastTone.error);
          }
        }),
      ]),
    ),
    maxHeightFactor: 0.7,
  );
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _MenuRow({super.key, required this.icon, required this.label, required this.onTap, this.iconColor = T.muted});
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(children: [Icon(icon, size: 20, color: iconColor), const SizedBox(width: 16), Expanded(child: Text(label, style: txt(16, w: FontWeight.w700)))]),
        ),
      );
}

/// Quick "Aa" display sheet — mirrors DisplaySheet in ClipSheets.tsx.
Future<void> showDisplaySheet(BuildContext context, {required double Function() rate, required ValueChanged<double> onRate}) {
  return showMimiSheet<void>(context, (_) => _DisplaySheet(rate: rate, onRate: onRate), maxHeightFactor: 0.8);
}

class _DisplaySheet extends StatefulWidget {
  final double Function() rate;
  final ValueChanged<double> onRate;
  const _DisplaySheet({required this.rate, required this.onRate});
  @override
  State<_DisplaySheet> createState() => _DisplaySheetState();
}

class _DisplaySheetState extends State<_DisplaySheet> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    final rows = <(String, bool, void Function(Settings, bool))>[
      ('Furigana (readings above kanji)', s.furigana, (x, v) => x.furigana = v),
      ('Romaji', s.romaji, (x, v) => x.romaji = v),
      ('English translation', s.translation, (x, v) => x.translation = v),
      ('Highlight the spoken word', s.highlight, (x, v) => x.highlight = v),
      ('Space between words', s.spacing, (x, v) => x.spacing = v),
    ];
    final rate = widget.rate();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Display', style: txt(18, w: FontWeight.w900)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: T.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Expanded(child: Text(rows[i].$1, style: txt(15, w: FontWeight.w700))),
                  Semantics(label: rows[i].$1, toggled: rows[i].$2, child: MimiToggle(value: rows[i].$2, onChanged: (v) => app.setSettings((x) => rows[i].$3(x, v)))),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        caps('Text size'),
        const SizedBox(height: 8),
        _Segmented(
          options: const [(0.85, 'Small'), (1.0, 'Medium'), (1.2, 'Large')],
          value: s.textSize,
          onPick: (v) => app.setSettings((x) => x.textSize = v),
        ),
        const SizedBox(height: 20),
        caps('Speed'),
        const SizedBox(height: 8),
        _Segmented(
          options: [for (final sp in speeds) (sp, speedLabel(sp))],
          value: rate,
          onPick: (v) {
            widget.onRate(v);
            setState(() {});
          },
        ),
      ]),
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<(double, String)> options;
  final double value;
  final ValueChanged<double> onPick;
  const _Segmented({required this.options, required this.value, required this.onPick});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Press(
              onTap: () => onPick(options[i].$1),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == options[i].$1 ? T.primary.withValues(alpha: 0.15) : T.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: value == options[i].$1 ? T.primary : T.border, width: 2),
                ),
                child: Text(options[i].$2, style: txt(14, w: FontWeight.w800, c: value == options[i].$1 ? T.primary : T.foreground)),
              ),
            ),
          ),
        ],
      ]);
}
