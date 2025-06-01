import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../utils/api_config.dart';

class UserService extends ChangeNotifier {
  // Singleton instance
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Fetch user profile data
  Future<User> fetchUserProfile(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.userProfileEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Create user from the backend data using fromJson factory
        return User.fromJson(data);
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user profile: $e');
      }
      rethrow;
    }
  }

  // Fetch user performance summary
  Future<Map<String, dynamic>> fetchPerformanceSummary(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.performanceSummaryEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load performance summary: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching performance summary: $e');
      }
      // Return empty data on error
      return {
        'completed_sessions': 0,
        'average_score': 0,
        'total_questions_answered': 0,
        'correct_answers': 0,
      };
    }
  }

  // Fetch user performance by topic
  Future<List<Map<String, dynamic>>> fetchPerformanceByTopic(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.performanceByTopicEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load performance by topic: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching performance by topic: $e');
      }
      // Return empty list on error
      return [];
    }
  }

  // Fetch user performance trends over time
  Future<List<Map<String, dynamic>>> fetchPerformanceTrends(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.performanceTrendsEndpoint),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response formats
        if (data is List) {
          return data.map((item) => item as Map<String, dynamic>).toList();
        } else if (data is Map) {
          if (data.containsKey('results') && data['results'] is List) {
            return (data['results'] as List).map((item) => item as Map<String, dynamic>).toList();
          } else if (data.containsKey('data_points') && data['data_points'] is List) {
            return (data['data_points'] as List).map((item) => item as Map<String, dynamic>).toList();
          } else {
            // Single object wrapped in a list
            return [data as Map<String, dynamic>];
          }
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to load performance trends: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching performance trends: $e');
      }
      // Return empty list on error
      return [];
    }
  }
  
  // Fetch user progress by topic specifically for profile
  Future<List<Map<String, dynamic>>> fetchUserProgressByTopic(String accessToken) async {
    try {
      // Use optimized endpoint that only returns topics with actual progress
      final response = await http.get(
        Uri.parse('${ApiConfig.progressByTopicEndpoint}?only_with_progress=true'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load progress by topic: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching progress by topic: $e');
      }
      // Fall back to performance by topic in case of error
      try {
        return await fetchPerformanceByTopic(accessToken);
      } catch (_) {
        // Return empty list if both endpoints fail
        return [];
      }
    }
  }
  
  // Fetch FAQs
  Future<List<Map<String, dynamic>>> fetchFAQs() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.faqItemsEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response formats
        if (data is List) {
          return data.map((item) => item as Map<String, dynamic>).toList();
        } else if (data is Map && data.containsKey('results')) {
          return (data['results'] as List).map((item) => item as Map<String, dynamic>).toList();
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to load FAQs: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching FAQs: $e');
      }
      // Return empty list on error - no mock data in production
      return [];
    }
  }
  
  // Fetch FAQ categories
  Future<List<Map<String, dynamic>>> fetchFAQCategories() async {
    try {
      // Since there's no separate categories endpoint, we'll extract categories from FAQ items
      final faqs = await fetchFAQs();
      
      // Extract unique category IDs from FAQs
      final Set<String> uniqueCategoryIds = {};
      final Map<String, String> categoryNames = {};
      
      // First, identify all category IDs from FAQs
      for (final faq in faqs) {
        final categoryId = faq['category_id']?.toString();
        final categoryName = faq['category_name']?.toString();
        if (categoryId != null) {
          uniqueCategoryIds.add(categoryId);
          if (categoryName != null) {
            categoryNames[categoryId] = categoryName;
          }
        }
      }
      
      // Then create category objects
      final List<Map<String, dynamic>> categories = [];
      for (final id in uniqueCategoryIds) {
        categories.add({
          'id': id,
          'name': categoryNames[id] ?? 'Category $id',
        });
      }
      
      // Return categories (empty if none found)
      return categories;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching FAQ categories: $e');
      }
      // Return empty list on error - no mock data in production
      return [];
    }
  }
} 