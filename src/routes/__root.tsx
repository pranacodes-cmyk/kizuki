import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  Outlet,
  Link,
  createRootRouteWithContext,
  useRouter,
  useLocation,
  HeadContent,
  Scripts,
  type ErrorComponentProps,
} from "@tanstack/react-router";
import { useEffect, useState, type ReactNode } from "react";

import appCss from "../styles.css?url";
import { reportLovableError } from "../lib/lovable-error-reporting";
import { TourHost } from "@/components/mimi/WelcomeTour";
import { AppFrame } from "@/components/mimi/AppFrame";
import { Mascot } from "@/components/mimi/Mascot";
import { useApp } from "@/lib/store";
import { learningPath, onboardingPath, purchaseNeedsAccount, subscriptionAccess } from "@/lib/logic";
import { useTour } from "@/lib/tour-store";
import { Button } from "@/components/mimi/ui";
import { AppEffects } from "@/components/mimi/AppEffects";
import { AnalyticsConsent } from "@/components/mimi/AnalyticsConsent";

function NotFoundComponent() {
  return (
    <AppFrame>
      <div className="absolute inset-0 flex flex-col items-center justify-center bg-background px-8 text-center">
        <Mascot pose="think" className="h-36 w-36" />
        <h1 className="mt-4 text-[1.6rem] font-black">This page wandered off</h1>
        <p className="mt-2 text-[0.9375rem] text-muted-foreground">The page you're looking for doesn't exist or has moved.</p>
        <Link to="/" className="btn-3d mt-8 inline-flex h-12 items-center justify-center rounded-2xl bg-primary px-6 font-extrabold text-primary-foreground">
          Back to Kizuki
        </Link>
      </div>
    </AppFrame>
  );
}

function ErrorComponent({ error, reset }: ErrorComponentProps) {
  console.error(error);
  const router = useRouter();
  useEffect(() => {
    reportLovableError(error, { boundary: "tanstack_root_error_component" });
  }, [error]);

  return (
    <AppFrame>
      <div className="absolute inset-0 flex flex-col items-center justify-center bg-background px-8 text-center">
        <Mascot pose="think" className="h-36 w-36" />
        <h1 className="mt-4 text-[1.6rem] font-black">Something went wrong</h1>
        <p className="mt-2 text-[0.9375rem] text-muted-foreground">Try again, or head back to your feed.</p>
        <div className="mt-8 flex gap-3">
          <button
            onClick={() => {
              router.invalidate();
              reset();
            }}
            className="btn-3d inline-flex h-12 items-center justify-center rounded-2xl bg-primary px-6 font-extrabold text-primary-foreground"
          >
            Try again
          </button>
          <a href="/" className="btn-3d-surface inline-flex h-12 items-center justify-center rounded-2xl bg-surface-2 px-6 font-extrabold text-foreground">
            Home
          </a>
        </div>
      </div>
    </AppFrame>
  );
}

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1, viewport-fit=cover" },
      { name: "theme-color", content: "#000000" },
      { title: "Kizuki — Learn Japanese from real clips" },
      { name: "description", content: "Learn Japanese by watching short real clips with tap-to-translate subtitles, saved words and smart flashcards." },
      { name: "author", content: "Kizuki" },
      { property: "og:site_name", content: "Kizuki" },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
    links: [
      { rel: "preconnect", href: "https://fonts.googleapis.com" },
      { rel: "preconnect", href: "https://fonts.gstatic.com", crossOrigin: "anonymous" },
      // Official YouTube player hosts: connect early so the first clip starts sooner.
      { rel: "preconnect", href: "https://www.youtube.com" },
      { rel: "preconnect", href: "https://www.youtube-nocookie.com" },
      { rel: "preconnect", href: "https://i.ytimg.com" },
      { rel: "dns-prefetch", href: "https://s.ytimg.com" },
      {
        rel: "stylesheet",
        href: "https://fonts.googleapis.com/css2?family=M+PLUS+Rounded+1c:wght@400;500;700;800&family=Nunito:wght@400;600;700;800;900&display=swap",
      },
      { rel: "stylesheet", href: appCss },
      { rel: "icon", type: "image/png", href: "/favicon.png" },
    ],
  }),
  shellComponent: RootShell,
  component: RootComponent,
  notFoundComponent: NotFoundComponent,
  errorComponent: ErrorComponent,
});

function RootShell({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}

function RootComponent() {
  const { queryClient } = Route.useRouteContext();

  return (
    <QueryClientProvider client={queryClient}>
      <AppFrame>
        <AppEffects />
        <AnalyticsConsent />
        {/* Required: nested routes render here. Removing <Outlet /> breaks all child routes. */}
        <SubscriptionBoundary><PurchaseAccountBoundary><Outlet /></PurchaseAccountBoundary></SubscriptionBoundary>
      </AppFrame>
    </QueryClientProvider>
  );
}

function SubscriptionBoundary({ children }: { children: ReactNode }) {
  const premium = useApp((s) => s.premium);
  const onboarded = useApp((s) => s.onboarded);
  const pending = useApp((s) => s.purchaseAccountPending);
  const { pathname } = useLocation();
  const router = useRouter();
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const check = () => setNow(Date.now());
    const end = premium.expiresAt ?? premium.trialEndsAt;
    const delay = end == null || end <= Date.now() ? 60000 : Math.min(end - Date.now(), 2147483647);
    const timer = setTimeout(check, delay);
    window.addEventListener("focus", check);
    document.addEventListener("visibilitychange", check);
    return () => { clearTimeout(timer); window.removeEventListener("focus", check); document.removeEventListener("visibilitychange", check); };
  }, [premium, now]);
  const access = subscriptionAccess(premium.active, premium.expiresAt, premium.trialEndsAt, now);
  const blocked = (onboarded || !onboardingPath(pathname)) && learningPath(pathname) && !access && !pending;
  useEffect(() => {
    if (!access && onboarded) { useTour.getState().reset(); useTour.getState().closeSheets(); }
  }, [access, onboarded]);
  if (!blocked) return <>{children}{access && <TourHost />}</>;
  return <div className="absolute inset-0 flex flex-col items-center justify-center bg-background px-6 text-center">
    <Mascot pose="heart" className="h-28 w-28" />
    <h1 className="mt-4 text-2xl font-black">Keep learning with Premium</h1>
    <p className="mt-2 text-muted-foreground">Your access has ended. Renew or restore your subscription to continue. Your saved words and progress are safe.</p>
    <div className="mt-6 w-full"><Button onClick={() => void router.navigate({ to: "/trial" })}>See plans</Button></div>
    <div className="mt-3 w-full"><Button variant="surface" onClick={() => void router.navigate({ to: "/settings" })}>Settings & restore purchase</Button></div>
    <Link to="/support" className="mt-5 text-sm text-muted-foreground">Get help</Link>
  </div>;
}

function PurchaseAccountBoundary({ children }: { children: ReactNode }) {
  const pending = useApp((s) => s.purchaseAccountPending);
  const location = useLocation();
  const allowed = ["/account", "/terms", "/privacy", "/support"].includes(location.pathname);
  if (!purchaseNeedsAccount(pending, false) || allowed) return children;
  return <div className="flex h-full flex-col items-center justify-center bg-background px-6 text-center">
    <Mascot pose="heart" className="h-24 w-24" />
    <h1 className="mt-4 text-2xl font-black">Your purchase is saved</h1>
    <p className="mt-2 text-muted-foreground">Sign in to continue with Kizuki.</p>
    <Link to="/account" search={{ mode: "signin" }} className="btn-3d mt-6 flex h-14 w-full items-center justify-center rounded-2xl bg-primary font-extrabold text-primary-foreground">Continue to sign in</Link>
  </div>;
}
