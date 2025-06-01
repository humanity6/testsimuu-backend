import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/exam_session.dart';
import '../models/quiz.dart';
import 'package:flutter/widgets.dart';
import '../utils/api_config.dart';
import 'auth_service.dart';
import 'package:dio/dio.dart';

class ExamSessionService extends ChangeNotifier {
  ExamSession? _currentSession;
  bool _isLoading = false;
  String? _error;
  Timer? _timer;
  int _timeRemainingSeconds = 0;
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();

  // Callback for when exam is auto-submitted due to time expiry
  Function(String sessionId)? _onAutoSubmitCallback;
  
  // Set callback for auto-submission navigation
  void setAutoSubmitCallback(Function(String sessionId)? callback) {
    _onAutoSubmitCallback = callback;
  }

  ExamSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get timeRemainingSeconds => _timeRemainingSeconds;
  
  String get formattedTimeRemaining {
    final hours = _timeRemainingSeconds ~/ 3600;
    final minutes = (_timeRemainingSeconds % 3600) ~/ 60;
    final seconds = _timeRemainingSeconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Singleton instance
  static final ExamSessionService _instance = ExamSessionService._internal();
  factory ExamSessionService() => _instance;
  ExamSessionService._internal();

  // Helper method to get auth token
  Future<String?> _getAuthToken() async {
    return _authService.getToken();
  }

  // Helper method to get the user's active exam ID from subscription
  Future<String?> _getUserActiveExamId() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        if (kDebugMode) {
          print('No auth token available to fetch user subscription');
        }
        return null;
      }
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      if (kDebugMode) {
        print('Fetching user subscription to get active exam ID');
      }
      
      final response = await http.get(
        Uri.parse(ApiConfig.userSubscriptionsEndpoint),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (kDebugMode) {
          print('User subscription data: $data');
        }
        
        // Extract exam ID from active subscription
        if (data is List && data.isNotEmpty) {
          final activeSubscription = data.firstWhere(
            (sub) => sub['status'] == 'ACTIVE',
            orElse: () => data.first
          );
          
          if (activeSubscription != null && activeSubscription['pricing_plan'] != null) {
            final examId = activeSubscription['pricing_plan']['exam_id'];
            if (kDebugMode) {
              print('Found user active exam ID: $examId');
            }
            return examId?.toString();
          }
        }
      } else {
        if (kDebugMode) {
          print('Failed to fetch user subscription: ${response.statusCode}');
          print('Response: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user active exam ID: $e');
      }
    }
    return null;
  }

  void dispose() {
    _stopTimer();
    super.dispose();
  }

  // Start a new exam session
  Future<bool> startExamSession(String examId, {String? authToken}) async {
    _isLoading = true;
    _error = null;
    // Schedule the notification for after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      // Get auth token if not provided
      final token = authToken ?? await _getAuthToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      // Safely parse the exam ID, handling both string and int formats
      var examIdValue = int.tryParse(examId) ?? 0;
      
      // If exam ID is invalid, try to get user's active exam ID from subscription
      if (examIdValue <= 0) {
        if (kDebugMode) {
          print('Invalid exam ID provided: $examId. Attempting to get user active exam ID.');
        }
        final activeExamId = await _getUserActiveExamId();
        if (activeExamId != null) {
          examIdValue = int.tryParse(activeExamId) ?? 0;
          if (kDebugMode) {
            print('Using user active exam ID instead: $examIdValue');
          }
        }
        
        // If still invalid, throw error
        if (examIdValue <= 0) {
          throw Exception('Could not determine a valid exam ID');
        }
      }

      if (kDebugMode) {
        print('Starting exam session with exam ID: $examIdValue');
        print('API endpoint: ${ApiConfig.examSessionsEndpoint}');
      }

      final response = await http.post(
        Uri.parse(ApiConfig.examSessionsEndpoint),
        headers: headers,
        body: json.encode({
          'exam_id': examIdValue,
          'session_type': 'TIMED_EXAM',
          'time_limit_seconds': 3600, // 1 hour default
          'title': 'Timed Exam Session',
          'num_questions': 10, // Add required field for question selection
        }),
      );
      
      if (kDebugMode) {
        print('Exam session response status: ${response.statusCode}');
        print('Exam session response body: ${response.body}');
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final sessionData = json.decode(response.body);
        _currentSession = ExamSession.fromJson(sessionData);
        _timeRemainingSeconds = _currentSession!.timeRemainingSeconds;
        _startTimer();
        _isLoading = false;
        // Schedule the notification for after the build is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return true;
      } else {
        String errorMessage = 'Failed to start exam session: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          } else if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'];
          }
        } catch (e) {
          // If decoding fails, use the default error message
          if (kDebugMode) {
            print('Error decoding response: $e');
          }
        }
        _error = errorMessage;
        _isLoading = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception in startExamSession: $e');
      }
      _error = 'Failed to start exam session: ${e.toString()}';
      _isLoading = false;
      // Schedule the notification for after the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return false;
    }
  }

  // Fetch an existing exam session
  Future<bool> fetchExamSession(String sessionId, {String? authToken}) async {
    _isLoading = true;
    _error = null;
    
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      // Get auth token if not provided
      final token = authToken ?? await _getAuthToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      if (kDebugMode) {
        print('Fetching exam session with ID: $sessionId');
        print('API endpoint: ${ApiConfig.examSessionsEndpoint}$sessionId/');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.examSessionsEndpoint}$sessionId/'),
        headers: headers,
      );
      
      if (kDebugMode) {
        print('Fetch session response status: ${response.statusCode}');
        print('Fetch session response body: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final sessionData = json.decode(response.body);
        _currentSession = ExamSession.fromJson(sessionData);
        _timeRemainingSeconds = _currentSession!.timeRemainingSeconds;
        
        // Only start the timer if the session is in progress
        if (_currentSession!.status == SessionStatus.inProgress) {
          _startTimer();
        }
        
        _isLoading = false;
        
        // Use addPostFrameCallback to avoid calling notifyListeners during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Authentication required to access exam session';
        _isLoading = false;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return false;
      } else if (response.statusCode == 404) {
        _error = 'Exam session not found';
        _isLoading = false;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return false;
      } else {
        String errorMessage = 'Failed to fetch exam session: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          } else if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'];
          }
        } catch (e) {
          // If decoding fails, use the default error message
          if (kDebugMode) {
            print('Error decoding response: $e');
          }
        }
        _error = errorMessage;
        _isLoading = false;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception in fetchExamSession: $e');
      }
      _error = 'Failed to fetch exam session: ${e.toString()}';
      _isLoading = false;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
      return false;
    }
  }

  // Submit an answer for a question
  Future<bool> submitAnswer(String questionId, String answer, {List<String>? mcqChoiceIds}) async {
    if (_currentSession == null) {
      _error = 'No active session';
      return false;
    }

    try {
      // First update the local state
      final updatedQuestions = _currentSession!.questions.map((q) {
        if (q.id == questionId) {
          return q.copyWith(userAnswer: answer);
        }
        return q;
      }).toList();

      _currentSession = _currentSession!.copyWith(questions: updatedQuestions);
      
      // Avoid excessive notifyListeners calls during submission
      // notifyListeners();
      
      // Then send to backend
      final token = await _getAuthToken();
      if (token == null) {
        _error = 'Authentication required to submit answer';
        return false;
      }
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      if (kDebugMode) {
        print('Submitting answer for question ID: $questionId');
        print('Answer: $answer');
        print('MCQ Choice IDs: $mcqChoiceIds');
      }
      
      // Find the question to determine its type
      final currentQuestion = _currentSession!.questions.firstWhere(
        (q) => q.id == questionId,
        orElse: () => throw Exception('Question not found in current session'),
      );
      
      // Fix the endpoint URL - use the correct user-answers pattern
      final endpoint = '${ApiConfig.apiV1Url}/user-answers/exam-sessions/${_currentSession!.id}/questions/$questionId/answer/';
      
      // Prepare request body based on question type
      final Map<String, dynamic> requestBody = {
        'time_spent_seconds': 60, // Default value, ideally this would be tracked
      };
      
      // Handle different question types appropriately
      if (currentQuestion.type == QuestionType.calculation) {
        // For calculation questions, send the answer in submitted_calculation_input
        requestBody['submitted_calculation_input'] = {
          'user_input': answer,
          'calculation_steps': [], // Could be enhanced to capture actual steps
        };
      } else if (currentQuestion.type == QuestionType.multipleChoice) {
        // For MCQ questions, use both submitted_answer_text and submitted_mcq_choice_ids
        requestBody['submitted_answer_text'] = answer;
        
        // Add MCQ choice IDs if provided
        if (mcqChoiceIds != null && mcqChoiceIds.isNotEmpty) {
          // Convert string IDs to integers for backend
          final List<int> choiceIdsAsInt = mcqChoiceIds
              .map((id) => int.tryParse(id) ?? 0)
              .where((id) => id > 0)
              .toList();
              
          requestBody['submitted_mcq_choice_ids'] = choiceIdsAsInt;
        }
      } else {
        // For open-ended and other text-based questions, use submitted_answer_text
        requestBody['submitted_answer_text'] = answer;
      }
      
      if (kDebugMode) {
        print('Question type: ${currentQuestion.type}');
        print('Answer submission endpoint: $endpoint');
        print('Answer submission body: $requestBody');
      }
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: json.encode(requestBody),
      );
      
      if (kDebugMode) {
        print('Answer submission response status: ${response.statusCode}');
        print('Answer submission response body: ${response.body}');
      }
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        // Parse the response to get updated question data
        try {
          final responseData = json.decode(response.body);
          
          // Update the question with the server response data
          final updatedQuestions = _currentSession!.questions.map((q) {
            if (q.id == questionId) {
              return q.copyWith(
                userAnswer: answer,
                isCorrect: responseData['is_correct'],
                // Add any additional fields from the response
              );
            }
            return q;
          }).toList();

          _currentSession = _currentSession!.copyWith(questions: updatedQuestions);
          
          // Only notify listeners once after successful submission
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifyListeners();
          });
          
          return true;
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing response: $e');
          }
          // Still return true if submission was successful even if parsing failed
          return true;
        }
      } else {
        String errorMessage = 'Failed to submit answer to server: ${response.statusCode}';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData.containsKey('detail')) {
            errorMessage = errorData['detail'];
          } else if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'];
          } else if (errorData is Map) {
            // Handle field-specific errors
            final errors = <String>[];
            errorData.forEach((key, value) {
              if (value is List) {
                errors.add('$key: ${value.join(', ')}');
              } else {
                errors.add('$key: $value');
              }
            });
            if (errors.isNotEmpty) {
              errorMessage = errors.join('; ');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error decoding response: $e');
          }
        }
        _error = errorMessage;
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Exception in submitAnswer: $e');
      }
      _error = 'Failed to submit answer: ${e.toString()}';
      return false;
    }
  }

  // Mark a question for review
  void toggleMarkForReview(String questionId) {
    if (_currentSession == null) return;

    final updatedQuestions = _currentSession!.questions.map((q) {
      if (q.id == questionId) {
        return q.copyWith(isMarkedForReview: !q.isMarkedForReview);
      }
      return q;
    }).toList();

    _currentSession = _currentSession!.copyWith(questions: updatedQuestions);
    notifyListeners();
  }

  // Submit the entire exam
  Future<bool> submitExam() async {
    if (_currentSession == null) {
      _error = 'No active session';
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getAuthToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.examSessionsEndpoint}${_currentSession!.id}/complete/'),
        headers: headers,
        body: json.encode({
          'answers': _currentSession!.questions.map((q) => {
            'question_id': q.id,
            'answer': q.userAnswer ?? '',
          }).toList(),
        }),
      );
      
      if (response.statusCode == 200) {
        final resultData = json.decode(response.body);
        _currentSession = ExamSession.fromJson(resultData);
        _stopTimer();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to submit exam: ${response.statusCode}');
      }
    } catch (e) {
      _error = 'Failed to submit exam: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Start the countdown timer
  void _startTimer() {
    _stopTimer(); // Ensure any existing timer is stopped
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemainingSeconds > 0) {
        _timeRemainingSeconds--;
        notifyListeners();
      } else {
        _stopTimer();
        // Auto-submit the exam when time runs out
        _autoSubmitExam();
      }
    });
  }

  // Stop the countdown timer
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // Auto-submit exam when time runs out
  Future<void> _autoSubmitExam() async {
    if (_currentSession == null) return;
    
    final success = await submitExam();
    
    if (success && _onAutoSubmitCallback != null) {
      // Call the callback to navigate to results
      _onAutoSubmitCallback!(_currentSession!.id);
    }
  }

  /// Get correct answer text for an MCQ choice
  Future<String> getCorrectAnswerText(String answerId) async {
    try {
      if (kDebugMode) {
        print('Finding correct answer text for ID: $answerId');
      }
      
      // First try to find the answer in the current session
      if (_currentSession != null) {
        // First pass: Try to find the option directly in the question that has this correct answer
        for (final question in _currentSession!.questions) {
          // Check if this question has this answerId as its correct answer
          if (question.correctAnswer == answerId && question.options != null) {
            for (final option in question.options!) {
              if (option.id == answerId) {
                if (kDebugMode) {
                  print('Found correct answer from current question options: ${option.text}');
                }
                return option.text;
              }
            }
          }
        }
        
        // Second pass: Look through all options in all questions
        for (final question in _currentSession!.questions) {
          if (question.options != null) {
            for (final option in question.options!) {
              if (option.id == answerId) {
                if (kDebugMode) {
                  print('Found correct answer from session options: ${option.text}');
                }
                return option.text;
              }
            }
          }
        }
      }
      
      // If we couldn't find the text directly, try to parse the answerId
      // Sometimes the ID might actually be the text
      if (answerId.contains(' ') || answerId.length > 10) {
        // If it has spaces or is very long, it's likely the actual text
        if (kDebugMode) {
          print('Answer ID appears to be the answer text itself: $answerId');
        }
        return answerId;
      }
      
      // As a last resort, format the ID to make it clear it's an ID
      if (kDebugMode) {
        print('Could not find answer text, using formatted ID as fallback');
      }
      return 'Answer #$answerId';
    } catch (e) {
      if (kDebugMode) {
        print('Error finding correct answer text: $e');
      }
      return 'Answer #$answerId';
    }
  }
} 