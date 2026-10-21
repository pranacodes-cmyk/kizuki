import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/logic.dart';
import '../services/config.dart';
import '../services/sync_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/ui.dart';

String fmtStudyTime(int sec) => sec < 3600 ? '${sec ~/ 60}m' : '${sec ~/ 3600}h ${(sec % 3600) ~/ 60}m';

final _heat = [T.surface2, T.primary.withValues(alpha: 0.25), T.primary.withValues(alpha: 0.5), T.primary.withValues(alpha: 0.75), T.primary];

/// Profile: streak, stats, activity map, achievements and shortcuts — mirrors src/routes/_app/profile.tsx.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sync = context.watch<SyncService>();
    final stats = app.stats;
    final goal = app.profile.dailyMinutes;
    final weeks = heatmapWeeks(DateTime.now(), 16);
    final today = dayKey(DateTime.now());
    final premium = app.premium;
    final trialDays = premium.trialEndsAt != null ? ((premium.trialEndsAt! - DateTime.now().millisecondsSinceEpoch) / dayMs).ceil().clamp(0, 999) : 0;
    final email = sync.session?.user.email;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.only(bottom: 112), children: [
          SizedBox(
            height: 48,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(tooltip: 'Settings', onPressed: () => context.push('/settings'), icon: const Icon(LucideIcons.settings, size: 24, color: T.muted)),
              const SizedBox(width: 8),
            ]),
          ),
          Center(child: Container(width: 96, height: 96, decoration: const BoxDecoration(color: T.surface, shape: BoxShape.circle), alignment: Alignment.center, child: const Mascot(MascotPose.face, size: 80))),
          const SizedBox(height: 8),
          Center(child: Text(app.profile.name.isEmpty ? 'Learner' : app.profile.name, style: txt(24, w: FontWeight.w900))),
          if (email != null) Center(child: Text(email, style: txt(13, c: T.faint))),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(16)),
            child: IntrinsicHeight(
              child: Row(children: [
                Expanded(child: _Stat(icon: '🔥', value: '${stats.streak}', label: 'Streak')),
                const VerticalDivider(width: 1, color: T.border),
                Expanded(child: _Stat(icon: '📚', value: '${stats.words}', label: 'Words')),
                const VerticalDivider(width: 1, color: T.border),
                Expanded(child: _Stat(icon: '⏰', value: fmtStudyTime(stats.seconds), label: 'Time')),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('Activity'),
              Surface(
                radius: 16,
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var i = 0; i < weeks.length; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Expanded(
                        child: Column(children: [
                          for (var d = 0; d < weeks[i].length; d++) ...[
                            if (d > 0) const SizedBox(height: 3),
                            AspectRatio(
                              aspectRatio: 1,
                              child: Builder(builder: (_) {
                                final key = weeks[i][d];
                                final future = key.compareTo(today) > 0;
                                final lv = future ? -1 : heatLevel(app.activity[key]?.sec ?? 0, goal);
                                return Container(
                                  decoration: BoxDecoration(
                                    color: lv < 0 ? Colors.transparent : _heat[lv],
                                    borderRadius: BorderRadius.circular(3),
                                    border: key == today ? Border.all(color: T.foreground.withValues(alpha: 0.6)) : null,
                                  ),
                                );
                              }),
                            ),
                          ],
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('Less', style: txt(11, c: T.faint)),
                    for (final h in _heat) Container(margin: const EdgeInsets.only(left: 4), width: 10, height: 10, decoration: BoxDecoration(color: h, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 4),
                    Text('More', style: txt(11, c: T.faint)),
                  ]),
                ]),
              ),
              SectionTitle(
                'Achievements',
                right: GestureDetector(
                  onTap: () => context.push('/achievements'),
                  child: Row(children: [Text('View all', style: txt(14, w: FontWeight.w800, c: T.muted)), const Icon(LucideIcons.chevronRight, size: 16, color: T.muted)]),
                ),
              ),
            ]),
          ),
          SizedBox(
            height: 112,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: achievements.length < 8 ? achievements.length : 8,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final a = achievements[i];
                final done = isUnlocked(a, stats);
                return SizedBox(
                  width: 74,
                  child: Column(children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: done ? T.gold.withValues(alpha: 0.2) : T.surface, shape: BoxShape.circle, border: done ? Border.all(color: T.gold, width: 2) : null),
                        child: Opacity(opacity: done ? 1 : 0.5, child: Text(a.icon, style: const TextStyle(fontSize: 28))),
                      ),
                      if (!done)
                        Positioned(right: -2, bottom: -2, child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: T.surface3, shape: BoxShape.circle), child: const Icon(LucideIcons.lock, size: 12))),
                    ]),
                    const SizedBox(height: 6),
                    Text(a.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: txt(11, w: FontWeight.w800, h: 1.15)),
                    if (!done) Text('${metricValue(stats, a.metric).clamp(0, a.goal)}/${a.goal}', style: txt(10, c: T.faint)),
                  ]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(children: [
              premium.active
                  ? _Row(icon: const Icon(LucideIcons.crown, size: 20, color: T.gold), title: 'Kizuki Premium', sub: trialDays > 0 ? 'Free trial · $trialDays day${trialDays == 1 ? '' : 's'} left' : 'Active', onTap: () => context.push('/settings'))
                  : _Row(icon: const Icon(LucideIcons.crown, size: 20, color: T.gold), title: 'Try Premium free', sub: 'Unlimited clips for 7 days', accent: true, onTap: () => context.push('/trial')),
              if (sync.session == null) _Row(icon: const Text('☁️', style: TextStyle(fontSize: 22)), title: 'Save your progress', sub: 'Create a free account to sync devices', onTap: () => context.push('/account')),
              _Row(icon: const Text('🔖', style: TextStyle(fontSize: 22)), title: 'Saved clips', sub: 'Clips you bookmarked', onTap: () => context.push('/saved')),
              _Row(icon: const Text('⏱️', style: TextStyle(fontSize: 22)), title: 'Watch history', sub: "Everything you've watched", onTap: () => context.push('/history')),
              _Row(
                icon: const Text('✉️', style: TextStyle(fontSize: 22)),
                title: 'Contact the founder',
                sub: 'Feedback, ideas or just say hi',
                onTap: () => launchUrl(Uri.parse('mailto:${AppConfig.supportEmail}?subject=Kizuki%20feedback')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String icon, value, label;
  const _Stat({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text('$icon $value', style: txt(20, w: FontWeight.w900)),
        Text(label, style: txt(12, w: FontWeight.w700, c: T.muted)),
      ]);
}

class _Row extends StatelessWidget {
  final Widget icon;
  final String title, sub;
  final VoidCallback onTap;
  final bool accent;
  const _Row({required this.icon, required this.title, required this.sub, required this.onTap, this.accent = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Press(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: accent ? T.gold.withValues(alpha: 0.1) : T.surface,
              borderRadius: BorderRadius.circular(16),
              border: accent ? Border.all(color: T.gold.withValues(alpha: 0.5), width: 2) : null,
            ),
            child: Row(children: [
              SizedBox(width: 36, height: 36, child: Center(child: icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: txt(16, w: FontWeight.w800)),
                  Text(sub, style: txt(13, w: FontWeight.w400, c: T.muted)),
                ]),
              ),
              const Icon(LucideIcons.chevronRight, size: 20, color: T.faint),
            ]),
          ),
        ),
      );
}
