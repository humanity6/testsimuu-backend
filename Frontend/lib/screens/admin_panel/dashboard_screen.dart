import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../models/user.dart';
import '../../models/subscription.dart';
import '../../models/ai_alert.dart';
import '../../services/admin_service.dart';
import '../../utils/api_config.dart';
import '../../utils/responsive_utils.dart';
import 'content/topics_screen.dart';
import 'content/questions_screen.dart';
import 'content/ai_templates_screen.dart';
import 'content/exams_screen.dart';
import '../../../widgets/admin/ai_alerts_widget.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _dashboardData = {};
  String? _error;
  late AdminService _adminService;

  @override
  void initState() {
    super.initState();
    _initializeAdminService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuild when orientation changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _initializeAdminService() {
    try {
      final authService = context.authService;
      final user = authService.currentUser;
      final accessToken = authService.accessToken;
      
      // Debug: Print token info
      print('User: ${user?.name}');
      print('User isStaff: ${user?.isStaff}');
      print('Access token available: ${accessToken != null}');
      if (accessToken != null) {
        print('Token (first 20 chars): ${accessToken.substring(0, accessToken.length > 20 ? 20 : accessToken.length)}...');
      }
      
      if (user != null && accessToken != null && user.isStaff) {
        _adminService = AdminService(accessToken: accessToken);
        _checkApiAndLoadData();
      } else if (user == null || accessToken == null) {
        // Handle case where user is not available or not authenticated
        print('No user or access token available, redirecting to login');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
      } else if (!user.isStaff) {
        // User is authenticated but not admin
        print('User is not admin, showing error');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _error = 'You do not have admin privileges to access this panel';
              _isLoading = false;
            });
          }
        });
      }
    } catch (e) {
      print('Error initializing admin service: $e');
      // Create admin service with null token as fallback
      _adminService = AdminService(accessToken: null);
      setState(() {
        _error = context.tr('auth_error');
        _isLoading = false;
      });
    }
  }

  Future<void> _checkApiAndLoadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check if API is available first
      final isApiAvailable = await ApiConfig.checkApiAvailability();
      if (!isApiAvailable) {
        if (mounted) {
          setState(() {
            _error = context.tr('api_unavailable');
            _isLoading = false;
          });
        }
        return;
      }

      // API is available, proceed with loading data
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Create variables to store our data with fallbacks
      Map<String, dynamic> metrics = {};
      Map<String, dynamic> aiStats = {'total_evaluations_last_7_days': 0};
      List<Subscription> activeSubscriptions = [];
      List<AIAlert> alerts = [];
      
      bool hasAuthError = false;
      String authErrorMessage = '';

      try {
        metrics = await _adminService.getDashboardMetrics();
        print('Loaded metrics: $metrics');
      } catch (e) {
        print('Error loading dashboard metrics: $e');
        if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
          hasAuthError = true;
          authErrorMessage = 'Authentication failed. Please check your admin permissions.';
        }
        // Continue with other data
      }

      try {
        aiStats = await _adminService.getAIUsageStats();
        print('Loaded AI stats: $aiStats');
      } catch (e) {
        print('Error loading AI usage stats: $e');
        if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
          hasAuthError = true;
          authErrorMessage = 'Authentication failed. Please check your admin permissions.';
        }
        // Continue with other data
      }

      try {
        activeSubscriptions = await _adminService.getActiveSubscriptions();
        print('Loaded ${activeSubscriptions.length} active subscriptions');
      } catch (e) {
        print('Error loading active subscriptions: $e');
        if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
          hasAuthError = true;
          authErrorMessage = 'Authentication failed. Please check your admin permissions.';
        } else if (e.toString().contains('Failed to parse subscription data')) {
          print('Subscription parsing error, continuing with empty list');
          activeSubscriptions = [];
          // Don't set as auth error since this is a data parsing issue
        } else {
          print('Other subscription error: $e');
          activeSubscriptions = [];
        }
        // Continue with other data
      }

      try {
        // Try loading all alerts first, then filter if needed
        alerts = await _adminService.getAIAlerts();
        print('Loaded ${alerts.length} AI alerts');

        // If we need to fetch more specific alerts, try fetching high priority ones
        if (alerts.isEmpty) {
          alerts = await _adminService.getAIAlerts(priority: 'HIGH');
          print('Loaded ${alerts.length} high priority AI alerts');
        }
      } catch (e) {
        print('Error loading AI alerts: $e');
        if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
          hasAuthError = true;
          authErrorMessage = 'Authentication failed. Please check your admin permissions.';
        } else if (e.toString().contains('400')) {
          print('Bad request for AI alerts, setting empty list');
          alerts = [];
        }
        // Continue with other data
      }

      if (mounted) {
        if (hasAuthError) {
          setState(() {
            _error = authErrorMessage;
            _isLoading = false;
          });
          
          // Show authentication error dialog
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAuthenticationErrorDialog();
          });
          
          return;
        }

        setState(() {
          _dashboardData = {
            'totalUsers': metrics['total_users'] ?? 0,
            'activeUsers': metrics['active_users'] ?? 0,
            'newUsersThisMonth': metrics['new_users_this_month'] ?? 0,
            'verifiedUsers': metrics['verified_users'] ?? 0,
            'staffUsers': metrics['staff_users'] ?? 0,
            'totalQuestions': metrics['total_questions'] ?? 0,
            'activeQuestions': metrics['active_questions'] ?? 0,
            'questionsByType': metrics['questions_by_type'] ?? {},
            'questionsByDifficulty': metrics['questions_by_difficulty'] ?? {},
            'activeSubscriptions': activeSubscriptions.length,
            'aiUsage': aiStats['total_evaluations_last_7_days'] ?? 0,
            'alerts': alerts.length,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading dashboard data: ${e.toString()}';
          _isLoading = false;
        });
        print('Dashboard data loading error: $e');
      }
    }
  }

  void _showAuthenticationErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(context.tr('authentication_error')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('admin_permission_error')),
            const SizedBox(height: 8),
            Text(context.tr('error_reasons')),
            const SizedBox(height: 4),
            Text(context.tr('session_expired')),
            Text(context.tr('no_admin_privileges')),
            Text(context.tr('backend_auth_issues')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Try to refresh the page
              _checkApiAndLoadData();
            },
            child: Text(context.tr('retry')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Logout and redirect to login
              await context.authService.logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: Text(context.tr('login_again')),
          ),
        ],
      ),
    );
  }

  // Navigate safely to a route, with fallback to dashboard if route doesn't exist
  void _navigateSafely(BuildContext context, String route) {
    try {
      Navigator.of(context).pushNamed(route);
    } catch (e) {
      // Show a snackbar if the route doesn't exist
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr("route_not_found")}: $route'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Handle logout with confirmation
  Future<void> _handleLogout() async {
    // Logout and redirect to login
    await context.authService.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is admin, redirect if not
    final user = context.authService.currentUser;
    
    if (user == null || !user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('admin_dashboard')),
          actions: const [
            LanguageSelector(isCompact: true),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('authentication_error'),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  context.tr('admin_permission_error'),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  context.tr('error_reasons'),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('session_expired')),
                    Text(context.tr('no_admin_privileges')),
                    Text(context.tr('backend_auth_issues')),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadDashboardData,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('retry')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.exit_to_app),
                    label: Text(context.tr('login_again')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('admin_dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('refresh'),
            onPressed: _checkApiAndLoadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: context.tr('logout'),
            onPressed: () async {
              // Show confirmation dialog
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.tr('logout_confirmation')),
                  content: Text(context.tr('logout_confirmation_message')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(context.tr('cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(context.tr('logout'), style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ) ?? false;
              
              if (shouldLogout && mounted) {
                await context.authService.logout();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
          ),
          const LanguageSelector(isCompact: true),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.darkBlue,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 40,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('admin_panel'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(
                context,
                icon: Icons.dashboard,
                title: context.tr('dashboard'),
                route: '/admin-panel/dashboard',
                isActive: true,
              ),
              _buildDrawerItem(
                context,
                icon: Icons.content_paste,
                title: context.tr('content_management'),
                route: '/admin-panel/content',
              ),
              _buildDrawerItem(
                context,
                icon: Icons.person,
                title: context.tr('user_management'),
                route: '/admin-panel/users',
              ),
              _buildDrawerItem(
                context,
                icon: Icons.notifications,
                title: context.tr('ai_alerts'),
                route: '/admin-panel/ai-alerts',
              ),
              _buildDrawerItem(
                context,
                icon: Icons.search,
                title: 'AI Search Management',
                route: '/admin-panel/ai-search',
              ),
              _buildDrawerItem(
                context,
                icon: Icons.monetization_on,
                title: context.tr('monetization'),
                route: '/admin-panel/monetization',
              ),
              _buildDrawerItem(
                context,
                icon: Icons.help,
                title: context.tr('support'),
                route: '/admin-panel/support',
              ),
              _buildDrawerItem(
                context,
                icon: Icons.settings,
                title: context.tr('settings'),
                route: '/admin-panel/settings',
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  final isTablet = screenWidth > 600;
                  final horizontalPadding = isTablet ? 24.0 : 16.0;
                  final verticalSpacing = isTablet ? 32.0 : 24.0;
                  
                  return Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('admin_dashboard_metrics'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: isTablet ? 24 : 20,
                          ),
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildMetricsGrid(),
                        SizedBox(height: verticalSpacing),
                        Text(
                          context.tr('admin_quick_links'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontSize: isTablet ? 24 : 20,
                          ),
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        _buildQuickLinks(),
                        SizedBox(height: horizontalPadding), // Bottom padding
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isWideDesktop = screenWidth >= 1200;
        final isTablet = screenWidth > 600 && screenWidth < 900;
        
        return isWideDesktop 
            ? _buildWideDesktopLayout()
            : isTablet
                ? _buildTabletLayout()
                : _buildMobileLayout();
      },
    );
  }
  
  Widget _buildWideDesktopLayout() {
    return Column(
      children: [
        // First row with metrics
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildMetricsCardsGrid(),
            ),
            SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Container(
                constraints: BoxConstraints(
                  minHeight: 250, // Reduced minimum height for better visibility
                  maxHeight: 600, // Increased maximum height for fullscreen mode
                ),
                child: AIAlertsDashboardWidget(
                  alerts: context.adminService.cachedAlerts ?? [],
                  onAlertTap: (alert) {
                    Navigator.of(context).pushNamed(
                      '/admin-panel/ai-alerts/detail',
                      arguments: alert,
                    );
                  },
                  onViewAllTap: () {
                    Navigator.of(context).pushNamed('/admin-panel/ai-alerts');
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        // Second row with other widgets
        // You can add more rows with other dashboard widgets here
      ],
    );
  }
  
  Widget _buildTabletLayout() {
    return Column(
      children: [
        _buildMetricsCardsGrid(),
        SizedBox(height: 20),
        Container(
          constraints: BoxConstraints(
            minHeight: 250, // Minimum height for visibility
            maxHeight: 500, // Maximum height to prevent overflow
          ),
          child: AIAlertsDashboardWidget(
            alerts: context.adminService.cachedAlerts ?? [],
            onAlertTap: (alert) {
              Navigator.of(context).pushNamed(
                '/admin-panel/ai-alerts/detail',
                arguments: alert,
              );
            },
            onViewAllTap: () {
              Navigator.of(context).pushNamed('/admin-panel/ai-alerts');
            },
          ),
        ),
        SizedBox(height: 20),
        _buildChartCard(),
      ],
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildMetricsCardsGrid(),
        SizedBox(height: 20),
        Container(
          constraints: BoxConstraints(
            minHeight: 180, // Minimum height for visibility on mobile
            maxHeight: 400, // Maximum height to prevent overflow
          ),
          child: AIAlertsDashboardWidget(
            alerts: context.adminService.cachedAlerts ?? [],
            onAlertTap: (alert) {
              Navigator.of(context).pushNamed(
                '/admin-panel/ai-alerts/detail',
                arguments: alert,
              );
            },
            onViewAllTap: () {
              Navigator.of(context).pushNamed('/admin-panel/ai-alerts');
            },
          ),
        ),
        SizedBox(height: 20),
        _buildChartCard(),
      ],
    );
  }
  
  Widget _buildMetricsCardsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: ResponsiveUtils.isMobile(context) ? 2 : 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: ResponsiveUtils.isMobile(context) ? 1.0 : 1.2,
      children: [
        _buildMetricCard(
          title: context.tr('Total Users'),
          value: _dashboardData['totalUsers'].toString(),
          icon: Icons.people,
          color: AppColors.blue,
        ),
        _buildMetricCard(
          title: context.tr('Active Subscriptions'),
          value: _dashboardData['activeSubscriptions'].toString(),
          icon: Icons.subscriptions,
          color: AppColors.green,
        ),
        _buildMetricCard(
          title: context.tr('AI Feedback Usage'),
          value: _dashboardData['aiUsage'].toString(),
          icon: Icons.psychology,
          color: AppColors.purple,
        ),
        _buildMetricCard(
          title: context.tr('Content Alerts'),
          value: _dashboardData['alerts'].toString(),
          icon: Icons.notifications_active,
          color: Colors.orange,
          isAlert: true,
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('User Activity'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.5,
              child: _buildUserRegistrationChart(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildUserRegistrationChart() {
    // Check if we have data for the user registration chart
    final List<Map<String, dynamic>> registrationData = 
        _dashboardData['user_registrations'] != null ? 
        List<Map<String, dynamic>>.from(_dashboardData['user_registrations']) : [];
    
    // If no data is available, show a placeholder
    if (registrationData.isEmpty) {
      return const Center(
        child: Text('No registration data available'),
      );
    }
    
    // Create bar groups from the data
    final barGroups = registrationData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final count = (data['count'] as num).toDouble();
      return _buildBarGroup(index, count);
    }).toList();
    
    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= registrationData.length) {
                    return const SizedBox.shrink();
                  }
                  final day = registrationData[value.toInt()]['day'] ?? '';
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 10),
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 5 != 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 10),
                        color: Colors.grey[600],
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }
  
  BarChartGroupData _buildBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppColors.darkBlue,
          width: ResponsiveUtils.isMobile(context) ? 12 : 18,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 20,
            color: Colors.grey.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isAlert = false,
  }) {
    // Ensure value is a valid number, default to "0" if not
    String displayValue = value;
    int numValue = 0;
    
    try {
      numValue = int.parse(value);
    } catch (e) {
      displayValue = "0";
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Add haptic feedback for touch screens
          HapticFeedback.lightImpact();
          _showMetricDetails(title, displayValue, icon, color);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 22, desktopSize: 24),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        displayValue,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context, base: 32),
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      if (isAlert && numValue > 0)
                        Container(
                          margin: EdgeInsets.only(left: 8, bottom: 8),
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveUtils.getFontSize(context, base: 10),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMetricDetails(String title, String value, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(context.tr('close')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLinks() {
    final adminLinks = [
      {
        'title': context.tr('manage_exams'),
        'icon': Icons.quiz,
        'route': '/admin-panel/content/exams',
      },
      {
        'title': context.tr('manage_topics'),
        'icon': Icons.category,
        'route': '/admin-panel/content/topics',
      },
      {
        'title': context.tr('manage_questions'),
        'icon': Icons.question_answer,
        'route': '/admin-panel/content/questions',
      },
      {
        'title': context.tr('ai_templates'),
        'icon': Icons.psychology,
        'route': '/admin-panel/content/ai-templates',
      },
      {
        'title': context.tr('user_management'),
        'icon': Icons.people,
        'route': '/admin-panel/users',
      },
      {
        'title': context.tr('subscription_management'),
        'icon': Icons.subscriptions,
        'route': '/admin-panel/subscriptions',
      },
      {
        'title': 'Affiliate Management',
        'icon': Icons.group_add,
        'route': '/admin-panel/affiliates',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isTablet = screenWidth > 600;
        final crossAxisCount = isTablet ? 4 : 2;
        final childAspectRatio = isTablet ? 1.2 : 1.0;
        
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12.0,
            mainAxisSpacing: 12.0,
            childAspectRatio: childAspectRatio,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: adminLinks.length,
          itemBuilder: (context, index) {
            final link = adminLinks[index];
            return _buildQuickLinkCard(
              title: link['title'] as String,
              icon: link['icon'] as IconData,
              onTap: () => _navigateSafely(context, link['route'] as String),
              index: index,
            );
          },
        );
      },
    );
  }

  Widget _buildQuickLinkCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required int index,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;
        final isSmallCard = cardHeight < 120 || cardWidth < 150;
        
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutBack,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(isSmallCard ? 8.0 : 12.0),
                child: _buildQuickLinkContent(
                  title: title,
                  icon: icon,
                  isSmallCard: isSmallCard,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickLinkContent({
    required String title,
    required IconData icon,
    required bool isSmallCard,
  }) {
    final iconSize = isSmallCard ? 28.0 : 36.0;
    final fontSize = isSmallCard ? 11.0 : 13.0;
    final spacing = isSmallCard ? 6.0 : 10.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          flex: 3,
          child: Icon(
            icon,
            size: iconSize,
            color: AppColors.darkBlue,
          ),
        ),
        SizedBox(height: spacing),
        Flexible(
          flex: 2,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    bool isActive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppColors.darkBlue : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? AppColors.darkBlue : null,
          fontWeight: isActive ? FontWeight.bold : null,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        if (route != '/admin-panel/dashboard' || !isActive) {
          // For non-dashboard routes, use pushNamed to maintain navigation stack
          if (route == '/admin-panel/dashboard') {
            Navigator.of(context).pushReplacementNamed(route);
          } else {
            Navigator.of(context).pushNamed(route);
          }
        }
      },
    );
  }
} 