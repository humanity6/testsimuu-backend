import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import all test files
import 'auth_integration_test.dart' as auth_tests;
import 'exam_integration_test.dart' as exam_tests;
import 'api_endpoint_test.dart' as api_tests;
import 'service_dummy_data_test.dart' as service_tests;

/// This file runs all the integration tests in the project.
/// It's used as the target for the integration_test_driver.
///
/// To run: flutter drive --driver=test/run_integration_tests.dart --target=test/all_tests.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('All Integration Tests', () {
    // Run all the test groups from each test file
    auth_tests.main();
    exam_tests.main();
    api_tests.main();
    service_tests.main();
  });
} 