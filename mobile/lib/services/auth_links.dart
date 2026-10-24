import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, visibleForTesting;

/// Handles the `kizuki://auth` hand-off from the browser sign-in flow
/// (mirrors the `bridge` mode of src/routes/account.tsx).
///
/// Sign-in happens on the published web origin (managed Google / Apple broker). When it
/// completes, the web page drops its own copy of the session and opens this link with the
/// session payload; the account screen exchanges its refresh token for a fresh session.
class AuthLinks {
  AuthLinks._();
  static final AuthLinks I = AuthLinks._();

  AppLinks? _links;

  /// Set by AccountScreen while it is mounted. Called with the session JSON.
  void Function(String sessionJson)? onSession;

  /// Hand-off that arrived while no screen was listening (cold start). The
  /// account screen consumes it on mount.
  String? pending;

  bool _started = false;

  /// Started at app launch so a link that cold-starts the app is never missed.
  void start() {
    if (_started || kIsWeb) return;
    _started = true;
    try {
      _links = AppLinks();
      _links!.uriLinkStream.listen(_handle, onError: (Object _) {});
      _links!.getInitialLink().then((uri) {
        if (uri != null) _handle(uri);
      }, onError: (Object _) {});
    } catch (_) {
      // A missing link plugin must never stop the app; browser sign-in then shows its
      // "Open browser again" state instead of finishing automatically.
    }
  }

  /// Installs a hand-off nobody on screen is waiting for (cold start, another screen), so
  /// a finished browser sign-in is never lost. The account screen still finishes the step.
  Future<void> Function(String sessionJson)? onUnclaimed;

  void _handle(Uri uri) {
    if (uri.scheme != 'kizuki' || uri.host != 'auth') return;
    final raw = uri.queryParameters['session'];
    if (raw == null || raw.isEmpty) return;
    final cb = onSession;
    if (cb != null) {
      cb(raw);
      return;
    }
    pending = raw;
    final install = onUnclaimed;
    if (install != null) {
      install(raw).then((_) {
        if (pending == raw) pending = null;
      }, onError: (Object e) => debugPrint('KIZUKI_WARN sign-in hand-off: $e'));
    }
  }

  /// Takes a hand-off that arrived before the account screen listened.
  String? takePending() {
    final p = pending;
    pending = null;
    return p;
  }

  /// Refresh token inside a hand-off payload (camelCase from the web page; snake_case
  /// accepted too). Null when the payload is unusable.
  static String? refreshTokenOf(String sessionJson) {
    try {
      final j = jsonDecode(sessionJson);
      if (j is! Map) return null;
      final t = j['refreshToken'] ?? j['refresh_token'];
      return t is String && t.isNotEmpty ? t : null;
    } catch (_) {
      return null;
    }
  }

  /// Test helper: same path a deep link takes.
  @visibleForTesting
  void handleForTest(Uri uri) => _handle(uri);
}
