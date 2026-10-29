import { createFileRoute, Link, useNavigate, useRouter } from "@tanstack/react-router";
import { ChevronRight } from "lucide-react";
import { useState, useSyncExternalStore } from "react";

import { Button, Hi, Modal, Screen, Toggle, TopBar } from "@/components/mimi/ui";
import { AnalyticsToggle } from "@/components/mimi/AnalyticsConsent";
import { supabase } from "@/lib/backend";
import { useSession } from "@/hooks/use-session";
import { getContent } from "@/lib/content";
import { downloadText, wordsCsv } from "@/lib/export";
import { haptic, hapticsOn, setHapticsEnabled } from "@/lib/haptics";
import { jlptLevels, windowLabel, subscriptionPhase, type LangCode } from "@/lib/logic";
import { localePackState, subscribeLocalePack } from "@/lib/locale-pack";
import { windowOptions } from "@/lib/onboarding";
import { FREE_DAILY_CLIPS } from "@/lib/paywall";
import { requestReminderPermission } from "@/lib/reminders";
import { flushSync } from "@/lib/sync";
import { useApp, type Settings } from "@/lib/store";
import { toast } from "@/lib/ui-store";
import { cn } from "@/lib/utils";
import { currentLanguage, getLang, tr } from "@/lib/i18n";

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
  const phase = subscriptionPhase(premium.active, premium.plan, premium.trialEndsAt, Date.now());
  const { setSettings, setProfile, resetTutorial, cancelPremium, reset } = useApp.getState();
  const [confirm, setConfirm] = useState<null | "delete" | "cancel">(null);
  const [busy, setBusy] = useState(false);

  const signOut = async () => {
    await flushSync();
    await supabase.auth.signOut();
    toast({ icon: "👋", title: tr("Signed out"), description: tr("Your progress stays on this device.") });
  };

  const deleteAccount = async () => {
    setBusy(true);
    const { error } = await supabase.rpc("delete_my_account");
    setBusy(false);
    if (error) { toast({ tone: "error", title: tr("Couldn't delete your account"), description: error.message }); return; }
    await supabase.auth.signOut();
    localStorage.clear();
    reset();
    setConfirm(null);
    void navigate({ to: "/", replace: true });
  };

  const exportWords = () => {
    const words = Object.values(useApp.getState().words);
    if (!words.some((w) => w.status !== "removed")) { toast({ title: tr("No saved words yet") }); return; }
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
      <TopBar title={tr("Settings")} onBack={() => router.history.back()} />
      <div className="space-y-6 px-4 pb-10 pt-2">
        <Group title={tr("Learning")}>
          <div className="px-4 py-3">
            <p className="text-[0.9375rem] font-bold">{tr("Japanese level")}</p>
            <div className="mt-2 grid grid-cols-5 gap-1.5">
              {jlptLevels.map((l) => (
                <button key={l} onClick={() => setProfile({ jlpt: l })} className={cn("press h-10 rounded-xl text-[0.875rem] font-black", profile.jlpt === l ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}>{l}</button>
              ))}
            </div>
            <p className="mt-2 text-[0.8125rem] text-muted-foreground">{LEVEL_HINT[profile.jlpt]}</p>
          </div>
          <div className="px-4 py-3">
            <div className="flex justify-between"><p className="text-[0.9375rem] font-bold">{tr("Daily goal")}</p><p className="text-[0.9375rem] font-black text-primary tabular">{tr("{minutes} min", { minutes: profile.dailyMinutes })}</p></div>
            <input type="range" min={5} max={60} step={5} value={profile.dailyMinutes} onChange={(e) => setProfile({ dailyMinutes: Number(e.target.value) })} aria-label={tr("Daily goal minutes")} className="mt-2 w-full accent-[var(--primary)]" />
          </div>
        </Group>

        <Group title={tr("Display")}>
          <LanguageRow onClick={() => void navigate({ to: "/language", search: { from: "settings" } })} />
          <T k="furigana" label={tr("Show furigana")} />
          <T k="romaji" label={tr("Show romaji")} />
          <T k="translation" label={tr("Show translation")} />
          <T k="spacing" label={tr("Space between words")} hint={tr("Turn off for natural Japanese text")} />
          <T k="highlight" label={tr("Highlight the spoken word")} />
          <T k="autoSave" label={tr("Save words I tap")} hint={tr("Off: save only with the Save button")} />
          <div className="flex items-center justify-between gap-3 px-4 py-3">
            <span className="min-w-0"><span className="block text-[0.9375rem] font-bold">{tr("Vibration feedback")}</span><span className="block text-[0.75rem] text-muted-foreground">{tr("Gentle taps for buttons and milestones")}</span></span>
            <Toggle
              label={tr("Vibration feedback")}
              checked={hapticsOn(s)}
              onChange={(v) => { setSettings({ haptics: v }); setHapticsEnabled(v); if (v) haptic("light"); }}
            />
          </div>
          <div className="px-4 py-3">
            <p className="text-[0.9375rem] font-bold">{tr("Text size")}</p>
            <div className="mt-2 grid grid-cols-3 gap-1.5">
              {[{ v: 0.85, l: tr("Small") }, { v: 1, l: tr("Medium") }, { v: 1.2, l: tr("Large") }].map((o) => (
                <button key={o.v} onClick={() => setSettings({ textSize: o.v })} className={cn("press h-10 rounded-xl text-[0.875rem] font-extrabold", s.textSize === o.v ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}>{o.l}</button>
              ))}
            </div>
          </div>
        </Group>

        <Group title={tr("Flashcards")}>
          <div className="px-4 py-3">
            <p className="text-[0.9375rem] font-bold">{tr("Card front")}</p>
            <div className="mt-2 grid grid-cols-2 gap-1.5">
              {([["jp", tr("Japanese → English")], ["en", tr("English → Japanese")]] as const).map(([v, l]) => (
                <button key={v} onClick={() => setSettings({ flashFront: v })} className={cn("press h-10 rounded-xl text-[0.8125rem] font-extrabold", s.flashFront === v ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}>{l}</button>
              ))}
            </div>
          </div>
          <T k="flashFurigana" label={tr("Furigana on the front")} />
          <T k="flashRomaji" label={tr("Romaji on the front")} />
        </Group>

        <Group title={tr("Reminders")}>
          <div className="flex items-center justify-between gap-3 px-4 py-3">
            <span className="text-[0.9375rem] font-bold">{tr("Daily reminder")}</span>
            <Toggle label={tr("Daily reminder")} checked={s.reminders} onChange={async (v) => { if (v) await requestReminderPermission(); setSettings({ reminders: v }); }} />
          </div>
          {s.reminders && (
            <>
              <div className="px-4 py-3">
                <p className="text-[0.9375rem] font-bold"><Hi text={tr("Study window [· {when}]", { when: windowLabel(profile.window) })} className="font-normal text-muted-foreground" /></p>
                <div className="mt-2 grid grid-cols-4 gap-1.5">
                  {windowOptions.map((o) => (
                    <button key={o.id} onClick={() => setProfile({ window: o.id })} className={cn("press flex h-14 flex-col items-center justify-center rounded-xl text-[0.75rem] font-extrabold", profile.window === o.id ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}><span className="text-[1.125rem]">{o.emoji}</span>{tr(o.label)}</button>
                  ))}
                </div>
              </div>
              <div className="px-4 py-3">
                <p className="text-[0.9375rem] font-bold">{tr("How often")}</p>
                <div className="mt-2 grid grid-cols-2 gap-1.5">
                  {([["standard", tr("Daily"), tr("A friendly nudge each day")], ["minimal", tr("Minimal"), tr("Only to save your streak")]] as const).map(([v, l, h]) => (
                    <button key={v} onClick={() => setSettings({ reminderFreq: v })} className={cn("press rounded-xl px-3 py-2 text-left", s.reminderFreq === v ? "bg-primary text-primary-foreground" : "bg-surface-2 text-muted-foreground")}><span className="block text-[0.875rem] font-extrabold">{l}</span><span className="block text-[0.6875rem] opacity-80">{h}</span></button>
                  ))}
                </div>
              </div>
            </>
          )}
        </Group>

        <Group title={tr("Your data")}>
          <AnalyticsToggle />
          <ActionRow label={tr("Export saved words (.csv)")} onClick={exportWords} />
          <ActionRow label={tr("Replay the welcome tour")} onClick={() => { resetTutorial(); toast({ icon: "🦊", title: tr("Tour reset"), description: tr("Kizuki will show you around on the feed.") }); void navigate({ to: "/feed" }); }} />
        </Group>

        <Group title={tr("Subscription")}>
          {premium.active ? (
            <>
              <div className="px-4 py-3"><p className="text-[0.9375rem] font-bold">{tr("Kizuki Premium · {plan}", { plan: premium.plan === "monthly" ? tr("Monthly") : tr("Yearly") })}</p><p className="text-[0.8125rem] text-muted-foreground">{phase === 'trial' ? tr("Premium active · Trial ends {date}", { date: new Date(premium.trialEndsAt ?? 0).toLocaleDateString(getLang()) }) : tr("Premium active")}</p></div>
              <ActionRow label={tr("Manage subscription")} onClick={() => setConfirm("cancel")} />
            </>
          ) : (
            <>
              <ActionRow label={tr("View Premium plans")} onClick={() => navigate({ to: "/trial" })} />
              {/* Same store restore as the paywall; the web prototype has no store, so it reports none found. */}
              <ActionRow label={tr("Restore purchase")} onClick={() => toast({ title: tr("No subscription found"), description: tr("Use the same store account you bought with.") })} />
            </>
          )}
        </Group>

        <Group title={tr("Account")}>
          {session ? (
            <>
              <div className="px-4 py-3 text-[0.875rem] text-muted-foreground"><Hi text={tr("Signed in as [{email}]", { email: session.user.email ?? "" })} className="font-bold text-foreground" /></div>
              <ActionRow label={tr("Sign out")} onClick={() => void signOut()} />
              <ActionRow label={tr("Delete account")} danger onClick={() => setConfirm("delete")} />
            </>
          ) : (
            <ActionRow label={tr("Sign in or create an account")} onClick={() => navigate({ to: "/account", search: { mode: "signin" } })} />
          )}
        </Group>

        <Group title={tr("Help")}>
          <ActionRow label={tr("Help & support")} onClick={() => navigate({ to: "/support" })} />
        </Group>

        <div className="space-y-2 px-2 text-center text-[0.75rem] leading-relaxed text-faint">
          <p><Link to="/terms" className="underline">{tr("Terms of Service")}</Link> · <Link to="/privacy" className="underline">{tr("Privacy Policy")}</Link></p>
          <p>{tr("Videos play through YouTube and belong to their creators. Dictionary data: JMdict (EDRDG), CC BY-SA 4.0. Example sentences: Tatoeba, CC BY 2.0 FR.")}</p>
        </div>
      </div>

      <Modal open={confirm === "delete"} onClose={() => setConfirm(null)}>
        <h2 className="text-[1.25rem] font-black">{tr("Delete your account?")}</h2>
        <p className="mt-2 text-[0.9375rem] text-muted-foreground">{tr("This permanently deletes your account and cloud progress. It can't be undone.")}</p>
        <div className="mt-5 space-y-2">
          <Button variant="danger" disabled={busy} onClick={() => void deleteAccount()}>{busy ? tr("Deleting…") : tr("Delete forever")}</Button>
          <Button variant="ghost" size="md" className="w-full" onClick={() => setConfirm(null)}>{tr("Keep my account")}</Button>
        </div>
      </Modal>
      <Modal open={confirm === "cancel"} onClose={() => setConfirm(null)}>
        <h2 className="text-[1.25rem] font-black">{tr("Manage subscription")}</h2>
        <p className="mt-2 text-[0.9375rem] text-muted-foreground">{tr("In the phone app this opens your App Store or Google Play subscriptions. This preview has no store, so you can end the simulated plan here — you'll go back to {FREE_DAILY_CLIPS} free clips a day and keep your words.", { FREE_DAILY_CLIPS })}</p>
        <div className="mt-5 space-y-2">
          <Button variant="danger" onClick={() => { cancelPremium(); setConfirm(null); toast({ title: tr("Premium ended (preview)") }); }}>{tr("End simulated plan")}</Button>
          <Button variant="ghost" size="md" className="w-full" onClick={() => setConfirm(null)}>{tr("Keep Premium")}</Button>
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

/** Settings → App language: the current language, opening the picker (_LanguageRow in settings.dart). */
function LanguageRow({ onClick }: { onClick: () => void }) {
  const l = currentLanguage();
  return (
    <button onClick={onClick} className="press flex w-full items-center gap-2 px-4 py-3.5 text-left">
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="text-[0.9375rem] font-bold">{tr("App language")}</span>
        {l.code !== "en" && <LanguagePackLine lang={l.code} />}
      </span>
      <span className="text-[0.875rem] font-bold text-muted-foreground"><span className="font-emoji">{l.flag}</span>{"\u00a0\u00a0"}{l.native}</span>
      <ChevronRight className="h-[18px] w-[18px] text-faint" />
    </button>
  );
}

/** Whether the clips are fully translated on this device (_LanguagePackLine in settings.dart). */
function LanguagePackLine({ lang }: { lang: LangCode }) {
  const st = useSyncExternalStore(subscribeLocalePack, () => localePackState(lang), () => "starter" as const);
  const text = st === "ready" ? tr("Translations downloaded") : st === "downloading" ? tr("Downloading translations…") : tr("First clips translated");
  return <span className={cn("mt-0.5 text-[0.78125rem] font-semibold", st === "ready" ? "text-success" : "text-faint")}>{text}</span>;
}

function ActionRow({ label, onClick, danger }: { label: string; onClick: () => void; danger?: boolean }) {
  return <button onClick={onClick} className={cn("press block w-full px-4 py-3.5 text-left text-[0.9375rem] font-bold", danger && "text-danger")}>{label}</button>;
}
