import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/logic.dart';

/// App state — mirrors src/lib/store.ts (same JSON shape, defaults and actions,
/// same storage key `mimi-state-v1`).
const storageKey = 'mimi-state-v1';

class Profile {
  String name;
  List<String> reasons;
  int level;
  String jlpt;
  List<String> challenges;
  String source;
  int fluencyMonths;
  int dailyMinutes;
  String window;
  int streakGoal;
  Profile({
    this.name = '',
    this.reasons = const [],
    this.level = 0,
    this.jlpt = 'N5',
    this.challenges = const [],
    this.source = '',
    this.fluencyMonths = 12,
    this.dailyMinutes = 15,
    this.window = 'evening',
    this.streakGoal = 14,
  });
  Map<String, dynamic> toJson() => {
        'name': name,
        'reasons': reasons,
        'level': level,
        'jlpt': jlpt,
        'challenges': challenges,
        'source': source,
        'fluencyMonths': fluencyMonths,
        'dailyMinutes': dailyMinutes,
        'window': window,
        'streakGoal': streakGoal,
      };
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] as String? ?? '',
        reasons: (j['reasons'] as List? ?? []).cast<String>(),
        level: (j['level'] as num? ?? 0).toInt(),
        jlpt: j['jlpt'] as String? ?? 'N5',
        challenges: (j['challenges'] as List? ?? []).cast<String>(),
        source: j['source'] as String? ?? '',
        fluencyMonths: (j['fluencyMonths'] as num? ?? 12).toInt(),
        dailyMinutes: (j['dailyMinutes'] as num? ?? 15).toInt(),
        window: j['window'] as String? ?? 'evening',
        streakGoal: (j['streakGoal'] as num? ?? 14).toInt(),
      );
}

class Premium {
  bool active;
  String? plan;
  int? since;
  int? trialEndsAt;
  Premium({this.active = false, this.plan, this.since, this.trialEndsAt});
  Map<String, dynamic> toJson() => {'active': active, 'plan': plan, 'since': since, 'trialEndsAt': trialEndsAt};
  factory Premium.fromJson(Map<String, dynamic> j) => Premium(
        active: j['active'] as bool? ?? false,
        plan: j['plan'] as String?,
        since: (j['since'] as num?)?.toInt(),
        trialEndsAt: (j['trialEndsAt'] as num?)?.toInt(),
      );
}

class SavedWord {
  final String key;
  final String? dictId;
  final String word, reading, romaji, gloss, pos, surface, clipId;
  final int? jlpt;
  final int line, idx;
  String note;
  String status; // learning | known | ignored | removed
  Card card;
  final int addedAt;
  int updatedAt;
  SavedWord({
    required this.key,
    this.dictId,
    required this.word,
    required this.reading,
    required this.romaji,
    required this.gloss,
    required this.pos,
    this.jlpt,
    required this.surface,
    required this.clipId,
    required this.line,
    required this.idx,
    this.note = '',
    this.status = 'learning',
    required this.card,
    required this.addedAt,
    required this.updatedAt,
  });
  WordLite get lite => WordLite(key, status, card, addedAt);
  Map<String, dynamic> toJson() => {
        'key': key,
        'dictId': dictId,
        'word': word,
        'reading': reading,
        'romaji': romaji,
        'gloss': gloss,
        'pos': pos,
        'jlpt': jlpt,
        'surface': surface,
        'clipId': clipId,
        'line': line,
        'idx': idx,
        'note': note,
        'status': status,
        'card': card.toJson(),
        'addedAt': addedAt,
        'updatedAt': updatedAt,
      };
  factory SavedWord.fromJson(Map<String, dynamic> j) => SavedWord(
        key: j['key'] as String,
        dictId: j['dictId'] as String?,
        word: j['word'] as String? ?? '',
        reading: j['reading'] as String? ?? '',
        romaji: j['romaji'] as String? ?? '',
        gloss: j['gloss'] as String? ?? '',
        pos: j['pos'] as String? ?? '',
        jlpt: (j['jlpt'] as num?)?.toInt(),
        surface: j['surface'] as String? ?? '',
        clipId: j['clipId'] as String? ?? '',
        line: (j['line'] as num? ?? 0).toInt(),
        idx: (j['idx'] as num? ?? 0).toInt(),
        note: j['note'] as String? ?? '',
        status: j['status'] as String? ?? 'learning',
        card: Card.fromJson((j['card'] as Map).cast<String, dynamic>()),
        addedAt: (j['addedAt'] as num? ?? 0).toInt(),
        updatedAt: (j['updatedAt'] as num? ?? 0).toInt(),
      );
}

/// Everything needed to save a tapped word.
class WordInput {
  final String? dictId;
  final String word, reading, romaji, gloss, pos, surface, clipId;
  final int? jlpt;
  final int line, idx;
  final String base;
  const WordInput({
    this.dictId,
    required this.base,
    required this.word,
    required this.reading,
    required this.romaji,
    required this.gloss,
    required this.pos,
    this.jlpt,
    required this.surface,
    required this.clipId,
    required this.line,
    required this.idx,
  });
  String get key => wordKeyOf(dictId, base);
}

class Settings {
  bool furigana, romaji, translation, spacing, highlight, autoSave, flashFurigana, flashRomaji, reminders;
  double textSize; // text scale: 0.85 small · 1 medium · 1.2 large (same as web)
  double speed;
  String flashFront; // jp | en
  String reminderFreq; // standard | minimal
  Settings({
    this.furigana = true,
    this.romaji = true,
    this.translation = true,
    this.spacing = true,
    this.highlight = true,
    this.autoSave = true,
    this.textSize = 1,
    this.speed = 1,
    this.flashFront = 'jp',
    this.flashFurigana = false,
    this.flashRomaji = false,
    this.reminders = true,
    this.reminderFreq = 'standard',
  });
  Map<String, dynamic> toJson() => {
        'furigana': furigana,
        'romaji': romaji,
        'translation': translation,
        'spacing': spacing,
        'highlight': highlight,
        'autoSave': autoSave,
        'textSize': textSize,
        'speed': speed,
        'flashFront': flashFront,
        'flashFurigana': flashFurigana,
        'flashRomaji': flashRomaji,
        'reminders': reminders,
        'reminderFreq': reminderFreq,
      };
  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        furigana: j['furigana'] as bool? ?? true,
        romaji: j['romaji'] as bool? ?? true,
        translation: j['translation'] as bool? ?? true,
        spacing: j['spacing'] as bool? ?? true,
        highlight: j['highlight'] as bool? ?? true,
        autoSave: j['autoSave'] as bool? ?? true,
        textSize: (j['textSize'] as num? ?? 1).toDouble(),
        speed: (j['speed'] as num? ?? 1).toDouble(),
        flashFront: j['flashFront'] as String? ?? 'jp',
        flashFurigana: j['flashFurigana'] as bool? ?? false,
        flashRomaji: j['flashRomaji'] as bool? ?? false,
        reminders: j['reminders'] as bool? ?? true,
        reminderFreq: j['reminderFreq'] as String? ?? 'standard',
      );
}

class HistoryEntry {
  final String clipId;
  final int at;
  const HistoryEntry(this.clipId, this.at);
  Map<String, dynamic> toJson() => {'clipId': clipId, 'at': at};
}

class AppState extends ChangeNotifier {
  bool onboarded = false;
  Profile profile = Profile();
  Premium premium = Premium();
  Map<String, SavedWord> words = {};
  Map<String, Card> kana = {};
  Map<String, int> seen = {};
  List<HistoryEntry> history = [];
  List<String> savedClips = [];
  Map<String, DayActivity> activity = {};
  int totalClips = 0, totalSeconds = 0, totalReviews = 0;
  Settings settings = Settings();
  bool tutorialFeed = false, tutorialReview = false;
  List<String> achievementsSeen = [];
  String feedSeed = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  int reviewSessions = 0;
  bool ratingAsked = false, planModalSeen = false;
  int updatedAt = 0;

  /// Called after every change (cloud sync hooks in here).
  void Function()? onChanged;

  SharedPreferences? _prefs;
  Timer? _saveTimer;

  int get now => DateTime.now().millisecondsSinceEpoch;
  String get today => dayKey(DateTime.now());
  DayActivity get todayActivity => activity[today] ?? const DayActivity();
  List<WordLite> get wordLites => words.values.map((w) => w.lite).toList();
  int get streak => currentStreak(activity, DateTime.now());
  WordCounts get counts => wordCounts(wordLites, now);
  List<String> get dueKeys => dueWordKeys(wordLites, now);
  Stats get stats => Stats(clips: totalClips, seconds: totalSeconds, words: counts.saved, known: counts.known, reviews: totalReviews, streak: streak);
  bool isSaved(String key) => words[key] != null && words[key]!.status != 'removed';

  /// Underline status for a word in a transcript: new | learning | known | ignored.
  String tokenStatus(String key) {
    final w = words[key];
    if (w == null || w.status == 'removed') return 'new';
    return wordStatus(status: w.status, card: w.card);
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(storageKey);
    if (raw != null) {
      try {
        applyJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('state load failed: $e');
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'onboarded': onboarded,
        'profile': profile.toJson(),
        'premium': premium.toJson(),
        'words': words.map((k, v) => MapEntry(k, v.toJson())),
        'kana': kana.map((k, v) => MapEntry(k, v.toJson())),
        'seen': seen,
        'history': history.map((h) => h.toJson()).toList(),
        'savedClips': savedClips,
        'activity': activity.map((k, v) => MapEntry(k, v.toJson())),
        'totals': {'clips': totalClips, 'seconds': totalSeconds, 'reviews': totalReviews},
        'settings': settings.toJson(),
        'tutorial': {'feed': tutorialFeed, 'review': tutorialReview},
        'achievementsSeen': achievementsSeen,
        'feedSeed': feedSeed,
        'reviewSessions': reviewSessions,
        'ratingAsked': ratingAsked,
        'planModalSeen': planModalSeen,
        'updatedAt': updatedAt,
      };

  void applyJson(Map<String, dynamic> j) {
    onboarded = j['onboarded'] as bool? ?? false;
    profile = Profile.fromJson((j['profile'] as Map? ?? {}).cast<String, dynamic>());
    premium = Premium.fromJson((j['premium'] as Map? ?? {}).cast<String, dynamic>());
    words = (j['words'] as Map? ?? {}).map((k, v) => MapEntry(k as String, SavedWord.fromJson((v as Map).cast<String, dynamic>())));
    kana = (j['kana'] as Map? ?? {}).map((k, v) => MapEntry(k as String, Card.fromJson((v as Map).cast<String, dynamic>())));
    seen = (j['seen'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt()));
    history = (j['history'] as List? ?? []).map((h) => HistoryEntry(h['clipId'] as String, (h['at'] as num).toInt())).toList();
    savedClips = (j['savedClips'] as List? ?? []).cast<String>();
    activity = (j['activity'] as Map? ?? {}).map((k, v) => MapEntry(k as String, DayActivity.fromJson((v as Map).cast<String, dynamic>())));
    final t = (j['totals'] as Map? ?? {}).cast<String, dynamic>();
    totalClips = (t['clips'] as num? ?? 0).toInt();
    totalSeconds = (t['seconds'] as num? ?? 0).toInt();
    totalReviews = (t['reviews'] as num? ?? 0).toInt();
    settings = Settings.fromJson((j['settings'] as Map? ?? {}).cast<String, dynamic>());
    final tut = (j['tutorial'] as Map? ?? {}).cast<String, dynamic>();
    tutorialFeed = tut['feed'] as bool? ?? false;
    tutorialReview = tut['review'] as bool? ?? false;
    achievementsSeen = (j['achievementsSeen'] as List? ?? []).cast<String>();
    feedSeed = j['feedSeed'] as String? ?? feedSeed;
    reviewSessions = (j['reviewSessions'] as num? ?? 0).toInt();
    ratingAsked = j['ratingAsked'] as bool? ?? false;
    planModalSeen = j['planModalSeen'] as bool? ?? false;
    updatedAt = (j['updatedAt'] as num? ?? 0).toInt();
  }

  void _commit({bool sync = true}) {
    updatedAt = now;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () => _prefs?.setString(storageKey, jsonEncode(toJson())));
    if (sync) onChanged?.call();
  }

  /// Replace everything (used by cloud sync after merging).
  void replaceAll(Map<String, dynamic> j) {
    applyJson(j);
    notifyListeners();
    _prefs?.setString(storageKey, jsonEncode(toJson()));
  }

  // ---- onboarding / account ----
  void setProfile(void Function(Profile p) edit) {
    edit(profile);
    _commit();
  }

  void completeOnboarding() {
    onboarded = true;
    _commit();
  }

  void startTrial(String plan) {
    final t = now;
    premium = Premium(active: true, plan: plan, since: t, trialEndsAt: t + 7 * dayMs);
    _commit();
  }

  void cancelPremium() {
    premium = Premium();
    _commit();
  }

  // ---- words ----
  void saveWord(WordInput i) {
    final existing = words[i.key];
    final t = now;
    if (existing != null && existing.status != 'removed') return;
    words[i.key] = SavedWord(
      key: i.key,
      dictId: i.dictId,
      word: i.word,
      reading: i.reading,
      romaji: i.romaji,
      gloss: i.gloss,
      pos: i.pos,
      jlpt: i.jlpt,
      surface: i.surface,
      clipId: i.clipId,
      line: i.line,
      idx: i.idx,
      card: newCard(t),
      addedAt: t,
      updatedAt: t,
    );
    activity[today] = todayActivity.add(words: 1);
    _commit();
  }

  /// "Mark remaining words as known" — saves each as known without reviews.
  void markKnown(List<WordInput> inputs) {
    final t = now;
    for (final i in inputs) {
      final w = words[i.key];
      if (w != null && w.status != 'removed') continue;
      words[i.key] = SavedWord(
        key: i.key,
        dictId: i.dictId,
        word: i.word,
        reading: i.reading,
        romaji: i.romaji,
        gloss: i.gloss,
        pos: i.pos,
        jlpt: i.jlpt,
        surface: i.surface,
        clipId: i.clipId,
        line: i.line,
        idx: i.idx,
        status: 'known',
        card: newCard(t),
        addedAt: t,
        updatedAt: t,
      );
    }
    _commit();
  }

  void setWordStatus(String key, String status) {
    final w = words[key];
    if (w == null) return;
    w.status = status;
    w.updatedAt = now;
    _commit();
  }

  void removeWord(String key) => setWordStatus(key, 'removed');

  void setWordNote(String key, String note) {
    final w = words[key];
    if (w == null) return;
    w.note = note;
    w.updatedAt = now;
    _commit();
  }

  /// Apply a flashcard answer; returns the updated card.
  Card answerWord(String key, Card updated) {
    final w = words[key];
    if (w != null) {
      w.card = updated;
      w.updatedAt = now;
    }
    totalReviews++;
    activity[today] = todayActivity.add(reviews: 1);
    _commit();
    return updated;
  }

  void answerKana(String id, Card updated) {
    kana[id] = updated;
    totalReviews++;
    activity[today] = todayActivity.add(reviews: 1);
    _commit();
  }

  void finishReviewSession() {
    reviewSessions++;
    _commit();
  }

  // ---- watching ----
  void addWatchSeconds(int sec) {
    if (sec <= 0) return;
    totalSeconds += sec;
    activity[today] = todayActivity.add(sec: sec);
    _commit(sync: false);
  }

  void markClipWatched(String clipId) {
    seen[clipId] = (seen[clipId] ?? 0) + 1;
    history.insert(0, HistoryEntry(clipId, now));
    if (history.length > 200) history = history.sublist(0, 200);
    totalClips++;
    activity[today] = todayActivity.add(clips: 1);
    _commit();
  }

  void toggleSavedClip(String clipId) {
    if (savedClips.contains(clipId)) {
      savedClips.remove(clipId);
    } else {
      savedClips.insert(0, clipId);
    }
    _commit();
  }

  // ---- settings & flags ----
  void setSettings(void Function(Settings s) edit) {
    edit(settings);
    _commit();
  }

  void completeTutorial(String which) {
    if (which == 'feed') tutorialFeed = true;
    if (which == 'review') tutorialReview = true;
    _commit();
  }

  void resetTutorial() {
    tutorialFeed = false;
    tutorialReview = false;
    _commit();
  }

  void markAchievementsSeen(List<String> ids) {
    achievementsSeen = {...achievementsSeen, ...ids}.toList();
    _commit();
  }

  void setRatingAsked() {
    ratingAsked = true;
    _commit();
  }

  void setPlanModalSeen() {
    planModalSeen = true;
    _commit();
  }

  /// Sign out / delete: wipe local data and start fresh.
  Future<void> reset() async {
    applyJson({});
    feedSeed = now.toRadixString(36);
    await _prefs?.remove(storageKey);
    notifyListeners();
  }
}
