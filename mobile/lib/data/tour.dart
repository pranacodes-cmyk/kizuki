// Welcome tour — mirrored from src/lib/tour.ts. An interactive walk through the whole
// loop (watch → tap a word → explanation → swipe → Explore → Vocab → first review).
// Shown the first time the feed opens, and again after Settings → Replay the welcome tour.

/// Things the learner does that move an "action" step forward (TourEvent in tour.ts).
enum TourEvent { word, explain, cardClosed, swipe, reveal, graded }

class TourStep {
  final String id;

  /// Routes the step shows on. Empty = any route.
  final List<String> screens;

  /// Spotlight target (a TourAnchor id), or null for a centered card.
  final String? target;
  final String text;

  /// Mascot pose name.
  final String pose;

  /// tap = Next (or tap anywhere) · action = do the highlighted thing · legend = underline key ·
  /// controls = what each player button does · finish = last card.
  final String kind;

  /// Action steps: the event that completes the step…
  final TourEvent? until;

  /// …or the route that completes it.
  final String? untilRoute;

  /// Animated hand: tap | swipe.
  final String? hand;

  /// The whole screen stays usable (no blocking layer), e.g. swiping the feed or closing the card.
  final bool passThrough;

  /// What to do, shown under action steps.
  final String? hint;

  /// If the target never appears, "Next" jumps here (later steps depend on this one).
  final String? skipTo;

  /// Pin the tip to the top (above a bottom sheet) or bottom of the screen: 'top' | 'bottom'.
  final String? place;

  /// Spotlight the whole target, even when it's taller than [tourMaxHoleHeight].
  final bool fullHole;

  /// Where the tap hand's fingertip sits on the target (0 top … 1 bottom); default [tourHandTipY].
  final double? handY;
  const TourStep(this.id, this.screens, this.target, this.text, this.pose,
      {this.kind = 'tap', this.until, this.untilRoute, this.hand, this.passThrough = false, this.hint, this.skipTo, this.place, this.fullHole = false, this.handY});
}

const tourSteps = [
  TourStep('hello', ['/feed'], null, 'Hi{name}! Let me show you how Kizuki works. It takes about a minute.', 'wave'),
  TourStep('clip', ['/feed'], 'player', 'Every clip is a short scene from a real Japanese video. It repeats, so you can hear it again and again.', 'listen'),
  TourStep('subs', ['/feed'], 'transcript', 'The subtitles follow along. The word being said gets a green box.', 'read'),
  TourStep('tapWord', ['/feed'], 'word', 'Tap this word to see what it means.', 'think',
      kind: 'action', until: TourEvent.word, hand: 'tap', hint: 'Tap the highlighted word', skipTo: 'legend'),
  TourStep('meaning', ['/feed'], 'cardExplain', "That's the meaning. Now tap Explain to see why it's used in this sentence.", 'read',
      kind: 'action', until: TourEvent.explain, hand: 'tap', hint: 'Tap Explain', skipTo: 'legend', place: 'top'),
  TourStep('explain', ['/feed'], 'card', "This explains the word in this exact sentence. It's already saved to your Vocab.", 'heart',
      kind: 'action', until: TourEvent.cardClosed, passThrough: true, hint: 'Tap above the card to close it', skipTo: 'legend', place: 'top', fullHole: true),
  TourStep('legend', ['/feed'], null, 'Underlines show what you know.', 'think', kind: 'legend'),
  TourStep('controls', ['/feed'], 'controls', 'These buttons help you listen:', 'think', kind: 'controls'),
  TourStep('swipe', ['/feed'], null, 'Swipe up for the next clip.', 'cheer',
      kind: 'action', until: TourEvent.swipe, hand: 'swipe', passThrough: true, hint: 'Swipe up anywhere'),
  TourStep('explore', ['/feed'], 'exploreTab', 'Tap Explore to find clips by word or topic.', 'think',
      kind: 'action', untilRoute: '/explore', hand: 'tap', hint: 'Tap Explore', skipTo: 'vocabTab'),
  TourStep('search', ['/explore'], 'exploreSearch', "Search any word in Japanese, romaji or English and you'll get clips that use it. Or pick a topic below.", 'read'),
  TourStep('vocabTab', ['/explore', '/feed'], 'vocabTab', 'Now tap Vocab. Every word you tap is saved there.', 'heart',
      kind: 'action', untilRoute: '/vocab', hand: 'tap', hint: 'Tap Vocab', skipTo: 'done'),
  TourStep('review', ['/vocab'], 'reviewButton', 'The word you tapped is already here. Tap to review it.', 'cheer',
      kind: 'action', untilRoute: '/review', hand: 'tap', hint: 'Tap the orange button', skipTo: 'done'),
  TourStep('reveal', ['/review'], 'reviewCard', 'Try to remember what it means, then tap the card to check.', 'think',
      kind: 'action', until: TourEvent.reveal, hand: 'tap', hint: 'Tap anywhere on the card', skipTo: 'done', place: 'bottom', fullHole: true, handY: 0.62),
  TourStep('grade', ['/review'], 'grade', 'Knew it? Tap Good. Forgot? Tap Again.', 'read',
      kind: 'action', until: TourEvent.graded, hint: 'Or swipe the card right or left', skipTo: 'done'),
  TourStep('done', [], null, "That's the whole loop: watch, tap, review. {minutes} minutes a day and you'll surprise yourself!", 'brave', kind: 'finish'),
];

/// Personal bits in the step text.
String tourText(TourStep s, {required String name, required int minutes}) =>
    s.text.replaceAll('{name}', name.trim().isEmpty ? '' : ' ${name.trim()}').replaceAll('{minutes}', '$minutes');

/// Index of a step id (tourSteps.length when missing, which ends the tour).
int tourIndexOf(String id) {
  final i = tourSteps.indexWhere((s) => s.id == id);
  return i < 0 ? tourSteps.length : i;
}

/// Word underline legend — drawn exactly like transcript words (Transcript colours).
const tourLegend = [
  ('new', 'New word', 'Tap it to see what it means'),
  ('learning', 'Learning', 'Saved. The line fades as you learn it'),
  ('known', 'Known', 'No underline, out of your way'),
  ('speaking', 'Being said now', 'The green box follows the audio'),
];

/// What each player button does (the controls step) — same order as the buttons.
const tourControls = [
  ('replay', 'Replay the line'),
  ('loop', 'Loop the line'),
  ('speed', 'Slow it down'),
  ('save', 'Save the clip'),
  ('display', 'Subtitles and text size'),
];

/// Delay before the legend's "Got it" button enables (so it's actually read).
const tourLegendDelayMs = 1500;

/// A step whose target hasn't appeared after this long offers "Next" instead (never stuck).
const tourTargetWaitMs = 2500;

/// Tall targets (the scrolling transcript, the word card) are spotlit only at the top, so the bubble fits.
const double tourMaxHoleHeight = 300;

/// The tap hand's fingertip sits this far down the target (0 = top, 1 = bottom), below the word.
const double tourHandTipY = 0.8;
