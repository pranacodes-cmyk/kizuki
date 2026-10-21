import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Welcome — mirrors src/routes/index.tsx.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.7, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Stack(alignment: Alignment.center, children: [
                    Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: T.primary.withValues(alpha: 0.25), blurRadius: 60)])),
                    const Mascot(MascotPose.listen, size: 224),
                  ]),
                ),
                const SizedBox(height: 8),
                Text('kizuki', style: txt(44, w: FontWeight.w900, h: 1)),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(children: [TextSpan(text: '気づき', style: jp(14, c: T.primary)), const TextSpan(text: '  ·  the moment it clicks')]),
                  style: txt(14, w: FontWeight.w700, c: T.muted),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: 300,
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Done with textbooks? '),
                      TextSpan(text: 'Start understanding real Japanese.', style: txt(24, w: FontWeight.w800, c: T.primary, h: 1.2)),
                    ]),
                    textAlign: TextAlign.center,
                    style: txt(24, w: FontWeight.w800, h: 1.2),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 290,
                  child: Text('Short clips from anime, dramas and vlogs. Tap any word. Remember it for good.', textAlign: TextAlign.center, style: txt(15, w: FontWeight.w400, c: T.muted)),
                ),
              ]),
            ),
            Button3D(label: 'Get started', onPressed: () => context.push('/onboarding')),
            const SizedBox(height: 8),
            Button3D(label: 'I already have an account', variant: BtnVariant.ghost, height: 48, onPressed: () => context.push('/account?mode=signin')),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}
