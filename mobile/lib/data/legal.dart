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
  updated: 'October 26, 2026',
  intro: 'This Privacy Policy explains how Kizuki (“Kizuki”, “we”, “us”) collects, uses and shares information when you use the Kizuki app for Android and iPhone and the website kiku-clip-word-garden.lovable.app (together, the “Service”). If anything here is unclear, message us and we will explain it.',
  sections: [
    LegalSection('1. The short version', [
      '• We collect only what Kizuki needs to work: your learning progress, your email if you create an account, and basic purchase and app-event data.',
      '• We never sell your personal information, and we do not insert our own ads into the learning interface. YouTube may show ads in its player.',
      '• Your progress is saved on your device first. An account adds a private cloud copy protected by account-specific access controls. Authorized service operations may process this data to run the Service.',
      '• You can delete your account and all synced data at any time in Settings.',
    ]),
    LegalSection('2. Information you give us', [
      '• Learning plan answers: why you are learning, your level, what is hardest for you, where you heard about Kizuki, your daily goal, reminder time and streak goal.',
      '• Learning activity: saved words and notes, word levels, review history and flashcard schedule, clips watched and saved, streaks, study time, achievements and settings.',
      '• Account details: when you choose an available email, Google or Apple sign-in method, the provider shares your account identifier and available name, email and profile picture with us. Kizuki does not ask for or receive your provider password.',
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
      '• Our project-owned backend service: account authentication, profiles and synced learning progress. Lovable provides website hosting and the AI Gateway used for tutor requests.',
      '• Apple App Store and Google Play: payments and subscription management.',
      '• RevenueCat: subscription status, receipts, trials and restores.',
      '• Meta Platforms (Facebook SDK and Conversions API): ads measurement, see section 6.',
      '• PostHog: optional product analytics, only after you turn on Usage analytics in Settings. It receives timestamped screen visits, tab and control interactions, onboarding and welcome-tour steps, paywall and checkout outcomes, clip and dictionary identifiers, learning activity, review grades, setting choices, subscription status, coarse error categories, device/browser information and an anonymous identifier. After sign-in we associate that identifier with your Kizuki account ID so we can understand journeys across devices. We do not send your name, email, passwords, sign-in tokens, messages, notes, chat questions or answers, card details or purchase receipts. Session replay and screen recording are disabled. These events measure product usage and funnels, not advertising audiences or optimization.',
      '• OpenAI, directly or through the Lovable AI Gateway depending on the active configuration: generates Ask Kizuki answers. We send the conversation text and relevant learning context, such as the clip sentence and word explanations. We do not intentionally attach your account name or email, but information you type yourself is included. Provider processing and security retention are governed by their terms.',
      '• YouTube (Google): clips play in YouTube\'s official embedded player. The player may receive your IP address, device/browser information, playback activity and cookies or identifiers. Google may show ads and process this information under its own policy: https://policies.google.com/privacy. YouTube Terms of Service: https://www.youtube.com/t/terms.',
      '• Google: sign-in with Google on the website, if you choose it.',
      'We may also disclose information when the law requires it, to protect the rights and safety of our users or others, or as part of a merger or sale of the Service, in which case we will tell you first.',
      'We do not sell your personal information. Advertising measurement is described in section 6; optional product analytics is a separate choice.',
    ]),
    LegalSection('6. Ads measurement and tracking', [
      'We advertise Kizuki on Facebook and Instagram. To learn which ads work, the app tells Meta when it is installed or opened and when onboarding or the welcome tour is finished, when the paywall is viewed, when checkout is started and when an achievement is unlocked. Event details can include a plan identifier, price and currency, or an achievement identifier. RevenueCat may share trial, purchase and renewal events through its configured Meta integration. The app supplies a Meta anonymous identifier and permitted device identifiers to RevenueCat for attribution. We do not insert our own ads; YouTube may show ads in its player.',
      '• iPhone: we ask with Apple\'s tracking prompt. If you choose “Ask App Not to Track”, the app does not read your advertising ID and Meta receives these events without it. You can change this anytime in Settings → Privacy & Security → Tracking.',
      '• Android: you can reset or delete your advertising ID in your phone\'s Settings → Privacy → Ads (or Settings → Google → Ads).',
      '• For advertising-data questions or an objection to processing, email pranacodes@gmail.com. The Usage analytics toggle controls PostHog only: it is not a switch for Meta or YouTube. Device privacy controls do not necessarily stop all non-advertising-ID event processing. Meta privacy information: https://www.facebook.com/privacy/policy/.',
    ]),
    LegalSection('7. Cookies and local storage', [
      'The website keeps your progress and sign-in session in your browser\'s local storage on that device. We do not use advertising cookies. Clips play in YouTube\'s privacy-enhanced mode, but YouTube may set its own cookies when a clip plays.',
      'Optional PostHog analytics also uses local storage and a mobile device identifier to remember analytics identity. Analytics stays off unless you explicitly opt in; there is no first-launch analytics popup. You can turn it on or off in Settings → Usage analytics. Your choice, time and notice version are saved on that device; a withdrawal preserves earlier acceptance evidence. Withdrawal stops future collection and clears analytics identity; it does not automatically erase events already received by PostHog. Contact us for deletion of previously collected analytics. Declining does not restrict Kizuki. Analytics choice is separate from advertising tracking and YouTube\'s player.',
    ]),
    LegalSection('8. How long we keep information', [
      '• Account and synced progress: until you delete your account.',
      '• Ask Kizuki: the tutor request handler does not save conversations to our learning database and requests that model responses are not stored by OpenAI. Conversation text is still processed by the AI provider and, when used, the AI Gateway; this does not guarantee zero provider logs or zero security retention.',
      '• Help messages: kept to handle your request and related follow-up, or where necessary for legal or security purposes. Contact us to request deletion; there is no automatic deletion schedule promised here.',
      '• Purchase records: as long as tax and accounting laws require.',
      '• Server logs: a limited time for security and troubleshooting.',
      '• Optional product analytics: retained according to the configured PostHog project retention, until removed under our retention settings or a valid deletion request. Contact us for access or deletion; we do not promise a specific period until project retention is configured.',
      '• Progress on your device: until you clear app or browser data, delete your account through the app, or remove the app where the operating system removes its stored data. Backups may follow your device provider\'s retention settings.',
    ]),
    LegalSection('9. Your choices and rights', [
      '• Delete your account: Settings → Delete account requests account deletion and clears local learner state after a successful response. This does not cancel an App Store or Google Play subscription. Purchase, security and legally required records, and provider backups, may be retained separately.',
      '• Delete without the app: send a message at kiku-clip-word-garden.lovable.app/support with the topic “Account”, using the email you signed up with. You may also email pranacodes@gmail.com. We may need to verify ownership before acting; we aim to handle verified requests within 30 days, subject to legal requirements and permitted extensions. Submission does not automatically delete an account or generate an email reply.',
      '• Export: Settings → Export saved words (.csv) downloads your words as a spreadsheet. For a copy of all your data, send us a message.',
      '• Correct: change your plan, level and settings in the app at any time.',
      '• Withdraw consent: turn off tracking, notifications or reminders in your phone\'s settings or in Kizuki\'s Settings.',
      'Depending on where you live (for example the EU/EEA, UK, Switzerland, California and other US states, Brazil or India), you may have the right to access, correct, delete or port your information, to restrict or object to its use, and to complain to your local data protection authority. We aim to answer verified requests within 30 days, or within the legally applicable period, and we never treat you differently for using your rights.',
      'Legal bases (EU/EEA and UK): performing our contract with you (running the Service), our legitimate interests (security, improving Kizuki and measuring our ads), your consent (optional product analytics and tracking or notifications where required) and legal obligations.',
    ]),
    LegalSection('10. Children', [
      'Kizuki is not directed to children under 13 (under 16 in the EU/EEA and UK). We do not knowingly collect their personal information. If you believe a child has given us information, contact us and we will delete it.',
    ]),
    LegalSection('11. Security', [
      'Data is encrypted in transit (HTTPS). Cloud progress is protected by account-specific access rules. Authentication is handled by our sign-in provider; we do not receive Google or Apple account passwords. No system is perfectly secure, but we work to protect your information and will tell you if a breach affects you.',
    ]),
    LegalSection('12. International transfers', [
      'We and our providers may process information in the United States and other countries. Applicable transfer protections depend on the service provider and your jurisdiction. Contact us for information about safeguards applicable to your data.',
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
  updated: 'October 26, 2026',
  intro: 'These Terms apply to the Kizuki Android and iPhone apps and website, operated by the Kizuki team. By using the Service you agree to these Terms. If you do not agree, do not use the Service. Questions can be sent to pranacodes@gmail.com.',
  sections: [
    LegalSection('1. The Service', [
      'Kizuki is a Japanese-learning service with contextual clips, word definitions, translations, vocabulary tools, spaced-repetition flashcards, progress tracking and an AI tutor. Features, content and availability may change. Learning outcomes or JLPT results are not guaranteed.',
    ]),
    LegalSection('2. Eligibility', [
      'Kizuki is not directed to children under 13, or under 16 in the EU/EEA and UK. If you are below the age of majority where you live, use the Service only with a parent or guardian\'s permission. Store purchases must be authorized by the account holder.',
    ]),
    LegalSection('3. Accounts and security', [
      'Provide accurate account information and keep your sign-in secure. Do not share credentials, impersonate another person or access another learner\'s data. Your learning progress is associated with your Kizuki account when signed in; use the same account across devices.',
      'Purchase recognition depends on the store account, the Kizuki account linked through RevenueCat, and the store and subscription provider\'s restore rules. Use Restore purchase with the original store account. A restore is not a promise that a subscription can be shared with or transferred to any other Kizuki account; contact us if access is attached to an unexpected account.',
    ]),
    LegalSection('4. Acceptable use', [
      'Use Kizuki for personal, non-commercial learning. Do not use it unlawfully, bypass access controls, disrupt the Service, scrape or redistribute content without permission, exploit the tutor, or infringe intellectual-property rights. Do not send passwords, payment details or sensitive personal information to the AI tutor.',
    ]),
    LegalSection('5. YouTube content and Premium learning features', [
      'Videos belong to their respective creators and are hosted on YouTube. Kizuki uses YouTube\'s official embedded player; it does not download, re-host or sell ownership of the videos. Kizuki is not affiliated with or endorsed by YouTube or the featured creators.',
      'YouTube-related features are subject to YouTube\'s Terms of Service: https://www.youtube.com/t/terms. Google\'s Privacy Policy applies to the player: https://policies.google.com/privacy. Standard player functionality, branding and any ads are controlled by YouTube. Do not bypass player restrictions or copy or redistribute videos without permission.',
      'Kizuki Premium provides our additional language-learning tools: contextual translations and definitions, vocabulary organization, flashcards and review scheduling, learning statistics, progress tracking and Ask Kizuki. The underlying videos remain available separately on YouTube, subject to creator availability and YouTube\'s rules. Our in-app learning experience requires an active eligible trial or subscription after any onboarding preview; we do not promise a free in-app video feed.',
      'A subscription does not grant a license to the creators\' videos or other third-party content. Videos can be removed, restricted or become unavailable, and the clip library may change. This description is not a representation that YouTube has approved Kizuki or granted special permissions.',
    ]),
    LegalSection('6. Learning content and intellectual property', [
      'Kizuki\'s branding, original software and original learning materials are protected by applicable intellectual-property laws. Third-party videos and other licensed material remain subject to their owners\' rights. Do not reuse our branding or materials without permission or a valid legal basis.',
      'Transcripts, translations and explanations may be AI-assisted and contain mistakes. Dictionary data includes JMdict (EDRDG, CC BY-SA 4.0); example sentences include Tatoeba (CC BY 2.0 FR). Applicable third-party licenses continue to apply.',
    ]),
    LegalSection('7. Subscriptions, prices and trials', [
      'Kizuki Premium is an auto-renewing monthly or yearly subscription purchased through Apple App Store or Google Play. The actual store price in your local currency, billing period and offer terms are shown before purchase. Monthly-equivalent yearly prices are comparisons: the yearly total is billed for the full year.',
      'Eligible yearly offers may include a 3-day or 7-day free trial, or no trial. The selected store product and your eligibility determine the offer; a trial is not guaranteed for every user. Monthly is billed immediately unless the store explicitly presents an eligible offer. At the end of a free trial, the displayed subscription price is charged automatically unless you cancel in time.',
      'Apple generally permits only one introductory offer per subscription group for an eligible store account. Choosing a different plan or signing into a different Kizuki account does not guarantee another trial. Google Play eligibility depends on its offer rules. The store\'s purchase confirmation governs the transaction.',
      'Payments are charged to your store account. Subscriptions renew automatically unless canceled under the store\'s rules. For Apple, cancel at least 24 hours before the current trial or billing period ends; renewal may be charged within the final 24 hours. For Google Play, follow the cancellation deadline shown by Google. Any price changes are handled under the store\'s notice and consent rules.',
    ]),
    LegalSection('8. Cancellation, refunds and restore', [
      'Manage or cancel your subscription through your App Store or Google Play account settings. Uninstalling Kizuki, signing out or deleting your Kizuki account does not cancel a store subscription. Access usually continues until the paid period ends; a free trial may end immediately after cancellation where the store\'s rules provide for this.',
      'Refund requests are handled by Apple or Google under their policies and applicable consumer law. Kizuki does not promise automatic refunds. Restore purchase checks existing store purchases; it does not create a new purchase or a new trial.',
      'After trial or paid access expires without renewal, learning access is restricted; account, settings, help, legal information and purchase or restore options remain available.',
    ]),
    LegalSection('9. Ask Kizuki', [
      'The AI tutor requires sign-in and a verified active Premium entitlement. Availability and operational limits may apply. Answers can be incorrect or incomplete and should not be treated as professional advice. We do not promise unlimited availability, a fixed free question allowance or error-free answers.',
    ]),
    LegalSection('10. Privacy and account deletion', [
      'Our Privacy Policy explains collection, processing, providers and your choices: https://kiku-clip-word-garden.lovable.app/privacy. You may request account deletion from Settings or contact us. Deletion does not automatically remove legally retained store/provider records or cancel subscriptions.',
    ]),
    LegalSection('11. Availability and disclaimers', [
      'To the extent permitted by law, the Service is provided as available without a guarantee of uninterrupted availability, perfect accuracy or compatibility with every device. Internet access and third-party services are required for video playback, purchases, sync and AI answers. Your mandatory consumer rights are not excluded.',
    ]),
    LegalSection('12. Liability and consumer rights', [
      'To the extent permitted by applicable law, we are not responsible for indirect or consequential losses from use of the Service. Nothing in these Terms excludes liability that cannot lawfully be excluded, or limits mandatory consumer rights, including rights related to refunds, digital services or data protection.',
    ]),
    LegalSection('13. Changes and termination', [
      'We may update these Terms and will show the revision date on this page. Material changes will be communicated as appropriate; any legally required notice or consent still applies. We may restrict abusive or unlawful use, subject to applicable law. Store cancellation and refund rules continue to apply separately.',
    ]),
    LegalSection('14. Apple license and applicable law', [
      'For the iPhone app, Apple\'s Standard End User License Agreement (EULA) applies to the app license: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/. These Terms describe Kizuki\'s service and do not replace Apple\'s purchase conditions or mandatory consumer rights.',
      'Applicable law and dispute rights depend on your jurisdiction and the applicable store license. These Terms do not require you to waive mandatory protections or bring claims in a foreign court.',
    ]),
    LegalSection('15. Contact', [
      'For support, subscription-access problems or legal questions, open Profile → Help & feedback, visit https://kiku-clip-word-garden.lovable.app/support, or email pranacodes@gmail.com.',
    ]),
  ],
);
