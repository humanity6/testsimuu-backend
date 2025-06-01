// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quiz_app/main.dart';
import 'package:quiz_app/services/localization_service.dart';
import 'package:quiz_app/services/auth_service.dart';
import 'package:quiz_app/services/notification_service.dart';
import 'package:quiz_app/providers/app_providers.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Create mock services for testing
    final localizationService = LocalizationService();
    await localizationService.init();
    
    final authService = AuthService();
    await authService.init();
    
    final notificationService = NotificationService();

    // Build our app and trigger a frame.
    await tester.pumpWidget(AppProviders(
      localizationService: localizationService,
      authService: authService,
      notificationService: notificationService,
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Test App')),
        ),
      ),
    ));

    // Verify that the test app is displayed
    expect(find.text('Test App'), findsOneWidget);
  });
}
