class PricingPlan {
  final int id;
  final String name;
  final String slug;
  final String description;
  final String price;
  final String currency;
  final String billingCycle; // 'MONTHLY', 'QUARTERLY', 'YEARLY', 'ONE_TIME'
  final List<String> featuresList;
  final int trialDays;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? examId;
  final String? examName;

  PricingPlan({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.price,
    required this.currency,
    required this.billingCycle,
    required this.featuresList,
    this.trialDays = 0,
    this.displayOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.examId,
    this.examName,
  });

  factory PricingPlan.fromJson(Map<String, dynamic> json) {
    // Handle different formats of features_list
    List<String> featuresList = [];
    if (json['features_list'] != null) {
      if (json['features_list'] is List) {
        // Simple list format
        featuresList = List<String>.from(json['features_list']);
      } else if (json['features_list'] is Map) {
        // Complex object format
        final featuresData = json['features_list'] as Map<String, dynamic>;
        
        // Extract features from the complex object
        if (featuresData['features'] is List) {
          featuresList.addAll(List<String>.from(featuresData['features']));
        }
        
        // Optionally add limitations as additional features
        if (featuresData['limitations'] is List) {
          final limitations = List<String>.from(featuresData['limitations']);
          featuresList.addAll(limitations.map((limitation) => "Limit: $limitation"));
        }
        
        // Add support level as a feature
        if (featuresData['support_level'] != null) {
          featuresList.add("Support: ${featuresData['support_level']}");
        }
      }
    }
    
    return PricingPlan(
      id: json['id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'] ?? '',
      price: json['price']?.toString() ?? '0.00',
      currency: json['currency'] ?? 'USD',
      billingCycle: json['billing_cycle'] ?? 'ONE_TIME',
      featuresList: featuresList,
      trialDays: json['trial_days'] ?? 0,
      displayOrder: json['display_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      examId: json['exam'],
      examName: json['exam_name'],
    );
  }

  String get formattedPrice {
    String symbol = '\$';
    switch (currency.toUpperCase()) {
      case 'USD':
        symbol = '\$';
        break;
      case 'EUR':
        symbol = '€';
        break;
      case 'GBP':
        symbol = '£';
        break;
      default:
        symbol = currency;
        break;
    }

    String interval = '';
    switch (billingCycle.toUpperCase()) {
      case 'MONTHLY':
        interval = '/month';
        break;
      case 'QUARTERLY':
        interval = '/quarter';
        break;
      case 'YEARLY':
        interval = '/year';
        break;
      case 'ONE_TIME':
        interval = '';
        break;
      default:
        interval = '';
        break;
    }

    return '$symbol$price$interval';
  }

  bool get isSubscription {
    return billingCycle.toUpperCase() != 'ONE_TIME';
  }

  bool get isPopular {
    return billingCycle.toUpperCase() == 'MONTHLY';
  }

  bool get isBestValue {
    return billingCycle.toUpperCase() == 'YEARLY';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'price': price,
      'currency': currency,
      'billing_cycle': billingCycle,
      'features_list': featuresList,
      'trial_days': trialDays,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'exam': examId,
      'exam_name': examName,
    };
  }
} 