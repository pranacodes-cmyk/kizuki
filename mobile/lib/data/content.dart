import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logic/logic.dart';
import 'models.dart';

/// Loads the bundled clip library + dictionary (same files as web public/data).
class Content {
  final Map<String, Video> videos;
  final List<Clip> clips;
  final Map<String, Clip> byId;
  final Map<String, DictEntry> dict;
  final Map<String, ClipNotes> _notes = {};

  Content._(this.videos, this.clips, this.dict) : byId = {for (final c in clips) c.id: c};

  static Content? _instance;
  static Future<Content>? _loading;
  static Content get I => _instance!;

  static Future<Content> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    return _loading ??= _loadOnce();
  }

  static Future<Content> _loadOnce() async {
    try {
    final raw = await rootBundle.loadString('assets/data/content.json');
    final dictRaw = await rootBundle.loadString('assets/data/dict.json');
    final parsed = await compute(_parse, [raw, dictRaw]);
    _instance = Content._(parsed.$1, parsed.$2, parsed.$3);
    return _instance!;
    } finally {
      _loading = null;
    }
  }

  /// Test hook: build from in-memory JSON.
  static Content fromJson(String raw, String dictRaw) {
    final p = _parse([raw, dictRaw]);
    _instance = Content._(p.$1, p.$2, p.$3);
    return _instance!;
  }

  static (Map<String, Video>, List<Clip>, Map<String, DictEntry>) _parse(List<String> input) {
    final j = jsonDecode(input[0]) as Map<String, dynamic>;
    final videos = (j['videos'] as Map<String, dynamic>).map((k, v) => MapEntry(k, Video(v['title'] as String, v['channel'] as String, v['channelUrl'] as String)));
    final clips = (j['clips'] as List).map((c) => Clip.fromJson(c as Map<String, dynamic>)).toList();
    final d = (jsonDecode(input[1]) as Map<String, dynamic>).map((k, v) => MapEntry(k, DictEntry.fromJson(v as Map<String, dynamic>)));
    return (videos, clips, d);
  }

  Future<ClipNotes> notes(String clipId) async {
    final cached = _notes[clipId];
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString('assets/data/explain/$clipId.json');
      final n = ClipNotes.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _notes[clipId] = n;
      return n;
    } catch (_) {
      return ClipNotes.empty;
    }
  }

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
