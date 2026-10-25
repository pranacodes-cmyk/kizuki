import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/data/paywall.dart';

void main() {
  test('yearly is \$54.99 with a 7-day free trial by default', () {
    expect(plans['yearly']!.price, '\$54.99');
    expect(priceLine(plans['yearly']!), '7 days free, then \$54.99/year');
  });
  test('monthly is \$10.99 and has no trial', () {
    expect(plans['monthly']!.price, '\$10.99');
    expect(priceLine(plans['monthly']!), '\$10.99/month, billed today');
  });
  test('trial experiment copy follows the server day count', () {
    expect(priceLine(plans['yearly']!, days: 3), '3 days free, then \$54.99/year');
    expect(trialBadge(3), '3 days free · Cancel anytime');
    expect(trialCta(3), 'Start my free trial');
    expect(trialCta(7), 'Start my free week');
    expect(purchaseToast(3), 'Your free trial has started');
    final t = trialTimeline(3);
    expect(t[1].$1, 'Day 1');
    expect(t[2].$1, 'Day 3');
  });
  test('0 days is a direct paywall with no trial wording', () {
    expect(priceLine(plans['yearly']!, days: 0), '\$54.99/year, billed today');
    expect(trialBadge(0), 'No commitment · Cancel anytime');
    expect(trialCta(0), 'Start learning today');
    expect(purchaseToast(0), 'Welcome to Premium');
  });
}
