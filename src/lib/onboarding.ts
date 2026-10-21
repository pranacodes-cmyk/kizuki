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

/** Founder note — the captions shown on the founder screen (and the script for the real video). */
export const founderLines = [
  { t: 0, text: "こんにちは！ Hi, I'm the person who built Kizuki." },
  { t: 4, text: "I started Japanese the usual way — textbooks and drill apps." },
  { t: 9, text: "I could order a coffee… but I couldn't follow a single real conversation." },
  { t: 15, text: "What finally worked was listening. A lot. Anime, vlogs, dramas, street interviews." },
  { t: 22, text: "Pausing on every word I didn't know, looking it up, and hearing it again." },
  { t: 28, text: "Kizuki does all of that for you, in short clips that actually feel fun." },
  { t: 34, text: "Watch a clip, tap a word, review it later with the real audio. That's it." },
  { t: 40, text: "If you have feedback or just want to say hi, message me anytime." },
  { t: 45, text: "がんばろう！ Let's do this together." },
];
export const FOUNDER_SECONDS = 50;
