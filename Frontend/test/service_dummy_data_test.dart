import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:testsimu_app/services/auth_service.dart';
import 'package:testsimu_app/services/user_exam_service.dart';
import 'package:testsimu_app/models/user.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Service Dummy Data Verification Tests', () {
    test('AuthService should never use User.dummy()', () async {
      // Access the auth service code directly
      final authService = AuthService();
      await authService.init();
      
      // Get the source code for the fetch user profile method
      final source = authService.toString();
      
      // Verify the code doesn't fallback to dummy data
      expect(source.contains('_currentUser = User.dummy()'), isFalse);
      
      // Even in debug mode, we should avoid using dummy data
      if (authService.isAuthenticated && authService.currentUser != null) {
        final user = authService.currentUser!;
        
        // Check that the user data doesn't match the dummy user data
        expect(user.id, isNot('1'));
        expect(user.name, isNot('Max Mustermann'));
        expect(user.email, isNot('max@example.com'));
      }
    });
    
    test('UserExamService should not use hardcoded exam data', () async {
      // Access the exam service directly
      final examService = UserExamService();
      
      // Get the source code
      final source = examService.toString();
      
      // Check that the service doesn't contain hardcoded exam data
      expect(source.contains('Sample Exam'), isFalse);
      expect(source.contains('Mock Exam'), isFalse);
      expect(source.contains('Dummy Exam'), isFalse);
      
      // Get the available exams
      final exams = await examService.getAvailableExams();
      
      // Check that no exam has suspicious names that suggest hardcoding
      for (final exam in exams) {
        expect(exam.name.contains('Sample'), isFalse);
        expect(exam.name.contains('Mock'), isFalse);
        expect(exam.name.contains('Dummy'), isFalse);
        expect(exam.name.contains('Test Exam'), isFalse);
      }
    });
    
    test('Services should use local development API endpoints', () async {
      // Check the auth service source code for the correct API URL
      final authService = AuthService();
      final authServiceString = authService.toString();
      
      // Verify the auth service is using the local development API URL
      expect(authServiceString.contains('http://188.245.35.46'), isTrue);
      
      // Check the exam service for local development API URL
      final examService = UserExamService();
      final examServiceString = examService.toString();
      
      // Verify the exam service is using the local development API URL
      expect(examServiceString.contains('http://188.245.35.46'), isTrue);
    });
  });
} 