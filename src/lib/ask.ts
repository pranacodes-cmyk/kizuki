// "Ask Kizuki" copy + request shape — mirrored in mobile/lib/data/ask.dart.
// The tutor runs on the server (src/routes/api/public/ask.ts); both clients post the same body.

import { tr } from "./i18n-core";

export type AskWord = { surface: string; head: string; reading: string; gloss: string };
export type AskContext = {
  clipId: string;
  title: string;
  level: string;
  learnerLevel: string;
  line: { ja: string; en: string };
  word: AskWord | null;
};

/** Quick questions shown before the first message. */
export const askSuggestions = (hasWord: boolean): string[] =>
  hasWord
    ? [tr("Why this form here?"), tr("Give me 2 more examples"), tr("Is it casual or polite?"), tr("Break down the whole line")]
    : [tr("Break down this line"), tr("Explain the grammar"), tr("Say it more politely"), tr("A similar sentence, please")];

/** First tutor bubble (shown locally, never sent). */
export const askGreeting = (word: AskWord | null) =>
  word
    ? tr("Ask me anything about **{word}** in this line — grammar, nuance, or more examples.", { word: word.head })
    : tr("Ask me anything about this line — grammar, nuance, or how to use it yourself.");

/** Path of the tutor endpoint on the web app (the phone app calls the published origin). */
export const ASK_PATH = "/api/public/ask";

/** Friendly copy for a failed question, keyed by HTTP status. */
export function askErrorText(status: number | null, serverMessage?: string | null) {
  if (serverMessage) return tr(serverMessage);
  if (status === 401) return tr("Please sign in again to ask Kizuki.");
  if (status === 429) return tr("Kizuki is busy right now — try again in a moment.");
  if (status === 402) return tr("Ask Kizuki is paused for now. Please try again later.");
  if (status === 404) return tr("Ask Kizuki isn't available yet. Please try again later.");
  if (status === null) return tr("You're offline. Check your connection and try again.");
  return tr("Kizuki couldn't answer that. Please try again.");
}
