import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/paywall.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/clip_view.dart';
import '../widgets/common.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

/// A single clip (from Explore, Saved, History, "hear it again") — mirrors src/routes/clip.$clipId.tsx.
class ClipScreen extends StatefulWidget {
  final String clipId;
  const ClipScreen({super.key, required this.clipId});
  @override
  State<ClipScreen> createState() => _ClipScreenState();
}

class _ClipScreenState extends State<ClipScreen> {
  late final bool allowed;

  @override
  void initState() {
    super.initState();
    // Lock decided on arrival only — the clip never locks while you're watching it.
    final app = context.read<AppState>();
    allowed = canWatchClip(app.premium.active, app.todayActivity.clips, freeDailyClips);
  }

  void _back() => context.canPop() ? context.pop() : context.go('/feed');

  @override
  Widget build(BuildContext context) {
    final premium = context.select<AppState, bool>((a) => a.premium.active);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentBuilder(builder: (context, content) {
          final clip = content.byId[widget.clipId];
          return Column(children: [
            TopBar(onBack: _back, title: clip?.title ?? ''),
            Expanded(
              child: clip == null
                  ? ErrorState(title: tr('Clip not found'), body: tr('It may have been removed from the library.'))
                  : (allowed || premium)
                      ? ClipView(clip: clip, content: content, active: true, bottomInset: 24)
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Mascot(MascotPose.heart, size: 112),
                            const SizedBox(height: 12),
                            Text(tr("That's your {n} free clips for today", {'n': freeDailyClips}), textAlign: TextAlign.center, style: txt(22, w: FontWeight.w900, h: 1.2)),
                            const SizedBox(height: 8),
                            Text(tr('Come back tomorrow, or unlock every clip with a free week of Premium.'), textAlign: TextAlign.center, style: txt(15, w: FontWeight.w400, c: T.muted)),
                            const SizedBox(height: 24),
                            Button3D(label: tr('Try Premium free'), onPressed: () => context.push('/trial')),
                          ]),
                        ),
            ),
          ]);
        }),
      ),
    );
  }
}
