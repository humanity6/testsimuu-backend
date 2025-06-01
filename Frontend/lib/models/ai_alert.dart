class AIAlert {
  final String id;
  final String title;
  final String source;
  final String alertType;
  final String? relatedTopicId;
  final String? relatedQuestionId;
  final String summaryOfPotentialChange;
  final String? detailedExplanation;
  final List<String>? sourceUrls;
  final double confidenceScore;
  final String priority;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final String? reviewedByAdminId;
  final DateTime? reviewedAt;
  final String? actionTaken;

  AIAlert({
    required this.id,
    required this.title,
    required this.source,
    required this.alertType,
    this.relatedTopicId,
    this.relatedQuestionId,
    required this.summaryOfPotentialChange,
    this.detailedExplanation,
    this.sourceUrls,
    required this.confidenceScore,
    required this.priority,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    this.reviewedByAdminId,
    this.reviewedAt,
    this.actionTaken,
  });

  factory AIAlert.fromJson(Map<String, dynamic> json) {
    return AIAlert(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      source: json['source'] ?? '',
      alertType: json['alert_type'] ?? '',
      relatedTopicId: json['related_topic_id']?.toString(),
      relatedQuestionId: json['related_question_id']?.toString(),
      summaryOfPotentialChange: json['summary_of_potential_change'] ?? '',
      detailedExplanation: json['detailed_explanation'],
      sourceUrls: json['source_urls'] != null 
        ? List<String>.from(json['source_urls'])
        : null,
      confidenceScore: (json['ai_confidence_score'] ?? 0.0).toDouble(),
      priority: json['priority'] ?? 'MEDIUM',
      status: json['status'] ?? 'NEW',
      adminNotes: json['admin_notes'],
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at'])
        : DateTime.now(),
      reviewedByAdminId: json['reviewed_by_admin_id']?.toString(),
      reviewedAt: json['reviewed_at'] != null 
        ? DateTime.parse(json['reviewed_at'])
        : null,
      actionTaken: json['action_taken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'alert_type': alertType,
      'related_topic_id': relatedTopicId,
      'related_question_id': relatedQuestionId,
      'summary_of_potential_change': summaryOfPotentialChange,
      'detailed_explanation': detailedExplanation,
      'source_urls': sourceUrls,
      'ai_confidence_score': confidenceScore,
      'priority': priority,
      'status': status,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'reviewed_by_admin_id': reviewedByAdminId,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'action_taken': actionTaken,
    };
  }
} 