import { createFileRoute, Link, useNavigate, useRouter } from "@tanstack/react-router";
import { useState } from "react";

import { Button, Modal, Screen, Toggle, TopBar } from "@/components/mimi/ui";
import { supabase } from "@/integrations/supabase/client";
import { useSession } from "@/hooks/use-session";
import { getContent } from "@/lib/content";
import { downloadText, wordsCsv } from "@/lib/export";
import { jlptLevels, windowLabel } from "@/lib/logic";
import { windowOptions } from "@/lib/onboarding";
import { FREE_DAILY_CLIPS } from "@/lib/paywall";
import { requestReminderPermission } from "@/lib/reminders";
import { flushSync } from "@/lib/sync";
import { useApp, type Settings } from "@/lib/store";
import { toast } from "@/lib/ui-store";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/settings")({
  head: () => ({
    meta: [
      { title: "Settings — Kizuki" },
      { name: "description", content: "Level, display, flashcards, reminders, subscription and account settings." },
      { property: "og:title", content: "Settings — Kizuki" },
      { property: "og:description", content: "Level, display, flashcards, reminders, subscription and account settings." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: SettingsPage,
});

const LEVEL_HINT: Record<string, string> = {
  N5: "Complete beginner — greetings and simple phrases",
  N4: "Basic — everyday words and short sentences",
  N3: "Intermediate — everyday conversations at natural speed",
  N2: "Upper-intermediate — dramas, news and fast talk",
  N1: "Advanced — almost everything",
};

function SettingsPage() {
  const router = useRouter();
  const navigate = useNavigate();
  const session = useSession();
  const s = useApp((x) => x.settings);
  const profile = useApp((x) => x.profile);
  const premium = useApp((x) => x.premium);
  const { setSettings, setProfile, resetTutorial, cancelPremium, reset } = useApp.getState();
  const [confirm, setConfirm] = useState<null | "delete" | "cancel">(null);
  const [busy, setBusy] = useState(false);

  const signOut = async () => {
    await flushSync();
    await supabase.auth.signOut();
    toast({ icon: "👋", title: "Signed out", description: "Your progress stays on this device." });
  };

  const deleteAccount = async () => {
    setBusy(true);
    const { error } = await supabase.rpc("delete_my_account");
    setBusy(false);
    if (error) { toast({ tone: "error", title: "Couldn't delete your account", description: error.message }); return; }
    await supabase.auth.signOut();
    localStorage.clear();
    reset();
    setConfirm(null);
    void navigate({ to: "/", replace: true });
  };

  const exportWords = () => {
    const words = Object.values(useApp.getState().words);
    if (!words.some((w) => w.status !== "removed")) { toast({ title: "No saved words yet" }); return; }
    downloadText(`kizuki-words-${new Date().toISOString().slice(0, 10)}.csv`, wordsCsv(words, getContent()));
  };

  const T = ({ k, label, hint }: { k: keyof Settings; label: string; hint?: string }) => (
    <div className="flex items-center justify-between gap-3 px-4 py-3">
      <span className="min-w-0"><span className="block text-[0.9375rem] font-bold">{label}</span>{hint && <span className="block text-[0.75rem] text-muted-foreground">{hint}</span>}</span>
      <Toggle label={label} checked={!!s[k]} onChange={(v) => setSettings({ [k]: v } as Partial<Settings>)} />
    </div>
  );

  return (
    <Screen>
      <TopBar title="Settings" onBack={() => router.history.back()} />
      <div className="space-y-6 px-4 pb-10 pt-2">
        <Group title="Learning">
          <div className="px-4 py-3">
            <p className="text-[0.9375rem] font-bold">Japanese level</p>
            <div className="mt-2 grid grid-cols-5 gap-1.5">
              {jlptLevels.map((l) => (
                <button key={l} onClick={() => setProfile({ jlpt: l })} className={cn("press h-10 rounded-xl text-[0.875rem] font-black", profile.jlpt === l ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}>{l}</button>
              ))}
            </div>
            <p className="mt-2 text-[0.8125rem] text-muted-foreground">{LEVEL_HINT[profile.jlpt]}</p>
          </div>
          <div className="px-4 py-3">
            <div className="flex justify-between"><p className="text-[0.9375rem] font-bold">Daily goal</p><p className="text-[0.9375rem] font-black text-primary tabular">{profile.dailyMinutes} min</p></div>
            <input type="range" min={5} max={60} step={5} value={profile.dailyMinutes} onChange={(e) => setProfile({ dailyMinutes: Number(e.target.value) })} aria-label="Daily goal minutes" className="mt-2 w-full accent-[var(--primary)]" />
          </div>
        </Group>

        <Group title="Display">
          <T k="furigana" label="Show furigana" />
          <T k="romaji" label="Show romaji" />
          <T k="translation" label="Show translation" />
          <T k="spacing" label="Space between words" hint="Turn off for natural Japanese text" />
          <T k="highlight" label="Highlight the spoken word" />
          <T k="autoSave" label="Save words I tap" hint="Off: save only with the Save button" />
          <div className="px-4 py-3">
            <p className="text-[0.9375rem] font-bold">Text size</p>
            <div className="mt-2 grid grid-cols-3 gap-1.5">
              {[{ v: 0.85, l: "Small" }, { v: 1, l: "Medium" }, { v: 1.2, l: "Large" }].map((o) => (
                <button key={o.v} onClick={() => setSettings({ textSize: o.v })} className={cn("press h-10 rounded-xl text-[0.875rem] font-extrabold", s.textSize === o.v ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}>{o.l}</button>
              ))}
            </div>
          </div>
        </Group>

        <Group title="Flashcards">
          <div className="px-4 py-3">
            <p className="text-[0.9375rem] font-bold">Card front</p>
            <div className="mt-2 grid grid-cols-2 gap-1.5">
              {([["jp", "Japanese → English"], ["en", "English → Japanese"]] as const).map(([v, l]) => (
                <button key={v} onClick={() => setSettings({ flashFront: v })} className={cn("press h-10 rounded-xl text-[0.8125rem] font-extrabold", s.flashFront === v ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}>{l}</button>
              ))}
            </div>
          </div>
          <T k="flashFurigana" label="Furigana on the front" />
          <T k="flashRomaji" label="Romaji on the front" />
        </Group>

        <Group title="Reminders">
          <div className="flex items-center justify-between gap-3 px-4 py-3">
            <span className="text-[0.9375rem] font-bold">Daily reminder</span>
            <Toggle label="Daily reminder" checked={s.reminders} onChange={async (v) => { if (v) await requestReminderPermission(); setSettings({ reminders: v }); }} />
          </div>
          {s.reminders && (
            <>
              <div className="px-4 py-3">
                <p className="text-[0.9375rem] font-bold">Study window <span className="font-normal text-muted-foreground">· {windowLabel(profile.window)}</span></p>
                <div className="mt-2 grid grid-cols-4 gap-1.5">
                  {windowOptions.map((o) => (
                    <button key={o.id} onClick={() => setProfile({ window: o.id })} className={cn("press flex h-14 flex-col items-center justify-center rounded-xl text-[0.75rem] font-extrabold", profile.window === o.id ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}><span className="text-[1.125rem]">{o.emoji}</span>{o.label}</button>
                  ))}
                </div>
              </div>
              <div className="px-4 py-3">
                <p className="text-[0.9375rem] font-bold">How often</p>
                <div className="mt-2 grid grid-cols-2 gap-1.5">
                  {([["standard", "Daily", "A friendly nudge each day"], ["minimal", "Minimal", "Only to save your streak"]] as const).map(([v, l, h]) => (
                    <button key={v} onClick={() => setSettings({ reminderFreq: v })} className={cn("press rounded-xl px-3 py-2 text-left", s.reminderFreq === v ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}><span className="block text-[0.875rem] font-extrabold">{l}</span><span className="block text-[0.6875rem] opacity-80">{h}</span></button>
                  ))}
                </div>
              </div>
            </>
          )}
        </Group>

        <Group title="Your data">
          <ActionRow label="Export saved words (.csv)" onClick={exportWords} />
          <ActionRow label="Replay the welcome tour" onClick={() => { resetTutorial(); toast({ icon: "🦊", title: "Tour reset", description: "Kizuki will show you around on the feed." }); void navigate({ to: "/feed" }); }} />
        </Group>

        <Group title="Subscription">
          {premium.active ? (
            <>
              <div className="px-4 py-3"><p className="text-[0.9375rem] font-bold">Kizuki Premium · {premium.plan === "monthly" ? "Monthly" : "Yearly"}</p><p className="text-[0.8125rem] text-muted-foreground">{premium.trialEndsAt && premium.trialEndsAt > Date.now() ? `Free trial until ${new Date(premium.trialEndsAt).toLocaleDateString()}` : "Active"}</p></div>
              <ActionRow label="Manage subscription" onClick={() => setConfirm("cancel")} />
            </>
          ) : (
            <>
              <ActionRow label="Try Premium free for 7 days" onClick={() => navigate({ to: "/trial" })} />
              {/* Same store restore as the paywall; the web prototype has no store, so it reports none found. */}
              <ActionRow label="Restore purchase" onClick={() => toast({ title: "No subscription found", description: "Use the same store account you bought with." })} />
            </>
          )}
        </Group>

        <Group title="Account">
          {session ? (
            <>
              <div className="px-4 py-3 text-[0.875rem] text-muted-foreground">Signed in as <b className="text-foreground">{session.user.email}</b></div>
              <ActionRow label="Sign out" onClick={() => void signOut()} />
              <ActionRow label="Delete account" danger onClick={() => setConfirm("delete")} />
            </>
          ) : (
            <ActionRow label="Sign in or create an account" onClick={() => navigate({ to: "/account", search: { mode: "signin" } })} />
          )}
        </Group>

        <Group title="Help">
          <ActionRow label="Help & support" onClick={() => navigate({ to: "/support" })} />
        </Group>

        <div className="space-y-2 px-2 text-center text-[0.75rem] leading-relaxed text-faint">
          <p><Link to="/terms" className="underline">Terms of Service</Link> · <Link to="/privacy" className="underline">Privacy Policy</Link></p>
          <p>Videos play through YouTube and belong to their creators. Dictionary data: JMdict (EDRDG), CC BY-SA 4.0. Example sentences: Tatoeba, CC BY 2.0 FR.</p>
        </div>
      </div>

      <Modal open={confirm === "delete"} onClose={() => setConfirm(null)}>
        <h2 className="text-[1.25rem] font-black">Delete your account?</h2>
        <p className="mt-2 text-[0.9375rem] text-muted-foreground">This permanently deletes your account and cloud progress. It can't be undone.</p>
        <div className="mt-5 space-y-2">
          <Button variant="danger" disabled={busy} onClick={() => void deleteAccount()}>{busy ? "Deleting…" : "Delete forever"}</Button>
          <Button variant="ghost" size="md" className="w-full" onClick={() => setConfirm(null)}>Keep my account</Button>
        </div>
      </Modal>
      <Modal open={confirm === "cancel"} onClose={() => setConfirm(null)}>
        <h2 className="text-[1.25rem] font-black">Manage subscription</h2>
        <p className="mt-2 text-[0.9375rem] text-muted-foreground">In the phone app this opens your App Store or Google Play subscriptions. This preview has no store, so you can end the simulated plan here — you'll go back to {FREE_DAILY_CLIPS} free clips a day and keep your words.</p>
        <div className="mt-5 space-y-2">
          <Button variant="danger" onClick={() => { cancelPremium(); setConfirm(null); toast({ title: "Premium ended (preview)" }); }}>End simulated plan</Button>
          <Button variant="ghost" size="md" className="w-full" onClick={() => setConfirm(null)}>Keep Premium</Button>
        </div>
      </Modal>
    </Screen>
  );
}

function Group({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <p className="mb-2 px-1 text-[0.8125rem] font-black uppercase tracking-[0.12em] text-muted-foreground">{title}</p>
      <div className="divide-y divide-border overflow-hidden rounded-2xl bg-surface">{children}</div>
    </section>
  );
}

function ActionRow({ label, onClick, danger }: { label: string; onClick: () => void; danger?: boolean }) {
  return <button onClick={onClick} className={cn("press block w-full px-4 py-3.5 text-left text-[0.9375rem] font-bold", danger && "text-danger")}>{label}</button>;
}
