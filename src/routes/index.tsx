import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { motion } from "motion/react";
import { useEffect } from "react";

import { Mascot } from "@/components/mimi/Mascot";
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
        <motion.div initial={{ scale: 0.7, opacity: 0, y: 30 }} animate={{ scale: 1, opacity: 1, y: 0 }} transition={{ type: "spring", stiffness: 200, damping: 16 }} className="relative">
          <div className="absolute inset-6 rounded-full bg-primary/20 blur-2xl" />
          <Mascot pose="listen" className="relative h-56 w-56" alt="Kizuki the fox" />
        </motion.div>
        <motion.p initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.15 }} className="mt-2 text-[2.75rem] font-black leading-none tracking-tight">
          kizuki
        </motion.p>
        <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.2 }} className="mt-1.5 text-[0.875rem] font-bold text-muted-foreground">
          <span className="font-jp text-primary">気づき</span>&nbsp;&nbsp;·&nbsp;&nbsp;the moment it clicks
        </motion.p>
        <motion.h1 initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.25 }} className="mt-3.5 max-w-[300px] text-[1.5rem] font-extrabold leading-tight">
          Done with textbooks? <span className="text-primary">Start understanding real Japanese.</span>
        </motion.h1>
        <motion.p initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.35 }} className="mt-3 max-w-[290px] text-[0.9375rem] text-muted-foreground">
          Short clips from anime, dramas and vlogs. Tap any word. Remember it for good.
        </motion.p>
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
