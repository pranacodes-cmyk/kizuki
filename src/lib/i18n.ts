// React side of the app language: re-exports the core (tr, setLang…) plus the useLang hook.
import { useSyncExternalStore } from "react";

import { getLang, subscribeLang } from "./i18n-core";
import type { LangCode } from "./logic";

export * from "./i18n-core";

/** Re-renders when the language changes. */
export function useLang(): LangCode {
  return useSyncExternalStore(subscribeLang, getLang, () => "en" as LangCode);
}
