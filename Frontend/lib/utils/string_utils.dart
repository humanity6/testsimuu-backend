class StringUtils {
  /// Converts camelCase or snake_case strings to normal formatted strings
  /// Example: "rewardType" -> "Reward Type"
  /// Example: "reward_type" -> "Reward Type"
  /// Example: "DISCOUNT_PERCENTAGE" -> "Discount Percentage"
  static String formatCamelCase(String input) {
    if (input.isEmpty) return input;
    
    // Handle UPPER_CASE_WITH_UNDERSCORES
    if (input.contains('_') && input == input.toUpperCase()) {
      return input
          .toLowerCase()
          .split('_')
          .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
          .join(' ');
    }
    
    // Handle snake_case
    if (input.contains('_')) {
      return input
          .split('_')
          .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
          .join(' ');
    }
    
    // Handle camelCase
    String result = input.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    
    // Capitalize first letter
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    
    return result;
  }
  
  /// Converts a field name to a user-friendly label
  /// Example: "referrerRewardType" -> "Referrer Reward Type"
  /// Example: "min_purchase_amount" -> "Minimum Purchase Amount"
  static String formatFieldName(String fieldName) {
    // Special cases for common field names
    final specialCases = {
      'id': 'ID',
      'url': 'URL',
      'api': 'API',
      'ui': 'UI',
      'uuid': 'UUID',
      'json': 'JSON',
      'xml': 'XML',
      'html': 'HTML',
      'css': 'CSS',
      'js': 'JavaScript',
      'sql': 'SQL',
      'db': 'Database',
    };
    
    String formatted = formatCamelCase(fieldName);
    
    // Replace special cases
    for (String key in specialCases.keys) {
      RegExp regex = RegExp('\\b${key}\\b', caseSensitive: false);
      formatted = formatted.replaceAllMapped(regex, (match) => specialCases[key]!);
    }
    
    return formatted;
  }
  
  /// Formats enum values to readable text
  /// Example: "DISCOUNT_PERCENTAGE" -> "Percentage Discount"
  /// Example: "EXTEND_SUBSCRIPTION_DAYS" -> "Extend Subscription Days"
  static String formatEnumValue(String enumValue) {
    if (enumValue.isEmpty) return enumValue;
    
    // Handle specific enum patterns
    final enumMappings = {
      'DISCOUNT_PERCENTAGE': 'Percentage Discount',
      'DISCOUNT_FIXED': 'Fixed Amount Discount',
      'EXTEND_SUBSCRIPTION_DAYS': 'Extend Subscription',
      'CREDIT': 'Account Credit',
    };
    
    if (enumMappings.containsKey(enumValue)) {
      return enumMappings[enumValue]!;
    }
    
    // Default formatting
    return formatCamelCase(enumValue);
  }
} 