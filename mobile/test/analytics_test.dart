import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mimi/services/analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('no analytics until an explicit choice; withdrawal persists refusal', () async {
    SharedPreferences.setMockInitialValues({});
    await Analytics.load();
    expect(Analytics.choice.value, isNull);
    Analytics.track('paywall_viewed'); // No SDK initialized before consent.
    await Analytics.setChoice(false);
    expect(Analytics.choice.value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('kizuki-analytics-choice'), isFalse);
    expect(prefs.getString('kizuki-analytics-notice'), 'posthog-2026-10-24');
  });
  test('withdrawal preserves prior acceptance evidence', () async {
    SharedPreferences.setMockInitialValues({'kizuki-analytics-accepted-at': '2026-10-24T16:48:00Z'});
    await Analytics.setChoice(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kizuki-analytics-accepted-at'), '2026-10-24T16:48:00Z');
  });
}