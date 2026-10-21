import 'package:integration_test/integration_test_driver.dart';

/// Host side of `flutter drive` for integration_test/ (used by .github/scripts/e2e.sh).
Future<void> main() => integrationDriver();
