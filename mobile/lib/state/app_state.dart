import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/logic.dart';
import '../services/attribution.dart';
import '../services/analytics.dart';

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
  int? expiresAt;
  Premium({this.active = false, this.plan, this.since, this.trialEndsAt, this.expiresAt});
  Map<String, dynamic> toJson() => {'active': active, 'plan': plan, 'since': since, 'trialEndsAt': trialEndsAt, 'expiresAt': expiresAt};
  factory Premium.fromJson(Map<String, dynamic> j) => Premium(
        active: j['active'] as bool? ?? false,
        plan: j['plan'] as String?,
        since: (j['since'] as num?)?.toInt(),
        trialEndsAt: (j['trialEndsAt'] as num?)?.toInt(),
        expiresAt: (j['expiresAt'] as num?)?.toInt(),
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
  bool haptics; // Settings → Vibration feedback (missing in older saved state = on)
  bool widgetSaved, widgetReading, widgetMeaning;
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
    this.haptics = true,
    this.widgetSaved = false,
    this.widgetReading = true,
    this.widgetMeaning = true,
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
        'haptics': haptics,
        'widgetSaved': widgetSaved, 'widgetReading': widgetReading, 'widgetMeaning': widgetMeaning,
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
        haptics: j['haptics'] as bool? ?? true,
        widgetSaved: j['widgetSaved'] as bool? ?? false,
        widgetReading: j['widgetReading'] as bool? ?? true,
        widgetMeaning: j['widgetMeaning'] as bool? ?? true,
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
  bool purchaseAccountPending = false;
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
  String asksDay = '';
  int asksN = 0;
  int updatedAt = 0;

  /// Account this device's learner progress last synced with (see localStateFor).
  String? owner;

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
  int get asksTodayCount => asksToday(asksDay, asksN, today);
  bool isSaved(String key) => words[key] != null && words[key]!.status != 'removed';

  /// Underline status for a word in a transcript: new | learning | known | ignored.
  String tokenStatus(String key) {
    final w = words[key];
    if (w == null || w.status == 'removed') return 'new';
    return wordStatus(status: w.status, card: w.card);
  }

  /// Level badge for a saved word (0 ignored, 1–4 learning, 5 known); null when not saved.
  int? tokenLevel(String key) {
    final w = words[key];
    if (w == null || w.status == 'removed') return null;
    return wordLevel(status: w.status, card: w.card);
  }

  /// Set by startup when [load] took too long and the app already started without it.
  bool loadIsLate = false;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(storageKey);
    if (raw != null) {
      try {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        if (loadIsLate) {
          // The app is already running: merge the saved progress in instead of replacing
          // what happened since, and keep the live (store-verified) Premium state. A saved
          // purchase-account step and the progress owner are never lost.
          final live = toJson();
          final merged = mergeState(live, saved);
          if (saved['purchaseAccountPending'] == true) merged['purchaseAccountPending'] = true;
          final owner = live['owner'] ?? saved['owner'];
          if (owner != null) {
            merged['owner'] = owner;
          } else {
            merged.remove('owner');
          }
          replaceAll(merged);
        } else {
          applyJson(saved);
        }
      } catch (e) {
        debugPrint('state load failed: $e');
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'onboarded': onboarded,
        'purchaseAccountPending': purchaseAccountPending,
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
        'asks': {'day': asksDay, 'n': asksN},
        'updatedAt': updatedAt,
        if (owner != null) 'owner': owner,
      };

  void applyJson(Map<String, dynamic> j) {
    onboarded = j['onboarded'] as bool? ?? false;
    purchaseAccountPending = j['purchaseAccountPending'] as bool? ?? false;
    owner = j['owner'] as String?;
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
    final asks = (j['asks'] as Map? ?? {}).cast<String, dynamic>();
    asksDay = asks['day'] as String? ?? '';
    asksN = (asks['n'] as num? ?? 0).toInt();
    updatedAt = (j['updatedAt'] as num? ?? 0).toInt();
  }

  /// [touch] false for device-only values (store-verified Premium): they must not make
  /// this device's older synced fields look newer than the cloud copy.
  void _commit({bool sync = true, bool touch = true}) {
    if (touch) updatedAt = now;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () => _prefs?.setString(storageKey, jsonEncode(toJson())));
    if (sync) onChanged?.call();
  }

  /// Replace everything (used by cloud sync after merging).
  void replaceAll(Map<String, dynamic> j) {
    final devicePremium = premium;
    applyJson(j);
    premium = devicePremium;
    notifyListeners();
    _prefs?.setString(storageKey, jsonEncode(toJson()));
  }

  // ---- onboarding / account ----
  void setProfile(void Function(Profile p) edit) {
    edit(profile);
    Analytics.track('learning_preferences_changed', {'jlpt': profile.jlpt, 'daily_minutes': profile.dailyMinutes});
    _commit();
  }

  void requirePurchaseAccount() {
    purchaseAccountPending = true;
    Analytics.track('purchase_account_required');
    _commit();
  }

  void confirmPurchaseAccount() {
    purchaseAccountPending = false;
    Analytics.track('purchase_account_completed');
    _commit();
  }

  void completeOnboarding() {
    if (!onboarded) Attribution.onboardingDone();
    if (!onboarded) Analytics.track('onboarding_completed');
    onboarded = true;
    _commit();
  }

  void startTrial(String plan) {
    final t = now;
    premium = Premium(active: true, plan: plan, since: t, trialEndsAt: simulatedTrialEnd(plan, t), expiresAt: simulatedTrialEnd(plan, t));
    _commit();
  }

  void cancelPremium() {
    premium = Premium();
    _commit();
  }

  /// Store-verified Premium (RevenueCat). Only writes when something actually changed.
  /// Premium never syncs, so it neither pushes nor advances the learner timestamp.
  void applyPremium(Premium p) {
    if (jsonEncode(p.toJson()) == jsonEncode(premium.toJson())) return;
    premium = p;
    Analytics.track('subscription_status_changed', {'active': p.active, 'plan': p.plan ?? 'none', 'is_trial': p.trialEndsAt != null});
    _commit(sync: false, touch: false);
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
    Analytics.track('word_saved', {'clip_id': i.clipId, 'word_id': i.key, 'jlpt': i.jlpt ?? 0});
    activity[today] = todayActivity.add(words: 1);
    _commit();
  }

  /// "Mark remaining words as known" — saves each as known without reviews.
  void markKnown(List<WordInput> inputs) {
    final t = now;
    Analytics.track('words_marked_known', {'count': inputs.length});
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
    Analytics.track('word_status_changed', {'word_id': key, 'status': status});
    w.updatedAt = now;
    _commit();
  }

  /// Kiku-style level menu: 0 ignored, 1–4 learning (reschedules the card), 5 known.
  void setWordLevel(String key, int level) {
    final w = words[key];
    if (w == null) return;
    final next = withWordLevel(w.status, w.card, level, now);
    if (next.status == w.status && identical(next.card, w.card)) return;
    Analytics.track('word_level_changed', {'word_id': key, 'level': level});
    w.status = next.status;
    w.card = next.card;
    w.updatedAt = now;
    _commit();
  }

  void removeWord(String key) => setWordStatus(key, 'removed');

  void setWordNote(String key, String note) {
    final w = words[key];
    if (w == null) return;
    w.note = note;
    Analytics.track('word_note_saved');
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
    Analytics.track('review_session_completed');
    _commit();
  }

  // ---- watching ----
  void addWatchSeconds(int sec) {
    if (sec <= 0) return;
    totalSeconds += sec;
    Analytics.track('study_time_recorded', {'seconds': sec});
    activity[today] = todayActivity.add(sec: sec);
    _commit(sync: false);
  }

  void markClipWatched(String clipId) {
    Analytics.track('clip_watched', {'clip_id': clipId});
    seen[clipId] = (seen[clipId] ?? 0) + 1;
    history.insert(0, HistoryEntry(clipId, now));
    if (history.length > 200) history = history.sublist(0, 200);
    totalClips++;
    activity[today] = todayActivity.add(clips: 1);
    _commit();
  }

  void toggleSavedClip(String clipId) {
    Analytics.track('clip_bookmark_changed', {'clip_id': clipId, 'saved': !savedClips.contains(clipId)});
    if (savedClips.contains(clipId)) {
      savedClips.remove(clipId);
    } else {
      savedClips.insert(0, clipId);
    }
    _commit();
  }

  // ---- settings & flags ----
  void setSettings(void Function(Settings s) edit) {
    final before = settings.toJson();
    edit(settings);
    for (final entry in settings.toJson().entries) {
      if (before[entry.key] != entry.value && entry.value is Object) Analytics.track('setting_changed', {'setting': entry.key, 'value': entry.value as Object});
    }
    _commit();
  }

  void completeTutorial(String which) {
    Analytics.track('welcome_tour_completed', {'tour': which});
    if (which == 'feed' && !tutorialFeed) Attribution.tourDone();
    if (which == 'feed') tutorialFeed = true;
    if (which == 'review') tutorialReview = true;
    _commit();
  }

  void resetTutorial() {
    Analytics.track('welcome_tour_restarted');
    tutorialFeed = false;
    tutorialReview = false;
    _commit();
  }

  void markAchievementsSeen(List<String> ids) {
    for (final id in ids) {
      if (!achievementsSeen.contains(id)) Attribution.achievement(id);
    }
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

  /// One answered "Ask Kizuki" question (counts toward the free daily allowance).
  void recordAsk() {
    Analytics.track('ask_answer_received');
    asksN = asksTodayCount + 1;
    asksDay = today;
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
