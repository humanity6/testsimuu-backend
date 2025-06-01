class UserSubscription {
  final int id;
  final int pricingPlanId;
  final String pricingPlanName;
  final String pricingPlanPrice;
  final String pricingPlanCurrency;
  final String pricingPlanBillingCycle;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // ACTIVE, EXPIRED, CANCELLED, PENDING_PAYMENT
  final bool autoRenew;
  final DateTime? cancelledAt;
  
  // Additional properties for UI display
  final String? examName;
  final double pricePaid;

  UserSubscription({
    required this.id,
    required this.pricingPlanId,
    required this.pricingPlanName,
    required this.pricingPlanPrice,
    required this.pricingPlanCurrency,
    required this.pricingPlanBillingCycle,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.autoRenew,
    this.cancelledAt,
    this.examName,
    required this.pricePaid,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'],
      pricingPlanId: json['pricing_plan_id'],
      pricingPlanName: json['pricing_plan_name'] ?? '',
      pricingPlanPrice: json['pricing_plan_price'] ?? '0.00',
      pricingPlanCurrency: json['pricing_plan_currency'] ?? 'USD',
      pricingPlanBillingCycle: json['pricing_plan_billing_cycle'] ?? 'MONTHLY',
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      status: json['status'] ?? 'PENDING_PAYMENT',
      autoRenew: json['auto_renew'] ?? false,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      examName: json['exam_name'],
      pricePaid: double.tryParse(json['pricing_plan_price'] ?? '0.00') ?? 0.00,
    );
  }

  String get formattedPrice {
    String symbol = '\$';
    switch (pricingPlanCurrency.toUpperCase()) {
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
        symbol = pricingPlanCurrency;
        break;
    }
    return '$symbol$pricingPlanPrice';
  }

  bool get isActive => status == 'ACTIVE';
  bool get isExpired => status == 'EXPIRED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isPendingPayment => status == 'PENDING_PAYMENT';

  // Add getter for planName compatibility
  String get planName => pricingPlanName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pricing_plan_id': pricingPlanId,
      'pricing_plan_name': pricingPlanName,
      'pricing_plan_price': pricingPlanPrice,
      'pricing_plan_currency': pricingPlanCurrency,
      'pricing_plan_billing_cycle': pricingPlanBillingCycle,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'auto_renew': autoRenew,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'exam_name': examName,
      'price_paid': pricePaid,
    };
  }
} 