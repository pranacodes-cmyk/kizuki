import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session _session(String userId, String token) => Session(
      accessToken: token,
      tokenType: 'bearer',
      user: User(id: userId, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '2026-01-01T00:00:00Z'),
    );

void main() {
  // A cloud sync that started for one account must never be merged into or uploaded under
  // another account that signed in while it was still loading (mirrors src/lib/sync.ts).
  test('a sync started for account A is discarded once account B signs in', () {
    final sync = SyncService();
    sync.setSession(_session('user-a', 't1'));
    final gen = sync.generation;
    expect(sync.isCurrent(gen, 'user-a'), isTrue);

    sync.setSession(_session('user-b', 't2'));
    expect(sync.isCurrent(gen, 'user-a'), isFalse);
    expect(sync.isCurrent(gen, 'user-b'), isFalse);
    expect(sync.isCurrent(sync.generation, 'user-b'), isTrue);
  });

  test('a token refresh for the same account keeps its sync running', () {
    final sync = SyncService();
    sync.setSession(_session('user-a', 't1'));
    final gen = sync.generation;
    sync.setSession(_session('user-a', 't1-refreshed'));
    expect(sync.generation, gen);
    expect(sync.isCurrent(gen, 'user-a'), isTrue);
  });

  test('signing out cancels a sync that is still loading', () {
    final sync = SyncService();
    sync.setSession(_session('user-a', 't1'));
    final gen = sync.generation;
    sync.setSession(null);
    expect(sync.isCurrent(gen, 'user-a'), isFalse);
  });
}
