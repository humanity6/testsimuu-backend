import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiConfig {
  // Production server configuration for Hetzner Cloud
  static String get baseUrl {
    // For web, we might need to handle environment differently
    try {
      const envBaseUrl = String.fromEnvironment('API_BASE_URL');
      if (envBaseUrl.isNotEmpty) {
        return envBaseUrl;
      }
    } catch (e) {
      // Fallback to default if environment variable is not set
    }
    
    // For web platform in development
    if (kIsWeb) {
      return 'http://188.245.35.46';  // Production server
    }
    
    // For native platforms (Android/iOS) - using production server
    // Updated to use Hetzner Cloud server for production deployment
    return 'http://188.245.35.46';  // Production server
  }
  
  // API version paths
  static const String apiV1Path = '/api/v1';
  
  // Full path for API v1 endpoints
  static String get apiV1Url => '$baseUrl$apiV1Path';
  
  // Base API URL for direct calls
  static String get apiBaseUrl => baseUrl;
  
  // Authentication endpoints
  static String get authLoginEndpoint => '$apiV1Url/auth/login/';
  static String get authRegisterEndpoint => '$apiV1Url/auth/register/';
  static String get authRefreshEndpoint => '$apiV1Url/auth/refresh/';
  static String get authLogoutEndpoint => '$apiV1Url/auth/logout/';
  static String get passwordResetEndpoint => '$apiV1Url/auth/password-reset/';
  static String get passwordResetConfirmEndpoint => '$apiV1Url/auth/password-reset-confirm/';
  
  // User endpoints
  static String get userProfileEndpoint => '$apiV1Url/users/me/';
  static String get userSubscriptionsEndpoint => '$apiV1Url/users/me/subscriptions/';
  static String get userPaymentsEndpoint => '$apiV1Url/users/me/payments/';
  static String get userPreferencesEndpoint => '$apiV1Url/users/me/preferences/';
  static String get userNotificationsEndpoint => '$apiV1Url/users/me/notifications/';
  static String get userMarkAllNotificationsReadEndpoint => '$apiV1Url/users/me/notifications/mark-all-as-read/';
  
  // Exam and question endpoints
  static String get examsEndpoint => '$apiV1Url/exams/';
  static String get topicsEndpoint => '$apiV1Url/topics/';
  static String get questionsEndpoint => '$apiV1Url/questions/';
  static String get tagsEndpoint => '$apiV1Url/tags/';
  
  // Subscription and payment endpoints
  static String get pricingPlansEndpoint => '$apiV1Url/pricing-plans/';
  static String get paymentsVerifyEndpoint => '$apiV1Url/payments/verify/';
  static String get paymentMethodsEndpoint => '$apiV1Url/payments/methods/';
  static String get referralProgramsEndpoint => '$apiV1Url/referral-programs/';
  static String get referralsApplyEndpoint => '$apiV1Url/referrals/apply/';
  
  // Exam sessions and assessment endpoints
  static String get examSessionsEndpoint => '$apiV1Url/exam-sessions/';
  static String get userAnswersEndpoint => '$apiV1Url/user-answers/';
  
  // Performance and analytics endpoints
  static String get performanceSummaryEndpoint => '$apiV1Url/users/me/performance/summary/';
  static String get performanceByTopicEndpoint => '$apiV1Url/users/me/performance/by-topic/';
  static String get performanceByDifficultyEndpoint => '$apiV1Url/users/me/performance/by-difficulty/';
  static String get performanceTrendsEndpoint => '$apiV1Url/users/me/performance/trends/';
  static String get progressByTopicEndpoint => '$apiV1Url/users/me/progress/by-topic/';
  static String get studySessionsEndpoint => '$apiV1Url/exam-sessions/';
  
  // Support and FAQ endpoints
  static String get faqItemsEndpoint => '$apiV1Url/faq-items/';
  static String get supportTicketsEndpoint => '$apiV1Url/support/tickets/';
  static String get createSupportTicketEndpoint => '$apiV1Url/support/tickets/create/';
  
  // AI Integration endpoints
  static String get evaluateAnswerEndpoint => '$apiV1Url/ai/evaluate/answer/';
  static String get evaluateBatchEndpoint => '$apiV1Url/ai/evaluate/batch/';
  static String get aiExplainEndpoint => '$apiV1Url/ai/explain/';
  static String get contentAlertsEndpoint => '$apiV1Url/ai/content-alerts/';
  static String get chatbotConversationsEndpoint => '$apiV1Url/ai/chatbot/conversations/';
  static String get chatbotSendMessageEndpoint => '$apiV1Url/ai/chatbot/conversations/send_message/';
  static String get chatbotActiveConversationEndpoint => '$apiV1Url/ai/chatbot/conversations/active_conversation/';
  static String get chatbotConversationHistoryEndpoint => '$apiV1Url/ai/chatbot/conversations/';
  static String get chatbotEndConversationEndpoint => '$apiV1Url/ai/chatbot/conversations/';
  
  // Affiliate endpoints
  static String get affiliateMeEndpoint => '$apiV1Url/affiliates/me/';
  static String get affiliateLinksEndpoint => '$apiV1Url/affiliates/me/links/';
  static String get affiliateVoucherCodesEndpoint => '$apiV1Url/affiliates/me/voucher-codes/';
  static String get affiliateStatisticsEndpoint => '$apiV1Url/affiliates/me/statistics/';
  static String get affiliateTrackClickEndpoint => '$apiV1Url/affiliates/track-click/';
  static String get affiliateApplyVoucherEndpoint => '$apiV1Url/affiliates/apply-voucher/';
  static String get affiliatePlansEndpoint => '$apiV1Url/affiliates/plans/';
  static String get affiliateApplicationsEndpoint => '$apiV1Url/affiliates/applications/';
  static String get affiliateOpportunitiesEndpoint => '$apiV1Url/affiliates/opportunities/';
  static String get affiliateStatusEndpoint => '$apiV1Url/affiliates/status/';
  
  // Admin endpoints
  static String get adminUsersEndpoint => '$apiV1Url/admin/users/';
  static String get adminQuestionsEndpoint => '$apiV1Url/admin/questions/questions/';
  static String get adminTopicsEndpoint => '$apiV1Url/admin/questions/topics/';
  static String get adminTagsEndpoint => '$apiV1Url/admin/questions/tags/';
  static String get adminSubscriptionsEndpoint => '$apiV1Url/admin/subscriptions/subscriptions/';
  static String get adminPricingPlansEndpoint => '$apiV1Url/admin/subscriptions/pricing-plans/';
  
  // Admin AI endpoints
  static String get adminAIContentAlertsEndpoint => '$apiV1Url/admin/ai/content-alerts/';
  static String get adminAIContentScanConfigsEndpoint => '$apiV1Url/admin/ai/content-scan-configs/';
  static String get adminAIContentScanLogsEndpoint => '$apiV1Url/admin/ai/content-scan-logs/';
  static String get adminAIFeedbackTemplatesEndpoint => '$apiV1Url/admin/ai/feedback-templates/';
  static String get adminAIEvaluationLogsEndpoint => '$apiV1Url/admin/ai/evaluation-logs/';
  static String get adminAIChatbotConversationsEndpoint => '$apiV1Url/admin/ai/chatbot/conversations/';
  static String get adminAIChatbotMessagesEndpoint => '$apiV1Url/admin/ai/chatbot/messages/';
  static String get adminAIEvaluateAnswerEndpoint => '$apiV1Url/admin/ai/evaluate/answer/';
  static String get adminAIEvaluateBatchEndpoint => '$apiV1Url/admin/ai/evaluate/batch/';
  
  // Admin Support endpoints
  static String get adminSupportFAQEndpoint => '$apiV1Url/admin/support/faq-items/';
  static String get adminSupportTicketsEndpoint => '$apiV1Url/admin/support/tickets/';
  
  // Admin Analytics endpoints
  static String get adminAnalyticsEndpoint => '$apiV1Url/admin/analytics/';
  static String get adminPaymentsEndpoint => '$apiV1Url/admin/subscriptions/payments/';
  
  // Helper method to create a URL for a specific endpoint
  static String getUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
  
  // Helper method to create an API v1 URL for a specific endpoint
  static String getApiV1Url(String endpoint) {
    return '$apiV1Url$endpoint';
  }
  
  // Check if the API is available
  static Future<bool> checkApiAvailability() async {
    try {
      // Try to access a simple endpoint to check connectivity
      final response = await http.get(
        Uri.parse('$baseUrl/admin/'),
      ).timeout(const Duration(seconds: 10));

      // Any response from the admin endpoint means the API is up
      return response.statusCode != 404 && response.statusCode != 500;
    } catch (e) {
      print('API availability check failed: $e');
      return false;
    }
  }
  
  // Comprehensive API health check for all major endpoints
  static Future<Map<String, bool>> checkAllEndpoints() async {
    final results = <String, bool>{};
    
    // Test endpoints without authentication
    final publicEndpoints = {
      'base': baseUrl,
      'admin': '$baseUrl/admin/',
      'pricing_plans': pricingPlansEndpoint,
      'faq_items': faqItemsEndpoint,
    };
    
    for (final entry in publicEndpoints.entries) {
      try {
        final response = await http.get(
          Uri.parse(entry.value),
        ).timeout(const Duration(seconds: 5));
        
        // Consider 200, 401, 403 as "working" (server is responding)
        results[entry.key] = response.statusCode < 500;
      } catch (e) {
        results[entry.key] = false;
      }
    }
    
    return results;
  }
  
  // Test authenticated endpoints (requires token)
  static Future<Map<String, bool>> checkAuthenticatedEndpoints(String token) async {
    final results = <String, bool>{};
    
    final authEndpoints = {
      'user_profile': userProfileEndpoint,
      'user_subscriptions': userSubscriptionsEndpoint,
      'performance_summary': performanceSummaryEndpoint,
      'exams': examsEndpoint,
      'topics': topicsEndpoint,
      'questions': questionsEndpoint,
    };
    
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    
    for (final entry in authEndpoints.entries) {
      try {
        final response = await http.get(
          Uri.parse(entry.value),
          headers: headers,
        ).timeout(const Duration(seconds: 5));
        
        // Consider 200, 401, 403 as "working" (server is responding)
        results[entry.key] = response.statusCode < 500;
      } catch (e) {
        results[entry.key] = false;
      }
    }
    
    return results;
  }
} 