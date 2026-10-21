import { createFileRoute, useRouter } from "@tanstack/react-router";
import { Lock } from "lucide-react";
import { useShallow } from "zustand/react/shallow";

import { Screen, TopBar } from "@/components/mimi/ui";
import { achievements, isUnlocked, metricValue } from "@/lib/logic";
import { statsOf, useApp } from "@/lib/store";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/achievements")({
  head: () => ({
    meta: [
      { title: "Achievements — Kizuki" },
      { name: "description", content: "Milestones for clips watched, words learned, study time and streaks." },
      { property: "og:title", content: "Achievements — Kizuki" },
      { property: "og:description", content: "Milestones for clips watched, words learned, study time and streaks." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Achievements,
});

function Achievements() {
  const router = useRouter();
  const stats = useApp(useShallow((s) => statsOf(s)));
  const unlocked = achievements.filter((a) => isUnlocked(a, stats)).length;
  return (
    <Screen>
      <TopBar title="Achievements" onBack={() => router.history.back()} />
      <p className="px-5 pb-3 text-center text-[0.9375rem] font-bold text-muted-foreground">{unlocked} of {achievements.length} unlocked</p>
      <div className="grid grid-cols-2 gap-3 px-4 pb-10">
        {achievements.map((a) => {
          const done = isUnlocked(a, stats);
          const v = Math.min(metricValue(stats, a.metric), a.goal);
          return (
            <div key={a.id} className={cn("rounded-2xl p-4", done ? "border-2 border-gold/50 bg-gold/10" : "bg-surface")}>
              <div className="flex items-center justify-between">
                <span className={cn("text-[2rem]", !done && "opacity-50 grayscale")}>{a.icon}</span>
                {!done && <Lock className="h-4 w-4 text-faint" />}
              </div>
              <p className="mt-2 text-[0.9375rem] font-extrabold">{a.title}</p>
              <p className="text-[0.75rem] text-muted-foreground">{a.desc}</p>
              {!done && (
                <div className="mt-2">
                  <div className="h-1.5 overflow-hidden rounded-full bg-surface-2"><div className="h-full rounded-full bg-primary" style={{ width: `${(v / a.goal) * 100}%` }} /></div>
                  <p className="mt-1 text-[0.6875rem] font-bold text-faint tabular">{v} / {a.goal}</p>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </Screen>
  );
}
