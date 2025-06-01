import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PerformanceSummary {
  final int totalQuestions;
  final int correctAnswers;
  final int partiallyCorrectAnswers;
  final double totalPointsEarned;
  final double totalPointsPossible;
  final int totalTimeSpentSeconds;
  final double accuracy;
  final double averageTimePerQuestion;
  final String startDate;
  final String endDate;
  
  PerformanceSummary({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.partiallyCorrectAnswers,
    required this.totalPointsEarned,
    required this.totalPointsPossible,
    required this.totalTimeSpentSeconds,
    required this.accuracy,
    required this.averageTimePerQuestion,
    required this.startDate,
    required this.endDate,
  });
  
  factory PerformanceSummary.fromJson(Map<String, dynamic> json) {
    return PerformanceSummary(
      totalQuestions: json['total_questions'] ?? 0,
      correctAnswers: json['correct_answers'] ?? 0,
      partiallyCorrectAnswers: json['partially_correct_answers'] ?? 0,
      totalPointsEarned: (json['total_points_earned'] ?? 0).toDouble(),
      totalPointsPossible: (json['total_points_possible'] ?? 0).toDouble(),
      totalTimeSpentSeconds: json['total_time_spent_seconds'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      averageTimePerQuestion: (json['average_time_per_question'] ?? 0).toDouble(),
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
    );
  }
  
  // Computed properties for backward compatibility
  int get completedQuizzes => totalQuestions > 0 ? 1 : 0; // Simplified
  double get averageScore => accuracy;
  double get totalStudyTimeHours => totalTimeSpentSeconds / 3600.0;
  int get totalQuestionsAnswered => totalQuestions;
  int get totalCorrectAnswers => correctAnswers;
}

class TopicPerformance {
  final String topicId;
  final String topicName;
  final int questionsAnswered;
  final int correctAnswers;
  final double accuracy;
  final double averageTimeSeconds;
  
  TopicPerformance({
    required this.topicId,
    required this.topicName,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.accuracy,
    required this.averageTimeSeconds,
  });
  
  factory TopicPerformance.fromJson(Map<String, dynamic> json) {
    // Calculate accuracy if not provided
    double accuracy = json['accuracy'] != null
        ? (json['accuracy']).toDouble()
        : json['questions_answered'] > 0
            ? (json['correct_answers'] / json['questions_answered'] * 100).toDouble()
            : 0.0;

    // Handle nested topic object or direct topic fields
    String topicId;
    String topicName;
    
    if (json['topic'] != null && json['topic'] is Map) {
      // New format with nested topic object
      final topicData = json['topic'] as Map<String, dynamic>;
      topicId = topicData['id']?.toString() ?? '';
      topicName = topicData['name'] ?? 'Unknown Topic';
    } else {
      // Legacy format with direct topic fields
      topicId = json['topic_id']?.toString() ?? '';
      topicName = json['topic_name'] ?? 'Unknown Topic';
    }
    
    return TopicPerformance(
      topicId: topicId,
      topicName: topicName,
      questionsAnswered: json['questions_answered'] ?? 0,
      correctAnswers: json['correct_answers'] ?? 0,
      accuracy: accuracy,
      averageTimeSeconds: (json['average_time_per_question'] ?? 0).toDouble(),
    );
  }
  
  // Get a user-friendly format for average time
  String get formattedAverageTime {
    if (averageTimeSeconds < 60) {
      return '${averageTimeSeconds.toStringAsFixed(1)} sec';
    } else {
      int minutes = (averageTimeSeconds / 60).floor();
      int seconds = (averageTimeSeconds % 60).round();
      return '$minutes min ${seconds.toString().padLeft(2, '0')} sec';
    }
  }
}

class DifficultyPerformance {
  final String difficulty;
  final int questionsAnswered;
  final int correctAnswers;
  final double accuracy;
  final double averageTimeSeconds;
  
  DifficultyPerformance({
    required this.difficulty,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.accuracy,
    required this.averageTimeSeconds,
  });
  
  factory DifficultyPerformance.fromJson(Map<String, dynamic> json) {
    // Calculate accuracy if not provided
    double accuracy = json['accuracy'] != null
        ? (json['accuracy']).toDouble()
        : json['questions_answered'] > 0
            ? (json['correct_answers'] / json['questions_answered'] * 100).toDouble()
            : 0.0;
    
    // Format the difficulty name to be user-friendly
    String difficultyName = json['difficulty'] ?? 'Unknown';
    
    // Handle different formats: "EASY", "easy", "Easy", etc.
    difficultyName = difficultyName.toLowerCase();
    
    // Convert to proper case
    switch (difficultyName) {
      case 'easy':
        difficultyName = 'Easy';
        break;
      case 'medium':
        difficultyName = 'Medium';
        break;
      case 'hard':
        difficultyName = 'Hard';
        break;
      case 'very_hard':
      case 'very hard':
        difficultyName = 'Very Hard';
        break;
      default:
        // Capitalize first letter
        difficultyName = difficultyName.isNotEmpty 
            ? difficultyName[0].toUpperCase() + difficultyName.substring(1)
            : 'Unknown';
    }
    
    return DifficultyPerformance(
      difficulty: difficultyName,
      questionsAnswered: json['questions_answered'] ?? 0,
      correctAnswers: json['correct_answers'] ?? 0,
      accuracy: accuracy,
      averageTimeSeconds: (json['average_time_per_question'] ?? 0).toDouble(),
    );
  }
  
  // Get color based on difficulty
  Color get difficultyColor {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.blue;
      case 'hard':
        return Colors.orange;
      case 'very hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class PerformanceTrend {
  final DateTime date;
  final double accuracy;
  final int questionsAnswered;
  final int correctAnswers;
  final double averageScore;
  
  PerformanceTrend({
    required this.date,
    required this.accuracy,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.averageScore,
  });
  
  factory PerformanceTrend.fromJson(Map<String, dynamic> json) {
    // Parse date from string
    DateTime date;
    try {
      if (json['date'] is String) {
        // Handle date string format like "2025-04-27"
        final dateStr = json['date'] as String;
        if (dateStr.contains('T')) {
          // Full datetime string
          date = DateTime.parse(dateStr);
        } else {
          // Date only string, add time to avoid timezone issues
          date = DateTime.parse('${dateStr}T00:00:00Z');
        }
      } else if (json['date'] is Map && json['date'].containsKey('year')) {
        // Handle nested date object format
        final dateObj = json['date'];
        date = DateTime(
          dateObj['year'] ?? 2025,
          dateObj['month'] ?? 1,
          dateObj['day'] ?? 1,
        );
      } else {
        // Fallback to current date if date format is unknown
        date = DateTime.now();
        if (kDebugMode) {
          print('Unknown date format in performance trend: ${json['date']}');
        }
      }
    } catch (e) {
      // Handle parsing errors gracefully
      date = DateTime.now();
      if (kDebugMode) {
        print('Error parsing date in performance trend: $e');
        print('Date value was: ${json['date']}');
      }
    }
    
    // Calculate accuracy if not provided
    double accuracy = 0.0;
    if (json['accuracy'] != null) {
      accuracy = double.tryParse(json['accuracy'].toString()) ?? 0.0;
    } else if (json['questions_answered'] != null && json['correct_answers'] != null) {
      final questionsAnswered = int.tryParse(json['questions_answered'].toString()) ?? 0;
      final correctAnswers = int.tryParse(json['correct_answers'].toString()) ?? 0;
      
      if (questionsAnswered > 0) {
        accuracy = (correctAnswers / questionsAnswered * 100);
      }
    }
    
    // Parse questions answered and correct answers
    final questionsAnswered = int.tryParse(json['questions_answered']?.toString() ?? '0') ?? 0;
    final correctAnswers = int.tryParse(json['correct_answers']?.toString() ?? '0') ?? 0;
    
    // Parse average score or points earned
    double averageScore = 0.0;
    if (json['points_earned'] != null) {
      averageScore = double.tryParse(json['points_earned'].toString()) ?? 0.0;
    } else if (json['average_score'] != null) {
      averageScore = double.tryParse(json['average_score'].toString()) ?? 0.0;
    }
    
    return PerformanceTrend(
      date: date,
      accuracy: accuracy,
      questionsAnswered: questionsAnswered,
      correctAnswers: correctAnswers,
      averageScore: averageScore,
    );
  }
  
  // Get formatted date (e.g., "Jan 15" or "Week 1")
  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class StudySession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> topicsStudied;
  final int questionsAnswered;
  final int correctAnswers;
  final double accuracy;
  final String sessionSource;
  
  StudySession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.topicsStudied,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.accuracy,
    required this.sessionSource,
  });
  
  factory StudySession.fromJson(Map<String, dynamic> json) {
    // Parse dates from strings
    DateTime startTime;
    DateTime endTime;
    
    try {
      startTime = DateTime.parse(json['start_time']);
      endTime = DateTime.parse(json['end_time']);
    } catch (e) {
      startTime = DateTime.now().subtract(const Duration(hours: 1));
      endTime = DateTime.now();
    }
    
    // Parse topics studied
    List<String> topics = [];
    if (json['topics_studied'] != null) {
      if (json['topics_studied'] is List) {
        topics = (json['topics_studied'] as List).map((e) => e.toString()).toList();
      } else if (json['topics_studied'] is String) {
        // Handle if it's a comma-separated string
        topics = (json['topics_studied'] as String).split(',');
      }
    }
    
    // Calculate accuracy
    int questionsAnswered = json['questions_answered'] ?? 0;
    int correctAnswers = json['correct_answers'] ?? 0;
    double accuracy = questionsAnswered > 0
        ? (correctAnswers / questionsAnswered * 100)
        : 0.0;
    
    return StudySession(
      id: json['id']?.toString() ?? '',
      startTime: startTime,
      endTime: endTime,
      topicsStudied: topics,
      questionsAnswered: questionsAnswered,
      correctAnswers: correctAnswers,
      accuracy: accuracy,
      sessionSource: json['session_source'] ?? 'Unknown',
    );
  }

  // Factory constructor for exam session data from backend
  factory StudySession.fromExamSessionJson(Map<String, dynamic> json) {
    // Parse dates from strings
    DateTime startTime;
    DateTime endTime;
    
    try {
      startTime = DateTime.parse(json['created_at'] ?? json['start_time'] ?? '');
    } catch (e) {
      startTime = DateTime.now().subtract(const Duration(hours: 1));
    }
    
    try {
      endTime = DateTime.parse(json['completed_at'] ?? json['end_time'] ?? json['updated_at'] ?? '');
    } catch (e) {
      // If no end time, calculate based on time limit or use start time + 1 hour
      final timeLimitSeconds = json['time_limit_seconds'] ?? 3600;
      endTime = startTime.add(Duration(seconds: timeLimitSeconds));
    }
    
    // Extract topic information from exam session
    List<String> topics = [];
    if (json['exam'] != null && json['exam']['title'] != null) {
      topics.add(json['exam']['title']);
    }
    if (json['topic'] != null && json['topic']['name'] != null) {
      topics.add(json['topic']['name']);
    }
    if (json['title'] != null) {
      topics.add(json['title']);
    }
    
    // Calculate questions and accuracy from session data
    int questionsAnswered = 0;
    int correctAnswers = 0;
    double accuracy = 0.0;
    
    if (json['user_answers'] != null && json['user_answers'] is List) {
      questionsAnswered = (json['user_answers'] as List).length;
      correctAnswers = (json['user_answers'] as List)
          .where((answer) => answer['is_correct'] == true)
          .length;
    } else {
      questionsAnswered = json['questions_answered'] ?? json['num_questions'] ?? 0;
      correctAnswers = json['correct_answers'] ?? 0;
    }
    
    if (questionsAnswered > 0) {
      accuracy = (correctAnswers / questionsAnswered * 100);
    }
    
    return StudySession(
      id: json['id']?.toString() ?? '',
      startTime: startTime,
      endTime: endTime,
      topicsStudied: topics.isEmpty ? ['Unknown'] : topics,
      questionsAnswered: questionsAnswered,
      correctAnswers: correctAnswers,
      accuracy: accuracy,
      sessionSource: json['session_type']?.toString().toUpperCase() ?? 'EXAM',
    );
  }
  
  // Get duration in minutes
  int get durationMinutes {
    return endTime.difference(startTime).inMinutes;
  }
  
  // Get formatted date
  String get formattedDate {
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }
  
  // Get formatted time
  String get formattedTime {
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
  }
}

// Add TopicProgress class after the existing model classes
class TopicProgress {
  final String topicId;
  final String topicName;
  final String topicSlug;
  final String? parentTopicId;
  final String? parentTopicName;
  final int totalQuestionsInTopic;
  final int questionsAttempted;
  final int questionsMastered;
  final String proficiencyLevel;
  final double completionPercentage;
  final String? lastActivityDate;
  
  TopicProgress({
    required this.topicId,
    required this.topicName,
    required this.topicSlug,
    this.parentTopicId,
    this.parentTopicName,
    required this.totalQuestionsInTopic,
    required this.questionsAttempted,
    required this.questionsMastered,
    required this.proficiencyLevel,
    required this.completionPercentage,
    this.lastActivityDate,
  });
  
  factory TopicProgress.fromJson(Map<String, dynamic> json) {
    return TopicProgress(
      topicId: json['topic_id']?.toString() ?? '',
      topicName: json['topic_name'] ?? 'Unknown Topic',
      topicSlug: json['topic_slug'] ?? '',
      parentTopicId: json['parent_topic_id']?.toString(),
      parentTopicName: json['parent_topic_name'],
      totalQuestionsInTopic: json['total_questions_in_topic'] ?? 0,
      questionsAttempted: json['questions_attempted'] ?? 0,
      questionsMastered: json['questions_mastered'] ?? 0,
      proficiencyLevel: json['proficiency_level'] ?? 'BEGINNER',
      completionPercentage: (json['completion_percentage'] ?? 0).toDouble(),
      lastActivityDate: json['last_activity_date'],
    );
  }
  
  // Computed property for backward compatibility
  double get proficiency => completionPercentage;
} 