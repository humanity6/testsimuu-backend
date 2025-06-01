# Testsimu Integration Tests

This directory contains integration tests to verify that the frontend and backend are properly integrated, with no dummy data being used.

## Test Files

- `auth_integration_test.dart` - Tests authentication features (login, registration, profile)
- `exam_integration_test.dart` - Tests exam and quiz features
- `api_endpoint_test.dart` - Verifies API endpoints are accessible and return proper responses
- `service_dummy_data_test.dart` - Specifically checks for absence of dummy data in services
- `all_tests.dart` - Runs all tests together
- `run_integration_tests.dart` - Driver script for running integration tests

## Running the Tests

### Prerequisites

1. Make sure your backend server is running:
   ```
   python manage.py runserver
   ```

2. Ensure you have the required Flutter packages:
   ```
   flutter pub get
   ```

3. Make sure you have a working device or emulator connected:
   ```
   flutter devices
   ```

### Running All Integration Tests

```bash
flutter drive --driver=test/run_integration_tests.dart --target=test/all_tests.dart
```

### Running Individual Test Files

```bash
flutter test integration_test/auth_integration_test.dart
flutter test integration_test/exam_integration_test.dart
flutter test integration_test/api_endpoint_test.dart
flutter test integration_test/service_dummy_data_test.dart
```

## What These Tests Verify

1. **Real Backend Integration**: All tests verify that the app connects to a real backend server, not mock services.

2. **No Dummy Data**: Tests check that no hardcoded or dummy data is being used in the application.

3. **API Structure**: Tests verify that API responses match the expected structure defined in the API documentation.

4. **Authentication Flow**: Tests the entire authentication flow from login to accessing protected resources.

5. **Exam/Quiz Flow**: Tests the exam and quiz functionality to ensure it uses real backend data.

## Test User Credentials

For testing purposes, you can use these credentials:

- Email: `test@example.com`
- Password: `password123`

Note: Make sure this test user exists in your backend database before running the tests. 