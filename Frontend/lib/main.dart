import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/password_reset_screen.dart';
import 'screens/auth/password_reset_confirm_screen.dart';
import 'screens/legal/terms_screen.dart';
import 'screens/legal/privacy_screen.dart';
import 'screens/my_exams/my_exams_screen.dart';
import 'screens/exams/practice_screen.dart';
import 'screens/exams/exam_session_screen.dart';
import 'screens/exams/exam_results_screen.dart';
import 'screens/exams/practice_results_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/help/help_screen.dart';
import 'screens/help/faq_screen.dart';
import 'screens/pricing/pricing_screen.dart';
import 'screens/pricing/checkout_screen.dart';
import 'screens/pricing/subscription_success_screen.dart';
import 'screens/admin_panel/dashboard_screen.dart';
import 'screens/admin_panel/content_screen.dart';
import 'screens/admin_panel/content/exams_screen.dart';
import 'screens/admin_panel/users/users_screen.dart';
import 'screens/admin_panel/users/user_detail_screen.dart';
import 'screens/admin_panel/ai_alerts/ai_alerts_screen.dart';
import 'screens/admin_panel/ai_alerts/alert_detail_screen.dart';
import 'screens/admin_panel/ai_search_management_screen.dart';
import 'screens/admin_panel/monetization/monetization_screen.dart';
import 'screens/admin_panel/support/faq_screen.dart';
import 'screens/admin_panel/settings/general_settings_screen.dart';
import 'screens/admin_panel/affiliate_management_screen.dart';
import 'screens/ai_chatbot/ai_chatbot_screen.dart';
import 'screens/profile/affiliate_screen.dart';
import 'theme.dart';
import 'providers/app_providers.dart';
import 'services/localization_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/user_exam_service.dart';
import 'models/exam.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  String? _initError;
  LocalizationService? _localizationService;
  AuthService? _authService;
  NotificationService? _notificationService;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize services in order
      _localizationService = LocalizationService();
      await _localizationService!.init();
      
      _authService = AuthService();
      if (kDebugMode) {
        print('Initializing auth service...');
      }
      await _authService!.init();
      if (kDebugMode) {
        print('Auth service initialized, authentication state: ${_authService!.isAuthenticated}');
        if (_authService!.isAuthenticated) {
          print('User is authenticated: ${_authService!.currentUser?.name ?? "Unknown"}');
        }
      }
      
      _notificationService = NotificationService();
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing app: $e');
      }
      setState(() {
        _initError = 'Failed to initialize app: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _localizationService == null || _authService == null || _notificationService == null) {
      return MaterialApp(
        title: 'Testsimu',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                if (_initError != null)
                  Text(_initError!, style: const TextStyle(color: Colors.red))
                else
                  const Text('Initializing app...'),
              ],
            ),
          ),
        ),
      );
    }
    
    return QuizApp(
      localizationService: _localizationService!,
      authService: _authService!,
      notificationService: _notificationService!,
    );
  }
}

class QuizApp extends StatelessWidget {
  final LocalizationService localizationService;
  final AuthService authService;
  final NotificationService notificationService;

  const QuizApp({
    Key? key,
    required this.localizationService,
    required this.authService,
    required this.notificationService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppProviders(
      localizationService: localizationService,
      authService: authService,
      notificationService: notificationService,
      child: Consumer2<LocalizationService, AuthService>(
        builder: (context, localizationService, authService, _) {
          return MaterialApp(
            key: ValueKey(localizationService.currentLocale.languageCode),
            title: 'Testsimu',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LocalizationService.supportedLocales,
            locale: localizationService.currentLocale,
            initialRoute: '/',
            routes: {
              '/': (context) => authService.isAuthenticated 
                ? (authService.currentUser?.isAdmin == true 
                    ? const AdminDashboardScreen() 
                    : const MainScreen())
                : const HomeScreen(),
              '/login': (context) => authService.isAuthenticated
                ? (authService.currentUser?.isAdmin == true 
                    ? const AdminDashboardScreen() 
                    : const MainScreen())
                : const LoginScreen(),
              '/signup': (context) => authService.isAuthenticated
                ? (authService.currentUser?.isAdmin == true 
                    ? const AdminDashboardScreen() 
                    : const MainScreen())
                : const SignupScreen(),
              '/reset-password': (context) => const PasswordResetScreen(),
              '/terms': (context) => const TermsScreen(),
              '/privacy': (context) => const PrivacyScreen(),
              '/my-exams': (context) => authService.isAuthenticated
                ? (authService.currentUser?.isAdmin == true 
                    ? const AdminDashboardScreen() 
                    : const MyExamsScreen())
                : const LoginScreen(),
              '/dashboard': (context) => authService.isAuthenticated
                ? (authService.currentUser?.isAdmin == true 
                    ? const AdminDashboardScreen() 
                    : const MainScreen())
                : const LoginScreen(),
              '/reports': (context) => authService.isAuthenticated
                ? (authService.currentUser?.isAdmin == true 
                    ? const AdminDashboardScreen() 
                    : const ReportsScreen())
                : const LoginScreen(),
              '/help': (context) => const HelpScreen(),
              '/faq': (context) => const FAQScreen(),
              '/pricing': (context) => const PricingScreen(),
              '/subscription/success': (context) => authService.isAuthenticated
                ? const SubscriptionSuccessScreen()
                : const LoginScreen(),
              '/profile': (context) => authService.isAuthenticated
                ? (authService.currentUser?.isAdmin == true
                    ? const AdminDashboardScreen()
                    : const ProfileScreen())
                : const LoginScreen(),
              '/ai-assistant': (context) => authService.isAuthenticated
                ? const AIChatbotScreen()
                : const LoginScreen(),
              '/affiliate': (context) => authService.isAuthenticated
                ? const AffiliateScreen()
                : const LoginScreen(),
              // Admin panel routes
              '/admin-panel/dashboard': (context) {
                if (!authService.isAuthenticated) {
                  return const LoginScreen();
                }
                if (authService.currentUser?.isAdmin != true) {
                  if (kDebugMode) {
                    print('Non-admin user attempted to access admin dashboard');
                    print('User admin status: ${authService.currentUser?.isAdmin}');
                  }
                  return const MainScreen();
                }
                return const AdminDashboardScreen();
              },
              '/admin-panel/content': (context) {
                if (!authService.isAuthenticated || authService.currentUser?.isAdmin != true) {
                  return const MainScreen();
                }
                return const AdminContentScreen();
              },
              '/admin-panel/content/topics': (context) {
                if (!authService.isAuthenticated || authService.currentUser?.isAdmin != true) {
                  return const MainScreen();
                }
                return const AdminContentScreen(initialTabIndex: 0);
              },
              '/admin-panel/content/questions': (context) {
                if (!authService.isAuthenticated || authService.currentUser?.isAdmin != true) {
                  return const MainScreen();
                }
                return const AdminContentScreen(initialTabIndex: 1);
              },
              '/admin-panel/content/ai-templates': (context) {
                if (!authService.isAuthenticated || authService.currentUser?.isAdmin != true) {
                  return const MainScreen();
                }
                return const AdminContentScreen(initialTabIndex: 2);
              },
              '/admin-panel/content/exams': (context) {
                if (!authService.isAuthenticated || authService.currentUser?.isAdmin != true) {
                  return const MainScreen();
                }
                return const ExamsScreen();
              },
              '/admin-panel/users': (context) {
                if (!authService.isAuthenticated || authService.currentUser?.isAdmin != true) {
                  return const MainScreen();
                }
                return const AdminUsersScreen();
              },
              '/admin-panel/ai-alerts': (context) {
                if (!authService.isAuthenticated || authService.currentUser?.isAdmin != true) {
                  return const MainScreen();
                }
                return const AdminAIAlertsScreen();
              },
              '/admin-panel/ai-search': (context) {
                if (!authService.isAuthenticated || authService.currentUser?.isAdmin != true) {
                  return const MainScreen();
                }
                return const AdminAISearchManagementScreen();
              },
              '/admin-panel/monetization': (context) {
                if (!authService.isAuthenticated || authService.currentUser?.isAdmin != true) {
                  return const MainScreen();
                }
                return const MonetizationScreen();
              },
              '/admin-panel/monetization/plans': (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                ? const MonetizationScreen(initialTabIndex: 0)
                : const MainScreen(),
              '/admin-panel/monetization/subscriptions': (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                ? const MonetizationScreen(initialTabIndex: 1)
                : const MainScreen(),
              '/admin-panel/monetization/referrals': (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                ? const MonetizationScreen(initialTabIndex: 2)
                : const MainScreen(),
              '/admin-panel/monetization/payments': (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                ? const MonetizationScreen(initialTabIndex: 3)
                : const MainScreen(),
              '/admin-panel/support': (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                ? const FAQManagementScreen()
                : const MainScreen(),
              '/admin-panel/settings': (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                ? const GeneralSettingsScreen()
                : const MainScreen(),
              '/admin-panel/subscriptions': (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                ? const MonetizationScreen(initialTabIndex: 1)
                : const MainScreen(),
              '/admin-panel/affiliates': (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                ? const AffiliateManagementScreen()
                : const MainScreen(),
            },
            onGenerateRoute: (settings) {
              // Handle dynamic routes
              if (settings.name?.startsWith('/reset-password/confirm/') ?? false) {
                final token = settings.name!.split('/').last;
                return MaterialPageRoute(
                  builder: (context) => PasswordResetConfirmScreen(token: token),
                );
              }
              
              // Handle exam practice routes
              if (settings.name?.startsWith('/exams/') ?? false) {
                final parts = settings.name!.split('/');
                
                // Route format: /exams/{examId}/practice or /exams/{examId}/{categoryId}/practice
                if (parts.length >= 4 && parts.last == 'practice') {
                  final examId = parts[2];
                  final categoryId = parts.length == 5 ? parts[3] : null;
                  
                  return MaterialPageRoute(
                    builder: (context) => authService.isAuthenticated
                      ? PracticeScreen(
                          examId: examId,
                          categoryId: categoryId,
                        )
                      : const LoginScreen(),
                  );
                }
                
                // Route format: /exams/{examId}/session/{sessionId}
                if (parts.length == 5 && parts[3] == 'session') {
                  final examId = parts[2];
                  final sessionId = parts[4];
                  
                  return MaterialPageRoute(
                    builder: (context) => authService.isAuthenticated
                      ? ExamSessionScreen(
                          examId: examId,
                          sessionId: sessionId,
                        )
                      : const LoginScreen(),
                  );
                }
                
                // Route format: /exams/{examId}/pricing
                if (parts.length == 4 && parts[3] == 'pricing') {
                  final examId = parts[2];
                  
                  return MaterialPageRoute(
                    builder: (context) => FutureBuilder<Exam?>(
                      future: context.examService.getExamById(examId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return PricingScreen(
                          selectedExam: snapshot.data,
                        );
                      },
                    ),
                  );
                }
              }
              
              // Handle exam results routes
              if (settings.name?.startsWith('/results/') ?? false) {
                final parts = settings.name!.split('/');
                if (parts.length == 3) {
                  final sessionId = parts[2];
                  return MaterialPageRoute(
                    builder: (context) => authService.isAuthenticated
                      ? ExamResultsScreen(
                          sessionId: sessionId,
                        )
                      : const LoginScreen(),
                  );
                }
              }
              
              // Handle practice results routes
              if (settings.name?.startsWith('/practice-results/') ?? false) {
                final parts = settings.name!.split('/');
                if (parts.length == 3) {
                  final sessionId = parts[2];
                  return MaterialPageRoute(
                    builder: (context) => authService.isAuthenticated
                      ? PracticeResultsScreen(
                          sessionId: sessionId,
                        )
                      : const LoginScreen(),
                  );
                }
              }
              
              // Handle admin user detail routes
              if (settings.name?.startsWith('/admin-panel/users/') ?? false) {
                final parts = settings.name!.split('/');
                if (parts.length == 4) {
                  final userId = parts[3];
                  return MaterialPageRoute(
                    builder: (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                      ? UserDetailScreen(userId: userId)
                      : const MainScreen(),
                  );
                }
              }
              
              // Handle admin AI alert detail routes
              if (settings.name?.startsWith('/admin-panel/ai-alerts/') ?? false) {
                final parts = settings.name!.split('/');
                if (parts.length == 4) {
                  final alertId = parts[3];
                  return MaterialPageRoute(
                    builder: (context) => authService.isAuthenticated && authService.currentUser?.isAdmin == true
                      ? AlertDetailScreen(alertId: alertId)
                      : const MainScreen(),
                  );
                }
              }
              
              return null;
            },
            onUnknownRoute: (settings) {
              // Redirect to dashboard with error message
              return MaterialPageRoute(
                builder: (context) {
                  // Show error message after the page is built
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${context.tr("route_not_found")}: ${settings.name}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                  
                  // Return to appropriate dashboard based on user role
                  return authService.isAuthenticated
                    ? (authService.currentUser?.isAdmin == true
                        ? const AdminDashboardScreen()
                        : const MainScreen())
                    : const HomeScreen();
                },
              );
            },
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _hasCheckedAdmin = false;
  
  final List<Widget> _screens = [
    const HomeScreen(),
    const MyExamsScreen(),
    const AIChatbotScreen(),
    const ReportsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Schedule admin check for after the initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRedirectIfAdmin();
    });
  }
  
  void _checkAndRedirectIfAdmin() {
    if (_hasCheckedAdmin) return;
    
    // Get the current user from auth service
    final user = context.authService.currentUser;
    
    if (kDebugMode) {
      print('MainScreen: Checking admin status');
      print('Current user: ${user?.name ?? 'null'}');
      print('User ID: ${user?.id ?? 'null'}');
      print('Is admin/staff: ${user?.isAdmin ?? 'null'}');
    }
    
    // If user is admin and widget is mounted, redirect to admin dashboard
    if (user?.isAdmin == true && mounted) {
      if (kDebugMode) {
        print('MainScreen: Detected admin user, redirecting to admin dashboard');
        print('User admin status: ${user?.isAdmin}');
        print('User details: ${user?.name}, ID: ${user?.id}');
      }
      
      _hasCheckedAdmin = true;
      Navigator.of(context).pushReplacementNamed('/admin-panel/dashboard');
    } else {
      if (kDebugMode) {
        print('MainScreen: User is not admin, showing regular UI');
      }
      _hasCheckedAdmin = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple check without causing rebuilds
    final user = context.authService.currentUser;
    final isAdmin = user?.isAdmin ?? false;
    
    if (kDebugMode) {
      print('MainScreen build: Checking admin status');
      print('Current user: ${user?.name ?? 'null'}');
      print('Is admin: $isAdmin');
    }
    
    // If admin and haven't checked yet, show loading
    if (isAdmin && !_hasCheckedAdmin) {
      if (kDebugMode) {
        print('MainScreen build: Detected admin user, will redirect');
      }
      
      // Schedule the redirect for the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndRedirectIfAdmin();
      });
      
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Redirecting to admin dashboard...'),
            ],
          ),
        ),
      );
    }
    
    // Normal user UI
    if (kDebugMode) {
      print('MainScreen build: Showing regular user UI');
    }
    
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: context.tr('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book),
            label: context.tr('my_exams'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.smart_toy),
            label: 'AI Assistant',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics),
            label: context.tr('reports'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: context.tr('profile'),
          ),
        ],
      ),
    );
  }
} 