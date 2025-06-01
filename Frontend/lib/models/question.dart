import 'dart:convert';

class Question {
  final String id;
  final String text;
  final String type; // 'mcq', 'open_ended', 'calculation'
  final String? topicId;
  final String? examId; // Added examId field
  final String difficulty; // 'easy', 'medium', 'hard', 'very_hard'
  
  // For MCQ questions
  final List<QuestionOption>? options;
  
  // For open-ended questions
  final List<String>? modelAnswers;
  
  // For calculation questions
  final Map<String, dynamic>? calculationParams;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.topicId,
    this.examId,
    required this.difficulty,
    this.options,
    this.modelAnswers,
    this.calculationParams,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? json['question_type']?.toString() ?? 'mcq';
    
    return Question(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      type: type.toLowerCase(),
      topicId: json['topic_id']?.toString() ?? json['topic']?.toString(),
      examId: json['exam_id']?.toString() ?? json['exam']?.toString(),
      difficulty: json['difficulty']?.toString()?.toLowerCase() ?? 'medium',
      options: type.toLowerCase() == 'mcq'
          ? (json['mcq_choices'] as List? ?? json['choices'] as List? ?? json['options'] as List?)
              ?.map((o) => QuestionOption.fromJson(o))
              .toList()
          : null,
      modelAnswers: type.toLowerCase() == 'open_ended'
          ? (json['model_answers'] as List?)?.map((a) => a.toString()).toList()
          : null,
      calculationParams: type.toLowerCase() == 'calculation'
          ? _parseCalculationParams(json)
          : null,
    );
  }

  static Map<String, dynamic>? _parseCalculationParams(Map<String, dynamic> json) {
    try {
      // Try to get calculation params from either field
      final calcParams = json['calculation_params'] ?? json['model_calculation_logic'];
      if (calcParams == null) return null;
      
      // If it's already a Map, return it
      if (calcParams is Map<String, dynamic>) {
        return calcParams;
      }
      
      // If it's a String (JSON), try to parse it
      if (calcParams is String) {
        return Map<String, dynamic>.from(jsonDecode(calcParams));
      }
      
      // For any other type, try to convert to Map
      return Map<String, dynamic>.from(calcParams);
    } catch (e) {
      print('Error parsing calculation params: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'text': text,
      'type': type,
      'difficulty': difficulty,
    };
    
    if (topicId != null) {
      data['topic_id'] = topicId;
    }
    
    if (examId != null) {
      data['exam_id'] = examId;
    }
    
    if (type == 'mcq' && options != null) {
      data['options'] = options!.map((o) => o.toJson()).toList();
    }
    
    if (type == 'open_ended' && modelAnswers != null) {
      data['model_answers'] = modelAnswers;
    }
    
    if (type == 'calculation' && calculationParams != null) {
      data['calculation_params'] = calculationParams;
    }
    
    return data;
  }
}

class QuestionOption {
  final String id;
  final String text;
  final bool isCorrect;

  QuestionOption({
    required this.id,
    required this.text,
    required this.isCorrect,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? json['choice_text']?.toString() ?? '',
      isCorrect: json['is_correct'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'is_correct': isCorrect,
    };
  }
} 