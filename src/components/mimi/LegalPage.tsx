import { useRouter } from "@tanstack/react-router";

import { Screen, TopBar } from "./ui";

/** Plain text legal page — copy mirrored word for word by mobile/lib/screens/legal.dart. */
export function LegalPage({ title, sections }: { title: string; sections: { h: string; p: string }[] }) {
  const router = useRouter();
  return (
    <Screen>
      <TopBar title={title} onBack={() => (router.history.canGoBack() ? router.history.back() : void router.navigate({ to: "/settings" }))} />
      <div className="space-y-5 px-5 pb-10 pt-2">
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
