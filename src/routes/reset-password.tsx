import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useState, type FormEvent } from "react";

import { Mascot } from "@/components/mimi/Mascot";
import { Button, Screen } from "@/components/mimi/ui";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "@/lib/ui-store";

export const Route = createFileRoute("/reset-password")({
  head: () => ({
    meta: [
      { title: "Choose a new password — Kizuki" },
      { name: "description", content: "Set a new password for your Kizuki account." },
      { property: "og:title", content: "Choose a new password — Kizuki" },
      { property: "og:description", content: "Set a new password for your Kizuki account." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ResetPassword,
});

function ResetPassword() {
  const navigate = useNavigate();
  const [pw, setPw] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (pw.length < 8) return setError("Use at least 8 characters");
    setBusy(true);
    const { error } = await supabase.auth.updateUser({ password: pw });
    setBusy(false);
    if (error) return setError(error.message.includes("session") ? "This reset link has expired. Request a new one from the sign-in screen." : error.message);
    toast({ icon: "🔒", title: "Password updated" });
    void navigate({ to: "/feed", replace: true });
  };

  return (
    <Screen className="px-6">
      <div className="flex flex-col items-center pt-10 text-center">
        <Mascot pose="think" className="h-28 w-28" />
        <h1 className="mt-3 text-[1.5rem] font-black">Choose a new password</h1>
      </div>
      <form onSubmit={submit} className="mt-8 space-y-3">
        <input type="password" value={pw} onChange={(e) => setPw(e.target.value)} placeholder="New password" autoComplete="new-password" aria-label="New password" className="h-14 w-full rounded-2xl border-2 border-border bg-surface px-4 text-[1rem] font-bold outline-none placeholder:text-faint focus:border-primary" />
        {error && <p role="alert" className="rounded-xl bg-danger-soft px-3 py-2 text-[0.875rem] font-bold text-danger">{error}</p>}
        <Button type="submit" disabled={busy}>{busy ? "Saving…" : "Save password"}</Button>
      </form>
    </Screen>
  );
}
