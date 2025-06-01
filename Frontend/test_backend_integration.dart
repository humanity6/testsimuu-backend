import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🔍 Testing Backend Integration...\n');
  
  // Test basic API connectivity
  final baseUrl = 'http://188.245.35.46';
  print('📋 API Configuration:');
  print('Base URL: $baseUrl');
  print('API v1 URL: $baseUrl/api/v1');
  print('');
  
  // Test public endpoints
  print('🌐 Testing Public Endpoints...');
  final publicEndpoints = {
    'base': baseUrl,
    'admin': '$baseUrl/admin/',
    'pricing_plans': '$baseUrl/api/v1/pricing-plans/',
    'faq_items': '$baseUrl/api/v1/faq-items/',
  };
  
  final publicResults = <String, bool>{};
  
  for (final entry in publicEndpoints.entries) {
    try {
      final response = await http.get(
        Uri.parse(entry.value),
      ).timeout(const Duration(seconds: 5));
      
      // Consider 200, 401, 403 as "working" (server is responding)
      publicResults[entry.key] = response.statusCode < 500;
      final status = publicResults[entry.key]! ? '✅' : '❌';
      print('$status ${entry.key}: ${publicResults[entry.key]! ? 'Working' : 'Failed'} (${response.statusCode})');
    } catch (e) {
      publicResults[entry.key] = false;
      print('❌ ${entry.key}: Failed - $e');
    }
  }
  print('');
  
  // Test basic API availability
  print('🔌 Testing Basic API Availability...');
  bool isAvailable = false;
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/'),
    ).timeout(const Duration(seconds: 10));

    // Any response from the admin endpoint means the API is up
    isAvailable = response.statusCode != 404 && response.statusCode != 500;
    print('${isAvailable ? '✅' : '❌'} API Available: $isAvailable (${response.statusCode})');
  } catch (e) {
    print('❌ API Available: false - $e');
  }
  print('');
  
  // Summary
  final workingEndpoints = publicResults.values.where((v) => v).length;
  final totalEndpoints = publicResults.length;
  
  print('📊 Summary:');
  print('Working endpoints: $workingEndpoints/$totalEndpoints');
  print('Overall status: ${workingEndpoints == totalEndpoints ? '✅ All Good' : '⚠️  Some Issues'}');
  
  if (workingEndpoints < totalEndpoints) {
    print('\n🔧 Troubleshooting:');
    print('1. Make sure your Django backend is running');
    print('2. Check if the backend is accessible at $baseUrl');
    print('3. Verify CORS settings in Django');
    print('4. Check Django URL patterns');
  }
  
  exit(0);
} 