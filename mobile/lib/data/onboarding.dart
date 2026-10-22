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

/// The welcome message before the trial: captions timed to assets/video/message.mp4
/// (public/video/kizuki-message.mp4 on web). A presenter from the Kizuki team, not a
/// personal founder story — swap in the founder's own recording + captions when there is one.
const founderLines = [
  FounderLine(0.0, "こんにちは！"),
  FounderLine(1.1, "Okay, real talk before you start."),
  FounderLine(2.6, "Most people learn Japanese the usual way."),
  FounderLine(4.65, "Textbooks, drill apps, flashcards."),
  FounderLine(7.3, "And sure, you can order a coffee."),
  FounderLine(9.38, "But a real conversation?"),
  FounderLine(11.0, "You can't follow a thing."),
  FounderLine(12.5, "What actually works is listening."),
  FounderLine(14.63, "A lot. Anime, vlogs, street interviews,"),
  FounderLine(17.49, "and pausing on every word you don't get."),
  FounderLine(19.8, "Kizuki does all of that for you,"),
  FounderLine(21.61, "in short clips that actually feel fun."),
  FounderLine(24.2, "Watch a clip, tap a word,"),
  FounderLine(25.7, "review it later with the real audio."),
  FounderLine(27.7, "If you've got feedback, or just wanna say hi,"),
  FounderLine(30.8, "message me anytime."),
  FounderLine(32.41, "がんばろう！ Let's do this together."),
];

/// Length of the message video (also the countdown when the video can't play).
const founderSeconds = 36;
const founderVideoAsset = 'assets/video/message.mp4';
const founderPosterAsset = 'assets/video/message.jpg';
