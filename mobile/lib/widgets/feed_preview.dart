import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/content.dart';
import '../data/models.dart' as m;
import '../screens/plan.dart' show previewOrder;
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'clip_view.dart';
import 'feed_pager.dart';
import 'ui.dart';
import '../i18n/i18n.dart';

/// The actual personalized home feed, scaled into the trial phone. No animation,
/// simulated captions, or geometry callbacks: only the settled clip has a player.
/// Mirrors FeedPreview.tsx and reuses the same player/transcript as the home screen.
class FeedPreview extends StatefulWidget {
  const FeedPreview({super.key});
  @override
  State<FeedPreview> createState() => _FeedPreviewState();
}

class _FeedPreviewState extends State<FeedPreview> {
  Content? _content;
  List<m.Clip> _clips = const [];
  int _active = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Content.load().then((c) {
      if (!mounted) return;
      final clips = previewOrder(c, context.read<AppState>()).take(12)
          .map((id) => c.byId[id]).whereType<m.Clip>().toList();
      setState(() { _content = c; _clips = clips; });
    }, onError: (_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _content;
    if (c == null || _clips.isEmpty) {
      return ColoredBox(color: T.stage, child: Center(child: _failed
          ? Text(tr('Your clips will appear on Home'), textAlign: TextAlign.center, style: txt(13, c: T.muted))
          : const CircularProgressIndicator(color: T.primary)));
    }
    return LayoutBuilder(builder: (_, bounds) {
      final scale = bounds.maxWidth / 360;
      if (scale <= 0 || bounds.maxHeight <= 0) return const SizedBox.shrink();
      return FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(width: 360, height: bounds.maxHeight / scale,
          child: ColoredBox(color: T.background, child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
              Text(tr('For you'), style: txt(18, w: FontWeight.w900)),
              const Spacer(), const Icon(LucideIcons.flame, color: T.primary, size: 20),
            ])),
            Expanded(child: FeedPager(
              itemCount: _clips.length,
              onSettled: (i) => setState(() => _active = i),
              itemBuilder: (_, i) => ClipView(key: ValueKey('trial-${_clips[i].id}'),
                clip: _clips[i], content: c, active: i == _active,
                inFeed: true, bottomInset: 12),
            )),
            Container(height: 48, color: T.surface, child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Icon(LucideIcons.play, color: T.primary, size: 20),
                Icon(LucideIcons.search, color: T.faint, size: 20),
                Icon(LucideIcons.bookmark, color: T.faint, size: 20),
                Icon(LucideIcons.user, color: T.faint, size: 20),
              ])),
          ])),
        ),
      );
    });
  }
}
