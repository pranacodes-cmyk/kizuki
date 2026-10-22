import { createFileRoute } from "@tanstack/react-router";

import { LegalPage } from "@/components/mimi/LegalPage";

export const Route = createFileRoute("/privacy")({
  head: () => ({
    meta: [
      { title: "Privacy Policy — Kizuki" },
      { name: "description", content: "What Kizuki stores about you and how you control it." },
      { property: "og:title", content: "Privacy Policy — Kizuki" },
      { property: "og:description", content: "What Kizuki stores about you and how you control it." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: () => (
    <LegalPage
      title="Privacy Policy"
      sections={[
        { h: "What we store", p: "Your learning plan answers, saved words, review progress, streak and settings are stored on your device. If you create an account, a copy is stored in our cloud so you can use Kizuki on more than one device." },
        { h: "Account data", p: "We store your email address and, if you sign in with Google, your name. We never sell your data." },
        { h: "Ads measurement & purchases", p: "Purchases are processed by Apple App Store / Google Play and managed by RevenueCat. The mobile app uses the Meta (Facebook) SDK to measure app installs, onboarding and subscription events (trial start, purchase, renewal) so we can see which Facebook/Instagram ads work; RevenueCat shares subscription events with Meta. This may include your device's advertising ID. On iPhone we only use it if you allow tracking; on Android you can reset or delete your advertising ID in Settings → Privacy → Ads. To withdraw, send us a message from Help & feedback and we will stop sharing." },
        { h: "Ask Kizuki (AI tutor)", p: "When you ask the tutor a question, your question and the clip line it is about are sent to our AI provider to write the answer. Questions are not used to identify you and are not sold. Ask Kizuki needs a free account." },
        { h: "Help messages", p: "If you contact us, we store your email, the topic, your message and your device type so we can reply. We delete them when they are no longer needed." },
        { h: "YouTube", p: "Clips play through YouTube's embedded player (privacy-enhanced mode where available). YouTube may collect data under Google's Privacy Policy when videos play." },
        { h: "Notifications", p: "Daily reminders are scheduled on your device. You can turn them off in Settings or your phone's settings." },
        { h: "Deleting your data", p: "Settings → Delete account permanently removes your account and cloud progress. Uninstalling the app removes the copy on your device." },
      ]}
    />
  ),
});
