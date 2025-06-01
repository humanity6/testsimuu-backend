class Subscription {
  final String id;
  final String userId;
  final String pricingPlanId;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
  final String? paymentGatewaySubscriptionId;
  final bool autoRenew;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool renewalReminderSent;
  final String name;  // From pricing plan
  final double price;  // From pricing plan
  final String currency;  // From pricing plan
  
  // Admin-specific fields
  final String? userEmail;
  final String? userName;
  final String? examName;

  Subscription({
    required this.id,
    required this.userId,
    required this.pricingPlanId,
    required this.startDate,
    this.endDate,
    required this.status,
    this.paymentGatewaySubscriptionId,
    required this.autoRenew,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
    required this.renewalReminderSent,
    required this.name,
    required this.price,
    required this.currency,
    this.userEmail,
    this.userName,
    this.examName,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'].toString(),
      // Handle both 'user' and 'user_id' formats
      userId: (json['user'] ?? json['user_id']).toString(),
      // Handle both 'pricing_plan' and 'pricing_plan_id' formats
      pricingPlanId: (json['pricing_plan'] ?? json['pricing_plan_id']).toString(),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      status: json['status'] ?? 'PENDING',
      paymentGatewaySubscriptionId: json['payment_gateway_subscription_id'],
      autoRenew: json['auto_renew'] ?? true,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      renewalReminderSent: json['renewal_reminder_sent'] ?? false,
      // Use the flat pricing plan fields from the API response
      name: json['pricing_plan_name'] ?? 'Unknown Plan',
      // Parse price from string field, with fallback to 0.0
      price: _parsePrice(json['pricing_plan_price']),
      currency: json['pricing_plan_currency'] ?? 'USD',
      // Admin-specific fields
      userEmail: json['user_email'],
      userName: json['user_username'],
      examName: json['exam_name'],
    );
  }

  // Helper method to safely parse price
  static double _parsePrice(dynamic priceValue) {
    if (priceValue == null) return 0.0;
    
    if (priceValue is String) {
      return double.tryParse(priceValue) ?? 0.0;
    }
    
    if (priceValue is num) {
      return priceValue.toDouble();
    }
    
    return 0.0;
  }

  // Getters for admin compatibility
  String get planName => name;
  double get amount => price;
  String get billingCycle => 'MONTHLY'; // Default, could be enhanced later
  
  // Status logs for admin interface (stub for now)
  List<StatusLog> get statusLogs => [
    StatusLog(
      status: status,
      timestamp: updatedAt,
      changedBy: 'System',
      note: 'Current status',
    ),
  ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pricing_plan_id': pricingPlanId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'payment_gateway_subscription_id': paymentGatewaySubscriptionId,
      'auto_renew': autoRenew,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'renewal_reminder_sent': renewalReminderSent,
      'user_email': userEmail,
      'user_username': userName,
      'exam_name': examName,
    };
  }
}

class StatusLog {
  final String status;
  final DateTime timestamp;
  final String changedBy;
  final String note;

  StatusLog({
    required this.status,
    required this.timestamp,
    required this.changedBy,
    this.note = '',
  });
} 