// Onboarding questions + copy — mirrored in mobile/lib/data/onboarding.dart.

export const reasonOptions = [
  { id: "travel", emoji: "✈️", label: "Travel" },
  { id: "anime", emoji: "🎌", label: "Anime & manga" },
  { id: "work", emoji: "💼", label: "Work" },
  { id: "fun", emoji: "🎉", label: "Just for fun" },
  { id: "friends", emoji: "👫", label: "Friends" },
  { id: "family", emoji: "🏡", label: "Family" },
  { id: "romance", emoji: "❤️", label: "Romance" },
  { id: "culture", emoji: "🏯", label: "Culture" },
];

export const levelOptions = [
  { label: "I'm new to Japanese", hint: "Starting from zero" },
  { label: "I know some words", hint: "Hello, thank you, a few basics" },
  { label: "I can have simple chats", hint: "Introduce myself, order food" },
  { label: "I can talk about many topics", hint: "Everyday conversations" },
  { label: "I can discuss most things", hint: "Want to sound natural" },
];

export const challengeOptions = [
  { id: "listening", emoji: "👂", label: "Understanding natives" },
  { id: "start", emoji: "🧭", label: "Where to start" },
  { id: "motivation", emoji: "💪", label: "Staying motivated" },
  { id: "grammar", emoji: "🧩", label: "Grammar" },
  { id: "speaking", emoji: "🗣️", label: "Speaking naturally" },
  { id: "vocab", emoji: "📚", label: "Remembering words" },
];

export const sourceOptions = [
  { id: "instagram", emoji: "📸", label: "Instagram" },
  { id: "youtube", emoji: "▶️", label: "YouTube" },
  { id: "tiktok", emoji: "🎵", label: "TikTok" },
  { id: "friend", emoji: "🤝", label: "A friend" },
  { id: "search", emoji: "🔎", label: "Google search" },
  { id: "store", emoji: "🛍️", label: "Play Store" },
  { id: "reddit", emoji: "💬", label: "Reddit" },
  { id: "other", emoji: "✨", label: "Somewhere else" },
];

export const windowOptions = [
  { id: "morning", emoji: "☀️", label: "Morning", hint: "6 AM – 12 PM" },
  { id: "afternoon", emoji: "⛅", label: "Afternoon", hint: "12 – 6 PM" },
  { id: "evening", emoji: "🌇", label: "Evening", hint: "6 – 10 PM" },
  { id: "night", emoji: "🌙", label: "Night", hint: "10 PM – 6 AM" },
];

export const streakOptions = [
  { days: 7, label: "Good", emoji: "🙂" },
  { days: 14, label: "Great", emoji: "😄" },
  { days: 30, label: "Incredible", emoji: "🤩" },
  { days: 50, label: "Unstoppable", emoji: "🔥" },
];

export const reviews = [
  { name: "Aarav S.", stars: 5, text: "Finally I understand what my favourite anime characters are actually saying." },
  { name: "Mei L.", stars: 5, text: "Tapping words in real clips is so much better than flashcards from a textbook." },
  { name: "Jonas K.", stars: 5, text: "Ten minutes a day on the train and my listening is way better." },
  { name: "Priya R.", stars: 5, text: "The explanations in context are gold. It feels like a tutor sitting next to me." },
];

/** The welcome message before the trial: captions timed to public/video/kizuki-message.mp4
 * (mobile/assets/video/message.mp4 in the app). A presenter from the Kizuki team, not a
 * personal founder story — swap in the founder's own recording + captions when there is one. */
export const founderLines = [
  { t: 0.0, text: "こんにちは！" },
  { t: 1.1, text: "Okay, real talk before you start." },
  { t: 2.6, text: "Most people learn Japanese the usual way." },
  { t: 4.65, text: "Textbooks, drill apps, flashcards." },
  { t: 7.3, text: "And sure, you can order a coffee." },
  { t: 9.38, text: "But a real conversation?" },
  { t: 11.0, text: "You can't follow a thing." },
  { t: 12.5, text: "What actually works is listening." },
  { t: 14.63, text: "A lot. Anime, vlogs, street interviews," },
  { t: 17.49, text: "and pausing on every word you don't get." },
  { t: 19.8, text: "Kizuki does all of that for you," },
  { t: 21.61, text: "in short clips that actually feel fun." },
  { t: 24.2, text: "Watch a clip, tap a word," },
  { t: 25.7, text: "review it later with the real audio." },
  { t: 27.7, text: "If you've got feedback, or just wanna say hi," },
  { t: 30.8, text: "message me anytime." },
  { t: 32.41, text: "がんばろう！ Let's do this together." },
];
/** Length of the message video (also the countdown when the video can't play). */
export const FOUNDER_SECONDS = 36;
export const FOUNDER_VIDEO_URL = "/video/kizuki-message.mp4";
export const FOUNDER_VIDEO_WEBM_URL = "/video/kizuki-message.webm";
export const FOUNDER_POSTER_URL = "/video/kizuki-message.jpg";
