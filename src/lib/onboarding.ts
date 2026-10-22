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
  { t: 1.4, text: "Okay, quick one before you start." },
  { t: 3.8, text: "Most of us tried textbooks and drill apps…" },
  { t: 6.45, text: "…and still couldn't follow real Japanese." },
  { t: 9.0, text: "What actually works is listening." },
  { t: 11.4, text: "A lot. To real people." },
  { t: 13.65, text: "That's Kizuki." },
  { t: 15.25, text: "Short, real clips." },
  { t: 17.2, text: "Tap any word to see what it means, right there." },
  { t: 20.25, text: "Then review it later, with the original voice." },
  { t: 23.55, text: "Ten minutes a day…" },
  { t: 24.95, text: "…and it starts to click." },
  { t: 26.55, text: "Got feedback? Message us anytime." },
  { t: 29.25, text: "がんばろう！" },
];
/** Length of the message video (also the countdown when the video can't play). */
export const FOUNDER_SECONDS = 30;
export const FOUNDER_VIDEO_URL = "/video/kizuki-message.mp4";
export const FOUNDER_VIDEO_WEBM_URL = "/video/kizuki-message.webm";
export const FOUNDER_POSTER_URL = "/video/kizuki-message.jpg";
