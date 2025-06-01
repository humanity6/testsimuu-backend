import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/affiliate.dart';
import '../utils/api_config.dart';

class AffiliateService {

  // Check user affiliate status
  Future<Map<String, dynamic>> getUserAffiliateStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.affiliateStatusEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get affiliate status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting affiliate status: $e');
    }
  }

  // Get affiliate opportunities (available plans)
  Future<Map<String, dynamic>> getAffiliateOpportunities(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.affiliateOpportunitiesEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get affiliate opportunities: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting affiliate opportunities: $e');
    }
  }

  // Get available affiliate plans
  Future<List<AffiliatePlan>> getAffiliatePlans() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.affiliatePlansEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? data;
        return results.map((json) => AffiliatePlan.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get affiliate plans: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting affiliate plans: $e');
    }
  }

  // Submit affiliate application
  Future<AffiliateApplication> submitApplication(
    String token,
    Map<String, dynamic> applicationData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.affiliateApplicationsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(applicationData),
      );

      if (response.statusCode == 201) {
        return AffiliateApplication.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to submit application');
      }
    } catch (e) {
      throw Exception('Error submitting application: $e');
    }
  }

  // Get user's affiliate applications
  Future<List<AffiliateApplication>> getUserApplications(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.affiliateApplicationsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? data;
        return results.map((json) => AffiliateApplication.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get applications: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting applications: $e');
    }
  }

  // Get affiliate profile (for existing affiliates)
  Future<Affiliate> getAffiliateProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.affiliateMeEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return Affiliate.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get affiliate profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting affiliate profile: $e');
    }
  }

  // Get affiliate statistics
  Future<AffiliateStatistics> getAffiliateStatistics(String token, {int periodDays = 30}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.affiliateStatisticsEndpoint}?period=$periodDays'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return AffiliateStatistics.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get affiliate statistics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting affiliate statistics: $e');
    }
  }

  // Get affiliate links
  Future<List<AffiliateLink>> getAffiliateLinks(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.affiliateLinksEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? data;
        return results.map((json) => AffiliateLink.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get affiliate links: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting affiliate links: $e');
    }
  }

  // Create affiliate link
  Future<AffiliateLink> createAffiliateLink(
    String token,
    Map<String, dynamic> linkData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.affiliateLinksEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(linkData),
      );

      if (response.statusCode == 201) {
        return AffiliateLink.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to create affiliate link');
      }
    } catch (e) {
      throw Exception('Error creating affiliate link: $e');
    }
  }

  // Track click on affiliate link
  Future<void> trackClick(String trackingId, {String? referrerUrl}) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.affiliateTrackClickEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'tracking_id': trackingId,
          if (referrerUrl != null) 'referrer_url': referrerUrl,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to track click: ${response.statusCode}');
      }
    } catch (e) {
      // Don't throw error for tracking failures to avoid disrupting user experience
      print('Warning: Failed to track affiliate click: $e');
    }
  }

  // Apply voucher code
  Future<Map<String, dynamic>> applyVoucherCode(String token, String code) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.affiliateApplyVoucherEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'code': code}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to apply voucher code');
      }
    } catch (e) {
      throw Exception('Error applying voucher code: $e');
    }
  }
} 