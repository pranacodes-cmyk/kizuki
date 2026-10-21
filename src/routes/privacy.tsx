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
        { h: "YouTube", p: "Clips play through YouTube's embedded player (privacy-enhanced mode where available). YouTube may collect data under Google's Privacy Policy when videos play." },
        { h: "Notifications", p: "Daily reminders are scheduled on your device. You can turn them off in Settings or your phone's settings." },
        { h: "Deleting your data", p: "Settings → Delete account permanently removes your account and cloud progress. Uninstalling the app removes the copy on your device." },
      ]}
    />
  ),
});
