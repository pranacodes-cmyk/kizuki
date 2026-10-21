import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/content.dart';
import '../data/topics.dart';
import '../logic/logic.dart';
import '../theme/tokens.dart';
import '../widgets/clip_card.dart';
import '../widgets/common.dart';
import '../widgets/feed_header.dart';
import '../widgets/ui.dart';

const _sections = [
  ('word', '🔍', 'Search a word', 'Find clips with any Japanese word'),
  ('level', '🎯', 'Difficulty', 'Filter by JLPT level'),
  ('grammar', '📖', 'Grammar', 'Clips that use a pattern'),
  ('topic', '🎬', 'Topic', 'Anime, food, travel & more'),
];

/// Explore: search by word, JLPT level, topic or grammar — mirrors src/routes/_app/explore.tsx.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            const FeedHeader(tab: 'explore'),
            Expanded(child: ContentBuilder(builder: (context, content) => _Explore(content: content))),
          ]),
        ),
      );
}

class _Explore extends StatefulWidget {
  final Content content;
  const _Explore({required this.content});
  @override
  State<_Explore> createState() => _ExploreState();
}

class _ExploreState extends State<_Explore> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String q = '';
  String? level, topic, grammar;
  String? panel; // level | grammar | topic
  late final List<MapEntry<String, int>> topics;
  late final List<MapEntry<String, int>> grammarList;

  @override
  void initState() {
    super.initState();
    final m = <String, int>{};
    for (final c in widget.content.clips) {
      for (final t in c.topics) {
        m[t] = (m[t] ?? 0) + 1;
      }
    }
    topics = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    grammarList = widget.content.grammarIndex().where((e) => e.value >= 2).take(40).toList();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get filtering => q.trim().isNotEmpty || level != null || topic != null || grammar != null;

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final results = filtering ? searchClips(content.clips, q, level: level, topic: topic, grammar: grammar) : const <String>[];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _text,
            focusNode: _focus,
            maxLength: 60,
            onChanged: (v) => setState(() => q = v),
            style: txt(16, w: FontWeight.w700),
            cursorColor: T.primary,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              hintText: 'English, Japanese or romaji',
              hintStyle: txt(16, w: FontWeight.w700, c: T.faint),
              prefixIcon: const Icon(LucideIcons.search, size: 20, color: T.faint),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => setState(() {
                        _text.clear();
                        q = '';
                      }),
                      icon: const Icon(LucideIcons.x, size: 20, color: T.faint),
                    ),
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
              MimiChip(active: level != null || panel == 'level', onTap: () => setState(() => panel = panel == 'level' ? null : 'level'), child: Text('🎯 ${level ?? 'Level'}')),
              const SizedBox(width: 8),
              MimiChip(active: topic != null || panel == 'topic', onTap: () => setState(() => panel = panel == 'topic' ? null : 'topic'), child: Text(topic != null ? '${topicEmoji(topic!)} ${topicLabel(topic!)}' : '🎬 Topic')),
              const SizedBox(width: 8),
              MimiChip(active: grammar != null || panel == 'grammar', onTap: () => setState(() => panel = panel == 'grammar' ? null : 'grammar'), child: Text('📖 ${grammar ?? 'Grammar'}')),
              if (level != null || topic != null || grammar != null) ...[
                const SizedBox(width: 8),
                MimiChip(onTap: () => setState(() {
                      level = topic = grammar = null;
                      panel = null;
                    }), child: const Text('Clear')),
              ],
            ]),
          ),
          if (panel == 'level')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                for (var i = 0; i < jlptLevels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Press(
                      onTap: () => setState(() {
                        level = level == jlptLevels[i] ? null : jlptLevels[i];
                        panel = null;
                      }),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: level == jlptLevels[i] ? T.primary.withValues(alpha: 0.15) : T.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: level == jlptLevels[i] ? T.primary : T.border, width: 2),
                        ),
                        child: Text(jlptLevels[i], style: txt(15, w: FontWeight.w900, c: level == jlptLevels[i] ? T.primary : T.foreground)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          if (panel == 'topic')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in topics)
                  MimiChip(
                    active: topic == t.key,
                    onTap: () => setState(() {
                      topic = topic == t.key ? null : t.key;
                      panel = null;
                    }),
                    child: Text.rich(TextSpan(children: [TextSpan(text: '${topicEmoji(t.key)} ${topicLabel(t.key)} '), TextSpan(text: '${t.value}', style: txt(14, c: T.faint))])),
                  ),
              ]),
            ),
          if (panel == 'grammar')
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final g in grammarList)
                    MimiChip(
                      active: grammar == g.key,
                      onTap: () => setState(() {
                        grammar = grammar == g.key ? null : g.key;
                        panel = null;
                      }),
                      child: Text.rich(TextSpan(children: [TextSpan(text: '${g.key} ', style: jp(14, c: grammar == g.key ? T.primary : T.muted)), TextSpan(text: '${g.value}', style: txt(14, c: T.faint))])),
                    ),
                ]),
              ),
            ),
        ]),
      ),
      Expanded(
        child: !filtering
            ? ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 112), children: [
                Row(children: [
                  const Mascot(MascotPose.read, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Explore ${content.clips.length} clips', style: txt(20, w: FontWeight.w900)),
                      Text('Search and filter to find exactly what you want to hear.', style: txt(14, w: FontWeight.w400, c: T.muted)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    for (final s in _sections)
                      Press(
                        onTap: () => s.$1 == 'word' ? _focus.requestFocus() : setState(() => panel = s.$1),
                        child: Surface(
                          radius: 16,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.$2, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 8),
                            Text(s.$3, style: txt(16, w: FontWeight.w800)),
                            Text(s.$4, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(13, w: FontWeight.w400, c: T.muted, h: 1.25)),
                          ]),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                caps('Popular topics'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final t in topics.take(10)) MimiChip(onTap: () => setState(() => topic = t.key), child: Text('${topicEmoji(t.key)} ${topicLabel(t.key)}')),
                ]),
              ])
            : results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(children: [
                      const Mascot(MascotPose.think, size: 96),
                      const SizedBox(height: 8),
                      Text('No clips found', style: txt(17, w: FontWeight.w900)),
                      Text('Try another word or remove a filter.', style: txt(14, w: FontWeight.w400, c: T.muted)),
                    ]),
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Text('${results.length} clip${results.length == 1 ? '' : 's'}', style: txt(13, w: FontWeight.w700, c: T.muted))),
                    Expanded(child: ClipGrid(content: content, ids: results.take(60).toList(), empty: '', highlight: q.trim(), padding: const EdgeInsets.fromLTRB(16, 8, 16, 112))),
                  ]),
      ),
    ]);
  }
}
