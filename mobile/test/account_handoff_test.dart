import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/logic/logic.dart';
import 'package:mimi/services/auth_links.dart';
import 'package:mimi/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Browser sign-in hand-off (kizuki://auth) and account-scoped learner progress.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthLinks.I.onSession = null;
    AuthLinks.I.onUnclaimed = null;
    AuthLinks.I.pending = null;
  });

  test('the refresh token is read from the web payload (camelCase) or snake_case', () {
    expect(AuthLinks.refreshTokenOf('{"accessToken":"a","refreshToken":"r1"}'), 'r1');
    expect(AuthLinks.refreshTokenOf('{"refresh_token":"r2"}'), 'r2');
    expect(AuthLinks.refreshTokenOf('{"refreshToken":""}'), isNull);
    expect(AuthLinks.refreshTokenOf('not json'), isNull);
    expect(AuthLinks.refreshTokenOf('[1]'), isNull);
  });

  test('an open account screen receives the hand-off', () {
    String? got;
    AuthLinks.I.onSession = (s) => got = s;
    AuthLinks.I.handleForTest(Uri.parse('kizuki://auth?session=%7B%22refreshToken%22%3A%22r%22%7D'));
    expect(got, '{"refreshToken":"r"}');
    expect(AuthLinks.I.pending, isNull);
  });

  test('with no account screen open the hand-off is installed, never dropped', () async {
    final installed = <String>[];
    AuthLinks.I.onUnclaimed = (s) async => installed.add(s);
    AuthLinks.I.handleForTest(Uri.parse('kizuki://auth?session=abc'));
    await Future<void>.delayed(Duration.zero);
    expect(installed, ['abc']);
    expect(AuthLinks.I.pending, isNull);
  });

  test('a hand-off that arrives before the app is ready waits as pending', () {
    AuthLinks.I.handleForTest(Uri.parse('kizuki://auth?session=abc'));
    expect(AuthLinks.I.takePending(), 'abc');
    expect(AuthLinks.I.takePending(), isNull);
  });

  test('other links are ignored', () {
    AuthLinks.I.handleForTest(Uri.parse('https://example.com/auth?session=abc'));
    AuthLinks.I.handleForTest(Uri.parse('kizuki://other?session=abc'));
    AuthLinks.I.handleForTest(Uri.parse('kizuki://auth'));
    expect(AuthLinks.I.pending, isNull);
  });

  test('store-verified Premium changes never make old learner data look newer', () {
    final app = AppState();
    app.updatedAt = 42;
    app.applyPremium(Premium(active: true, plan: 'yearly'));
    expect(app.premium.active, isTrue);
    expect(app.updatedAt, 42);
  });

  test("signing into another account starts clean; the previous learner's words stay out", () {
    final app = AppState();
    app.replaceAll({...app.toJson(), 'owner': 'u1', 'onboarded': true});
    final scoped = localStateFor(app.toJson(), 'u2');
    expect(scoped['owner'], 'u2');
    expect(scoped['onboarded'], isTrue);
    expect(scoped.containsKey('words'), isFalse);
    expect(scoped.containsKey('profile'), isFalse);
    app.replaceAll(scoped);
    expect(app.toJson()['owner'], 'u2');
    expect(app.words, isEmpty);
  });

  test('a late saved-state load keeps the account step but never revives saved Premium', () async {
    SharedPreferences.setMockInitialValues({
      storageKey: '{"onboarded":true,"purchaseAccountPending":true,"owner":"u1","premium":{"active":true,"plan":"yearly"},"updatedAt":9}',
    });
    final app = AppState()..loadIsLate = true;
    await app.load();
    expect(app.purchaseAccountPending, isTrue);
    expect(app.onboarded, isTrue);
    expect(app.premium.active, isFalse);
    expect(app.toJson()['owner'], 'u1');
  });
}
