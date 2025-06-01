class PaymentTransaction {
  final int id;
  final String userEmail;
  final double amount;
  final String currency;
  final String status; // PENDING, SUCCESSFUL, FAILED, REFUNDED
  final String? paymentGatewayTransactionId;
  final DateTime transactionTime;
  final String? invoiceNumber;
  final String? refundReference;
  
  // Additional properties for UI display
  final String? paymentMethod;
  final String? examName;
  final String? planName;
  final String? last4;
  
  // Admin-specific fields
  final String? userName;
  final String? paymentSource;
  final String? description;

  PaymentTransaction({
    required this.id,
    required this.userEmail,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentGatewayTransactionId,
    required this.transactionTime,
    this.invoiceNumber,
    this.refundReference,
    this.paymentMethod,
    this.examName,
    this.planName,
    this.last4,
    this.userName,
    this.paymentSource,
    this.description,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'],
      userEmail: json['user_email'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.00,
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? 'PENDING',
      paymentGatewayTransactionId: json['payment_gateway_transaction_id'],
      transactionTime: DateTime.parse(json['transaction_time']),
      invoiceNumber: json['invoice_number'],
      refundReference: json['refund_reference'],
      paymentMethod: json['payment_method_details']?['type'] ?? 'card',
      examName: json['subscription_plan']?['exam_name'],
      planName: json['subscription_plan']?['name'],
      last4: json['payment_method_details']?['last_four'],
      // Admin-specific fields - derive from available data
      userName: json['user_email']?.split('@')[0] ?? 'Unknown', // Extract username from email
      paymentSource: _getPaymentSourceFromMethod(json['payment_method_details']?['type']),
      description: json['description'] ?? 'Subscription payment',
    );
  }

  // Helper method to map payment method to user-friendly source
  static String _getPaymentSourceFromMethod(String? method) {
    switch (method?.toLowerCase()) {
      case 'card':
        return 'Credit Card';
      case 'paypal':
        return 'PayPal';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'apple_pay':
        return 'Apple Pay';
      case 'google_pay':
        return 'Google Pay';
      default:
        return 'Credit Card'; // Default fallback
    }
  }

  String get formattedAmount {
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
    return '$symbol${amount.toStringAsFixed(2)}';
  }
  
  // Add getters for admin compatibility
  DateTime get date => transactionTime;
  DateTime get timestamp => transactionTime;
  String get userId => id.toString(); // Convert ID to string for consistency

  bool get isSuccessful => status == 'SUCCESSFUL';
  bool get isPending => status == 'PENDING';
  bool get isFailed => status == 'FAILED';
  bool get isRefunded => status == 'REFUNDED';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_email': userEmail,
      'amount': amount.toString(),
      'currency': currency,
      'status': status,
      'payment_gateway_transaction_id': paymentGatewayTransactionId,
      'transaction_time': transactionTime.toIso8601String(),
      'invoice_number': invoiceNumber,
      'refund_reference': refundReference,
      'payment_method': paymentMethod,
      'exam_name': examName,
      'plan_name': planName,
      'last4': last4,
      'user_name': userName,
      'payment_source': paymentSource,
      'description': description,
    };
  }
} 