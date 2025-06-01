import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../models/quiz.dart';

class AIExplanationService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  final Map<String, String> _explanationCache = {};

  bool get isLoading => _isLoading;
  String? get error => _error;

  // Singleton instance
  static final AIExplanationService _instance = AIExplanationService._internal();
  factory AIExplanationService() => _instance;
  AIExplanationService._internal();

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = AuthService().accessToken;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get AI explanation for a user's answer to a question
  Future<String?> getAIExplanation({
    required String questionId,
    required String userAnswer,
    required QuestionType questionType,
    String? correctAnswer,
  }) async {
    // Only provide AI explanations for open-ended and calculation questions
    if (questionType != QuestionType.openEnded && questionType != QuestionType.calculation) {
      return null;
    }

    // Check cache first
    final cacheKey = '$questionId:$userAnswer';
    if (_explanationCache.containsKey(cacheKey)) {
      return _explanationCache[cacheKey];
    }

    try {
      _setLoading(true);
      _setError(null);

      final headers = await _getHeaders();
      
      // Get current locale for translation
      final currentLocale = LocalizationService().currentLocale;
      
      final response = await http.post(
        Uri.parse(ApiConfig.aiExplainEndpoint),
        headers: headers,
        body: json.encode({
          'question_id': questionId,
          'user_answer': userAnswer,
          'question_type': _questionTypeToString(questionType),
          'language': currentLocale.languageCode, // Send language preference
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          final explanation = data['ai_feedback'] as String? ?? '';
          
          // Cache the explanation
          _explanationCache[cacheKey] = explanation;
          
          return explanation;
        } catch (jsonError) {
          if (kDebugMode) {
            print('JSON decode error: $jsonError');
            print('Response body: ${response.body}');
          }
          _setError('Invalid response format from server');
          return null;
        }
      } else {
        if (kDebugMode) {
          print('API error: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
        
        _setError('Failed to get AI explanation');
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting AI explanation: $e');
      }
      _setError('Network error: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Submit answer for AI evaluation (for practice mode)
  Future<Map<String, dynamic>?> submitAnswerForEvaluation({
    required String questionId,
    required String userAnswer,
    required QuestionType questionType,
    String? sessionId,
  }) async {
    // Only evaluate open-ended and calculation questions
    if (questionType != QuestionType.openEnded && questionType != QuestionType.calculation) {
      return null;
    }

    try {
      _setLoading(true);
      _setError(null);

      final headers = await _getHeaders();
      
      // Prepare the request body
      final requestBody = {
        'question_id': questionId,
        'user_answer': userAnswer,
        'question_type': _questionTypeToString(questionType),
      };

      if (kDebugMode) {
        print('Submitting to AI endpoint: ${ApiConfig.aiExplainEndpoint}');
        print('Request body: ${json.encode(requestBody)}');
      }

      final response = await http.post(
        Uri.parse(ApiConfig.aiExplainEndpoint),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (kDebugMode) {
        print('AI evaluation response status: ${response.statusCode}');
        print('Response headers: ${response.headers}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          return {
            'ai_feedback': data['ai_feedback'] as String? ?? '',
            'score': data['score'] as double? ?? 0.0,
            'is_correct': data['is_correct'] as bool? ?? false,
            'processing_time_ms': data['processing_time_ms'] as int? ?? 0,
            'metadata': data['metadata'] as Map<String, dynamic>? ?? {},
          };
        } catch (jsonError) {
          if (kDebugMode) {
            print('JSON decode error in submitAnswerForEvaluation: $jsonError');
            print('Response body: ${response.body}');
          }
          _setError('Invalid response format from server');
          return null;
        }
      } else {
        // Handle error responses
        String errorMessage = 'Failed to evaluate answer';
        
        try {
          // Try to parse JSON error response
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorData['detail'] ?? errorMessage;
        } catch (jsonError) {
          // If JSON parsing fails, use status code information
          if (response.statusCode == 404) {
            errorMessage = 'AI evaluation service not available';
          } else if (response.statusCode == 401) {
            errorMessage = 'Authentication required. Please log in again.';
          } else if (response.statusCode == 403) {
            errorMessage = 'Not authorized to access AI evaluations';
          } else if (response.statusCode >= 500) {
            errorMessage = 'Server error. Please try again later.';
          } else {
            errorMessage = 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? "Unknown error"}';
          }
          
          if (kDebugMode) {
            print('Non-JSON error response in submitAnswerForEvaluation: ${response.statusCode}');
            print('Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
          }
        }
        
        _setError(errorMessage);
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error submitting answer for evaluation: $e');
      }
      _setError('Network error: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if a question type supports AI explanations
  bool supportsAIExplanation(QuestionType questionType) {
    return questionType == QuestionType.openEnded || questionType == QuestionType.calculation;
  }

  /// Clear error state
  void clearError() {
    _setError(null);
  }

  /// Clear explanation cache
  void clearCache() {
    _explanationCache.clear();
  }

  /// Convert QuestionType enum to string
  String _questionTypeToString(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'MCQ';
      case QuestionType.openEnded:
        return 'OPEN_ENDED';
      case QuestionType.calculation:
        return 'CALCULATION';
    }
  }
} 