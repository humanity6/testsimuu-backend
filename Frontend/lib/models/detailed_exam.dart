import 'package:flutter/material.dart';
import 'exam.dart';

class PricingPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String billingCycle; // 'MONTHLY', 'QUARTERLY', 'YEARLY', 'ONE_TIME'
  final List<String> features;
  final int trialDays;
  final bool isPopular;

  PricingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.billingCycle,
    required this.features,
    this.trialDays = 0,
    this.isPopular = false,
  });

  factory PricingPlan.fromJson(Map<String, dynamic> json) {
    return PricingPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      billingCycle: json['billing_cycle'] ?? 'ONE_TIME',
      features: json['features_list'] != null
          ? List<String>.from(json['features_list'])
          : [],
      trialDays: json['trial_days'] ?? 0,
      isPopular: json['is_popular'] ?? false,
    );
  }

  String get formattedPrice {
    String symbol = '€';
    switch (currency) {
      case 'USD':
        symbol = '\$';
        break;
      case 'EUR':
        symbol = '€';
        break;
      case 'GBP':
        symbol = '£';
        break;
    }

    String interval = '';
    switch (billingCycle) {
      case 'MONTHLY':
        interval = '/month';
        break;
      case 'QUARTERLY':
        interval = '/quarter';
        break;
      case 'YEARLY':
        interval = '/year';
        break;
    }

    return '$symbol$price$interval';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'billing_cycle': billingCycle,
      'features_list': features,
      'trial_days': trialDays,
      'is_popular': isPopular,
    };
  }
}

class DetailedExam extends Exam {
  final String? parentExamId;
  final List<DetailedExam> subExams;
  final String? userProgress;
  final String? subscriptionStatus; // 'ACTIVE', 'EXPIRED', 'NOT_SUBSCRIBED'
  final DateTime? subscriptionEndDate;
  final List<PricingPlan> pricingPlans;

  DetailedExam({
    required super.id,
    required super.title,
    required super.description,
    required super.subject,
    required super.difficulty,
    required super.questionCount,
    required super.timeLimit,
    super.imageUrl = '',
    super.rating = 0.0,
    super.completionCount = 0,
    super.requiresSubscription = false,
    this.parentExamId,
    this.subExams = const [],
    this.userProgress,
    this.subscriptionStatus,
    this.subscriptionEndDate,
    this.pricingPlans = const [],
  });

  factory DetailedExam.fromJson(Map<String, dynamic> json) {
    final List<DetailedExam> subExams = [];
    if (json['sub_exams'] != null) {
      subExams.addAll(
        (json['sub_exams'] as List).map((e) => DetailedExam.fromJson(e)).toList(),
      );
    }

    final List<PricingPlan> pricingPlans = [];
    if (json['pricing_plans'] != null) {
      pricingPlans.addAll(
        (json['pricing_plans'] as List).map((e) => PricingPlan.fromJson(e)).toList(),
      );
    }

    return DetailedExam(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      subject: json['subject'] ?? '',
      difficulty: json['difficulty'] ?? 'Beginner',
      questionCount: json['question_count'] ?? 0,
      timeLimit: json['time_limit'] ?? 60,
      imageUrl: json['image_url'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      completionCount: json['completion_count'] ?? 0,
      requiresSubscription: json['requires_subscription'] ?? false,
      parentExamId: json['parent_exam_id'],
      subExams: subExams,
      userProgress: json['user_progress'],
      subscriptionStatus: json['subscription_status'],
      subscriptionEndDate: json['subscription_end_date'] != null
          ? DateTime.parse(json['subscription_end_date'])
          : null,
      pricingPlans: pricingPlans,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = super.toJson();
    data['parent_exam_id'] = parentExamId;
    data['sub_exams'] = subExams.map((e) => e.toJson()).toList();
    data['user_progress'] = userProgress;
    data['subscription_status'] = subscriptionStatus;
    data['subscription_end_date'] = subscriptionEndDate?.toIso8601String();
    data['pricing_plans'] = pricingPlans.map((e) => e.toJson()).toList();
    return data;
  }

  bool get isSubscribed => subscriptionStatus == 'ACTIVE';
  bool get isExpired => subscriptionStatus == 'EXPIRED';
  bool get hasSubExams => subExams.isNotEmpty;
  
  Color getSubscriptionStatusColor() {
    switch (subscriptionStatus) {
      case 'ACTIVE':
        return Colors.green;
      case 'EXPIRED':
        return Colors.red;
      case 'NOT_SUBSCRIBED':
      default:
        return Colors.grey;
    }
  }

  int get daysRemaining {
    if (subscriptionEndDate == null) return 0;
    final now = DateTime.now();
    return subscriptionEndDate!.difference(now).inDays;
  }

  bool get isExpiringSoon {
    return isSubscribed && daysRemaining <= 7 && daysRemaining >= 0;
  }

  // Create a copy of this DetailedExam with optional modifications
  DetailedExam copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    String? difficulty,
    int? questionCount,
    int? timeLimit,
    String? imageUrl,
    double? rating,
    int? completionCount,
    bool? requiresSubscription,
    String? parentExamId,
    List<DetailedExam>? subExams,
    String? userProgress,
    String? subscriptionStatus,
    DateTime? subscriptionEndDate,
    List<PricingPlan>? pricingPlans,
  }) {
    return DetailedExam(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      difficulty: difficulty ?? this.difficulty,
      questionCount: questionCount ?? this.questionCount,
      timeLimit: timeLimit ?? this.timeLimit,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      completionCount: completionCount ?? this.completionCount,
      requiresSubscription: requiresSubscription ?? this.requiresSubscription,
      parentExamId: parentExamId ?? this.parentExamId,
      subExams: subExams ?? this.subExams,
      userProgress: userProgress ?? this.userProgress,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      pricingPlans: pricingPlans ?? this.pricingPlans,
    );
  }
} 