import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/ask.dart';
import '../data/content.dart';
import '../data/models.dart' as m;
import '../logic/logic.dart';
import '../services/tts.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'ask_sheet.dart';
import 'common.dart';
import 'ui.dart';

const posNames = {
  'noun': 'noun', 'verb': 'verb', 'adj': 'adjective', 'i-adj': 'い-adjective', 'na-adj': 'な-adjective', 'adverb': 'adverb', 'particle': 'particle',
  'auxiliary': 'auxiliary', 'pronoun': 'pronoun', 'interjection': 'interjection', 'conjunction': 'conjunction', 'prefix': 'prefix', 'suffix': 'suffix', 'other': 'word',
};

String keyOfWord(m.Word w) => wordKeyOf(w.d, w.b.isEmpty ? w.s : w.b);

/// Saved-word payload for a transcript token — mirrors wordInput() in WordCard.tsx.
WordInput wordInputOf(m.Clip clip, int li, int wi, Content content, m.ClipNotes? notes) {
  final w = clip.lines[li].words[wi];
  final e = w.d != null ? content.dict[w.d] : null;
  final base = w.b.isEmpty ? w.s : w.b;
  final noteM = notes?.words['$li.$wi']?.m ?? '';
  return WordInput(
    dictId: w.d,
    base: base,
    word: e?.w ?? base,
    reading: e?.r ?? w.r,
    romaji: w.ro,
    gloss: noteM.isNotEmpty ? noteM : (e?.gloss ?? ''),
    pos: w.p,
    jlpt: e?.j,
    surface: w.s,
    clipId: clip.id,
    line: li,
    idx: wi,
  );
}

Future<void> showWordCard(BuildContext context, {required m.Clip clip, required int line, required int idx, required Content content, required m.ClipNotes? notes}) {
  return showMimiSheet<void>(context, (_) => WordCard(clip: clip, line: line, idx: idx, content: content, notes: notes), maxHeightFactor: 0.78);
}

/// Word details sheet: meaning, explanation in context, examples ("hear it again") and notes.
class WordCard extends StatefulWidget {
  final m.Clip clip;
  final int line, idx;
  final Content content;
  final m.ClipNotes? notes;
  const WordCard({super.key, required this.clip, required this.line, required this.idx, required this.content, required this.notes});
  @override
  State<WordCard> createState() => _WordCardState();
}

const _tabs = ['Meaning', 'Explain', 'Examples', 'Notes'];

class _WordCardState extends State<WordCard> {
  String tab = 'Meaning';
  late final TextEditingController _note;
  List<String>? _others;

  m.Word get w => widget.clip.lines[widget.line].words[widget.idx];
  String get key => keyOfWord(w);

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _note = TextEditingController(text: app.words[key]?.note ?? '');
    _others = clipsWithWord(widget.content.clips, key, widget.clip.id, app.profile.jlpt);
  }

  @override
  void dispose() {
    final app = context.read<AppState>();
    final live = app.words[key];
    if (live != null && live.status != 'removed' && live.note != _note.text) app.setWordNote(key, _note.text.length > 500 ? _note.text.substring(0, 500) : _note.text);
    _note.dispose();
    super.dispose();
  }

  WordInput _input() => wordInputOf(widget.clip, widget.line, widget.idx, widget.content, widget.notes);

  /// What the tutor needs to know about this word and its line — mirrors askContext() in WordCard.tsx.
  AskContext _askContext() {
    final i = _input();
    final l = widget.clip.lines[widget.line];
    return AskContext(
      clipId: widget.clip.id,
      title: widget.clip.title,
      level: widget.clip.level,
      learnerLevel: context.read<AppState>().profile.jlpt,
      ja: l.ja,
      en: l.en,
      word: AskWord(surface: w.s, head: i.word, reading: i.reading, gloss: i.gloss),
    );
  }

  Widget _tag(String s, {Color bg = T.surface2, Color fg = T.foreground}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(s, style: txt(12, w: FontWeight.w800, c: fg)),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final content = widget.content;
    final entry = w.d != null ? content.dict[w.d] : null;
    final head = entry?.w ?? (w.b.isEmpty ? w.s : w.b);
    final reading = entry?.r ?? w.r;
    final saved = app.words[key];
    final live = saved != null && saved.status != 'removed' ? saved : null;
    final status = live == null ? 'new' : (live.status == 'ignored' ? 'ignored' : wordStatus(status: live.status, card: live.card));
    final note = widget.notes?.words['${widget.line}.${widget.idx}'];
    final lineNote = widget.notes?.lines['${widget.line}'];
    final firstPos = entry != null && entry.m.isNotEmpty && entry.m.first.pos.isNotEmpty ? entry.m.first.pos.first : null;
    final now = DateTime.now().millisecondsSinceEpoch;

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (reading.isNotEmpty && reading != head) Text(reading, style: jp(15, c: T.muted)),
              Text(head, style: jp(36, w: FontWeight.w900, h: 1.2)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(w.ro, style: txt(15, c: T.muted)),
                if (firstPos != null) _tag(firstPos),
                if (firstPos == null && w.p != 'other') _tag(posNames[w.p] ?? w.p),
                if (entry?.j != null) _tag('N${entry!.j}', bg: T.successSoft, fg: T.success),
                if (entry?.c == true) _tag('common', fg: T.muted),
                if (w.s != head) Text.rich(TextSpan(children: [const TextSpan(text: 'heard as '), TextSpan(text: w.s, style: jp(13, c: T.muted))]), style: txt(13, c: T.faint)),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _RoundIcon(icon: LucideIcons.volume2, label: 'Play pronunciation', onTap: () => Tts.speak(reading.isNotEmpty ? reading : head)),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(children: live == null || live.status == 'ignored'
            ? [
                Expanded(
                  child: Button3D(
                    height: 44,
                    onPressed: () => app.saveWord(_input()),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(LucideIcons.plus, size: 16), const SizedBox(width: 6), Text('Save word', style: txt(15, w: FontWeight.w800, c: T.primaryFg))]),
                  ),
                ),
                const SizedBox(width: 8),
                _Chip(
                  icon: LucideIcons.check,
                  iconColor: T.success,
                  label: 'I know it',
                  onTap: () => live != null ? app.setWordStatus(key, 'known') : app.markKnown([_input()]),
                ),
              ]
            : [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: status == 'known' ? T.successSoft : T.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.centerLeft,
                    child: status == 'known'
                        ? Row(children: [const Icon(LucideIcons.check, size: 16, color: T.success), const SizedBox(width: 6), Text('Known', style: txt(14, w: FontWeight.w800, c: T.success))])
                        : Text('Learning · review ${live.card.due <= now ? 'now' : 'in ${formatInterval(live.card.due - now)}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(14, w: FontWeight.w800, c: T.primary)),
                  ),
                ),
                if (status != 'known') ...[const SizedBox(width: 8), _Chip(icon: LucideIcons.check, iconColor: T.success, label: 'Known', onTap: () => app.setWordStatus(key, 'known'))],
                const SizedBox(width: 8),
                _SquareIcon(icon: LucideIcons.eyeOff, color: T.muted, label: 'Ignore word', onTap: () => app.setWordStatus(key, 'ignored')),
                const SizedBox(width: 8),
                _SquareIcon(icon: LucideIcons.trash2, color: T.danger, label: 'Remove word', onTap: () => app.removeWord(key)),
              ]),
      ),
      const SizedBox(height: 16),
      Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.border))),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final t in _tabs)
            Expanded(
              child: Semantics(
                selected: tab == t,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => tab = t),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(children: [
                      Text(t, style: txt(14, w: FontWeight.w800, c: tab == t ? T.foreground : T.faint)),
                      const SizedBox(height: 8),
                      Container(height: 3, margin: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: tab == t ? T.primary : Colors.transparent, borderRadius: BorderRadius.circular(99))),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
      Flexible(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 180),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: switch (tab) {
              'Meaning' => _meaning(entry, note),
              'Explain' => _explain(note, lineNote),
              'Examples' => _examples(entry),
              _ => _notes(live != null),
            },
          ),
        ),
      ),
    ]);
  }

  Widget _meaning(m.DictEntry? entry, m.WordNote? note) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (note != null && note.m.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: T.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              caps('In this clip', c: T.primary),
              const SizedBox(height: 2),
              Text(note.m, style: txt(18, w: FontWeight.w800)),
            ]),
          ),
        if (entry != null)
          for (var i = 0; i < entry.m.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 24, height: 24, alignment: Alignment.center, decoration: const BoxDecoration(color: T.surface2, shape: BoxShape.circle), child: Text('${i + 1}', style: txt(12, w: FontWeight.w900))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    if (entry.m[i].pos.isNotEmpty) WidgetSpan(alignment: PlaceholderAlignment.middle, child: Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(4)), child: Text(entry.m[i].pos.first, style: txt(11, w: FontWeight.w800, c: T.muted)))),
                    TextSpan(text: entry.m[i].g),
                  ]), style: txt(15, w: FontWeight.w400, h: 1.35)),
                ),
              ]),
            )
        else if (note == null || note.m.isEmpty)
          Text('No dictionary entry for this word — check the Explain tab.', style: txt(15, w: FontWeight.w400, c: T.muted)),
      ]);

  Widget _explain(m.WordNote? note, m.LineNote? lineNote) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Mascot(MascotPose.think, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(color: T.surface2, borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
              child: note != null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(text: w.s, style: jp(15, w: FontWeight.w800)),
                        const TextSpan(text: ' here means '),
                        TextSpan(text: '“${note.m}”', style: txt(15, w: FontWeight.w800)),
                        const TextSpan(text: '.'),
                      ]), style: txt(15, w: FontWeight.w400, h: 1.5)),
                      const SizedBox(height: 6),
                      Text(note.n, style: txt(15, w: FontWeight.w400, h: 1.5)),
                    ])
                  : Text(widget.notes != null ? 'This word is a small helper in the sentence — the full line meaning is below.' : 'Loading explanation…', style: txt(15, w: FontWeight.w400, h: 1.5, c: widget.notes != null ? T.foreground : T.muted)),
            ),
          ),
        ]),
        if (lineNote != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: T.surface2.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              caps('The whole line'),
              const SizedBox(height: 4),
              Text(widget.clip.lines[widget.line].ja, style: jp(16)),
              const SizedBox(height: 4),
              Text('Literally: ${lineNote.lit}', style: txt(14, w: FontWeight.w400, c: T.muted)),
              if (lineNote.tip.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('💡 ${lineNote.tip}', style: txt(14, w: FontWeight.w400))),
            ]),
          ),
        const SizedBox(height: 14),
        Button3D(
          key: const ValueKey('ask-open'),
          variant: BtnVariant.surface,
          height: 48,
          onPressed: () => showAskSheet(context, _askContext()),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(LucideIcons.messageCircleQuestion, size: 18, color: T.primary),
            const SizedBox(width: 8),
            Text('Still curious? Ask Kizuki', style: txt(15, w: FontWeight.w800)),
          ]),
        ),
      ]);

  Widget _examples(m.DictEntry? entry) {
    final others = _others ?? const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (others.isNotEmpty) ...[
        caps('Hear it in other clips'),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: others.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = widget.content.byId[others[i]];
              if (c == null) return const SizedBox();
              return Press(
                onTap: () {
                  Navigator.of(context).pop();
                  GoRouter.of(context).push('/clip/${c.id}');
                },
                child: Container(
                  width: 132,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipThumb(c.thumb),
                    Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 0), child: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(11, h: 1.2))),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (entry != null && entry.ex.isNotEmpty) ...[
        caps('Example sentences'),
        const SizedBox(height: 8),
        for (final e in entry.ex)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Press(
              onTap: () => Tts.speak(e.ja),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(16)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.ja, style: jp(16)),
                      const SizedBox(height: 2),
                      Text(e.en, style: txt(13, w: FontWeight.w400, c: T.muted)),
                    ]),
                  ),
                  const Padding(padding: EdgeInsets.only(top: 4, left: 8), child: Icon(LucideIcons.volume2, size: 16, color: T.faint)),
                ]),
              ),
            ),
          ),
        Text('Examples: Tatoeba (CC BY 2.0 FR) via JMdict.', style: txt(11, w: FontWeight.w400, c: T.faint)),
      ] else if (others.isEmpty)
        Text('No other examples yet for this word.', style: txt(15, w: FontWeight.w400, c: T.muted)),
    ]);
  }

  Widget _notes(bool isSaved) => isSaved
      ? TextField(
          controller: _note,
          maxLines: 5,
          maxLength: 500,
          style: txt(15, w: FontWeight.w400),
          cursorColor: T.primary,
          onTapOutside: (_) {
            FocusScope.of(context).unfocus();
            context.read<AppState>().setWordNote(key, _note.text);
          },
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Add a note — a memory trick, where you heard it…',
            hintStyle: txt(15, w: FontWeight.w400, c: T.faint),
            filled: true,
            fillColor: T.surface2,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: T.border, width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: T.primary, width: 2)),
          ),
        )
      : Text('Save this word to add your own notes.', style: txt(15, w: FontWeight.w400, c: T.muted));
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Press(onTap: onTap, child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: T.surface2, shape: BoxShape.circle), child: Icon(icon, size: 20))),
      );
}

class _SquareIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _SquareIcon({required this.icon, required this.color, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Press(onTap: onTap, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 16, color: color))),
      );
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _Chip({required this.icon, required this.iconColor, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: iconColor), const SizedBox(width: 6), Text(label, style: txt(14, w: FontWeight.w800))]),
        ),
      );
}
