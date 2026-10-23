import { createFileRoute } from "@tanstack/react-router";

import { LegalPage } from "@/components/mimi/LegalPage";
import { TERMS } from "@/lib/legal";

export const Route = createFileRoute("/terms")({
  head: () => ({
    meta: [
      { title: "Terms of Service — Kizuki" },
      { name: "description", content: "The terms for using the Kizuki Japanese learning app, including subscriptions and free trials." },
      { property: "og:title", content: "Terms of Service — Kizuki" },
      { property: "og:description", content: "The terms for using the Kizuki Japanese learning app, including subscriptions and free trials." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: () => <LegalPage doc={TERMS} />,
});
