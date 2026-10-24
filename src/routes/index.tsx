import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";

import { FadeUp, LivelyMascot } from "@/components/mimi/Mascot";
import { Button, Screen } from "@/components/mimi/ui";
import { useApp } from "@/lib/store";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Kizuki — Learn Japanese from real clips" },
      { name: "description", content: "Watch short real Japanese clips, tap any word for its meaning, and remember it with smart reviews." },
      { property: "og:title", content: "Kizuki — Learn Japanese from real clips" },
      { property: "og:description", content: "Watch short real Japanese clips, tap any word for its meaning, and remember it with smart reviews." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Welcome,
});

function Welcome() {
  const navigate = useNavigate();
  const onboarded = useApp((s) => s.onboarded);
  useEffect(() => {
    // Preview shortcut: /?tour=1 skips onboarding and opens the feed with a fresh welcome tour.
    if (new URLSearchParams(window.location.search).get("tour") === "1") {
      useApp.setState({ onboarded: true, tutorial: { feed: false, review: false }, updatedAt: Date.now() });
      void navigate({ to: "/feed", replace: true });
      return;
    }
    if (onboarded) void navigate({ to: "/feed", replace: true });
  }, [onboarded, navigate]);

  return (
    <Screen scroll={false} className="items-center px-6">
      <div className="flex flex-1 flex-col items-center justify-center text-center">
        {/* Springs in as the splash fades, floats with a breathing glow, hops when tapped (welcome.dart). */}
        <LivelyMascot pose="listen" size={224} idle="float" entrance tappable halo alt="Kizuki the fox" />
        <FadeUp delay={150} className="mt-2">
          <p className="text-[2.75rem] font-black leading-none tracking-tight">kizuki</p>
        </FadeUp>
        <FadeUp delay={200} dy={0} className="mt-1.5">
          <p className="text-[0.875rem] font-bold text-muted-foreground">
            <span className="font-jp text-primary">気づき</span>&nbsp;&nbsp;·&nbsp;&nbsp;the moment it clicks
          </p>
        </FadeUp>
        <FadeUp delay={250} className="mt-3.5">
          <h1 className="max-w-[300px] text-[1.5rem] font-extrabold leading-tight">
            Done with textbooks? <span className="text-primary">Start understanding real Japanese.</span>
          </h1>
        </FadeUp>
        <FadeUp delay={350} dy={0} className="mt-3">
          <p className="max-w-[290px] text-[0.9375rem] text-muted-foreground">Short clips from anime, dramas and vlogs. Tap any word. Remember it for good.</p>
        </FadeUp>
      </div>
      <div className="w-full space-y-3 pb-2">
        <Button onClick={() => navigate({ to: "/onboarding" })}>Get started</Button>
        <Button variant="ghost" size="md" className="w-full" onClick={() => navigate({ to: "/account", search: { mode: "signin" } })}>
          I already have an account
        </Button>
      </div>
    </Screen>
  );
}
