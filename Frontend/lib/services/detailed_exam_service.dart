import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/detailed_exam.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class DetailedExamService extends ChangeNotifier {
  DetailedExam? _currentExam;
  bool _isLoading = false;
  String? _error;

  DetailedExam? get currentExam => _currentExam;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Singleton instance
  static final DetailedExamService _instance = DetailedExamService._internal();
  factory DetailedExamService() => _instance;
  DetailedExamService._internal();

  // Helper method to get auth token
  Future<String?> _getAuthToken() async {
    try {
      final authService = AuthService();
      return authService.getToken();
    } catch (e) {
      print('Error getting auth token: $e');
      return null;
    }
  }

  // Parse exam details from API response (which uses different field names than our model)
  DetailedExam _parseDetailedExamFromAPI(Map<String, dynamic> json) {
    try {
      return DetailedExam(
        id: json['id']?.toString() ?? '',
        title: json['name'] ?? json['title'] ?? 'Unknown Exam', // Try both 'name' and 'title' fields
        description: json['description'] ?? '',
        subject: _extractSubject(json),
        difficulty: _getDifficultyFromExamData(json),
        questionCount: _parseIntField(json['question_count']),
        timeLimit: _parseTimeLimit(json['time_limit_seconds']),
        requiresSubscription: json['requires_subscription'] ?? true,
        parentExamId: json['parent_exam_id']?.toString(),
      );
    } catch (e) {
      print('Error parsing exam data: $e');
      // Return a basic exam object if parsing fails
      return DetailedExam(
        id: json['id']?.toString() ?? '',
        title: 'Unknown Exam',
        description: 'Description not available',
        subject: 'General',
        difficulty: 'Intermediate',
        questionCount: 0,
        timeLimit: 60,
        requiresSubscription: true,
        parentExamId: null,
      );
    }
  }

  // Helper method to extract subject safely
  String _extractSubject(Map<String, dynamic> json) {
    try {
      if (json['parent_exam'] != null && json['parent_exam'] is Map) {
        final parentExam = json['parent_exam'] as Map<String, dynamic>;
        return parentExam['name'] ?? parentExam['title'] ?? 'General';
      }
      return json['subject'] ?? 'General';
    } catch (e) {
      print('Error extracting subject: $e');
      return 'General';
    }
  }

  // Helper method to parse integer fields safely
  int _parseIntField(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Helper method to parse time limit safely
  int _parseTimeLimit(dynamic timeLimitSeconds) {
    try {
      final seconds = _parseIntField(timeLimitSeconds);
      return seconds > 0 ? (seconds ~/ 60).clamp(1, 999) : 60; // Convert to minutes, default 60
    } catch (e) {
      print('Error parsing time limit: $e');
      return 60;
    }
  }

  // Extract difficulty from exam data
  String _getDifficultyFromExamData(Map<String, dynamic>? examData) {
    if (examData == null) return 'Intermediate';
    
    try {
      final difficulty = examData['difficulty']?.toString() ?? '';
      
      switch (difficulty.toUpperCase()) {
        case 'EASY':
        case 'BEGINNER':
          return 'Beginner';
        case 'MEDIUM':
        case 'INTERMEDIATE':
          return 'Intermediate';
        case 'HARD':
        case 'ADVANCED':
          return 'Advanced';
        default:
          return 'Intermediate';
      }
    } catch (e) {
      print('Error getting difficulty: $e');
      return 'Intermediate';
    }
  }

  // Get exam details by ID or slug
  Future<DetailedExam?> getExamDetails(String examIdOrSlug) async {
    if (examIdOrSlug.isEmpty) {
      print('Empty exam ID/slug provided');
      _error = 'Invalid exam identifier';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get auth token if available
      final token = await _getAuthToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      print('Fetching exam details for ID/slug: $examIdOrSlug');
      
      // Try to determine if this is a numeric ID or a slug
      String apiEndpoint;
      if (RegExp(r'^\d+$').hasMatch(examIdOrSlug)) {
        // It's a numeric ID, we need to first get the slug
        print('Detected numeric ID, fetching exam list to find slug...');
        
        try {
          final listResponse = await http.get(
            Uri.parse('${ApiConfig.examsEndpoint}'),
            headers: headers,
          ).timeout(const Duration(seconds: 10));
          
          if (listResponse.statusCode == 200) {
            final listData = json.decode(listResponse.body);
            final results = listData['results'] as List<dynamic>?;
            
            if (results != null) {
              // Find the exam with matching ID
              final examData = results.firstWhere(
                (exam) => exam['id']?.toString() == examIdOrSlug,
                orElse: () => null,
              );
              
              if (examData != null && examData['slug'] != null && examData['slug'].isNotEmpty) {
                apiEndpoint = '${ApiConfig.examsEndpoint}${examData['slug']}/';
                print('Found slug for ID $examIdOrSlug: ${examData['slug']}');
              } else {
                print('Exam with ID $examIdOrSlug not found or has no slug');
                _error = 'Exam not found';
                _isLoading = false;
                notifyListeners();
                return null;
              }
            } else {
              print('No results in exam list response');
              _error = 'Failed to load exam list';
              _isLoading = false;
              notifyListeners();
              return null;
            }
          } else {
            print('Failed to fetch exam list: ${listResponse.statusCode}');
            _error = 'Failed to load exam list';
            _isLoading = false;
            notifyListeners();
            return null;
          }
        } catch (e) {
          print('Error fetching exam list: $e');
          _error = 'Failed to load exam list';
          _isLoading = false;
          notifyListeners();
          return null;
        }
      } else {
        // It's already a slug
        apiEndpoint = '${ApiConfig.examsEndpoint}$examIdOrSlug/';
      }
      
      print('API endpoint: $apiEndpoint');
      
      final response = await http.get(
        Uri.parse(apiEndpoint),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      
      print('Exam details response status: ${response.statusCode}');
      
      _isLoading = false;
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          print('Exam details response data keys: ${(data as Map<String, dynamic>).keys.toList()}');
          
          _currentExam = _parseDetailedExamFromAPI(data);
          _error = null;
          notifyListeners();
          
          print('Successfully loaded exam: ${_currentExam?.title}');
          return _currentExam;
        } catch (e) {
          print('Error parsing exam details response: $e');
          _error = 'Failed to parse exam details';
          notifyListeners();
          return null;
        }
      } else if (response.statusCode == 401) {
        _error = 'Authentication required to access exam details';
        notifyListeners();
        return null;
      } else if (response.statusCode == 404) {
        _error = 'Exam not found';
        notifyListeners();
        return null;
      } else if (response.statusCode == 403) {
        _error = 'Access denied to exam details';
        notifyListeners();
        return null;
      } else {
        print('Exam details API error: ${response.statusCode} - ${response.body}');
        _error = 'Failed to load exam details: Server error (${response.statusCode})';
        notifyListeners();
        return null;
      }
    } catch (e) {
      print('Exception in getExamDetails: $e');
      _error = 'Failed to load exam details: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Fetch pricing plans for an exam
  Future<List<PricingPlan>> getExamPricingPlans(String examId, {String? authToken}) async {
    if (examId.isEmpty) {
      print('Empty exam ID provided for pricing plans');
      return [];
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get auth token if not provided
      final token = authToken ?? await _getAuthToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      print('Fetching pricing plans for exam ID: $examId');
      
      final response = await http.get(
        Uri.parse('${ApiConfig.apiV1Url}/exams/$examId/pricing-plans/'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      _isLoading = false;

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          final List<dynamic> plansData = data['results'] ?? data ?? [];
          
          final plans = plansData.map((planJson) => _parsePricingPlan(planJson)).toList();
          notifyListeners();
          
          print('Loaded ${plans.length} pricing plans for exam $examId');
          return plans;
        } catch (e) {
          print('Error parsing pricing plans: $e');
          notifyListeners();
          return [];
        }
      } else if (response.statusCode == 404) {
        print('No pricing plans found for exam $examId');
        notifyListeners();
        return [];
      } else {
        print('Pricing plans API error: ${response.statusCode} - ${response.body}');
        notifyListeners();
        return [];
      }
    } catch (e) {
      print('Exception in getExamPricingPlans: $e');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Parse pricing plan from API response
  PricingPlan _parsePricingPlan(Map<String, dynamic> json) {
    try {
      return PricingPlan(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? 'Unknown Plan',
        description: json['description'] ?? '',
        price: _parseDoubleField(json['price']),
        currency: json['currency'] ?? 'USD',
        billingCycle: json['billing_cycle'] ?? 'ONE_TIME',
        features: _parseFeatures(json['features_list'] ?? json['features']),
        trialDays: _parseIntField(json['trial_days']),
        isPopular: json['is_popular'] ?? false,
      );
    } catch (e) {
      print('Error parsing pricing plan: $e');
      return PricingPlan(
        id: json['id']?.toString() ?? '',
        name: 'Unknown Plan',
        description: 'Plan details unavailable',
        price: 0.0,
        currency: 'USD',
        billingCycle: 'ONE_TIME',
        features: [],
        trialDays: 0,
        isPopular: false,
      );
    }
  }

  // Helper method to parse double fields safely
  double _parseDoubleField(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Helper method to parse features list safely
  List<String> _parseFeatures(dynamic features) {
    try {
      if (features == null) return [];
      if (features is List) {
        return features.map((f) => f.toString()).toList();
      }
      if (features is String) {
        return [features];
      }
      return [];
    } catch (e) {
      print('Error parsing features: $e');
      return [];
    }
  }

  // Purchase exam by creating a subscription for the specified plan
  Future<bool> purchaseExam(String examId, String planId) async {
    if (examId.isEmpty || planId.isEmpty) {
      _error = 'Invalid exam ID or plan ID';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get auth token
      final token = await _getAuthToken();
      if (token == null) {
        _error = 'Authentication required to purchase exam';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print('Purchasing exam $examId with plan $planId');
      
      // Create subscription for the pricing plan
      final response = await http.post(
        Uri.parse(ApiConfig.userSubscriptionsEndpoint),
        headers: headers,
        body: json.encode({
          'pricing_plan_id': int.tryParse(planId) ?? planId,
          'exam_id': examId,
        }),
      ).timeout(const Duration(seconds: 15));

      _isLoading = false;
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Successfully purchased exam $examId');
        _error = null;
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Authentication failed. Please log in again.';
        notifyListeners();
        return false;
      } else if (response.statusCode == 403) {
        _error = 'Access denied. You may not have permission to purchase this exam.';
        notifyListeners();
        return false;
      } else if (response.statusCode == 400) {
        try {
          final errorData = json.decode(response.body);
          _error = errorData['detail'] ?? errorData['error'] ?? 'Invalid purchase request';
        } catch (e) {
          _error = 'Invalid purchase request';
        }
        notifyListeners();
        return false;
      } else {
        print('Purchase exam API error: ${response.statusCode} - ${response.body}');
        try {
          final errorData = json.decode(response.body);
          _error = errorData['detail'] ?? errorData['error'] ?? 'Failed to purchase exam: Server error (${response.statusCode})';
        } catch (e) {
          _error = 'Failed to purchase exam: Server error (${response.statusCode})';
        }
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Exception in purchaseExam: $e');
      _error = 'Failed to purchase exam: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Clear current exam data
  void clearCurrentExam() {
    _currentExam = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
} 