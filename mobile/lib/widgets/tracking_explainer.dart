import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'ui.dart';
import '../i18n/i18n.dart';

/// iPhone only: a short, honest note shown right before Apple's tracking question.
/// One button, no incentive, and it always leads to the system prompt (App Review 5.1.1).
Future<void> showTrackingExplainer(BuildContext context) => showMimiModal<void>(
      context,
      (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Mascot(MascotPose.wave, size: 88),
        const SizedBox(height: 12),
        Text(tr('One quick question'), textAlign: TextAlign.center, style: txt(22, w: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          tr('Your iPhone will ask if Kizuki may see which ad brought you here. Allowing it helps us spend less on ads and more on new clips. Kizuki works exactly the same either way.'),
          textAlign: TextAlign.center,
          style: txt(15, w: FontWeight.w500, c: T.muted, h: 1.45),
        ),
        const SizedBox(height: 20),
        Button3D(label: tr('Continue'), onPressed: () => Navigator.of(ctx).pop()),
      ]),
      dismissible: false,
    );
