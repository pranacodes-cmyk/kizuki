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

/// User's founder story; video contains its own timed captions.
const founderLines = [
  FounderLine(0.7, "Konnichiwa, Kenji here,"),
  FounderLine(2.44, "creator of Kizuki."),
  FounderLine(3.82, "Three years ago,"),
  FounderLine(4.44, "I failed my"),
  FounderLine(5.02, "first Japanese test."),
  FounderLine(6.58, "So bad, my"),
  FounderLine(7.3, "teacher asked if"),
  FounderLine(8.04, "I was guessing"),
  FounderLine(8.52, "randomly."),
  FounderLine(10.18, "18 months later,"),
  FounderLine(11.42, "I passed the"),
  FounderLine(11.98, "N2, and was"),
  FounderLine(13.62, "giving presentations in"),
  FounderLine(14.6, "Tokyo."),
  FounderLine(15.18, "How?"),
  FounderLine(15.9, "Definitely not Duolingo."),
  FounderLine(17.1, "That bird only"),
  FounderLine(17.62, "taught me, the"),
  FounderLine(18.46, "lawyer loves green"),
  FounderLine(19.18, "tea."),
  FounderLine(20.42, "And textbooks?"),
  FounderLine(22.4, "Genki made me"),
  FounderLine(22.94, "want to stare"),
  FounderLine(23.36, "at a blank"),
  FounderLine(23.76, "wall."),
  FounderLine(24.74, "Then it hit"),
  FounderLine(25.18, "me."),
  FounderLine(25.8, "Japanese babies don't"),
  FounderLine(26.64, "study grammar charts."),
  FounderLine(27.58, "They just listen"),
  FounderLine(28.52, "until it clicks."),
  FounderLine(30.4, "That click is"),
  FounderLine(31.14, "what Kizuki means."),
  FounderLine(32.76, "Short, real clips,"),
  FounderLine(34.02, "tap whatever you"),
  FounderLine(34.7, "don't get."),
  FounderLine(35.56, "If anything feels"),
  FounderLine(36.16, "off, message me"),
  FounderLine(37.2, "in the app."),
  FounderLine(37.96, "I read every one."),
  FounderLine(39.5, "Ja ne!"),
];

/// Length of the message video (also the countdown when the video can't play).
const founderSeconds = 40.067;
const founderVideoAsset = 'assets/video/message.mp4';
const founderPosterAsset = 'assets/video/message.jpg';
