import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logic/logic.dart';
import '../services/content_pack.dart';
import 'models.dart';

/// Loads the clip library + dictionary: the bundled files (same as web public/data), or a
/// newer server pack once it was downloaded and verified (services/content_pack.dart).
class Content {
  final Map<String, Video> videos;
  final List<Clip> clips;
  final Map<String, Clip> byId;
  final Map<String, DictEntry> dict;
  /// Curated first clips for everyone, in order (scripts/content/pick_starter.py).
  final List<StarterClip> starter;
  final Map<String, ClipNotes> _notes = {};
  final Map<String, Future<Map<String, dynamic>?>> _shards = {};

  Content._(this.videos, this.clips, this.dict, List<String> starterIds) : byId = {for (final c in clips) c.id: c}, starter = [] {
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

  Future<ClipNotes> notes(String clipId) async {
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
