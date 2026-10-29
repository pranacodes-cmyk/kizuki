import { useRouter } from "@tanstack/react-router";

import type { LegalDoc } from "@/lib/legal";

import { Screen, TopBar } from "./ui";
import { tr } from "@/lib/i18n";

/** Legal page (Privacy / Terms) — layout mirrored by mobile/lib/screens/legal.dart; copy lives
 * in src/lib/legal.ts. Lines starting with "• " render as bullet points. */
export function LegalPage({ doc }: { doc: LegalDoc }) {
  const router = useRouter();
  return (
    <Screen>
      <TopBar title={doc.title} onBack={() => (router.history.canGoBack() ? router.history.back() : void router.navigate({ to: "/settings" }))} />
      <article className="px-5 pb-12 pt-2">
        <p className="text-[0.8125rem] font-bold text-faint">{tr("Last updated: {updated}", { updated: doc.updated })}</p>
        <p className="mt-3 text-[0.9375rem] leading-relaxed text-muted-foreground">{doc.intro}</p>
        {doc.sections.map((s) => (
          <section key={s.h} className="mt-7">
            <h2 className="text-[1.0625rem] font-black leading-snug">{s.h}</h2>
            <div className="mt-2 space-y-2">
              {s.body.map((line) =>
                line.startsWith("• ") ? (
                  <p key={line} className="flex gap-2.5 text-[0.9375rem] leading-relaxed text-muted-foreground">
                    <span aria-hidden className="mt-[0.6em] h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                    <span>{line.slice(2)}</span>
                  </p>
                ) : (
                  <p key={line} className="text-[0.9375rem] leading-relaxed text-muted-foreground">
                    {line}
                  </p>
                ),
              )}
            </div>
          </section>
        ))}
      </article>
    </Screen>
  );
}
