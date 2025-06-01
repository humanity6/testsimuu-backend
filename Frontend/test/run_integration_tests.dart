import 'package:integration_test/integration_test_driver.dart' as driver;

/// This is the main entry point for running all integration tests together.
/// 
/// To run: flutter drive --driver=test/run_integration_tests.dart --target=test/all_tests.dart
///
/// This assumes you have a file called all_tests.dart that imports and runs all your 
/// integration tests.

Future<void> main() async {
  await driver.integrationDriver(
    timeout: const Duration(minutes: 5),
  );
} 