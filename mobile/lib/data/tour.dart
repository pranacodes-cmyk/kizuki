// Welcome tour steps — mirrored from src/lib/tour.ts. Shown on the feed the first time
// (and again after Settings → Replay the welcome tour).

class TourStep {
  final String id;
  /// Spotlight target: player | transcript | controls | tabs, or null for a centered card.
  final String? target;
  final String text;
  final String pose; // mascot pose name
  /// normal | legend | swipe
  final String kind;
  const TourStep(this.id, this.target, this.text, this.pose, [this.kind = 'normal']);
}

const tourSteps = [
  TourStep('hello', null, "Let me show you around! It'll only take a minute.", 'wave'),
  TourStep('player', 'player', 'Learn by watching short, fun clips from real Japanese videos.', 'listen'),
  TourStep('words', 'transcript', "Subtitles light up as people speak. Tap any word to see its meaning — and why it's used in this sentence.", 'read'),
  TourStep('legend', null, 'Underlines show what you know.', 'think', 'legend'),
  TourStep('controls', 'controls', 'Replay a line, loop it, slow it down, or change what you see with Aa.', 'think'),
  TourStep('swipe', null, 'Swipe up for the next clip.', 'cheer', 'swipe'),
  TourStep('vocab', 'tabs', 'Words you tap are saved in Vocab. Review them each day with the original audio.', 'heart'),
];

/// Word underline legend (Transcript colours).
const tourLegend = [
  ('new', 'New word', 'Tap it to look it up'),
  ('learning', 'Learning', 'Saved — in your reviews'),
  ('known', 'Known', 'No underline, out of your way'),
];

/// Delay before the legend's "Got it" button enables (so it's actually read).
const tourLegendDelayMs = 1500;

/// Tall targets (the scrolling transcript) are spotlit only at the top, so the bubble fits.
const double tourMaxHoleHeight = 300;
