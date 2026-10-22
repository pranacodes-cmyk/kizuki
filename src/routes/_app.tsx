import { createFileRoute, Outlet, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";

import { TabBar } from "@/components/mimi/TabBar";
import { useApp } from "@/lib/store";

/** Main app shell (Feed / Explore / Vocab / Profile) with the floating tab bar. */
export const Route = createFileRoute("/_app")({
  component: AppLayout,
});

function AppLayout() {
  const onboarded = useApp((s) => s.onboarded);
  const navigate = useNavigate();
  useEffect(() => {
    if (!onboarded) void navigate({ to: "/", replace: true });
  }, [onboarded, navigate]);
  if (!onboarded) return null;
  return (
    <>
      <Outlet />
      <TabBar />
    </>
  );
}
