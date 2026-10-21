// Topic labels for clip tags — mirrored from src/lib/topics.ts.
const _topics = {
  'anime': ('Anime', '🎌'),
  'drama': ('Drama', '🎭'),
  'fun': ('Fun', '🎉'),
  'comedy': ('Comedy', '😂'),
  'work': ('Work', '💼'),
  'romance': ('Romance', '❤️'),
  'travel': ('Travel', '✈️'),
  'food': ('Food', '🍜'),
  'culture': ('Culture', '🏯'),
  'friends': ('Friends', '👫'),
  'family': ('Family', '🏡'),
  'animals': ('Animals', '🐾'),
  'daily': ('Daily life', '☀️'),
  'school': ('School', '🏫'),
  'sports': ('Sports', '⚽'),
  'music': ('Music', '🎵'),
  'kids': ('Kids', '🧸'),
  'vlog': ('Vlogs', '📹'),
  'learning': ('Lessons', '📖'),
  'interview': ('Interviews', '🎤'),
  'news': ('News', '📰'),
  'games': ('Games', '🎮'),
};

String topicLabel(String t) => _topics[t]?.$1 ?? (t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}');
String topicEmoji(String t) => _topics[t]?.$2 ?? '🎬';
