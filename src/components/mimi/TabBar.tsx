import { Link, useRouterState } from "@tanstack/react-router";
import { BookOpen, Play, User } from "lucide-react";

import { haptic } from "@/lib/haptics";
import { countsOf, useApp } from "@/lib/store";
import { cn } from "@/lib/utils";

const TABS = [
  { to: "/feed", match: ["/feed", "/explore"], label: "Feed", icon: Play },
  { to: "/vocab", match: ["/vocab"], label: "Vocab", icon: BookOpen },
  { to: "/profile", match: ["/profile"], label: "Profile", icon: User },
] as const;

/** Floating bottom navigation pill — mirrored by TabBar in mobile/lib/widgets/tab_bar.dart. */
export function TabBar() {
  const path = useRouterState({ select: (s) => s.location.pathname });
  const due = useApp((s) => countsOf(s).due);
  return (
    <nav className="pointer-events-none absolute inset-x-0 bottom-0 z-40 flex justify-center pb-[calc(var(--sab)+10px)]">
      <div className="pointer-events-auto flex items-center gap-1 rounded-full border border-border bg-surface/95 p-1.5 shadow-[0_16px_40px_-12px_oklch(0_0_0/0.7)] backdrop-blur">
        {TABS.map((t) => {
          const active = t.match.some((m) => path.startsWith(m));
          const Icon = t.icon;
          return (
            <Link key={t.to} to={t.to} onClick={() => { if (!active) haptic("select"); }} aria-label={t.label} data-tour={t.label === "Vocab" ? "vocabTab" : undefined} className={cn("relative flex h-12 items-center gap-2 rounded-full px-5 text-[0.875rem] font-extrabold transition-colors", active ? "bg-surface-3 text-foreground" : "text-faint")}>
              <Icon className={cn("h-5 w-5", active && t.label === "Feed" && "fill-current")} strokeWidth={2.4} />
              {active && <span>{t.label}</span>}
              {t.label === "Vocab" && due > 0 && (
                <span className="absolute -right-0.5 -top-0.5 flex h-5 min-w-5 items-center justify-center rounded-full bg-primary px-1 text-[0.6875rem] font-black text-primary-foreground tabular">{due > 99 ? "99+" : due}</span>
              )}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
