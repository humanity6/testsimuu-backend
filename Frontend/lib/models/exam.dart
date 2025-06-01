import 'package:flutter/material.dart';

class Exam {
  final String id;
  final String slug;
  final String title;
  final String description;
  final String? translatedDescription;
  final String subject;
  final String difficulty;
  final int questionCount;
  final int timeLimit; // in minutes
  final String imageUrl;
  final double rating;
  final int completionCount;
  final bool requiresSubscription;
  final List<String>? availableTranslations;
  final ExamTranslationInfo? translationInfo;

  Exam({
    required this.id,
    this.slug = '',
    required this.title,
    required this.description,
    this.translatedDescription,
    required this.subject,
    required this.difficulty,
    required this.questionCount,
    required this.timeLimit,
    this.imageUrl = '',
    this.rating = 0.0,
    this.completionCount = 0,
    this.requiresSubscription = false,
    this.availableTranslations,
    this.translationInfo,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? '',
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      translatedDescription: json['translated_description'],
      subject: json['subject'] ?? '',
      difficulty: json['difficulty'] ?? 'Beginner',
      questionCount: json['questionCount'] ?? 0,
      timeLimit: json['timeLimit'] ?? 60,
      imageUrl: json['imageUrl'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      completionCount: json['completionCount'] ?? 0,
      requiresSubscription: json['requiresSubscription'] ?? false,
      availableTranslations: (json['available_translations'] as List<dynamic>?)?.cast<String>(),
      translationInfo: json['translation_info'] != null 
          ? ExamTranslationInfo.fromJson(json['translation_info'])
          : null,
    );
  }

  // Factory method for API response format
  factory Exam.fromApiJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id']?.toString() ?? '',
      slug: json['slug'] ?? '',
      title: json['name'] ?? json['title'] ?? '',
      description: json['description'] ?? '',
      translatedDescription: json['translated_description'],
      subject: json['subject'] ?? 'General',
      difficulty: json['difficulty'] ?? 'Beginner',
      questionCount: json['question_count'] ?? json['questionCount'] ?? 0,
      timeLimit: json['time_limit_minutes'] ?? json['timeLimit'] ?? 60,
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      completionCount: json['completion_count'] ?? json['completionCount'] ?? 0,
      requiresSubscription: json['requires_subscription'] ?? json['requiresSubscription'] ?? false,
      availableTranslations: (json['available_translations'] as List<dynamic>?)?.cast<String>(),
      translationInfo: json['translation_info'] != null 
          ? ExamTranslationInfo.fromJson(json['translation_info'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'description': description,
      'translated_description': translatedDescription,
      'subject': subject,
      'difficulty': difficulty,
      'questionCount': questionCount,
      'timeLimit': timeLimit,
      'imageUrl': imageUrl,
      'rating': rating,
      'completionCount': completionCount,
      'requiresSubscription': requiresSubscription,
      'available_translations': availableTranslations,
      'translation_info': translationInfo?.toJson(),
    };
  }

  /// Get the appropriate description based on locale
  String getLocalizedDescription() {
    return translatedDescription?.isNotEmpty == true 
        ? translatedDescription!
        : description;
  }

  /// Check if translation is available for a specific language
  bool hasTranslation(String languageCode) {
    return availableTranslations?.contains(languageCode) ?? false;
  }

  /// Check if translation is currently being processed
  bool get isTranslationPending {
    return translationInfo?.status == 'PENDING';
  }

  /// Check if translation has completed successfully
  bool get hasTranslationCompleted {
    return translationInfo?.status == 'COMPLETED';
  }

  /// Check if translation encountered an error
  bool get hasTranslationError {
    return translationInfo?.status == 'ERROR';
  }

  // Get color based on difficulty
  Color getDifficultyColor() {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
  
  // Get translated difficulty
  String getTranslatedDifficulty(BuildContext context) {
    final translations = {
      'beginner': 'exams_beginner',
      'intermediate': 'exams_intermediate',
      'advanced': 'exams_advanced',
    };
    
    final key = translations[difficulty.toLowerCase()] ?? 'exams_beginner';
    // We'll need to access the translation service, but we'll handle this in the UI
    return key;
  }
}

class ExamTranslationInfo {
  final String languageCode;
  final String languageName;
  final String status;
  final DateTime? translatedAt;
  final String? translationMethod;

  ExamTranslationInfo({
    required this.languageCode,
    required this.languageName,
    required this.status,
    this.translatedAt,
    this.translationMethod,
  });

  factory ExamTranslationInfo.fromJson(Map<String, dynamic> json) {
    return ExamTranslationInfo(
      languageCode: json['language_code'] ?? '',
      languageName: json['language_name'] ?? '',
      status: json['translation_status'] ?? json['status'] ?? '',
      translatedAt: json['translated_at'] != null 
          ? DateTime.tryParse(json['translated_at'])
          : null,
      translationMethod: json['translation_method'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_code': languageCode,
      'language_name': languageName,
      'translation_status': status,
      'translated_at': translatedAt?.toIso8601String(),
      'translation_method': translationMethod,
    };
  }

  /// Get status display color
  Color getStatusColor() {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'ERROR':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get status display text
  String getStatusDisplayText() {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return 'Translation Complete';
      case 'PENDING':
        return 'Translation In Progress';
      case 'ERROR':
        return 'Translation Failed';
      case 'NOT_AVAILABLE':
        return 'Translation Not Available';
      default:
        return status;
    }
  }
} 