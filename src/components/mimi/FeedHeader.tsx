import { Link } from "@tanstack/react-router";
import { Trophy } from "lucide-react";

import { goalProgress, minutesLeft } from "@/lib/logic";
import { todayOf, useApp } from "@/lib/store";
import { cn } from "@/lib/utils";

/** Daily-goal bar + For You / Explore tabs (top of the Feed). */
export function FeedHeader({ tab }: { tab: "foryou" | "explore" }) {
  const goal = useApp((s) => s.profile.dailyMinutes);
  const sec = useApp((s) => todayOf(s).sec);
  const left = minutesLeft(goal, sec);
  const pct = goalProgress(goal, sec);
  return (
    <div className="shrink-0 bg-background px-4 pb-1">
      <div className="flex items-center gap-3 pt-1">
        <div className="relative h-3 flex-1 overflow-hidden rounded-full bg-surface-2">
          <div className="h-full rounded-full bg-primary transition-[width] duration-700" style={{ width: `${Math.max(3, pct * 100)}%` }} />
        </div>
        <span className={cn("flex items-center gap-1 text-[0.8125rem] font-black tabular", left === 0 ? "text-gold" : "text-muted-foreground")}>
          {left === 0 ? "Goal done!" : `${left} min left`}
          <Trophy className={cn("h-4 w-4", left === 0 ? "fill-gold text-gold" : "text-faint")} />
        </span>
      </div>
      <div className="mt-2 flex justify-center gap-8">
        <HeaderTab to="/feed" active={tab === "foryou"}>For You</HeaderTab>
        <HeaderTab to="/explore" active={tab === "explore"}>Explore</HeaderTab>
      </div>
    </div>
  );
}

function HeaderTab({ to, active, children }: { to: "/feed" | "/explore"; active: boolean; children: React.ReactNode }) {
  return (
    <Link to={to} className={cn("relative pb-2 text-[1rem] font-black", active ? "text-foreground" : "text-faint")}>
      {children}
      {active && <span className="absolute inset-x-1 bottom-0 h-[3px] rounded-full bg-primary" />}
    </Link>
  );
}
