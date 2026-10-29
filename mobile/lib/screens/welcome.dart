import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/mascot_motion.dart';
import '../theme/tokens.dart';
import '../widgets/lively_mascot.dart';
import '../widgets/ui.dart';
import '../i18n/i18n.dart';

/// Welcome — mirrors src/routes/index.tsx. The fox springs in once the splash fades, floats
/// with a breathing glow, and hops when tapped.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // Root screen: a stray back press must not close the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) confirmAppExit(context);
      },
      child: Scaffold(
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const LivelyMascot(MascotPose.listen, size: 224, idle: MascotIdle.float, entrance: true, tappable: true, halo: true),
                const SizedBox(height: 8),
                FadeUp(delayMs: 150, child: Text('kizuki', style: txt(44, w: FontWeight.w900, h: 1))),
                const SizedBox(height: 6),
                FadeUp(
                  delayMs: 200,
                  dy: 0,
                  child: Text.rich(
                    TextSpan(children: [TextSpan(text: '気づき', style: jp(14, c: T.primary)), TextSpan(text: '  ·  ${tr('the moment it clicks')}')]),
                    style: txt(14, w: FontWeight.w700, c: T.muted),
                  ),
                ),
                const SizedBox(height: 14),
                FadeUp(
                  delayMs: 250,
                  child: SizedBox(
                    width: 300,
                    child: Text.rich(
                      TextSpan(children: trSpans('Done with textbooks? [Start understanding real Japanese.]', txt(24, w: FontWeight.w800, c: T.primary, h: 1.2))),
                      textAlign: TextAlign.center,
                      style: txt(24, w: FontWeight.w800, h: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeUp(
                  delayMs: 350,
                  dy: 0,
                  child: SizedBox(
                    width: 290,
                    child: Text(tr('Short clips from anime, dramas and vlogs. Tap any word. Remember it for good.'), textAlign: TextAlign.center, style: txt(15, w: FontWeight.w400, c: T.muted)),
                  ),
                ),
              ]),
            ),
            Button3D(label: tr('Get started'), onPressed: () => context.push('/onboarding')),
            const SizedBox(height: 8),
            Button3D(label: tr('I already have an account'), variant: BtnVariant.ghost, height: 48, onPressed: () => context.push('/account?mode=signin')),
            const SizedBox(height: 8),
          ]),
        ),
      ),
      ),
    );
  }
}
