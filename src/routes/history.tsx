import { createFileRoute, useRouter } from "@tanstack/react-router";
import { useMemo } from "react";

import { ClipGrid } from "@/components/mimi/ClipCard";
import { MascotLoader, Screen, TopBar } from "@/components/mimi/ui";
import { useContent } from "@/lib/feed";
import { useApp } from "@/lib/store";

export const Route = createFileRoute("/history")({
  head: () => ({
    meta: [
      { title: "Watch history — Kizuki" },
      { name: "description", content: "Every Japanese clip you've watched in Kizuki." },
      { property: "og:title", content: "Watch history — Kizuki" },
      { property: "og:description", content: "Every Japanese clip you've watched in Kizuki." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: History,
});

function History() {
  const router = useRouter();
  const { data } = useContent();
  const history = useApp((s) => s.history);
  const ids = useMemo(() => [...new Set(history.map((h) => h.clipId))], [history]);
  return (
    <Screen>
      <TopBar title="Watch history" onBack={() => router.history.back()} />
      {!data ? <MascotLoader className="flex-1" /> : <ClipGrid ids={ids.filter((id) => data.byId[id])} empty="Clips you watch will show up here." />}
    </Screen>
  );
}
