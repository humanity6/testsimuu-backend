import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/api_config.dart';
import 'localization_service.dart';
import 'auth_service.dart';

class ExamTranslationService {
  static final ExamTranslationService _instance = ExamTranslationService._internal();
  factory ExamTranslationService() => _instance;
  ExamTranslationService._internal();

  final Map<String, dynamic> _translationCache = {};
  final Map<String, List<String>> _supportedLanguagesCache = {};

  /// Get translated exam data
  Future<Map<String, dynamic>?> getExamWithTranslation(
    String examSlug, {
    String? languageCode,
  }) async {
    try {
      final currentLocale = LocalizationService().currentLocale;
      final targetLanguage = languageCode ?? currentLocale.languageCode;
      
      // Create cache key
      final cacheKey = '${examSlug}_$targetLanguage';
      
      // Check cache first
      if (_translationCache.containsKey(cacheKey)) {
        return _translationCache[cacheKey];
      }

      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/exams/$examSlug/with-translation/')
          .replace(queryParameters: {'lang': targetLanguage});
      
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // Cache the result
        _translationCache[cacheKey] = data;
        
        return data;
      } else {
        if (kDebugMode) {
          print('Failed to get exam translation: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting exam translation: $e');
      }
      return null;
    }
  }

  /// Trigger translation for an exam
  Future<Map<String, dynamic>?> translateExam(
    int examId,
    String languageCode,
  ) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/exams/$examId/translate/'),
        headers: headers,
        body: json.encode({
          'language_code': languageCode,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // Clear cache for this exam to force refresh
        _clearExamCache(examId);
        
        return data;
      } else {
        if (kDebugMode) {
          print('Failed to trigger translation: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error triggering translation: $e');
      }
      return null;
    }
  }

  /// Get translation status for an exam
  Future<Map<String, dynamic>?> getTranslationStatus(
    int examId, {
    String? languageCode,
  }) async {
    try {
      final headers = await _getHeaders();
      var uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/exams/$examId/translate/');
      
      if (languageCode != null) {
        uri = uri.replace(queryParameters: {'language_code': languageCode});
      }
      
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        if (kDebugMode) {
          print('Failed to get translation status: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting translation status: $e');
      }
      return null;
    }
  }

  /// Get supported languages for translation
  Future<Map<String, String>?> getSupportedLanguages() async {
    try {
      // Check cache first
      if (_supportedLanguagesCache.isNotEmpty) {
        final cached = _supportedLanguagesCache['languages'];
        if (cached != null) {
          return Map<String, String>.fromEntries(
            cached.map((lang) => MapEntry(lang, lang))
          );
        }
      }

      final headers = await _getHeaders();
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/exams/supported-languages/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final supportedLanguages = data['supported_languages'] as Map<String, dynamic>;
        
        // Cache the result
        _supportedLanguagesCache['languages'] = supportedLanguages.keys.toList();
        
        return supportedLanguages.cast<String, String>();
      } else {
        if (kDebugMode) {
          print('Failed to get supported languages: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting supported languages: $e');
      }
      return null;
    }
  }

  /// Batch translate multiple exams
  Future<Map<String, dynamic>?> translateMultipleExams(
    List<int> examIds,
    List<String> languageCodes,
  ) async {
    try {
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/exams/translate/batch/'),
        headers: headers,
        body: json.encode({
          'exam_ids': examIds,
          'language_codes': languageCodes,
        }),
      );

      if (response.statusCode == 202) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // Clear cache for affected exams
        for (final examId in examIds) {
          _clearExamCache(examId);
        }
        
        return data;
      } else {
        if (kDebugMode) {
          print('Failed to trigger batch translation: ${response.statusCode}');
          print('Response: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error triggering batch translation: $e');
      }
      return null;
    }
  }

  /// Clear cache for a specific exam
  void _clearExamCache(int examId) {
    _translationCache.removeWhere((key, value) => key.startsWith('${examId}_'));
  }

  /// Clear all translation cache
  void clearCache() {
    _translationCache.clear();
    _supportedLanguagesCache.clear();
  }

  /// Check if a language is supported
  bool isLanguageSupported(String languageCode) {
    const supportedLanguages = [
      'de', 'fr', 'es', 'it', 'pt', 'nl', 'ru', 'pl', 'tr', 'zh', 'ja', 'ko', 'ar'
    ];
    return supportedLanguages.contains(languageCode.toLowerCase());
  }

  /// Get language name from code
  String getLanguageName(String languageCode) {
    const languageNames = {
      'de': 'German',
      'fr': 'French',
      'es': 'Spanish',
      'it': 'Italian',
      'pt': 'Portuguese',
      'nl': 'Dutch',
      'ru': 'Russian',
      'pl': 'Polish',
      'tr': 'Turkish',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
    };
    return languageNames[languageCode.toLowerCase()] ?? languageCode;
  }

  /// Get headers for API requests
  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    try {
      final authService = AuthService();
      final token = authService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting auth token: $e');
      }
    }

    return headers;
  }
} 