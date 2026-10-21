import { createFileRoute, Outlet, useNavigate, useRouterState } from "@tanstack/react-router";
import { useEffect } from "react";

import { TabBar } from "@/components/mimi/TabBar";
import { WelcomeTour } from "@/components/mimi/WelcomeTour";
import { useApp } from "@/lib/store";

/** Main app shell (Feed / Explore / Vocab / Profile) with the floating tab bar. */
export const Route = createFileRoute("/_app")({
  component: AppLayout,
});

function AppLayout() {
  const onboarded = useApp((s) => s.onboarded);
  const tourDone = useApp((s) => s.tutorial.feed);
  const path = useRouterState({ select: (s) => s.location.pathname });
  const navigate = useNavigate();
  useEffect(() => {
    if (!onboarded) void navigate({ to: "/", replace: true });
  }, [onboarded, navigate]);
  if (!onboarded) return null;
  return (
    <>
      <Outlet />
      <TabBar />
      {!tourDone && path === "/feed" && <WelcomeTour />}
    </>
  );
}
