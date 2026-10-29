import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import '../data/content.dart';
import '../logic/logic.dart';
import '../state/app_state.dart';

/// Small shared native snapshot; never exports the learner document or private notes.
class HomeWidgets {
  static const channel = MethodChannel('com.kizukijapan.app/widgets');
  static AppState? _app;
  static Content? _content;
  static List<WidgetWord>? _public;
  static String? _last;
  static String? _owner;
  static int _generation = 0;
  static Future<void> _queue = Future.value();
  static StreamSubscription<Uri>? _links;
  static void Function(String)? onOpen;
  static String? pending;

  static List<WidgetWord> publicWords(Content c) {
    final cached = _public;
    if (identical(c, _content) && cached != null) return cached;
    final locations = <String, String>{};
    for (final clip in c.clips) {
      for (final line in clip.lines) {
        for (final w in line.words) {
          if (w.d != null) locations.putIfAbsent(w.d ?? '', () => clip.id);
        }
      }
    }
    final result = [for (final e in c.dict.entries)
      if (e.value.c && e.value.j != null && locations.containsKey(e.key))
        WidgetWord(key: e.key, word: e.value.w, reading: e.value.r, meaning: e.value.gloss, jlpt: e.value.j ?? 5, clipId: locations[e.key] ?? '', example: e.value.ex.isEmpty ? '' : e.value.ex.first.ja)];
    if (identical(c, _content)) _public = result;
    return result;
  }

  static List<WidgetWord> words(AppState a, Content c) => widgetWords(publicWords(c), [for (final w in a.words.values)
    WidgetWord(key: w.key, word: w.word, reading: w.reading, meaning: w.gloss, clipId: w.clipId, status: w.status, due: w.card.due)], a.profile.jlpt, a.settings.widgetSaved, a.now);

  static void start(AppState app) {
    if (kIsWeb) return;
    _app = app;
    _owner = app.owner;
    app.addListener(refresh);
    // Remove any snapshot from the previous process before loading public content.
    _send(null);
    Content.load().then((c) { _content = c; refresh(); }, onError: (Object _) {});
    final links = AppLinks();
    _links = links.uriLinkStream.listen(_open, onError: (Object _) {});
    links.getInitialLink().then((u) { if (u != null) _open(u); }, onError: (Object _) {});
  }

  static void _open(Uri uri) {
    final destination = widgetDestination(uri.toString());
    if (destination == null) return;
    final cb = onOpen;
    if (cb == null) { pending = destination; } else { cb(destination); }
  }

  static void _send(String? json) {
    final generation = ++_generation;
    _queue = _queue.then((_) async {
      if (generation != _generation) return;
      try { await channel.invokeMethod<void>('publish', json); } catch (_) { /* Native plugin missing must not break learning. */ }
    });
  }

  static void refresh() {
    final a = _app, c = _content;
    if (a == null) return;
    if (_owner != a.owner) { _owner = a.owner; _last = null; _send(null); }
    if (c == null) return;
    final pool = words(a, c);
    final publicPool = widgetWords(publicWords(c), [], a.profile.jlpt, false, a.now);
    final base = (a.now ~/ widgetSlotMs) * widgetSlotMs;
    final payload = jsonEncode({'version': 1, 'base': base, 'expires': base + 12 * widgetSlotMs,
      'personal': a.settings.widgetSaved && a.words.values.any((w) => w.status == 'learning'),
      'reading': a.settings.widgetReading, 'meaning': a.settings.widgetMeaning,
      'due': a.settings.widgetSaved ? a.dueKeys.length : 0, 'streak': a.settings.widgetSaved ? a.streak : 0,
      'words': pool.map((w) => w.toJson()).toList(), 'fallback': publicPool.map((w) => w.toJson()).toList()});
    if (payload == _last) return;
    _last = payload;
    _send(payload);
  }

  static Future<bool> requestPin(bool wide) async {
    try { return await channel.invokeMethod<bool>('pin', wide) ?? false; } catch (_) { return false; }
  }

  static void dispose() {
    _app?.removeListener(refresh);
    _links?.cancel();
    onOpen = null;
  }
}