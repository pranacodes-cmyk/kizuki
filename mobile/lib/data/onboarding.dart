// Onboarding questions + copy — mirrored from src/lib/onboarding.ts.

class Option {
  final String id, emoji, label;
  final String? hint;
  const Option(this.id, this.emoji, this.label, [this.hint]);
}

const reasonOptions = [
  Option('travel', '✈️', 'Travel'),
  Option('anime', '🎌', 'Anime & manga'),
  Option('work', '💼', 'Work'),
  Option('fun', '🎉', 'Just for fun'),
  Option('friends', '👫', 'Friends'),
  Option('family', '🏡', 'Family'),
  Option('romance', '❤️', 'Romance'),
  Option('culture', '🏯', 'Culture'),
];

const levelOptions = [
  Option('0', '', "I'm new to Japanese", 'Starting from zero'),
  Option('1', '', 'I know some words', 'Hello, thank you, a few basics'),
  Option('2', '', 'I can have simple chats', 'Introduce myself, order food'),
  Option('3', '', 'I can talk about many topics', 'Everyday conversations'),
  Option('4', '', 'I can discuss most things', 'Want to sound natural'),
];

const challengeOptions = [
  Option('listening', '👂', 'Understanding natives'),
  Option('start', '🧭', 'Where to start'),
  Option('motivation', '💪', 'Staying motivated'),
  Option('grammar', '🧩', 'Grammar'),
  Option('speaking', '🗣️', 'Speaking naturally'),
  Option('vocab', '📚', 'Remembering words'),
];

const sourceOptions = [
  Option('instagram', '📸', 'Instagram'),
  Option('youtube', '▶️', 'YouTube'),
  Option('tiktok', '🎵', 'TikTok'),
  Option('friend', '🤝', 'A friend'),
  Option('search', '🔎', 'Google search'),
  Option('store', '🛍️', 'Play Store'),
  Option('reddit', '💬', 'Reddit'),
  Option('other', '✨', 'Somewhere else'),
];

const windowOptions = [
  Option('morning', '☀️', 'Morning', '6 AM – 12 PM'),
  Option('afternoon', '⛅', 'Afternoon', '12 – 6 PM'),
  Option('evening', '🌇', 'Evening', '6 – 10 PM'),
  Option('night', '🌙', 'Night', '10 PM – 6 AM'),
];

class StreakOption {
  final int days;
  final String label, emoji;
  const StreakOption(this.days, this.label, this.emoji);
}

const streakOptions = [
  StreakOption(7, 'Good', '🙂'),
  StreakOption(14, 'Great', '😄'),
  StreakOption(30, 'Incredible', '🤩'),
  StreakOption(50, 'Unstoppable', '🔥'),
];

class Review {
  final String name, text;
  final int stars;
  const Review(this.name, this.stars, this.text);
}

const reviews = [
  Review('Aarav S.', 5, 'Finally I understand what my favourite anime characters are actually saying.'),
  Review('Mei L.', 5, 'Tapping words in real clips is so much better than flashcards from a textbook.'),
  Review('Jonas K.', 5, 'Ten minutes a day on the train and my listening is way better.'),
  Review('Priya R.', 5, 'The explanations in context are gold. It feels like a tutor sitting next to me.'),
];

class FounderLine {
  final double t;
  final String text;
  const FounderLine(this.t, this.text);
}

/// Founder note — captions on the founder screen (and the script for the real video).
const founderLines = [
  FounderLine(0, "こんにちは！ Hi, I'm the person who built Kizuki."),
  FounderLine(4, 'I started Japanese the usual way — textbooks and drill apps.'),
  FounderLine(9, "I could order a coffee… but I couldn't follow a single real conversation."),
  FounderLine(15, 'What finally worked was listening. A lot. Anime, vlogs, dramas, street interviews.'),
  FounderLine(22, "Pausing on every word I didn't know, looking it up, and hearing it again."),
  FounderLine(28, 'Kizuki does all of that for you, in short clips that actually feel fun.'),
  FounderLine(34, "Watch a clip, tap a word, review it later with the real audio. That's it."),
  FounderLine(40, 'If you have feedback or just want to say hi, message me anytime.'),
  FounderLine(45, "がんばろう！ Let's do this together."),
];
const founderSeconds = 50;
