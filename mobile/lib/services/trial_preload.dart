import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/content.dart';

/// Prepare content, notes, poster and the official player's own code; never create a player.
///
/// The YouTube player runs inside a WebView, which has its own network stack and HTTP cache:
/// warming from Dart did not help it. So a blank, never-shown WebView (no player, no video,
/// no sound) starts the browser engine early and fills the WebView cache with YouTube's
/// player scripts (base.js is ~1.6 MB and cacheable for a year). The trial preview's real
/// player then skips the engine start-up and that download. Mirrors trialPreload in web.
class TrialPreload {
  static bool _started = false;
  static WebViewController? _engine;

  static void start(BuildContext context) {
    if (_started) return;
    _started = true;
    unawaited(_prepare(context).catchError((_) { _started = false; }));
  }

  static Future<void> _prepare(BuildContext context) async {
    final content = await Content.load();
    if (content.starter.isEmpty) return;
    final clip = content.byId[content.starter.first.id];
    if (clip == null) return;
    _warmPlayerCode(clip.videoId);
    unawaited(content.notes(clip.id));
    if (context.mounted) unawaited(precacheImage(NetworkImage(clip.thumb), context).catchError((_) {}));
  }

  /// Same host/baseUrl as youtube_player_iframe (privacy-enhanced mode), so the cached files
  /// land in the cache partition the real player reads from.
  static const _host = 'https://www.youtube-nocookie.com';

  static void _warmPlayerCode(String videoId) {
    if (_engine != null) return;
    try {
      final c = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
      _engine = c;
      unawaited(c.loadHtmlString(warmupHtml(videoId), baseUrl: _host).catchError((_) {}));
      // Scripts are cached by then; drop the page so it holds no memory or timers.
      Timer(const Duration(seconds: 20), () {
        unawaited(c.loadRequest(Uri.parse('about:blank')).catchError((_) {}));
      });
    } catch (_) {
      // No WebView platform (tests) or engine unavailable: warming is best-effort only.
      _engine = null;
    }
  }
}

/// Blank page: connections + YouTube's public player scripts only. It never calls
/// `new YT.Player`, so no player, video stream or sound is ever created.
@visibleForTesting
String warmupHtml(String videoId) {
  final id = RegExp(r'^[A-Za-z0-9_-]{6,20}$').hasMatch(videoId) ? videoId : '';
  return '''<!doctype html><html><head><meta charset="utf-8">
<link rel="preconnect" href="https://www.youtube.com">
<link rel="preconnect" href="https://www.youtube-nocookie.com">
<link rel="preconnect" href="https://i.ytimg.com">
<link rel="preconnect" href="https://www.google.com">
</head><body>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
(function(){
  var id = "$id";
  if (!id) return;
  fetch("/embed/" + id).then(function(r){ return r.text(); }).then(function(t){
    t = t.split("\\\\/").join("/");
    var re = /(?:https:\\/\\/www\\.youtube(?:-nocookie)?\\.com)?\\/s\\/player\\/[^"'\\\\\\s]+?\\.(?:js|css)/g, seen = {}, m;
    while ((m = re.exec(t))) {
      if (seen[m[0]]) continue;
      seen[m[0]] = 1;
      fetch(m[0], { mode: "no-cors" }).catch(function(){});
    }
  }).catch(function(){});
})();
</script></body></html>''';
}
