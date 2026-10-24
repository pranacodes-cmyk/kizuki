import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Daily-goal bar + For You / Explore tabs (top of the Feed) — mirrors FeedHeader.tsx.
class FeedHeader extends StatelessWidget {
  final String tab; // foryou | explore
  const FeedHeader({super.key, required this.tab});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final goal = app.profile.dailyMinutes;
    final sec = app.todayActivity.sec;
    final left = minutesLeft(goal, sec);
    final pct = goalProgress(goal, sec);
    return Container(
      color: T.background,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => Container(
                height: 12,
                decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(99)),
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  width: c.maxWidth * (pct < 0.03 ? 0.03 : pct),
                  decoration: BoxDecoration(color: T.primary, borderRadius: BorderRadius.circular(99)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(left == 0 ? 'Goal done!' : '$left min left', style: txt(13, w: FontWeight.w900, c: left == 0 ? T.gold : T.muted)),
          const SizedBox(width: 4),
          Icon(LucideIcons.trophy, size: 16, color: left == 0 ? T.gold : T.faint),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _HeaderTab(label: 'For You', active: tab == 'foryou', onTap: () => context.go('/feed')),
          const SizedBox(width: 32),
          _HeaderTab(label: 'Explore', active: tab == 'explore', onTap: () => context.go('/explore')),
        ]),
      ]),
    );
  }
}

class _HeaderTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _HeaderTab({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        selected: active,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(children: [
            Text(label, style: txt(16, w: FontWeight.w900, c: active ? T.foreground : T.faint)),
            const SizedBox(height: 6),
            Container(height: 3, width: 48, decoration: BoxDecoration(color: active ? T.primary : Colors.transparent, borderRadius: BorderRadius.circular(99))),
          ]),
        ),
      );
}
