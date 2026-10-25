import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data/content.dart';

/// Prepare content, notes, poster and official player bootstrap; never create a hidden player.
class TrialPreload {
  static bool _started = false;
  static void start(BuildContext context) {
    if (_started) return;
    _started = true;
    unawaited(_prepare(context).catchError((_) { _started = false; }));
  }
  static Future<void> _prepare(BuildContext context) async {
    // Start connection/bootstrap work immediately, not after the library is parsed.
    final bootstrap = _bootstrap();
    final content = await Content.load();
    if (content.starter.isEmpty) return;
    final clip = content.byId[content.starter.first.id];
    if (clip == null) return;
    unawaited(content.notes(clip.id));
    if (context.mounted) unawaited(precacheImage(NetworkImage(clip.thumb), context).catchError((_) {}));
    await bootstrap;
  }
  static Future<void> _bootstrap() async {
    // The WebView still owns its own cache; this warms DNS/TLS and the public bootstrap only.
    final client = http.Client();
    try {
      await client.get(Uri.parse('https://www.youtube.com/iframe_api')).timeout(const Duration(seconds: 3));
    } catch (_) { /* Network warming is best-effort, never blocks content preparation. */ }
    finally { client.close(); }
  }
}