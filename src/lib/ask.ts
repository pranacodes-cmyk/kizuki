// "Ask Kizuki" copy + request shape — mirrored in mobile/lib/data/ask.dart.
// The tutor runs on the server (src/routes/api/public/ask.ts); both clients post the same body.

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
    ? ["Why this form here?", "Give me 2 more examples", "Is it casual or polite?", "Break down the whole line"]
    : ["Break down this line", "Explain the grammar", "Say it more politely", "A similar sentence, please"];

/** First tutor bubble (shown locally, never sent). */
export const askGreeting = (word: AskWord | null) =>
  word
    ? `Ask me anything about **${word.head}** in this line — grammar, nuance, or more examples.`
    : "Ask me anything about this line — grammar, nuance, or how to use it yourself.";

/** Path of the tutor endpoint on the web app (the phone app calls the published origin). */
export const ASK_PATH = "/api/public/ask";

/** Friendly copy for a failed question, keyed by HTTP status. */
export function askErrorText(status: number | null, serverMessage?: string | null) {
  if (serverMessage) return serverMessage;
  if (status === 401) return "Please sign in again to ask Kizuki.";
  if (status === 429) return "Kizuki is busy right now — try again in a moment.";
  if (status === 402) return "Ask Kizuki is paused for now. Please try again later.";
  if (status === 404) return "Ask Kizuki isn't available yet. Please try again later.";
  if (status === null) return "You're offline. Check your connection and try again.";
  return "Kizuki couldn't answer that. Please try again.";
}
