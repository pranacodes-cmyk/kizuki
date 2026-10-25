// GENERATED from src/lib/legal.ts — the same Privacy Policy and Terms word for word.
// Edit src/lib/legal.ts, then run: bun scripts/legal/gen_legal_dart.ts (src/lib/legal.test.ts fails while they differ).
// Lines starting with "• " render as bullet points.

class LegalSection {
  final String h;
  final List<String> body;
  const LegalSection(this.h, this.body);
}

class LegalDoc {
  final String title, updated, intro;
  final List<LegalSection> sections;
  const LegalDoc({required this.title, required this.updated, required this.intro, required this.sections});
}

const privacyDoc = LegalDoc(
  title: 'Privacy Policy',
  updated: 'October 25, 2026',
  intro: 'This Privacy Policy explains how Kizuki (“Kizuki”, “we”, “us”) collects, uses and shares information when you use the Kizuki app for Android and iPhone and the website kiku-clip-word-garden.lovable.app (together, the “Service”). If anything here is unclear, message us and we will explain it.',
  sections: [
    LegalSection('1. The short version', [
      '• We collect only what Kizuki needs to work: your learning progress, your email if you create an account, and basic purchase and app-event data.',
      '• We never sell your personal information, and there are no ads inside Kizuki.',
      '• Your progress is saved on your device first. An account adds a private cloud copy that only you can access.',
      '• You can delete your account and all synced data at any time in Settings.',
    ]),
    LegalSection('2. Information you give us', [
      '• Learning plan answers: why you are learning, your level, what is hardest for you, where you heard about Kizuki, your daily goal, reminder time and streak goal.',
      '• Learning activity: saved words and notes, word levels, review history and flashcard schedule, clips watched and saved, streaks, study time, achievements and settings.',
      '• Account details: when you choose Google, Apple or Lovable sign-in, the provider shares your account identifier and available name, email and profile picture with us. Kizuki does not ask for or receive your provider password.',
      '• Ask Kizuki questions: the question you type and the clip sentence it is about.',
      '• Help messages: your email address, the topic, your message and your device type.',
    ]),
    LegalSection('3. Information collected automatically', [
      '• Purchase information: whether you have Kizuki Premium, your plan, trial and renewal dates and store transaction IDs. Apple and Google process payments; we never see or store your card or payment details.',
      '• App events: app installs and opens, onboarding steps completed, and subscription events (trial started, purchase, renewal, cancellation).',
      '• Device information: device model, operating system and app version, language, country or region and time zone.',
      '• Identifiers: a random Kizuki user ID and, only where allowed (see section 6), your device\'s advertising ID.',
      '• Technical logs: error and request logs that our servers keep for a short time to run the Service securely.',
    ]),
    LegalSection('4. How we use information', [
      '• To provide the Service: build your plan, choose clips at your level, save words, schedule reviews and keep your streak.',
      '• To sync your progress between your devices when you are signed in.',
      '• To answer your Ask Kizuki questions and your help messages.',
      '• To process subscriptions, free trials and restores, and to remind you before a free trial ends.',
      '• To send the daily study reminder you chose. Reminders are scheduled on your device and you can turn them off at any time.',
      '• To understand which of our ads bring new learners and to improve onboarding.',
      '• To keep the Service secure, prevent abuse and meet legal obligations.',
      'We do not use your information for automated decisions that have legal or similarly significant effects on you.',
    ]),
    LegalSection('5. Who we share information with', [
      'We share information only with service providers that help us run Kizuki, and only what each one needs:',
      '• Lovable (Lovable Cloud): hosting, database and sign-in for accounts and synced progress.',
      '• Apple App Store and Google Play: payments and subscription management.',
      '• RevenueCat: subscription status, receipts, trials and restores.',
      '• Meta Platforms (Facebook SDK and Conversions API): ads measurement, see section 6.',
      '• PostHog: optional product analytics, only after you turn on Usage analytics in Settings. It receives timestamped screen visits, tab and control interactions, onboarding and welcome-tour steps, paywall and checkout outcomes, clip and dictionary identifiers, learning activity, review grades, setting choices, subscription status, coarse error categories, device/browser information and an anonymous identifier. After sign-in we associate that identifier with your Kizuki account ID so we can understand journeys across devices. We do not send your name, email, passwords, sign-in tokens, messages, notes, chat questions or answers, card details or purchase receipts. Session replay and screen recording are disabled. These events measure product usage and funnels, not advertising audiences or optimization.',
      '• OpenAI, through the Lovable AI Gateway: writes Ask Kizuki answers. We send only your question and the clip sentence, never your name or email.',
      '• YouTube (Google): clips play in YouTube\'s official embedded player, which may collect data under Google\'s Privacy Policy.',
      '• Google: sign-in with Google on the website, if you choose it.',
      'We may also disclose information when the law requires it, to protect the rights and safety of our users or others, or as part of a merger or sale of the Service, in which case we will tell you first.',
      'We do not sell your personal information. Apart from the ads measurement in section 6, which you can turn off, we do not share it for advertising.',
    ]),
    LegalSection('6. Ads measurement and tracking', [
      'We advertise Kizuki on Facebook and Instagram. To learn which ads work, the app tells Meta when it is installed or opened and when onboarding is finished, and RevenueCat tells Meta about trial starts, purchases and renewals. Kizuki shows no ads.',
      '• iPhone: we ask with Apple\'s tracking prompt. If you choose “Ask App Not to Track”, the app does not read your advertising ID and Meta receives these events without it. You can change this anytime in Settings → Privacy & Security → Tracking.',
      '• Android: you can reset or delete your advertising ID in your phone\'s Settings → Privacy → Ads (or Settings → Google → Ads).',
      '• Anywhere: send us a message from Help & feedback and we will stop sharing your app events with Meta.',
    ]),
    LegalSection('7. Cookies and local storage', [
      'The website keeps your progress and sign-in session in your browser\'s local storage on that device. We do not use advertising cookies. Clips play in YouTube\'s privacy-enhanced mode, but YouTube may set its own cookies when a clip plays.',
      'Optional PostHog analytics also uses local storage and a mobile device identifier to remember analytics identity. Analytics stays off unless you explicitly opt in; there is no first-launch analytics popup. You can turn it on or off in Settings → Usage analytics. Your choice, time and notice version are saved on that device; a withdrawal preserves earlier acceptance evidence. Withdrawal stops future collection and clears analytics identity; it does not automatically erase events already received by PostHog. Contact us for deletion of previously collected analytics. Declining does not restrict Kizuki. Analytics choice is separate from advertising tracking and YouTube\'s player.',
    ]),
    LegalSection('8. How long we keep information', [
      '• Account and synced progress: until you delete your account.',
      '• Ask Kizuki questions: we do not store the text of your questions; our AI provider processes them only to write the answer.',
      '• Help messages: until your request is resolved and for up to 2 years after, then deleted.',
      '• Purchase records: as long as tax and accounting laws require.',
      '• Server logs: a limited time for security and troubleshooting.',
      '• Optional product analytics: retained according to the configured PostHog project retention, until removed under our retention settings or a valid deletion request. Contact us for access or deletion; we do not promise a specific period until project retention is configured.',
      '• Progress on your device: until you delete the app or its data.',
    ]),
    LegalSection('9. Your choices and rights', [
      '• Delete your account: Settings → Delete account permanently removes your account and cloud progress right away.',
      '• Delete without the app: send a message at kiku-clip-word-garden.lovable.app/support with the topic “Account”, using the email you signed up with. We delete the account and its data within 30 days and confirm by reply.',
      '• Export: Settings → Export saved words (.csv) downloads your words as a spreadsheet. For a copy of all your data, send us a message.',
      '• Correct: change your plan, level and settings in the app at any time.',
      '• Withdraw consent: turn off tracking, notifications or reminders in your phone\'s settings or in Kizuki\'s Settings.',
      'Depending on where you live (for example the EU/EEA, UK, Switzerland, California and other US states, Brazil or India), you may have the right to access, correct, delete or port your information, to restrict or object to its use, and to complain to your local data protection authority. We answer requests within 30 days, or sooner if the law requires, and we never treat you differently for using your rights.',
      'Legal bases (EU/EEA and UK): performing our contract with you (running the Service), our legitimate interests (security, improving Kizuki and measuring our ads), your consent (tracking on iPhone, notifications) and legal obligations.',
    ]),
    LegalSection('10. Children', [
      'Kizuki is not directed to children under 13 (under 16 in the EU/EEA and UK). We do not knowingly collect their personal information. If you believe a child has given us information, contact us and we will delete it.',
    ]),
    LegalSection('11. Security', [
      'Data is encrypted in transit (HTTPS). Cloud progress is protected by access rules so each account can read only its own data, and passwords are stored only as secure hashes. No system is perfectly secure, but we work to protect your information and will tell you if a breach affects you.',
    ]),
    LegalSection('12. International transfers', [
      'We and our providers may process information in the United States and other countries. Where required, transfers are protected by safeguards such as the European Commission\'s Standard Contractual Clauses.',
    ]),
    LegalSection('13. Changes to this policy', [
      'When we change this policy we update the date at the top. For significant changes we will tell you in the app before they take effect.',
    ]),
    LegalSection('14. Contact us', [
      'Questions or privacy requests: open Profile → Help & feedback in the app, visit kiku-clip-word-garden.lovable.app/support, or email pranacodes@gmail.com.',
    ]),
  ],
);

const termsDoc = LegalDoc(
  title: 'Terms of Service',
  updated: 'October 23, 2026',
  intro: 'These terms apply when you use the Kizuki app and website. By using Kizuki you agree to them.',
  sections: [
    LegalSection('Using Kizuki', [
      'Kizuki helps you learn Japanese with short clips, transcripts, word explanations and flashcards. Use it for personal, non-commercial learning.',
    ]),
    LegalSection('Videos', [
      'Clips play through YouTube\'s official embedded player and remain the property of their creators. YouTube\'s Terms of Service apply when you watch them. Kizuki does not download or host these videos.',
    ]),
    LegalSection('Learning content', [
      'Transcripts, translations and explanations are produced with care and AI assistance and may contain mistakes. Dictionary data comes from JMdict (EDRDG, CC BY-SA 4.0); example sentences from Tatoeba (CC BY 2.0 FR).',
    ]),
    LegalSection('Subscriptions', [
      'Kizuki Premium is an auto-renewing subscription billed through the App Store or Google Play. The yearly plan starts with a 7-day free trial; the monthly plan is billed right away. Payment is charged to your store account when you confirm (or when the trial ends), and the subscription renews at the same price unless you cancel at least 24 hours before the current period ends. Manage or cancel it anytime in your App Store or Google Play subscriptions; access continues until the end of the paid period. Prices are shown in your local currency before you buy.',
    ]),
    LegalSection('Ask Kizuki', [
      'Answers from the AI tutor are generated automatically and can be wrong. Free accounts get 5 questions a day; Premium is unlimited. Please don\'t send personal information in your questions.',
    ]),
    LegalSection('Your account', [
      'You\'re responsible for keeping your login safe. You can delete your account at any time in Settings, which removes your cloud progress.',
    ]),
    LegalSection('Privacy', [
      'Our Privacy Policy explains what we collect and how we use it.',
    ]),
    LegalSection('Contact', [
      'Questions or problems? Open Profile → Help & feedback, visit kiku-clip-word-garden.lovable.app/support, or email pranacodes@gmail.com.',
    ]),
  ],
);
