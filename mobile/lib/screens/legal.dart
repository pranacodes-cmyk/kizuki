import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import '../widgets/ui.dart';

// Same draft copy as src/routes/terms.tsx and src/routes/privacy.tsx — must be reviewed before release.
const _terms = [
  ('Using Kizuki', 'Kizuki helps you learn Japanese with short clips, transcripts, word explanations and flashcards. Use it for personal, non-commercial learning.'),
  ('Videos', "Clips play through YouTube's official embedded player and remain the property of their creators. YouTube's Terms of Service apply when you watch them. Kizuki does not download or host these videos."),
  ('Learning content', 'Transcripts, translations and explanations are produced with care and AI assistance and may contain mistakes. Dictionary data comes from JMdict (EDRDG, CC BY-SA 4.0); example sentences from Tatoeba (CC BY 2.0 FR).'),
  ('Subscriptions', 'Premium is billed through Google Play after any free trial. You can cancel anytime in Google Play; access continues until the end of the paid period.'),
  ('Your account', "You're responsible for keeping your login safe. You can delete your account at any time in Settings, which removes your cloud progress."),
];

const _privacy = [
  ('What we store', 'Your learning plan answers, saved words, review progress, streak and settings are stored on your device. If you create an account, a copy is stored in our cloud so you can use Kizuki on more than one device.'),
  ('Account data', 'We store your email address and, if you sign in with Google, your name. We never sell your data.'),
  ('YouTube', "Clips play through YouTube's embedded player (privacy-enhanced mode where available). YouTube may collect data under Google's Privacy Policy when videos play."),
  ('Notifications', "Daily reminders are scheduled on your device. You can turn them off in Settings or your phone's settings."),
  ('Deleting your data', 'Settings → Delete account permanently removes your account and cloud progress. Uninstalling the app removes the copy on your device.'),
];

/// Plain text legal page — mirrors LegalPage.tsx.
class LegalScreen extends StatelessWidget {
  final String kind; // terms | privacy
  const LegalScreen({super.key, required this.kind});
  @override
  Widget build(BuildContext context) {
    final sections = kind == 'terms' ? _terms : _privacy;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: kind == 'terms' ? 'Terms of Service' : 'Privacy Policy', onBack: () => context.canPop() ? context.pop() : context.go('/settings')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: T.surface2, borderRadius: BorderRadius.circular(12)),
                child: Text('Draft — to be finalised before release.', style: txt(13, w: FontWeight.w700, c: T.muted)),
              ),
              for (final s in sections)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.$1, style: txt(16, w: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(s.$2, style: txt(15, w: FontWeight.w400, c: T.muted, h: 1.6)),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
