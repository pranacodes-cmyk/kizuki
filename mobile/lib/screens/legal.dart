import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';
import '../widgets/ui.dart';

// Same copy as src/routes/terms.tsx and src/routes/privacy.tsx — keep them word for word.
const _terms = [
  ('Using Kizuki', 'Kizuki helps you learn Japanese with short clips, transcripts, word explanations and flashcards. Use it for personal, non-commercial learning.'),
  ('Videos', "Clips play through YouTube's official embedded player and remain the property of their creators. YouTube's Terms of Service apply when you watch them. Kizuki does not download or host these videos."),
  ('Learning content', 'Transcripts, translations and explanations are produced with care and AI assistance and may contain mistakes. Dictionary data comes from JMdict (EDRDG, CC BY-SA 4.0); example sentences from Tatoeba (CC BY 2.0 FR).'),
  ('Subscriptions', "Kizuki Premium is an auto-renewing subscription billed through the App Store or Google Play. The yearly plan starts with a 7-day free trial; the monthly plan is billed right away. Payment is charged to your store account when you confirm (or when the trial ends), and the subscription renews at the same price unless you cancel at least 24 hours before the current period ends. Manage or cancel it anytime in your App Store or Google Play subscriptions; access continues until the end of the paid period. Prices are shown in your local currency before you buy."),
  ('Ask Kizuki', 'Answers from the AI tutor are generated automatically and can be wrong. Free accounts get 5 questions a day; Premium is unlimited. Please don\'t send personal information in your questions.'),
  ('Your account', "You're responsible for keeping your login safe. You can delete your account at any time in Settings, which removes your cloud progress."),
  ('Contact', 'Questions or problems? Open Profile → Help & feedback, or visit kiku-clip-word-garden.lovable.app/support.'),
];

const _privacy = [
  ('What we store', 'Your learning plan answers, saved words, review progress, streak and settings are stored on your device. If you create an account, a copy is stored in our cloud so you can use Kizuki on more than one device.'),
  ('Account data', 'We store your email address and, if you sign in with Google, your name. We never sell your data.'),
  ('Ads measurement & purchases', "Purchases are processed by Apple App Store / Google Play and managed by RevenueCat. The mobile app uses the Meta (Facebook) SDK to measure app installs, onboarding and subscription events (trial start, purchase, renewal) so we can see which Facebook/Instagram ads work; RevenueCat shares subscription events with Meta. This may include your device's advertising ID. On iPhone we only use it if you allow tracking; on Android you can reset or delete your advertising ID in Settings → Privacy → Ads. To withdraw, send us a message from Help & feedback and we will stop sharing."),
  ('Ask Kizuki (AI tutor)', 'When you ask the tutor a question, your question and the clip line it is about are sent to our AI provider to write the answer. Questions are not used to identify you and are not sold. Ask Kizuki needs a free account.'),
  ('Help messages', 'If you contact us, we store your email, the topic, your message and your device type so we can reply. We delete them when they are no longer needed.'),
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
