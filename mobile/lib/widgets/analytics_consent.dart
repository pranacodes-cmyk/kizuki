import 'package:flutter/material.dart';
import '../services/analytics.dart';
import '../theme/tokens.dart';
import 'ui.dart';
import '../i18n/i18n.dart';

/// First-launch analytics choice (mirrors src/components/mimi/AnalyticsConsent.tsx).
/// It sits above the router in MaterialApp's builder, where no Material exists yet, so it
/// brings its own: without one, text falls back to Flutter's debug style (yellow underline).
class AnalyticsConsent extends StatelessWidget {
  const AnalyticsConsent({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool?>(
    valueListenable: Analytics.choice,
    builder: (context, choice, _) => choice != null ? const SizedBox.shrink() : Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: tr('Usage analytics'),
          child: ColoredBox(color: T.background.withValues(alpha: 0.95), child: SafeArea(
            child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Usage analytics'), style: txt(24, w: FontWeight.w900)),
                const SizedBox(height: 16),
                Text(Analytics.notice, style: txt(15, c: T.muted, h: 1.5)),
                const SizedBox(height: 24),
                Button3D(label: tr('Allow analytics'), variant: BtnVariant.surface, onPressed: () => Analytics.setChoice(true)),
                const SizedBox(height: 12),
                Button3D(label: tr('No thanks'), variant: BtnVariant.surface, onPressed: () => Analytics.setChoice(false)),
              ],
            ))),
          )),
        ),
      ),
    ),
  );
}
