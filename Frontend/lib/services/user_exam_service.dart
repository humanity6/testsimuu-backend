import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_exam.dart';
import '../models/exam.dart';
import 'auth_service.dart';
import '../utils/api_config.dart';

class UserExamService extends ChangeNotifier {
  List<UserExam> _userExams = [];
  List<UserExam> _activeExams = [];
  List<UserExam> _expiredExams = [];
  bool _isLoading = false;
  String? _error;

  List<UserExam> get userExams => _userExams;
  List<UserExam> get activeExams => _activeExams;
  List<UserExam> get expiredExams => _expiredExams;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Singleton instance
  static final UserExamService _instance = UserExamService._internal();
  factory UserExamService() => _instance;
  UserExamService._internal();

  // Helper method to get auth token
  Future<String?> _getAuthToken() async {
    final authService = AuthService();
    return authService.getToken();
  }

  // Fetch user's exams from API
  Future<void> fetchUserExams() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getAuthToken();
      
      if (token == null) {
        throw Exception('Authentication token not available');
      }
      
      // Fetch user's exams from API
      final response = await http.get(
        Uri.parse(ApiConfig.userSubscriptionsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List || (data is Map && data.containsKey('results'))) {
          final resultsData = data is List ? data : data['results'] as List;
          _userExams = _parseUserExams(resultsData);
          _processExams();
          _isLoading = false;
          _error = null;
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 401) {
        _error = 'Authentication failed. Please log in again.';
      } else {
        _error = 'Failed to load user exams: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Failed to load user exams: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Parse API response to UserExam objects
  List<UserExam> _parseUserExams(List<dynamic> data) {
    final List<UserExam> exams = [];
    
    for (var item in data) {
      try {
        // Parse subscription data properly - use the actual exam data from pricing plan
        final pricingPlanName = item['pricing_plan_name'] ?? 'Unknown Plan';
        
        // Extract exam ID and name from the subscription data
        // The backend now properly returns exam_id, exam_name, and exam_slug
        String examId = '';
        String examName = '';
        String examSlug = '';
        
        if (item.containsKey('exam_id') && item['exam_id'] != null) {
          examId = item['exam_id'].toString();
        }
        
        if (item.containsKey('exam_name') && item['exam_name'] != null) {
          examName = item['exam_name'].toString();
        }
        
        if (item.containsKey('exam_slug') && item['exam_slug'] != null) {
          examSlug = item['exam_slug'].toString();
        }
        
        // Fallback to pricing plan name only if exam info is completely missing
        if (examId.isEmpty && examName.isEmpty) {
          examName = pricingPlanName;
          if (pricingPlanName.contains(' - ')) {
            examName = pricingPlanName.split(' - ')[0];
          }
          // Only use pricing plan ID as absolute last resort
          examId = item['pricing_plan_id']?.toString() ?? '';
          
          if (kDebugMode) {
            print('Warning: Using pricing plan fallback for subscription ${item['id']}');
          }
        }
        
        if (kDebugMode) {
          print('Parsed subscription: Exam ID=$examId, Name=$examName, Plan=${pricingPlanName}');
        }
        
        // Map API response to Exam object
        final exam = Exam(
          id: examId,
          title: examName.isNotEmpty ? examName : pricingPlanName,
          description: 'Subscription: $pricingPlanName',
          subject: _getSubjectFromPlanName(examName.isNotEmpty ? examName : pricingPlanName),
          difficulty: 'Intermediate',
          questionCount: 100, // Default value
          timeLimit: 60, // Default value
          requiresSubscription: true,
        );
        
        // Create UserExam from API data
        final userExam = UserExam(
          id: item['id']?.toString() ?? '',
          exam: exam,
          startDate: item['start_date'] != null
              ? DateTime.parse(item['start_date'])
              : DateTime.now().subtract(const Duration(days: 30)),
          endDate: item['end_date'] != null
              ? DateTime.parse(item['end_date'])
              : DateTime.now().add(const Duration(days: 30)),
          status: item['status'] ?? 'INACTIVE',
          autoRenew: item['auto_renew'] ?? false,
          progress: _getProgressForSubscription(item),
        );
        
        exams.add(userExam);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing subscription data: ${e.toString()}');
          print('Item data: $item');
        }
      }
    }
    
    return exams;
  }
  
  // Extract subject from pricing plan name
  String _getSubjectFromPlanName(String planName) {
    if (planName.toLowerCase().contains('medical')) {
      return 'Medical';
    } else if (planName.toLowerCase().contains('engineering')) {
      return 'Engineering';
    } else if (planName.toLowerCase().contains('law')) {
      return 'Law';
    } else if (planName.toLowerCase().contains('business')) {
      return 'Business';
    }
    return 'General';
  }
  
  // Get progress percentage for a subscription
  String _getProgressForSubscription(Map<String, dynamic> subscriptionData) {
    try {
      // For active subscriptions, calculate progress based on time elapsed
      if (subscriptionData['status'] == 'ACTIVE') {
        final startDate = DateTime.parse(subscriptionData['start_date']);
        final endDate = DateTime.parse(subscriptionData['end_date']);
        final now = DateTime.now();
        
        if (now.isAfter(endDate)) {
          return '100%';
        } else if (now.isBefore(startDate)) {
          return '0%';
        } else {
          final totalDuration = endDate.difference(startDate).inDays;
          final elapsedDuration = now.difference(startDate).inDays;
          final progressPercent = ((elapsedDuration / totalDuration) * 100).clamp(0, 100);
          return '${progressPercent.round()}%';
        }
      } else if (subscriptionData['status'] == 'EXPIRED') {
        return '100%';
      } else {
        return '0%';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating progress: $e');
      }
      return '0%';
    }
  }

  // Process exams into active and expired lists
  void _processExams() {
    _activeExams = _userExams.where((exam) => exam.isActive).toList();
    _expiredExams = _userExams.where((exam) => exam.isExpired).toList();
  }

  // Get exam by ID
  UserExam? getUserExamById(String id) {
    try {
      return _userExams.firstWhere((exam) => exam.id == id);
    } catch (e) {
      return null;
    }
  }

  // Renew subscription
  Future<bool> renewSubscription(String userExamId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getAuthToken();
      
      if (token == null) {
        _error = 'Authentication token not available';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.userSubscriptionsEndpoint}$userExamId/renew/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchUserExams(); // Refresh the list after renewal
        _isLoading = false;
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Authentication failed. Please log in again.';
        _isLoading = false;
        notifyListeners();
        return false;
      } else {
        _error = 'Failed to renew subscription: ${response.statusCode}';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to renew subscription: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Cancel subscription
  Future<bool> cancelSubscription(String userExamId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getAuthToken();
      
      if (token == null) {
        _error = 'Authentication token not available';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.userSubscriptionsEndpoint}$userExamId/cancel/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchUserExams(); // Refresh the list after cancellation
        _isLoading = false;
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Authentication failed. Please log in again.';
        _isLoading = false;
        notifyListeners();
        return false;
      } else {
        _error = 'Failed to cancel subscription: ${response.statusCode}';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to cancel subscription: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Fetch user progress for a specific exam
  Future<void> fetchUserProgressForExam(String examId) async {
    try {
      final token = await _getAuthToken();
      
      if (token == null) {
        return; // Silently return as this is not critical functionality
      }
      
      // Make API call to get user progress for a specific exam
      final response = await http.get(
        Uri.parse('${ApiConfig.getApiV1Url("/users/me/progress/by-topic/?exam_id=$examId")}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Update the progress for this exam in the local list
        final examIndex = _userExams.indexWhere((exam) => exam.exam.id == examId);
        if (examIndex >= 0) {
          // Calculate overall progress from topics
          final overallProgress = _calculateOverallProgress(data);
          
          // Update the exam with the new progress
          _userExams[examIndex] = _userExams[examIndex].copyWith(progress: '$overallProgress%');
          
          notifyListeners();
        }
      }
    } catch (e) {
      // Silently handle error as this is an enhancement, not critical functionality
      if (kDebugMode) {
        print('Error fetching progress: ${e.toString()}');
      }
    }
  }
  
  // Calculate overall progress from topic progress data
  int _calculateOverallProgress(dynamic progressData) {
    if (progressData is! List || progressData.isEmpty) {
      return 0;
    }
    
    int totalQuestions = 0;
    int totalMastered = 0;
    
    for (var topic in progressData) {
      totalQuestions += (topic['total_questions_in_topic'] as num?)?.toInt() ?? 0;
      totalMastered += (topic['questions_mastered'] as num?)?.toInt() ?? 0;
    }
    
    if (totalQuestions == 0) {
      return 0;
    }
    
    return ((totalMastered / totalQuestions) * 100).round();
  }
} 