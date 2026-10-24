import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { motion } from "motion/react";
import { useEffect, useMemo, useRef } from "react";

import { LivelyMascot } from "@/components/mimi/Mascot";
import { Confetti } from "@/components/mimi/Confetti";
import { Button, Pill, Screen } from "@/components/mimi/ui";
import { thumbOf } from "@/lib/content";
import { haptic } from "@/lib/haptics";
import { feedOrder, levelFitCount, useContent } from "@/lib/feed";
import { goalDateLabel, planItems, onboardingAfterPlan } from "@/lib/logic";
import { refreshOnboardingSettings } from '@/lib/onboarding-settings';
import { preloadTrial } from '@/lib/trial-preload';
import { useApp } from "@/lib/store";

export const Route = createFileRoute("/plan")({
  head: () => ({
    meta: [
      { title: "Your plan is ready — Kizuki" },
      { name: "description", content: "Your personal Japanese listening plan: daily minutes, clips at your level and a streak goal." },
      { property: "og:title", content: "Your plan is ready — Kizuki" },
      { property: "og:description", content: "Your personal Japanese listening plan: daily minutes, clips at your level and a streak goal." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Plan,
});

function Plan() {
  const navigate = useNavigate();
  const profile = useApp((s) => s.profile);
  const seen = useApp((s) => s.seen);
  const feedSeed = useApp((s) => s.feedSeed);
  const totals = useApp((s) => s.totals);
  const { data } = useContent();
  useEffect(() => { void preloadTrial(); void refreshOnboardingSettings(); }, []);
  // A celebration tap in step with the confetti (plan.dart), once.
  const celebrated = useRef(false);
  useEffect(() => { if (!celebrated.current) { celebrated.current = true; haptic("celebrate"); } }, []);

  const first = useMemo(() => (data ? feedOrder(data, { profile, seen, feedSeed, totals }).slice(0, 3).map((id) => data.byId[id]).filter((c): c is NonNullable<typeof c> => !!c) : []), [data, profile, seen, feedSeed, totals]);
  const items = planItems({
    reasonList: profile.reasons, challengeList: profile.challenges, dailyMinutes: profile.dailyMinutes, window: profile.window,
    streakGoal: profile.streakGoal, jlpt: profile.jlpt, clipCount: data ? levelFitCount(data, profile.jlpt) : 0,
  });

  return (
    <Screen scroll={false} className="px-6">
      <Confetti />
      <div className="min-h-0 flex-1 overflow-y-auto pb-6 no-scrollbar">
      <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="pt-6 text-center">
        <LivelyMascot pose="cheer" size={80} entrance hopAfter={450} tappable className="mx-auto" />
        <h1 className="mt-3 text-[1.625rem] font-black leading-tight">
          {profile.name ? `${profile.name}, your plan is ready!` : "Your plan is ready!"}
        </h1>
        <div className="mt-3 flex justify-center"><Pill tone="success">🇯🇵 Conversational by {goalDateLabel(new Date(), profile.fluencyMonths)}</Pill></div>
      </motion.div>

      <div className="mt-6 space-y-3">
        {items.map((it, i) => (
          <motion.div key={it.title} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.15 + i * 0.08 }} className="flex items-center gap-4 rounded-2xl bg-surface px-4 py-3.5">
            <span className="text-[1.75rem]">{it.icon}</span>
            <span className="min-w-0">
              <span className="block text-[1rem] font-extrabold">{it.title}</span>
              <span className="block text-[0.8125rem] text-muted-foreground">{it.body}</span>
            </span>
          </motion.div>
        ))}
      </div>

      {first.length > 0 && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.6 }} className="mt-6">
          <p className="mb-2 text-[0.8125rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Your first clips</p>
          <div className="grid grid-cols-3 gap-2">
            {first.map((c) => (
              <div key={c.id} className="overflow-hidden rounded-xl bg-surface">
                <img src={thumbOf(c.videoId)} alt="" loading="lazy" className="aspect-video w-full object-cover" />
                <p className="line-clamp-2 px-2 py-1.5 text-[0.6875rem] font-bold leading-tight">{c.title}</p>
              </div>
            ))}
          </div>
        </motion.div>
      )}

      </div>
      <div className="shrink-0 bg-background pb-2 pt-3">
        <Button onClick={async () => { const enabled = await refreshOnboardingSettings(); void navigate({ to: onboardingAfterPlan(enabled) }); }}>Continue</Button>
      </div>
    </Screen>
  );
}
