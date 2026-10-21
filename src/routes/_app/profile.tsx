import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { ChevronRight, Crown, Lock, Settings as Gear } from "lucide-react";
import { useMemo } from "react";
import { useShallow } from "zustand/react/shallow";

import { Mascot } from "@/components/mimi/Mascot";
import { Screen, SectionTitle } from "@/components/mimi/ui";
import { useSession } from "@/hooks/use-session";
import { achievements, dayKey, dayMs, heatLevel, heatmapWeeks, isUnlocked, metricValue } from "@/lib/logic";
import { statsOf, useApp } from "@/lib/store";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/_app/profile")({
  head: () => ({
    meta: [
      { title: "Your progress — Kizuki" },
      { name: "description", content: "Your streak, study time, words and achievements in Kizuki." },
      { property: "og:title", content: "Your progress — Kizuki" },
      { property: "og:description", content: "Your streak, study time, words and achievements in Kizuki." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Profile,
});

const HEAT = ["bg-surface-2", "bg-primary/25", "bg-primary/50", "bg-primary/75", "bg-primary"];
const fmtTime = (sec: number) => (sec < 3600 ? `${Math.floor(sec / 60)}m` : `${Math.floor(sec / 3600)}h ${Math.floor((sec % 3600) / 60)}m`);

function Profile() {
  const navigate = useNavigate();
  const session = useSession();
  const name = useApp((s) => s.profile.name);
  const goal = useApp((s) => s.profile.dailyMinutes);
  const activity = useApp((s) => s.activity);
  const premium = useApp((s) => s.premium);
  const stats = useApp(useShallow((s) => statsOf(s)));
  const weeks = useMemo(() => heatmapWeeks(new Date(), 16), []);
  const today = dayKey(new Date());
  const trialDays = premium.trialEndsAt ? Math.max(0, Math.ceil((premium.trialEndsAt - Date.now()) / dayMs)) : 0;

  return (
    <Screen>
      <div className="flex h-12 shrink-0 items-center justify-end px-3">
        <Link to="/settings" aria-label="Settings" className="press flex h-10 w-10 items-center justify-center rounded-full text-muted-foreground"><Gear className="h-6 w-6" /></Link>
      </div>
      <div className="flex flex-col items-center px-5">
        <div className="flex h-24 w-24 items-center justify-center rounded-full bg-surface"><Mascot pose="face" className="h-20 w-20" /></div>
        <p className="mt-2 text-[1.5rem] font-black">{name || "Learner"}</p>
        {session?.user.email && <p className="text-[0.8125rem] font-bold text-faint">{session.user.email}</p>}
      </div>

      <div className="mx-5 mt-4 grid grid-cols-3 divide-x divide-border rounded-2xl bg-surface py-3">
        <Stat icon="🔥" value={String(stats.streak)} label="Streak" />
        <Stat icon="📚" value={String(stats.words)} label="Words" />
        <Stat icon="⏰" value={fmtTime(stats.seconds)} label="Time" />
      </div>

      <div className="px-5">
        <SectionTitle>Activity</SectionTitle>
        <div className="rounded-2xl bg-surface p-3">
          <div className="flex justify-between gap-[3px]">
            {weeks.map((wk, i) => (
              <div key={i} className="flex flex-1 flex-col gap-[3px]">
                {wk.map((d) => {
                  const lv = d > today ? -1 : heatLevel(activity[d]?.sec ?? 0, goal);
                  return <div key={d} title={d} className={cn("aspect-square w-full rounded-[3px]", lv < 0 ? "bg-transparent" : HEAT[lv], d === today && "ring-1 ring-foreground/60")} />;
                })}
              </div>
            ))}
          </div>
          <div className="mt-2 flex items-center justify-end gap-1 text-[0.6875rem] font-bold text-faint">Less {HEAT.map((h) => <span key={h} className={cn("h-2.5 w-2.5 rounded-[2px]", h)} />)} More</div>
        </div>

        <SectionTitle right={<Link to="/achievements" className="flex items-center text-[0.875rem] font-extrabold text-muted-foreground">View all <ChevronRight className="h-4 w-4" /></Link>}>Achievements</SectionTitle>
        <div className="flex gap-3 overflow-x-auto pb-1 no-scrollbar">
          {achievements.slice(0, 8).map((a) => {
            const done = isUnlocked(a, stats);
            return (
              <div key={a.id} className="flex w-[74px] shrink-0 flex-col items-center text-center">
                <span className={cn("relative flex h-16 w-16 items-center justify-center rounded-full text-[1.75rem]", done ? "bg-gold/20 ring-2 ring-gold" : "bg-surface opacity-60 grayscale")}>
                  {a.icon}
                  {!done && <Lock className="absolute -bottom-0.5 -right-0.5 h-5 w-5 rounded-full bg-surface-3 p-1" />}
                </span>
                <span className="mt-1.5 line-clamp-2 text-[0.6875rem] font-extrabold leading-tight">{a.title}</span>
                {!done && <span className="text-[0.625rem] font-bold text-faint tabular">{Math.min(metricValue(stats, a.metric), a.goal)}/{a.goal}</span>}
              </div>
            );
          })}
        </div>

        <div className="mt-5 space-y-2 pb-28">
          {premium.active ? (
            <Row icon={<Crown className="h-5 w-5 text-gold" />} title="Kizuki Premium" sub={trialDays > 0 ? `Free trial · ${trialDays} day${trialDays === 1 ? "" : "s"} left` : "Active"} onClick={() => navigate({ to: "/settings" })} />
          ) : (
            <Row icon={<Crown className="h-5 w-5 text-gold" />} title="Try Premium free" sub="Unlimited clips for 7 days" onClick={() => navigate({ to: "/trial" })} accent />
          )}
          {!session && <Row icon="☁️" title="Save your progress" sub="Create a free account to sync devices" onClick={() => navigate({ to: "/account", search: { mode: "signup" } })} />}
          <Row icon="🔖" title="Saved clips" sub="Clips you bookmarked" onClick={() => navigate({ to: "/saved" })} />
          <Row icon="⏱️" title="Watch history" sub="Everything you've watched" onClick={() => navigate({ to: "/history" })} />
          <Row icon="✉️" title="Contact the founder" sub="Feedback, ideas or just say hi" onClick={() => { window.location.href = "mailto:hello@kizuki.app?subject=Kizuki%20feedback"; }} />
        </div>
      </div>
    </Screen>
  );
}

function Stat({ icon, value, label }: { icon: string; value: string; label: string }) {
  return (
    <div className="flex flex-col items-center">
      <span className="text-[1.25rem] font-black tabular">{icon} {value}</span>
      <span className="text-[0.75rem] font-bold text-muted-foreground">{label}</span>
    </div>
  );
}

function Row({ icon, title, sub, onClick, accent }: { icon: React.ReactNode; title: string; sub: string; onClick: () => void; accent?: boolean }) {
  return (
    <button onClick={onClick} className={cn("press flex w-full items-center gap-3 rounded-2xl px-4 py-3.5 text-left", accent ? "border-2 border-gold/50 bg-gold/10" : "bg-surface")}>
      <span className="flex h-9 w-9 items-center justify-center text-[1.375rem]">{icon}</span>
      <span className="min-w-0 flex-1">
        <span className="block text-[1rem] font-extrabold">{title}</span>
        <span className="block text-[0.8125rem] text-muted-foreground">{sub}</span>
      </span>
      <ChevronRight className="h-5 w-5 text-faint" />
    </button>
  );
}
