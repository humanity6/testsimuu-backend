import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../utils/api_config.dart';

class AuthService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  String? _accessToken;
  String? _refreshToken;
  bool _isAuthenticated = false;
  User? _currentUser;
  bool _isInitialized = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  String? get accessToken => _accessToken;

  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Initialize the auth service and check for existing session
  Future<void> init() async {
    try {
      if (kDebugMode) {
        print('Initializing Auth Service...');
      }
      
      // Check API availability
      final isApiAvailable = await _checkApiAvailability();
      if (!isApiAvailable) {
        _error = 'Unable to connect to the server. Please check your connection.';
        notifyListeners();
        if (kDebugMode) {
          print('API not available, initialization aborted');
        }
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final hasAccessToken = prefs.containsKey('access_token');
      final hasRefreshToken = prefs.containsKey('refresh_token');
      
      if (kDebugMode) {
        print('Found tokens: Access: $hasAccessToken, Refresh: $hasRefreshToken');
      }
      
      if (hasAccessToken && hasRefreshToken) {
        _accessToken = prefs.getString('access_token');
        _refreshToken = prefs.getString('refresh_token');
        
        // Verify token validity
        final isValid = await _verifyToken();
        
        if (isValid) {
          _isAuthenticated = true;
          await _fetchUserProfile();
          
          if (kDebugMode) {
            print('Successfully authenticated from stored tokens');
            print('User: ${_currentUser?.name}');
          }
        } else {
          // If token verification fails, try to refresh the token
          final refreshed = await _refreshAccessToken();
          
          if (refreshed) {
            _isAuthenticated = true;
            await _fetchUserProfile();
            
            if (kDebugMode) {
              print('Successfully refreshed token and authenticated');
              print('User: ${_currentUser?.name}');
            }
          } else {
            // If token refresh fails, clear tokens and require login
            _clearTokens();
            if (kDebugMode) {
              print('Token refresh failed, user needs to login again');
            }
          }
        }
      } else {
        if (kDebugMode) {
          print('No stored tokens found, user needs to login');
        }
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing auth service: $e');
      }
      _clearTokens();
      notifyListeners();
    }
  }
  
  // Check if the API is available
  Future<bool> _checkApiAvailability() async {
    try {
      if (kDebugMode) {
        print('Checking API availability at ${ApiConfig.baseUrl}...');
      }
      
      // First try the health endpoint
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/health/'),
        ).timeout(const Duration(seconds: 3));
        
        if (kDebugMode) {
          print('API health check status: ${response.statusCode}');
        }
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Health endpoint not available, trying fallback...');
        }
      }
      
      // If health check fails, try the base URL as fallback
      try {
        final baseResponse = await http.get(
          Uri.parse(ApiConfig.baseUrl),
        ).timeout(const Duration(seconds: 3));
        
        if (kDebugMode) {
          print('Base URL check status: ${baseResponse.statusCode}');
        }
        
        // For base URL, any response (even 404) means the server is running
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('Base URL check failed: $e');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('API health check failed: $e');
      }
      return false;
    }
  }
  
  // Verify if the current token is valid
  Future<bool> _verifyToken() async {
    if (_accessToken == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.userProfileEndpoint),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying token: $e');
      }
      return false;
    }
  }
  
  // Clear tokens and authentication state
  void _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _isAuthenticated = false;
    _currentUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('access_token');
    prefs.remove('refresh_token');
  }

  // Fetch user profile
  Future<bool> _fetchUserProfile() async {
    if (_accessToken == null) {
      if (kDebugMode) {
        print('Cannot fetch user profile: access token is null');
      }
      return false;
    }
    
    try {
      if (kDebugMode) {
        print('Fetching user profile from: ${ApiConfig.userProfileEndpoint}');
      }
      
      final response = await http.get(
        Uri.parse(ApiConfig.userProfileEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
      );
      
      if (kDebugMode) {
        print('User profile response status: ${response.statusCode}');
        print('User profile response: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Create user from response data using fromJson factory
        try {
          _currentUser = User.fromJson(data);
          if (kDebugMode) {
            print('User profile successfully loaded: ${_currentUser?.name}');
            print('User is admin/staff: ${_currentUser?.isAdmin}');
            print('Original is_staff value from API: ${data['is_staff']}');
          }
          notifyListeners();
          return true;
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing user data: $e');
          }
          _error = 'Error parsing user data: $e';
          notifyListeners();
          return false;
        }
      } else if (response.statusCode == 401) {
        // Token expired or invalid, try refreshing
        if (kDebugMode) {
          print('Token expired, attempting to refresh');
        }
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          // Try fetching profile again with new token
          return await _fetchUserProfile();
        } else {
          // Clear auth data if refresh failed
          await _clearAuthData();
          _error = 'Session expired, please login again';
          notifyListeners();
          return false;
        }
      } else {
        // Handle error
        _error = 'Failed to fetch user profile: ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error while fetching profile: ${e.toString()}';
      if (kDebugMode) {
        print('Error fetching user profile: $e');
      }
      notifyListeners();
      return false;
    }
  }

  // Refresh access token
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.authRefreshEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'refresh': _refreshToken,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // The API returns 'access' in the response
        _accessToken = data['access'];
        
        // Save the new access token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        
        _isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        // Clear auth data if refresh failed
        await _clearAuthData();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing token: $e');
      }
      await _clearAuthData();
      return false;
    }
  }

  // Clear authentication data
  Future<void> _clearAuthData() async {
    _accessToken = null;
    _refreshToken = null;
    _isAuthenticated = false;
    _currentUser = null;
    
    // Remove tokens from local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    
    notifyListeners();
  }

  // Update user profile
  Future<bool> updateProfile({
    required String name,
    required String email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Parse name into first_name and last_name
      final nameParts = name.split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
      final response = await http.put(
        Uri.parse(ApiConfig.userProfileEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
        }),
      );

      _isLoading = false;
      if (response.statusCode == 200) {
        await _fetchUserProfile(); // Refresh the user data
        return true;
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh it
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          // Try updating profile again
          return await updateProfile(name: name, email: email);
        } else {
          _error = 'Session expired, please login again';
          notifyListeners();
          return false;
        }
      } else {
        final responseData = json.decode(response.body);
        _error = responseData['detail'] ?? 'Failed to update profile';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to update profile: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update user profile with avatar
  Future<bool> updateProfileWithAvatar({
    required String name,
    required String email,
    File? avatarFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // If avatar file is provided, upload it first
      String? avatarUrl;
      if (avatarFile != null) {
        avatarUrl = await _uploadAvatar(avatarFile);
        if (avatarUrl == null) {
          _error = 'Failed to upload avatar';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Update profile with new data
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode({
          'name': name,
          'email': email,
          if (avatarUrl != null) 'avatar': avatarUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Update current user with new data
        if (_currentUser != null) {
          // Parse name into first and last name
          final nameParts = name.split(' ');
          final firstName = nameParts.first;
          final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          
          _currentUser = User(
            id: _currentUser!.id,
            username: _currentUser!.username,
            firstName: firstName,
            lastName: lastName,
            email: email,
            isStaff: _currentUser!.isStaff,
            isActive: _currentUser!.isActive,
            emailVerified: _currentUser!.emailVerified,
            profilePictureUrl: avatarUrl ?? _currentUser!.profilePictureUrl,
            dateOfBirth: _currentUser!.dateOfBirth,
            gdprConsentDate: _currentUser!.gdprConsentDate,
            referralCode: _currentUser!.referralCode,
            lastActive: _currentUser!.lastActive,
            timeZone: _currentUser!.timeZone,
            accessToken: _currentUser!.accessToken,
            refreshToken: _currentUser!.refreshToken,
            rank: _currentUser!.rank,
            totalPoints: _currentUser!.totalPoints,
          );
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final data = json.decode(response.body);
        _error = data['message'] ?? 'Failed to update profile. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Failed to update profile: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Upload avatar to server
  Future<String?> _uploadAvatar(File avatarFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/auth/upload-avatar'),
      );
      
      request.headers['Authorization'] = 'Bearer $_accessToken';
      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        avatarFile.path,
      ));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['avatar_url'];
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Sign up
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String? referralCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Parse name into first_name and last_name
      final nameParts = name.split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      
      if (kDebugMode) {
        print('Attempting to sign up with endpoint: ${ApiConfig.authRegisterEndpoint}');
      }
      
      final body = {
        'email': email,
        'password': password,
        'password_confirm': password,
        'first_name': firstName,
        'last_name': lastName,
        'username': firstName.toLowerCase(),
      };
      
      if (kDebugMode) {
        print('Request body: ${json.encode(body)}');
      }
      
      final response = await http.post(
        Uri.parse(ApiConfig.authRegisterEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      
      if (kDebugMode) {
        print('Signup response status code: ${response.statusCode}');
        print('Signup response body:\n${response.body}');
      }
      
      _isLoading = false;
      
      if (response.statusCode == 201) {
        // Registration was successful - don't auto-login
        // Let user go to login screen
        notifyListeners();
        return true;
      } else {
        // Handle different error cases
        Map<String, dynamic> errorData = {};
        try {
          errorData = json.decode(response.body);
        } catch (e) {
          // If response body is not valid JSON
          _error = 'Failed to register: ${response.statusCode}';
          notifyListeners();
          return false;
        }
        
        // Handle specific field errors
        if (errorData.containsKey('email')) {
          _error = 'Email: ${errorData['email'][0]}';
        } else if (errorData.containsKey('password')) {
          _error = 'Password: ${errorData['password'][0]}';
        } else if (errorData.containsKey('password_confirm')) {
          _error = 'Password confirmation: ${errorData['password_confirm'][0]}';
        } else if (errorData.containsKey('username')) {
          _error = 'Username: ${errorData['username'][0]}';
        } else if (errorData.containsKey('non_field_errors')) {
          _error = errorData['non_field_errors'][0];
        } else if (errorData.containsKey('detail')) {
          _error = errorData['detail'];
        } else {
          _error = 'Registration failed. Please try again.';
        }
        
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Login
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      if (kDebugMode) {
        print('Attempting login with email: $email');
        print('Login endpoint: ${ApiConfig.authLoginEndpoint}');
      }
      
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
      
      if (kDebugMode) {
        print('Login response status: ${response.statusCode}');
        print('Login response body:\n${response.body}');
      }
      
      _isLoading = false;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('Login successful, parsing response data...');
          print('Raw response data: $data');
        }
        
        // Store tokens - handle nested structure
        if (data.containsKey('tokens')) {
          _accessToken = data['tokens']['access'];
          _refreshToken = data['tokens']['refresh'];
        } else {
          // For backward compatibility with older API
          _accessToken = data['access'];
          _refreshToken = data['refresh'];
        }
        
        if (_accessToken == null || _refreshToken == null) {
          _error = 'Invalid response format from server';
          notifyListeners();
          return false;
        }
        
        _isAuthenticated = true;
        
        // Save tokens to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        
        // Store user data if available in response
        if (data.containsKey('user')) {
          if (kDebugMode) {
            print('User data from login response:');
            print('Raw user data: ${data['user']}');
            print('is_staff value: ${data['user']['is_staff']}');
          }
          
          _currentUser = User.fromJson(data['user']);
          
          if (kDebugMode) {
            print('Parsed user data:');
            print('User name: ${_currentUser?.name}');
            print('User ID: ${_currentUser?.id}');
            print('Is admin/staff: ${_currentUser?.isAdmin}');
          }
        } else {
          // Fetch user profile to update the user object
          if (kDebugMode) {
            print('No user data in login response, fetching profile...');
          }
          await _fetchUserProfile();
        }
        
        notifyListeners();
        return true;
      } else {
        Map<String, dynamic> responseData;
        try {
          responseData = json.decode(response.body);
          _error = responseData['detail'] ?? 'Login failed. Please check your credentials.';
        } catch (e) {
          _error = 'Login failed. Please check your credentials.';
        }
        
        if (kDebugMode) {
          print('Login failed: $_error');
        }
        
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      
      if (kDebugMode) {
        print('Login exception: $e');
      }
      
      notifyListeners();
      return false;
    }
  }

  // Request password reset
  Future<bool> requestPasswordReset({
    required String email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/auth/password-reset/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
        }),
      );

      _isLoading = false;
      
      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      } else {
        final data = json.decode(response.body);
        _error = data['detail'] ?? 'Failed to request password reset. Please try again.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      // For development, simulate success
      if (kDebugMode) {
        await Future.delayed(const Duration(seconds: 1));
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = 'Failed to request password reset: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Confirm password reset
  Future<bool> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiV1Url}/auth/password-reset-confirm/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'password': newPassword,
        }),
      );

      _isLoading = false;
      
      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      } else {
        final data = json.decode(response.body);
        _error = data['detail'] ?? 'Failed to reset password. Please try again.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      // For development, simulate success
      if (kDebugMode) {
        await Future.delayed(const Duration(seconds: 1));
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = 'Failed to reset password: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout user
  Future<bool> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      if (_refreshToken != null) {
        // Try to blacklist the refresh token on the server
        final response = await http.post(
          Uri.parse(ApiConfig.authLogoutEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
          body: json.encode({
            'refresh': _refreshToken,
          }),
        );
        
        // Even if server logout fails, we still clear local auth data
        if (response.statusCode != 200 && response.statusCode != 204) {
          if (kDebugMode) {
            print('Warning: Server logout returned status ${response.statusCode}');
          }
        }
      }
      
      // Clear local auth data
      await _clearAuthData();
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
      
      // Still clear local auth data on error
      await _clearAuthData();
      
      _error = 'Error during logout: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get auth token
  String? getToken() {
    return _accessToken;
  }

  // Reset error
  void resetError() {
    _error = null;
    notifyListeners();
  }
} 