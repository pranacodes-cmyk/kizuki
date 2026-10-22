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
  FounderLine(1.4, "Okay, quick one before you start."),
  FounderLine(3.8, "Most of us tried textbooks and drill apps…"),
  FounderLine(6.45, "…and still couldn't follow real Japanese."),
  FounderLine(9.0, "What actually works is listening."),
  FounderLine(11.4, "A lot. To real people."),
  FounderLine(13.65, "That's Kizuki."),
  FounderLine(15.25, "Short, real clips."),
  FounderLine(17.2, "Tap any word to see what it means, right there."),
  FounderLine(20.25, "Then review it later, with the original voice."),
  FounderLine(23.55, "Ten minutes a day…"),
  FounderLine(24.95, "…and it starts to click."),
  FounderLine(26.55, "Got feedback? Message us anytime."),
  FounderLine(29.25, "がんばろう！"),
];

/// Length of the message video (also the countdown when the video can't play).
const founderSeconds = 30;
const founderVideoAsset = 'assets/video/message.mp4';
const founderPosterAsset = 'assets/video/message.jpg';
