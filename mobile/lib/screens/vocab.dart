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
import '../widgets/ui.dart';

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
      if (nq.isNotEmpty && ![w.word, w.reading, w.surface].any((f) => normalizeQuery(f).contains(nq)) && !w.romaji.toLowerCase().contains(nq) && !w.gloss.toLowerCase().contains(nq)) return false;
      return true;
    }).toList();
    final today = dayKey(DateTime.now());
    final yest = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final groups = <(String, List<SavedWord>)>[];
    for (final w in list) {
      final d = DateTime.fromMillisecondsSinceEpoch(w.addedAt);
      final k = dayKey(d);
      final label = k == today ? 'Today' : (k == yest ? 'Yesterday' : DateFormat('MMM d').format(d));
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
                Text('Japanese words you know 🇯🇵', style: txt(16, w: FontWeight.w800, c: T.muted)),
              ]),
            ),
            const Mascot(MascotPose.read, size: 80),
          ]),
          const SizedBox(height: 16),
          if (counts.due > 0)
            Button3D(label: '${counts.due} card${counts.due == 1 ? '' : 's'} to review', onPressed: () => context.push('/review?deck=words'))
          else
            Surface(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: SizedBox(
                width: double.infinity,
                child: Column(children: [
                  Text(counts.saved > 0 ? 'Done reviewing for today 🎉' : 'Tap words in clips to save them', textAlign: TextAlign.center, style: txt(16, w: FontWeight.w800)),
                  Text(counts.saved > 0 ? '${counts.learning} learning · ${counts.known} known' : "They'll show up here, ready to review.", textAlign: TextAlign.center, style: txt(13, w: FontWeight.w400, c: T.muted)),
                  if (counts.learning > 0) TextButton(onPressed: () => context.push('/review?deck=words&mode=extra'), child: Text('Keep studying', style: txt(14, w: FontWeight.w800, c: T.primary))),
                ]),
              ),
            ),
          const SizedBox(height: 24),
          caps('Decks'),
          const SizedBox(height: 8),
          _DeckRow(icon: '🔖', title: 'Your words', sub: '${counts.saved} saved from clips', badge: counts.due, onTap: counts.due > 0 ? () => context.push('/review?deck=words') : null),
          const SizedBox(height: 8),
          _DeckRow(icon: 'あ', title: 'Hiragana', sub: '${kanaLearned(_hira, app.kana)} / ${_hira.length} learned', badge: hiraDue, onTap: () => context.push('/review?deck=hiragana')),
          const SizedBox(height: 8),
          _DeckRow(icon: 'ア', title: 'Katakana', sub: '${kanaLearned(_kata, app.kana)} / ${_kata.length} learned', badge: kataDue, onTap: () => context.push('/review?deck=katakana')),
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
              hintText: 'Search your words',
              hintStyle: txt(16, w: FontWeight.w700, c: T.faint),
              prefixIcon: const Icon(LucideIcons.search, size: 20, color: T.faint),
              suffixIcon: q.isEmpty ? null : IconButton(tooltip: 'Clear', onPressed: () => setState(() {
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
              for (final f in [('all', 'All ${counts.saved}'), ('due', 'Due ${counts.due}'), ('learning', 'Learning ${counts.learning}'), ('known', 'Known ${counts.known}')]) ...[
                MimiChip(active: filter == f.$1, onTap: () => setState(() => filter = f.$1), child: Text(f.$2)),
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
                Text(counts.saved > 0 ? 'No words match.' : 'No words yet — watch a clip and tap any word.', textAlign: TextAlign.center, style: txt(15, w: FontWeight.w700, c: T.muted)),
                if (counts.saved == 0) Padding(padding: const EdgeInsets.only(top: 12), child: Button3D(label: 'Go to the feed', variant: BtnVariant.surface, height: 48, expand: false, onPressed: () => context.go('/feed'))),
              ]),
            ),
          for (final g in groups) ...[
            Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Text(g.$1, style: txt(14, w: FontWeight.w800, c: T.muted))),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                for (var i = 0; i < g.$2.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: T.border),
                  _WordRow(w: g.$2[i], onOpen: () => showSavedWord(context, g.$2[i], content)),
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
  final VoidCallback onOpen;
  const _WordRow({required this.w, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final st = w.status == 'ignored' ? 'ignored' : wordStatus(status: w.status, card: w.card);
    final dot = st == 'known' ? T.success : (st == 'ignored' ? T.surface3 : T.learning);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: Row(children: [
              Semantics(label: st, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: dot, shape: BoxShape.circle))),
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
                  Text(w.gloss, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(13, w: FontWeight.w400, c: T.muted)),
                ]),
              ),
            ]),
          ),
        ),
        IconButton(tooltip: 'Play ${w.word}', onPressed: () => Tts.speak(w.reading.isNotEmpty ? w.reading : w.word), icon: const Icon(LucideIcons.volume2, size: 16, color: T.faint)),
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
                Text(title, style: txt(16, w: FontWeight.w800)),
                Text(sub, style: txt(13, w: FontWeight.w400, c: T.muted)),
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
