import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/services/billing.dart';
import 'package:mimi/state/app_state.dart';

void main() {
  test('learner sync cannot overwrite live device Premium', () {
    final app = AppState();
    app.premium = Premium(active: true, expiresAt: 1924905600000);
    app.replaceAll({'onboarded': true, 'premium': {'active': false}});
    expect(app.premium.active, isTrue);
    expect(app.premium.expiresAt, 1924905600000);
    expect(app.onboarded, isTrue);
    app.dispose();
  });
  test('cloud Premium cannot unlock an unverified device', () {
    final app = AppState();
    app.replaceAll({'premium': {'active': true, 'expiresAt': 1924905600000}});
    expect(app.premium.active, isFalse);
    app.dispose();
  });
  test('a phone without a usable store is expected, not an app error', () {
    // The exact error RevenueCat gives on an emulator without Google Play billing.
    final noPlay = PlatformException(code: '3', message: 'The device or user is not allowed to make the purchase.', details: {
      'readableErrorCode': 'PurchaseNotAllowedError',
      'underlyingErrorMessage': 'Billing is not available in this device. ErrorCode: BILLING_UNAVAILABLE.',
    });
    expect(Billing.storeUnavailable(noPlay), isTrue);
    expect(Billing.storeUnavailable(PlatformException(code: '10', message: 'Network error')), isFalse);
    expect(Billing.storeUnavailable(StateError('offerings missing')), isFalse);
  });
}
