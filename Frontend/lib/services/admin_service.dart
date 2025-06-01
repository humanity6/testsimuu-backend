import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../models/user.dart';
import '../models/question.dart';
import '../models/topic.dart';
import '../models/ai_alert.dart';
import '../models/subscription.dart';
import '../models/pricing_plan.dart';
import '../models/affiliate.dart';
import '../models/exam.dart';

class AdminService {
  final String baseUrl = ApiConfig.baseUrl;
  final Map<String, String> headers;
  final String? accessToken;
  List<AIAlert>? _cachedAlerts;

  AdminService({required this.accessToken}) 
    : headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${accessToken ?? ''}',
      } {
    // Debug: Print token info (first 20 chars only for security)
    // if (accessToken != null && accessToken.isNotEmpty) {
    //   print('AdminService initialized with token: ${accessToken.substring(0, accessToken.length > 20 ? 20 : accessToken.length)}...');
    // } else {
    //   print('AdminService initialized with no token!');
    // }
  }

  // Getter for cached alerts
  List<AIAlert>? get cachedAlerts => _cachedAlerts;

  // Dashboard Metrics
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    try {
      // Get user metrics - Updated endpoint
      final userMetricsResponse = await http.get(
        Uri.parse('${ApiConfig.adminUsersEndpoint}metrics/'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> metrics = {
        'total_users': 0,
        'active_users': 0,
        'new_users_this_month': 0,
        'verified_users': 0,
        'staff_users': 0,
      };

      if (userMetricsResponse.statusCode == 200) {
        final userMetrics = json.decode(userMetricsResponse.body);
        metrics.addAll(userMetrics);
      } else if (userMetricsResponse.statusCode == 401) {
        throw Exception('Unauthorized: Admin permissions required for user metrics');
      }

      // Get question metrics - Updated endpoint URL to use ViewSet action
      try {
        final questionMetricsResponse = await http.get(
          Uri.parse('${ApiConfig.adminQuestionsEndpoint}metrics/'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));

        if (questionMetricsResponse.statusCode == 200) {
          final questionMetrics = json.decode(questionMetricsResponse.body);
          metrics.addAll(questionMetrics);
        } else if (questionMetricsResponse.statusCode == 401) {
          throw Exception('Unauthorized: Admin permissions required for question metrics');
        } else if (questionMetricsResponse.statusCode == 404) {
          print('Questions metrics endpoint not implemented yet');
          // Add default question metrics
          metrics.addAll({
            'total_questions': 0,
            'active_questions': 0,
            'questions_by_type': {},
            'questions_by_difficulty': {},
          });
        }
      } catch (e) {
        print('Questions metrics endpoint error: $e');
        // Add default question metrics if endpoint fails
        metrics.addAll({
          'total_questions': 0,
          'active_questions': 0,
          'questions_by_type': {},
          'questions_by_difficulty': {},
        });
      }

      return metrics;
    } catch (e) {
      print('Exception when loading dashboard metrics: $e');
      return {
        'total_users': 0,
        'active_users': 0,
        'new_users_this_month': 0,
        'verified_users': 0,
        'staff_users': 0,
        'total_questions': 0,
        'active_questions': 0,
        'questions_by_type': {},
        'questions_by_difficulty': {},
      };
    }
  }

  // User Management - Updated with proper query parameters
  Future<List<User>> getUsers({
    String? searchQuery,
    String? filterBy, // Deprecated - kept for backward compatibility
    bool? isActive,
    bool? isStaff,
    bool? emailVerified,
    String? sortBy,
    String? sortOrder,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }
    
    if (isActive != null) {
      queryParams['is_active'] = isActive.toString();
    }

    if (isStaff != null) {
      queryParams['is_staff'] = isStaff.toString();
    }

    if (emailVerified != null) {
      queryParams['email_verified'] = emailVerified.toString();
    }

    if (sortBy != null && sortBy.isNotEmpty) {
      final orderPrefix = sortOrder == 'desc' ? '-' : '';
      queryParams['ordering'] = '$orderPrefix$sortBy';
      print('Setting ordering parameter: ${queryParams['ordering']}'); // Debug
    }

    final response = await http.get(
      Uri.parse(ApiConfig.adminUsersEndpoint).replace(queryParameters: queryParams),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Handle paginated response (expected format)
      if (data is Map<String, dynamic> && data.containsKey('results')) {
        final results = data['results'];
        if (results is List) {
          return results.map((user) => User.fromJson(user as Map<String, dynamic>)).toList();
        } else {
          throw Exception('Results is not a list: ${results.runtimeType}');
        }
      } 
      // Handle non-paginated response (fallback)
      else if (data is List) {
        return data.map((user) => User.fromJson(user as Map<String, dynamic>)).toList();
      } 
      // Handle unexpected response format
      else {
        throw Exception('Unexpected response format: ${data.runtimeType}');
      }
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else if (response.statusCode == 403) {
      throw Exception('Forbidden: Insufficient admin privileges');
    } else {
      throw Exception('Failed to load users: ${response.statusCode}');
    }
  }

  Future<User> getUserDetails(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.adminUsersEndpoint}$userId/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load user details: ${response.statusCode}');
    }
  }

  Future<User> createUser(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.adminUsersEndpoint),
      headers: headers,
      body: json.encode(userData),
    );

    if (response.statusCode == 201) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create user: ${response.statusCode}');
    }
  }

  Future<User> updateUser(String userId, Map<String, dynamic> userData) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.adminUsersEndpoint}$userId/'),
      headers: headers,
      body: json.encode(userData),
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update user: ${response.statusCode}');
    }
  }

  Future<void> deleteUser(String userId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.adminUsersEndpoint}$userId/'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete user: ${response.statusCode}');
    }
  }

  // User Management Actions
  Future<Map<String, dynamic>> suspendUser(String userId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.adminUsersEndpoint}$userId/suspend/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 400) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Cannot suspend this user');
    } else if (response.statusCode == 403) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Insufficient permissions to suspend this user');
    } else {
      throw Exception('Failed to suspend user: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> resetUserPassword(String userId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.adminUsersEndpoint}$userId/reset_password/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 500) {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Failed to send password reset email');
    } else {
      throw Exception('Failed to reset user password: ${response.statusCode}');
    }
  }

  // Subscription Management - Updated endpoints
  Future<List<Subscription>> getUserSubscriptions(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.adminSubscriptionsEndpoint}?user_id=$userId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['results'] as List).map((sub) => Subscription.fromJson(sub)).toList();
    } else {
      throw Exception('Failed to load user subscriptions: ${response.statusCode}');
    }
  }

  Future<List<Subscription>> getSubscriptions({
    String? userId,
    String? status,
    String? examId,
    bool? expiringSoon,
    bool? expired,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (userId != null) queryParams['user_id'] = userId;
    if (status != null) queryParams['status'] = status;
    if (examId != null) queryParams['exam_id'] = examId;
    if (expiringSoon != null) queryParams['expiring_soon'] = '7'; // 7 days
    if (expired != null) queryParams['expired'] = expired.toString();

    final response = await http.get(
      Uri.parse(ApiConfig.adminSubscriptionsEndpoint).replace(queryParameters: queryParams),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      try {
        final subscriptions = <Subscription>[];
        List<dynamic> results;
        
        // Handle paginated response (expected format)
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          final resultsData = data['results'];
          if (resultsData is List) {
            results = resultsData;
          } else {
            throw Exception('Results is not a list: ${resultsData.runtimeType}');
          }
        } 
        // Handle non-paginated response (fallback)
        else if (data is List) {
          results = data;
        } 
        // Handle unexpected response format
        else {
          throw Exception('Unexpected response format: ${data.runtimeType}');
        }
        
        for (int i = 0; i < results.length; i++) {
          try {
            final sub = results[i];
            subscriptions.add(Subscription.fromJson(sub));
          } catch (e) {
            print('Error parsing subscription at index $i: $e');
            // Continue with other subscriptions instead of failing completely
            continue;
          }
        }
        
        print('Loaded ${subscriptions.length} active subscriptions');
        return subscriptions;
      } catch (e) {
        print('Error parsing subscription data: $e');
        throw Exception('Failed to parse subscription data: $e');
      }
    } else {
      print('Failed to load subscriptions: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to load subscriptions: ${response.statusCode}');
    }
  }

  Future<List<Subscription>> getActiveSubscriptions() async {
    try {
      return await getSubscriptions(status: 'ACTIVE');
    } catch (e) {
      print('Error loading active subscriptions: $e');
      rethrow;
    }
  }

  // Pricing Plans Management
  Future<List<PricingPlan>> getPricingPlans() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.adminPricingPlansEndpoint),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<dynamic> planList;
        
        // Handle paginated response (expected format)
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          final results = data['results'];
          if (results is List) {
            planList = results;
          } else {
            throw Exception('Results is not a list: ${results.runtimeType}');
          }
        } 
        // Handle non-paginated response (fallback)
        else if (data is List) {
          planList = data;
        } 
        // Handle unexpected response format
        else {
          throw Exception('Unexpected response format: ${data.runtimeType}');
        }
        
        // Parse plans with individual error handling
        final List<PricingPlan> pricingPlans = [];
        for (int i = 0; i < planList.length; i++) {
          try {
            final plan = planList[i] as Map<String, dynamic>;
            pricingPlans.add(PricingPlan.fromJson(plan));
          } catch (e) {
            print('Error parsing pricing plan at index $i: $e');
            print('Plan data: ${planList[i]}');
            // Continue with other plans instead of failing completely
            continue;
          }
        }
        
        print('Successfully loaded ${pricingPlans.length} out of ${planList.length} pricing plans');
        return pricingPlans;
      } else {
        throw Exception('Failed to load pricing plans: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error in getPricingPlans: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPricingPlan(Map<String, dynamic> planData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.adminPricingPlansEndpoint),
      headers: headers,
      body: json.encode(planData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create pricing plan: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updatePricingPlan(String planId, Map<String, dynamic> planData) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.adminPricingPlansEndpoint}$planId/'),
      headers: headers,
      body: json.encode(planData),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update pricing plan: ${response.statusCode}');
    }
  }

  Future<void> deletePricingPlan(String planId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.adminPricingPlansEndpoint}$planId/'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete pricing plan: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateSubscription(String subscriptionId, Map<String, dynamic> subscriptionData) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.adminSubscriptionsEndpoint}$subscriptionId/'),
      headers: headers,
      body: json.encode(subscriptionData),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update subscription: ${response.statusCode}');
    }
  }

  // User Performance Analytics
  Future<Map<String, dynamic>> getUserPerformance(String userId) async {
    // Note: Using the general analytics endpoint for admin access
    final response = await http.get(
      Uri.parse('${ApiConfig.apiV1Url}/admin/analytics/user-performance/$userId/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      // Return empty performance data if endpoint doesn't exist
      return {
        'total_questions_answered': 0,
        'average_score': 0.0,
        'study_time_hours': 0,
        'completion_rate': 0.0,
      };
    }
  }

  // Content Management - Updated endpoints
  Future<List<Topic>> getTopics({String? examId}) async {
    try {
      final queryParams = <String, String>{};
      if (examId != null) {
        queryParams['exam_id'] = examId;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.adminTopicsEndpoint).replace(queryParameters: queryParams),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both paginated and non-paginated responses
        if (data is List) {
          return data.map((topic) => Topic.fromJson(topic)).toList();
        } else if (data is Map && data.containsKey('results')) {
          return (data['results'] as List).map((topic) => Topic.fromJson(topic)).toList();
        } else {
          return [];
        }
      } else {
        print('Failed to load topics: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception when loading topics: $e');
      return [];
    }
  }

  Future<Topic> createTopic(Topic topic) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.adminTopicsEndpoint),
        headers: headers,
        body: json.encode(topic.toJson()),
      );

      if (response.statusCode == 201) {
        return Topic.fromJson(json.decode(response.body));
      } else {
        print('Failed to create topic: ${response.statusCode}');
        throw Exception('Failed to create topic: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when creating topic: $e');
      rethrow;
    }
  }

  Future<Topic> updateTopic(String topicId, Topic topic) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.adminTopicsEndpoint}$topicId/'),
        headers: headers,
        body: json.encode(topic.toJson()),
      );

      if (response.statusCode == 200) {
        return Topic.fromJson(json.decode(response.body));
      } else {
        print('Failed to update topic: ${response.statusCode}');
        throw Exception('Failed to update topic: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when updating topic: $e');
      rethrow;
    }
  }

  Future<void> deleteTopic(String topicId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.adminTopicsEndpoint}$topicId/'),
        headers: headers,
      );

      if (response.statusCode != 204) {
        print('Failed to delete topic: ${response.statusCode}');
        throw Exception('Failed to delete topic: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when deleting topic: $e');
      rethrow;
    }
  }

  // Questions Management - Updated with proper filtering
  Future<List<Question>> getQuestions({
    String? examId,
    String? topicId,
    String? questionType,
    String? difficulty,
    String? tagId,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (examId != null) queryParams['exam_id'] = examId;
      if (topicId != null) queryParams['topic_id'] = topicId;
      if (questionType != null) queryParams['question_type'] = questionType;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (tagId != null) queryParams['tag_id'] = tagId;
      if (isActive != null) queryParams['is_active'] = isActive.toString();

      final response = await http.get(
        Uri.parse(ApiConfig.adminQuestionsEndpoint).replace(queryParameters: queryParams),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['results'] as List).map((question) => Question.fromJson(question)).toList();
      } else {
        print('Failed to load questions: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception when loading questions: $e');
      return [];
    }
  }

  Future<Question> createQuestion(Map<String, dynamic> questionData) async {
    print('Creating question with data: ${json.encode(questionData)}');
    final response = await http.post(
      Uri.parse(ApiConfig.adminQuestionsEndpoint),
      headers: headers,
      body: json.encode(questionData),
    );

    print('Create question response: ${response.statusCode}');
    print('Create question response body: ${response.body}');

    if (response.statusCode == 201) {
      return Question.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create question: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Question> updateQuestion(String questionId, Map<String, dynamic> questionData) async {
    print('Updating question $questionId with data: ${json.encode(questionData)}');
    final response = await http.put(
      Uri.parse('${ApiConfig.adminQuestionsEndpoint}$questionId/'),
      headers: headers,
      body: json.encode(questionData),
    );

    print('Update question response: ${response.statusCode}');
    print('Update question response body: ${response.body}');

    if (response.statusCode == 200) {
      return Question.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update question: ${response.statusCode} - ${response.body}');
    }
  }

  Future<Question> getQuestionDetails(String questionId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.adminQuestionsEndpoint}$questionId/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return Question.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load question details: ${response.statusCode}');
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.adminQuestionsEndpoint}$questionId/'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete question: ${response.statusCode}');
    }
  }

  // Tags Management
  Future<List<dynamic>> getTags() async {
    final response = await http.get(
      Uri.parse(ApiConfig.adminTagsEndpoint),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] as List;
    } else {
      throw Exception('Failed to load tags: ${response.statusCode}');
    }
  }

  // Exams Management - Added method to get available exams for question creation
  Future<List<Exam>> getExams() async {
    try {
      // Use the public exams endpoint to get available exams
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/exams/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle paginated response (expected format)
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          final results = data['results'];
          if (results is List) {
            return results.map((exam) => Exam.fromJson(exam as Map<String, dynamic>)).toList();
          } else {
            throw Exception('Results is not a list: ${results.runtimeType}');
          }
        } 
        // Handle non-paginated response (fallback)
        else if (data is List) {
          return data.map((exam) => Exam.fromJson(exam as Map<String, dynamic>)).toList();
        } 
        // Handle unexpected response format
        else {
          throw Exception('Unexpected response format: ${data.runtimeType}');
        }
      } else {
        print('Failed to load exams: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception when loading exams: $e');
      return [];
    }
  }

  // Legacy method for question form compatibility - returns Map format
  Future<List<Map<String, dynamic>>> getExamsForQuestionForm() async {
    try {
      // Use the public exams endpoint to get available exams
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/exams/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle paginated response (expected format)
        if (data is Map<String, dynamic> && data.containsKey('results')) {
          final results = data['results'];
          if (results is List) {
            return List<Map<String, dynamic>>.from(results);
          } else {
            throw Exception('Results is not a list: ${results.runtimeType}');
          }
        } 
        // Handle non-paginated response (fallback)
        else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } 
        // Handle unexpected response format
        else {
          return [];
        }
      } else {
        print('Failed to load exams: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception when loading exams: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createTag(Map<String, dynamic> tagData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.adminTagsEndpoint),
      headers: headers,
      body: json.encode(tagData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create tag: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateTag(String tagId, Map<String, dynamic> tagData) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.adminTagsEndpoint}$tagId/'),
      headers: headers,
      body: json.encode(tagData),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update tag: ${response.statusCode}');
    }
  }

  Future<void> deleteTag(String tagId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.adminTagsEndpoint}$tagId/'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete tag: ${response.statusCode}');
    }
  }

  // AI Analytics and Management - Updated endpoints
  Future<Map<String, dynamic>> getAIUsageStats() async {
    try {
      // Since there's no dedicated AI metrics endpoint, we'll get evaluation logs
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/ai/evaluation-logs/?page=1&page_size=100'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final logs = data['results'] as List? ?? [];
        
        // Calculate basic metrics from evaluation logs
        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        
        int totalEvaluationsLast7Days = 0;
        int totalEvaluations = logs.length;
        double averageResponseTime = 0;
        
        for (final log in logs) {
          if (log['created_at'] != null) {
            final createdAt = DateTime.parse(log['created_at']);
            if (createdAt.isAfter(sevenDaysAgo)) {
              totalEvaluationsLast7Days++;
            }
          }
        }
        
        return {
          'total_evaluations_last_7_days': totalEvaluationsLast7Days,
          'total_evaluations': totalEvaluations,
          'average_response_time_ms': averageResponseTime,
        };
      } else {
        print('Failed to load AI evaluation logs: ${response.statusCode}');
        return {
          'total_evaluations_last_7_days': 0,
          'total_evaluations': 0,
          'average_response_time_ms': 0,
        };
      }
    } catch (e) {
      print('Exception when loading AI usage stats: $e');
      return {
        'total_evaluations_last_7_days': 0,
        'total_evaluations': 0,
        'average_response_time_ms': 0,
      };
    }
  }

  // AI Alerts Management
  Future<List<AIAlert>> getAIAlerts({
    String? alertType,
    String? status,
    String? priority,
    String? relatedTopicId,
    String? relatedQuestionId,
    String? createdAfter,
    String? createdBefore,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (alertType != null) queryParams['alert_type'] = alertType;
      if (status != null) queryParams['status'] = status;
      if (priority != null) queryParams['priority'] = priority;
      if (relatedTopicId != null) queryParams['related_topic_id'] = relatedTopicId;
      if (relatedQuestionId != null) queryParams['related_question_id'] = relatedQuestionId;
      if (createdAfter != null) queryParams['created_after'] = createdAfter;
      if (createdBefore != null) queryParams['created_before'] = createdBefore;

      final response = await http.get(
        Uri.parse('${ApiConfig.adminAIContentAlertsEndpoint}').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List? ?? [];
        return results.map((alert) => AIAlert.fromJson(alert)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Admin permissions required');
      } else {
        print('Failed to fetch AI alerts: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch AI alerts: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when fetching AI alerts: $e');
      throw Exception('Failed to fetch AI alerts: $e');
    }
  }

  Future<AIAlert> getAIAlertDetails(String alertId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.apiV1Url}/admin/ai/content-alerts/$alertId/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return AIAlert.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load alert details: ${response.statusCode}');
    }
  }

  Future<AIAlert> updateAIAlert(String alertId, Map<String, dynamic> alertData) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.apiV1Url}/admin/ai/content-alerts/$alertId/'),
      headers: headers,
      body: json.encode(alertData),
    );

    if (response.statusCode == 200) {
      return AIAlert.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update alert: ${response.statusCode}');
    }
  }

  Future<void> deleteAIAlert(String alertId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.apiV1Url}/admin/ai/content-alerts/$alertId/'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete alert: ${response.statusCode}');
    }
  }

  // AI Evaluation Management
  Future<Map<String, dynamic>> triggerAnswerEvaluation(String userAnswerId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.apiV1Url}/admin/ai/evaluate/answer/'),
      headers: headers,
      body: json.encode({'user_answer_id': userAnswerId}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to trigger evaluation: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> triggerBatchEvaluation() async {
    final response = await http.post(
      Uri.parse('${ApiConfig.apiV1Url}/admin/ai/evaluate/batch/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to trigger batch evaluation: ${response.statusCode}');
    }
  }

  // AI Alert Status Update
  Future<void> updateAlertStatus(String alertId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.adminAIContentAlertsEndpoint}$alertId/'),
        headers: headers,
        body: json.encode({'status': newStatus}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Failed to update alert status: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to update alert status: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when updating alert status: $e');
      throw Exception('Failed to update alert status: $e');
    }
  }

  // Alert Detail Methods (for alert detail screen compatibility)
  Future<Map<String, dynamic>> getAlertDetails(String alertId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/ai/content-alerts/$alertId/'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // Map the backend field names to what the UI expects
        return {
          ...data,
          'notes': data['admin_notes'] ?? '', // Map admin_notes to notes
        };
      } else {
        throw Exception('Failed to load alert details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load alert details: $e');
    }
  }

  Future<void> updateAlert(String alertId, Map<String, dynamic> alertData) async {
    try {
      // Map UI field names to backend field names
      final backendData = {
        'status': alertData['status'],
        'admin_notes': alertData['notes'], // Map notes to admin_notes
        'priority': alertData['priority'],
        'action_taken': alertData['action_taken'],
      };

      final response = await http.patch(
        Uri.parse('${ApiConfig.apiV1Url}/admin/ai/content-alerts/$alertId/'),
        headers: headers,
        body: json.encode(backendData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to update alert: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update alert: $e');
    }
  }

  // Scan Configuration Management
  Future<List<dynamic>> getScanConfigs({
    bool? isActive,
    String? frequency,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (isActive != null) queryParams['is_active'] = isActive.toString();
      if (frequency != null) queryParams['frequency'] = frequency;

      final response = await http.get(
        Uri.parse('${ApiConfig.adminAIContentScanConfigsEndpoint}').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results'] as List? ?? [];
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Admin permissions required');
      } else {
        print('Failed to fetch scan configs: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch scan configs: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when fetching scan configs: $e');
      throw Exception('Failed to fetch scan configs: $e');
    }
  }

  Future<Map<String, dynamic>> createScanConfig(Map<String, dynamic> configData) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.adminAIContentScanConfigsEndpoint}'),
        headers: headers,
        body: json.encode(configData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        print('Failed to create scan config: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to create scan config: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when creating scan config: $e');
      throw Exception('Failed to create scan config: $e');
    }
  }

  Future<void> toggleScanConfig(String configId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.adminAIContentScanConfigsEndpoint}$configId/toggle_active/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Failed to toggle scan config: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to toggle scan config: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when toggling scan config: $e');
      throw Exception('Failed to toggle scan config: $e');
    }
  }

  Future<void> runScanManually(String configId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.adminAIContentScanConfigsEndpoint}$configId/run_scan/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Failed to run scan manually: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to run scan manually: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when running scan manually: $e');
      throw Exception('Failed to run scan manually: $e');
    }
  }

  Future<void> deleteScanConfig(int configId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.apiV1Url}/admin/ai/content-scan-configs/$configId/'),
        headers: headers,
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete scan configuration: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting scan config: $e');
      throw Exception('Failed to delete scan configuration: ${e.toString()}');
    }
  }

  // Support Management
  Future<List<dynamic>> getSupportTickets({
    String? status,
    String? ticketType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (status != null) queryParams['status'] = status;
    if (ticketType != null) queryParams['ticket_type'] = ticketType;

    final response = await http.get(
      Uri.parse('${ApiConfig.apiV1Url}/admin/support/tickets/').replace(queryParameters: queryParams),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] as List;
    } else {
      throw Exception('Failed to load support tickets: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateSupportTicket(String ticketId, Map<String, dynamic> ticketData) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.apiV1Url}/admin/support/tickets/$ticketId/'),
      headers: headers,
      body: json.encode(ticketData),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update support ticket: ${response.statusCode}');
    }
  }

  // Payment Management
  Future<List<dynamic>> getPayments({
    String? userId,
    String? subscriptionId,
    String? status,
    String? fromDate,
    String? toDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (userId != null) queryParams['user_id'] = userId;
    if (subscriptionId != null) queryParams['subscription_id'] = subscriptionId;
    if (status != null) queryParams['status'] = status;
    if (fromDate != null) queryParams['from'] = fromDate;
    if (toDate != null) queryParams['to'] = toDate;

    final response = await http.get(
      Uri.parse('${ApiConfig.apiV1Url}/admin/subscriptions/payments/').replace(queryParameters: queryParams),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] as List;
    } else {
      throw Exception('Failed to load payments: ${response.statusCode}');
    }
  }

  // Referral Program Management
  Future<List<dynamic>> getReferralPrograms({
    bool? isActive,
    String? rewardType,
    String? referrerRewardType,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (isActive != null) queryParams['is_active'] = isActive.toString();
      if (rewardType != null) queryParams['reward_type'] = rewardType;
      if (referrerRewardType != null) queryParams['referrer_reward_type'] = referrerRewardType;

      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/subscriptions/referral-programs/').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results'] as List? ?? [];
      } else {
        print('Failed to load referral programs: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load referral programs: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when loading referral programs: $e');
      throw Exception('Failed to load referral programs: $e');
    }
  }

  Future<Map<String, dynamic>> getReferralProgramDetails(String programId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/subscriptions/referral-programs/$programId/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load referral program details: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when loading referral program details: $e');
      throw Exception('Failed to load referral program details: $e');
    }
  }

  Future<Map<String, dynamic>> createReferralProgram(Map<String, dynamic> programData) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/admin/subscriptions/referral-programs/'),
        headers: headers,
        body: json.encode(programData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        print('Failed to create referral program: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to create referral program: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when creating referral program: $e');
      throw Exception('Failed to create referral program: $e');
    }
  }

  Future<Map<String, dynamic>> updateReferralProgram(String programId, Map<String, dynamic> programData) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.apiV1Url}/admin/subscriptions/referral-programs/$programId/'),
        headers: headers,
        body: json.encode(programData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to update referral program: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to update referral program: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when updating referral program: $e');
      throw Exception('Failed to update referral program: $e');
    }
  }

  Future<void> deleteReferralProgram(String programId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.apiV1Url}/admin/subscriptions/referral-programs/$programId/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 204) {
        print('Failed to delete referral program: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to delete referral program: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when deleting referral program: $e');
      throw Exception('Failed to delete referral program: $e');
    }
  }

  Future<Map<String, dynamic>> toggleReferralProgramStatus(String programId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/admin/subscriptions/referral-programs/$programId/toggle_active/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to toggle referral program status: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to toggle referral program status: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when toggling referral program status: $e');
      throw Exception('Failed to toggle referral program status: $e');
    }
  }

  // User Referral Management
  Future<List<dynamic>> getUserReferrals({
    String? status,
    String? referrerId,
    String? referredUserId,
    String? programId,
    String? fromDate,
    String? toDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (referrerId != null) queryParams['referrer_id'] = referrerId;
      if (referredUserId != null) queryParams['referred_user_id'] = referredUserId;
      if (programId != null) queryParams['program_id'] = programId;
      if (fromDate != null) queryParams['from'] = fromDate;
      if (toDate != null) queryParams['to'] = toDate;

      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/subscriptions/user-referrals/').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results'] as List? ?? [];
      } else {
        print('Failed to load user referrals: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load user referrals: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when loading user referrals: $e');
      throw Exception('Failed to load user referrals: $e');
    }
  }

  Future<Map<String, dynamic>> markReferralRewardsGranted(String referralId, {
    bool grantToReferrer = false,
    bool grantToReferred = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/admin/subscriptions/user-referrals/$referralId/mark_rewards_granted/'),
        headers: headers,
        body: json.encode({
          'grant_to_referrer': grantToReferrer,
          'grant_to_referred': grantToReferred,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to mark referral rewards as granted: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to mark referral rewards as granted: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when marking referral rewards as granted: $e');
      throw Exception('Failed to mark referral rewards as granted: $e');
    }
  }

  // Exam Management
  Future<List<Map<String, dynamic>>> getAdminExams({
    String? search,
    String? parentExamId,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (parentExamId != null) queryParams['parent_exam_id'] = parentExamId;
      if (isActive != null) queryParams['is_active'] = isActive.toString();

      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/exams/exams/').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['results'] ?? []);
      } else {
        print('Failed to load admin exams: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load exams: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when loading admin exams: $e');
      throw Exception('Failed to load exams: $e');
    }
  }

  Future<Map<String, dynamic>> getAdminExamDetails(String examId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/exams/exams/$examId/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load exam details: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when loading exam details: $e');
      throw Exception('Failed to load exam details: $e');
    }
  }

  Future<Map<String, dynamic>> createExam(Map<String, dynamic> examData) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/admin/exams/exams/'),
        headers: headers,
        body: json.encode(examData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        print('Failed to create exam: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to create exam: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when creating exam: $e');
      throw Exception('Failed to create exam: $e');
    }
  }

  Future<Map<String, dynamic>> updateExam(String examId, Map<String, dynamic> examData) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.apiV1Url}/admin/exams/exams/$examId/'),
        headers: headers,
        body: json.encode(examData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to update exam: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to update exam: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when updating exam: $e');
      throw Exception('Failed to update exam: $e');
    }
  }

  Future<void> deleteExam(String examId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.apiV1Url}/admin/exams/exams/$examId/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 204) {
        print('Failed to delete exam: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to delete exam: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when deleting exam: $e');
      throw Exception('Failed to delete exam: $e');
    }
  }

  Future<Map<String, dynamic>> getExamMetrics() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/exams/exams/metrics/'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to load exam metrics: ${response.statusCode} - ${response.body}');
        return {
          'total_exams': 0,
          'active_exams': 0,
          'inactive_exams': 0,
          'exams_with_questions': 0,
          'empty_exams': 0,
          'avg_questions_per_exam': 0.0,
        };
      }
    } catch (e) {
      print('Exception when loading exam metrics: $e');
      return {
        'total_exams': 0,
        'active_exams': 0,
        'inactive_exams': 0,
        'exams_with_questions': 0,
        'empty_exams': 0,
        'avg_questions_per_exam': 0.0,
      };
    }
  }

  // Affiliate Management Methods
  Future<List<AffiliateApplication>> getAffiliateApplications({
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/affiliates/applications/').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final applications = (data['results'] as List)
            .map((app) => AffiliateApplication.fromJson(app))
            .toList();
        return applications;
      } else {
        print('Failed to load affiliate applications: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception when loading affiliate applications: $e');
      return [];
    }
  }

  Future<List<Affiliate>> getAffiliates({
    String? search,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (isActive != null) queryParams['is_active'] = isActive.toString();

      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/affiliates/affiliates/').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final affiliates = (data['results'] as List)
            .map((affiliate) => Affiliate.fromJson(affiliate))
            .toList();
        return affiliates;
      } else {
        print('Failed to load affiliates: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception when loading affiliates: $e');
      return [];
    }
  }

  Future<List<AffiliatePlan>> getAffiliatePlans({
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (isActive != null) queryParams['is_active'] = isActive.toString();

      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/affiliates/plans/').replace(queryParameters: queryParams),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final plans = (data['results'] as List)
            .map((plan) => AffiliatePlan.fromJson(plan))
            .toList();
        return plans;
      } else {
        print('Failed to load affiliate plans: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception when loading affiliate plans: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getAffiliateAnalytics() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/admin/affiliates/analytics/'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to load affiliate analytics: ${response.statusCode} - ${response.body}');
        return {
          'total_affiliates': 0,
          'active_affiliates': 0,
          'total_conversions': 0,
          'total_earnings': 0,
          'pending_applications': 0,
          'monthly_stats': [],
        };
      }
    } catch (e) {
      print('Exception when loading affiliate analytics: $e');
      return {
        'total_affiliates': 0,
        'active_affiliates': 0,
        'total_conversions': 0,
        'total_earnings': 0,
        'pending_applications': 0,
        'monthly_stats': [],
      };
    }
  }

  Future<AffiliateApplication> approveApplication(String applicationId, {String? notes}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/admin/affiliates/applications/$applicationId/approve/'),
        headers: headers,
        body: json.encode({
          if (notes != null) 'admin_notes': notes,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return AffiliateApplication.fromJson(json.decode(response.body));
      } else {
        print('Failed to approve application: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to approve application: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when approving application: $e');
      throw Exception('Failed to approve application: $e');
    }
  }

  Future<AffiliateApplication> rejectApplication(String applicationId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/admin/affiliates/applications/$applicationId/reject/'),
        headers: headers,
        body: json.encode({
          'admin_notes': reason,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return AffiliateApplication.fromJson(json.decode(response.body));
      } else {
        print('Failed to reject application: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to reject application: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when rejecting application: $e');
      throw Exception('Failed to reject application: $e');
    }
  }

  Future<Affiliate> updateAffiliateStatus(String affiliateId, bool isActive) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.apiV1Url}/admin/affiliates/affiliates/$affiliateId/'),
        headers: headers,
        body: json.encode({
          'is_active': isActive,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Affiliate.fromJson(json.decode(response.body));
      } else {
        print('Failed to update affiliate status: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to update affiliate status: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when updating affiliate status: $e');
      throw Exception('Failed to update affiliate status: $e');
    }
  }

  Future<AffiliatePlan> updatePlanStatus(String planId, bool isActive) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.apiV1Url}/admin/affiliates/plans/$planId/'),
        headers: headers,
        body: json.encode({
          'is_active': isActive,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return AffiliatePlan.fromJson(json.decode(response.body));
      } else {
        print('Failed to update plan status: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to update plan status: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when updating plan status: $e');
      throw Exception('Failed to update plan status: $e');
    }
  }

  Future<AffiliatePlan> createAffiliatePlan(Map<String, dynamic> planData) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/admin/affiliates/plans/'),
        headers: headers,
        body: json.encode(planData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        return AffiliatePlan.fromJson(json.decode(response.body));
      } else {
        print('Failed to create affiliate plan: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to create affiliate plan: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception when creating affiliate plan: $e');
      throw Exception('Failed to create affiliate plan: $e');
    }
  }

  // AI Templates
  Future<List<dynamic>> getAITemplates() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.adminAIFeedbackTemplatesEndpoint}'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Handle paginated response - extract the results array
      if (data is Map<String, dynamic> && data.containsKey('results')) {
        return data['results'] as List<dynamic>;
      }
      // Fallback for non-paginated response
      return data is List ? data : [];
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else {
      throw Exception('Failed to load AI templates: ${response.statusCode}');
    }
  }

  // Create AI Template
  Future<Map<String, dynamic>> createAITemplate(Map<String, dynamic> templateData) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.adminAIFeedbackTemplatesEndpoint}'),
      headers: headers,
      body: json.encode(templateData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else {
      throw Exception('Failed to create AI template: ${response.statusCode}');
    }
  }

  // Update AI Template
  Future<Map<String, dynamic>> updateAITemplate(String templateId, Map<String, dynamic> templateData) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.adminAIFeedbackTemplatesEndpoint}$templateId/'),
      headers: headers,
      body: json.encode(templateData),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else {
      throw Exception('Failed to update AI template: ${response.statusCode}');
    }
  }

  // Delete AI Template
  Future<void> deleteAITemplate(String templateId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.adminAIFeedbackTemplatesEndpoint}$templateId/'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      return;
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else {
      throw Exception('Failed to delete AI template: ${response.statusCode}');
    }
  }

  // Toggle AI Template Active Status
  Future<Map<String, dynamic>> toggleAITemplateStatus(String templateId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.adminAIFeedbackTemplatesEndpoint}$templateId/toggle_active/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else {
      throw Exception('Failed to toggle AI template status: ${response.statusCode}');
    }
  }

  // FAQ Management
  Future<List<dynamic>> getFAQCategories() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.adminSupportFAQEndpoint}categories/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // The categories endpoint returns a direct array
      if (data is List) {
        return data;
      } else {
        return [];
      }
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else {
      throw Exception('Failed to load FAQ categories: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getFAQs() async {
    List<dynamic> allFaqs = [];
    String? nextUrl = ApiConfig.adminSupportFAQEndpoint;
    
    // Fetch all pages of FAQs
    while (nextUrl != null) {
      final response = await http.get(
        Uri.parse(nextUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle paginated response format from Django REST Framework
        if (data is Map && data.containsKey('results')) {
          final List<dynamic> pageResults = data['results'] as List<dynamic>;
          allFaqs.addAll(pageResults);
          
          // Check if there's a next page
          nextUrl = data['next'];
        } else if (data is List) {
          // Fallback for direct array format (non-paginated)
          allFaqs.addAll(data);
          nextUrl = null; // No more pages
        } else {
          nextUrl = null; // No more pages
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Admin permissions required');
      } else {
        throw Exception('Failed to load FAQs: ${response.statusCode}');
      }
    }
    
    return allFaqs;
  }

  Future<Map<String, dynamic>> createFAQ(Map<String, dynamic> faqData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.adminSupportFAQEndpoint),
      headers: headers,
      body: json.encode(faqData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else {
      throw Exception('Failed to create FAQ: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> updateFAQ(String faqId, Map<String, dynamic> faqData) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.adminSupportFAQEndpoint}$faqId/'),
      headers: headers,
      body: json.encode(faqData),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else {
      throw Exception('Failed to update FAQ: ${response.statusCode}');
    }
  }

  Future<void> deleteFAQ(String faqId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.adminSupportFAQEndpoint}$faqId/'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete FAQ: ${response.statusCode}');
    }
  }

  // System Settings
  Future<Map<String, dynamic>> getSystemSettings() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.apiV1Url}/admin/settings/system/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized: Admin permissions required');
    } else {
      throw Exception('Failed to load system settings: ${response.statusCode}');
    }
  }

  Future<void> updateSystemSettings(Map<String, dynamic> settings) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.apiV1Url}/admin/settings/system/'),
      headers: headers,
      body: json.encode(settings),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update system settings: ${response.statusCode}');
    }
  }
} 