class AITemplate {
  final int id;
  final String templateName;
  final String questionType;
  final String templateContent;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  AITemplate({
    required this.id,
    required this.templateName,
    required this.questionType,
    required this.templateContent,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory AITemplate.fromJson(Map<String, dynamic> json) {
    return AITemplate(
      id: json['id'] ?? 0,
      templateName: json['template_name'] ?? '',
      questionType: json['question_type'] ?? '',
      templateContent: json['template_content'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_name': templateName,
      'question_type': questionType,
      'template_content': templateContent,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  // Helper getters for backward compatibility with UI
  String get name => templateName;
  String get template => templateContent;
  String get description => 'AI Feedback Template for $questionType questions';
  List<String> get variables => _extractVariablesFromTemplate(templateContent);

  // Extract variables from template content (look for {variable_name} patterns)
  static List<String> _extractVariablesFromTemplate(String templateContent) {
    final regex = RegExp(r'\{([^}]+)\}');
    final matches = regex.allMatches(templateContent);
    return matches.map((match) => match.group(1)?.trim() ?? '').where((v) => v.isNotEmpty).toList();
  }
} 