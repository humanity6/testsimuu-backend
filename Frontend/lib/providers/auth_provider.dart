import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../utils/api_config.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  int? _userId;
  String? _email;
  DateTime? _expiryDate;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  int? get userId => _userId;
  String? get email => _email;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }

    final extractedUserData = json.decode(prefs.getString('userData')!);
    final expiryDate = DateTime.parse(extractedUserData['expiryDate']);

    if (expiryDate.isBefore(DateTime.now())) {
      return false;
    }

    _token = extractedUserData['token'];
    _userId = extractedUserData['userId'];
    _email = extractedUserData['email'];
    _expiryDate = expiryDate;
    
    // Set authenticated state to true
    _isAuthenticated = true;
    
    notifyListeners();
    return true;
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse(ApiConfig.authLoginEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Debug info
        if (kDebugMode) {
          print('Login successful, processing response data');
          print('Response contains tokens: ${responseData.containsKey('tokens')}');
        }
        
        final tokens = responseData['tokens'];
        _token = tokens['access'];
        _userId = responseData['user']['id'];
        _email = email;
        
        // Set expiry date to 7 days from now
        _expiryDate = DateTime.now().add(const Duration(days: 7));
        
        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final userData = json.encode({
          'token': _token,
          'userId': _userId,
          'email': _email,
          'expiryDate': _expiryDate!.toIso8601String(),
        });
        prefs.setString('userData', userData);
        
        // Set authenticated state to true
        _isAuthenticated = true;
        
        _isLoading = false;
        notifyListeners();
        
        // Debug info
        if (kDebugMode) {
          print('Login complete, token stored, authentication state: $isAuthenticated');
        }
        
        return true;
      } else {
        final responseData = json.decode(response.body);
        _error = responseData['detail'] ?? 'Authentication failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup(String email, String password, String firstName, String lastName) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await http.post(
        Uri.parse(ApiConfig.authRegisterEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
        }),
      );

      if (response.statusCode == 201) {
        // Registration successful, now login
        return await login(email, password);
      } else {
        final responseData = json.decode(response.body);
        
        // Check for specific error messages
        if (responseData.containsKey('email')) {
          _error = 'Email: ${responseData['email'][0]}';
        } else if (responseData.containsKey('password')) {
          _error = 'Password: ${responseData['password'][0]}';
        } else {
          _error = 'Registration failed: ${responseData['detail'] ?? 'Unknown error'}';
        }
        
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _email = null;
    _expiryDate = null;
    
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('userData');
    
    notifyListeners();
  }
} 