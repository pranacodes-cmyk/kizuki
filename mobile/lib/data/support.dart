// Help & support copy — mirrors src/lib/support.ts word for word.

const supportFaq = [
  (
    'How do I cancel or change my subscription?',
    "Subscriptions are handled by your app store. iPhone: Settings → your name → Subscriptions → Kizuki. Android: Google Play → profile picture → Payments & subscriptions → Subscriptions → Kizuki. Deleting the app doesn't cancel it.",
  ),
  (
    "I paid but Premium isn't unlocked",
    'Open Profile → Settings → Restore purchase, using the same Apple ID or Google account you paid with. If it still shows locked, send us a message below.',
  ),
  (
    'How does the free trial work?',
    "The yearly plan starts with 7 days free. Cancel at least 24 hours before the trial ends and you won't be charged. The monthly plan has no trial.",
  ),
  (
    "A video won't play",
    'Some YouTube videos are blocked in certain countries or by their channel. Swipe to the next clip, check your connection, or tap Watch on YouTube. Tell us which clip and we will replace it.',
  ),
  (
    'How do I move my progress to a new phone?',
    'Create a free account from Profile → Save your progress, then sign in with the same account on the new phone. Your words, reviews and streak sync automatically.',
  ),
  (
    'How do I delete my account?',
    'Profile → Settings → Delete account. This permanently removes your account and cloud progress. No longer have the app? Send us a message below with the topic Account, from the email you signed up with, and we will delete your account and data within 30 days.',
  ),
  (
    'Where do the videos come from?',
    "Every clip plays through YouTube's official player and belongs to its creator. Kizuki adds the Japanese transcript, translations and word explanations.",
  ),
];

/// Account-deletion copy shown as its own section. Mirrors DELETE_ACCOUNT_COPY in src/lib/support.ts.
const deleteAccountCopy = (
  title: 'Delete your Kizuki account',
  intro: 'Kizuki (the Japanese learning app by Prana codes, contact pranacodes@gmail.com) lets you delete your account and all associated data at any time.',
  stepsTitle: 'In the Kizuki app',
  steps: 'Open Kizuki → Profile → Settings → Delete account. This permanently deletes your account, saved words, reviews, streak and cloud progress.',
  webTitle: 'Without the app',
  web: 'Send us a message below with the topic “Account”, from the email you signed up with, or email pranacodes@gmail.com. We delete your account and data within 30 days of a verified request.',
  kept: 'Deletion removes your profile, learner progress and support messages. Purchase records stay with your app store (Apple/Google) as required for receipts and refunds.',
);

const supportTopicLabels = {
  'subscription': 'Subscription',
  'account': 'Account',
  'bug': 'Something broke',
  'content': 'A clip or word',
  'feedback': 'Idea',
  'other': 'Other',
};
