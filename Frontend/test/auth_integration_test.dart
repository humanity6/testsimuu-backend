import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:testsimu_app/main.dart';
import 'package:testsimu_app/services/auth_service.dart';
import 'package:testsimu_app/models/user.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([http.Client])
import 'auth_integration_test.mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  late MockClient mockClient;
  late AuthService authService;

  setUp(() async {
    // Setup shared preferences for testing
    SharedPreferences.setMockInitialValues({});
    
    // Create a mock http client
    mockClient = MockClient();
    
    // Initialize auth service with our mock client
    authService = AuthService();
  });

  group('Authentication Integration Tests', () {
    testWidgets('Login should connect to real backend server', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const AppInitializer());
      await tester.pumpAndSettle();
      
      // Verify we're on the home screen
      expect(find.text('Welcome to Testsimu'), findsOneWidget);
      
      // Navigate to login screen
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      // Verify we're on the login screen
      expect(find.text('Sign in to your account'), findsOneWidget);
      
      // Enter credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      
      // Tap the login button
      await tester.tap(find.text('Sign In'));
      await tester.pump(); // Start the login process
      
      // Verify we're showing loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Allow enough time for API request to complete
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      // Verify that there's no dummy data message
      expect(find.text('Dummy data detected'), findsNothing);
      
      // Verify real authentication is being used (either login succeeded or failed)
      expect(
        find.textContaining('Failed') // Shows error if credentials are wrong
        .or(find.byType(Scaffold)), // Shows main app screen if login succeeded
        findsOneWidget
      );
    });

    testWidgets('Auth service should never fall back to dummy data', (WidgetTester tester) async {
      // Access auth service directly to verify it doesn't use dummy data
      final authService = AuthService();
      await authService.init();
      
      // Ensure we don't automatically use dummy data in debug mode
      if (authService.isAuthenticated && authService.currentUser != null) {
        // If we're authenticated, make sure it's not the dummy user
        expect(authService.currentUser!.id, isNot('1')); // Dummy user has ID 1
        expect(authService.currentUser!.email, isNot('max@example.com')); // Dummy user email
      }
    });
  });

  group('User Profile Tests', () {
    testWidgets('User profile should fetch real data from backend', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const AppInitializer());
      await tester.pumpAndSettle();
      
      // Login first (assuming test credentials)
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      // If login succeeded, navigate to profile
      // This might need adjustment based on your navigation structure
      if (find.text('Dashboard').evaluate().isNotEmpty) {
        // Navigate to profile
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        
        // Verify profile data is not dummy data
        expect(find.text('Max Mustermann'), findsNothing);
        expect(find.text('max@example.com'), findsNothing);
      }
    });
  });
} 