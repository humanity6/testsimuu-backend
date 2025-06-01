class Topic {
  final String id;
  final String name;
  final String? description;
  final String? parentTopicId;
  final bool isActive;
  final int displayOrder;
  final String slug;

  Topic({
    required this.id,
    required this.name,
    this.description,
    this.parentTopicId,
    required this.isActive,
    required this.displayOrder,
    required this.slug,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      parentTopicId: json['parent_topic_id']?.toString(),
      isActive: json['is_active'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      slug: json['slug']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'parent_topic_id': parentTopicId,
      'is_active': isActive,
      'display_order': displayOrder,
      'slug': slug,
    };
  }
} 