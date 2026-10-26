// Business rules for Kizuki. Kept 1:1 with src/lib/logic.ts (mirrored tests in
// test/logic_test.dart and src/lib/logic.test.ts). UI code calls these helpers
// instead of re-deriving rules.

import 'dart:math' as math;

import '../data/models.dart';

// ---------------------------------------------------------------------------
// Onboarding answers
// ---------------------------------------------------------------------------

const reasons = ['travel', 'anime', 'work', 'fun', 'friends', 'family', 'romance', 'culture'];
const challenges = ['listening', 'start', 'motivation', 'grammar', 'speaking', 'vocab'];
const studyWindows = ['morning', 'afternoon', 'evening', 'night'];
const streakGoals = [7, 14, 30, 50];
const jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];

List<String> signInProviders(String platform) => platform == 'android' ? const ['google'] : const ['google', 'apple'];
bool founderVideoEnabled(Object? remote, [bool cached = true]) => remote is bool ? remote : cached;

/// Server-sent founder video override: only a clean https link counts; anything else keeps
/// the bundled clip.
String? founderVideoUrl(Object? remote) {
  if (remote is! String) return null;
  final u = remote.trim();
  return u.startsWith('https://') && u.length > 8 ? u : null;
}
String onboardingAfterPlan(bool enabled) => enabled ? '/founder' : '/trial';

/// Remote native sign-in switch: off until the backend accepts this app's own provider
/// tokens; a missing/invalid value keeps the last valid one.
bool nativeSignInEnabled(Object? remote, [bool cached = false]) => remote is bool ? remote : cached;

/// Server-sent trial experiment: `false` (or 0 days) = direct paywall with no trial wording;
/// a plausible day count (1–14) replaces the shipped default; anything missing/invalid keeps
/// the last valid value.
const defaultTrialDays = 7;
int trialDays(Object? remoteEnabled, Object? remoteDays, [int cached = defaultTrialDays]) {
  final days = remoteDays is int ? remoteDays : cached;
  if (remoteEnabled == false || days <= 0) return 0;
  return days <= 14 ? days : cached;
}

/// Phone sign-in never substitutes a browser for the requested native account sheet.
String signInMethod(String provider) =>
    provider == 'google' || provider == 'apple' ? 'native' : 'unavailable';

/// Learner progress on a device belongs to the account it last synced with (`owner`).
/// Progress made before any sign-in (no owner) joins the first account; signing into a
/// different account starts from a clean learner document that keeps only device-level
/// values, so one learner's words, history and profile never merge into another account.
Map<String, dynamic> localStateFor(Map<String, dynamic> local, String userId) {
  final owner = local['owner'];
  if (owner == null || owner == userId) return {...local, 'owner': userId};
  return {
    'version': local['version'] ?? 1,
    'onboarded': local['onboarded'] == true,
    'purchaseAccountPending': local['purchaseAccountPending'] == true,
    'premium': local['premium'],
    'settings': local['settings'],
    'feedSeed': local['feedSeed'],
    'owner': userId,
    'updatedAt': 0,
  };
}

/// Self-reported level (0..4) → JLPT band used for content.
String levelToJlpt(int level) => const ['N5', 'N5', 'N4', 'N3', 'N2'][level.clamp(0, 4)];

/// JLPT band → index (N5 = 0 … N1 = 4).
int jlptIndex(String jlpt) {
  final i = jlptLevels.indexOf(jlpt);
  return i < 0 ? 0 : i;
}

/// Words a learner meets per month at a daily study time.
int wordsPerMonth(int minutes) => (minutes * 20.4).round();

/// Daily minutes recommended for a fluency goal (months), rounded to 5, 5..60.
int recommendedMinutes(int months) {
  final raw = 225 / math.max(1, months);
  final rounded = (raw / 5).round() * 5;
  return rounded.clamp(5, 60);
}

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Oct 2027" — the month the fluency goal lands on.
String goalDateLabel(DateTime now, int months) {
  final total = now.month - 1 + months;
  final year = now.year + total ~/ 12;
  return '${_monthNames[total % 12]} $year';
}

/// Window → reminder hour (local time).
int windowHour(String window) {
  switch (window) {
    case 'morning':
      return 8;
    case 'afternoon':
      return 13;
    case 'evening':
      return 19;
    default:
      return 22;
  }
}

String windowLabel(String window) {
  switch (window) {
    case 'morning':
      return 'in the morning';
    case 'afternoon':
      return 'in the afternoon';
    case 'evening':
      return 'in the evening';
    default:
      return 'at night';
  }
}

String challengeBenefit(String challenge) {
  switch (challenge) {
    case 'listening':
      return 'Real Japanese at natural speed, with every word subtitled';
    case 'start':
      return 'A simple daily path — watch, save words, review';
    case 'motivation':
      return 'Short, fun clips that keep you coming back';
    case 'grammar':
      return 'Every word explained in the sentence you heard';
    case 'speaking':
      return 'Hear how natives really talk, so you sound natural too';
    default:
      return 'Words stick because you learn them in a real scene';
  }
}

/// Onboarding reason → content topics it unlocks.
List<String> reasonTopics(String reason) {
  switch (reason) {
    case 'travel':
      return const ['travel', 'food', 'culture'];
    case 'anime':
      return const ['anime'];
    case 'work':
      return const ['work'];
    case 'fun':
      return const ['fun', 'comedy', 'animals'];
    case 'friends':
      return const ['friends', 'daily'];
    case 'family':
      return const ['family', 'daily'];
    case 'romance':
      return const ['romance'];
    default:
      return const ['culture', 'food', 'travel'];
  }
}

class PlanItem {
  final String icon;
  final String title;
  final String body;
  const PlanItem(this.icon, this.title, this.body);
}

PlanItem _reasonItem(String reason) {
  switch (reason) {
    case 'travel':
      return const PlanItem('🌍', 'Travel with confidence', 'Real Japanese from trains, shops and restaurants');
    case 'anime':
      return const PlanItem('🎌', 'Understand anime without subtitles', 'Scenes from real shows, explained word by word');
    case 'work':
      return const PlanItem('💼', 'Japanese for work', 'Polite speech and office talk from real dramas');
    case 'fun':
      return const PlanItem('🎉', 'Learning that feels like scrolling', 'Funny, cute and surprising clips — no textbook');
    case 'friends':
      return const PlanItem('👫', 'Chat naturally with friends', 'Casual Japanese the way friends really talk');
    case 'family':
      return const PlanItem('🏡', 'Talk with family', 'Warm, everyday Japanese from home life');
    case 'romance':
      return const PlanItem('❤️', 'Love, in Japanese', 'Feelings and sweet talk from romance dramas');
    default:
      return const PlanItem('🏯', 'Live the culture', 'Food, festivals and daily life in Japan');
  }
}

PlanItem _challengeItem(String challenge, int streakGoal, String window) {
  switch (challenge) {
    case 'listening':
      return const PlanItem('👂', 'Train your ear', 'Natural-speed Japanese with word-by-word subtitles');
    case 'start':
      return const PlanItem('🧭', 'A clear daily path', 'Watch → save words → review. That\'s it.');
    case 'motivation':
      return PlanItem('🔥', 'A $streakGoal-day streak goal', 'Friendly reminders ${windowLabel(window)}');
    case 'grammar':
      return const PlanItem('🧩', 'Grammar in context', 'Every word explained in the sentence you heard');
    case 'speaking':
      return const PlanItem('🗣️', 'Sound like a native', 'Copy real rhythm and intonation, line by line');
    default:
      return const PlanItem('📚', 'Words that stick', 'Smart reviews with the original clip audio');
  }
}

/// The "Your plan is ready" list — every line reflects an answer.
List<PlanItem> planItems({
  required List<String> reasonList,
  required List<String> challengeList,
  required int dailyMinutes,
  required String window,
  required int streakGoal,
  required String jlpt,
  required int clipCount,
}) {
  final items = <PlanItem>[
    PlanItem('⏰', '$dailyMinutes-minute daily sessions', 'Bite-sized clips ${windowLabel(window)}'),
  ];
  items.add(_reasonItem(reasonList.isEmpty ? 'fun' : reasonList.first));
  items.add(_challengeItem(challengeList.isEmpty ? 'listening' : challengeList.first, streakGoal, window));
  items.add(PlanItem('📈', '${wordsPerMonth(dailyMinutes)} new words a month', 'At $dailyMinutes minutes a day'));
  items.add(PlanItem('🎬', '$clipCount clips picked for you', 'Matched to your level ($jlpt) and interests'));
  return items;
}

// ---------------------------------------------------------------------------
// Deterministic hashing (identical in TS: Math.imul FNV-1a over UTF-16 units)
// ---------------------------------------------------------------------------

int fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

// ---------------------------------------------------------------------------
// Feed ranking
// ---------------------------------------------------------------------------

class RankClip {
  final String id;
  final String videoId;
  final String level;
  final List<String> topics;
  final int quality;

  /// Still-picture video (podcast): ranked well below real video, so it never opens the feed.
  final bool still;
  const RankClip({required this.id, required this.videoId, required this.level, required this.topics, required this.quality, this.still = false});
}

/// Score taken off a still-picture clip (more than the whole random jitter range).
const stillClipPenalty = 6.0;

/// The curated starter clips lead the feed until the learner has watched this many clips.
const starterWatchLimit = 60;
/// Only yearly simulation has a trial; native dates always come from the store.
int? simulatedTrialEnd(String plan, int now) => plan == 'yearly' ? now + 7 * dayMs : null;
/// Expired trials/subscriptions never fall back to free learning.
bool subscriptionAccess(bool active, int? expiresAt, int? trialEndsAt, int now) {
  final end = expiresAt ?? trialEndsAt;
  return active && (end == null || end > now);
}
bool learningPath(String path) => !['/account', '/settings', '/support', '/terms', '/privacy', '/trial', '/profile', '/achievements'].contains(path);
bool onboardingPath(String path) => ['/', '/onboarding', '/building', '/plan', '/founder'].contains(path);
bool accountNeedsOnboarding(bool fromWelcome, bool onboarded, bool premiumAccess) => fromWelcome && !onboarded && !premiumAccess;
String subscriptionPhase(bool active, String? plan, int? trialEndsAt, int now) =>
    !active ? 'free' : plan == 'yearly' && trialEndsAt != null && trialEndsAt > now ? 'trial' : 'active';
/// YouTube reports zero until metadata arrives; allow only end-padding tolerance.
bool clipWindowAvailable(double start, double end, double duration) =>
    duration <= 0 || (start < duration && end <= duration + 0.75);
/// A curated starter clip: id + JLPT level.
typedef StarterClip = ({String id, String level});

/// Everyone's first clips: the curated starter list in its order (only clips that exist and are
/// not watched yet), then the personal ranking without them. Learners above N3 skip starters more
/// than two levels easier than theirs (jlpt null = the onboarding preview: same for everyone).
/// After [starterWatchLimit] watched clips the feed is fully personal.
List<String> starterFeedOrder(List<String> personalized, List<StarterClip> starter, {Map<String, int> seen = const {}, int watched = 0, String? jlpt}) {
  if (watched >= starterWatchLimit) return personalized;
  final available = personalized.toSet();
  final lead = <String>[];
  for (final s in starter) {
    if (!available.contains(s.id) || (seen[s.id] ?? 0) > 0 || lead.contains(s.id)) continue;
    if (jlpt != null && jlptIndex(s.level) - jlptIndex(jlpt) < -2) continue;
    lead.add(s.id);
  }
  if (lead.isEmpty) return personalized;
  final taken = lead.toSet();
  return [...lead, ...personalized.where((id) => !taken.contains(id))];
}

double clipScore(RankClip clip, {required List<String> reasonList, required String jlpt, required Map<String, int> seen, required String seed}) {
  final wanted = <String, int>{};
  for (final r in reasonList) {
    for (final t in reasonTopics(r)) {
      wanted[t] = (wanted[t] ?? 0) + 1;
    }
  }
  var topic = 0.0;
  for (final t in clip.topics) {
    if (wanted.containsKey(t)) topic += 3;
  }
  topic = math.min(topic, 6);
  final d = jlptIndex(clip.level) - jlptIndex(jlpt);
  final level = d == 0
      ? 4.0
      : d == -1
          ? 3.0
          : d == 1
              ? 2.0
              : d <= -2
                  ? 1.0
                  : -2.0;
  final quality = (clip.quality - 3) * 1.5;
  final seenPenalty = (seen[clip.id] ?? 0) * 8.0;
  final jitter = (fnv1a('$seed:${clip.id}') % 1000) / 1000 * 2.5;
  final still = clip.still ? stillClipPenalty : 0.0;
  return topic + level + quality - seenPenalty - still + jitter;
}

/// Ordered clip ids for the For You feed. Same video never plays twice in a row
/// when another choice exists within the next 5.
List<String> rankFeed(List<RankClip> clips, {required List<String> reasonList, required String jlpt, required Map<String, int> seen, required String seed}) {
  final scored = clips
      .map((c) => MapEntry(c, clipScore(c, reasonList: reasonList, jlpt: jlpt, seen: seen, seed: seed)))
      .toList()
    ..sort((a, b) {
      final s = b.value.compareTo(a.value);
      return s != 0 ? s : a.key.id.compareTo(b.key.id);
    });
  final pool = scored.map((e) => e.key).toList();
  final out = <RankClip>[];
  while (pool.isNotEmpty) {
    var pick = 0;
    if (out.isNotEmpty) {
      for (var i = 0; i < math.min(5, pool.length); i++) {
        if (pool[i].videoId != out.last.videoId) {
          pick = i;
          break;
        }
      }
    }
    out.add(pool.removeAt(pick));
  }
  return out.map((c) => c.id).toList();
}

// ---------------------------------------------------------------------------
// Spaced repetition (two buttons: Again / Good)
// ---------------------------------------------------------------------------

const minuteMs = 60 * 1000;
const dayMs = 24 * 60 * minuteMs;
const knownIntervalDays = 21;

class Card {
  final String state; // new | learning | review | relearning
  final int step;
  final double interval; // days
  final double ease;
  final int due; // epoch ms
  final int reps;
  final int lapses;
  const Card({this.state = 'new', this.step = 0, this.interval = 0, this.ease = 2.5, required this.due, this.reps = 0, this.lapses = 0});

  Card copyWith({String? state, int? step, double? interval, double? ease, int? due, int? reps, int? lapses}) => Card(
        state: state ?? this.state,
        step: step ?? this.step,
        interval: interval ?? this.interval,
        ease: ease ?? this.ease,
        due: due ?? this.due,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
      );

  Map<String, dynamic> toJson() => {'state': state, 'step': step, 'interval': interval, 'ease': ease, 'due': due, 'reps': reps, 'lapses': lapses};

  factory Card.fromJson(Map<String, dynamic> j) => Card(
        state: j['state'] as String? ?? 'new',
        step: (j['step'] as num? ?? 0).toInt(),
        interval: (j['interval'] as num? ?? 0).toDouble(),
        ease: (j['ease'] as num? ?? 2.5).toDouble(),
        due: (j['due'] as num? ?? 0).toInt(),
        reps: (j['reps'] as num? ?? 0).toInt(),
        lapses: (j['lapses'] as num? ?? 0).toInt(),
      );
}

Card newCard(int now) => Card(due: now);

/// Apply an answer. Again → back in 1 minute. Good: new → 10 minutes,
/// learning → 1 day, review → interval × ease, relearning → half interval.
Card answerCard(Card c, String grade, int now) {
  if (grade == 'again') {
    final wasReview = c.state == 'review';
    return c.copyWith(
      state: wasReview || c.state == 'relearning' ? 'relearning' : 'learning',
      step: 0,
      due: now + minuteMs,
      ease: wasReview ? math.max(1.3, c.ease - 0.2) : c.ease,
      lapses: wasReview ? c.lapses + 1 : c.lapses,
      reps: c.reps + 1,
    );
  }
  switch (c.state) {
    case 'new':
      return c.copyWith(state: 'learning', step: 1, due: now + 10 * minuteMs, reps: c.reps + 1);
    case 'learning':
      return c.copyWith(state: 'review', step: 0, interval: 1, due: now + dayMs, reps: c.reps + 1);
    case 'relearning':
      final iv = math.max(1.0, (c.interval * 0.5).roundToDouble());
      return c.copyWith(state: 'review', step: 0, interval: iv, due: now + (iv * dayMs).round(), reps: c.reps + 1);
    default:
      final iv = math.max(c.interval + 1, (c.interval * c.ease).roundToDouble());
      return c.copyWith(interval: iv, due: now + (iv * dayMs).round(), reps: c.reps + 1);
  }
}

/// Compact label for how long until a card returns ("<1m", "10m", "3d", "2mo").
String formatInterval(int ms) {
  if (ms < minuteMs) return '<1m';
  if (ms < 60 * minuteMs) return '${(ms / minuteMs).round()}m';
  if (ms < dayMs) return '${(ms / (60 * minuteMs)).round()}h';
  final days = ms / dayMs;
  if (days < 30) return '${days.round()}d';
  if (days < 365) return '${(days / 30).round()}mo';
  return '${(days / 365).toStringAsFixed(1)}y';
}

/// Plain-English time until the next practice ("now", "in 10 minutes", "tomorrow", "in 3 days")
/// for learner-facing text — mirrors formatWhen in logic.ts.
String formatWhen(int ms) {
  String n(int v, String unit) => 'in $v $unit${v == 1 ? '' : 's'}';
  if (ms <= 0) return 'now';
  if (ms < minuteMs) return 'in under a minute';
  if (ms < 60 * minuteMs) return n((ms / minuteMs).round().clamp(1, 59), 'minute');
  if (ms < dayMs) {
    final h = (ms / (60 * minuteMs)).round();
    return h >= 24 ? 'tomorrow' : n(h, 'hour');
  }
  final days = ms / dayMs;
  if (days < 1.5) return 'tomorrow';
  if (days < 30) return n(days.round(), 'day');
  if (days < 365) return n((days / 30).round(), 'month');
  return n((days / 365).round(), 'year');
}

String nextIntervalLabel(Card c, String grade, int now) => grade == 'again' ? '1m' : formatInterval(answerCard(c, grade, now).due - now);

bool isDue(Card c, int now) => c.due <= now;

/// Learner-facing status. Saved words move from learning → known automatically.
String wordStatus({required String status, required Card card}) {
  if (status == 'ignored') return 'ignored';
  if (status == 'known') return 'known';
  if (card.state == 'review' && card.interval >= knownIntervalDays) return 'known';
  return 'learning';
}

// ---------------------------------------------------------------------------
// Word levels (Kiku-style familiarity badge): 1 New → 2 Recognized → 3 Familiar →
// 4 Almost known → 5 Known; 0 = ignored. They rise by themselves as reviews space out,
// and the learner can pick one, which reschedules the card to match.
// ---------------------------------------------------------------------------

/// A review interval of this many days or more counts as "Almost known" (level 4).
const almostKnownDays = 7;

class WordLevelInfo {
  final int level;
  final String label, hint;
  const WordLevelInfo(this.level, this.label, this.hint);
}

/// Menu order: learning levels, Known, then Ignored (mirrors WORD_LEVELS in logic.ts).
const wordLevels = [
  WordLevelInfo(1, 'New', 'Just saved. Reviews start now'),
  WordLevelInfo(2, 'Recognized', 'Starting to stick'),
  WordLevelInfo(3, 'Familiar', 'You remember it for days'),
  WordLevelInfo(4, 'Almost known', 'You remember it for a week or more'),
  WordLevelInfo(5, 'Known', 'No more reviews, no underline'),
  WordLevelInfo(0, 'Ignored', 'Never underlined or reviewed'),
];

WordLevelInfo wordLevelInfo(int level) => wordLevels.firstWhere((l) => l.level == level, orElse: () => wordLevels.first);

/// The level a saved word is at now.
int wordLevel({required String status, required Card card}) {
  if (status == 'ignored' || status == 'removed') return 0;
  if (wordStatus(status: status, card: card) == 'known') return 5;
  if (card.state == 'new') return 1;
  if (card.state != 'review') return 2;
  return card.interval >= almostKnownDays ? 4 : 3;
}

/// Reschedule a card for a learning level the learner picked: 1 = review now,
/// 2 = in 10 minutes, 3 = in 3 days, 4 = in 10 days. Ease, reps and lapses are kept.
Card cardAtLevel(Card c, int level, int now) {
  switch (level) {
    case 1:
      return c.copyWith(state: 'new', step: 0, interval: 0, due: now);
    case 2:
      return c.copyWith(state: 'learning', step: 1, interval: 0, due: now + 10 * minuteMs);
    case 3:
      return c.copyWith(state: 'review', step: 0, interval: 3, due: now + 3 * dayMs);
    default:
      return c.copyWith(state: 'review', step: 0, interval: 10, due: now + 10 * dayMs);
  }
}

/// Parts of speech worth teaching first: the welcome tour asks you to tap one of these.
const tourWordPos = ['noun', 'verb', 'adj', 'i-adj', 'na-adj', 'adverb'];

/// The word the welcome tour asks you to tap, from line [from] on: the first new content word
/// with a dictionary entry (never a filler like ん or a particle), else the first new word,
/// else any word. Looks at one line at a time so the target stays near what's playing.
(int, int)? pickTourWord(List<List<({String p, String? d})>> lines, int from, bool Function(int line, int idx) isNew) {
  for (var li = from < 0 ? 0 : from; li < lines.length; li++) {
    (int, int)? firstNew;
    (int, int)? any;
    final words = lines[li];
    for (var wi = 0; wi < words.length; wi++) {
      final w = words[wi];
      if (w.p == 'punct') continue;
      any ??= (li, wi);
      if (!isNew(li, wi)) continue;
      if (w.d != null && tourWordPos.contains(w.p)) return (li, wi);
      firstNew ??= (li, wi);
    }
    if (firstNew != null) return firstNew;
    if (any != null) return any;
  }
  return null;
}

/// True when an in-clip meaning only repeats the dictionary's first sense ("every day" vs
/// "every day; daily"), so a card shows the meaning once. Empty meanings count as repeats.
bool repeatsSense(String gloss, String? sense) {
  String norm(String x) => x
      .toLowerCase()
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r"[^a-z0-9' ]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final g = norm(gloss);
  if (g.isEmpty) return true;
  if (sense == null) return false;
  return norm(sense) == g || sense.split(RegExp(r'[;,]')).any((p) => norm(p) == g);
}

/// Status + card after the learner picks a level. Picking the level a learning word is
/// already at keeps its schedule.
({String status, Card card}) withWordLevel(String status, Card card, int level, int now) {
  if (level <= 0) return (status: 'ignored', card: card);
  if (level >= 5) return (status: 'known', card: card);
  if (status == 'learning' && wordLevel(status: status, card: card) == level) return (status: 'learning', card: card);
  return (status: 'learning', card: cardAtLevel(card, level, now));
}

/// In-session queue: a card leaves only once it graduates or passes review.
class ReviewSession {
  final List<String> queue;
  int answered = 0;
  ReviewSession(List<String> ids) : queue = List.of(ids);

  String? get current => queue.isEmpty ? null : queue.first;
  bool get done => queue.isEmpty;

  /// Returns the updated card; requeues it at the end while still learning.
  Card answer(Card card, String grade, int now) {
    final id = queue.removeAt(0);
    answered++;
    final next = answerCard(card, grade, now);
    if (next.state == 'learning' || next.state == 'relearning') queue.add(id);
    return next;
  }
}

// ---------------------------------------------------------------------------
// Days, streaks, goals
// ---------------------------------------------------------------------------

String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

class DayActivity {
  final int sec;
  final int clips;
  final int reviews;
  final int words;
  const DayActivity({this.sec = 0, this.clips = 0, this.reviews = 0, this.words = 0});
  bool get active => sec >= 60 || clips > 0 || reviews > 0;
  DayActivity add({int sec = 0, int clips = 0, int reviews = 0, int words = 0}) =>
      DayActivity(sec: this.sec + sec, clips: this.clips + clips, reviews: this.reviews + reviews, words: this.words + words);
  Map<String, dynamic> toJson() => {'sec': sec, 'clips': clips, 'reviews': reviews, 'words': words};
  factory DayActivity.fromJson(Map<String, dynamic> j) => DayActivity(
        sec: (j['sec'] as num? ?? 0).toInt(),
        clips: (j['clips'] as num? ?? 0).toInt(),
        reviews: (j['reviews'] as num? ?? 0).toInt(),
        words: (j['words'] as num? ?? 0).toInt(),
      );
}

/// Consecutive active days ending today (or yesterday while today is still open).
int currentStreak(Map<String, DayActivity> activity, DateTime today) {
  var d = DateTime(today.year, today.month, today.day);
  if (!(activity[dayKey(d)]?.active ?? false)) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (activity[dayKey(d)]?.active ?? false) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

int bestStreak(Map<String, DayActivity> activity) {
  final keys = activity.entries.where((e) => e.value.active).map((e) => e.key).toList()..sort();
  var best = 0, run = 0;
  DateTime? prev;
  for (final k in keys) {
    final d = parseDayKey(k);
    run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d ? run + 1 : 1;
    best = math.max(best, run);
    prev = d;
  }
  return best;
}

/// Minutes left in today's goal (rounded up, never negative).
int minutesLeft(int goalMinutes, int secondsToday) => math.max(0, ((goalMinutes * 60 - secondsToday) / 60).ceil());

/// 0..1 progress toward today's goal.
double goalProgress(int goalMinutes, int secondsToday) => goalMinutes <= 0 ? 1 : math.min(1, secondsToday / (goalMinutes * 60));

/// Heatmap intensity 0..4 for a day.
int heatLevel(int sec, int goalMinutes) {
  if (sec <= 0) return 0;
  final r = sec / math.max(60, goalMinutes * 60);
  if (r < 0.25) return 1;
  if (r < 0.6) return 2;
  if (r < 1) return 3;
  return 4;
}

/// Day keys for a Monday-first heatmap of [weeks] columns ending this week.
List<List<String>> heatmapWeeks(DateTime today, int weeks) {
  final t = DateTime(today.year, today.month, today.day);
  final monday = DateTime(t.year, t.month, t.day - (t.weekday - 1));
  final start = DateTime(monday.year, monday.month, monday.day - 7 * (weeks - 1));
  return List.generate(weeks, (w) => List.generate(7, (d) => dayKey(DateTime(start.year, start.month, start.day + w * 7 + d))));
}

// ---------------------------------------------------------------------------
// Achievements
// ---------------------------------------------------------------------------

class Stats {
  final int clips;
  final int seconds;
  final int words;
  final int known;
  final int reviews;
  final int streak;
  const Stats({this.clips = 0, this.seconds = 0, this.words = 0, this.known = 0, this.reviews = 0, this.streak = 0});
}

class Achievement {
  final String id;
  final String icon;
  final String title;
  final String desc;
  final String metric; // clips | minutes | words | known | reviews | streak
  final int goal;
  const Achievement(this.id, this.icon, this.title, this.desc, this.metric, this.goal);
}

const achievements = [
  Achievement('first-clip', '🎧', 'First Listen', 'Watch your first clip', 'clips', 1),
  Achievement('clips-10', '🎬', 'Ten Clips', 'Watch 10 clips', 'clips', 10),
  Achievement('words-10', '🔖', 'Word Collector', 'Save 10 words', 'words', 10),
  Achievement('review-1', '🔁', 'First Review', 'Answer your first flashcard', 'reviews', 1),
  Achievement('streak-3', '🔥', 'On a Roll', 'Reach a 3-day streak', 'streak', 3),
  Achievement('time-30', '⏱️', 'Half Hour Hero', 'Study for 30 minutes', 'minutes', 30),
  Achievement('clips-50', '🍿', 'Binge Learner', 'Watch 50 clips', 'clips', 50),
  Achievement('streak-7', '📅', 'One Week Strong', 'Reach a 7-day streak', 'streak', 7),
  Achievement('words-50', '📚', 'Word Hoarder', 'Save 50 words', 'words', 50),
  Achievement('time-60', '⚡', 'Hour of Power', 'Study for 60 minutes', 'minutes', 60),
  Achievement('known-25', '🌱', 'Getting Fluent', 'Know 25 words', 'known', 25),
  Achievement('streak-30', '🏆', 'Unstoppable', 'Reach a 30-day streak', 'streak', 30),
];

int metricValue(Stats s, String metric) {
  switch (metric) {
    case 'clips':
      return s.clips;
    case 'minutes':
      return s.seconds ~/ 60;
    case 'words':
      return s.words;
    case 'known':
      return s.known;
    case 'reviews':
      return s.reviews;
    default:
      return s.streak;
  }
}

bool isUnlocked(Achievement a, Stats s) => metricValue(s, a.metric) >= a.goal;

/// Achievements newly unlocked compared to the already-celebrated ids.
List<Achievement> newlyUnlocked(Stats s, List<String> seen) => achievements.where((a) => isUnlocked(a, s) && !seen.contains(a.id)).toList();

// ---------------------------------------------------------------------------
// Search
// ---------------------------------------------------------------------------

/// Lower-case, katakana → hiragana, strip spaces — so "Neko", "ネコ", "ねこ" all match.
String normalizeQuery(String s) {
  final b = StringBuffer();
  for (final c in s.toLowerCase().runes) {
    if (c >= 0x30a1 && c <= 0x30f6) {
      b.writeCharCode(c - 0x60);
    } else if (c != 0x20 && c != 0x3000) {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}

// ---------------------------------------------------------------------------
// Kana decks
// ---------------------------------------------------------------------------

const hiraganaRows = [
  ['あ', 'a'], ['い', 'i'], ['う', 'u'], ['え', 'e'], ['お', 'o'],
  ['か', 'ka'], ['き', 'ki'], ['く', 'ku'], ['け', 'ke'], ['こ', 'ko'],
  ['さ', 'sa'], ['し', 'shi'], ['す', 'su'], ['せ', 'se'], ['そ', 'so'],
  ['た', 'ta'], ['ち', 'chi'], ['つ', 'tsu'], ['て', 'te'], ['と', 'to'],
  ['な', 'na'], ['に', 'ni'], ['ぬ', 'nu'], ['ね', 'ne'], ['の', 'no'],
  ['は', 'ha'], ['ひ', 'hi'], ['ふ', 'fu'], ['へ', 'he'], ['ほ', 'ho'],
  ['ま', 'ma'], ['み', 'mi'], ['む', 'mu'], ['め', 'me'], ['も', 'mo'],
  ['や', 'ya'], ['ゆ', 'yu'], ['よ', 'yo'],
  ['ら', 'ra'], ['り', 'ri'], ['る', 'ru'], ['れ', 're'], ['ろ', 'ro'],
  ['わ', 'wa'], ['を', 'wo'], ['ん', 'n'],
  ['が', 'ga'], ['ぎ', 'gi'], ['ぐ', 'gu'], ['げ', 'ge'], ['ご', 'go'],
  ['ざ', 'za'], ['じ', 'ji'], ['ず', 'zu'], ['ぜ', 'ze'], ['ぞ', 'zo'],
  ['だ', 'da'], ['ぢ', 'ji'], ['づ', 'zu'], ['で', 'de'], ['ど', 'do'],
  ['ば', 'ba'], ['び', 'bi'], ['ぶ', 'bu'], ['べ', 'be'], ['ぼ', 'bo'],
  ['ぱ', 'pa'], ['ぴ', 'pi'], ['ぷ', 'pu'], ['ぺ', 'pe'], ['ぽ', 'po'],
];

/// Hiragana → katakana for the katakana deck.
String toKatakana(String s) => String.fromCharCodes(s.runes.map((c) => c >= 0x3041 && c <= 0x3096 ? c + 0x60 : c));

class KanaCard {
  final String id;
  final String kana;
  final String romaji;
  const KanaCard(this.id, this.kana, this.romaji);
}

List<KanaCard> kanaDeck(String deck) => [
      for (final r in hiraganaRows)
        deck == 'katakana' ? KanaCard('k:${toKatakana(r[0])}', toKatakana(r[0]), r[1]) : KanaCard('h:${r[0]}', r[0], r[1]),
    ];

// ---------------------------------------------------------------------------
// Cloud sync merge
// ---------------------------------------------------------------------------

/// Merge two keyed maps of records that carry an `updatedAt` (ms). Newer wins;
/// ties keep the local copy. Used for saved words when syncing devices.
Map<String, Map<String, dynamic>> mergeByUpdatedAt(Map<String, Map<String, dynamic>> local, Map<String, Map<String, dynamic>> remote) {
  final out = <String, Map<String, dynamic>>{...local};
  remote.forEach((k, r) {
    final l = out[k];
    final ru = (r['updatedAt'] as num? ?? 0).toInt();
    final lu = (l?['updatedAt'] as num? ?? -1).toInt();
    if (l == null || ru > lu) out[k] = r;
  });
  return out;
}

/// Merge per-day activity: keep the larger value of each counter.
Map<String, DayActivity> mergeActivity(Map<String, DayActivity> a, Map<String, DayActivity> b) {
  final out = <String, DayActivity>{...a};
  b.forEach((k, v) {
    final x = out[k];
    out[k] = x == null
        ? v
        : DayActivity(sec: math.max(x.sec, v.sec), clips: math.max(x.clips, v.clips), reviews: math.max(x.reviews, v.reviews), words: math.max(x.words, v.words));
  });
  return out;
}

// ---------------------------------------------------------------------------
// Words & clip search
// ---------------------------------------------------------------------------

/// Stable key for a saved word: dictionary id when known, else its dictionary form.
String wordKeyOf(String? dictId, String base) => dictId != null ? 'd$dictId' : 'b$base';

/// Unique word keys in a clip (punctuation skipped), in order of appearance.
List<String> clipWordKeys(Clip c) {
  final seen = <String>{};
  final out = <String>[];
  for (final l in c.lines) {
    for (final w in l.words) {
      if (w.isPunct) continue;
      final k = wordKeyOf(w.d, w.b.isEmpty ? w.s : w.b);
      if (seen.add(k)) out.add(k);
    }
  }
  return out;
}

String grammarKey(String g) => g.split('—').first.trim();

int _matchScore(Clip c, String q, String qLower) {
  var best = 0;
  for (final l in c.lines) {
    for (final w in l.words) {
      if (w.isPunct) continue;
      final forms = [normalizeQuery(w.s), normalizeQuery(w.b), normalizeQuery(w.r), w.ro.toLowerCase()];
      if (forms.contains(q)) return 3;
      if (q.length >= 2 && forms.any((f) => f.startsWith(q))) best = math.max(best, 2);
    }
    if (normalizeQuery(l.ja).contains(q)) best = math.max(best, 1);
    if (qLower.length >= 3 && l.en.toLowerCase().contains(qLower)) best = math.max(best, 1);
  }
  return best;
}

/// Clip ids matching a word/text query (Japanese, kana, romaji or English) and filters.
List<String> searchClips(List<Clip> clips, String query, {String? level, String? topic, String? grammar}) {
  final q = normalizeQuery(query);
  final qLower = query.trim().toLowerCase();
  final hits = <MapEntry<Clip, int>>[];
  for (final c in clips) {
    if (level != null && level.isNotEmpty && c.level != level) continue;
    if (topic != null && topic.isNotEmpty && !c.topics.contains(topic)) continue;
    if (grammar != null && grammar.isNotEmpty && !c.grammar.any((g) => grammarKey(g) == grammar)) continue;
    final s = q.isEmpty ? 1 : _matchScore(c, q, qLower);
    if (s > 0) hits.add(MapEntry(c, s));
  }
  hits.sort((a, b) {
    if (a.value != b.value) return b.value.compareTo(a.value);
    final l = jlptIndex(a.key.level).compareTo(jlptIndex(b.key.level));
    return l != 0 ? l : a.key.id.compareTo(b.key.id);
  });
  return hits.map((e) => e.key.id).toList();
}

// ---------------------------------------------------------------------------
// Saved words: review queue + counts
// ---------------------------------------------------------------------------

class WordLite {
  final String key;
  final String status; // learning | known | ignored | removed
  final Card card;
  final int addedAt;
  const WordLite(this.key, this.status, this.card, this.addedAt);
}

/// Saved words due for review now, oldest due first. Manually-known, ignored and
/// removed words are never reviewed.
List<String> dueWordKeys(List<WordLite> words, int now) {
  final due = words.where((w) => w.status == 'learning' && isDue(w.card, now)).toList()
    ..sort((a, b) => a.card.due != b.card.due ? a.card.due.compareTo(b.card.due) : a.key.compareTo(b.key));
  return due.map((w) => w.key).toList();
}

class WordCounts {
  final int saved, learning, known, due;
  const WordCounts(this.saved, this.learning, this.known, this.due);
}

WordCounts wordCounts(List<WordLite> words, int now) {
  var learning = 0, known = 0, due = 0;
  for (final w in words) {
    if (w.status == 'ignored' || w.status == 'removed') continue;
    final s = wordStatus(status: w.status, card: w.card);
    if (s == 'known') {
      known++;
    } else {
      learning++;
    }
    if (w.status == 'learning' && isDue(w.card, now)) due++;
  }
  return WordCounts(learning + known, learning, known, due);
}

// ---------------------------------------------------------------------------
// Whole-state merge for cloud sync (JSON shape of store.ts / app_state.dart)
// ---------------------------------------------------------------------------

int _n(dynamic v) => (v as num? ?? 0).toInt();

/// Merge two saved learner states. Per-word newest wins, activity/seen/totals keep the
/// max, history/achievements union; profile, settings and other single values come
/// from whichever state changed last. Premium never syncs: each device keeps its own,
/// verified by its store (a cloud copy could relock a payer or revive an expired plan).
Map<String, dynamic> mergeState(Map<String, dynamic> local, Map<String, dynamic> remote) {
  final newer = _n(remote['updatedAt']) > _n(local['updatedAt']) ? remote : local;
  Map<String, dynamic> m(dynamic v) => (v as Map? ?? {}).cast<String, dynamic>();
  final kana = <String, dynamic>{...m(local['kana'])};
  m(remote['kana']).forEach((k, c) {
    if (kana[k] == null || _n(c['reps']) > _n(kana[k]['reps'])) kana[k] = c;
  });
  final seen = <String, dynamic>{...m(local['seen'])};
  m(remote['seen']).forEach((k, n) => seen[k] = math.max(_n(seen[k]), _n(n)));
  final hist = <String, Map<String, dynamic>>{};
  for (final h in [...(local['history'] as List? ?? []), ...(remote['history'] as List? ?? [])]) {
    final e = (h as Map).cast<String, dynamic>();
    hist['${e['clipId']}@${e['at']}'] = e;
  }
  final history = hist.values.toList()..sort((a, b) => _n(b['at']).compareTo(_n(a['at'])));
  final words = mergeByUpdatedAt(
    m(local['words']).map((k, v) => MapEntry(k, (v as Map).cast<String, dynamic>())),
    m(remote['words']).map((k, v) => MapEntry(k, (v as Map).cast<String, dynamic>())),
  );
  final activity = mergeActivity(
    m(local['activity']).map((k, v) => MapEntry(k, DayActivity.fromJson((v as Map).cast<String, dynamic>()))),
    m(remote['activity']).map((k, v) => MapEntry(k, DayActivity.fromJson((v as Map).cast<String, dynamic>()))),
  );
  final lt = m(local['totals']), rt = m(remote['totals']);
  final ach = <String>{...(local['achievementsSeen'] as List? ?? []).cast<String>(), ...(remote['achievementsSeen'] as List? ?? []).cast<String>()}.toList()..sort();
  return {
    ...newer,
    'onboarded': (local['onboarded'] == true) || (remote['onboarded'] == true),
    'premium': local['premium'],
    'purchaseAccountPending': local['purchaseAccountPending'] == true,
    'words': words,
    'kana': kana,
    'seen': seen,
    'history': history.take(200).toList(),
    'activity': activity.map((k, v) => MapEntry(k, v.toJson())),
    'totals': {
      'clips': math.max(_n(lt['clips']), _n(rt['clips'])),
      'seconds': math.max(_n(lt['seconds']), _n(rt['seconds'])),
      'reviews': math.max(_n(lt['reviews']), _n(rt['reviews'])),
    },
    'achievementsSeen': ach,
    'reviewSessions': math.max(_n(local['reviewSessions']), _n(remote['reviewSessions'])),
    'updatedAt': math.max(_n(local['updatedAt']), _n(remote['updatedAt'])),
  };
}

// ---------------------------------------------------------------------------
// Free tier + "hear it again"
// ---------------------------------------------------------------------------

/// Only active trial/paid learners can watch; legacy quota arguments stay compatible.
bool canWatchClip(bool premiumActive, int clipsToday, int freeLimit) => premiumActive;

/// Other clips that contain a word key, best level-fit first, excluding the current clip.
List<String> clipsWithWord(List<Clip> clips, String key, String excludeId, String jlpt, {int limit = 6}) {
  final out = <MapEntry<String, int>>[];
  for (final c in clips) {
    if (c.id == excludeId) continue;
    if (!clipWordKeys(c).contains(key)) continue;
    out.add(MapEntry(c.id, (jlptIndex(c.level) - jlptIndex(jlpt)).abs()));
  }
  out.sort((a, b) => a.value != b.value ? a.value.compareTo(b.value) : a.key.compareTo(b.key));
  return out.take(limit).map((e) => e.key).toList();
}

// ---------------------------------------------------------------------------
// Review queues: kana decks + custom study
// ---------------------------------------------------------------------------

/// Kana session: due cards (soonest first), then up to [newLimit] unseen characters in deck order.
List<String> kanaQueue(List<KanaCard> deck, Map<String, Card> cards, int now, {int newLimit = 10}) {
  final due = deck.where((k) => cards[k.id] != null && isDue(cards[k.id]!, now)).toList()
    ..sort((a, b) => cards[a.id]!.due.compareTo(cards[b.id]!.due));
  final fresh = deck.where((k) => cards[k.id] == null).take(newLimit).map((k) => k.id);
  return [...due.map((k) => k.id), ...fresh];
}

/// Characters that have graduated to review in a kana deck.
int kanaLearned(List<KanaCard> deck, Map<String, Card> cards) => deck.where((k) => cards[k.id]?.state == 'review').length;

/// "Keep studying" after the due queue: learning words not yet due, soonest first.
List<String> customStudyKeys(List<WordLite> words, int now, {int limit = 20}) {
  final list = words.where((w) => w.status == 'learning' && !isDue(w.card, now)).toList()
    ..sort((a, b) => a.card.due != b.card.due ? a.card.due.compareTo(b.card.due) : a.key.compareTo(b.key));
  return list.take(limit).map((w) => w.key).toList();
}

// ---------------------------------------------------------------------------
// Ask Kizuki — AI follow-up questions about a line or word
// ---------------------------------------------------------------------------

/// Longest question a learner can type.
const askMaxChars = 400;

/// How many chat messages are sent to the tutor with each question.
const askMaxMessages = 10;

/// Questions asked today; the counter resets on a new day.
int asksToday(String day, int n, String today) => day == today ? n : 0;

/// Only active trial/paid learners can ask; no free learning tier.
bool canAsk(bool premiumActive, int asked, int freeLimit) => premiumActive;

/// Free questions left today, or null when unlimited.
int? asksLeft(bool premiumActive, int asked, int freeLimit) => premiumActive ? null : 0;

/// Typed question → what gets sent: whitespace collapsed, trimmed, capped at [askMaxChars].
String cleanQuestion(String s) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > askMaxChars ? t.substring(0, askMaxChars).trim() : t;
}

class AskTurn {
  final String role, text;
  const AskTurn(this.role, this.text);
}

/// Chat history sent with a question: non-empty turns, the last [max], starting with a user turn.
List<T> askHistory<T extends AskTurn>(List<T> msgs, [int max = askMaxMessages]) {
  final kept = msgs.where((m) => m.text.trim().isNotEmpty).toList();
  var out = kept.length > max ? kept.sublist(kept.length - max) : kept;
  while (out.isNotEmpty && out.first.role != 'user') {
    out = out.sublist(1);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Help & support messages (stored in public.support_messages; limits match its checks)
// ---------------------------------------------------------------------------

const supportMessageMin = 5;
const supportMessageMax = 2000;
const supportTopics = ['subscription', 'account', 'bug', 'content', 'feedback', 'other'];

/// Problem with a support message, or null when it can be sent.
String? supportMessageError(String email, String message) {
  final e = email.trim();
  if (e.length < 3 || e.length > 255 || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)) return 'Enter the email we should reply to.';
  final m = message.trim();
  if (m.length < supportMessageMin) return 'Tell us a little more (at least 5 characters).';
  if (m.length > supportMessageMax) return 'Keep it under $supportMessageMax characters.';
  return null;
}

/// A completed purchase requires account verification before learning continues.
bool purchaseNeedsAccount(bool pending, bool verified) => pending && !verified;

// ---------------------------------------------------------------------------
// Server content packs: more clips without an app update. The bundled library always stays
// the default; a pack is used only after every file was downloaded and verified, from the
// next app start. Mirrors src/lib/logic.ts.
// ---------------------------------------------------------------------------

const contentPackFormat = 1;
const contentPackMaxFiles = 64;
const contentPackMaxFileBytes = 40000000;

class ContentPackFile {
  final String name, sha256;
  final int bytes;
  const ContentPackFile(this.name, this.sha256, this.bytes);
  Map<String, Object> toJson() => {'name': name, 'sha256': sha256, 'bytes': bytes};
}

class ContentPackManifest {
  final int version;
  final List<ContentPackFile> files;
  final List<String> notes;
  const ContentPackManifest(this.version, this.files, this.notes);
  Map<String, Object> toJson() => {'format': contentPackFormat, 'version': version, 'files': [for (final f in files) f.toJson()], 'notes': notes};
}

final _packFileName = RegExp(r'^[a-z0-9][a-z0-9-]{0,40}\.json$');
final _sha256Hex = RegExp(r'^[0-9a-f]{64}$');
final _clipId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
bool _isWhole(Object? v) => v is int || (v is double && v.isFinite && v == v.truncateToDouble());
bool _isNum(Object? v) => v is num && v.isFinite;
bool _allStrings(Object? v) => v is List && v.every((x) => x is String);

/// What to do with the server's content row: stay on the bundled library ('bundled'), keep the
/// pack already downloaded ('keep'), or fetch the newer one ('download'). Off switch, a missing
/// link or a version that is not newer than the bundle all mean the bundle.
String contentPackAction(Object? enabled, Object? version, Object? url, int bundledVersion, int? activeVersion) {
  if (enabled == false) return 'bundled';
  final v = _isWhole(version) ? (version as num).toInt() : null;
  if (v == null || v <= bundledVersion || founderVideoUrl(url) == null) return 'bundled';
  return v == activeVersion ? 'keep' : 'download';
}

/// A pack manifest the app can trust, or null: known format, the advertised version, safe
/// file names, sha-256 checksums, bounded sizes, and the index + dictionary present.
ContentPackManifest? contentPackManifest(Object? raw, int expectedVersion) {
  if (raw is! Map || raw['format'] != contentPackFormat || !_isWhole(raw['version']) || (raw['version'] as num).toInt() != expectedVersion) return null;
  final files = raw['files'];
  if (files is! List || files.isEmpty || files.length > contentPackMaxFiles) return null;
  final out = <ContentPackFile>[];
  final names = <String>{};
  for (final f in files) {
    if (f is! Map) return null;
    final name = f['name'], sha = f['sha256'], bytes = f['bytes'];
    if (name is! String || !_packFileName.hasMatch(name) || names.contains(name)) return null;
    if (sha is! String || !_sha256Hex.hasMatch(sha)) return null;
    final size = _isWhole(bytes) ? (bytes as num).toInt() : 0;
    if (size < 1 || size > contentPackMaxFileBytes) return null;
    names.add(name);
    out.add(ContentPackFile(name, sha, size));
  }
  if (!names.contains('content.json') || !names.contains('dict.json')) return null;
  final notes = raw['notes'] ?? const [];
  if (notes is! List || notes.length > contentPackMaxFiles) return null;
  if (notes.any((n) => n is! String || !names.contains(n) || n == 'content.json' || n == 'dict.json') || notes.toSet().length != notes.length) return null;
  return ContentPackManifest(expectedVersion, out, List<String>.from(notes));
}

/// Pack files are stored once by checksum next to the manifests (`…/packs/v2.json` → `…/objects/<sha>.json.gz`).
String contentObjectUrl(String manifestUrl, String sha256) => Uri.parse(manifestUrl).resolve('../objects/$sha256.json.gz').toString();

/// Which notes file holds a clip's explanations (FNV-1a over UTF-16 code units).
int notesShard(String clipId, int count) => count < 1 ? -1 : fnv1a(clipId) % count;

/// Problem with a pack's content.json, or null.
String? contentIndexProblem(Object? index, ContentPackManifest manifest) {
  if (index is! Map) return 'index';
  if (index['version'] != manifest.version) return 'version';
  final videos = index['videos'];
  if (videos is! Map || videos.isEmpty) return 'videos';
  for (final v in videos.values) {
    if (v is! Map || v['title'] is! String || v['channel'] is! String || v['channelUrl'] is! String) return 'videos';
  }
  final names = {for (final f in manifest.files) f.name};
  final parts = index['parts'];
  if (parts is! List || parts.isEmpty || parts.toSet().length != parts.length) return 'parts';
  for (final p in parts) {
    if (p is! String || !names.contains(p) || p == 'content.json' || p == 'dict.json' || manifest.notes.contains(p)) return 'parts';
  }
  if (index['starter'] != null && !_allStrings(index['starter'])) return 'starter';
  return null;
}

/// Problem with one clip of a pack, or null (fields every screen reads).
String? contentClipProblem(Object? clip, Map videos) {
  if (clip is! Map || clip['id'] is! String || !_clipId.hasMatch(clip['id'] as String) || clip['title'] is! String || clip['level'] is! String) return 'clip';
  if (!_allStrings(clip['topics']) || !_allStrings(clip['grammar']) || (clip['quality'] != null && !_isNum(clip['quality']))) return 'clip';
  final videoId = clip['videoId'];
  if (videoId is! String || !videos.containsKey(videoId)) return 'video';
  final start = clip['start'], end = clip['end'];
  if (!_isNum(start) || !_isNum(end) || !((end as num) > (start as num))) return 'window';
  final lines = clip['lines'];
  if (lines is! List || lines.isEmpty) return 'lines';
  for (final l in lines) {
    if (l is! Map || !_isNum(l['start']) || !_isNum(l['end']) || l['words'] is! List) return 'lines';
    for (final w in l['words'] as List) {
      if (w is! Map || w['s'] is! String || !_isNum(w['t0']) || !_isNum(w['t1'])) return 'lines';
    }
  }
  return null;
}

/// Problem with a pack's dictionary, or null.
String? contentDictProblem(Object? dict) {
  if (dict is! Map || dict.isEmpty) return 'dict';
  for (final e in dict.values) {
    if (e is! Map || e['w'] is! String || e['r'] is! String || e['m'] is! List || e['ex'] is! List) return 'dict';
  }
  return null;
}

/// Problem with a pack's notes file (clip id → explanations), or null.
String? contentNotesProblem(Object? shard) {
  if (shard is! Map) return 'notes';
  for (final n in shard.values) {
    if (n is! Map) return 'notes';
    final w = n['w'] ?? const {}, l = n['l'] ?? const {};
    if (w is! Map || l is! Map) return 'notes';
    for (final x in w.values) {
      if (x is! Map || x['m'] is! String || x['n'] is! String) return 'notes';
    }
    for (final x in l.values) {
      if (x is! Map || x['lit'] is! String || x['tip'] is! String) return 'notes';
    }
  }
  return null;
}
