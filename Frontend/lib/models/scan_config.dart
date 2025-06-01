import 'exam.dart';

class ScanConfig {
  final int id;
  final String name;
  final List<Exam> exams;
  final String frequency; // 'DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY'
  final int maxQuestionsPerScan;
  final bool isActive;
  final String promptTemplate;
  final DateTime? lastRun;
  final DateTime? nextScheduledRun;
  final String? createdByUsername;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScanConfig({
    required this.id,
    required this.name,
    required this.exams,
    required this.frequency,
    required this.maxQuestionsPerScan,
    required this.isActive,
    required this.promptTemplate,
    this.lastRun,
    this.nextScheduledRun,
    this.createdByUsername,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScanConfig.fromJson(Map<String, dynamic> json) {
    final List<Exam> exams = [];
    if (json['exams_detail'] != null) {
      exams.addAll(
        (json['exams_detail'] as List).map((e) => Exam.fromApiJson(e)).toList(),
      );
    }

    return ScanConfig(
      id: json['id'],
      name: json['name'] ?? '',
      exams: exams,
      frequency: json['frequency'] ?? 'WEEKLY',
      maxQuestionsPerScan: json['max_questions_per_scan'] ?? 20,
      isActive: json['is_active'] ?? true,
      promptTemplate: json['prompt_template'] ?? '',
      lastRun: json['last_run'] != null ? DateTime.parse(json['last_run']) : null,
      nextScheduledRun: json['next_scheduled_run'] != null ? DateTime.parse(json['next_scheduled_run']) : null,
      createdByUsername: json['created_by_username'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'exams': exams.map((e) => int.parse(e.id)).toList(),
      'frequency': frequency,
      'max_questions_per_scan': maxQuestionsPerScan,
      'is_active': isActive,
      'prompt_template': promptTemplate,
      'last_run': lastRun?.toIso8601String(),
      'next_scheduled_run': nextScheduledRun?.toIso8601String(),
      'created_by_username': createdByUsername,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
} 