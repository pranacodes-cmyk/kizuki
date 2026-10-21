// Topic labels for clip tags — mirrored in mobile/lib/data/topics.dart.
export const TOPICS: Record<string, { label: string; emoji: string }> = {
  anime: { label: "Anime", emoji: "🎌" },
  drama: { label: "Drama", emoji: "🎭" },
  fun: { label: "Fun", emoji: "🎉" },
  comedy: { label: "Comedy", emoji: "😂" },
  work: { label: "Work", emoji: "💼" },
  romance: { label: "Romance", emoji: "❤️" },
  travel: { label: "Travel", emoji: "✈️" },
  food: { label: "Food", emoji: "🍜" },
  culture: { label: "Culture", emoji: "🏯" },
  friends: { label: "Friends", emoji: "👫" },
  family: { label: "Family", emoji: "🏡" },
  animals: { label: "Animals", emoji: "🐾" },
  daily: { label: "Daily life", emoji: "☀️" },
  school: { label: "School", emoji: "🏫" },
  sports: { label: "Sports", emoji: "⚽" },
  music: { label: "Music", emoji: "🎵" },
  kids: { label: "Kids", emoji: "🧸" },
  vlog: { label: "Vlogs", emoji: "📹" },
  learning: { label: "Lessons", emoji: "📖" },
  interview: { label: "Interviews", emoji: "🎤" },
  news: { label: "News", emoji: "📰" },
  games: { label: "Games", emoji: "🎮" },
};

export const topicLabel = (t: string) => TOPICS[t]?.label ?? t.charAt(0).toUpperCase() + t.slice(1);
export const topicEmoji = (t: string) => TOPICS[t]?.emoji ?? "🎬";
