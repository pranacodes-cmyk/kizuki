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

const supportTopicLabels = {
  'subscription': 'Subscription',
  'account': 'Account',
  'bug': 'Something broke',
  'content': 'A clip or word',
  'feedback': 'Idea',
  'other': 'Other',
};
