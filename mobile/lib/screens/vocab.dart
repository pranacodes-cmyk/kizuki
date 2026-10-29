import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../services/tts.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/saved_word_sheet.dart';
import '../widgets/tour.dart';
import '../widgets/ui.dart';
import '../widgets/word_level.dart';
import '../i18n/i18n.dart';

final _hira = kanaDeck('hiragana');
final _kata = kanaDeck('katakana');

/// Your words + decks — mirrors src/routes/_app/vocab.tsx.
class VocabScreen extends StatefulWidget {
  const VocabScreen({super.key});
  @override
  State<VocabScreen> createState() => _VocabScreenState();
}

class _VocabScreenState extends State<VocabScreen> {
  String filter = 'all';
  final _text = TextEditingController();
  String q = '';
  Content? content;

  @override
  void initState() {
    super.initState();
    Content.load().then((c) {
      if (mounted) setState(() => content = c);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final counts = app.counts;
    final now = DateTime.now().millisecondsSinceEpoch;
    final nq = normalizeQuery(q);
    final all = app.words.values.where((w) => w.status != 'removed').toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    final list = all.where((w) {
      final st = w.status == 'ignored' ? 'ignored' : wordStatus(status: w.status, card: w.card);
      if (filter == 'due' && !(w.status == 'learning' && isDue(w.card, now))) return false;
      if (filter == 'learning' && st != 'learning') return false;
      if (filter == 'known' && st != 'known') return false;
      if (nq.isNotEmpty && ![w.word, w.reading, w.surface].any((f) => normalizeQuery(f).contains(nq)) && !w.romaji.toLowerCase().contains(nq) && !w.gloss.toLowerCase().contains(nq) && !w.glossIn(content).toLowerCase().contains(nq)) return false;
      return true;
    }).toList();
    final today = dayKey(DateTime.now());
    final yest = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final groups = <(String, List<SavedWord>)>[];
    for (final w in list) {
      final d = DateTime.fromMillisecondsSinceEpoch(w.addedAt);
      final k = dayKey(d);
      final label = k == today ? tr('Today') : (k == yest ? tr('Yesterday') : DateFormat.MMMd().format(d));
      if (groups.isNotEmpty && groups.last.$1 == label) {
        groups.last.$2.add(w);
      } else {
        groups.add((label, [w]));
      }
    }
    final hiraDue = kanaQueue(_hira, app.kana, now).length;
    final kataDue = kanaQueue(_kata, app.kana, now).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 112), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${counts.known}', style: txt(52, w: FontWeight.w900, h: 1)),
                const SizedBox(height: 4),
                Text(tr('Words you know'), style: txt(16, w: FontWeight.w800, c: T.muted)),
              ]),
            ),
            const Mascot(MascotPose.read, size: 80),
          ]),
          const SizedBox(height: 16),
          if (counts.due > 0)
            TourAnchor(id: 'reviewButton', child: Button3D(label: trn(counts.due, '{n} card to review', '{n} cards to review'), onPressed: () => context.push('/review?deck=words')))
          else
            Surface(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: double.infinity,
                child: Column(children: [
                  Text(counts.saved > 0 ? tr('Done reviewing for today 🎉') : tr('Tap words in clips to save them'), textAlign: TextAlign.center, style: txt(16, w: FontWeight.w800)),
                  Text(counts.saved > 0 ? tr('{learning} learning · {known} known', {'learning': counts.learning, 'known': counts.known}) : tr("They'll show up here, ready to review."), textAlign: TextAlign.center, style: txt(13, w: FontWeight.w400, c: T.muted)),
                  if (counts.learning > 0) TextButton(onPressed: () => context.push('/review?deck=words&mode=extra'), child: Text(tr('Keep studying'), style: txt(14, w: FontWeight.w800, c: T.primary))),
                ]),
              ),
            ),
          const SizedBox(height: 24),
          caps(tr('Decks')),
          const SizedBox(height: 8),
          _DeckRow(icon: '🔖', title: tr('Your words'), sub: tr('{saved} saved from clips', {'saved': counts.saved}), badge: counts.due, onTap: counts.due > 0 ? () => context.push('/review?deck=words') : null),
          const SizedBox(height: 8),
          // The welcome tour's "kanaDecks" step spotlights both alphabet decks together.
          TourAnchor(
            id: 'kanaDecks',
            child: Column(children: [
              _DeckRow(icon: 'あ', title: tr('Hiragana'), sub: tr('{known} / {total} known', {'known': kanaLearned(_hira, app.kana), 'total': _hira.length}), badge: hiraDue, onTap: () => context.push('/review?deck=hiragana')),
              const SizedBox(height: 8),
              _DeckRow(icon: 'ア', title: tr('Katakana'), sub: tr('{known} / {total} known', {'known': kanaLearned(_kata, app.kana), 'total': _kata.length}), badge: kataDue, onTap: () => context.push('/review?deck=katakana')),
            ]),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _text,
            maxLength: 40,
            onChanged: (v) => setState(() => q = v),
            style: txt(16, w: FontWeight.w700),
            cursorColor: T.primary,
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              hintText: tr('Search your words'),
              hintStyle: txt(16, w: FontWeight.w700, c: T.faint),
              prefixIcon: const Icon(LucideIcons.search, size: 20, color: T.faint),
              suffixIcon: q.isEmpty ? null : IconButton(tooltip: tr('Clear'), onPressed: () => setState(() {
                    _text.clear();
                    q = '';
                  }), icon: const Icon(LucideIcons.x, size: 20, color: T.faint)),
              filled: true,
              fillColor: T.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: T.border, width: 2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: T.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in [('all', tr('All {saved}', {'saved': counts.saved})), ('due', tr('To Review {due}', {'due': counts.due})), ('known', tr('Known {known}', {'known': counts.known}))]) ...[
                MimiChip(active: filter == f.$1, onTap: () => setState(() => filter = f.$1), child: Text(tr(f.$2))),
                const SizedBox(width: 8),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(children: [
                const Mascot(MascotPose.think, size: 80),
                const SizedBox(height: 8),
                Text(counts.saved > 0 ? tr('No words match.') : tr('No words yet — watch a clip and tap any word.'), textAlign: TextAlign.center, style: txt(15, w: FontWeight.w700, c: T.muted)),
                if (counts.saved == 0) Padding(padding: const EdgeInsets.only(top: 12), child: Button3D(label: tr('Go to the feed'), variant: BtnVariant.surface, height: 48, expand: false, onPressed: () => context.go('/feed'))),
              ]),
            ),
          for (final g in groups) ...[
            Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Text(tr(g.$1), style: txt(14, w: FontWeight.w800, c: T.muted))),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                for (var i = 0; i < g.$2.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: T.border),
                  _WordRow(w: g.$2[i], gloss: g.$2[i].glossIn(content), onOpen: () => showSavedWord(context, g.$2[i], content)),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  final SavedWord w;
  final String gloss;
  final VoidCallback onOpen;
  const _WordRow({required this.w, required this.gloss, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final level = wordLevel(status: w.status, card: w.card);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Row(children: [
              LevelBadge(level: level, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: w.word),
                      if (w.reading.isNotEmpty && w.reading != w.word) TextSpan(text: '  ${w.reading}', style: jp(13, c: T.faint)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jp(17),
                  ),
                  Text(gloss, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(13, w: FontWeight.w400, c: T.muted)),
                ]),
              ),
            ]),
          ),
        ),
        IconButton(tooltip: tr('Play {word}', {'word': w.word}), onPressed: () => Tts.speak(w.reading.isNotEmpty ? w.reading : w.word), icon: const Icon(LucideIcons.volume2, size: 16, color: T.faint)),
      ]),
    );
  }
}

class _DeckRow extends StatelessWidget {
  final String icon, title, sub;
  final int badge;
  final VoidCallback? onTap;
  const _DeckRow({required this.icon, required this.title, required this.sub, required this.badge, this.onTap});
  @override
  Widget build(BuildContext context) => Press(
        onTap: onTap ?? () {},
        child: Surface(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Container(width: 44, height: 44, alignment: Alignment.center, decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(12)), child: Text(icon, style: jp(22, w: FontWeight.w900))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(title), style: txt(16, w: FontWeight.w800)),
                Text(tr(sub), style: txt(13, w: FontWeight.w400, c: T.muted)),
              ]),
            ),
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: T.primary, borderRadius: BorderRadius.circular(99)),
                child: Text('$badge', style: txt(12, w: FontWeight.w900, c: T.primaryFg)),
              ),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronRight, size: 20, color: T.faint),
          ]),
        ),
      );
}
