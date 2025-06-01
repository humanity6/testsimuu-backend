class Affiliate {
  final int id;
  final String name;
  final String email;
  final String? website;
  final String? description;
  final String commissionModel;
  final double commissionRate;
  final double fixedFee;
  final String trackingCode;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double totalEarnings;
  final double pendingEarnings;

  Affiliate({
    required this.id,
    required this.name,
    required this.email,
    this.website,
    this.description,
    required this.commissionModel,
    required this.commissionRate,
    required this.fixedFee,
    required this.trackingCode,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.totalEarnings,
    required this.pendingEarnings,
  });

  factory Affiliate.fromJson(Map<String, dynamic> json) {
    return Affiliate(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      website: json['website'],
      description: json['description'],
      commissionModel: json['commission_model'] ?? '',
      commissionRate: _parseDouble(json['commission_rate']),
      fixedFee: _parseDouble(json['fixed_fee']),
      trackingCode: json['tracking_code'] ?? '',
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      totalEarnings: _parseDouble(json['total_earnings']),
      pendingEarnings: _parseDouble(json['pending_earnings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'website': website,
      'description': description,
      'commission_model': commissionModel,
      'commission_rate': commissionRate,
      'fixed_fee': fixedFee,
      'tracking_code': trackingCode,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'total_earnings': totalEarnings,
      'pending_earnings': pendingEarnings,
    };
  }
}

class AffiliatePlan {
  final int id;
  final String name;
  final String description;
  final String planType;
  final double commissionPerDownload;
  final double commissionPerSubscription;
  final double commissionPercentage;
  final double fixedMonthlyPayment;
  final int minimumFollowers;
  final int minimumMonthlyConversions;
  final String commissionSummary;
  final bool isActive;
  final bool isAutoApproval;
  final DateTime createdAt;
  final DateTime updatedAt;

  AffiliatePlan({
    required this.id,
    required this.name,
    required this.description,
    required this.planType,
    required this.commissionPerDownload,
    required this.commissionPerSubscription,
    required this.commissionPercentage,
    required this.fixedMonthlyPayment,
    required this.minimumFollowers,
    required this.minimumMonthlyConversions,
    required this.commissionSummary,
    required this.isActive,
    required this.isAutoApproval,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AffiliatePlan.fromJson(Map<String, dynamic> json) {
    return AffiliatePlan(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      planType: json['plan_type'] ?? '',
      commissionPerDownload: _parseDouble(json['commission_per_download']),
      commissionPerSubscription: _parseDouble(json['commission_per_subscription']),
      commissionPercentage: _parseDouble(json['commission_percentage']),
      fixedMonthlyPayment: _parseDouble(json['fixed_monthly_payment']),
      minimumFollowers: json['minimum_followers'] ?? 0,
      minimumMonthlyConversions: json['minimum_monthly_conversions'] ?? 0,
      commissionSummary: json['commission_summary'] ?? '',
      isActive: json['is_active'] ?? false,
      isAutoApproval: json['is_auto_approval'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  String get planTypeDisplay {
    switch (planType) {
      case 'PURE_AFFILIATE':
        return 'Pure Affiliate';
      case 'FIXED_PLUS_COMMISSION':
        return 'Fixed + Commission';
      case 'TIERED_COMMISSION':
        return 'Tiered Commission';
      default:
        return planType;
    }
  }
}

class AffiliateApplication {
  final int id;
  final String userEmail;
  final int requestedPlan;
  final String planName;
  final String? businessName;
  final String? websiteUrl;
  final Map<String, dynamic>? socialMediaLinks;
  final String audienceDescription;
  final String promotionStrategy;
  final int followerCount;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  AffiliateApplication({
    required this.id,
    required this.userEmail,
    required this.requestedPlan,
    required this.planName,
    this.businessName,
    this.websiteUrl,
    this.socialMediaLinks,
    required this.audienceDescription,
    required this.promotionStrategy,
    required this.followerCount,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AffiliateApplication.fromJson(Map<String, dynamic> json) {
    return AffiliateApplication(
      id: json['id'] ?? 0,
      userEmail: json['user_email'] ?? '',
      requestedPlan: json['requested_plan'] ?? 0,
      planName: json['plan_name'] ?? 'Unknown Plan',
      businessName: json['business_name'],
      websiteUrl: json['website_url'],
      socialMediaLinks: json['social_media_links'],
      audienceDescription: json['audience_description'] ?? '',
      promotionStrategy: json['promotion_strategy'] ?? '',
      followerCount: json['follower_count'] ?? 0,
      status: json['status'] ?? 'PENDING',
      adminNotes: json['admin_notes'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'PENDING':
        return 'Pending Review';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'UNDER_REVIEW':
        return 'Under Review';
      default:
        return status;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'requested_plan': requestedPlan,
      'business_name': businessName,
      'website_url': websiteUrl,
      'social_media_links': socialMediaLinks,
      'audience_description': audienceDescription,
      'promotion_strategy': promotionStrategy,
      'follower_count': followerCount,
    };
  }
}

class AffiliateLink {
  final int id;
  final String name;
  final String linkType;
  final String targetUrl;
  final String trackingId;
  final String utmMedium;
  final String? utmCampaign;
  final int clickCount;
  final String fullUrl;
  final double conversionRate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AffiliateLink({
    required this.id,
    required this.name,
    required this.linkType,
    required this.targetUrl,
    required this.trackingId,
    required this.utmMedium,
    this.utmCampaign,
    required this.clickCount,
    required this.fullUrl,
    required this.conversionRate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AffiliateLink.fromJson(Map<String, dynamic> json) {
    return AffiliateLink(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      linkType: json['link_type'] ?? '',
      targetUrl: json['target_url'] ?? '',
      trackingId: json['tracking_id'] ?? '',
      utmMedium: json['utm_medium'] ?? '',
      utmCampaign: json['utm_campaign'],
      clickCount: json['click_count'] ?? 0,
      fullUrl: json['full_url'] ?? '',
      conversionRate: _parseDouble(json['conversion_rate']),
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
    );
  }
}

class AffiliateStatistics {
  final int totalClicks;
  final int totalConversions;
  final double conversionRate;
  final double totalEarnings;
  final double pendingEarnings;
  final Map<String, int> conversionBreakdown;
  final List<Map<String, dynamic>> recentConversions;
  final List<Map<String, dynamic>> topLinks;

  AffiliateStatistics({
    required this.totalClicks,
    required this.totalConversions,
    required this.conversionRate,
    required this.totalEarnings,
    required this.pendingEarnings,
    required this.conversionBreakdown,
    required this.recentConversions,
    required this.topLinks,
  });

  factory AffiliateStatistics.fromJson(Map<String, dynamic> json) {
    // Safely handle conversion breakdown which might be null or in different formats
    Map<String, int> conversionBreakdown = {};
    if (json['conversion_breakdown'] != null) {
      if (json['conversion_breakdown'] is Map) {
        try {
          conversionBreakdown = Map<String, int>.from(json['conversion_breakdown']);
        } catch (e) {
          // If conversion fails, use empty map
          conversionBreakdown = {};
        }
      }
    }

    // Safely handle list types
    List<Map<String, dynamic>> recentConversions = [];
    if (json['recent_conversions'] != null && json['recent_conversions'] is List) {
      recentConversions = List<Map<String, dynamic>>.from(json['recent_conversions']);
    }

    List<Map<String, dynamic>> topLinks = [];
    if (json['top_links'] != null && json['top_links'] is List) {
      topLinks = List<Map<String, dynamic>>.from(json['top_links']);
    }

    return AffiliateStatistics(
      totalClicks: json['total_clicks'] ?? 0,
      totalConversions: json['total_conversions'] ?? 0,
      conversionRate: _parseDouble(json['conversion_rate']),
      totalEarnings: _parseDouble(json['total_earnings']),
      pendingEarnings: _parseDouble(json['pending_earnings']),
      conversionBreakdown: conversionBreakdown,
      recentConversions: recentConversions,
      topLinks: topLinks,
    );
  }
}

// Helper function to safely parse doubles
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  try {
    return double.parse(value.toString());
  } catch (e) {
    return 0.0;
  }
} 