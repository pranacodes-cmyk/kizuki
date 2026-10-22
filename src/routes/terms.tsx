import { createFileRoute } from "@tanstack/react-router";

import { LegalPage } from "@/components/mimi/LegalPage";

export const Route = createFileRoute("/terms")({
  head: () => ({
    meta: [
      { title: "Terms of Service — Kizuki" },
      { name: "description", content: "The terms for using the Kizuki Japanese learning app." },
      { property: "og:title", content: "Terms of Service — Kizuki" },
      { property: "og:description", content: "The terms for using the Kizuki Japanese learning app." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: () => (
    <LegalPage
      title="Terms of Service"
      sections={[
        { h: "Using Kizuki", p: "Kizuki helps you learn Japanese with short clips, transcripts, word explanations and flashcards. Use it for personal, non-commercial learning." },
        { h: "Videos", p: "Clips play through YouTube's official embedded player and remain the property of their creators. YouTube's Terms of Service apply when you watch them. Kizuki does not download or host these videos." },
        { h: "Learning content", p: "Transcripts, translations and explanations are produced with care and AI assistance and may contain mistakes. Dictionary data comes from JMdict (EDRDG, CC BY-SA 4.0); example sentences from Tatoeba (CC BY 2.0 FR)." },
        { h: "Subscriptions", p: "Kizuki Premium is an auto-renewing subscription billed through the App Store or Google Play. The yearly plan starts with a 7-day free trial; the monthly plan is billed right away. Payment is charged to your store account when you confirm (or when the trial ends), and the subscription renews at the same price unless you cancel at least 24 hours before the current period ends. Manage or cancel it anytime in your App Store or Google Play subscriptions; access continues until the end of the paid period. Prices are shown in your local currency before you buy." },
        { h: "Ask Kizuki", p: "Answers from the AI tutor are generated automatically and can be wrong. Free accounts get 5 questions a day; Premium is unlimited. Please don't send personal information in your questions." },
        { h: "Your account", p: "You're responsible for keeping your login safe. You can delete your account at any time in Settings, which removes your cloud progress." },
        { h: "Contact", p: "Questions or problems? Open Profile → Help & feedback, or visit kiku-clip-word-garden.lovable.app/support." },
      ]}
    />
  ),
});
