import { useRouter } from "@tanstack/react-router";

import { Screen, TopBar } from "./ui";

/** Plain text legal page. Draft copy — must be reviewed before release. */
export function LegalPage({ title, sections }: { title: string; sections: { h: string; p: string }[] }) {
  const router = useRouter();
  return (
    <Screen>
      <TopBar title={title} onBack={() => router.history.back()} />
      <div className="space-y-5 px-5 pb-10 pt-2">
        <p className="rounded-xl bg-surface-2 px-3 py-2 text-[0.8125rem] font-bold text-muted-foreground">Draft — to be finalised before release.</p>
        {sections.map((s) => (
          <section key={s.h}>
            <h2 className="text-[1rem] font-black">{s.h}</h2>
            <p className="mt-1 text-[0.9375rem] leading-relaxed text-muted-foreground">{s.p}</p>
          </section>
        ))}
      </div>
    </Screen>
  );
}
