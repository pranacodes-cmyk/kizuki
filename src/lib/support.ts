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
    a: "Profile → Settings → Delete account. This permanently removes your account and cloud progress.",
  },
  {
    q: "Where do the videos come from?",
    a: "Every clip plays through YouTube's official player and belongs to its creator. Kizuki adds the Japanese transcript, translations and word explanations.",
  },
];

export const SUPPORT_TOPIC_LABELS: Record<SupportTopic, string> = {
  subscription: "Subscription",
  account: "Account",
  bug: "Something broke",
  content: "A clip or word",
  feedback: "Idea",
  other: "Other",
};
