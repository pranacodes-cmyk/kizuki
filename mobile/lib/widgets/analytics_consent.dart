import 'package:flutter/material.dart';
import '../services/analytics.dart';
import '../theme/tokens.dart';
import 'ui.dart';

class AnalyticsConsent extends StatelessWidget {
  const AnalyticsConsent({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool?>(
    valueListenable: Analytics.choice,
    builder: (context, choice, _) => choice != null ? const SizedBox.shrink() : Positioned.fill(
      child: ColoredBox(color: T.background.withValues(alpha: 0.9), child: SafeArea(
        child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Usage analytics', style: txt(24, w: FontWeight.w900)),
          const SizedBox(height: 16),
          Text(Analytics.notice, style: txt(15, c: T.muted, h: 1.5)),
          const SizedBox(height: 24),
          Button3D(label: 'Allow analytics', variant: BtnVariant.surface, onPressed: () => Analytics.setChoice(true)),
          const SizedBox(height: 12),
          Button3D(label: 'No thanks', variant: BtnVariant.surface, onPressed: () => Analytics.setChoice(false)),
        ]))),
      )),
    ),
  );
}