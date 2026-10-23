import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart' as m;
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'ui.dart';

/// Thumbnail card linking to a single clip (Explore, Saved, History) — mirrors ClipCard.tsx.
class ClipCard extends StatelessWidget {
  final m.Clip clip;
  final String? highlight;
  const ClipCard({super.key, required this.clip, this.highlight});
  @override
  Widget build(BuildContext context) {
    final seen = context.select<AppState, bool>((a) => (a.seen[clip.id] ?? 0) > 0);
    final dur = clip.duration.round();
    final h = highlight;
    final line = (h != null && h.isNotEmpty ? clip.lines.where((l) => l.ja.contains(h)).firstOrNull : null) ?? (clip.lines.isEmpty ? null : clip.lines.first);
    Widget badge(String s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: T.stage.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
          child: Text(s, style: txt(11, w: FontWeight.w900)),
        );
    return Press(
      onTap: () => context.push('/clip/${clip.id}'),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipThumb(clip.thumb),
            Positioned(right: 6, bottom: 6, child: badge('0:${dur.toString().padLeft(2, '0')}')),
            Positioned(left: 6, top: 6, child: badge('JLPT ${clip.level}')),
            if (seen)
              Positioned(
                right: 6,
                top: 6,
                child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: T.success, shape: BoxShape.circle), child: const Icon(LucideIcons.check, size: 12, color: T.primaryFg)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line?.ja ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: jp(14)),
              Text(clip.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: txt(12, w: FontWeight.w400, c: T.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Two-column grid of clip cards with an empty state — mirrors ClipGrid.
class ClipGrid extends StatelessWidget {
  final Content content;
  final List<String> ids;
  final String empty;
  final String? highlight;
  final EdgeInsets padding;
  const ClipGrid({super.key, required this.content, required this.ids, required this.empty, this.highlight, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32)});
  @override
  Widget build(BuildContext context) {
    final clips = ids.map((id) => content.byId[id]).whereType<m.Clip>().toList();
    if (clips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 64),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Mascot(MascotPose.think, size: 96),
            const SizedBox(height: 8),
            Text(empty, textAlign: TextAlign.center, style: txt(15, w: FontWeight.w700, c: T.muted)),
          ]),
        ),
      );
    }
    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.98),
      itemCount: clips.length,
      itemBuilder: (_, i) => ClipCard(clip: clips[i], highlight: highlight),
    );
  }
}
