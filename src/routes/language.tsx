import { createFileRoute, useNavigate, useRouter } from "@tanstack/react-router";
import { Check } from "lucide-react";
import { useState } from "react";
import { z } from "zod";

import { LivelyMascot, Pop } from "@/components/mimi/Mascot";
import { Button, Screen, TopBar } from "@/components/mimi/ui";
import { track } from "@/lib/analytics";
import { haptic } from "@/lib/haptics";
import { getLang, isLangChosen, setLang, suggestedLang, trIn } from "@/lib/i18n";
import { LANGUAGES, type LangCode, type Language } from "@/lib/logic";
import { cn } from "@/lib/utils";

const searchSchema = z.object({ from: z.enum(["settings"]).optional() });

export const Route = createFileRoute("/language")({
  validateSearch: searchSchema,
  head: () => ({
    meta: [
      { title: "Choose your language — Kizuki" },
      { name: "description", content: "Pick the language Kizuki uses to explain Japanese: English, Vietnamese, Indonesian, Thai, Korean or Brazilian Portuguese." },
      { property: "og:title", content: "Choose your language — Kizuki" },
      { property: "og:description", content: "Pick the language Kizuki uses to explain Japanese: English, Vietnamese, Indonesian, Thai, Korean or Brazilian Portuguese." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: LanguagePage,
});

/** App language picker — mirrored by LanguageScreen in mobile/lib/screens/language.dart.
 * First run (before the welcome screen) and Settings → App language. The browser's language is
 * preselected when Kizuki speaks it; the heading and button preview the highlighted language. */
function LanguagePage() {
  const { from } = Route.useSearch();
  const fromSettings = from === "settings";
  const navigate = useNavigate();
  const router = useRouter();
  const [picked, setPicked] = useState<LangCode>(() => (isLangChosen() ? getLang() : suggestedLang()));
  const back = () => (window.history.length > 1 ? router.history.back() : void navigate({ to: "/settings" }));

  const done = () => {
    haptic("tap");
    const before = getLang();
    setLang(picked);
    track("language_selected", { language: picked, previous_language: before, suggested: picked === suggestedLang(), source: fromSettings ? "settings" : "first_run" });
    if (fromSettings) back();
    else void navigate({ to: "/", replace: true });
  };

  return (
    <Screen scroll={false}>
      {fromSettings ? <TopBar title={trIn(picked, "App language")} onBack={back} /> : <div className="h-3 shrink-0" />}
      <div className="min-h-0 flex-1 overflow-y-auto px-6 pb-6 pt-2 no-scrollbar scroll-fade">
        {!fromSettings && (
          <div className="mb-3 flex justify-center">
            <LivelyMascot pose="wave" size={112} idle="float" entrance />
          </div>
        )}
        <h1 className={cn("text-[1.625rem] font-black leading-tight", !fromSettings && "text-center")}>{trIn(picked, "Choose your language")}</h1>
        <p className={cn("mt-2 text-[0.9375rem] text-muted-foreground", !fromSettings && "text-center")}>
          {trIn(picked, "Kizuki explains Japanese in this language. You can change it anytime in Settings.")}
        </p>
        <div className="mt-5 space-y-2.5" role="radiogroup" aria-label={trIn(picked, "Choose your language")}>
          {LANGUAGES.map((l) => (
            <LanguageRow key={l.code} language={l} active={picked === l.code} onClick={() => setPicked(l.code)} />
          ))}
        </div>
      </div>
      <div className="shrink-0 bg-background px-6 pb-3 pt-1">
        <Button onClick={done}>{fromSettings ? trIn(picked, "Save") : trIn(picked, "Continue")}</Button>
      </div>
    </Screen>
  );
}

function LanguageRow({ language, active, onClick }: { language: Language; active: boolean; onClick: () => void }) {
  const same = language.native === language.english;
  return (
    <button
      role="radio"
      aria-checked={active}
      aria-label={same ? language.native : `${language.native}, ${language.english}`}
      lang={language.code === "pt" ? "pt-BR" : language.code}
      onClick={() => { haptic("select"); onClick(); }}
      className={cn("press flex h-[68px] w-full items-center gap-3.5 rounded-2xl border-2 px-3.5 text-left transition-colors duration-150", active ? "border-primary bg-primary/10" : "border-border bg-surface")}
    >
      <span className="flex h-[42px] w-[42px] shrink-0 items-center justify-center rounded-full bg-surface-2">
        <Pop active={active} className="font-emoji text-[1.5rem] leading-none">{language.flag}</Pop>
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-[1rem] font-extrabold">{language.native}</span>
        {!same && <span className="block truncate text-[0.8125rem] font-semibold text-muted-foreground">{language.english}</span>}
      </span>
      <span className={cn("flex h-6 w-6 shrink-0 items-center justify-center rounded-full border-2 transition-colors duration-150", active ? "border-primary bg-primary" : "border-surface-3")}>
        {active && <Check className="h-[15px] w-[15px] text-primary-foreground" strokeWidth={3.5} />}
      </span>
    </button>
  );
}
