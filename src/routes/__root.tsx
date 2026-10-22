import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  Outlet,
  Link,
  createRootRouteWithContext,
  useRouter,
  HeadContent,
  Scripts,
  type ErrorComponentProps,
} from "@tanstack/react-router";
import { useEffect, type ReactNode } from "react";

import appCss from "../styles.css?url";
import { reportLovableError } from "../lib/lovable-error-reporting";
import { TourHost } from "@/components/mimi/WelcomeTour";
import { AppFrame } from "@/components/mimi/AppFrame";
import { Mascot } from "@/components/mimi/Mascot";
import { AppEffects } from "@/components/mimi/AppEffects";

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
      { name: "theme-color", content: "#16171B" },
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
        {/* Required: nested routes render here. Removing <Outlet /> breaks all child routes. */}
        <Outlet />
        <TourHost />
      </AppFrame>
    </QueryClientProvider>
  );
}
