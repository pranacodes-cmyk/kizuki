import { createFileRoute } from "@tanstack/react-router";

import { LegalPage } from "@/components/mimi/LegalPage";
import { PRIVACY } from "@/lib/legal";

const DESCRIPTION = "What Kizuki collects, why, who it is shared with, how long it is kept, and how to delete your data.";

export const Route = createFileRoute("/privacy")({
  head: () => ({
    meta: [
      { title: "Privacy Policy — Kizuki" },
      { name: "description", content: DESCRIPTION },
      { property: "og:title", content: "Privacy Policy — Kizuki" },
      { property: "og:description", content: DESCRIPTION },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: () => <LegalPage doc={PRIVACY} />,
});
