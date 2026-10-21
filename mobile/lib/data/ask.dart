// "Ask Kizuki" copy + request shape — mirrored from src/lib/ask.ts.
// The tutor runs on the web app's server (/api/public/ask); both clients post the same body.

class AskWord {
  final String surface, head, reading, gloss;
  const AskWord({required this.surface, required this.head, required this.reading, required this.gloss});
  Map<String, dynamic> toJson() => {'surface': surface, 'head': head, 'reading': reading, 'gloss': gloss};
}

class AskContext {
  final String clipId, title, level, learnerLevel, ja, en;
  final AskWord? word;
  const AskContext({required this.clipId, required this.title, required this.level, required this.learnerLevel, required this.ja, required this.en, this.word});
  Map<String, dynamic> toJson() => {
        'clipId': clipId,
        'title': title,
        'level': level,
        'learnerLevel': learnerLevel,
        'line': {'ja': ja, 'en': en},
        'word': word?.toJson(),
      };
}

/// Quick questions shown before the first message.
List<String> askSuggestions(bool hasWord) => hasWord
    ? const ['Why this form here?', 'Give me 2 more examples', 'Is it casual or polite?', 'Break down the whole line']
    : const ['Break down this line', 'Explain the grammar', 'Say it more politely', 'A similar sentence, please'];

/// First tutor bubble (shown locally, never sent).
String askGreeting(AskWord? word) => word != null
    ? 'Ask me anything about **${word.head}** in this line — grammar, nuance, or more examples.'
    : 'Ask me anything about this line — grammar, nuance, or how to use it yourself.';

/// Path of the tutor endpoint on the web app.
const askPath = '/api/public/ask';

/// Friendly copy for a failed question, keyed by HTTP status (null = no connection).
String askErrorText(int? status, [String? serverMessage]) {
  if (serverMessage != null && serverMessage.isNotEmpty) return serverMessage;
  if (status == 401) return 'Please sign in again to ask Kizuki.';
  if (status == 429) return 'Kizuki is busy right now — try again in a moment.';
  if (status == 402) return 'Ask Kizuki is paused for now. Please try again later.';
  if (status == 404) return "Ask Kizuki isn't available yet. Please try again later.";
  if (status == null) return "You're offline. Check your connection and try again.";
  return "Kizuki couldn't answer that. Please try again.";
}
