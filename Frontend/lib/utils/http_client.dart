import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class CustomHttpClient {
  static final CustomHttpClient _instance = CustomHttpClient._internal();
  factory CustomHttpClient() => _instance;
  CustomHttpClient._internal();

  // Configure timeouts
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 30);

  // Create HTTP client with custom configuration
  static http.Client _createClient() {
    final client = http.Client();
    return client;
  }

  // Get headers with authentication if available
  static Map<String, String> _getHeaders({String? authToken, bool includeContentType = true}) {
    final headers = <String, String>{};
    
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    
    headers['Accept'] = 'application/json';
    headers['User-Agent'] = 'TestimusApp/1.0';
    
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    
    return headers;
  }

  // Custom GET request with better error handling
  static Future<http.Response> get(
    String url, {
    String? authToken,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) async {
    try {
      final client = _createClient();
      final headers = _getHeaders(authToken: authToken, includeContentType: false);
      
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      if (kDebugMode) {
        print('GET Request: $url');
        print('Headers: $headers');
      }

      final response = await client
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(timeout ?? _receiveTimeout);

      if (kDebugMode) {
        print('GET Response: ${response.statusCode}');
        if (response.statusCode >= 400) {
          print('Error Response Body: ${response.body}');
        }
      }

      client.close();
      return response;
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('SocketException in GET $url: $e');
      }
      throw HttpException('Network connection failed: ${e.message}');
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('TimeoutException in GET $url: $e');
      }
      throw HttpException('Request timeout');
    } catch (e) {
      if (kDebugMode) {
        print('Exception in GET $url: $e');
      }
      rethrow;
    }
  }

  // Custom POST request with better error handling
  static Future<http.Response> post(
    String url, {
    String? authToken,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) async {
    try {
      final client = _createClient();
      final headers = _getHeaders(authToken: authToken);
      
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      final jsonBody = body != null ? json.encode(body) : null;

      if (kDebugMode) {
        print('POST Request: $url');
        print('Headers: $headers');
        print('Body: $jsonBody');
      }

      final response = await client
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonBody,
          )
          .timeout(timeout ?? _receiveTimeout);

      if (kDebugMode) {
        print('POST Response: ${response.statusCode}');
        if (response.statusCode >= 400) {
          print('Error Response Body: ${response.body}');
        }
      }

      client.close();
      return response;
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('SocketException in POST $url: $e');
      }
      throw HttpException('Network connection failed: ${e.message}');
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('TimeoutException in POST $url: $e');
      }
      throw HttpException('Request timeout');
    } catch (e) {
      if (kDebugMode) {
        print('Exception in POST $url: $e');
      }
      rethrow;
    }
  }

  // Custom PUT request
  static Future<http.Response> put(
    String url, {
    String? authToken,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) async {
    try {
      final client = _createClient();
      final headers = _getHeaders(authToken: authToken);
      
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      final jsonBody = body != null ? json.encode(body) : null;

      if (kDebugMode) {
        print('PUT Request: $url');
        print('Headers: $headers');
        print('Body: $jsonBody');
      }

      final response = await client
          .put(
            Uri.parse(url),
            headers: headers,
            body: jsonBody,
          )
          .timeout(timeout ?? _receiveTimeout);

      if (kDebugMode) {
        print('PUT Response: ${response.statusCode}');
        if (response.statusCode >= 400) {
          print('Error Response Body: ${response.body}');
        }
      }

      client.close();
      return response;
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('SocketException in PUT $url: $e');
      }
      throw HttpException('Network connection failed: ${e.message}');
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('TimeoutException in PUT $url: $e');
      }
      throw HttpException('Request timeout');
    } catch (e) {
      if (kDebugMode) {
        print('Exception in PUT $url: $e');
      }
      rethrow;
    }
  }

  // Custom PATCH request
  static Future<http.Response> patch(
    String url, {
    String? authToken,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) async {
    try {
      final client = _createClient();
      final headers = _getHeaders(authToken: authToken);
      
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      final jsonBody = body != null ? json.encode(body) : null;

      if (kDebugMode) {
        print('PATCH Request: $url');
        print('Headers: $headers');
        print('Body: $jsonBody');
      }

      final response = await client
          .patch(
            Uri.parse(url),
            headers: headers,
            body: jsonBody,
          )
          .timeout(timeout ?? _receiveTimeout);

      if (kDebugMode) {
        print('PATCH Response: ${response.statusCode}');
        if (response.statusCode >= 400) {
          print('Error Response Body: ${response.body}');
        }
      }

      client.close();
      return response;
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('SocketException in PATCH $url: $e');
      }
      throw HttpException('Network connection failed: ${e.message}');
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('TimeoutException in PATCH $url: $e');
      }
      throw HttpException('Request timeout');
    } catch (e) {
      if (kDebugMode) {
        print('Exception in PATCH $url: $e');
      }
      rethrow;
    }
  }

  // Custom DELETE request
  static Future<http.Response> delete(
    String url, {
    String? authToken,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) async {
    try {
      final client = _createClient();
      final headers = _getHeaders(authToken: authToken, includeContentType: false);
      
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      if (kDebugMode) {
        print('DELETE Request: $url');
        print('Headers: $headers');
      }

      final response = await client
          .delete(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(timeout ?? _receiveTimeout);

      if (kDebugMode) {
        print('DELETE Response: ${response.statusCode}');
        if (response.statusCode >= 400) {
          print('Error Response Body: ${response.body}');
        }
      }

      client.close();
      return response;
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('SocketException in DELETE $url: $e');
      }
      throw HttpException('Network connection failed: ${e.message}');
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('TimeoutException in DELETE $url: $e');
      }
      throw HttpException('Request timeout');
    } catch (e) {
      if (kDebugMode) {
        print('Exception in DELETE $url: $e');
      }
      rethrow;
    }
  }

  // Test connectivity to the API
  static Future<bool> testConnectivity() async {
    try {
      final response = await get(
        '${ApiConfig.baseUrl}/admin/',
        timeout: const Duration(seconds: 5),
      );
      
      // Any response means the server is reachable
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Connectivity test failed: $e');
      }
      return false;
    }
  }
}

// Custom exceptions
class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  
  @override
  String toString() => 'HttpException: $message';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
} 