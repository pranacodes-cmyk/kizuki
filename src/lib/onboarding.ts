import founderVideo from "@/assets/videos/founder-v8.mp4.asset.json";
import founderPoster from "@/assets/videos/founder-v8.jpg.asset.json";
import founderWebm from "@/assets/videos/founder-v8.webm.asset.json";

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

/** User's founder story with burned-in captions; fallback uses matching speech. */
export const founderLines = [
  { t: 0.7, text: "Konnichiwa, Kenji here," },
  { t: 2.44, text: "creator of Kizuki." },
  { t: 3.82, text: "Three years ago," },
  { t: 4.44, text: "I failed my" },
  { t: 5.02, text: "first Japanese test." },
  { t: 6.58, text: "So bad, my" },
  { t: 7.3, text: "teacher asked if" },
  { t: 8.04, text: "I was guessing" },
  { t: 8.52, text: "randomly." },
  { t: 10.18, text: "18 months later," },
  { t: 11.42, text: "I passed the" },
  { t: 11.98, text: "N2, and was" },
  { t: 13.62, text: "giving presentations in" },
  { t: 14.6, text: "Tokyo." },
  { t: 15.18, text: "How?" },
  { t: 15.9, text: "Definitely not Duolingo." },
  { t: 17.1, text: "That bird only" },
  { t: 17.62, text: "taught me, the" },
  { t: 18.46, text: "lawyer loves green" },
  { t: 19.18, text: "tea." },
  { t: 20.42, text: "And textbooks?" },
  { t: 22.4, text: "Genki made me" },
  { t: 22.94, text: "want to stare" },
  { t: 23.36, text: "at a blank" },
  { t: 23.76, text: "wall." },
  { t: 24.74, text: "Then it hit" },
  { t: 25.18, text: "me." },
  { t: 25.8, text: "Japanese babies don't" },
  { t: 26.64, text: "study grammar charts." },
  { t: 27.58, text: "They just listen" },
  { t: 28.52, text: "until it clicks." },
  { t: 30.4, text: "That click is" },
  { t: 31.14, text: "what Kizuki means." },
  { t: 32.76, text: "Short, real clips," },
  { t: 34.02, text: "tap whatever you" },
  { t: 34.7, text: "don't get." },
  { t: 35.56, text: "If anything feels" },
  { t: 36.16, text: "off, message me" },
  { t: 37.2, text: "in the app." },
  { t: 37.96, text: "I read every one." },
  { t: 39.5, text: "Ja ne!" },
];
export const FOUNDER_SECONDS = 40.067;
export const FOUNDER_VIDEO_URL = founderVideo.url;
export const FOUNDER_VIDEO_WEBM_URL = founderWebm.url;
export const FOUNDER_POSTER_URL = founderPoster.url;
