import { createFileRoute, useRouter } from "@tanstack/react-router";

import { ClipGrid } from "@/components/mimi/ClipCard";
import { MascotLoader, Screen, TopBar } from "@/components/mimi/ui";
import { useContent } from "@/lib/feed";
import { useApp } from "@/lib/store";
import { tr } from "@/lib/i18n";

export const Route = createFileRoute("/saved")({
  head: () => ({
    meta: [
      { title: "Saved clips — Kizuki" },
      { name: "description", content: "Japanese clips you bookmarked to watch again." },
      { property: "og:title", content: "Saved clips — Kizuki" },
      { property: "og:description", content: "Japanese clips you bookmarked to watch again." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Saved,
});

function Saved() {
  const router = useRouter();
  const { data } = useContent();
  const saved = useApp((s) => s.savedClips);
  return (
    <Screen>
      <TopBar title={tr("Saved clips")} onBack={() => router.history.back()} />
      {!data ? <MascotLoader className="flex-1" /> : <ClipGrid ids={saved.filter((id) => data.byId[id])} empty={tr("Tap the bookmark on any clip to save it here.")} />}
    </Screen>
  );
}
