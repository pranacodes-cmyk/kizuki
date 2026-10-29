// Help & support copy — mirrored word for word by mobile/lib/data/support.dart.
import type { SupportTopic } from "./logic";

export const SUPPORT_FAQ: { q: string; a: string }[] = [
  {
    q: "How do I cancel or change my subscription?",
    a: "Subscriptions are handled by your app store. iPhone: Settings → your name → Subscriptions → Kizuki. Android: Google Play → profile picture → Payments & subscriptions → Subscriptions → Kizuki. Deleting the app doesn't cancel it.",
  },
  {
    q: "I paid but Premium isn't unlocked",
    a: "Open Profile → Settings → Restore purchase, using the same Apple ID or Google account you paid with. If it still shows locked, send us a message below.",
  },
  {
    q: "How does the free trial work?",
    a: "The yearly plan starts with 7 days free. Cancel at least 24 hours before the trial ends and you won't be charged. The monthly plan has no trial.",
  },
  {
    q: "A video won't play",
    a: "Some YouTube videos are blocked in certain countries or by their channel. Swipe to the next clip, check your connection, or tap Watch on YouTube. Tell us which clip and we will replace it.",
  },
  {
    q: "How do I move my progress to a new phone?",
    a: "Create a free account from Profile → Save your progress, then sign in with the same account on the new phone. Your words, reviews and streak sync automatically.",
  },
  {
    q: "How do I delete my account?",
    a: "Profile → Settings → Delete account. This permanently removes your account and cloud progress. No longer have the app? Send us a message below with the topic Account, from the email you signed up with, and we will delete your account and data within 30 days.",
  },
  {
    q: "Where do the videos come from?",
    a: "Every clip plays through YouTube's official player and belongs to its creator. Kizuki adds the Japanese transcript, translations and word explanations.",
  },
];

/** Account-deletion copy shown as its own section. Store reviewers require the page to name the app and developer. */
export const DELETE_ACCOUNT_COPY = {
  title: "Delete your Kizuki account",
  intro: "Kizuki (the Japanese learning app by Prana codes, contact pranacodes@gmail.com) lets you delete your account and all associated data at any time.",
  stepsTitle: "In the Kizuki app",
  steps: "Open Kizuki → Profile → Settings → Delete account. This permanently deletes your account, saved words, reviews, streak and cloud progress.",
  webTitle: "Without the app",
  web: "Send us a message below with the topic “Account”, from the email you signed up with, or email pranacodes@gmail.com. We delete your account and data within 30 days of a verified request.",
  kept: "Deletion removes your profile, learner progress and support messages. Purchase records stay with your app store (Apple/Google) as required for receipts and refunds.",
};

export const SUPPORT_TOPIC_LABELS: Record<SupportTopic, string> = {
  subscription: "Subscription",
  account: "Account",
  bug: "Something broke",
  content: "A clip or word",
  feedback: "Idea",
  other: "Other",
};
