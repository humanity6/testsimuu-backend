import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import '../models/exam.dart';
import 'auth_service.dart';
import '../utils/api_config.dart';

class ExamService extends ChangeNotifier {
  List<Exam> _featuredExams = [];
  List<Exam> _allExams = [];
  List<String> _subjects = [];
  List<Exam> _examTopics = [];
  bool _isLoading = false;
  String? _error;

  List<Exam> get featuredExams => _featuredExams;
  List<Exam> get allExams => _allExams;
  List<String> get subjects => _subjects;
  List<Exam> get examTopics => _examTopics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Singleton instance
  static final ExamService _instance = ExamService._internal();
  factory ExamService() => _instance;
  ExamService._internal();

  // Safe method to notify listeners without causing setState during build
  void _notifyListenersSafe() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Helper method to get auth token
  Future<String?> _getAuthToken() async {
    final authService = AuthService();
    return authService.getToken();
  }

  // Fetch featured exams from API
  Future<void> fetchFeaturedExams() async {
    _isLoading = true;
    _error = null;
    _notifyListenersSafe();

    try {
      final headers = {
        'Content-Type': 'application/json',
      };

      // Use the /api/v1/exams/ endpoint with a filter for featured
      final response = await http.get(
        Uri.parse('${ApiConfig.examsEndpoint}?is_featured=true'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        
        _featuredExams = results.map((json) => _parseExamFromJson(json)).toList();
        _isLoading = false;
        _notifyListenersSafe();
      } else if (response.statusCode == 401) {
        // Authentication error - user needs to log in
        _error = 'Failed to load featured exams: Unauthorized';
        _isLoading = false;
        _notifyListenersSafe();
      } else {
        // Other API errors
        _error = 'Failed to load featured exams: ${response.statusCode}';
        _isLoading = false;
        _notifyListenersSafe();
      }
    } catch (e) {
      _error = 'Failed to load exams: ${e.toString()}';
      _isLoading = false;
      _notifyListenersSafe();
    }
  }

  // Fetch all exams from API
  Future<void> fetchAllExams() async {
    _isLoading = true;
    _error = null;
    _notifyListenersSafe();

    try {
      final headers = {
        'Content-Type': 'application/json',
      };
      
      // Use the API endpoint for exams from API_ENDPOINTS.txt
      final response = await http.get(
        Uri.parse('${ApiConfig.examsEndpoint}?is_active=true'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        
        _allExams = results.map((json) => _parseExamFromJson(json)).toList();
        
        // Extract unique subjects
        final Set<String> subjectSet = <String>{};
        for (var exam in _allExams) {
          if (exam.subject.isNotEmpty) {
            subjectSet.add(exam.subject);
          }
        }
        _subjects = subjectSet.toList()..sort();
        
        _isLoading = false;
        _error = null;
        _notifyListenersSafe();
      } else if (response.statusCode == 401) {
        _error = 'Failed to load exams: Unauthorized';
        _isLoading = false;
        _notifyListenersSafe();
      } else {
        _error = 'Failed to load exams: ${response.statusCode}';
        _isLoading = false;
        _notifyListenersSafe();
      }
    } catch (e) {
      _error = 'Failed to load exams: ${e.toString()}';
      _isLoading = false;
      _notifyListenersSafe();
    }
  }

  // Parse exam from API response
  Exam _parseExamFromJson(Map<String, dynamic> json) {
    try {
      return Exam(
        id: json['id']?.toString() ?? '',
        slug: json['slug'] ?? '',
        title: json['name'] ?? json['title'] ?? 'Unknown Exam', // Try both 'name' and 'title' fields
        description: json['description'] ?? '',
        subject: _extractSubject(json),
        difficulty: _getDifficultyFromExamData(json),
        questionCount: _parseIntField(json['question_count']),
        timeLimit: _parseTimeLimit(json['time_limit_seconds']),
        requiresSubscription: json['requires_subscription'] ?? true,
      );
    } catch (e) {
      print('Error parsing exam from JSON: $e');
      // Return a basic exam object if parsing fails
      return Exam(
        id: json['id']?.toString() ?? '',
        slug: json['slug'] ?? '',
        title: 'Unknown Exam',
        description: 'Description not available',
        subject: 'General',
        difficulty: 'Intermediate',
        questionCount: 0,
        timeLimit: 60,
        requiresSubscription: true,
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

  // Get exams by subject
  List<Exam> getExamsBySubject(String subject) {
    if (subject.isEmpty) {
      return _allExams;
    }
    return _allExams.where((exam) => exam.subject.toLowerCase() == subject.toLowerCase()).toList();
  }

  // Search exams by query
  List<Exam> searchExams(String query) {
    if (query.isEmpty) {
      return _allExams;
    }
    
    final lowercaseQuery = query.toLowerCase();
    return _allExams.where((exam) {
      return exam.title.toLowerCase().contains(lowercaseQuery) ||
          exam.description.toLowerCase().contains(lowercaseQuery) ||
          exam.subject.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Get exam details by ID or slug
  Future<Exam?> getExamById(String examIdOrSlug) async {
    _isLoading = true;
    _error = null;
    _notifyListenersSafe();
    
    try {
      final headers = {
        'Content-Type': 'application/json',
      };
      
      // Try to determine if this is a numeric ID or a slug
      String apiEndpoint;
      if (RegExp(r'^\d+$').hasMatch(examIdOrSlug)) {
        // It's a numeric ID, we need to first get the slug
        print('Detected numeric ID, finding slug from loaded exams...');
        
        // Try to find the exam in our already loaded exams first
        final existingExam = _allExams.firstWhere(
          (exam) => exam.id == examIdOrSlug,
          orElse: () => Exam(id: '', title: '', description: '', subject: '', difficulty: '', questionCount: 0, timeLimit: 0),
        );
        
        if (existingExam.id.isNotEmpty && existingExam.slug.isNotEmpty) {
          apiEndpoint = '${ApiConfig.examsEndpoint}${existingExam.slug}/';
          print('Found slug in loaded exams for ID $examIdOrSlug: ${existingExam.slug}');
        } else {
          // Need to fetch exam list to find the slug
          print('Fetching exam list to find slug...');
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
                  _notifyListenersSafe();
                  return null;
                }
              } else {
                print('No results in exam list response');
                _error = 'Failed to load exam list';
                _isLoading = false;
                _notifyListenersSafe();
                return null;
              }
            } else {
              print('Failed to fetch exam list: ${listResponse.statusCode}');
              _error = 'Failed to load exam list';
              _isLoading = false;
              _notifyListenersSafe();
              return null;
            }
          } catch (e) {
            print('Error fetching exam list: $e');
            _error = 'Failed to load exam list';
            _isLoading = false;
            _notifyListenersSafe();
            return null;
          }
        }
      } else {
        // It's already a slug
        apiEndpoint = '${ApiConfig.examsEndpoint}$examIdOrSlug/';
      }
      
      print('Using API endpoint: $apiEndpoint');
      
      final response = await http.get(
        Uri.parse(apiEndpoint),
        headers: headers,
      );
      
      _isLoading = false;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final exam = _parseExamFromJson(data);
        _notifyListenersSafe();
        return exam;
      } else if (response.statusCode == 404) {
        _error = 'Exam not found';
        _notifyListenersSafe();
        return null;
      } else if (response.statusCode == 401) {
        _error = 'Failed to load exam details: Unauthorized';
        _notifyListenersSafe();
        return null;
      } else {
        _error = 'Failed to load exam details: ${response.statusCode}';
        _notifyListenersSafe();
        return null;
      }
    } catch (e) {
      _error = 'Failed to load exam details: ${e.toString()}';
      _isLoading = false;
      _notifyListenersSafe();
      return null;
    }
  }

  // Get exam topics (categories)
  Future<List<Exam>> getExamTopics(String examId) async {
    _isLoading = true;
    _error = null;
    _notifyListenersSafe();
    
    try {
      final headers = {
        'Content-Type': 'application/json',
      };
      
      // Use the API endpoint for topics with parent_exam_id filter
      final response = await http.get(
        Uri.parse('${ApiConfig.examsEndpoint}?parent_exam_id=$examId&is_active=true'),
        headers: headers,
      );
      
      _isLoading = false;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        
        _examTopics = results.map((json) => _parseExamFromJson(json)).toList();
        _notifyListenersSafe();
        return _examTopics;
      } else if (response.statusCode == 401) {
        _error = 'Failed to load exam topics: Unauthorized';
        _notifyListenersSafe();
        return [];
      } else {
        _error = 'Failed to load exam topics: ${response.statusCode}';
        _notifyListenersSafe();
        return [];
      }
    } catch (e) {
      _error = 'Failed to load exam topics: ${e.toString()}';
      _isLoading = false;
      _notifyListenersSafe();
      return [];
    }
  }

  // Get exam categories (might be the same as topics in some implementations)
  Future<List<Exam>> getExamCategories(String examId) async {
    // Reuse the getExamTopics implementation since they're the same concept
    return getExamTopics(examId);
  }

  // Create new exam session with mode selection
  Future<Map<String, dynamic>?> createExamSession(Map<String, dynamic> sessionData) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse(ApiConfig.examSessionsEndpoint),
        headers: headers,
        body: json.encode(sessionData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to create exam session');
      }
    } catch (e) {
      _error = 'Failed to create exam session: ${e.toString()}';
      _notifyListenersSafe();
      throw e;
    }
  }

  // Get exam session details
  Future<Map<String, dynamic>?> getExamSession(String sessionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('${ApiConfig.examSessionsEndpoint}$sessionId/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get exam session');
      }
    } catch (e) {
      _error = 'Failed to get exam session: ${e.toString()}';
      _notifyListenersSafe();
      throw e;
    }
  }

  // Get learning materials for an exam session
  Future<List<Map<String, dynamic>>> getLearningMaterials(String sessionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('${ApiConfig.examSessionsEndpoint}$sessionId/learning_materials/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 404) {
        // No learning materials available
        return [];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get learning materials');
      }
    } catch (e) {
      _error = 'Failed to get learning materials: ${e.toString()}';
      _notifyListenersSafe();
      throw e;
    }
  }

  // Mark learning materials as viewed
  Future<void> markLearningMaterialViewed(String sessionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.examSessionsEndpoint}$sessionId/mark_learning_material_viewed/'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to mark learning material as viewed');
      }
    } catch (e) {
      _error = 'Failed to mark learning material as viewed: ${e.toString()}';
      _notifyListenersSafe();
      throw e;
    }
  }

  // Submit answer for a question in practice mode
  Future<Map<String, dynamic>?> submitAnswer(String sessionId, Map<String, dynamic> answerData) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.examSessionsEndpoint}$sessionId/submit_answer/'),
        headers: headers,
        body: json.encode(answerData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to submit answer');
      }
    } catch (e) {
      _error = 'Failed to submit answer: ${e.toString()}';
      _notifyListenersSafe();
      throw e;
    }
  }

  // Complete exam session
  Future<Map<String, dynamic>?> completeExamSession(String sessionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.examSessionsEndpoint}$sessionId/complete/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to complete exam session');
      }
    } catch (e) {
      _error = 'Failed to complete exam session: ${e.toString()}';
      _notifyListenersSafe();
      throw e;
    }
  }

  // Get available topics for an exam session
  Future<List<Map<String, dynamic>>> getSessionTopics(String sessionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('${ApiConfig.examSessionsEndpoint}$sessionId/topics/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get session topics');
      }
    } catch (e) {
      _error = 'Failed to get session topics: ${e.toString()}';
      _notifyListenersSafe();
      throw e;
    }
  }

  // Submit a practice session
  Future<bool> submitPracticeSession(String sessionId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.examSessionsEndpoint}$sessionId/complete/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to submit practice session');
      }
    } catch (e) {
      _error = 'Failed to submit practice session: ${e.toString()}';
      _notifyListenersSafe();
      return false;
    }
  }
} 