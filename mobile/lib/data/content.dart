import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';
import '../logic/logic.dart';
import '../services/content_pack.dart';
import '../services/locale_pack.dart';
import 'models.dart';

/// Translations shown over the English library for one language: the starter translations
/// bundled in the app plus, when downloaded and verified, the full language pack.
class _Overlay {
  final String lang;
  final Map lines, dict, grammar, notes;
  final LocalePack? pack;
  final LocalePackStore? store;
  _Overlay(this.lang, this.lines, this.dict, this.grammar, this.notes, this.pack, this.store);
}

/// Loads the clip library + dictionary: the bundled files (same as web public/data), or a
/// newer server pack once it was downloaded and verified (services/content_pack.dart).
///
/// The library is written in English. For another app language the same library is shown
/// through a translation overlay (services/locale_pack.dart): [clips], [byId] and [dict] then
/// hold the translated view, and a clip, word or explanation without a translation made for
/// exactly it stays in English. Mirrors src/lib/content.ts.
class Content {
  final Map<String, Video> videos;
  final List<Clip> _baseClips;
  final Map<String, Clip> _baseById;
  final Map<String, DictEntry> _baseDict;
  late List<Clip> clips;
  late Map<String, Clip> byId;
  late Map<String, DictEntry> dict;

  /// Language [clips] and [dict] are shown in.
  String lang = 'en';
  _Overlay? _overlay;
  final Map<String, ClipNotes> _localNotes = {};
  final Map<String, Future<Map<String, dynamic>?>> _localeShards = {};
  /// Curated first clips for everyone, in order (scripts/content/pick_starter.py).
  final List<StarterClip> starter;
  final Map<String, ClipNotes> _notes = {};
  final Map<String, Future<Map<String, dynamic>?>> _shards = {};

  Content._(this.videos, List<Clip> clips, Map<String, DictEntry> dict, List<String> starterIds)
      : _baseClips = clips,
        _baseDict = dict,
        _baseById = {for (final c in clips) c.id: c},
        starter = [] {
    this.clips = _baseClips;
    byId = _baseById;
    this.dict = _baseDict;
    for (final id in starterIds) {
      final c = byId[id];
      if (c != null) starter.add((id: id, level: c.level));
    }
  }

  static Content? _instance;
  static Future<Content>? _loading;
  static Content get I => _instance!;

  /// Library version bundled with this build (content.json "version").
  static int bundledVersion = 1;

  /// The verified server pack this run reads, or null for the bundled library.
  static ActivePack? pack;
  static ContentPackStore? _packStore;

  static Future<Content> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    return _loading ??= _loadOnce();
  }

  static Future<Content> _loadOnce() async {
    try {
      final raw = await rootBundle.loadString('assets/data/content.json', cache: false);
      bundledVersion = _versionOf(raw);
      final store = await ContentPack.store();
      final active = await store?.active(bundledVersion);
      if (store != null && active != null) {
        try {
          final index = await store.readText(active, 'content.json');
          final dictRaw = await store.readText(active, 'dict.json');
          final parts = await Future.wait(_partNames(index).map((p) => store.readText(active, p)));
          final parsed = await compute(_parse, [index, dictRaw, ...parts]);
          pack = active;
          _packStore = store;
          _instance = Content._(parsed.$1, parsed.$2, parsed.$3, parsed.$4);
          await _instance!._useLanguage(I18n.lang.value);
          return _instance!;
        } catch (e) {
          // A pack that does not load is dropped for good; the bundle below takes over.
          debugPrint('KIZUKI_ERROR content pack: $e');
          pack = null;
          await store.deactivate();
        }
      }
      final dictRaw = await rootBundle.loadString('assets/data/dict.json', cache: false);
      // Clips are sharded into parts (repo file-size limit); see scripts/content/build.ts.
      final parts = await Future.wait(_partNames(raw).map((p) => rootBundle.loadString('assets/data/$p', cache: false)));
      final parsed = await compute(_parse, [raw, dictRaw, ...parts]);
      _instance = Content._(parsed.$1, parsed.$2, parsed.$3, parsed.$4);
      await _instance!._useLanguage(I18n.lang.value);
      return _instance!;
    } finally {
      _loading = null;
    }
  }

  static int _versionOf(String index) {
    final m = RegExp(r'"version"\s*:\s*(\d+)').firstMatch(index);
    return m == null ? 1 : int.parse(m.group(1)!);
  }

  static List<String> _partNames(String index) => ((jsonDecode(index) as Map<String, dynamic>)['parts'] as List?)?.cast<String>() ?? const <String>[];

  /// Test hook: build from in-memory JSON (the index plus its clip parts, when sharded).
  static Content fromJson(String raw, String dictRaw, [List<String> parts = const []]) {
    final p = _parse([raw, dictRaw, ...parts]);
    _instance = Content._(p.$1, p.$2, p.$3, p.$4);
    return _instance!;
  }

  static (Map<String, Video>, List<Clip>, Map<String, DictEntry>, List<String>) _parse(List<String> input) {
    final j = jsonDecode(input[0]) as Map<String, dynamic>;
    final videos = (j['videos'] as Map<String, dynamic>).map((k, v) => MapEntry(k, Video(v['title'] as String, v['channel'] as String, v['channelUrl'] as String)));
    final rawClips = j['clips'] as List? ?? [for (final part in input.skip(2)) ...((jsonDecode(part) as Map<String, dynamic>)['clips'] as List)];
    final clips = rawClips.map((c) => Clip.fromJson(c as Map<String, dynamic>)).toList();
    final d = (jsonDecode(input[1]) as Map<String, dynamic>).map((k, v) => MapEntry(k, DictEntry.fromJson(v as Map<String, dynamic>)));
    final starter = (j['starter'] as List?)?.cast<String>() ?? const <String>[];
    return (videos, clips, d, starter);
  }

  /// Shows the library in [code] (after the app language changed). Screens holding this
  /// Content see the translated view from their next build.
  static Future<void> useLanguage(String code) async {
    final c = _instance;
    if (c != null) await c._useLanguage(code);
  }

  /// Language pack files the running app reads (never deleted underneath it).
  static Set<String> get localeFilesInUse => {for (final f in _instance?._overlay?.pack?.manifest.files ?? const <LocalePackFile>[]) f.sha256};

  Future<void> _useLanguage(String code) async {
    if (code == lang && (code == 'en' || _overlay != null)) return;
    final o = code == 'en' ? null : await _loadOverlay(code);
    if (I18n.lang.value != code && code != 'en') return; // switched again meanwhile
    applyOverlay(code, o?.lines, o?.dict, o?.grammar);
    _overlay = o;
    shown.value = code;
  }

  /// Language the library is shown in; screens holding explanations reload them when it changes.
  static final shown = ValueNotifier<String>('en');

  /// Test hook too: shows the library through translation maps (null = English).
  @visibleForTesting
  void applyOverlay(String code, Map? lines, Map? dictOverlay, Map? grammar) {
    lang = code;
    _overlay = null;
    _localNotes.clear();
    _localeShards.clear();
    if (code == 'en' || lines == null) {
      clips = _baseClips;
      byId = _baseById;
      dict = _baseDict;
      return;
    }
    final g = grammar == null || grammar.isEmpty ? null : grammar;
    clips = [for (final c in _baseClips) localizeClip(c, lines[c.id] is Map ? lines[c.id] as Map : null, g)];
    byId = {for (final c in clips) c.id: c};
    dict = {for (final e in _baseDict.entries) e.key: localizeEntry(e.value, dictOverlay?[e.key] is Map ? dictOverlay![e.key] as Map : null)};
  }

  static Future<_Overlay> _loadOverlay(String code) async {
    Map<String, dynamic> bundled = const {};
    try {
      bundled = await compute(_decodeMap, await rootBundle.loadString('assets/data/locale/$code.json', cache: false));
    } catch (_) {}
    Map pick(Object? x) => x is Map ? x : const {};
    final lines = {...pick(bundled['lines'])}, dict = {...pick(bundled['dict'])}, grammar = {...pick(bundled['grammar'])};
    final notes = pick(bundled['notes']);
    final s = await LocalePacks.store();
    final p = await s?.active(code);
    if (s != null && p != null) {
      try {
        final texts = await Future.wait(['lines.json', 'dict.json', 'grammar.json'].map((n) => s.readText(p, n)));
        final parsed = await compute(_decodeMaps, texts);
        // The pack is newer than the app; the bundled starter translations fill what it lacks.
        lines.addAll(parsed[0]);
        dict.addAll(parsed[1]);
        grammar.addAll(parsed[2]);
        return _Overlay(code, lines, dict, grammar, notes, p, s);
      } catch (e) {
        // A pack that does not load (cache cleared, file changed) is dropped; it downloads again.
        debugPrint('KIZUKI_ERROR language pack $code: $e');
        await s.deactivate(code);
      }
    }
    return _Overlay(code, lines, dict, grammar, notes, null, null);
  }

  static List<Map<String, dynamic>> _decodeMaps(List<String> texts) => [for (final t in texts) jsonDecode(t) as Map<String, dynamic>];

  /// A clip's explanations in the app language (English where no translation was made for it).
  Future<ClipNotes> notes(String clipId) async {
    final o = _overlay;
    if (o == null) return _baseNotes(clipId);
    final hit = _localNotes[clipId];
    if (hit != null) return hit;
    final base = await _baseNotes(clipId);
    final clip = _baseById[clipId];
    if (clip == null) return base;
    Object? n;
    final p = o.pack, s = o.store;
    if (p != null && s != null) n = (await _localeShard(s, p, clipId))?[clipId];
    n ??= o.notes[clipId];
    final out = localizeNotes(base, n is Map ? n : null, clipLocaleSig(clip.lines));
    if (identical(o, _overlay)) _localNotes[clipId] = out;
    return out;
  }

  /// A language pack's notes file, decoded off the UI thread; the two most recent stay in memory.
  Future<Map<String, dynamic>?> _localeShard(LocalePackStore s, LocalePack p, String clipId) {
    final name = 'notes-${localeNoteShard(clipId).toString().padLeft(2, '0')}.json';
    final hit = _localeShards.remove(name);
    if (hit != null) return _localeShards[name] = hit;
    final f = s.readText(p, name).then((t) => compute(_decodeMap, t)).then<Map<String, dynamic>?>((m) => m, onError: (Object _) => null);
    _localeShards[name] = f;
    while (_localeShards.length > 2) {
      _localeShards.remove(_localeShards.keys.first);
    }
    return f;
  }

  /// Explanations as built (English).
  Future<ClipNotes> _baseNotes(String clipId) async {
    final cached = _notes[clipId];
    if (cached != null) return cached;
    final p = pack, s = _packStore;
    if (p != null && s != null && p.manifest.notes.isNotEmpty) {
      final shard = await _shard(s, p, p.manifest.notes[notesShard(clipId, p.manifest.notes.length)]);
      final j = shard?[clipId];
      if (j is Map<String, dynamic>) {
        try {
          return _notes[clipId] = ClipNotes.fromJson(j);
        } catch (_) {}
      }
    }
    try {
      final raw = await rootBundle.loadString('assets/data/explain/$clipId.json', cache: false);
      final n = ClipNotes.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _notes[clipId] = n;
      return n;
    } catch (_) {
      return ClipNotes.empty;
    }
  }

  /// A pack notes file, decoded off the UI thread; the two most recent stay in memory.
  Future<Map<String, dynamic>?> _shard(ContentPackStore s, ActivePack p, String name) {
    final hit = _shards.remove(name);
    if (hit != null) return _shards[name] = hit;
    final f = s.readText(p, name).then((t) => compute(_decodeMap, t)).then<Map<String, dynamic>?>((m) => m, onError: (Object _) => null);
    _shards[name] = f;
    while (_shards.length > 2) {
      _shards.remove(_shards.keys.first);
    }
    return f;
  }

  static Map<String, dynamic> _decodeMap(String text) => jsonDecode(text) as Map<String, dynamic>;

  List<RankClip> get rankClips => [for (final c in clips) RankClip(id: c.id, videoId: c.videoId, level: c.level, topics: c.topics, quality: c.quality, still: c.still)];

  /// All grammar patterns with how many clips use them, most common first.
  List<MapEntry<String, int>> grammarIndex() {
    final m = <String, int>{};
    for (final c in clips) {
      for (final g in c.grammar) {
        final key = g.split('—').first.trim();
        m[key] = (m[key] ?? 0) + 1;
      }
    }
    final list = m.entries.toList()..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    return list;
  }
}
