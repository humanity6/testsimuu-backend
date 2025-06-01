import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'quiz.dart';
import 'exam.dart';

enum SessionStatus {
  inProgress,
  completed,
  abandoned
}

class ExamSession {
  final String id;
  final String examId;
  final String? examName;
  final DateTime startTime;
  final DateTime endTimeExpected;
  final DateTime? actualEndTime;
  final int timeRemainingSeconds;
  final SessionStatus status;
  final double? totalScoreAchieved;
  final double totalPossibleScore;
  final double passThreshold;
  final bool? passed;
  final List<SessionQuestion> questions;

  ExamSession({
    required this.id,
    required this.examId,
    this.examName,
    required this.startTime,
    required this.endTimeExpected,
    this.actualEndTime,
    required this.timeRemainingSeconds,
    required this.status,
    this.totalScoreAchieved,
    required this.totalPossibleScore,
    required this.passThreshold,
    this.passed,
    required this.questions,
  });

  factory ExamSession.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Parsing ExamSession from JSON: ${json.keys}');
    }
    
    try {
      return ExamSession(
        id: json['id'].toString(),
        examId: json['exam'].toString(),
        examName: json['exam_name']?.toString(),
        startTime: DateTime.parse(json['start_time']),
        endTimeExpected: DateTime.parse(json['end_time_expected']),
        actualEndTime: json['actual_end_time'] != null 
            ? DateTime.parse(json['actual_end_time']) 
            : null,
        timeRemainingSeconds: (json['time_remaining_seconds'] ?? 
            DateTime.parse(json['end_time_expected']).difference(DateTime.now()).inSeconds).toInt(),
        status: _parseStatus(json['status']?.toString() ?? 'IN_PROGRESS'),
        totalScoreAchieved: json['total_score_achieved'] != null ? 
            (json['total_score_achieved'] is int ? 
                (json['total_score_achieved'] as int).toDouble() : 
                json['total_score_achieved'] as double) : null,
        totalPossibleScore: json['total_possible_score'] is int ? 
            (json['total_possible_score'] as int).toDouble() : 
            (json['total_possible_score'] as num).toDouble(),
        passThreshold: json['pass_threshold'] is int ? 
            (json['pass_threshold'] as int).toDouble() : 
            (json['pass_threshold'] as num).toDouble(),
        passed: json['passed'],
        questions: (json['questions'] as List<dynamic>?)
                ?.map((q) => SessionQuestion.fromJson(q))
                .toList() ?? [],
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing ExamSession: $e');
        print('JSON data: $json');
      }
      // Re-throw the error instead of creating dummy data
      throw Exception('Failed to parse ExamSession from backend data: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam': examId,
      'exam_name': examName,
      'start_time': startTime.toIso8601String(),
      'end_time_expected': endTimeExpected.toIso8601String(),
      'actual_end_time': actualEndTime?.toIso8601String(),
      'time_remaining_seconds': timeRemainingSeconds,
      'status': _statusToString(status),
      'total_score_achieved': totalScoreAchieved,
      'total_possible_score': totalPossibleScore,
      'pass_threshold': passThreshold,
      'passed': passed,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  static SessionStatus _parseStatus(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return SessionStatus.inProgress;
      case 'COMPLETED':
        return SessionStatus.completed;
      case 'ABANDONED':
        return SessionStatus.abandoned;
      default:
        return SessionStatus.inProgress;
    }
  }

  static String _statusToString(SessionStatus status) {
    switch (status) {
      case SessionStatus.inProgress:
        return 'IN_PROGRESS';
      case SessionStatus.completed:
        return 'COMPLETED';
      case SessionStatus.abandoned:
        return 'ABANDONED';
    }
  }

  // Create a copy of this ExamSession with updated values
  ExamSession copyWith({
    String? id,
    String? examId,
    String? examName,
    DateTime? startTime,
    DateTime? endTimeExpected,
    DateTime? actualEndTime,
    int? timeRemainingSeconds,
    SessionStatus? status,
    double? totalScoreAchieved,
    double? totalPossibleScore,
    double? passThreshold,
    bool? passed,
    List<SessionQuestion>? questions,
  }) {
    return ExamSession(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      examName: examName ?? this.examName,
      startTime: startTime ?? this.startTime,
      endTimeExpected: endTimeExpected ?? this.endTimeExpected,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      timeRemainingSeconds: timeRemainingSeconds ?? this.timeRemainingSeconds,
      status: status ?? this.status,
      totalScoreAchieved: totalScoreAchieved ?? this.totalScoreAchieved,
      totalPossibleScore: totalPossibleScore ?? this.totalPossibleScore,
      passThreshold: passThreshold ?? this.passThreshold,
      passed: passed ?? this.passed,
      questions: questions ?? this.questions,
    );
  }
}

class SessionQuestion {
  final String id;
  final String text;
  final QuestionType type;
  final String difficulty;
  final List<Option>? options;
  final int displayOrder;
  final double questionWeight;
  final String? userAnswer;
  final bool? isCorrect;
  final String? correctAnswer;
  final String? explanation;
  final bool isMarkedForReview;
  final String? metadata;

  SessionQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.difficulty,
    this.options,
    required this.displayOrder,
    required this.questionWeight,
    this.userAnswer,
    this.isCorrect,
    this.correctAnswer,
    this.explanation,
    this.isMarkedForReview = false,
    this.metadata,
  });

  factory SessionQuestion.fromJson(Map<String, dynamic> json) {
    try {
      final questionType = _parseQuestionType(json['question_type']?.toString() ?? 'MCQ');
      
      // More comprehensive debugging
      if (kDebugMode) {
        print('===== SESSION QUESTION JSON PARSING =====');
        print('Question ID: ${json['id']}');
        print('Question Type: ${json['question_type']}');
        print('Parsed Question Type: $questionType');
        print('JSON Keys: ${json.keys.toList()}');

        // Check for various fields that might contain choices
        print('Has mcq_choices: ${json.containsKey('mcq_choices')}');
        print('Has choices: ${json.containsKey('choices')}');
        print('Has options: ${json.containsKey('options')}');
        
        if (json.containsKey('mcq_choices')) {
          print('mcq_choices type: ${json['mcq_choices'].runtimeType}');
          print('mcq_choices: ${json['mcq_choices']}');
        }
        if (json.containsKey('choices')) {
          print('choices type: ${json['choices'].runtimeType}');
          print('choices: ${json['choices']}');
        }
        print('====================================');
      }

      // Parse options from different possible field names with robust error handling
      List<Option>? parsedOptions;
      try {
        if (questionType == QuestionType.multipleChoice) {
          if (json.containsKey('mcq_choices') && json['mcq_choices'] != null) {
            final choicesData = json['mcq_choices'];
            if (kDebugMode) {
              print('Parsing mcq_choices: $choicesData');
            }
            
            if (choicesData is List) {
              parsedOptions = choicesData
                  .map((c) => Option.fromJson(c))
                  .toList();
            } else {
              if (kDebugMode) {
                print('Error: mcq_choices is not a List: ${choicesData.runtimeType}');
              }
            }
          } else if (json.containsKey('choices') && json['choices'] != null) {
            final choicesData = json['choices'];
            if (kDebugMode) {
              print('Parsing choices: $choicesData');
            }
            
            if (choicesData is List) {
              parsedOptions = choicesData
                  .map((c) => Option.fromJson(c))
                  .toList();
            } else {
              if (kDebugMode) {
                print('Error: choices is not a List: ${choicesData.runtimeType}');
              }
            }
          } else if (json.containsKey('options') && json['options'] != null) {
            final optionsData = json['options'];
            if (kDebugMode) {
              print('Parsing options: $optionsData');
            }
            
            if (optionsData is List) {
              parsedOptions = optionsData
                  .map((c) => Option.fromJson(c))
                  .toList();
            } else {
              if (kDebugMode) {
                print('Error: options is not a List: ${optionsData.runtimeType}');
              }
            }
          } else {
            // If we still couldn't find options, log error but don't create dummy options
            if (kDebugMode) {
              print('Warning: No options found in question JSON. Question type: $questionType');
              print('Question data: $json');
            }
            // For multiple choice questions, this is an error - we should not proceed
            if (questionType == QuestionType.multipleChoice) {
              throw Exception('Multiple choice question missing options data');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing options: $e');
          print('Question data: $json');
        }
        // For multiple choice questions, we cannot proceed without proper options
        if (questionType == QuestionType.multipleChoice) {
          throw Exception('Failed to parse options for multiple choice question: $e');
        }
      }
      
      // Final validation for multiple choice questions
      if (questionType == QuestionType.multipleChoice && (parsedOptions == null || parsedOptions.isEmpty)) {
        throw Exception('Multiple choice question must have valid options');
      }
      
      // Extract user answer information and correctness from user_answer object
      String? userAnswerText;
      bool? isCorrect;
      
      // Check if there's a user_answer object
      if (json.containsKey('user_answer') && json['user_answer'] != null) {
        final userAnswerData = json['user_answer'] as Map<String, dynamic>;
        
        // Extract the is_correct field from user_answer
        isCorrect = userAnswerData['is_correct'] as bool?;
        
        // Extract user answer text based on question type
        if (questionType == QuestionType.multipleChoice) {
          // For MCQ, we might want to show the selected choices
          final mcqChoices = userAnswerData['mcq_choices'] as List?;
          if (mcqChoices != null && mcqChoices.isNotEmpty) {
            userAnswerText = mcqChoices.join(',');
          }
        } else {
          // For open-ended and calculation questions
          userAnswerText = userAnswerData['answer_text']?.toString() ?? 
                          userAnswerData['calculation_input']?.toString();
        }
      }
      
      return SessionQuestion(
        id: json['id']?.toString() ?? '0',
        text: json['text']?.toString() ?? 'Question text not available',
        type: questionType,
        difficulty: json['difficulty']?.toString() ?? 'MEDIUM',
        options: parsedOptions,
        displayOrder: json['display_order'] != null ? int.tryParse(json['display_order'].toString()) ?? 0 : 0,
        questionWeight: json['question_weight'] != null ? 
            (json['question_weight'] is int ? 
                (json['question_weight'] as int).toDouble() : 
                double.tryParse(json['question_weight'].toString()) ?? 1.0) : 1.0,
        userAnswer: userAnswerText,
        isCorrect: isCorrect,
        correctAnswer: json['correct_answer']?.toString(),
        explanation: json['explanation']?.toString(),
        isMarkedForReview: json['is_marked_for_review'] ?? false,
        metadata: json['metadata']?.toString(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing SessionQuestion: $e');
        print('JSON data: $json');
      }
      // Re-throw the error instead of creating dummy data
      throw Exception('Failed to parse SessionQuestion from backend data: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'question_type': _questionTypeToString(type),
      'difficulty': difficulty,
      'choices': options?.map((o) => o.toJson()).toList(),
      'display_order': displayOrder,
      'question_weight': questionWeight,
      'user_answer': userAnswer,
      'is_correct': isCorrect,
      'correct_answer': correctAnswer,
      'explanation': explanation,
      'is_marked_for_review': isMarkedForReview,
      'metadata': metadata,
    };
  }

  static QuestionType _parseQuestionType(String type) {
    switch (type) {
      case 'MCQ':
        return QuestionType.multipleChoice;
      case 'OPEN_ENDED':
        return QuestionType.openEnded;
      case 'CALCULATION':
        return QuestionType.calculation;
      default:
        return QuestionType.multipleChoice;
    }
  }

  static String _questionTypeToString(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'MCQ';
      case QuestionType.openEnded:
        return 'OPEN_ENDED';
      case QuestionType.calculation:
        return 'CALCULATION';
    }
  }

  // Create a copy of this SessionQuestion with updated values
  SessionQuestion copyWith({
    String? id,
    String? text,
    QuestionType? type,
    String? difficulty,
    List<Option>? options,
    int? displayOrder,
    double? questionWeight,
    String? userAnswer,
    bool? isCorrect,
    String? correctAnswer,
    String? explanation,
    bool? isMarkedForReview,
    String? metadata,
  }) {
    return SessionQuestion(
      id: id ?? this.id,
      text: text ?? this.text,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      options: options ?? this.options,
      displayOrder: displayOrder ?? this.displayOrder,
      questionWeight: questionWeight ?? this.questionWeight,
      userAnswer: userAnswer ?? this.userAnswer,
      isCorrect: isCorrect ?? this.isCorrect,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      isMarkedForReview: isMarkedForReview ?? this.isMarkedForReview,
      metadata: metadata ?? this.metadata,
    );
  }
} 