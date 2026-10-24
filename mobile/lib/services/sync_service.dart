import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/logic.dart';
import '../state/app_state.dart';
import 'config.dart';
import 'auth_links.dart';
import 'billing.dart';
import 'analytics.dart';

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
    // The backend may already be connecting for an early sign-in hand-off; sync still
    // starts for this app once it is ready.
    return ensureBackend().then((ok) {
      if (ok) start(app);
      return ok;
    });
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
    _setSession(_db.auth.currentSession);
    if (session != null) syncNow();
    _db.auth.onAuthStateChange.listen((data) {
      final e = data.event;
      if (e != AuthChangeEvent.signedIn && e != AuthChangeEvent.signedOut && e != AuthChangeEvent.userUpdated && e != AuthChangeEvent.tokenRefreshed) return;
      final was = session != null;
      _setSession(data.session);
      notifyListeners();
      if (e == AuthChangeEvent.signedIn && !was) syncNow();
    });
  }

  /// Bumped whenever the signed-in account changes (sign-in, sign-out, switch). A sync
  /// started for one account discards its result if the account changed meanwhile, so
  /// one learner's progress can never be merged into or uploaded under another account.
  int _generation = 0;
  String? _userId;

  /// Updates the session; a different account cancels pending pushes and in-flight syncs.
  void setSession(Session? s) => _setSession(s);

  void _setSession(Session? s) {
    final id = s?.user.id;
    if (id != _userId) {
      _generation++;
      _userId = id;
      _timer?.cancel();
      _inflight = null;
      unawaited(Billing.identify(id));
      Analytics.identity(id);
    }
    session = s;
  }

  bool _current(int gen, String uid) => gen == _generation && session?.user.id == uid;

  @visibleForTesting
  int get generation => _generation;
  @visibleForTesting
  bool isCurrent(int gen, String uid) => _current(gen, uid);

  /// Pull the cloud copy, merge it into this device and push the result back.
  Future<void> syncNow() {
    final existing = _inflight;
    if (existing != null) return existing;
    final f = _pullAndMerge();
    _inflight = f;
    return f.whenComplete(() {
      if (identical(_inflight, f)) _inflight = null;
    });
  }

  Future<void> _pullAndMerge() async {
    final s = session;
    if (s == null || !_started) return; // start() syncs as soon as the app is attached
    final gen = _generation, uid = s.user.id;
    try {
      final row = await _db.from('learner_state').select('state').eq('user_id', uid).maybeSingle();
      if (!_current(gen, uid)) return; // account changed while the cloud copy loaded
      // Another account's progress on this device never merges into this account.
      final local = localStateFor(_app.toJson(), uid);
      final remote = (row?['state'] as Map?)?.cast<String, dynamic>();
      final merged = remote != null ? {...mergeState(local, remote), 'owner': uid} : local;
      _app.replaceAll(merged);
      await _push(s, gen, merged);
    } catch (e) {
      debugPrint('sync pull failed: $e');
    }
  }

  /// Installs a session handed back by the browser sign-in (kizuki://auth). Its refresh
  /// token is exchanged for a fresh session; the web page already dropped its own copy.
  Future<void> installHandoff(String sessionJson) async {
    final refresh = AuthLinks.refreshTokenOf(sessionJson);
    if (refresh == null) throw const AuthException("Sign-in didn't finish. Please try again.");
    if (!await ensureBackend()) throw const AuthException("You're offline. Check your connection and try again.");
    final res = await _db.auth.setSession(refresh);
    _setSession(res.session ?? _db.auth.currentSession);
    notifyListeners();
  }

  Future<void> push([Map<String, dynamic>? state]) async {
    final s = session;
    if (s == null || !_started) return;
    await _push(s, _generation, state);
  }

  Future<void> _push(Session s, int gen, [Map<String, dynamic>? state]) async {
    final uid = s.user.id;
    if (!_current(gen, uid)) return;
    try {
      final payload = state ?? _app.toJson();
      await _db.from('learner_state').upsert({'user_id': uid, 'state': payload});
      if (!_current(gen, uid)) return;
      final metadata = s.user.userMetadata ?? {};
      final name = _app.profile.name.isNotEmpty ? _app.profile.name : (metadata['full_name'] ?? metadata['name'] ?? '').toString();
      await _db.from('profiles').upsert({'id': uid, 'display_name': name, 'avatar_url': metadata['avatar_url'], 'preferences': payload['profile'], 'updated_at': DateTime.now().toUtc().toIso8601String()});
    } catch (e) {
      debugPrint('sync push failed: $e');
    }
  }

  Future<void> signOut() async {
    await push();
    await _db.auth.signOut();
  }
}
