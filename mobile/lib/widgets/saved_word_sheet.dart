import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart' as m;
import '../logic/logic.dart';
import '../services/tts.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'ui.dart';
import 'word_level.dart';
import '../i18n/i18n.dart';

/// The source sentence with the saved word highlighted — mirrors HighlightedLine.
class HighlightedLine extends StatelessWidget {
  final m.Clip clip;
  final int line, idx;
  final double size;
  const HighlightedLine({super.key, required this.clip, required this.line, required this.idx, this.size = 17});
  @override
  Widget build(BuildContext context) {
    if (line < 0 || line >= clip.lines.length) return const SizedBox();
    final l = clip.lines[line];
    return Text.rich(
      TextSpan(children: [for (var i = 0; i < l.words.length; i++) TextSpan(text: l.words[i].s, style: i == idx ? jp(size, c: T.primary, h: 1.35) : null)]),
      style: jp(size, h: 1.35),
    );
  }
}

Future<void> showSavedWord(BuildContext context, SavedWord word, Content? content) =>
    showMimiSheet<void>(context, (_) => SavedWordSheet(wordKey: word.key, fallback: word, content: content), maxHeightFactor: 0.88);

/// Saved word details (Vocab list) — mirrors SavedWordSheet.tsx.
class SavedWordSheet extends StatefulWidget {
  final String wordKey;
  final SavedWord fallback;
  final Content? content;
  const SavedWordSheet({super.key, required this.wordKey, required this.fallback, required this.content});
  @override
  State<SavedWordSheet> createState() => _SavedWordSheetState();
}

class _SavedWordSheetState extends State<SavedWordSheet> {
  late final TextEditingController _note = TextEditingController(text: widget.fallback.note);
  late final AppState _app = context.read<AppState>();

  @override
  void dispose() {
    final w = _app.words[widget.wordKey];
    if (w != null && w.status != 'removed' && w.note != _note.text) _app.setWordNote(widget.wordKey, _note.text);
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final w = app.words[widget.wordKey] ?? widget.fallback;
    final content = widget.content;
    final entry = w.dictId != null ? content?.dict[w.dictId] : null;
    final gloss = w.glossIn(content);
    final clip = content?.byId[w.clipId];
    final level = wordLevel(status: w.status, card: w.card);
    final now = DateTime.now().millisecondsSinceEpoch;
    final review = level >= 1 && level <= 4 ? (w.card.due <= now ? tr('Practice now') : tr('Next practice {when}', {'when': formatWhen(w.card.due - now)})) : null;
    void close() => Navigator.of(context).pop();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (w.reading.isNotEmpty && w.reading != w.word) Text(w.reading, style: jp(15, c: T.muted)),
              Text(w.word, style: jp(36, w: FontWeight.w900, h: 1.2)),
              Row(children: [
                Text(w.romaji, style: txt(15, c: T.muted)),
                if (w.jlpt != null)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: T.successSoft, borderRadius: BorderRadius.circular(6)),
                    child: Text('N${w.jlpt}', style: txt(12, w: FontWeight.w800, c: T.success)),
                  ),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              button: true,
              label: tr('Play pronunciation'),
              child: Press(onTap: () => Tts.speak(w.reading.isNotEmpty ? w.reading : w.word), child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: T.surface2, shape: BoxShape.circle), child: const Icon(LucideIcons.volume2, size: 20))),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              button: true,
              label: tr('Remove from Vocab'),
              child: Press(
                onTap: () {
                  app.removeWord(w.key);
                  close();
                },
                child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: T.surface2, shape: BoxShape.circle), child: const Icon(LucideIcons.trash2, size: 18, color: T.danger)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Flexible(child: LevelPill(wordKey: w.key, word: w.word, onRemoved: close)),
          const SizedBox(width: 10),
          if (review != null) Expanded(child: Text(review, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(13, w: FontWeight.w700, c: T.muted))),
        ]),
        const SizedBox(height: 16),
        // The clip meaning, unless the dictionary's first sense already says the same thing.
        if (gloss.isNotEmpty && (entry == null || entry.m.isEmpty || !repeatsSense(gloss, entry.m.first.g))) Text(gloss, style: txt(18, w: FontWeight.w800)),
        if (entry != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < entry.m.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${i + 1}. ', style: txt(15, w: FontWeight.w900)),
                    if (entry.m[i].pos.isNotEmpty) TextSpan(text: '[${entry.m[i].pos.first}] ', style: txt(12, w: FontWeight.w800, c: T.muted)),
                    TextSpan(text: entry.m[i].g),
                  ]), style: txt(15, w: FontWeight.w400, c: T.muted)),
                ),
            ]),
          ),
        if (clip != null) ...[
          const SizedBox(height: 20),
          caps(tr('Where you found it')),
          const SizedBox(height: 8),
          HighlightedLine(clip: clip, line: w.line, idx: w.idx),
          if (w.line < clip.lines.length) Text(clip.lines[w.line].en, style: txt(14, w: FontWeight.w400, c: T.muted)),
          const SizedBox(height: 8),
          Press(
            onTap: () {
              Navigator.of(context).pop();
              GoRouter.of(context).push('/clip/${clip.id}');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Expanded(child: Text(tr('Watch the whole clip'), style: txt(14, w: FontWeight.w800))), const Icon(LucideIcons.chevronRight, size: 16)]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLines: 3,
          maxLength: 500,
          style: txt(15, w: FontWeight.w400),
          cursorColor: T.primary,
          onTapOutside: (_) {
            FocusScope.of(context).unfocus();
            app.setWordNote(w.key, _note.text);
          },
          decoration: InputDecoration(
            counterText: '',
            hintText: tr('Add a note…'),
            hintStyle: txt(15, w: FontWeight.w400, c: T.faint),
            filled: true,
            fillColor: T.surface2,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: T.border, width: 2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: T.primary, width: 2)),
          ),
        ),
      ]),
    );
  }
}
