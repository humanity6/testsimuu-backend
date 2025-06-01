class PaymentMethod {
  final String id;
  final String name;
  final List<String> supportedCurrencies;

  PaymentMethod({
    required this.id,
    required this.name,
    required this.supportedCurrencies,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      supportedCurrencies: json['supported_currencies'] != null
          ? List<String>.from(json['supported_currencies'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'supported_currencies': supportedCurrencies,
    };
  }

  bool supportsCurrency(String currency) {
    return supportedCurrencies.contains(currency.toUpperCase());
  }
} 