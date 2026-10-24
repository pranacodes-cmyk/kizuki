import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Word level colours (Kiku's colour legend): 1 bright orange fading to brown by 4,
/// green when known, red when ignored — mirrors levelColor in WordLevel.tsx.
Color levelColor(int level) => switch (level) {
      0 => T.danger,
      1 => T.learning,
      2 => T.level2,
      3 => T.level3,
      4 => T.level4,
      _ => T.success,
    };

/// Round level badge: the number for learning levels, ✓ when known, × when ignored.
class LevelBadge extends StatelessWidget {
  final int level;
  final double size;
  const LevelBadge({super.key, required this.level, this.size = 22});
  @override
  Widget build(BuildContext context) {
    final fg = level >= 1 && level <= 2 ? T.primaryFg : (level == 5 || level == 0 ? T.stage : T.foreground);
    return Semantics(
      label: 'Level: ${(level >= 1 && level <= 4 ? 'Learning' : wordLevelInfo(level).label)}',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: levelColor(level), shape: BoxShape.circle),
        child: level == 5
            ? Icon(LucideIcons.check, size: size * 0.6, color: fg)
            : level == 0
                ? Icon(LucideIcons.x, size: size * 0.6, color: fg)
                : Icon(LucideIcons.bookOpen, size: size * 0.6, color: fg),
      ),
    );
  }
}

/// The one status button on a saved word: badge + level name. Opens the level sheet.
class LevelPill extends StatelessWidget {
  final String wordKey;
  final String word;

  /// Called after the learner removed the word from the level sheet.
  final VoidCallback? onRemoved;
  const LevelPill({super.key, required this.wordKey, required this.word, this.onRemoved});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final w = app.words[wordKey];
    if (w == null) return const SizedBox.shrink();
    final level = wordLevel(status: w.status, card: w.card);
    return Semantics(
      button: true,
      label: 'Word level: ${(level >= 1 && level <= 4 ? 'Learning' : wordLevelInfo(level).label)}. Change',
      child: Press(
        onTap: () async {
          final r = await showWordLevelSheet(context, wordKey: wordKey, word: word);
          if (r == 'removed') onRemoved?.call();
        },
        child: Container(
          key: const ValueKey('level-pill'),
          height: 44,
          padding: const EdgeInsets.only(left: 8, right: 10),
          decoration: BoxDecoration(color: levelColor(level).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LevelBadge(level: level, size: 26),
            const SizedBox(width: 8),
            Flexible(child: Text((level >= 1 && level <= 4 ? 'Learning' : wordLevelInfo(level).label), maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(15, w: FontWeight.w800, c: level == 0 ? T.muted : T.foreground))),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronDown, size: 16, color: T.muted),
          ]),
        ),
      ),
    );
  }
}

/// "How well do you know …?" — pick a level (reschedules reviews to match), or remove the word.
/// Resolves to 'removed' when the word was removed.
Future<String?> showWordLevelSheet(BuildContext context, {required String wordKey, required String word}) =>
    showMimiSheet<String>(context, (_) => _WordLevelSheet(wordKey: wordKey, word: word), maxHeightFactor: 0.8);

class _WordLevelSheet extends StatelessWidget {
  final String wordKey;
  final String word;
  const _WordLevelSheet({required this.wordKey, required this.word});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final w = app.words[wordKey];
    if (w == null) return const SizedBox.shrink();
    final current = wordLevel(status: w.status, card: w.card);
    final now = DateTime.now().millisecondsSinceEpoch;
    final review = current >= 1 && current <= 4 ? 'Next practice: ${formatWhen(w.card.due - now)}' : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(
          TextSpan(children: [const TextSpan(text: 'How well do you know '), TextSpan(text: word, style: jp(20, w: FontWeight.w900)), const TextSpan(text: '?')]),
          style: txt(20, w: FontWeight.w900),
        ),
        if (review != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(review, style: txt(14, w: FontWeight.w700, c: T.muted))),
        const SizedBox(height: 12),
        for (final l in [wordLevels[0], wordLevels[4], wordLevels[5]])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Semantics(
              button: true,
              selected: (l.level == 1 ? current >= 1 && current <= 4 : l.level == current),
              label: '${l.label}. ${l.hint}',
              child: Press(
                onTap: () {
                  if (!(l.level == 1 && current >= 1 && current <= 4)) app.setWordLevel(wordKey, l.level);
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: (l.level == 1 ? current >= 1 && current <= 4 : l.level == current) ? T.surface2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: (l.level == 1 ? current >= 1 && current <= 4 : l.level == current) ? T.border : Colors.transparent, width: 2),
                  ),
                  child: Row(children: [
                    LevelBadge(level: l.level, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.level == 1 ? 'Learning' : l.label, style: txt(16, w: FontWeight.w800)),
                        Text(l.level == 1 ? 'Keep this word in my reviews' : l.level == 5 ? 'I know this word' : 'Leave this word out', style: txt(13, w: FontWeight.w600, c: T.muted)),
                      ]),
                    ),
                    if ((l.level == 1 ? current >= 1 && current <= 4 : l.level == current)) const Icon(LucideIcons.check, size: 20, color: T.primary),
                  ]),
                ),
              ),
            ),
          ),
        const Divider(height: 20, color: T.border),
        Semantics(
          button: true,
          label: 'Remove from Vocab',
          child: Press(
            onTap: () {
              app.removeWord(wordKey);
              Navigator.of(context).pop('removed');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                const SizedBox(width: 30, child: Icon(LucideIcons.trash2, size: 20, color: T.danger)),
                const SizedBox(width: 12),
                Text('Remove from Vocab', style: txt(16, w: FontWeight.w800, c: T.danger)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
