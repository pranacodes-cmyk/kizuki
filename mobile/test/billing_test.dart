import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/services/billing.dart';

void main() {
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
