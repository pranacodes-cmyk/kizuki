// Welcome tour — mirrored from src/lib/tour.ts. A short "do what I point at" walk through the
// whole loop: tap a word → its meaning + Ask Kizuki → swipe → Vocab → first review → back to
// the videos. Shown the first time the feed opens, and again after Settings → Replay the tour.

/// Things the learner does that move an "action" step forward (TourEvent in tour.ts).
enum TourEvent { word, explain, cardClosed, askOpened, askClosed, swipe, reveal, graded }

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
  /// finish = last card.
  final String kind;

  /// Action steps: the event that completes the step…
  final TourEvent? until;

  /// …or the route that completes it.
  final String? untilRoute;

  /// Animated hand: tap | swipe.
  final String? hand;

  /// The anchor the tap hand points at when it isn't the whole spotlight (e.g. Explain on the
  /// lit word card). Default: the target itself.
  final String? handAt;

  /// The whole screen stays usable (no blocking layer), e.g. swiping the feed.
  final bool passThrough;

  /// What to do, shown under action steps.
  final String? hint;

  /// If the target never appears, "Next" jumps here (later steps depend on this one).
  final String? skipTo;

  /// 'top' = the tip sits above the spotlight (above a bottom sheet), else pinned to the top;
  /// 'bottom' = pinned to the bottom of the screen (over the empty lower part of a tall card).
  final String? place;

  /// Spotlight the whole target, even when it's taller than [tourMaxHoleHeight].
  final bool fullHole;

  /// Where the tap hand's fingertip sits on the target (0 top … 1 bottom); default [tourHandTipY].
  final double? handY;

  /// Button label on tap / finish steps (default "Next" / "Let's go!").
  final String? button;

  /// Moving on closes the open word card and Ask Kizuki for the learner (no "close it yourself").
  final bool closesSheets;

  /// Finish step: where the learner lands after the last button.
  final String? endRoute;

  const TourStep(this.id, this.screens, this.target, this.text, this.pose,
      {this.kind = 'tap',
      this.until,
      this.untilRoute,
      this.hand,
      this.handAt,
      this.passThrough = false,
      this.hint,
      this.skipTo,
      this.place,
      this.fullHole = false,
      this.handY,
      this.button,
      this.closesSheets = false,
      this.endRoute});
}

const tourSteps = [
  TourStep('hello', ['/feed'], null, "Hi{name}! I'll show you how Kizuki works. It takes one minute — just tap what I point at.", 'wave', button: 'Show me'),
  TourStep('controls', ['/feed'], 'controls', 'Slow down, replay or save a clip.', 'listen', kind: 'controls', button: 'Try a word'),
  TourStep('tapWord', ['/feed'], 'word', 'Real Japanese, with subtitles. Tap this word to see what it means.', 'think',
      kind: 'action', until: TourEvent.word, hand: 'tap', hint: 'Tap the highlighted word', skipTo: 'legend'),
  TourStep('meaning', ['/feed'], 'card', "That's what it means. It's saved for you, so you can practice it later.", 'read',
      kind: 'action', until: TourEvent.explain, hand: 'tap', handAt: 'cardExplain', hint: 'Now tap Explain', skipTo: 'legend', place: 'top', fullHole: true),
  TourStep('askOpen', ['/feed'], 'card', 'This explains the word in this exact sentence. Still have a question?', 'think',
      kind: 'action', until: TourEvent.askOpened, hand: 'tap', handAt: 'askButton', hint: 'Tap Ask Kizuki', skipTo: 'legend', place: 'top', fullHole: true),
  TourStep('askInfo', ['/feed'], 'askPanel', 'Here is an example. Your question stays about the word and sentence you just watched.', 'heart',
      button: 'Back to the video', closesSheets: true, place: 'top'),
  TourStep('legend', ['/feed'], null, 'The line under each word tells you:', 'think', kind: 'legend'),
  TourStep('swipe', ['/feed'], 'controls', 'Swipe up for the next clip.', 'cheer',
      kind: 'action', until: TourEvent.swipe, hand: 'swipe', passThrough: true, hint: 'Swipe up anywhere'),
  TourStep('vocabTab', ['/feed', '/explore'], 'vocabTab', 'Every word you tap is saved in Vocab.', 'heart',
      kind: 'action', untilRoute: '/vocab', hand: 'tap', hint: 'Tap Vocab', skipTo: 'done'),
  TourStep('kanaDecks', ['/vocab'], 'kanaDecks', "Japanese ABCs\nHiragana あ and Katakana ア write the same sounds in two ways. Start with Hiragana. Both decks are optional.", 'read', button: 'Got it'),
  TourStep('review', ['/vocab'], 'reviewButton', 'Your new word is waiting here. Let\'s practice it once.', 'cheer',
      kind: 'action', untilRoute: '/review', hand: 'tap', hint: 'Tap the orange button', skipTo: 'done'),
  TourStep('reveal', ['/review'], 'reviewCard', 'Do you remember what it means? Tap the card to check.', 'think',
      kind: 'action', until: TourEvent.reveal, hand: 'tap', hint: 'Tap anywhere on the card', skipTo: 'done', place: 'bottom', fullHole: true, handY: 0.62),
  TourStep('grade', ['/review'], 'grade', 'Remembered it? Tap Remembered. If not, tap Forgot — the word just comes back sooner.', 'read',
      kind: 'action', until: TourEvent.graded, hint: 'Tap one of the two buttons', skipTo: 'done'),
  TourStep('done', [], null, "That's it: watch, tap new words, practice them. {minutes} minutes a day is all you need!", 'brave',
      kind: 'finish', button: 'Back to videos', endRoute: '/feed'),
];

/// Steps that happen on the open word card / Ask Kizuki: closing a card by hand skips the rest.
const tourCardSteps = ['meaning', 'askOpen', 'askInfo'];

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
  ('new', 'Blue line · new word', 'Tap it to see what it means'),
  ('learning', 'Orange line · saved word', "You're learning it"),
  ('known', 'No line · known word', 'You already know it'),
];

/// Delay before the legend's "Got it" button enables (so it's actually read).
const tourLegendDelayMs = 1200;

/// A step whose target hasn't appeared after this long offers "Next" instead (never stuck).
const tourTargetWaitMs = 2500;

/// Tall targets are spotlit only at the top, so the bubble fits (unless the step lights it whole).
const double tourMaxHoleHeight = 300;

/// The tap hand's fingertip sits this far down the target (0 = top, 1 = bottom), below the word.
const double tourHandTipY = 0.8;

/// Estimated tip height used to decide whether it fits above / below a spotlight.
const double tourTipEstHeight = 150;
