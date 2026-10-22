import 'package:flutter_test/flutter_test.dart';
import 'package:mimi/data/paywall.dart';

void main() {
  test('yearly is \$54.99 with a 7-day free trial', () {
    expect(plans['yearly']!.price, '\$54.99');
    expect(priceLine(plans['yearly']!), '7 days free, then \$54.99/year');
  });
  test('monthly is \$10.99 and has no trial', () {
    expect(plans['monthly']!.price, '\$10.99');
    expect(priceLine(plans['monthly']!), '\$10.99/month, billed today');
    expect(priceLine(plans['yearly']!, trial: false), '\$54.99/year, billed today');
  });
}
