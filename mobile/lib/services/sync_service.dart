import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/logic.dart';
import '../state/app_state.dart';
import 'config.dart';

/// Cloud sync for signed-in learners — mirrors src/lib/sync.ts. The whole learner state
/// lives in one row of public.learner_state (RLS: own row only); on sign-in we pull, merge
/// with mergeState() and push; afterwards changes push debounced.
class SyncService extends ChangeNotifier {
  static final SyncService I = SyncService();
  late AppState _app;
  AppState? _pending;
  Future<bool>? _ready;
  Session? session;
  Timer? _timer;
  Future<void>? _inflight;
  bool _started = false;

  SupabaseClient get _db => Supabase.instance.client;

  /// Connects to the backend in the background after the first frame — the app never
  /// waits for the network to show its UI (offline-first; a slow or failed connection
  /// must never leave the screen blank).
  Future<bool> boot(AppState app) {
    _pending = app;
    return ensureBackend();
  }

  /// Resolves once the backend client is ready (true) or failed to start (false).
  /// Screens that talk to the backend await this first; a failure retries next call.
  Future<bool> ensureBackend() => _ready ??= _init();

  Future<bool> _init() async {
    try {
      await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabasePublishableKey);
      final app = _pending;
      if (app != null) start(app);
      return true;
    } catch (e) {
      debugPrint('backend init failed: $e');
      _ready = null;
      return false;
    }
  }

  void start(AppState app) {
    if (_started) return;
    _started = true;
    _app = app;
    app.onChanged = () {
      if (session == null) return;
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 2500), () => push());
    };
    session = _db.auth.currentSession;
    if (session != null) syncNow();
    _db.auth.onAuthStateChange.listen((data) {
      final e = data.event;
      if (e != AuthChangeEvent.signedIn && e != AuthChangeEvent.signedOut && e != AuthChangeEvent.userUpdated && e != AuthChangeEvent.tokenRefreshed) return;
      final was = session != null;
      session = data.session;
      notifyListeners();
      if (e == AuthChangeEvent.signedIn && !was) syncNow();
    });
  }

  /// Pull the cloud copy, merge it into this device and push the result back.
  Future<void> syncNow() => _inflight ??= _pullAndMerge().whenComplete(() => _inflight = null);

  Future<void> _pullAndMerge() async {
    final s = session;
    if (s == null) return;
    try {
      final row = await _db.from('learner_state').select('state').eq('user_id', s.user.id).maybeSingle();
      final local = _app.toJson();
      final remote = (row?['state'] as Map?)?.cast<String, dynamic>();
      final merged = remote != null ? mergeState(local, remote) : local;
      if (remote != null) _app.replaceAll(merged);
      await push(merged);
    } catch (e) {
      debugPrint('sync pull failed: $e');
    }
  }

  Future<void> push([Map<String, dynamic>? state]) async {
    final s = session;
    if (s == null) return;
    try {
      await _db.from('learner_state').upsert({'user_id': s.user.id, 'state': state ?? _app.toJson()});
    } catch (e) {
      debugPrint('sync push failed: $e');
    }
  }

  Future<void> signOut() async {
    await push();
    await _db.auth.signOut();
  }
}
