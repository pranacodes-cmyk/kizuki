import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../logic/logic.dart';
import '../services/haptics.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/lively_mascot.dart';
import '../widgets/ui.dart';

/// Feed order for this learner (shared rankFeed rule) — mirrors src/lib/feed.ts.
/// For You order: the curated starter clips first (same for everyone, until watched), then the
/// personal ranking — shared rules starterFeedOrder + rankFeed (mirrors src/lib/feed.ts).
List<String> feedOrder(Content c, AppState s) => starterFeedOrder(
      rankFeed(c.rankClips, reasonList: s.profile.reasons, jlpt: s.profile.jlpt, seen: s.seen, seed: s.feedSeed),
      c.starter,
      seen: s.seen,
      watched: s.totalClips,
      jlpt: s.profile.jlpt,
    );

/// The onboarding phone preview: the starter clips for everyone, in order (no level or history).
List<String> previewOrder(Content c, AppState s) =>
    starterFeedOrder(rankFeed(c.rankClips, reasonList: s.profile.reasons, jlpt: s.profile.jlpt, seen: s.seen, seed: s.feedSeed), c.starter);

int levelFitCount(Content c, String jlpt) => c.clips.where((x) => (jlptIndex(x.level) - jlptIndex(jlpt)).abs() <= 1).length;

/// "Your plan is ready" — mirrors src/routes/plan.tsx. Arrives with a celebration tap in step
/// with the confetti; the fox springs in and cheers.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Haptics.celebrate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.profile;
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          child: ContentBuilder(builder: (context, content) {
            final first = feedOrder(content, app).take(3).map((id) => content.byId[id]).whereType<Object>().toList();
            final items = planItems(
              reasonList: p.reasons,
              challengeList: p.challenges,
              dailyMinutes: p.dailyMinutes,
              window: p.window,
              streakGoal: p.streakGoal,
              jlpt: p.jlpt,
              clipCount: levelFitCount(content, p.jlpt),
            );
            return Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 16), children: [
                  const Center(child: LivelyMascot(MascotPose.cheer, size: 80, entrance: true, hopAfterMs: 450, tappable: true)),
                  const SizedBox(height: 12),
                  Text(p.name.isNotEmpty ? '${p.name}, your plan is ready!' : 'Your plan is ready!', textAlign: TextAlign.center, style: txt(26, w: FontWeight.w900, h: 1.2)),
                  const SizedBox(height: 12),
                  Center(child: Pill('🇯🇵 Conversational by ${goalDateLabel(DateTime.now(), p.fluencyMonths)}', tone: PillTone.success)),
                  const SizedBox(height: 24),
                  for (var i = 0; i < items.length; i++)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: 300 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Surface(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          radius: 16,
                          child: Row(children: [
                            Text(items[i].icon, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(items[i].title, style: txt(16, w: FontWeight.w800)),
                                Text(items[i].body, style: txt(13, w: FontWeight.w400, c: T.muted)),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  if (first.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    caps('Your first clips'),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final id in feedOrder(content, app).take(3))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                color: T.surface,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  ClipThumb(content.byId[id]!.thumb),
                                  Padding(padding: const EdgeInsets.all(8), child: Text(content.byId[id]!.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: txt(11, h: 1.2))),
                                ]),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ],
                ]),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Button3D(label: 'Continue', onPressed: () => context.push('/founder'))),
            ]);
          }),
        ),
        const Positioned.fill(child: Confetti()),
      ]),
    );
  }
}
