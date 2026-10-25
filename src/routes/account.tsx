import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { ChevronRight, ShieldCheck } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { z } from "zod";

import { useSession } from "@/hooks/use-session";
import { Mascot } from "@/components/mimi/Mascot";
import { Button, Screen, TopBar } from "@/components/mimi/ui";
import { supabase } from "@/lib/backend";
import { syncNow } from "@/lib/sync";
import { track } from '@/lib/analytics';
import { toast } from "@/lib/ui-store";
import { useApp } from "@/lib/store";
import { signInProviders } from '@/lib/logic';
import { ProviderIcon } from '@/components/mimi/ProviderIcon';

const searchSchema = z.object({
  mode: z.enum(["signup", "signin"]).optional(),
  platform: z.enum(['android', 'ios']).optional(),
  // Bridge mode: opened by the Android/iOS app in the system browser. Sign-in
  // completes here and the session is handed back via the kizuki:// deep link.
  // TanStack's search serializer can hand this over as a number or boolean.
  bridge: z.union([z.string(), z.number(), z.boolean()]).optional(),
  provider: z.enum(["google", "apple", "lovable"]).optional(),
});

export const Route = createFileRoute("/account")({
  validateSearch: (s) => searchSchema.parse(s),
  head: () => ({
    meta: [
      { title: "Save your progress — Kizuki" },
      { name: "description", content: "Sign in to Kizuki with Google or Apple to keep your words, streak and reviews on every device." },
      { property: "og:title", content: "Save your progress — Kizuki" },
      { property: "og:description", content: "Sign in to Kizuki with Google or Apple to keep your words, streak and reviews on every device." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: Account,
});

type Provider = "google" | "apple" | "lovable";

function Account() {
  const navigate = useNavigate();
  const { mode: initialMode, bridge, provider, platform } = Route.useSearch();
  const [device, setDevice] = useState('ios');
  useEffect(() => { setDevice(platform ?? (/android/i.test(navigator.userAgent) ? 'android' : 'ios')); }, [platform]);
  // TanStack search params can arrive as number/boolean (its own serializer),
  // so compare across types.
  const isBridge = bridge === true || bridge === "true" || String(bridge) === "1";
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [handed, setHanded] = useState(false);
  const onboarded = useApp((s) => s.onboarded);
  const completeOnboarding = useApp((s) => s.completeOnboarding);
  const requiredAccount = useApp((s) => s.purchaseAccountPending);
  const session = useSession();
  const finishing = useRef(false);
  const autoStarted = useRef(false);
  const fromWelcome = initialMode === "signin" && !requiredAccount && !onboarded;

  /// Session payload handed to the phone app. Built once: right after building it this
  /// page drops its own copy of the session, so the phone's refresh is the only one (a
  /// second refresh of the same token would make the backend revoke the phone's session).
  const handoffUrl = useRef<string | null>(null);
  const handoff = async () => {
    if (!handoffUrl.current) {
      const { data } = await supabase.auth.getSession();
      const s = data.session;
      if (!s) { setError("Sign-in didn't finish. Please try again."); return false; }
      const camel = (o: Record<string, unknown>) =>
        Object.fromEntries(Object.entries(o).map(([k, v]) => [k.replace(/_([a-z])/g, (_, c) => c.toUpperCase()), v]));
      const payload = encodeURIComponent(JSON.stringify({
        accessToken: s.access_token,
        refreshToken: s.refresh_token,
        tokenType: s.token_type,
        expiresIn: s.expires_in,
        expiresAt: s.expires_at,
        user: camel(s.user as unknown as Record<string, unknown>),
      }));
      const returnTo = encodeURIComponent(`${window.location.origin}/account?bridge=1&done=1`);
      // Chrome on Android launches the app directly with an intent; other platforms
      // use the plain custom scheme.
      handoffUrl.current = /android/i.test(navigator.userAgent)
        ? `intent://auth?session=${payload}#Intent;scheme=kizuki;package=com.kizukijapan.app;S.browser_fallback_url=${returnTo};end`
        : `kizuki://auth?session=${payload}`;
      dropBrowserSession();
    }
    window.location.href = handoffUrl.current;
    setHanded(true);
    return true;
  };

  const finish = async () => {
    const { data, error } = await supabase.auth.getUser();
    if (error || !data.user) { setError("Please sign in to continue."); return; }
    if (isBridge) { await handoff(); return; }
    await syncNow();
    const s = useApp.getState();
    // Confirm out loud: silent redirects left users unsure the sign-in worked.
    if (requiredAccount) {
      toast({ icon: "🎉", title: "You're all set", description: "Your progress is now saved to your account." });
    } else {
      const created = Date.parse(data.user.created_at);
      const isNew = Number.isFinite(created) && Date.now() - created < 2 * 60 * 1000;
      toast({ icon: isNew ? "🎉" : "👋", title: isNew ? "Account created" : "Welcome back", description: isNew ? "Let's set up your learning plan." : "Your progress is synced on this device." });
    }
    if (fromWelcome && !s.onboarded) {
      // Signed in on a fresh device without cloud progress → still needs a plan.
      void navigate({ to: "/onboarding", replace: true });
      return;
    }
    s.confirmPurchaseAccount();
    if (!s.onboarded) completeOnboarding();
    void navigate({ to: "/feed", replace: true });
  };

  useEffect(() => {
    if (!session || finishing.current) return;
    if (!requiredAccount && !isBridge) return;
    finishing.current = true;
    void finish().finally(() => { finishing.current = false; });
  }, [session, requiredAccount, isBridge]);

  // Bridge mode opened with a provider: start that sign-in right away. Skip when
  // we're back from the provider (access_token in the hash) — the session listener
  // finishes the hand-off, otherwise we'd redirect in a loop.
  useEffect(() => {
    if (!isBridge || !provider || autoStarted.current) return;
    if (session || window.location.hash.includes("access_token")) return;
    autoStarted.current = true;
    void oauth(provider);
  }, [isBridge, provider, session]);

  const oauth = async (p: Provider) => {
    track('sign_in_started', { provider: p });
    setError(null);
    setBusy(true);
    // In bridge mode return to this page so the app hand-off completes here.
    const redirect_uri = isBridge
      ? `${window.location.origin}/account?bridge=1&provider=${p}`
      : window.location.origin;
    const { error: oauthError } = await supabase.auth.signInWithOAuth({
      provider: p as "google" | "apple",
      options: { redirectTo: redirect_uri },
    });
    if (oauthError) { track('sign_in_failed', { category: 'provider' }); setError(friendly(oauthError)); setBusy(false); return; }
    // Full-page redirect to the provider; when it returns, the session listener continues.
  };

  const later = () => {
    if (requiredAccount) return;
    if (fromWelcome) { void navigate({ to: "/" }); return; }
    completeOnboarding();
    void navigate({ to: "/feed", replace: true });
  };

  if (handed) {
    return (
      <Screen className="items-center px-6 text-center">
        <div className="flex flex-1 flex-col items-center justify-center">
          <Mascot pose="heart" className="h-24 w-24" />
          <h1 className="mt-5 text-[1.5rem] font-black">You're signed in!</h1>
          <p className="mt-2 max-w-[300px] text-[0.9375rem] text-muted-foreground">
            You can close this page and return to the Kizuki app — your words, streak and reviews are syncing.
          </p>
        </div>
        <div className="w-full space-y-3 pb-2">
          <Button onClick={() => void handoff()}>Return to the app</Button>
        </div>
      </Screen>
    );
  }

  return (
    <Screen>
      {!requiredAccount && !isBridge && <TopBar onBack={() => (fromWelcome ? navigate({ to: "/" }) : navigate({ to: "/trial" }))} />}
      <div className="flex flex-1 flex-col items-center justify-center px-6 text-center">
        {/* Mascot on a soft orange glow, so the screen feels alive, not empty. */}
        <div className="relative">
          <div aria-hidden className="absolute -inset-8 rounded-full bg-[radial-gradient(circle,var(--primary-dim),transparent_70%)]" />
          <Mascot pose="wave" className="relative h-[104px] w-[104px]" />
        </div>
        <h1 className="mt-2.5 text-[1.5rem] font-black leading-tight">
          {initialMode === "signin" ? <>Welcome <span className="text-primary">back</span></> : <>Save your <span className="text-primary">progress</span></>}
        </h1>
        <p className="mt-1.5 text-[0.9375rem] text-muted-foreground">{initialMode === "signin" ? "Sign in to pick up where you left off." : "Keep your words, streak and reviews safe on every device."}</p>

        <div className="mt-7 w-full space-y-3">
          {error && <p role="alert" className="rounded-xl bg-danger-soft px-3 py-2 text-center text-[0.875rem] font-bold text-danger">{error}</p>}
          {signInProviders(device).map((p) => <Button key={p} variant="surface" disabled={busy} onClick={() => void oauth(p)} className="h-[68px] justify-start gap-3.5 px-4 tracking-normal">
            <span className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-surface-3"><ProviderIcon provider={p} /></span>
            <span className="flex-1 text-left">{busy ? 'Signing in…' : `Continue with ${p === 'google' ? 'Google' : 'Apple'}`}</span>
            <ChevronRight aria-hidden="true" className="h-5 w-5 shrink-0 text-faint" />
          </Button>)}
          {!busy && <p className="flex items-center justify-center gap-1.5 pt-1 text-[0.8125rem] font-bold text-faint"><ShieldCheck aria-hidden="true" className="h-4 w-4" />One tap · no passwords · progress stays safe</p>}
        </div>
      </div>

      <div className="space-y-1 px-6 pt-6 text-center">
        {isBridge ? (
          <p className="text-[0.8125rem] font-bold text-faint">Finish here in your browser — the Kizuki app opens again as soon as you're done.</p>
        ) : (
          !requiredAccount && <Button variant="ghost" size="md" onClick={later} className="w-full">{fromWelcome ? "Back" : "Maybe later"}</Button>
        )}
      </div>
    </Screen>
  );
}

/** Forget this browser's copy of the session without signing it out on the server (that
 * would end the phone's session too): stop refreshing it and remove it from storage. */
function dropBrowserSession() {
  void supabase.auth.stopAutoRefresh();
  try {
    for (const key of Object.keys(window.localStorage)) {
      if (/^sb-.*-auth-token/.test(key)) window.localStorage.removeItem(key);
    }
  } catch {
    // Storage unavailable: nothing persisted to drop.
  }
}

function friendly(err: unknown) {
  const msg = err instanceof Error ? err.message : typeof err === "object" && err && "message" in err ? String((err as { message: unknown }).message) : String(err);
  if (/offline|network/i.test(msg)) return "You're offline. Check your connection and try again.";
  return msg || "Something went wrong. Please try again.";
}
