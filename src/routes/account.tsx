import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Eye, EyeOff, MailCheck } from "lucide-react";
import { useState, type FormEvent } from "react";
import { z } from "zod";
import "@lovable.dev/cloud-auth-js/styles.css";

import { Mascot } from "@/components/mimi/Mascot";
import { Button, Screen, TopBar } from "@/components/mimi/ui";
import { supabase } from "@/integrations/supabase/client";
import { lovable } from "@/integrations/lovable/index";
import { setSession, syncNow } from "@/lib/sync";
import { useApp } from "@/lib/store";
import { toast } from "@/lib/ui-store";

const searchSchema = z.object({ mode: z.enum(["signup", "signin"]).optional() });

export const Route = createFileRoute("/account")({
  validateSearch: (s) => searchSchema.parse(s),
  head: () => ({
    meta: [
      { title: "Save your progress — Kizuki" },
      { name: "description", content: "Create a free Kizuki account to keep your words, streak and reviews on every device." },
      { property: "og:title", content: "Save your progress — Kizuki" },
      { property: "og:description", content: "Create a free Kizuki account to keep your words, streak and reviews on every device." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Account,
});

const emailSchema = z.string().trim().email("Enter a valid email").max(255);
const passwordSchema = z.string().min(8, "Use at least 8 characters").max(72);

function Account() {
  const navigate = useNavigate();
  const { mode: initialMode } = Route.useSearch();
  const [mode, setMode] = useState<"signup" | "signin">(initialMode ?? "signup");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState<null | "confirm" | "reset">(null);
  const onboarded = useApp((s) => s.onboarded);
  const completeOnboarding = useApp((s) => s.completeOnboarding);
  const fromWelcome = initialMode === "signin" && !onboarded;

  const finish = async () => {
    await syncNow();
    const s = useApp.getState();
    if (fromWelcome && !s.onboarded) {
      // Signed in on a fresh device without cloud progress → still needs a plan.
      void navigate({ to: "/onboarding", replace: true });
      return;
    }
    if (!s.onboarded) completeOnboarding();
    void navigate({ to: "/feed", replace: true });
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    const em = emailSchema.safeParse(email);
    if (!em.success) return setError(em.error.issues[0]?.message ?? "Enter a valid email");
    const pw = passwordSchema.safeParse(password);
    if (!pw.success) return setError(pw.error.issues[0]?.message ?? "Use at least 8 characters");
    setBusy(true);
    try {
      if (mode === "signup") {
        const { data, error } = await supabase.auth.signUp({
          email: em.data,
          password: pw.data,
          options: { emailRedirectTo: window.location.origin, data: { name: useApp.getState().profile.name || undefined } },
        });
        if (error) throw error;
        if (!data.session) { setSent("confirm"); return; }
        setSession(data.session);
      } else {
        const { data, error } = await supabase.auth.signInWithPassword({ email: em.data, password: pw.data });
        if (error) throw error;
        setSession(data.session);
        toast({ icon: "👋", title: "Welcome back!" });
      }
      await finish();
    } catch (err) {
      setError(friendly(err));
    } finally {
      setBusy(false);
    }
  };

  const oauth = async (provider: "google" | "lovable") => {
    setError(null);
    const result = await lovable.auth.signInWithOAuth(provider, { redirect_uri: window.location.origin });
    if (result.error) { setError(friendly(result.error)); return; }
    if (result.redirected) return;
    const { data } = await supabase.auth.getSession();
    setSession(data.session);
    await finish();
  };

  const forgot = async () => {
    const em = emailSchema.safeParse(email);
    if (!em.success) return setError("Enter your email first, then tap “Forgot password”.");
    setBusy(true);
    const { error } = await supabase.auth.resetPasswordForEmail(em.data, { redirectTo: `${window.location.origin}/reset-password` });
    setBusy(false);
    if (error) setError(friendly(error));
    else setSent("reset");
  };

  const later = () => {
    if (fromWelcome) { void navigate({ to: "/" }); return; }
    completeOnboarding();
    void navigate({ to: "/feed", replace: true });
  };

  if (sent) {
    return (
      <Screen className="items-center px-6 text-center">
        <div className="flex flex-1 flex-col items-center justify-center">
          <MailCheck className="h-16 w-16 text-primary" />
          <h1 className="mt-5 text-[1.5rem] font-black">Check your inbox</h1>
          <p className="mt-2 max-w-[300px] text-[0.9375rem] text-muted-foreground">
            {sent === "confirm" ? <>We sent a confirmation link to <b className="text-foreground">{email}</b>. Open it to finish creating your account — your progress is saved on this phone meanwhile.</> : <>We sent a password reset link to <b className="text-foreground">{email}</b>.</>}
          </p>
        </div>
        <div className="w-full space-y-3 pb-2">
          {sent === "confirm" ? <Button onClick={later}>Continue to Kizuki</Button> : <Button onClick={() => { setSent(null); setMode("signin"); }}>Back to sign in</Button>}
        </div>
      </Screen>
    );
  }

  return (
    <Screen>
      <TopBar onBack={() => (fromWelcome ? navigate({ to: "/" }) : navigate({ to: "/trial" }))} />
      <div className="flex flex-col items-center px-6 text-center">
        <Mascot pose={mode === "signup" ? "heart" : "wave"} className="h-24 w-24" />
        <h1 className="mt-2 text-[1.5rem] font-black leading-tight">{mode === "signup" ? "Save your progress" : "Welcome back"}</h1>
        <p className="mt-1.5 text-[0.9375rem] text-muted-foreground">{mode === "signup" ? "Keep your words, streak and reviews safe on every device." : "Sign in to pick up where you left off."}</p>
      </div>

      <div className="mt-6 space-y-3 px-6">
        <button type="button" className="lovable-auth-button w-full" onClick={() => void oauth("lovable")}>Continue with Lovable</button>
        <Button variant="surface" onClick={() => void oauth("google")}>
          <GoogleMark /> Continue with Google
        </Button>
      </div>

      <div className="my-5 flex items-center gap-3 px-6 text-[0.8125rem] font-bold text-faint"><span className="h-px flex-1 bg-border" />or with email<span className="h-px flex-1 bg-border" /></div>

      <form onSubmit={submit} className="space-y-3 px-6" noValidate>
        <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" autoComplete="email" aria-label="Email" className="h-14 w-full rounded-2xl border-2 border-border bg-surface px-4 text-[1rem] font-bold outline-none placeholder:text-faint focus:border-primary" />
        <div className="relative">
          <input type={show ? "text" : "password"} value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Password" autoComplete={mode === "signup" ? "new-password" : "current-password"} aria-label="Password" className="h-14 w-full rounded-2xl border-2 border-border bg-surface px-4 pr-12 text-[1rem] font-bold outline-none placeholder:text-faint focus:border-primary" />
          <button type="button" aria-label={show ? "Hide password" : "Show password"} onClick={() => setShow(!show)} className="absolute right-3 top-1/2 -translate-y-1/2 p-1 text-muted-foreground">{show ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}</button>
        </div>
        {error && <p role="alert" className="rounded-xl bg-danger-soft px-3 py-2 text-[0.875rem] font-bold text-danger">{error}</p>}
        <Button type="submit" disabled={busy}>{busy ? "One moment…" : mode === "signup" ? "Create account" : "Sign in"}</Button>
        {mode === "signin" && <button type="button" onClick={() => void forgot()} className="press mx-auto block text-[0.875rem] font-bold text-muted-foreground">Forgot password?</button>}
      </form>

      <div className="mt-auto space-y-1 px-6 pt-6 text-center">
        <button onClick={() => { setMode(mode === "signup" ? "signin" : "signup"); setError(null); }} className="press text-[0.9375rem] font-bold text-muted-foreground">
          {mode === "signup" ? <>Already have an account? <span className="text-primary">Sign in</span></> : <>New here? <span className="text-primary">Create an account</span></>}
        </button>
        <button onClick={later} className="press block w-full py-2 text-[0.875rem] font-bold text-faint">{fromWelcome ? "Back" : "Maybe later"}</button>
      </div>
    </Screen>
  );
}

function friendly(err: unknown) {
  const msg = err instanceof Error ? err.message : typeof err === "object" && err && "message" in err ? String((err as { message: unknown }).message) : String(err);
  if (/invalid login/i.test(msg)) return "That email and password don't match.";
  if (/already registered|already exists/i.test(msg)) return "That email already has an account — try signing in.";
  if (/email not confirmed/i.test(msg)) return "Please confirm your email first — check your inbox.";
  if (/pwned|leaked|weak/i.test(msg)) return "That password is too common. Please pick another.";
  return msg || "Something went wrong. Please try again.";
}

function GoogleMark() {
  return (
    <svg viewBox="0 0 48 48" className="h-5 w-5" aria-hidden>
      <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z" />
      <path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" />
      <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z" />
      <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z" />
    </svg>
  );
}
