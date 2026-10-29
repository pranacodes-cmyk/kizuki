// "Ask Kizuki" copy + request shape — mirrored from src/lib/ask.ts.
// The tutor runs on the web app's server (/api/public/ask); both clients post the same body.

import '../i18n/i18n.dart';

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
    ? [tr('Why this form here?'), tr('Give me 2 more examples'), tr('Is it casual or polite?'), tr('Break down the whole line')]
    : [tr('Break down this line'), tr('Explain the grammar'), tr('Say it more politely'), tr('A similar sentence, please')];

/// First tutor bubble (shown locally, never sent).
String askGreeting(AskWord? word) => word != null
    ? tr('Ask me anything about **{word}** in this line — grammar, nuance, or more examples.', {'word': word.head})
    : tr('Ask me anything about this line — grammar, nuance, or how to use it yourself.');

/// Path of the tutor endpoint on the web app.
const askPath = '/api/public/ask';

/// Friendly copy for a failed question, keyed by HTTP status (null = no connection).
String askErrorText(int? status, [String? serverMessage]) {
  if (serverMessage != null && serverMessage.isNotEmpty) return tr(serverMessage);
  if (status == 401) return tr('Please sign in again to ask Kizuki.');
  if (status == 429) return tr('Kizuki is busy right now — try again in a moment.');
  if (status == 402) return tr('Ask Kizuki is paused for now. Please try again later.');
  if (status == 404) return tr("Ask Kizuki isn't available yet. Please try again later.");
  if (status == null) return tr("You're offline. Check your connection and try again.");
  return tr("Kizuki couldn't answer that. Please try again.");
}
