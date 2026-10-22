import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/paywall.dart';
import '../data/tour.dart' show TourEvent;
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/clip_view.dart';
import '../widgets/common.dart';
import '../widgets/feed_header.dart';
import '../widgets/feed_pager.dart';
import '../widgets/tour.dart';
import '../widgets/ui.dart';
import 'plan.dart' show feedOrder;

/// For You feed: vertical swipe through personal clips — mirrors src/routes/_app/feed.tsx.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            const FeedHeader(tab: 'foryou'),
            Expanded(child: ContentBuilder(loadingLabel: 'Finding clips for you…', builder: (context, content) => _Feed(content: content))),
          ]),
        ),
      );
}

class _Feed extends StatefulWidget {
  final Content content;
  const _Feed({required this.content});
  @override
  State<_Feed> createState() => _FeedState();
}

class _FeedState extends State<_Feed> {
  int active = 0;
  late final List<String> order;
  int? lockedFrom;

  @override
  void initState() {
    super.initState();
    // Order fixed for this visit (re-ranked on the next one, so it never reshuffles under you).
    order = feedOrder(widget.content, context.read<AppState>());
    _checkLock();
  }

  /// Free-tier lock is decided when you arrive on a clip, so the clip you're watching never locks mid-way.
  void _checkLock() {
    final app = context.read<AppState>();
    if (app.premium.active) {
      lockedFrom = null;
      return;
    }
    if (lockedFrom == null && !canWatchClip(app.premium.active, app.todayActivity.clips, freeDailyClips)) lockedFrom = active + 1;
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.select<AppState, bool>((a) => a.premium.active);
    context.select<AppState, int>((a) => a.todayActivity.clips);
    if (premium && lockedFrom != null) lockedFrom = null;
    if (!premium) _checkLock();
    // One swipe = one clip; the active clip is set when the feed settles, so a drag that
    // springs back never flips clips or starts the next one (widgets/feed_pager.dart).
    return FeedPager(
      itemCount: order.length,
      onSettled: (page) {
        setState(() {
          active = page;
          _checkLock();
        });
        Tour.I.emit(TourEvent.swipe);
      },
      itemBuilder: (context, i) {
        if ((i - active).abs() > 1) return const SizedBox.expand();
        if (lockedFrom != null && i >= lockedFrom!) return const _LimitCard();
        final clip = widget.content.byId[order[i]];
        if (clip == null) return const SizedBox.expand();
        return ClipView(key: ValueKey(clip.id), clip: clip, content: widget.content, active: i == active, tourTargets: true, inFeed: true);
      },
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 96),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Mascot(MascotPose.heart, size: 128),
          const SizedBox(height: 12),
          Text('You watched your $freeDailyClips free clips today!', textAlign: TextAlign.center, style: txt(24, w: FontWeight.w900, h: 1.2)),
          const SizedBox(height: 8),
          Text('Great work. Review your words now, or unlock unlimited clips with a free week of Premium.', textAlign: TextAlign.center, style: txt(15, w: FontWeight.w400, c: T.muted)),
          const SizedBox(height: 24),
          Button3D(label: 'Try Premium free', onPressed: () => context.push('/trial')),
          const SizedBox(height: 12),
          Button3D(label: 'Review my words', variant: BtnVariant.surface, onPressed: () => context.go('/vocab')),
        ]),
      );
}
