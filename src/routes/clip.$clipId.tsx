import { createFileRoute, useNavigate, useRouter } from "@tanstack/react-router";
import { useState } from "react";

import { ClipView } from "@/components/mimi/ClipView";
import { Mascot } from "@/components/mimi/Mascot";
import { Button, ErrorState, MascotLoader, TopBar } from "@/components/mimi/ui";
import { useContent } from "@/lib/feed";
import { canWatchClip } from "@/lib/logic";
import { FREE_DAILY_CLIPS } from "@/lib/paywall";
import { todayOf, useApp } from "@/lib/store";

export const Route = createFileRoute("/clip/$clipId")({
  head: () => ({
    meta: [
      { title: "Watch a clip — Kizuki" },
      { name: "description", content: "A short real Japanese clip with an interactive, tap-to-translate transcript." },
      { property: "og:title", content: "Watch a clip — Kizuki" },
      { property: "og:description", content: "A short real Japanese clip with an interactive, tap-to-translate transcript." },
      { property: "og:type", content: "video.other" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ClipPage,
});

function ClipPage() {
  const { clipId } = Route.useParams();
  const router = useRouter();
  const navigate = useNavigate();
  const { data, error, refetch, isLoading } = useContent();
  const premium = useApp((s) => s.premium.active);
  // Lock decided on arrival only — the clip never locks while you're watching it.
  const [allowed] = useState(() => canWatchClip(premium, todayOf(useApp.getState()).clips, FREE_DAILY_CLIPS) || (useApp.getState().seen[clipId] ?? 0) > 0);
  const back = () => (window.history.length > 1 ? router.history.back() : void navigate({ to: "/feed" }));
  const clip = data?.byId[clipId];

  return (
    <div className="absolute inset-0 flex flex-col bg-background pt-[calc(var(--sat)+4px)]">
      <TopBar onBack={back} title={clip ? clip.title : ""} />
      {isLoading && <MascotLoader className="flex-1" />}
      {error && <div className="flex flex-1 items-center"><ErrorState title="Couldn't load this clip" onRetry={() => void refetch()} /></div>}
      {data && !clip && <div className="flex flex-1 items-center"><ErrorState title="Clip not found" body="It may have been removed from the library." /></div>}
      {clip && data && (allowed || premium ? (
        <div className="min-h-0 flex-1"><ClipView clip={clip} content={data} active bottomInset={24} /></div>
      ) : (
        <div className="flex flex-1 flex-col items-center justify-center px-8 text-center">
          <Mascot pose="heart" className="h-28 w-28" />
          <h2 className="mt-3 text-[1.375rem] font-black">That's your {FREE_DAILY_CLIPS} free clips for today</h2>
          <p className="mt-2 text-[0.9375rem] text-muted-foreground">Come back tomorrow, or unlock every clip with a free week of Premium.</p>
          <div className="mt-6 w-full"><Button onClick={() => navigate({ to: "/trial" })}>Try Premium free</Button></div>
        </div>
      ))}
    </div>
  );
}
