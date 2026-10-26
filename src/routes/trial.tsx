import { createFileRoute, Link, Navigate, useNavigate } from "@tanstack/react-router";
import { motion } from "motion/react";
import { Bell, Check, Crown, Lock, Sparkles } from "lucide-react";
import { useEffect, useState, type ReactNode } from "react";

import { FeedPreview } from "@/components/mimi/FeedPreview";
import { LivelyMascot } from "@/components/mimi/Mascot";
import { Button, ProgressHeader, Screen } from "@/components/mimi/ui";
import { track } from '@/lib/analytics';
import { haptic } from "@/lib/haptics";
import { PLANS, priceLine, purchaseToast, trialBadge, trialCta, trialTimeline } from "@/lib/paywall";
import { useApp } from "@/lib/store";
import { subscriptionAccess } from '@/lib/logic';
import { toast } from "@/lib/ui-store";
import { cn } from "@/lib/utils";
import { cachedFounderEnabled, cachedReviewSignIn, cachedTrialDays, refreshOnboardingSettings } from '@/lib/onboarding-settings';

export const Route = createFileRoute("/trial")({
  head: () => ({
    meta: [
      { title: "Try Kizuki free for 7 days" },
      { name: "description", content: "Unlimited clips, tap-to-explain words and smart reviews. Free for 7 days, cancel anytime." },
      { property: "og:title", content: "Try Kizuki free for 7 days" },
      { property: "og:description", content: "Unlimited clips, tap-to-explain words and smart reviews. Free for 7 days, cancel anytime." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Trial,
});

/** The web prototype has no store account, so store eligibility never limits the trial here;
 * the server trial experiment (cached trial days, 0 = direct paywall) still applies. The
 * Android/iPhone app also reads eligibility from the store and drops trial promises when false. */
function Trial() {
  const navigate = useNavigate();
  const premium = useApp((s) => s.premium);
  const onboarded = useApp((s) => s.onboarded);
  const startTrial = useApp((s) => s.startTrial);
  const [step, setStep] = useState(() => useApp.getState().onboarded ? 2 : 0);
  const [plan, setPlan] = useState<"yearly" | "monthly">("yearly");
  const [busy, setBusy] = useState(false);
  const [days, setDays] = useState(cachedTrialDays);
  const [reviewSignIn, setReviewSignIn] = useState(false);
  useEffect(() => { setReviewSignIn(cachedReviewSignIn()); void refreshOnboardingSettings().then(() => { setDays(cachedTrialDays()); setReviewSignIn(cachedReviewSignIn()); }); }, []);
  const trial = days > 0;

  useEffect(() => track('paywall_viewed'), []);
  useEffect(() => track('paywall_step_viewed', { step_index: step }), [step]);
  const start = async () => {
    track('checkout_started', { plan, is_simulated: true });
    setBusy(true);
    await new Promise((r) => setTimeout(r, 900)); // store sheet stand-in (real billing in the Android app)
    startTrial(plan);
    track('checkout_result', { result: 'done', plan, is_simulated: true });
    // The account step is required as soon as the store confirms, even if this screen was left.
    useApp.getState().requirePurchaseAccount();
    setBusy(false);
    haptic("celebrate");
    toast({ icon: "🎉", title: purchaseToast(days), description: "Everything in Kizuki is unlocked." });
    void navigate({ to: "/account", search: { mode: "signin" }, replace: true });
  };
  const skip = () => {
    track('paywall_skipped');
    if (busy) return;
    if (useApp.getState().onboarded) window.history.back();
    else void navigate({ to: "/account" });
  };
  const back = () => {
    if (busy) return; // the store sheet is open; leaving now would lose its result
    if (step === 2 && !trial) setStep(0);
    else if (step) setStep(step - 1);
    else if (useApp.getState().onboarded) window.history.back();
    else void navigate({ to: cachedFounderEnabled() ? "/founder" : "/plan" });
  };

  if (onboarded && subscriptionAccess(premium.active, premium.expiresAt, premium.trialEndsAt, Date.now())) return <Navigate to="/feed" replace />;

  return (
    <Screen scroll={false}>
      <ProgressHeader progress={(9 + step) / 12} onBack={back} />
      <div key={step} className="flex min-h-0 flex-1 flex-col">
        {step === 0 && <StepTry days={days} onNext={() => setStep(trial ? 1 : 2)} />}
        {step === 1 && <StepRemind days={days} onNext={() => setStep(2)} />}
        {step === 2 && <StepPlans plan={plan} setPlan={(p) => { setPlan(p); track('plan_selected', { plan: p }); }} busy={busy} trialDays={days} reviewSignIn={reviewSignIn} onStart={start} onSkip={skip} />}
      </div>
    </Screen>
  );
}

/** Scrolling step content above a pinned footer: the main button, price and legal links
 * stay on screen on small phones and with large text (mirrors _pinned in trial.dart). */
function Pinned({ children, footer }: { children: ReactNode; footer: ReactNode }) {
  return (
    <>
      <div className="min-h-0 flex-1 overflow-y-auto px-6 pb-4 no-scrollbar scroll-fade">{children}</div>
      <div className="shrink-0 space-y-2 bg-background px-6 pb-2 pt-2">{footer}</div>
    </>
  );
}

function StepTry({ days, onNext }: { days: number; onNext: () => void }) {
  const onboarded = useApp((s) => s.onboarded);
  const trial = days > 0;
  return (
    <div className="flex flex-1 flex-col px-6">
      <h1 className="pt-4 text-center text-[1.625rem] font-black leading-tight">
        {trial ? (
          <>
            Try Kizuki <span className="text-primary">free</span> for {days} days
          </>
        ) : (
          <>
            Learn with Kizuki <span className="text-primary">Premium</span>
          </>
        )}
      </h1>
      <div className="relative mx-auto mt-6 w-[230px] flex-1">
        <div className="absolute inset-0 overflow-hidden rounded-[32px] border-[6px] border-surface-3 bg-stage">
          {onboarded ? <div className="flex h-full items-center justify-center px-4 text-center font-extrabold">Renew Premium to keep learning</div> : <FeedPreview />}
        </div>
        <LivelyMascot pose="cheer" size={96} tappable className="absolute -bottom-3 -right-14" />
      </div>
      <div className="space-y-3 pb-2 pt-6">
        <p className="flex items-center justify-center gap-2 text-[0.9375rem] font-extrabold">
          <Check className="h-5 w-5 text-success" strokeWidth={3} /> {trial ? "No payment due now" : "Cancel anytime"}
        </p>
        <Button onClick={onNext}>{trial ? "Try for $0.00" : "See plans"}</Button>
        <p className="text-center text-[0.8125rem] text-muted-foreground">{priceLine(PLANS.yearly, days)}</p>
      </div>
    </div>
  );
}

function StepRemind({ days, onNext }: { days: number; onNext: () => void }) {
  const items = trialTimeline(days);
  const icons = [Lock, Bell, Crown];
  return (
    <Pinned
      footer={
        <>
          <p className="flex items-center justify-center gap-2 pb-1 text-[0.9375rem] font-extrabold">
            <Check className="h-5 w-5 text-success" strokeWidth={3} /> No payment due now
          </p>
          <Button onClick={onNext}>Continue for free</Button>
        </>
      }
    >
      <h1 className="pt-4 text-center text-[1.625rem] font-black leading-tight">We'll remind you before your trial ends</h1>
      <div className="mt-7 flex justify-center">
        <motion.div className="relative" animate={{ rotate: [0, -5, 5, -3, 3, 0] }} transition={{ duration: 1.1, delay: 0.3 }}>
          <Bell className="h-[88px] w-[88px] fill-gold text-gold" strokeWidth={1.5} />
          <span className="absolute -right-1 top-1 flex h-8 w-8 items-center justify-center rounded-full bg-danger text-[0.9375rem] font-black">1</span>
        </motion.div>
      </div>
      <div className="mt-8">
        {items.map((it, i) => {
          const Icon = icons[i] ?? Bell;
          const last = i === items.length - 1;
          return (
            <div key={it.title} className="flex gap-4">
              <div className="flex flex-col items-center">
                <span className={cn("flex h-11 w-11 items-center justify-center rounded-full", i === 0 ? "bg-primary text-primary-foreground" : "bg-surface-2 text-foreground")}>
                  <Icon className="h-5 w-5" />
                </span>
                {!last && <span className="my-1 w-1 flex-1 rounded-full bg-surface-2" />}
              </div>
              <div className={last ? "" : "pb-6"}>
                <p className="text-[1rem] font-extrabold">{it.title}</p>
                <p className="text-[0.875rem] text-muted-foreground">{it.body}</p>
              </div>
            </div>
          );
        })}
      </div>
    </Pinned>
  );
}

const PERKS = [
  "Unlimited clips, every level",
  "Tap any word for an explanation in context",
  "Unlimited questions to Kizuki, your AI tutor",
  "Smart reviews with the original audio",
  "Hiragana & katakana trainer",
  "Streaks, goals and progress stats",
];

function StepPlans({
  plan,
  setPlan,
  busy,
  trialDays,
  reviewSignIn,
  onStart,
  onSkip,
}: {
  plan: "yearly" | "monthly";
  setPlan: (p: "yearly" | "monthly") => void;
  busy: boolean;
  trialDays: number;
  reviewSignIn: boolean;
  onStart: () => void;
  onSkip: () => void;
}) {
  const days = plan === "yearly" ? trialDays : 0;
  return (
    <Pinned
      footer={
        <>
          <p className="flex items-center justify-center gap-2 text-[0.875rem] font-extrabold">
            <Check className="h-4 w-4 text-success" strokeWidth={3} /> {trialBadge(days)}
          </p>
          <Button onClick={onStart} disabled={busy}>
            {busy ? "Starting…" : trialCta(days)}
          </Button>
          <p className="text-center text-[0.75rem] text-faint">
            {priceLine(PLANS[plan], days)}. Renews automatically, cancel anytime in your store settings.
          </p>
          <div className="flex flex-wrap justify-center gap-x-6">
            <button
              onClick={() => toast({ title: "No subscription found", description: "Use the same store account you bought with." })}
              disabled={busy}
              className="press min-h-10 px-2 text-[0.8125rem] font-bold text-muted-foreground disabled:opacity-50"
            >
              Restore purchase
            </button>
            <button onClick={onSkip} disabled={busy} className="press min-h-10 px-2 text-[0.8125rem] font-bold text-muted-foreground disabled:opacity-50">
              Not now
            </button>
            {/* Store reviewers finish onboarding, then sign in here; hidden unless the server switch is on. */}
            {reviewSignIn && (
              <Link to="/account" search={{ mode: "signin" }} className="press flex min-h-10 items-center px-2 text-[0.8125rem] font-bold text-muted-foreground">
                I already have an account
              </Link>
            )}
          </div>
          {/* Store rules: subscription screens link the Terms of Use and Privacy Policy. */}
          <p className="text-center text-[0.75rem] text-faint">
            <Link to="/terms" className="underline">
              Terms of Use
            </Link>{" "}
            ·{" "}
            <Link to="/privacy" className="underline">
              Privacy Policy
            </Link>
          </p>
        </>
      }
    >
      <div className="flex items-center gap-3 pt-2">
        <LivelyMascot pose="heart" size={64} />
        <h1 className="text-[1.5rem] font-black leading-tight">
          Unlock everything in <span className="text-primary">Kizuki</span>
        </h1>
      </div>
      {/* Plans come first so the price is always visible on small phones; perks scroll below. */}
      <div className="mt-5 space-y-3.5">
        {(["yearly", "monthly"] as const).map((id) => {
          const p = PLANS[id];
          const active = plan === id;
          return (
            <button
              key={id}
              onClick={() => { if (plan !== id) haptic("select"); setPlan(id); }}
              aria-pressed={active}
              className={cn("press relative flex w-full items-center gap-3 rounded-2xl border-2 bg-surface px-4 py-3.5 text-left", active ? "border-primary bg-primary/10" : "border-border")}
            >
              {p.badge && (
                <span className="absolute -top-3 right-4 rounded-full bg-primary px-2.5 py-0.5 text-[0.6875rem] font-black uppercase tracking-wider text-primary-foreground">
                  {p.badge}
                </span>
              )}
              <span className={cn("flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2", active ? "border-primary bg-primary" : "border-surface-3")}>
                {active && <Check className="h-4 w-4 text-primary-foreground" strokeWidth={3.5} />}
              </span>
              <span className="flex-1">
                <span className="block text-[1rem] font-extrabold">{p.label}</span>
                <span className="block text-[0.8125rem] text-muted-foreground">{p.sub}</span>
              </span>
              <span className="text-right">
                <span className="block text-[1rem] font-black tabular">{p.perMonth}</span>
                <span className="block text-[0.6875rem] font-bold text-muted-foreground">per month</span>
              </span>
            </button>
          );
        })}
      </div>
      <p className="mt-6 text-[0.6875rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Everything in Premium</p>
      <div className="mt-2.5 space-y-2">
        {PERKS.map((p) => (
          <p key={p} className="flex items-center gap-2.5 text-[0.9375rem] font-bold">
            <Sparkles className="h-4 w-4 shrink-0 text-gold" />
            {p}
          </p>
        ))}
      </div>
    </Pinned>
  );
}
