import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/quiz.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';

class QuestionService extends ChangeNotifier {
  final AuthService _authService;
  bool _isLoading = false;
  String? _error;
  List<Question> _questions = [];

  QuestionService() : _authService = AuthService();

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Question> get questions => _questions;

  Future<List<Question>> getQuestions(Map<String, dynamic> filters) async {
    if (!_authService.isAuthenticated) {
      _error = 'User not authenticated';
      return [];
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Build query parameters
      final queryParams = <String, String>{};
      filters.forEach((key, value) {
        if (value != null) {
          queryParams[key] = value.toString();
        }
      });

      final uri = Uri.parse(ApiConfig.questionsEndpoint)
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_authService.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> questionsJson;
        
        // Handle both paginated and direct list responses
        if (data is Map && data.containsKey('results')) {
          questionsJson = data['results'];
        } else if (data is List) {
          questionsJson = data;
        } else {
          questionsJson = [];
        }
        
        _questions = questionsJson.map((json) => _parseQuestion(json)).toList();
        _isLoading = false;
        notifyListeners();
        return _questions;
      } else if (response.statusCode == 401) {
        _error = 'Authentication required or token expired';
        _isLoading = false;
        notifyListeners();
        return [];
      } else {
        _error = 'Failed to load questions: ${response.statusCode}';
        _isLoading = false;
        notifyListeners();
        return [];
      }
    } catch (e) {
      _error = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<Question?> getQuestionById(String id) async {
    if (!_authService.isAuthenticated) {
      _error = 'User not authenticated';
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.get(
        Uri.parse('${ApiConfig.questionsEndpoint}$id/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_authService.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final questionJson = json.decode(response.body);
        final question = _parseQuestion(questionJson);
        _isLoading = false;
        notifyListeners();
        return question;
      } else if (response.statusCode == 401) {
        _error = 'Authentication required or token expired';
        _isLoading = false;
        notifyListeners();
        return null;
      } else {
        _error = 'Failed to load question: ${response.statusCode}';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>> submitAnswer(
    String sessionId,
    String questionId,
    String answer,
    QuestionType questionType,
  ) async {
    if (!_authService.isAuthenticated) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final Map<String, dynamic> payload = {};

      // Set the appropriate answer field based on question type
      switch (questionType) {
        case QuestionType.multipleChoice:
          payload['submitted_mcq_choice_ids'] = [answer]; // For MCQ, answer is the option ID
          break;
        case QuestionType.openEnded:
          payload['submitted_answer_text'] = answer;
          break;
        case QuestionType.calculation:
          payload['submitted_calculation_input'] = answer;
          break;
      }

      // Use the correct endpoint format from API_ENDPOINTS.txt
      final response = await http.post(
        Uri.parse('${ApiConfig.userAnswersEndpoint}exam-sessions/$sessionId/questions/$questionId/answer/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_authService.accessToken}',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = json.decode(response.body);
        _isLoading = false;
        notifyListeners();
        return {
          'success': true,
          'is_correct': result['is_correct'] ?? false,
          'ai_feedback': result['ai_feedback'] ?? '',
          'explanation': result['explanation'] ?? '',
          'score': result['score'] ?? 0,
        };
      } else if (response.statusCode == 401) {
        _error = 'Authentication required or token expired';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'message': _error};
      } else {
        _error = 'Failed to submit answer: ${response.statusCode}';
        _isLoading = false;
        notifyListeners();
        return {'success': false, 'message': _error};
      }
    } catch (e) {
      _error = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': _error};
    }
  }

  // Helper method to parse question from API response
  Question _parseQuestion(Map<String, dynamic> json) {
    // Determine question type
    QuestionType type;
    switch (json['question_type']) {
      case 'MCQ':
        type = QuestionType.multipleChoice;
        break;
      case 'OPEN_ENDED':
        type = QuestionType.openEnded;
        break;
      case 'CALCULATION':
        type = QuestionType.calculation;
        break;
      default:
        type = QuestionType.multipleChoice;
    }

    // Parse options for MCQ questions
    List<Option>? options;
    if (type == QuestionType.multipleChoice && json['mcq_choices'] != null) {
      options = (json['mcq_choices'] as List).map((optionJson) {
        return Option(
          id: optionJson['id'].toString(),
          text: optionJson['choice_text'],
        );
      }).toList();
    }

    return Question(
      id: json['id'].toString(),
      text: json['question_text'] ?? '',
      type: type,
      options: options,
      difficulty: _mapDifficulty(json['difficulty']),
      subject: json['topic']?['name'] ?? 'General',
      explanation: json['explanation'] ?? '',
      points: json['points'] ?? 1,
    );
  }

  String _mapDifficulty(String? difficulty) {
    switch (difficulty?.toUpperCase()) {
      case 'EASY':
        return 'Easy';
      case 'MEDIUM':
        return 'Medium';
      case 'HARD':
        return 'Hard';
      default:
        return 'Medium';
    }
  }
} 