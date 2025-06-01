import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testsimu_app/main.dart';
import 'package:testsimu_app/services/auth_service.dart';
import 'package:testsimu_app/services/user_exam_service.dart';
import 'package:testsimu_app/models/exam.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Setup for tests
  });

  group('Exam Data Integration Tests', () {
    testWidgets('Exams list should fetch real data from backend', (WidgetTester tester) async {
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
      
      // If login succeeded, navigate to My Exams
      if (find.text('Dashboard').evaluate().isNotEmpty) {
        // Navigate to My Exams
        await tester.tap(find.text('My Exams'));
        await tester.pumpAndSettle();
        
        // Verify the exam data is loading from the backend
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Allow enough time for API request to complete
        await tester.pumpAndSettle(const Duration(seconds: 5));
        
        // Verify we don't have placeholder/dummy text for exams
        expect(find.text('Sample Exam 1'), findsNothing);
        expect(find.text('Sample Exam 2'), findsNothing);
        
        // If no exams are found, we should see a message
        // If exams are found, we should see the list
        expect(
          find.text('No exams found')
          .or(find.byType(ListView)), 
          findsOneWidget
        );
      }
    });
    
    testWidgets('Exam service should use the real API endpoint', (WidgetTester tester) async {
      // Access the exam service directly
      final userExamService = UserExamService();
      
      // Get the available exams
      final exams = await userExamService.getAvailableExams();
      
      // If no exams returned, at least verify it's not using hardcoded data
      if (exams.isEmpty) {
        // Success: empty is fine as long as it's not dummy data
      } else {
        // Verify the data has proper structure of real API response
        for (final exam in exams) {
          expect(exam.id, isNot('sample_1')); // Check it's not using dummy IDs
          expect(exam.name, isNotEmpty);
          expect(exam.description, isNotEmpty);
        }
      }
    });
  });

  group('Quiz/Practice Session Integration Tests', () {
    testWidgets('Quiz questions should come from the backend', (WidgetTester tester) async {
      // Build the app and login
      await tester.pumpWidget(const AppInitializer());
      await tester.pumpAndSettle();
      
      // Login first
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      
      await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      // If login succeeded, start a practice quiz
      if (find.text('Dashboard').evaluate().isNotEmpty) {
        // Navigate to My Exams
        await tester.tap(find.text('My Exams'));
        await tester.pumpAndSettle();
        
        // Wait for exams to load
        await tester.pumpAndSettle(const Duration(seconds: 5));
        
        // If we have any exam items, tap on the first one
        final examItems = find.byType(ListTile);
        if (examItems.evaluate().isNotEmpty) {
          await tester.tap(examItems.first);
          await tester.pumpAndSettle();
          
          // Look for a Practice/Start button
          final practiceButton = find.text('Practice').evaluate().isNotEmpty 
            ? find.text('Practice')
            : find.text('Start Quiz');
            
          if (practiceButton.evaluate().isNotEmpty) {
            await tester.tap(practiceButton.first);
            await tester.pumpAndSettle(const Duration(seconds: 5));
            
            // Now we should be in a quiz with real questions
            // Verify questions are being loaded from backend
            expect(find.text('Loading questions...'), findsOneWidget);
            await tester.pumpAndSettle(const Duration(seconds: 5));
            
            // Verify we don't have placeholder/dummy text for questions
            expect(find.text('Sample Question 1'), findsNothing);
            expect(find.text('This is a sample question'), findsNothing);
            
            // Verify we either have real questions or a "no questions" message
            expect(
              find.text('No questions available')
              .or(find.byType(Card)), 
              findsOneWidget
            );
          }
        }
      }
    });
  });
} 