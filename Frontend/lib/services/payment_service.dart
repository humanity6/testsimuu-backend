import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../models/payment_transaction.dart';
import '../models/user_subscription.dart';
import '../models/pricing_plan.dart';
import '../models/payment_method.dart';

class PaymentService extends ChangeNotifier {
  final String baseUrl = ApiConfig.baseUrl;
  
  bool _isLoading = false;
  String? _error;
  List<UserSubscription> _subscriptions = [];
  List<PaymentTransaction> _transactions = [];
  List<PricingPlan> _pricingPlans = [];
  List<PaymentMethod> _paymentMethods = [];
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserSubscription> get subscriptions => _subscriptions;
  List<PaymentTransaction> get transactions => _transactions;
  List<PricingPlan> get pricingPlans => _pricingPlans;
  List<PaymentMethod> get paymentMethods => _paymentMethods;

  Future<List<PricingPlan>> getPricingPlans({String? token, int? examId, String? examSlug}) async {
    try {
      _isLoading = true;
      _error = null;
      // Don't call notifyListeners() here - let the caller handle UI updates
      
      String url = ApiConfig.pricingPlansEndpoint;
      
      // Add query parameters if provided
      List<String> queryParams = [];
      if (examId != null) queryParams.add('exam_id=$examId');
      if (examSlug != null) queryParams.add('exam_slug=$examSlug');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }
      
      Map<String, String> headers = {'Content-Type': 'application/json'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(Uri.parse(url), headers: headers);

      _isLoading = false;
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData is List 
            ? responseData 
            : (responseData['results'] as List<dynamic>);
        _pricingPlans = data.map((json) => PricingPlan.fromJson(json)).toList();
        
        // Sort by display order
        _pricingPlans.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        
        // Don't call notifyListeners() here - let the caller handle UI updates
        return _pricingPlans;
      } else {
        _error = 'Failed to load pricing plans: ${response.statusCode}';
        // Don't call notifyListeners() here - let the caller handle UI updates
        throw Exception(_error);
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error fetching pricing plans: $e';
      // Don't call notifyListeners() here - let the caller handle UI updates
      throw Exception(_error);
    }
  }

  Future<List<PaymentMethod>> getPaymentMethods(String token) async {
    try {
      _isLoading = true;
      _error = null;
      
      final response = await http.get(
        Uri.parse(ApiConfig.paymentMethodsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      _isLoading = false;
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData is List 
            ? responseData 
            : (responseData['results'] as List<dynamic>);
        _paymentMethods = data.map((json) => PaymentMethod.fromJson(json)).toList();
        notifyListeners();
        return _paymentMethods;
      } else {
        _error = 'Failed to load payment methods: ${response.statusCode}';
        throw Exception(_error);
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error fetching payment methods: $e';
      throw Exception(_error);
    }
  }

  Future<Map<String, dynamic>> createSubscription(String token, int pricingPlanId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await http.post(
        Uri.parse(ApiConfig.userSubscriptionsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'pricing_plan_id': pricingPlanId}),
      );

      _isLoading = false;
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        notifyListeners();
        
        // Don't refresh subscriptions immediately as payment might be pending
        // await getUserSubscriptions(token);
        
        return data;
      } else {
        final errorBody = response.body.isNotEmpty ? json.decode(response.body) : {};
        _error = errorBody['detail'] ?? errorBody['error'] ?? 'Failed to create subscription: ${response.statusCode}';
        notifyListeners();
        throw Exception(_error);
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error creating subscription: $e';
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<Map<String, dynamic>> createBundleSubscription(String token, List<int> pricingPlanIds) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/users/me/bundles/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'pricing_plan_ids': pricingPlanIds}),
      );

      _isLoading = false;
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        notifyListeners();
        
        // Refresh subscriptions after creating bundle
        await getUserSubscriptions(token);
        
        return data;
      } else {
        _error = 'Failed to create bundle subscription: ${response.statusCode}';
        notifyListeners();
        throw Exception(_error);
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error creating bundle subscription: $e';
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<bool> verifyPayment(String token, String transactionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // First, simulate the webhook for testing
      await _simulateTestWebhook(transactionId);
      
      final response = await http.post(
        Uri.parse(ApiConfig.paymentsVerifyEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'transaction_id': transactionId}),
      );

      _isLoading = false;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        notifyListeners();
        return data['status'] == 'verified' && data['payment_status'] == 'SUCCESSFUL';
      } else {
        _error = 'Failed to verify payment: ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error verifying payment: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _simulateTestWebhook(String transactionId) async {
    try {
      // Call the test webhook simulation endpoint
      await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/test/webhook-simulation/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'transaction_id': transactionId,
          'status': 'PAID'
        }),
      );
    } catch (e) {
      // Ignore errors in test webhook simulation
      print('Test webhook simulation failed: $e');
    }
  }

  Future<List<PaymentTransaction>> getPaymentHistory(String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await http.get(
        Uri.parse(ApiConfig.userPaymentsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      _isLoading = false;
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData['results'] ?? responseData;
        _transactions = data.map((json) => PaymentTransaction.fromJson(json)).toList();
        notifyListeners();
        return _transactions;
      } else {
        _error = 'Failed to load payment history: ${response.statusCode}';
        notifyListeners();
        throw Exception(_error);
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error fetching payment history: $e';
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<List<UserSubscription>> getUserSubscriptions(String token) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await http.get(
        Uri.parse(ApiConfig.userSubscriptionsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      _isLoading = false;
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData['results'] ?? responseData;
        _subscriptions = data.map((json) => UserSubscription.fromJson(json)).toList();
        notifyListeners();
        return _subscriptions;
      } else {
        _error = 'Failed to load subscriptions: ${response.statusCode}';
        notifyListeners();
        throw Exception(_error);
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Error fetching subscriptions: $e';
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<bool> cancelSubscription(String token, String subscriptionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final response = await http.post(
        Uri.parse('${ApiConfig.userSubscriptionsEndpoint}$subscriptionId/cancel/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      _isLoading = false;
      notifyListeners();
      
      if (response.statusCode == 200) {
        // Refresh subscriptions after canceling
        await getUserSubscriptions(token);
        return true;
      }
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Error canceling subscription: $e';
      notifyListeners();
      throw Exception(_error);
    }
  }

  Future<bool> toggleAutoRenew(String token, String subscriptionId, bool autoRenew) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // Since this isn't a standard endpoint in the API, we'll update the subscription
      // using the subscription update endpoint (if available) or handle it on the backend
      final response = await http.patch(
        Uri.parse('${ApiConfig.apiV1Url}/users/me/subscriptions/$subscriptionId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'auto_renew': autoRenew}),
      );

      _isLoading = false;
      notifyListeners();
      
      if (response.statusCode == 200) {
        // Refresh subscriptions after updating
        await getUserSubscriptions(token);
        return true;
      }
      return false;
    } catch (e) {
      _isLoading = false;
      _error = 'Error toggling auto-renew: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void clearData() {
    _subscriptions.clear();
    _transactions.clear();
    _pricingPlans.clear();
    _paymentMethods.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
} 