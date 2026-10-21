import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AnimatePresence, motion } from "motion/react";
import { Bell, Check, Crown, Lock, Sparkles } from "lucide-react";
import { useState } from "react";

import { Mascot } from "@/components/mimi/Mascot";
import { Button, ProgressHeader, Screen } from "@/components/mimi/ui";
import { PLANS, priceLine, trialTimeline } from "@/lib/paywall";
import { useApp } from "@/lib/store";
import { toast } from "@/lib/ui-store";
import { cn } from "@/lib/utils";

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

function Trial() {
  const navigate = useNavigate();
  const startTrial = useApp((s) => s.startTrial);
  const [step, setStep] = useState(0);
  const [plan, setPlan] = useState<"yearly" | "monthly">("yearly");
  const [busy, setBusy] = useState(false);

  const start = async () => {
    setBusy(true);
    await new Promise((r) => setTimeout(r, 900)); // store sheet stand-in (real billing in the Android app)
    startTrial(plan);
    setBusy(false);
    toast({ icon: "🎉", title: "Your free week has started", description: "Everything in Kizuki is unlocked." });
    void navigate({ to: useApp.getState().onboarded ? "/feed" : "/account" });
  };
  const skip = () => (useApp.getState().onboarded ? window.history.back() : void navigate({ to: "/account" }));

  return (
    <Screen scroll={false}>
      <ProgressHeader progress={(10 + step) / 13} onBack={() => (step ? setStep(step - 1) : useApp.getState().onboarded ? window.history.back() : navigate({ to: "/founder" }))} />
      <AnimatePresence mode="wait">
        <motion.div key={step} initial={{ opacity: 0, x: 40 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -40 }} transition={{ duration: 0.25 }} className="flex flex-1 flex-col overflow-y-auto no-scrollbar">
          {step === 0 && <StepTry onNext={() => setStep(1)} />}
          {step === 1 && <StepRemind onNext={() => setStep(2)} />}
          {step === 2 && <StepPlans plan={plan} setPlan={setPlan} busy={busy} onStart={start} onSkip={skip} />}
        </motion.div>
      </AnimatePresence>
    </Screen>
  );
}

function StepTry({ onNext }: { onNext: () => void }) {
  return (
    <div className="flex flex-1 flex-col px-6">
      <h1 className="pt-4 text-center text-[1.625rem] font-black leading-tight">Try Kizuki <span className="text-primary">free</span> for 7 days</h1>
      <div className="relative mx-auto mt-6 w-[230px] flex-1">
        <div className="absolute inset-0 overflow-hidden rounded-[32px] border-[6px] border-surface-3 bg-stage">
          <div className="h-[44%] bg-[linear-gradient(160deg,var(--primary-dim),var(--surface-2))]" />
          <div className="space-y-2 p-3">
            <p className="font-jp text-[1rem] font-bold leading-tight"><span className="rounded bg-primary/25 px-0.5 text-primary">今日</span>は<span className="underline decoration-learning decoration-2 underline-offset-4">楽しかった</span>ね！</p>
            <p className="text-[0.75rem] text-muted-foreground">Today was fun, wasn't it!</p>
            <div className="mt-3 rounded-2xl bg-surface p-3">
              <p className="font-jp text-[1.25rem] font-black">今日 <span className="text-[0.75rem] font-bold text-muted-foreground">きょう</span></p>
              <p className="text-[0.8125rem] font-bold">today</p>
              <p className="mt-1 text-[0.6875rem] text-muted-foreground">Said at the end of a happy day out with friends.</p>
            </div>
          </div>
        </div>
        <Mascot pose="cheer" className="absolute -bottom-3 -right-14 h-24 w-24" />
      </div>
      <div className="space-y-3 pb-2 pt-6">
        <p className="flex items-center justify-center gap-2 text-[0.9375rem] font-extrabold"><Check className="h-5 w-5 text-success" strokeWidth={3} /> No payment due now</p>
        <Button onClick={onNext}>Try for $0.00</Button>
        <p className="text-center text-[0.8125rem] text-muted-foreground">{priceLine(PLANS.yearly)}</p>
      </div>
    </div>
  );
}

function StepRemind({ onNext }: { onNext: () => void }) {
  const items = trialTimeline();
  const icons = [Lock, Bell, Crown];
  return (
    <div className="flex flex-1 flex-col px-6">
      <h1 className="pt-4 text-center text-[1.625rem] font-black leading-tight">We'll remind you before your trial ends</h1>
      <div className="mt-8 flex justify-center">
        <motion.div className="relative" animate={{ rotate: [0, -12, 12, -8, 8, 0] }} transition={{ duration: 1.1, delay: 0.3 }}>
          <Bell className="h-24 w-24 fill-gold text-gold" strokeWidth={1.5} />
          <span className="absolute -right-1 top-1 flex h-8 w-8 items-center justify-center rounded-full bg-danger text-[0.9375rem] font-black">1</span>
        </motion.div>
      </div>
      <div className="mt-10 space-y-0">
        {items.map((it, i) => {
          const Icon = icons[i] ?? Bell;
          return (
            <div key={it.title} className="flex gap-4">
              <div className="flex flex-col items-center">
                <span className={cn("flex h-11 w-11 items-center justify-center rounded-full", i === 0 ? "bg-primary text-primary-foreground" : "bg-surface-2 text-foreground")}><Icon className="h-5 w-5" /></span>
                {i < items.length - 1 && <span className="my-1 w-1 flex-1 rounded-full bg-surface-2" />}
              </div>
              <div className="pb-6">
                <p className="text-[1rem] font-extrabold">{it.title}</p>
                <p className="text-[0.875rem] text-muted-foreground">{it.body}</p>
              </div>
            </div>
          );
        })}
      </div>
      <div className="mt-auto space-y-3 pb-2 pt-4">
        <p className="flex items-center justify-center gap-2 text-[0.9375rem] font-extrabold"><Check className="h-5 w-5 text-success" strokeWidth={3} /> No payment due now</p>
        <Button onClick={onNext}>Continue for free</Button>
      </div>
    </div>
  );
}

function StepPlans({ plan, setPlan, busy, onStart, onSkip }: { plan: "yearly" | "monthly"; setPlan: (p: "yearly" | "monthly") => void; busy: boolean; onStart: () => void; onSkip: () => void }) {
  const perks = ["Unlimited clips, every level", "Tap any word for an explanation in context", "Smart reviews with the original audio", "Hiragana & katakana trainer", "Streaks, goals and progress stats"];
  return (
    <div className="flex flex-1 flex-col px-6">
      <div className="flex items-center gap-3 pt-2">
        <Mascot pose="heart" className="h-16 w-16" />
        <h1 className="text-[1.5rem] font-black leading-tight">Unlock everything in <span className="text-primary">Kizuki</span></h1>
      </div>
      <div className="mt-4 space-y-2">
        {perks.map((p) => <p key={p} className="flex items-center gap-2.5 text-[0.9375rem] font-bold"><Sparkles className="h-4 w-4 shrink-0 text-gold" />{p}</p>)}
      </div>
      <div className="mt-5 space-y-3">
        {(["yearly", "monthly"] as const).map((id) => {
          const p = PLANS[id];
          const active = plan === id;
          return (
            <button key={id} onClick={() => setPlan(id)} aria-pressed={active} className={cn("press relative flex w-full items-center gap-3 rounded-2xl border-2 bg-surface px-4 py-3.5 text-left", active ? "border-primary bg-primary/10" : "border-border")}>
              {p.badge && <span className="absolute -top-3 right-4 rounded-full bg-primary px-2.5 py-0.5 text-[0.6875rem] font-black uppercase tracking-wider text-primary-foreground">{p.badge}</span>}
              <span className={cn("flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2", active ? "border-primary bg-primary" : "border-surface-3")}>{active && <Check className="h-4 w-4 text-primary-foreground" strokeWidth={3.5} />}</span>
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
      <div className="mt-auto space-y-2 pb-1 pt-5">
        <p className="flex items-center justify-center gap-2 text-[0.875rem] font-extrabold"><Check className="h-4 w-4 text-success" strokeWidth={3} /> 7 days free · Cancel anytime</p>
        <Button onClick={onStart} disabled={busy}>{busy ? "Starting…" : "Start my free week"}</Button>
        <p className="text-center text-[0.75rem] text-faint">{priceLine(PLANS[plan])}. Purchases are simulated in this preview.</p>
        <button onClick={onSkip} className="press mx-auto block py-1 text-[0.8125rem] font-bold text-muted-foreground">Not now</button>
      </div>
    </div>
  );
}
