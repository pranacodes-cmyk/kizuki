import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/models.dart' as m;
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'tour.dart';
import 'ui.dart';
import 'word_level.dart';

/// Index of the line being spoken (last line whose start ≤ t), -1 before the first line.
int activeLineIndex(m.Clip clip, double t) {
  var idx = -1;
  for (var i = 0; i < clip.lines.length; i++) {
    if (clip.lines[i].start <= t + 0.05) idx = i;
  }
  return idx;
}

/// Punctuation sticks to the word before it so "。" never wraps onto its own line.
List<(int, String)> groupTokens(List<m.Word> words) {
  final out = <(int, String)>[];
  for (var wi = 0; wi < words.length; wi++) {
    final w = words[wi];
    if (w.isPunct && out.isNotEmpty) {
      final last = out.removeLast();
      out.add((last.$1, last.$2 + w.s));
    } else {
      out.add((wi, ''));
    }
  }
  return out;
}

/// Interactive transcript: furigana, romaji, translation, status underlines and the
/// karaoke highlight — mirrors Transcript.tsx.
class Transcript extends StatelessWidget {
  final m.Clip clip;
  final double time;
  final Settings settings;
  final String Function(m.Word w) statusOf;

  /// Level of a saved word (1–4 while learning): its underline fades from orange to brown.
  final int? Function(m.Word w)? levelOf;
  final (int, int)? selected;
  final void Function(int line, int idx) onWord;
  final ValueChanged<int> onLine;
  final ValueChanged<int> onLineMenu;
  final List<GlobalKey> lineKeys;

  /// The word the welcome tour spotlights (line, index), if any.
  final (int, int)? tourWord;
  const Transcript({super.key, required this.clip, required this.time, required this.settings, required this.statusOf, this.levelOf, required this.selected, required this.onWord, required this.onLine, required this.onLineMenu, required this.lineKeys, this.tourWord});

  @override
  Widget build(BuildContext context) {
    final current = activeLineIndex(clip, time);
    final scale = settings.textSize;
    final base = 20.8 * scale; // 1.3rem
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(children: [
        for (var li = 0; li < clip.lines.length; li++)
          Padding(
            key: li < lineKeys.length ? lineKeys[li] : null,
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onLine(li),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: li == current ? 1 : 0.6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 36, 10),
                  decoration: BoxDecoration(color: li == current ? T.surface : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (clip.lines[li].sp.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(clip.lines[li].sp.toUpperCase(), style: txt(11, w: FontWeight.w900, c: T.faint, ls: 1.1))),
                      Wrap(
                        spacing: settings.spacing ? 6 : 0,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          for (final (wi, trail) in groupTokens(clip.lines[li].words))
                            TourAnchor(
                              key: ValueKey('word-$li-$wi'),
                              id: 'word',
                              enabled: tourWord != null && tourWord!.$1 == li && tourWord!.$2 == wi,
                              child: _Token(
                              w: clip.lines[li].words[wi],
                              trail: trail,
                              size: base,
                              status: clip.lines[li].words[wi].isPunct ? 'known' : statusOf(clip.lines[li].words[wi]),
                              level: clip.lines[li].words[wi].isPunct ? null : levelOf?.call(clip.lines[li].words[wi]),
                              speaking: settings.highlight && li == current && time >= clip.lines[li].words[wi].t0 && time < clip.lines[li].words[wi].t1 && !clip.lines[li].words[wi].isPunct,
                              selected: selected != null && selected!.$1 == li && selected!.$2 == wi,
                              furigana: settings.furigana,
                              romaji: settings.romaji,
                              onTap: clip.lines[li].words[wi].isPunct ? null : () => onWord(li, wi),
                            ),
                            ),
                        ],
                      ),
                      if (settings.translation) Padding(padding: const EdgeInsets.only(top: 6), child: Text(clip.lines[li].en, style: txt(15 * scale, w: FontWeight.w400, c: T.muted))),
                    ]),
                    Positioned(
                      right: -32,
                      top: -2,
                      child: IconButton(
                        tooltip: 'Line options',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onLineMenu(li),
                        icon: const Icon(LucideIcons.ellipsisVertical, size: 16, color: T.faint),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Token extends StatelessWidget {
  final m.Word w;
  final String trail;
  final double size;
  final String status;
  final int? level;
  final bool speaking, selected, furigana, romaji;
  final VoidCallback? onTap;
  const _Token({required this.w, required this.trail, required this.size, required this.status, this.level, required this.speaking, required this.selected, required this.furigana, required this.romaji, this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = jp(size, h: 1.25);
    if (onTap == null) return Text(w.s + trail, style: style.copyWith(height: 1.9));
    final underline = status == 'new' ? T.info : (status == 'learning' ? levelColor((level ?? 1).clamp(1, 4)) : Colors.transparent);
    final rubySize = size * 0.5;
    final showRuby = furigana && w.f != null;
    Widget body;
    if (showRuby) {
      body = Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final seg in w.f!)
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(seg.length > 1 && seg[1] != null ? seg[1]! : ' ', style: jp(rubySize, c: T.muted, h: 1.1)),
            Text(seg[0] ?? '', style: style),
          ]),
      ]);
    } else {
      body = Text(w.s, style: style);
    }
    final btn = Semantics(
      button: true,
      label: w.s,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? T.primary.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: speaking ? T.success : Colors.transparent, width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: underline, width: 3))),
              child: body,
            ),
            if (romaji) Padding(padding: const EdgeInsets.only(top: 4), child: Text(w.ro.isEmpty ? ' ' : w.ro, style: txt(size * 0.5, w: FontWeight.w700, c: T.faint))),
          ]),
        ),
      ),
    );
    if (trail.isEmpty) return btn;
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      btn,
      Padding(padding: EdgeInsets.only(top: showRuby ? rubySize * 1.1 + 2 : 2), child: Text(trail, style: style)),
    ]);
  }
}
