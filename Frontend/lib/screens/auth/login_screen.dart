import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import 'signup_screen.dart';
import 'password_reset_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  
  late final _authService;

  @override
  void initState() {
    super.initState();
    
    // Store a reference to the auth service to avoid context issues in dispose
    _authService = context.authService;
    
    // Listen to auth changes to refresh UI accordingly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _authService.addListener(_refreshOnAuthChange);
      }
    });
  }

  @override
  void dispose() {
    // Remove listener using stored reference instead of context
    _authService.removeListener(_refreshOnAuthChange);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refreshOnAuthChange() {
    // Rebuild UI when auth state changes
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final success = await context.authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (success && mounted) {
        // Show a success message first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 1500),
          ),
        );
        
        // Wait briefly for the snackbar to be visible
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          // Check if user is admin and redirect accordingly
          final isAdmin = context.authService.currentUser?.isAdmin ?? false;
          
          if (kDebugMode) {
            print('Login successful, redirecting user...');
            print('Is admin/staff user: $isAdmin');
            if (context.authService.currentUser != null) {
              print('User details: ${context.authService.currentUser?.name}, ID: ${context.authService.currentUser?.id}');
            }
          }
          
          // Use a safer navigation method to prevent potential lifecycle issues
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (isAdmin) {
                // Redirect admin users to admin dashboard
                if (kDebugMode) {
                  print('Redirecting ADMIN user to admin dashboard');
                }
                Navigator.of(context).pushNamedAndRemoveUntil('/admin-panel/dashboard', (route) => false);
              } else {
                // Navigate regular users to the main app
                if (kDebugMode) {
                  print('Redirecting regular user to main screen');
                }
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            }
          });
        }
      } else if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.authService.error ?? context.tr('login_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignupScreen()),
    );
  }

  void _navigateToPasswordReset() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PasswordResetScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.authService.isLoading;
    final isAuthenticated = context.authService.isAuthenticated;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Row(
          children: [
            Text(
              context.tr('app_title'),
              style: const TextStyle(
                color: AppColors.darkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            const Spacer(),
            const LanguageSelector(isCompact: true),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('login_title'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('login_subtitle'),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.darkGrey,
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email field
                    Text(
                      context.tr('login_email'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: context.tr('login_email_placeholder'),
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.tr('login_validation_email_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Password field
                    Text(
                      context.tr('login_password'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: context.tr('login_password_placeholder'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return context.tr('login_validation_password_required');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    
                    // Forgot password link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _navigateToPasswordReset,
                        child: Text(
                          context.tr('forgot_password'),
                          style: const TextStyle(
                            color: AppColors.darkBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Login button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              context.tr('login_button'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Sign up link - only show if not authenticated
                    if (!isAuthenticated)
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: context.tr('login_no_account'),
                            style: const TextStyle(
                              color: AppColors.darkGrey,
                            ),
                            children: [
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: context.tr('sign_up'),
                                style: const TextStyle(
                                  color: AppColors.darkBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = _navigateToSignup,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 