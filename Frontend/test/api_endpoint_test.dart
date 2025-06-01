import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Replace with your actual API base URL - using local development server
  final String baseUrl = 'http://188.245.35.46'; 

  group('API Endpoint Tests', () {
    test('Auth endpoints should be accessible', () async {
      // Test login endpoint
      final loginResponse = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        // Send invalid credentials to avoid actually logging in
        body: json.encode({
          'email': 'nonexistent@example.com',
          'password': 'wrong-password',
        }),
      );
      
      // Even with wrong credentials, the endpoint should respond with a proper error
      // rather than a 404 Not Found or 500 Server Error
      expect(loginResponse.statusCode, isNot(404));
      expect(loginResponse.statusCode, isNot(500));
      
      // Test registration endpoint (without actually registering)
      final registerResponse = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        // Just testing the endpoint, not actually registering
        body: json.encode({
          'email': 'test@example.com',
          'password': 'password123',
          'first_name': 'Test',
          'last_name': 'User',
        }),
      );
      
      // Should be a real endpoint, not 404
      expect(registerResponse.statusCode, isNot(404));
    });

    test('Exams endpoint should be accessible', () async {
      // Test exams endpoint
      final examsResponse = await http.get(
        Uri.parse('$baseUrl/api/v1/exams/'),
        headers: {'Content-Type': 'application/json'},
      );
      
      // Should be a real endpoint, not 404
      expect(examsResponse.statusCode, isNot(404));
      
      // Should return JSON data in the expected format
      if (examsResponse.statusCode == 200) {
        final data = json.decode(examsResponse.body);
        
        // Verify the response structure
        expect(data, isA<Map>());
        expect(data.containsKey('results'), isTrue);
        expect(data['results'], isA<List>());
      }
    });
    
    test('Questions endpoint should be accessible', () async {
      // Try to get questions without auth (should fail with 401, not 404)
      final questionsResponse = await http.get(
        Uri.parse('$baseUrl/api/v1/questions/'),
        headers: {'Content-Type': 'application/json'},
      );
      
      // Should be a real endpoint that requires auth (401), not a missing endpoint (404)
      expect(questionsResponse.statusCode, isNot(404));
      expect(questionsResponse.statusCode, 401); // Should require authentication
    });
    
    test('User profile endpoint should be accessible', () async {
      // Try to get user profile without auth (should fail with 401, not 404)
      final profileResponse = await http.get(
        Uri.parse('$baseUrl/api/v1/users/me/'),
        headers: {'Content-Type': 'application/json'},
      );
      
      // Should be a real endpoint that requires auth (401), not a missing endpoint (404)
      expect(profileResponse.statusCode, isNot(404));
      expect(profileResponse.statusCode, 401); // Should require authentication
    });
  });
  
  group('API Data Structure Tests', () {
    test('Public endpoints should return properly structured data', () async {
      // Test pricing plans endpoint which is typically public
      final pricingResponse = await http.get(
        Uri.parse('$baseUrl/api/v1/pricing-plans/'),
        headers: {'Content-Type': 'application/json'},
      );
      
      // Should be a real endpoint
      expect(pricingResponse.statusCode, isNot(404));
      
      if (pricingResponse.statusCode == 200) {
        final data = json.decode(pricingResponse.body);
        
        // Verify the data structure follows API documentation
        expect(data, isA<Map>());
        
        if (data.containsKey('results') && data['results'].isNotEmpty) {
          final firstPlan = data['results'][0];
          
          // Check if the structure matches the expected API response
          expect(firstPlan.containsKey('name'), isTrue);
          expect(firstPlan.containsKey('price'), isTrue);
          expect(firstPlan.containsKey('billing_cycle'), isTrue);
          
          // Verify it's not using dummy data
          expect(firstPlan['name'], isNot('Basic Plan'));
          expect(firstPlan['name'], isNot('Sample Plan'));
        }
      }
    });
  });
} 