import { useEffect } from "react";

import { newlyUnlocked } from "@/lib/logic";
import { statsOf, useApp } from "@/lib/store";
import { startSync } from "@/lib/sync";
import { toast } from "@/lib/ui-store";

/** App-wide side effects: cloud sync and achievement celebrations. */
export function AppEffects() {
  useEffect(() => {
    startSync();
  }, []);

  const totals = useApp((s) => s.totals);
  const words = useApp((s) => s.words);
  const activity = useApp((s) => s.activity);
  const onboarded = useApp((s) => s.onboarded);

  useEffect(() => {
    if (!onboarded) return;
    const s = useApp.getState();
    const fresh = newlyUnlocked(statsOf(s), s.achievementsSeen);
    if (!fresh.length) return;
    s.markAchievementsSeen(fresh.map((a) => a.id));
    for (const a of fresh) toast({ tone: "achievement", icon: a.icon, title: a.title, description: a.desc });
  }, [totals, words, activity, onboarded]);

  return null;
}
