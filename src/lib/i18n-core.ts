// The learner's app language (no React here, so logic.ts can use tr()) — mirrored in
// mobile/lib/i18n/i18n.dart. React components use the useLang hook from ./i18n.
//
// Interface text is written in English in the code and wrapped in tr(); the translations are
// generated into i18n-strings.json (scripts/i18n/gen_strings.ts) from the reviewed catalog in
// scripts/i18n/ui/. Anything not translated shows in English, never as a key.
//
// The choice is a device setting (not learner state), so signing in or switching accounts never
// changes the language the person picked. The app shell renders only after hydration, so
// reading localStorage here never causes SSR mismatches.
import STRINGS from "./i18n-strings.json";
import { fillTemplate, isLangCode, languageForLocale, LANGUAGES, type LangCode, type Language } from "./logic";

const KEY = "kizuki-lang";
const TABLES = STRINGS as Record<string, Record<string, string>>;

let lang: LangCode = "en";
let chosen = false;
let table: Record<string, string> | null = null;
let loaded = false;
const listeners = new Set<() => void>();

function load() {
  if (loaded || typeof window === "undefined") return;
  loaded = true;
  try {
    const saved = window.localStorage.getItem(KEY);
    if (isLangCode(saved)) {
      chosen = true;
      apply(saved);
    }
  } catch {
    /* storage blocked: English */
  }
}

function apply(code: LangCode) {
  lang = code;
  table = code === "en" ? null : (TABLES[code] ?? null);
  document.documentElement.lang = code;
  for (const l of listeners) l();
}

export function getLang(): LangCode {
  load();
  return lang;
}

/** True once the person picked a language (the first-run picker is then skipped). */
export function isLangChosen(): boolean {
  load();
  return chosen;
}

export function setLang(code: LangCode) {
  load();
  chosen = true;
  try {
    window.localStorage.setItem(KEY, code);
  } catch {
    /* storage blocked: this session only */
  }
  apply(code);
}

/** The language the browser suggests, English when unsupported. */
export function suggestedLang(): LangCode {
  return typeof navigator === "undefined" ? "en" : languageForLocale(navigator.language);
}

export function currentLanguage(): Language {
  return LANGUAGES.find((l) => l.code === getLang()) ?? LANGUAGES[0]!;
}

export function subscribeLang(fn: () => void) {
  listeners.add(fn);
  return () => {
    listeners.delete(fn);
  };
}

/** Interface text in the learner's language: `en` is the English text (and the lookup key);
 * `{name}` placeholders are filled from `vars`. */
export function tr(en: string, vars?: Record<string, string | number>): string {
  load();
  return fillTemplate(table?.[en] ?? en, vars);
}

/** `en` in a specific language (the picker previews its own text before the choice is saved). */
export function trIn(code: LangCode, en: string, vars?: Record<string, string | number>): string {
  return fillTemplate((code === "en" ? null : TABLES[code])?.[en] ?? en, vars);
}

/** Count text: `one` when n is 1, else `other`; both get `{n}` (and any vars). */
export function trn(n: number, one: string, other: string, vars?: Record<string, string | number>): string {
  return tr(n === 1 ? one : other, { n, ...vars });
}
