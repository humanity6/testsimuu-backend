import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/user.dart';
import '../../theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../utils/image_utils.dart';
import '../../services/user_service.dart';
import '../../services/analytics_service.dart';
import '../../services/user_exam_service.dart';
import '../reports/reports_screen.dart';
import 'subscriptions_screen.dart';
import 'payment_history_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _performanceSummary = {};
  List<Map<String, dynamic>> _performanceByTopic = [];
  List<Map<String, dynamic>> _performanceTrends = [];
  List<Map<String, dynamic>> _progressByTopic = []; // New data for subject progress

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final authService = context.authService;
      if (authService.isAuthenticated && authService.accessToken != null) {
        // Get the analytics service
        final analyticsService = Provider.of<AnalyticsService>(context, listen: false);
        
        // Fetch data from analytics service
        await analyticsService.fetchPerformanceSummary(authService.accessToken!);
        await analyticsService.fetchPerformanceByTopic(authService.accessToken!);
        await analyticsService.fetchPerformanceTrends(authService.accessToken!);
        await analyticsService.fetchProgressByTopic(authService.accessToken!);
        
        // Legacy fetching for backward compatibility
        final userService = UserService();
        final results = await Future.wait([
          userService.fetchPerformanceSummary(authService.accessToken!),
          userService.fetchPerformanceByTopic(authService.accessToken!),
          userService.fetchPerformanceTrends(authService.accessToken!),
          userService.fetchUserProgressByTopic(authService.accessToken!),
        ]);
        
        if (mounted) {
          setState(() {
            _performanceSummary = results[0] as Map<String, dynamic>;
            _performanceByTopic = results[1] as List<Map<String, dynamic>>;
            _performanceTrends = results[2] as List<Map<String, dynamic>>;
            _progressByTopic = results[3] as List<Map<String, dynamic>>;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get authenticated user or redirect to login if not authenticated
    final user = context.authService.currentUser;
    
    if (user == null && !context.authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Use the authenticated user data
    if (user == null) {
      // If there's no authenticated user, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: AppColors.limeYellow,
      appBar: AppBar(
        title: Text(context.tr('my_profile')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.tr('error_loading_data'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(_error!),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadUserData,
                          child: Text(context.tr('retry')),
                        ),
                      ],
                    ),
                  )
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildUserInfo(context, user),
                          const SizedBox(height: 32),
                          _buildStatsSection(context, user),
                          const SizedBox(height: 32),
                          _buildProgressSection(context),
                          const SizedBox(height: 32),
                          _buildSubjectsSection(context),
                          const SizedBox(height: 32),
                          _buildAccountManagementSection(context),
                          const SizedBox(height: 32),
                          const LanguageSelector(),
                          const SizedBox(height: 32),
                          _buildActionButtons(context),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context, User user) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
            ).then((_) {
              setState(() {});
              _loadUserData(); // Reload data when returning from edit profile
            });
          },
          child: _buildProfilePicture(user),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                user.email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.darkGrey.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildBadge(context, '${context.tr('rank')} ${user.rank}'),
                  const SizedBox(width: 8),
                  _buildBadge(context, '${user.totalPoints} ${context.tr('points')}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, User user) {
    // Use real data from API or fallback to defaults
    final completedSessions = _performanceSummary['completed_sessions']?.toString() ?? '0';
    final averageScore = _performanceSummary['average_score'] != null 
        ? '${(_performanceSummary['average_score'] * 100).toInt()}%' 
        : '0%';
    
    // Find best and worst topic based on performance data
    String bestTopic = context.tr('no_data');
    String worstTopic = context.tr('no_data');
    
    if (_performanceByTopic.isNotEmpty) {
      _performanceByTopic.sort((a, b) => 
        (b['accuracy'] as num).compareTo(a['accuracy'] as num));
      
      if (_performanceByTopic.first['topic_name'] != null) {
        bestTopic = _performanceByTopic.first['topic_name'];
      }
      
      if (_performanceByTopic.last['topic_name'] != null) {
        worstTopic = _performanceByTopic.last['topic_name'];
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('statistics'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                context.tr('completed'),
                completedSessions,
                Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                context.tr('average'),
                averageScore,
                Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                context.tr('best_subject'),
                bestTopic,
                Icons.star_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                context.tr('to_improve'),
                worstTopic,
                Icons.thumb_up_alt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportsScreen()),
              );
            },
            icon: const Icon(Icons.analytics),
            label: Text(context.tr('view_detailed_reports')),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.darkBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    // Get performance trends from the analytics service
    final analyticsService = Provider.of<AnalyticsService>(context, listen: false);
    final trendsData = analyticsService.performanceTrends;
    
    // Create a progress chart using real data if available
    List<FlSpot> spots = [];
    List<String> dayLabels = [];
    
    if (trendsData.isNotEmpty) {
      // Sort trends by date
      final sortedTrends = [...trendsData];
      sortedTrends.sort((a, b) => a.date.compareTo(b.date));
      
      // Use the last 7 entries or all if fewer than 7
      final trendPoints = sortedTrends.length > 7 
          ? sortedTrends.sublist(sortedTrends.length - 7) 
          : sortedTrends;
      
      // Generate spots and labels from the trends data
      for (int i = 0; i < trendPoints.length; i++) {
        final trend = trendPoints[i];
        spots.add(FlSpot(i.toDouble(), trend.accuracy));
        dayLabels.add('${trend.date.day}/${trend.date.month}');
      }
    } else if (_performanceTrends.isNotEmpty) {
      // Fallback to previously fetched trends data
      final dateFormat = RegExp(r'\d{4}-\d{2}-\d{2}');
      
      // Sort trends by date
      final sortedTrends = List<Map<String, dynamic>>.from(_performanceTrends);
      sortedTrends.sort((a, b) {
        final aMatch = dateFormat.firstMatch(a['date'].toString());
        final bMatch = dateFormat.firstMatch(b['date'].toString());
        if (aMatch != null && bMatch != null) {
          return aMatch.group(0)!.compareTo(bMatch.group(0)!);
        }
        return 0;
      });
      
      // Use the last 7 entries or all if fewer than 7
      final trendPoints = sortedTrends.length > 7 
          ? sortedTrends.sublist(sortedTrends.length - 7) 
          : sortedTrends;
      
      // Generate spots and labels from the trends data
      for (int i = 0; i < trendPoints.length; i++) {
        final trend = trendPoints[i];
        final accuracy = (trend['accuracy'] as num?)?.toDouble() ?? 0.0;
        spots.add(FlSpot(i.toDouble(), accuracy));
        
        // Try to parse the date for the label
        try {
          final date = DateTime.parse(trend['date'].toString());
          dayLabels.add('${date.day}/${date.month}');
        } catch (e) {
          dayLabels.add('${i+1}');
        }
      }
    }
    
    // If no real data is available, reload from analytics service
    if (spots.isEmpty && _isLoading == false) {
      // Request a reload from the analytics service
      final authService = context.authService;
      if (authService.isAuthenticated && authService.accessToken != null) {
        // Reload trends data in the background
        analyticsService.fetchPerformanceTrends(authService.accessToken!);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('your_progress'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: trendsData.isEmpty && spots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.analytics_outlined, size: 48, color: AppColors.lightGrey),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('no_progress_data_yet'),
                        style: const TextStyle(color: AppColors.darkGrey),
                      ),
                    ],
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value % 20 == 0) {
                              return Text(
                                '${value.toInt()}%',
                                style: const TextStyle(
                                  color: AppColors.darkGrey,
                                  fontSize: 10,
                                ),
                              );
                            }
                            return Container();
                          },
                          reservedSize: 30,
                        ),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            const style = TextStyle(
                              color: AppColors.darkGrey,
                              fontSize: 10,
                            );
                            
                            final index = value.toInt();
                            if (index >= 0 && index < dayLabels.length) {
                              return Text(dayLabels[index], style: style);
                            }
                            return Container();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: spots.length - 1.0,
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppColors.darkBlue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.darkBlue.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSubjectsSection(BuildContext context) {
    // Get progress data from the analytics service
    final analyticsService = Provider.of<AnalyticsService>(context, listen: false);
    final topicProgressData = analyticsService.topicProgress;
    
    // Prepare the subject progress data, only including subjects with actual progress
    List<Map<String, dynamic>> subjects = [];
    
    if (topicProgressData.isNotEmpty) {
      // Use progress data from analytics service, filtering only subjects with progress
      subjects = topicProgressData
          .where((topic) => topic.questionsAttempted > 0)
          .map((topic) => {
            'name': topic.topicName,
            'progress': topic.proficiency / 100,
            'id': topic.topicId,
          })
          .toList();
    } else if (_progressByTopic.isNotEmpty) {
      // Fallback to previously fetched progress data, filtering only subjects with progress
      subjects = _progressByTopic
          .where((topic) {
            final questionsAttempted = (topic['questions_attempted'] as num?)?.toInt() ?? 0;
            final questionsMastered = (topic['questions_mastered'] as num?)?.toInt() ?? 0;
            return questionsAttempted > 0 || questionsMastered > 0;
          })
          .map((topic) => {
              'name': topic['topic_name'] ?? context.tr('unknown'),
              'progress': (topic['proficiency'] as num?)?.toDouble() ?? 
                         (topic['completion_percentage'] as num?)?.toDouble() ?? 0.0,
              'id': topic['topic_id']?.toString() ?? '',
            })
          .toList();
    } else if (_performanceByTopic.isNotEmpty) {
      // Fallback to performance data if no progress data is available
      subjects = _performanceByTopic
          .where((topic) {
            final questionsAnswered = (topic['questions_answered'] as num?)?.toInt() ?? 0;
            return questionsAnswered > 0;
          })
          .map((topic) => {
              'name': topic['topic_name'] ?? context.tr('unknown'),
              'progress': (topic['accuracy'] as num?)?.toDouble() ?? 0.0,
              'id': topic['topic_id']?.toString() ?? '',
            })
          .toList();
    }

    // Sort subjects by progress level for visualization
    subjects.sort((a, b) => (b['progress'] as double).compareTo(a['progress'] as double));

    // Top 5 and worst 5 subjects (if we have more than 10 subjects)
    List<Map<String, dynamic>> topSubjects = [];
    List<Map<String, dynamic>> worstSubjects = [];
    
    if (subjects.length > 10) {
      topSubjects = subjects.take(5).toList();
      // Get worst 5 subjects, but ensure they're not the same as top subjects
      worstSubjects = subjects.reversed.take(5).toList();
    } else if (subjects.length > 5) {
      // If we have 6-10 subjects, show the top 5 and whatever is left for worst
      topSubjects = subjects.take(5).toList();
      worstSubjects = subjects.skip(5).toList();
    } else {
      // If we have 5 or fewer subjects, just show all of them as top subjects
      topSubjects = subjects;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('subjects'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (subjects.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.school_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('no_subject_data'),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('start_practicing_to_see_subjects'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/exams');
                      },
                      icon: const Icon(Icons.search),
                      label: Text(context.tr('find_exams')),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (topSubjects.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                  child: Text(
                    context.tr('strengths'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ),
                ...topSubjects.map((subject) => _buildSubjectMeter(context, subject)),
                const SizedBox(height: 16),
              ],
              if (worstSubjects.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                  child: Text(
                    context.tr('areas_for_improvement'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ),
                ...worstSubjects.map((subject) => _buildSubjectMeter(context, subject)),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildSubjectMeter(
    BuildContext context,
    Map<String, dynamic> subject,
  ) {
    final String name = subject['name'] as String;
    final double progress = subject['progress'] as double;
    final String id = subject['id'] as String;
    final Color progressColor = _getProgressColor(progress);
    final IconData subjectIcon = _getSubjectIcon(name);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: progressColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              subjectIcon, 
              color: progressColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CustomPaint(
                      size: const Size(double.infinity, 8),
                      painter: MeterPainter(
                        progress: progress,
                        color: progressColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSubjectIcon(String subject) {
    // Map subject names to icons
    final subjectLower = subject.toLowerCase();
    
    if (subjectLower.contains('math') || subjectLower.contains('calc') || subjectLower.contains('algebra')) {
      return Icons.calculate_outlined;
    } else if (subjectLower.contains('science') || subjectLower.contains('physics') || subjectLower.contains('chem')) {
      return Icons.science_outlined;
    } else if (subjectLower.contains('hist')) {
      return Icons.history_edu_outlined;
    } else if (subjectLower.contains('eng') || subjectLower.contains('lang') || subjectLower.contains('lit')) {
      return Icons.menu_book_outlined;
    } else if (subjectLower.contains('geo') || subjectLower.contains('earth')) {
      return Icons.public_outlined;
    } else if (subjectLower.contains('comp') || subjectLower.contains('program') || subjectLower.contains('code')) {
      return Icons.computer_outlined;
    } else if (subjectLower.contains('art') || subjectLower.contains('music') || subjectLower.contains('draw')) {
      return Icons.palette_outlined;
    } else if (subjectLower.contains('econ') || subjectLower.contains('business') || subjectLower.contains('finance')) {
      return Icons.account_balance_outlined;
    } else {
      return Icons.school_outlined;
    }
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) {
      return AppColors.green;
    } else if (progress >= 0.6) {
      return AppColors.blue;
    } else if (progress >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Widget _buildAccountManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('account_management'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.subscriptions_outlined, color: AppColors.darkBlue),
                title: Text(context.tr('subscriptions')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionsScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: AppColors.darkBlue),
                title: Text(context.tr('payment_history')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PaymentHistoryScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.darkBlue),
                title: Text(context.tr('edit_profile')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  ).then((_) => setState(() {}));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        CustomButton(
          onPressed: () {
            context.authService.logout();
            Navigator.of(context).pushReplacementNamed('/login');
          },
          text: context.tr('logout'),
          type: ButtonType.outline,
          icon: Icons.logout,
          isFullWidth: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/help');
                },
                text: context.tr('get_support'),
                type: ButtonType.secondary,
                icon: Icons.support_agent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/affiliate');
                },
                text: 'Affiliate',
                type: ButtonType.secondary,
                icon: Icons.handshake_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/faq');
                },
                text: context.tr('faq'),
                type: ButtonType.secondary,
                icon: Icons.help_outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfilePicture(User user) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.darkBlue,
          child: ClipOval(
            child: SizedBox(
              width: 80,
              height: 80,
              child: user.avatar != null && user.avatar!.isNotEmpty
                  ? ImageUtils.loadImage(
                      imagePath: user.avatar!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: AppColors.darkBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for the meter/eclipse progress bar
class MeterPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  MeterPainter({required this.progress, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.fill;
      
    final Paint progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Calculate the width of the progress
    final double progressWidth = size.width * progress;
    
    // Draw background (already drawn by parent container)
    // canvas.drawRRect(RRect.fromRectAndRadius(
    //   Rect.fromLTWH(0, 0, size.width, size.height),
    //   Radius.circular(size.height / 2),
    // ), backgroundPaint);
    
    // Draw the progress with an elliptical end
    if (progressWidth > 0) {
      // For the main rectangle part
      final Rect progressRect = Rect.fromLTWH(0, 0, progressWidth, size.height);
      canvas.drawRect(progressRect, progressPaint);
      
      // For the elliptical end cap
      if (progressWidth < size.width) {
        final Rect endCapRect = Rect.fromLTWH(
          progressWidth - (size.height / 2), 
          0, 
          size.height, 
          size.height
        );
        canvas.drawArc(endCapRect, -math.pi/2, math.pi, true, progressPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
} 