import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/clip_card.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

void _back(BuildContext context) => context.canPop() ? context.pop() : context.go('/profile');

/// Watch history — mirrors src/routes/history.tsx.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().history;
    final ids = <String>{for (final h in history) h.clipId}.toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('Watch history'), onBack: () => _back(context)),
          Expanded(child: ContentBuilder(builder: (_, c) => ClipGrid(content: c, ids: ids.where((id) => c.byId.containsKey(id)).toList(), empty: tr('Clips you watch will show up here.')))),
        ]),
      ),
    );
  }
}

/// Saved clips — mirrors src/routes/saved.tsx.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final saved = context.watch<AppState>().savedClips;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('Saved clips'), onBack: () => _back(context)),
          Expanded(child: ContentBuilder(builder: (_, c) => ClipGrid(content: c, ids: saved.where((id) => c.byId.containsKey(id)).toList(), empty: tr('Tap the bookmark on any clip to save it here.')))),
        ]),
      ),
    );
  }
}

/// All achievements — mirrors src/routes/achievements.tsx.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final stats = context.watch<AppState>().stats;
    final unlocked = achievements.where((a) => isUnlocked(a, stats)).length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('Achievements'), onBack: () => _back(context)),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12), child: Text(tr('{unlocked} of {total} unlocked', {'unlocked': unlocked, 'total': achievements.length}), style: txt(15, w: FontWeight.w700, c: T.muted))),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.88),
              itemCount: achievements.length,
              itemBuilder: (_, i) {
                final a = achievements[i];
                final done = isUnlocked(a, stats);
                final v = metricValue(stats, a.metric).clamp(0, a.goal);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: done ? T.gold.withValues(alpha: 0.1) : T.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: done ? Border.all(color: T.gold.withValues(alpha: 0.5), width: 2) : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Opacity(opacity: done ? 1 : 0.5, child: Text(a.icon, style: const TextStyle(fontSize: 32))),
                      const Spacer(),
                      if (!done) const Icon(LucideIcons.lock, size: 16, color: T.faint),
                    ]),
                    const SizedBox(height: 8),
                    Text(tr(a.title), style: txt(15, w: FontWeight.w800)),
                    Text(tr(a.desc), maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(12, w: FontWeight.w400, c: T.muted)),
                    const Spacer(),
                    if (!done) ...[
                      ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: v / a.goal, minHeight: 6, backgroundColor: T.surface2, color: T.primary)),
                      const SizedBox(height: 4),
                      Text('$v / ${a.goal}', style: txt(11, c: T.faint)),
                    ],
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
