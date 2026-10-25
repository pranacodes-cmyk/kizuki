import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { Check } from "lucide-react";
import { useEffect, useMemo, useState, type ReactNode } from "react";

import { LivelyMascot, Pop } from "@/components/mimi/Mascot";
import { Button, Pill, ProgressHeader, Screen } from "@/components/mimi/ui";
import { challengeBenefit, goalDateLabel, levelToJlpt, recommendedMinutes, windowLabel, wordsPerMonth } from "@/lib/logic";
import { challengeOptions, levelOptions, reasonOptions, sourceOptions, streakOptions, windowOptions } from "@/lib/onboarding";
import { prefetchFounderVideo } from "@/lib/onboarding-settings";
import { track } from '@/lib/analytics';
import { haptic } from "@/lib/haptics";
import { requestReminderPermission } from "@/lib/reminders";
import { useApp } from "@/lib/store";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/onboarding")({
  head: () => ({
    meta: [
      { title: "Build your plan — Kizuki" },
      { name: "description", content: "Answer a few questions and Kizuki builds a Japanese listening plan around your goals." },
      { property: "og:title", content: "Build your plan — Kizuki" },
      { property: "og:description", content: "Answer a few questions and Kizuki builds a Japanese listening plan around your goals." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Onboarding,
});

const STEPS = ["reasons", "level", "challenges", "method", "source", "fluency", "minutes", "window", "streak"] as const;

function Onboarding() {
  const navigate = useNavigate();
  const reducedMotion = useReducedMotion();
  const profile = useApp((s) => s.profile);
  const setProfile = useApp((s) => s.setProfile);
  const [i, setI] = useState(0);
  const [dir, setDir] = useState(1);
  const step = STEPS[i] ?? 'reasons';

  useEffect(() => track('onboarding_step_viewed', { step, step_index: i }), [step, i]);
  // Warm the server-sent founder video a few screens before its slide.
  useEffect(() => prefetchFounderVideo(), []);
  const next = () => {
    track('onboarding_step_completed', { step, step_index: i });
    if (i === STEPS.length - 1) {
      void navigate({ to: "/building" });
      return;
    }
    setDir(1);
    setI(i + 1);
  };
  const back = () => {
    track('onboarding_step_back', { step });
    if (i === 0) void navigate({ to: "/" });
    else {
      setDir(-1);
      setI(i - 1);
    }
  };

  return (
    <Screen scroll={false}>
      <ProgressHeader progress={(i + 1) / STEPS.length} onBack={back} />
      <div className="relative flex-1 overflow-hidden">
        <AnimatePresence initial={false} custom={dir} mode="popLayout">
          <motion.div
            key={step}
            custom={dir}
            initial={{ x: dir * (reducedMotion ? 0 : 16), opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ x: dir * (reducedMotion ? 0 : -16), opacity: 0 }}
            transition={{ duration: reducedMotion ? 0 : 0.22, ease: [0.22, 1, 0.36, 1] }}
            className="absolute inset-0 flex min-h-0 flex-col"
          >
            {step === "reasons" && <Reasons value={profile.reasons} onChange={(reasons) => setProfile({ reasons })} onNext={next} />}
            {step === "level" && <Level value={profile.level} onPick={(level) => { setProfile({ level, jlpt: levelToJlpt(level) }); setTimeout(next, 220); }} />}
            {step === "challenges" && <Challenges value={profile.challenges} onChange={(challenges) => setProfile({ challenges })} onNext={next} />}
            {step === "method" && <Method onNext={next} />}
            {step === "source" && <Source value={profile.source} onPick={(source) => { setProfile({ source }); setTimeout(next, 220); }} />}
            {step === "fluency" && <Fluency months={profile.fluencyMonths} onChange={(fluencyMonths) => setProfile({ fluencyMonths, dailyMinutes: recommendedMinutes(fluencyMonths) })} onNext={next} />}
            {step === "minutes" && <Minutes minutes={profile.dailyMinutes} months={profile.fluencyMonths} onChange={(dailyMinutes) => setProfile({ dailyMinutes })} onNext={next} />}
            {step === "window" && <Window value={profile.window} minutes={profile.dailyMinutes} onChange={(window) => setProfile({ window })} onNext={async () => { await requestReminderPermission(); next(); }} />}
            {step === "streak" && <Streak value={profile.streakGoal} onChange={(streakGoal) => setProfile({ streakGoal })} onNext={next} />}
          </motion.div>
        </AnimatePresence>
      </div>
    </Screen>
  );
}

function Title({ title, subtitle, children }: { title: string; subtitle?: string; children?: ReactNode }) {
  return (
    <div className="px-6 pt-4">
      <h1 className="text-[1.625rem] font-black leading-tight">{title}</h1>
      {subtitle && <p className="mt-2 text-[0.9375rem] text-muted-foreground">{subtitle}</p>}
      {children}
    </div>
  );
}

/** Step content that scrolls above the pinned Footer, so the main button is always on
 * screen on small phones and with large text (mirrors _stepBody in onboarding.dart). */
function StepBody({ children }: { children: ReactNode }) {
  return <div className="min-h-0 flex-1 overflow-y-auto pb-4 no-scrollbar scroll-fade">{children}</div>;
}

function Footer({ children }: { children: ReactNode }) {
  return <div className="mt-auto shrink-0 space-y-3 bg-background px-6 pb-2 pt-3">{children}</div>;
}

function GridCard({ active, emoji, label, onClick }: { active: boolean; emoji: string; label: string; onClick: () => void }) {
  return (
    <button
      onClick={() => { haptic("select"); onClick(); }}
      aria-pressed={active}
      className={cn(
        "press relative flex h-[104px] flex-col items-center justify-center gap-2 rounded-2xl border-2 bg-surface px-2 text-center transition-colors duration-150",
        active ? "border-primary bg-primary/10" : "border-border",
      )}
    >
      {/* The check badge springs in (and shrinks away) instead of blinking (onboarding.dart _GridCard). */}
      <motion.span
        aria-hidden
        initial={false}
        animate={{ scale: active ? 1 : 0 }}
        transition={{ duration: 0.26, ease: active ? [0.34, 1.56, 0.64, 1] : [0.32, 0, 0.67, 0] }}
        className="absolute right-2 top-2 flex h-5 w-5 items-center justify-center rounded-full bg-primary"
      >
        <Check className="h-3.5 w-3.5 text-primary-foreground" strokeWidth={3.5} />
      </motion.span>
      <Pop active={active} className="text-[2rem] leading-none">{emoji}</Pop>
      <span className="text-[0.9375rem] font-extrabold">{label}</span>
    </button>
  );
}

function ListOption({ active, left, label, hint, onClick }: { active: boolean; left: ReactNode; label: string; hint?: string; onClick: () => void }) {
  return (
    <button
      onClick={() => { haptic("select"); onClick(); }}
      aria-pressed={active}
      className={cn("press flex w-full items-center gap-4 rounded-2xl border-2 bg-surface px-4 py-3.5 text-left transition-colors duration-150", active ? "border-primary bg-primary/10" : "border-border")}
    >
      <span className="flex h-10 w-10 shrink-0 items-center justify-center text-[1.6rem]"><Pop active={active}>{left}</Pop></span>
      <span className="min-w-0 flex-1">
        <span className="block text-[1rem] font-extrabold">{label}</span>
        {hint && <span className="block text-[0.8125rem] text-muted-foreground">{hint}</span>}
      </span>
    </button>
  );
}

const toggle = (list: string[], id: string) => (list.includes(id) ? list.filter((x) => x !== id) : [...list, id]);

function Reasons({ value, onChange, onNext }: { value: string[]; onChange: (v: string[]) => void; onNext: () => void }) {
  return (
    <>
      <Title title="Why do you want to learn Japanese?" subtitle="Pick all that apply — we'll find clips you'll love." />
      <div className="mt-5 grid min-h-0 flex-1 auto-rows-[104px] grid-cols-2 content-start gap-3 overflow-y-auto px-6 pb-6 no-scrollbar">
        {reasonOptions.map((o) => <GridCard key={o.id} active={value.includes(o.id)} emoji={o.emoji} label={o.label} onClick={() => onChange(toggle(value, o.id))} />)}
      </div>
      <Footer><Button disabled={!value.length} onClick={onNext}>Continue</Button></Footer>
    </>
  );
}

function Level({ value, onPick }: { value: number; onPick: (v: number) => void }) {
  const [picked, setPicked] = useState<number | null>(null);
  return (
    <>
      <Title title="How much Japanese do you know?" subtitle="We'll match clips to your level.">
        <Pill className="mt-3">You can change this anytime in settings</Pill>
      </Title>
      <div className="mt-5 space-y-3 overflow-y-auto px-6 no-scrollbar">
        {levelOptions.map((o, idx) => (
          <ListOption
            key={o.label}
            active={(picked ?? value) === idx && picked !== null}
            left={<Bars n={idx + 1} />}
            label={o.label}
            hint={o.hint}
            onClick={() => { setPicked(idx); onPick(idx); }}
          />
        ))}
      </div>
    </>
  );
}

function Bars({ n }: { n: number }) {
  return (
    <span className="flex h-6 items-end gap-[3px]" aria-hidden>
      {[1, 2, 3, 4, 5].map((b) => <span key={b} className={cn("w-[5px] rounded-sm", b <= n ? "bg-primary" : "bg-surface-3")} style={{ height: `${b * 20}%` }} />)}
    </span>
  );
}

function Challenges({ value, onChange, onNext }: { value: string[]; onChange: (v: string[]) => void; onNext: () => void }) {
  const last = value[value.length - 1];
  return (
    <>
      <Title title="What's hardest for you right now?" subtitle="Select all that apply." />
      <div className="mt-5 grid min-h-0 flex-1 auto-rows-[104px] grid-cols-2 content-start gap-3 overflow-y-auto px-6 pb-6 no-scrollbar">
        {challengeOptions.map((o) => <GridCard key={o.id} active={value.includes(o.id)} emoji={o.emoji} label={o.label} onClick={() => onChange(toggle(value, o.id))} />)}
      </div>
      <Footer>
        <div className="min-h-[44px]">
          <AnimatePresence mode="wait">
            {last && (
              <motion.div key={last} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -8 }} className="flex items-start gap-2 text-[0.875rem] font-bold text-success">
                <Check className="mt-0.5 h-4 w-4 shrink-0" strokeWidth={3} /> {challengeBenefit(last)}
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        <Button disabled={!value.length} onClick={onNext}>Continue</Button>
      </Footer>
    </>
  );
}

function Method({ onNext }: { onNext: () => void }) {
  return (
    <>
      <StepBody>
      <Title title="Learn the way you learned your first language" subtitle="By listening to real people — not by memorising rules." />
      <div className="mx-6 mt-6 rounded-3xl bg-surface p-5">
        <p className="text-[0.8125rem] font-black uppercase tracking-[0.12em] text-muted-foreground">Real Japanese you hear in 10 minutes</p>
        <div className="mt-5 flex h-[230px] items-end justify-center gap-8">
          <div className="flex flex-col items-center gap-2">
            <span className="text-[0.875rem] font-extrabold text-muted-foreground">~10 lines</span>
            <motion.div initial={{ height: 0 }} animate={{ height: 36 }} transition={{ delay: 0.2, duration: 0.6 }} className="w-20 rounded-t-xl bg-surface-3" />
            <span className="text-[0.8125rem] font-bold text-muted-foreground">Drill apps</span>
          </div>
          <div className="flex flex-col items-center gap-1">
            <span className="text-[0.875rem] font-extrabold text-primary">100+ lines</span>
            {/* Rides up with the growing bar, then hops as it lands. */}
            <LivelyMascot pose="cheer" size={48} hopAfter={1200} />
            <motion.div initial={{ height: 0 }} animate={{ height: 130 }} transition={{ delay: 0.35, duration: 0.8, ease: [0.22, 1, 0.36, 1] }} className="w-20 rounded-t-xl bg-primary" />
            <span className="mt-1 text-[0.8125rem] font-bold text-foreground">With Kizuki</span>
          </div>
        </div>
      </div>
      <div className="mx-6 mt-4 space-y-2.5">
        {["Hear real native speed from day one", "Every word explained in its sentence", "Remember words with the original audio"].map((t) => (
          <p key={t} className="flex items-center gap-2 text-[0.9375rem] font-bold"><Check className="h-4 w-4 text-success" strokeWidth={3} />{t}</p>
        ))}
      </div>
      </StepBody>
      <Footer><Button onClick={onNext}>Continue</Button></Footer>
    </>
  );
}

function Source({ onPick }: { value: string; onPick: (v: string) => void }) {
  const [picked, setPicked] = useState<string | null>(null);
  return (
    <>
      <Title title="Where did you hear about Kizuki?" subtitle="Helps us reach more learners like you." />
      <div className="mt-5 space-y-2.5 overflow-y-auto px-6 pb-4 no-scrollbar">
        {sourceOptions.map((o) => (
          <ListOption key={o.id} active={picked === o.id} left={o.emoji} label={o.label} onClick={() => { setPicked(o.id); onPick(o.id); }} />
        ))}
      </div>
    </>
  );
}

function Ring({ value, max, color, children }: { value: number; max: number; color: string; children: ReactNode }) {
  const r = 78, c = 2 * Math.PI * r;
  return (
    <div className="relative mx-auto h-[190px] w-[190px]">
      <svg viewBox="0 0 190 190" className="h-full w-full -rotate-90">
        <circle cx="95" cy="95" r={r} fill="none" strokeWidth="14" className="stroke-surface-2" />
        <motion.circle cx="95" cy="95" r={r} fill="none" strokeWidth="14" strokeLinecap="round" className={color} strokeDasharray={c} initial={false} animate={{ strokeDashoffset: c * (1 - value / max) }} transition={{ type: "spring", stiffness: 120, damping: 20 }} />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">{children}</div>
    </div>
  );
}

function Slider({ value, min, max, step, onChange, tone }: { value: number; min: number; max: number; step: number; onChange: (v: number) => void; tone: "success" | "primary" }) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <input
      type="range"
      min={min}
      max={max}
      step={step}
      value={value}
      onChange={(e) => {
        const v = Number(e.target.value);
        if (v !== value) haptic("tick"); // a soft tick per step, like a picker wheel
        onChange(v);
      }}
      className={cn(
        "h-3 w-full cursor-pointer appearance-none rounded-full",
        "[&::-webkit-slider-thumb]:h-8 [&::-webkit-slider-thumb]:w-8 [&::-webkit-slider-thumb]:appearance-none [&::-webkit-slider-thumb]:rounded-full [&::-webkit-slider-thumb]:border-4 [&::-webkit-slider-thumb]:border-foreground [&::-webkit-slider-thumb]:shadow-lg",
        tone === "success" ? "[&::-webkit-slider-thumb]:bg-success" : "[&::-webkit-slider-thumb]:bg-primary",
      )}
      style={{ background: `linear-gradient(90deg, var(--${tone}) ${pct}%, var(--surface-2) ${pct}%)` }}
    />
  );
}

function Fluency({ months, onChange, onNext }: { months: number; onChange: (v: number) => void; onNext: () => void }) {
  const date = useMemo(() => goalDateLabel(new Date(), months), [months]);
  return (
    <>
      <StepBody>
      <Title title="When do you want to understand Japanese?" subtitle="Set a goal. We'll keep it realistic." />
      <div className="mt-4 flex justify-center"><Pill tone="success">🇯🇵 Conversational by {date}</Pill></div>
      <div className="mt-6"><Ring value={months} max={36} color="stroke-success"><span className="text-[3.25rem] font-black leading-none tabular">{months}</span><span className="text-[1rem] font-bold text-muted-foreground">months</span></Ring></div>
      <div className="mt-8 px-8"><Slider value={months} min={3} max={36} step={1} onChange={onChange} tone="success" /></div>
      <div className="mt-2 flex justify-between px-8 text-[0.75rem] font-bold text-faint"><span>3 months</span><span>3 years</span></div>
      </StepBody>
      <Footer><Button onClick={onNext}>Continue</Button></Footer>
    </>
  );
}

function Minutes({ minutes, months, onChange, onNext }: { minutes: number; months: number; onChange: (v: number) => void; onNext: () => void }) {
  const rec = recommendedMinutes(months);
  return (
    <>
      <StepBody>
      <Title title="How much time can you give each day?" subtitle="Consistency beats intensity. Even 5 minutes works." />
      <div className="mt-4 flex justify-center"><Pill tone="primary">🧠 About {wordsPerMonth(minutes)} new words a month</Pill></div>
      <div className="mt-6"><Ring value={minutes} max={60} color="stroke-primary"><span className="text-[3.25rem] font-black leading-none tabular">{minutes}</span><span className="text-[1rem] font-bold text-muted-foreground">minutes</span></Ring></div>
      <div className="mt-8 px-8"><Slider value={minutes} min={5} max={60} step={5} onChange={onChange} tone="primary" /></div>
      <div className="mt-4 flex justify-center px-6 text-center">
        {minutes >= rec ? <Pill tone="success">✓ Enough to reach your {months}-month goal</Pill> : <Pill>{rec} min/day recommended for {months} months</Pill>}
      </div>
      </StepBody>
      <Footer><Button onClick={onNext}>I'm committed</Button></Footer>
    </>
  );
}

function Window({ value, minutes, onChange, onNext }: { value: string; minutes: number; onChange: (v: string) => void; onNext: () => void }) {
  const [picked, setPicked] = useState(false);
  return (
    <>
      <StepBody>
        <Title title={`When can you spend ${minutes} minutes?`} subtitle="We'll send one friendly reminder so you never break your streak." />
        <div className="mt-5 space-y-3 px-6">
          {windowOptions.map((o) => <ListOption key={o.id} active={picked && value === o.id} left={o.emoji} label={o.label} hint={o.hint} onClick={() => { setPicked(true); onChange(o.id); }} />)}
        </div>
      </StepBody>
      <Footer>
        <p className="text-center text-[0.8125rem] text-muted-foreground">Learners with reminders on are far more likely to keep their streak.</p>
        <Button disabled={!picked} onClick={onNext}>{picked ? `Remind me ${windowLabel(value)}` : "Pick a time"}</Button>
      </Footer>
    </>
  );
}

function Streak({ value, onChange, onNext }: { value: number; onChange: (v: number) => void; onNext: () => void }) {
  return (
    <>
      <StepBody>
        <div className="flex justify-center pt-2"><LivelyMascot pose="brave" size={112} entrance hopKey={value} tappable /></div>
        <Title title="Make a promise to yourself" subtitle="Pick a streak goal. Kizuki will cheer you on." />
        <div className="mt-5 space-y-3 px-6">
          {streakOptions.map((o) => (
            <ListOption key={o.days} active={value === o.days} left={o.emoji} label={`${o.days}-day streak`} hint={o.label} onClick={() => onChange(o.days)} />
          ))}
        </div>
      </StepBody>
      <Footer><Button onClick={onNext}>Commit to {value} days</Button></Footer>
    </>
  );
}

