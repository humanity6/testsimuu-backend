import 'package:flutter/material.dart';import 'package:flutter/foundation.dart';import '../../models/user.dart';import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/exam_card.dart';
import '../../widgets/section_header.dart';
import '../../providers/app_providers.dart';
import '../../utils/auth_navigation.dart';
import '../pricing/pricing_screen.dart';
import '../exams/exams_screen.dart';
import '../exams/exam_mode_selection_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../utils/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../services/localization_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<void> _examsFuture;
  bool _isLoadingDashboard = false;
  Map<String, dynamic> _dashboardData = {};
  String? _dashboardError;
  late final _authService;

  @override
  void initState() {
    super.initState();
    _examsFuture = _loadData();
    
    // Store a reference to the auth service to avoid context issues in dispose
    _authService = context.authService;
    
    // Listen to auth changes to refresh UI accordingly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _authService.addListener(_refreshOnAuthChange);
        
        // Show welcome message if the user just logged in
        if (_authService.isAuthenticated) {
          _showWelcomeMessage();
        }
      }
    });
  }

  @override
  void dispose() {
    // Remove listener using stored reference instead of context
    _authService.removeListener(_refreshOnAuthChange);
    super.dispose();
  }

  void _refreshOnAuthChange() {
    // Reload data and rebuild UI when auth state changes
    if (mounted) {
      setState(() {
        _examsFuture = _loadData();
      });
    }
  }

  Future<void> _loadData() async {
    // Use a small delay to ensure the widget is fully built before making API calls
    await Future.delayed(Duration.zero);
    
    // Check if widget is still mounted before accessing context
    if (!mounted) return;
    
    final isAuthenticated = context.authService.isAuthenticated;
    
    if (isAuthenticated) {
      await _loadDashboardData();
    } else {
      await context.examService.fetchFeaturedExams();
    }
  }

  Future<void> _loadDashboardData() async {
    // Check if widget is still mounted before making state changes
    if (!mounted) return;
    
    // Initialize dashboard data with default values
    setState(() {
      _isLoadingDashboard = true;
      _dashboardError = null;
      // Set default values for all dashboard sections to prevent null errors
      _dashboardData = {
        'subscriptions': [],
        'performance': {
          'completed_quizzes': 0,
          'average_score': 0,
          'total_study_time_hours': 0,
        },
        'performance_trends': [],
        'exams': [],
      };
    });

    try {
      final token = context.authService.getToken();

      if (token == null) {
        throw Exception('Authentication token not available');
      }

      // Fetch dashboard data in parallel
      await Future.wait([
        _fetchUserExams(token),
        _fetchUserSubscriptions(token),
        _fetchUserPerformance(token),
        _fetchTopicProgress(token),
      ]);
      
      if (mounted) {
        setState(() {
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDashboard = false;
          _dashboardError = e.toString();
        });
      }
      if (kDebugMode) {
        print('Error loading dashboard data: $e');
      }
    }
  }

  Future<void> _fetchUserExams(String token) async {
    try {
      await context.userExamService.fetchUserExams();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _fetchUserSubscriptions(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.userSubscriptionsEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('User subscriptions response: ${response.body}');
          print('User subscriptions data type: ${data.runtimeType}');
        }
        
        List<dynamic> subscriptionsList = [];
        
        // Ensure we're handling the data correctly regardless of its format
        if (data is List) {
          subscriptionsList = data;
        } else if (data is Map) {
          // If it's a map with a 'results' field (common pagination pattern)
          if (data.containsKey('results') && data['results'] is List) {
            subscriptionsList = data['results'];
          } else {
            // If it's just a map, wrap it in a list to handle it uniformly
            subscriptionsList = [data];
          }
        } else {
          // Default to empty list if the format is unexpected
          subscriptionsList = [];
          if (kDebugMode) {
            print('Unexpected subscription data format: $data');
          }
        }
        
        if (mounted) {
          setState(() {
            _dashboardData['subscriptions'] = subscriptionsList;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _dashboardData['subscriptions'] = [];
          });
        }
      }
    } catch (e) {
      // Handle error and set default empty list
      if (mounted) {
        setState(() {
          _dashboardData['subscriptions'] = [];
        });
      }
      if (kDebugMode) {
        print('Error fetching user subscriptions: $e');
      }
    }
  }

  Future<void> _fetchUserPerformance(String token) async {
    try {
      // Fetch performance summary from the correct API endpoint
      final response = await http.get(
        Uri.parse(ApiConfig.performanceSummaryEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('Performance data received: $data');
        }
        
        if (mounted) {
          setState(() {
            _dashboardData['performance'] = data;
          });
        }
        
        // Also fetch performance trends for more detailed analytics
        await _fetchPerformanceTrends(token);
      } else {
        // If the API fails, use some default data
        if (mounted) {
          setState(() {
            _dashboardData['performance'] = {
              'completed_quizzes': 0,
              'average_score': 0,
              'total_study_time_hours': 0,
            };
          });
        }
      }
    } catch (e) {
      // Handle error, use default data in case of failure
      if (mounted) {
        setState(() {
          _dashboardData['performance'] = {
            'completed_quizzes': 0,
            'average_score': 0,
            'total_study_time_hours': 0,
          };
        });
      }
      
      if (kDebugMode) {
        print('Error fetching performance data: ${e.toString()}');
      }
    }
  }
  
  Future<void> _fetchPerformanceTrends(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.performanceTrendsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            _dashboardData['performance_trends'] = data;
          });
        }
      } else {
        // Handle error status codes
        if (kDebugMode) {
          print('Error fetching performance trends: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
        // Set empty trends data to prevent UI errors
        if (mounted) {
          setState(() {
            _dashboardData['performance_trends'] = [];
          });
        }
      }
    } catch (e) {
      // Set empty trends data to prevent UI errors
      if (mounted) {
        setState(() {
          _dashboardData['performance_trends'] = [];
        });
      }
      
      if (kDebugMode) {
        print('Exception fetching performance trends: ${e.toString()}');
      }
    }
  }

  Future<void> _fetchTopicProgress(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.progressByTopicEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            _dashboardData['topic_progress'] = data;
          });
        }
      } else {
        // Handle error status codes
        if (kDebugMode) {
          print('Error fetching topic progress: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
        // Set empty progress data to prevent UI errors
        if (mounted) {
          setState(() {
            _dashboardData['topic_progress'] = [];
          });
        }
      }
    } catch (e) {
      // Set empty progress data to prevent UI errors
      if (mounted) {
        setState(() {
          _dashboardData['topic_progress'] = [];
        });
      }
      
      if (kDebugMode) {
        print('Exception fetching topic progress: ${e.toString()}');
      }
    }
  }

  void _navigateToPricing() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PricingScreen()),
    );
  }

  void _navigateToExams() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExamsScreen(),
      ),
    );
  }

  void _navigateToSignup() {
    AuthNavigation.navigateToSignup(context);
  }

  void _navigateToLogin() {
    AuthNavigation.navigateToLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localizationService, child) {
        final isAuthenticated = context.authService.isAuthenticated;
        
        return Scaffold(
          backgroundColor: AppColors.white,
          body: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                backgroundColor: AppColors.white,
                elevation: 0,
                floating: true,
                pinned: true,
                expandedHeight: 0,
                leadingWidth: 0,
                leading: const SizedBox(),
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
              ),

              // Content
              SliverToBoxAdapter(
                child: isAuthenticated
                    ? _buildDashboardView()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero Section
                          _buildHeroSection(),

                          // How It Works Section
                          _buildHowItWorksSection(),

                          // Featured Exams Section
                          FutureBuilder<void>(
                            future: _examsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              } else {
                                return _buildFeaturedExamsSection();
                              }
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
          floatingActionButton: isAuthenticated
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.pushNamed(context, '/ai-assistant');
                  },
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.smart_toy),
                  label: Text(context.tr('ai_assistant')),
                )
              : null,
        );
      },
    );
  }

  Widget _buildDashboardView() {
    if (_isLoadingDashboard) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_dashboardError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                context.tr('dashboard_error'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_dashboardError!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDashboardData,
                child: Text(context.tr('retry')),
              ),
            ],
          ),
        ),
      );
    }

    // Get user data
    final user = context.authService.currentUser;
    if (user == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserHeader(user),
        _buildDashboardSummary(),
        _buildActiveSubscriptions(),
        _buildAnalyticsPreview(),
        _buildRecentExams(),
      ],
    );
  }

  Widget _buildUserHeader(User user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.limeYellow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.darkBlue,
                child: _buildUserAvatar(user),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('welcome_user', params: {'name': user.name}),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(User user) {
    // Check if user has a valid avatar URL
    if (user.avatar?.isNotEmpty == true && _isValidImageUrl(user.avatar!)) {
      return ClipOval(
        child: Image.network(
          user.avatar!,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // If network image fails, show initials
            return _buildInitialsAvatar(user);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          },
        ),
      );
    } else {
      // Show initials if no valid avatar
      return _buildInitialsAvatar(user);
    }
  }

  Widget _buildInitialsAvatar(User user) {
    return Text(
      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  bool _isValidImageUrl(String url) {
    // Check if URL is valid and not a placeholder
    if (url.isEmpty) return false;
    if (url.contains('example.com')) return false; // Filter out example URLs
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  Widget _buildDashboardSummary() {
    final performance = _dashboardData['performance'] as Map<String, dynamic>? ?? {};
    
    // Map API field names to expected field names
    final completedQuizzes = performance['total_questions'] ?? 0;
    final averageScore = performance['accuracy'] ?? 0;
    final studyTimeSeconds = performance['total_time_spent_seconds'] ?? 0;
    final studyTimeHours = (studyTimeSeconds / 3600).round(); // Convert seconds to hours
    
    if (kDebugMode) {
      print('Dashboard display - Completed: $completedQuizzes, Score: $averageScore%, Hours: $studyTimeHours');
      print('Raw performance data: $performance');
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('your_progress'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context.tr('completed_quizzes'),
                  completedQuizzes.toString(),
                  Icons.check_circle,
                  AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context.tr('average_score'),
                  '${averageScore.toStringAsFixed(1)}%',
                  Icons.analytics,
                  AppColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context.tr('study_time'),
                  '$studyTimeHours ${context.tr('hours')}',
                  Icons.access_time,
                  AppColors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptions() {
    // Safely get subscriptions, ensuring it's a list
    final subscriptionsData = _dashboardData['subscriptions'];
    final List<dynamic> subscriptions = 
        (subscriptionsData is List) ? subscriptionsData : [];
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('active_subscriptions'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          if (subscriptions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.subscriptions_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('no_active_subscriptions'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _navigateToPricing,
                        child: Text(context.tr('view_plans')),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subscriptions.length,
              itemBuilder: (context, index) {
                final subscription = subscriptions[index];
                
                // Extract subscription properties with correct field names
                final planName = subscription is Map ? (subscription['pricing_plan_name'] ?? context.tr('unknown_plan')) : context.tr('unknown_plan');
                final status = subscription is Map ? (subscription['status'] ?? context.tr('inactive_status')) : context.tr('inactive_status');
                final endDate = subscription is Map ? (subscription['end_date'] ?? context.tr('not_available')) : context.tr('not_available');
                final autoRenew = subscription is Map ? (subscription['auto_renew'] == true) : false;
                final price = subscription is Map ? (subscription['pricing_plan_price'] ?? '0') : '0';
                final currency = subscription is Map ? (subscription['pricing_plan_currency'] ?? context.tr('default_currency')) : context.tr('default_currency');
                
                // Format the end date
                String formattedEndDate = context.tr('not_available');
                if (endDate != context.tr('not_available')) {
                  try {
                    final date = DateTime.parse(endDate);
                    formattedEndDate = '${date.day}/${date.month}/${date.year}';
                  } catch (e) {
                    formattedEndDate = endDate;
                  }
                }
                
                // Choose colors based on status
                Color statusColor = AppColors.green;
                IconData statusIcon = Icons.verified;
                
                switch (status.toUpperCase()) {
                  case 'ACTIVE':
                    statusColor = AppColors.green;
                    statusIcon = Icons.verified;
                    break;
                  case 'EXPIRED':
                    statusColor = Colors.red;
                    statusIcon = Icons.warning;
                    break;
                  case 'CANCELED':
                    statusColor = Colors.orange;
                    statusIcon = Icons.cancel;
                    break;
                  default:
                    statusColor = Colors.grey;
                    statusIcon = Icons.info;
                }
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      planName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$price $currency'),
                        Text('${context.tr('expires')}: $formattedEndDate'),
                        Text(
                          context.tr(status.toLowerCase()),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    leading: Icon(statusIcon, color: statusColor),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (autoRenew && status == 'ACTIVE')
                          Chip(
                            label: Text(context.tr('auto_renew')),
                            backgroundColor: AppColors.green.withOpacity(0.1),
                            labelStyle: const TextStyle(color: AppColors.green, fontSize: 10),
                          ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPreview() {
    final performanceTrends = _dashboardData['performance_trends'];
    final topicProgress = _dashboardData['topic_progress'];
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('performance_overview'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full analytics screen
                  Navigator.of(context).pushNamed('/analytics');
                },
                child: Text(context.tr('view_all')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Performance Trends Preview
          if (performanceTrends != null && performanceTrends is Map && performanceTrends['data_points'] != null)
            _buildPerformanceTrendsPreview(performanceTrends['data_points'])
          else
            _buildNoAnalyticsCard('performance_trends'),
          
          const SizedBox(height: 16),
          
          // Topic Progress Preview
          if (topicProgress != null && topicProgress is List && topicProgress.isNotEmpty)
            _buildTopicProgressPreview(topicProgress.take(3).toList())
          else
            _buildNoAnalyticsCard('topic_progress'),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceTrendsPreview(List<dynamic> trendsData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: AppColors.blue),
                const SizedBox(width: 8),
                Text(
                  context.tr('recent_performance'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: trendsData.take(7).map<Widget>((trendData) {
                  final accuracy = (trendData['accuracy'] ?? 0).toDouble();
                  final questionsAnswered = trendData['questions_answered'] ?? 0;
                  final date = trendData['date'] ?? '';
                  
                  return Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        Container(
                          height: 40,
                          width: 12,
                          decoration: BoxDecoration(
                            color: accuracy >= 80 ? AppColors.green : 
                                   accuracy >= 60 ? Colors.orange : Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor: (accuracy / 100).clamp(0.1, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: accuracy >= 80 ? AppColors.green : 
                                       accuracy >= 60 ? Colors.orange : Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${accuracy.round()}%',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$questionsAnswered ${context.tr('q_abbreviation')}',
                          style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                        ),
                        Text(
                          date.length > 5 ? date.substring(5) : date,
                          style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopicProgressPreview(List<dynamic> topicsData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.category, color: AppColors.purple),
                const SizedBox(width: 8),
                Text(
                  context.tr('top_topics'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...topicsData.map<Widget>((topicData) {
              final topicName = topicData['topic_name'] ?? context.tr('unknown_topic');
              final completionPercentage = (topicData['completion_percentage'] ?? 0).toDouble();
              final proficiencyLevel = topicData['proficiency_level'] ?? context.tr('beginner');
              final questionsAttempted = topicData['questions_attempted'] ?? 0;
              final totalQuestions = topicData['total_questions_in_topic'] ?? 0;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topicName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$questionsAttempted / $totalQuestions ${context.tr('questions')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: completionPercentage / 100,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              completionPercentage >= 75 ? AppColors.green :
                              completionPercentage >= 50 ? Colors.orange : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${completionPercentage.round()}%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getProficiencyColor(proficiencyLevel).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  context.tr(proficiencyLevel.toLowerCase()),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _getProficiencyColor(proficiencyLevel),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoAnalyticsCard(String type) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(
                type == 'performance_trends' ? Icons.trending_up : Icons.category,
                size: 32,
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                type == 'performance_trends' 
                  ? context.tr('no_performance_data')
                  : context.tr('no_topic_progress'),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('start_practicing_to_see_data'),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getProficiencyColor(String level) {
    switch (level.toUpperCase()) {
      case 'EXPERT':
        return AppColors.green;
      case 'ADVANCED':
        return AppColors.blue;
      case 'INTERMEDIATE':
        return Colors.orange;
      case 'BEGINNER':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRecentExams() {
    final exams = context.userExamService.userExams;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('your_exams'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to My Exams tab
                  Navigator.of(context).pushNamed('/my-exams');
                },
                child: Text(context.tr('view_all')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (exams.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('no_exams_found'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _navigateToExams,
                        child: Text(context.tr('browse_exams')),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: exams.length,
                itemBuilder: (context, index) {
                  final exam = exams[index];
                  // Parse progress string to double for progress bar
                  double progressValue = 0.0;
                  if (exam.progress != null) {
                    // Remove % sign and convert to double
                    String progressStr = exam.progress!.replaceAll('%', '');
                    progressValue = double.tryParse(progressStr) ?? 0.0;
                  }
                  
                  return SizedBox(
                    width: 280,
                    child: Card(
                      margin: const EdgeInsets.only(right: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.exam.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${context.tr('progress')}: ${progressValue.toInt()}%',
                              style: const TextStyle(color: AppColors.darkGrey),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progressValue / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () {
                                // Navigate to the exam mode selection instead of direct practice
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExamModeSelectionScreen(
                                      examId: exam.exam.id,
                                      examTitle: exam.exam.title,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.darkBlue,
                                minimumSize: const Size(double.infinity, 36),
                              ),
                              child: Text(context.tr('continue')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Methods for the public home page
  Widget _buildHeroSection() {
    final isAuthenticated = context.authService.isAuthenticated;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.limeYellow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('hero_title'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('hero_subtitle'),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _navigateToExams,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(context.tr('browse_exams')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _navigateToPricing,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(context.tr('pricing')),
                ),
              ),
            ],
          ),
          // Only show login/signup buttons for unauthenticated users
          if (!isAuthenticated) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _navigateToSignup,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.white,
                    ),
                    child: Text(context.tr('sign_up')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextButton(
                    onPressed: _navigateToLogin,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(context.tr('log_in')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              context.tr('how_it_works'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkBlue,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildHowItWorksStep(
            '1',
            context.tr('how_it_works_step1_title'),
            context.tr('how_it_works_step1_desc'),
            Icons.search,
          ),
          _buildHowItWorksStep(
            '2',
            context.tr('how_it_works_step2_title'),
            context.tr('how_it_works_step2_desc'),
            Icons.quiz,
          ),
          _buildHowItWorksStep(
            '3',
            context.tr('how_it_works_step3_title'),
            context.tr('how_it_works_step3_desc'),
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep(
    String number,
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.limeYellow,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: AppColors.darkBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.darkGrey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedExamsSection() {
    return Container(
      padding: const EdgeInsets.only(bottom: 48),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: context.tr('featured_exams'),
            actionText: context.tr('view_all'),
            onActionTap: () {},
            hasDivider: true,
          ),
          _buildFeaturedExamsList(),
        ],
      ),
    );
  }

  Widget _buildFeaturedExamsList() {
    final exams = context.examService.featuredExams;
    final isLoading = context.examService.isLoading;
    final error = context.examService.error;

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            error,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (exams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            context.tr('no_exams_found'),
            style: TextStyle(color: AppColors.darkGrey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: exams.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ExamCard(
              exam: exams[index],
              onTap: () {},
              isCompact: true,
            ),
          );
        },
      ),
    );
  }

  // Show welcome message
  void _showWelcomeMessage() async {
    try {
      // Get translations before async operations to avoid Provider errors
      final userTranslation = context.tr('user');
      final welcomeUserTemplate = context.localization.translate('welcome_user');
      
      // Use SharedPreferences to check if welcome message has been shown this session
      final prefs = await SharedPreferences.getInstance();
      final sessionId = DateTime.now().day.toString() + DateTime.now().month.toString() + DateTime.now().year.toString();
      
      if (prefs.getString('last_welcome_session') != sessionId) {
        if (mounted && _authService.isAuthenticated) {
          final userName = _authService.currentUser?.name?.isNotEmpty == true 
              ? _authService.currentUser!.name 
              : userTranslation;
              
          // Create welcome message with parameters
          final welcomeMessage = welcomeUserTemplate.replaceAll('{name}', userName);
              
          // Show welcome snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(welcomeMessage),
              backgroundColor: AppColors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Save that we've shown the welcome message for this session
          await prefs.setString('last_welcome_session', sessionId);
        }
      }
    } catch (e) {
      // Silently handle any errors in showing the welcome message
      if (kDebugMode) {
        print('Error showing welcome message: $e');
      }
    }
  }
} 