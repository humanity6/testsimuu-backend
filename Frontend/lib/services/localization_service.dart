import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  // Supported languages
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('de', 'DE'),
  ];

  // Default locale
  static const Locale defaultLocale = Locale('en', 'US');

  // Current locale
  Locale _currentLocale = defaultLocale;
  Locale get currentLocale => _currentLocale;
  
  // Is service initialized
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Translations
  Map<String, dynamic> _localizedStrings = {};

  // Singleton instance
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  // Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? languageCode = prefs.getString('languageCode');
      final String? countryCode = prefs.getString('countryCode');

      if (languageCode != null && countryCode != null) {
        final locale = Locale(languageCode, countryCode);
        
        // Verify that the stored locale is in our supported list
        bool isSupported = supportedLocales.any(
          (supportedLocale) => 
            supportedLocale.languageCode == locale.languageCode && 
            supportedLocale.countryCode == locale.countryCode
        );
        
        if (isSupported) {
          _currentLocale = locale;
        } else {
          // If not supported, fall back to default
          _currentLocale = defaultLocale;
          // Update preferences to match
          await prefs.setString('languageCode', defaultLocale.languageCode);
          await prefs.setString('countryCode', defaultLocale.countryCode ?? '');
        }
      }

      await loadTranslations(_currentLocale);
      _isInitialized = true;
    } catch (e) {
      print('Error initializing localization service: $e');
      // Fallback to default locale if there's an error
      _currentLocale = defaultLocale;
      await loadTranslations(_currentLocale);
      _isInitialized = true;
    }
  }

  // Load translations for a specific locale
  Future<void> loadTranslations(Locale locale) async {
    try {
      print('Loading translations for ${locale.languageCode}...');
      final String jsonString = await rootBundle.loadString('assets/translations/${locale.languageCode}.json');
      final Map<String, dynamic> newTranslations = json.decode(jsonString);
      
      // Validate that translations are not empty
      if (newTranslations.isEmpty) {
        throw Exception('Translation file is empty for ${locale.languageCode}');
      }
      
      _localizedStrings = Map<String, dynamic>.from(newTranslations);
      _currentLocale = locale;
      
      print('Loaded ${_localizedStrings.length} translation keys for ${locale.languageCode}');
      
      // Validate some common keys exist
      final testKeys = ['app_title', 'home', 'loading', 'error'];
      for (final key in testKeys) {
        if (!_localizedStrings.containsKey(key)) {
          print('Warning: Missing translation key "$key" in ${locale.languageCode}');
        }
      }
      
      notifyListeners();
      print('Notified listeners of locale change to ${locale.languageCode}');
    } catch (e) {
      print('Error loading translations for ${locale.languageCode}: $e');
      
      // If there's an error loading translations, try to load the default English translations
      if (locale.languageCode != 'en') {
        try {
          print('Falling back to English translations...');
          final String jsonString = await rootBundle.loadString('assets/translations/en.json');
          final Map<String, dynamic> fallbackTranslations = json.decode(jsonString);
          _localizedStrings = Map<String, dynamic>.from(fallbackTranslations);
          _currentLocale = const Locale('en', 'US');
          notifyListeners();
          print('Loaded fallback English translations with ${_localizedStrings.length} keys');
        } catch (fallbackError) {
          print('Error loading fallback translations: $fallbackError');
          // Use basic translations as a last resort
          _localizedStrings = _getBasicTranslations();
          notifyListeners();
        }
      } else {
        // If we can't load English, use basic translations
        print('Failed to load English translations, using basic fallback');
        _localizedStrings = _getBasicTranslations();
        notifyListeners();
      }
    }
  }

  // Provide basic translations as fallback
  Map<String, dynamic> _getBasicTranslations() {
    return {
      'app_title': 'Testsimu',
      'home': 'Home',
      'loading': 'Loading...',
      'error': 'Error',
      'try_again': 'Try Again',
      'back': 'Back',
      'next': 'Next',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'settings': 'Settings',
      'profile': 'Profile',
      'logout': 'Sign Out',
      'login': 'Sign In',
      'signup': 'Sign Up',
      'exam_details': 'Exam Details',
      'exam_not_found': 'Exam not found',
      'error_loading_exam': 'Error loading exam',
      'translation_unavailable': 'Translation not available',
      // Add missing keys that were causing errors
      'hours': 'hours',
      'advanced': 'advanced',
      'expert': 'expert',
      'expired': 'expired',
      'user': 'User',
      'welcome_user': 'Welcome, {name}!',
    };
  }

  // Change the current locale
  Future<void> changeLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) {
      print('Locale $locale is not supported');
      return;
    }

    if (_currentLocale.languageCode == locale.languageCode) {
      print('Locale is already set to ${locale.languageCode}');
      return;
    }

    try {
      print('Changing locale from ${_currentLocale.languageCode} to ${locale.languageCode}');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('languageCode', locale.languageCode);
      await prefs.setString('countryCode', locale.countryCode ?? '');

      await loadTranslations(locale);
      
      print('Locale changed successfully to ${_currentLocale.languageCode}');
    } catch (e) {
      print('Error changing locale: $e');
      // If there's an error, don't change the locale
    }
  }

  // Get a translated string
  String translate(String key, {Map<String, String>? params}) {
    // Check if service is initialized
    if (!_isInitialized) {
      print('Warning: LocalizationService not initialized, returning key: $key');
      return key;
    }
    
    // Check if translations are loaded
    if (_localizedStrings.isEmpty) {
      print('Warning: No translations loaded, returning key: $key');
      return key;
    }
    
    // Get the translation
    String text = _localizedStrings[key]?.toString() ?? key;
    
    // Replace parameters if provided
    if (params != null) {
      params.forEach((paramKey, value) {
        text = text.replaceAll('{$paramKey}', value);
      });
    }
    
    // Debug log for missing translations (only in debug mode)
    if (text == key && _localizedStrings.isNotEmpty) {
      print('Missing translation for key: $key in language: ${_currentLocale.languageCode}');
    }
    
    return text;
  }

  // Get locale name
  static String getDisplayLanguage(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      default:
        return locale.languageCode;
    }
  }
} 