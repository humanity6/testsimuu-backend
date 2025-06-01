import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/exam.dart';
import '../../models/user.dart';
import '../../models/performance_data.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/language_selector.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Filter state
  Exam? _selectedExam;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String? _selectedTopic;
  String? _selectedDifficulty;
  bool _isLoading = false;
  bool _isDataLoaded = false;
  
  // User exams (will be loaded from service)
  List<Exam> _userExams = [];
  
  // Available topics (will be populated from the backend)
  List<String> _topics = [];
  
  // Available difficulties (will be populated from the backend)
  List<String> _difficulties = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Use a post-frame callback to load exams after the first build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserExams();
    });
  }

  Future<void> _loadUserExams() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // Load user exams from the service
      await context.userExamService.fetchUserExams();
      
      if (!mounted) return;
      setState(() {
        _userExams = context.userExamService.userExams
            .map((userExam) => userExam.exam)
            .toList();
        
        // Set initial exam selection if user has exams
        if (_userExams.isNotEmpty) {
          _selectedExam = _userExams.first;
          if (kDebugMode) {
            print('Selected first exam: ID=${_selectedExam?.id}, Title=${_selectedExam?.title}');
          }
        } else {
          if (kDebugMode) {
            print('No user exams found for reports');
          }
        }
        
        _isLoading = false;
      });
      
      // Load analytics data regardless of whether user has exams
      _loadAnalyticsData();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user exams: $e');
      }
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final initialDateRange = _dateRange;
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
    );

    if (newDateRange != null && mounted) {
      setState(() {
        _dateRange = newDateRange;
      });
      // Auto-apply filters when date range changes
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get authenticated user or redirect to login if not authenticated
    final user = context.authService.currentUser;
    
    // Redirect to login if not authenticated
    if (user == null && !context.authService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Use the authenticated user data
    if (user == null) {
      // If there's no authenticated user, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final userData = user;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('reports_analytics')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (kDebugMode) {
                print('Manual refresh triggered');
              }
              _loadAnalyticsData();
            },
            tooltip: 'Refresh Data',
          ),
          const LanguageSelector(isCompact: true),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.darkBlue,
          tabs: [
            Tab(text: context.tr('accuracy')),
            Tab(text: context.tr('strengths_weaknesses')),
            Tab(text: context.tr('progress')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildUserHeader(context, userData),
                _buildFilters(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAccuracyTab(),
                      _buildStrengthsWeaknessesTab(),
                      _buildProgressTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUserHeader(BuildContext context, User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.limeYellow,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.darkBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0] : '',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${context.tr('rank')}: ${user.rank} · ${user.totalPoints} ${context.tr('points')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.darkGrey.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppColors.limeYellow.withOpacity(0.1),
      child: Column(
        children: [
          // Compact filter bar - always visible
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Filter chips showing current selections
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Exam chip
                        if (_selectedExam != null)
                          _buildFilterChip(
                            label: _selectedExam!.title,
                            onDeleted: () {
                              setState(() {
                                _selectedExam = null;
                              });
                              _applyFilters();
                            },
                          ),
                        if (_selectedExam != null) const SizedBox(width: 8),
                        
                        // Date range chip
                        _buildFilterChip(
                          label: '${_dateRange.start.day}/${_dateRange.start.month} - ${_dateRange.end.day}/${_dateRange.end.month}',
                          onTap: _selectDateRange,
                          icon: Icons.calendar_today,
                        ),
                        const SizedBox(width: 8),
                        
                        // Topic chip
                        if (_selectedTopic != null)
                          _buildFilterChip(
                            label: _selectedTopic!,
                            onDeleted: () {
                              setState(() {
                                _selectedTopic = null;
                              });
                              _applyFilters();
                            },
                          ),
                        if (_selectedTopic != null) const SizedBox(width: 8),
                        
                        // Difficulty chip
                        if (_selectedDifficulty != null)
                          _buildFilterChip(
                            label: _selectedDifficulty!,
                            onDeleted: () {
                              setState(() {
                                _selectedDifficulty = null;
                              });
                              _applyFilters();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Filter button
                IconButton(
                  onPressed: () => _showFilterBottomSheet(context),
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filters',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.darkBlue.withOpacity(0.1),
                    foregroundColor: AppColors.darkBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    VoidCallback? onTap,
    VoidCallback? onDeleted,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.darkBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBlue.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.darkBlue),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.darkBlue,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDeleted,
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('filters'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Exam selection
                  Text(
                    context.tr('exam'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Exam>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedExam,
                    hint: Text(context.tr('select_exam')),
                    items: _userExams.map((exam) {
                      return DropdownMenuItem<Exam>(
                        value: exam,
                        child: Text(exam.title),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedExam = value;
                        _selectedTopic = null; // Reset topic when exam changes
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Topic selection
                  Text(
                    context.tr('topic'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedTopic,
                    hint: Text(context.tr('select_topic')),
                    items: _topics.map((topic) {
                      return DropdownMenuItem<String>(
                        value: topic,
                        child: Text(topic),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedTopic = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Difficulty selection
                  Text(
                    context.tr('difficulty'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    value: _selectedDifficulty,
                    hint: Text(context.tr('select_difficulty')),
                    items: _difficulties.map((difficulty) {
                      return DropdownMenuItem<String>(
                        value: difficulty,
                        child: Text(difficulty),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedDifficulty = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Date range
                  Text(
                    context.tr('date_range'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final newDateRange = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _dateRange,
                      );
                      if (newDateRange != null) {
                        setModalState(() {
                          _dateRange = newDateRange;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 12),
                          Text(
                            '${_dateRange.start.day}/${_dateRange.start.month}/${_dateRange.start.year} - ${_dateRange.end.day}/${_dateRange.end.month}/${_dateRange.end.year}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedExam = null;
                              _selectedTopic = null;
                              _selectedDifficulty = null;
                              _dateRange = DateTimeRange(
                                start: DateTime.now().subtract(const Duration(days: 30)),
                                end: DateTime.now(),
                              );
                            });
                          },
                          child: Text(context.tr('clear_all')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              // Update the main widget state
                            });
                            _applyFilters();
                            Navigator.pop(context);
                          },
                          child: Text(context.tr('apply_filters')),
                        ),
                      ),
                    ],
                  ),
                  
                  // Add bottom padding for safe area
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccuracyTab() {
    final topicPerformance = context.analyticsService.topicPerformance;
    final trends = context.analyticsService.performanceTrends;
    final performanceSummary = context.analyticsService.performanceSummary;
    final isLoading = context.analyticsService.isLoading;
    final error = context.analyticsService.error;
    
    if (kDebugMode) {
      print('Building Accuracy Tab - Topic Performance Count: ${topicPerformance.length}');
      print('Building Accuracy Tab - Performance Trends Count: ${trends.length}');
      print('Building Accuracy Tab - Is Loading: $isLoading');
      print('Building Accuracy Tab - Error: $error');
      print('Building Accuracy Tab - Performance Summary: $performanceSummary');
    }
    
    // Show error state if there's an error
    if (error != null && !isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading analytics data',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalyticsData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Summary Cards
          if (performanceSummary != null) ...[
            _buildSectionTitle(context.tr('overall_performance')),
            const SizedBox(height: 16),
            _buildPerformanceSummaryCards(performanceSummary),
            const SizedBox(height: 24),
          ] else if (!isLoading && _isDataLoaded) ...[
            _buildSectionTitle(context.tr('overall_performance')),
            const SizedBox(height: 16),
            _buildEmptyState('No performance summary available'),
            const SizedBox(height: 24),
          ],
          
          _buildSectionTitle(context.tr('accuracy_over_time')),
          const SizedBox(height: 16),
          if (isLoading && trends.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            _buildAccuracyChart(trends),
          const SizedBox(height: 24),
          
          _buildSectionTitle(context.tr('accuracy_by_topic')),
          const SizedBox(height: 16),
          if (isLoading && topicPerformance.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (topicPerformance.isEmpty)
            _buildEmptyState(context.tr('no_topic_performance_data'))
          else ...[
            // Sort topics by accuracy for better visualization
            ...(topicPerformance.toList()
                ..sort((a, b) => b.accuracy.compareTo(a.accuracy)))
                .take(10) // Show top 10 topics
                .map((topic) => _buildTopicAccuracyItem(
                    topic.topicName,
                    topic.accuracy,
                    questionsAnswered: topic.questionsAnswered,
                    averageTime: topic.formattedAverageTime,
                ))
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildStrengthsWeaknessesTab() {
    final topicPerformance = context.analyticsService.topicPerformance;
    final difficultyPerformance = context.analyticsService.difficultyPerformance;
    
    // Sort topics by accuracy for strengths and weaknesses
    final sortedTopics = List<TopicPerformance>.from(topicPerformance)
      ..sort((a, b) => b.accuracy.compareTo(a.accuracy));
    
    final strengths = sortedTopics.take(5).toList();
    final weaknesses = sortedTopics.reversed.take(5).toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Analysis Summary
          _buildPerformanceAnalysis(topicPerformance, difficultyPerformance),
          const SizedBox(height: 24),
          
          _buildSectionTitle(context.tr('top_strengths')),
          const SizedBox(height: 16),
          if (strengths.isEmpty)
            _buildEmptyState(context.tr('no_strengths_data'))
          else
            ...strengths.map(
              (topic) => _buildTopicAccuracyItem(
                topic.topicName,
                topic.accuracy,
                isStrength: true,
                questionsAnswered: topic.questionsAnswered,
                averageTime: topic.formattedAverageTime,
              ),
            ),
          const SizedBox(height: 24),
          _buildSectionTitle(context.tr('areas_for_improvement')),
          const SizedBox(height: 16),
          if (weaknesses.isEmpty)
            _buildEmptyState(context.tr('no_weaknesses_data'))
          else
            ...weaknesses.map(
              (topic) => _buildTopicAccuracyItem(
                topic.topicName,
                topic.accuracy,
                isStrength: false,
                questionsAnswered: topic.questionsAnswered,
                averageTime: topic.formattedAverageTime,
              ),
            ),
          const SizedBox(height: 24),
          _buildSectionTitle(context.tr('performance_by_difficulty')),
          const SizedBox(height: 16),
          _buildDifficultyChart(difficultyPerformance),
          const SizedBox(height: 16),
          if (difficultyPerformance.isNotEmpty)
            _buildDifficultyBreakdown(difficultyPerformance),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    final trends = context.analyticsService.performanceTrends;
    final sessions = context.analyticsService.studySessions;
    final topicProgress = context.analyticsService.topicProgress;
    final performanceSummary = context.analyticsService.performanceSummary;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Overview Cards
          if (performanceSummary != null) ...[
            _buildSectionTitle(context.tr('study_overview')),
            const SizedBox(height: 16),
            _buildStudyOverviewCards(performanceSummary),
            const SizedBox(height: 24),
          ],
          
          _buildSectionTitle(context.tr('progress_trend')),
          const SizedBox(height: 16),
          _buildProgressChart(trends),
          const SizedBox(height: 24),
          
          // Topic Progress
          _buildSectionTitle(context.tr('topic_progress')),
          const SizedBox(height: 16),
          if (topicProgress.isEmpty)
            _buildEmptyState(context.tr('no_topic_progress_data'))
          else
            _buildTopicProgressList(topicProgress),
          const SizedBox(height: 24),
          
          _buildSectionTitle(context.tr('recent_activity')),
          const SizedBox(height: 16),
          if (sessions.isEmpty)
            _buildEmptyState(context.tr('no_study_sessions'))
          else
            ...sessions.take(5).map((session) => _buildSessionItem(session)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.darkBlue,
      ),
    );
  }

  Widget _buildAccuracyChart(List<PerformanceTrend> trends) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: trends.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timeline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('no_performance_trend_data'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < trends.length) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              trends[index].formattedDate,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                minX: 0,
                maxX: trends.length - 1.0,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: trends.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.accuracy);
                    }).toList(),
                    isCurved: true,
                    color: AppColors.darkBlue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: AppColors.darkBlue,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.darkBlue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTopicAccuracyItem(String topic, double accuracy, {bool? isStrength, int? questionsAnswered, String? averageTime}) {
    final color = isStrength == null
        ? _getProgressColor(_safeDouble(accuracy) / 100)
        : isStrength
            ? Colors.green
            : Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    topic,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_safeToInt(accuracy)}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _safeProgress(accuracy),
              color: color,
              backgroundColor: Colors.grey.withOpacity(0.2),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (questionsAnswered != null)
                  Text(
                    '${questionsAnswered} ${context.tr('questions')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                if (averageTime != null)
                  Text(
                    '${context.tr('avg_time')}: $averageTime',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            if (isStrength != null) ...[
              const SizedBox(height: 8),
              Text(
                isStrength
                    ? 'You\'re performing well in this area!'
                    : 'This area needs more focus and practice.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChart(List<DifficultyPerformance> difficultyData) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: difficultyData.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('no_difficulty_performance_data'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                minY: 0,
                groupsSpace: 12,
                barTouchData: BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < difficultyData.length) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              difficultyData[index].difficulty,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${_safeToInt(value)}%',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                barGroups: difficultyData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final difficulty = entry.value;
                  
                  // Get appropriate color based on difficulty
                  Color barColor;
                  switch (difficulty.difficulty.toLowerCase()) {
                    case 'easy':
                      barColor = Colors.green;
                      break;
                    case 'medium':
                      barColor = Colors.blue;
                      break;
                    case 'hard':
                      barColor = Colors.orange;
                      break;
                    case 'very hard':
                      barColor = Colors.red;
                      break;
                    default:
                      barColor = Colors.grey;
                  }
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: difficulty.accuracy,
                        color: barColor,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildProgressChart(List<PerformanceTrend> trends) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: trends.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timeline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('no_progress_data'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 200,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < trends.length) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              trends[index].formattedDate,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 200,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                minX: 0,
                maxX: trends.length - 1.0,
                minY: 0,
                maxY: trends.isEmpty ? 100.0 : trends.fold<double>(0.0, (prev, trend) => 
                    trend.questionsAnswered > prev ? trend.questionsAnswered.toDouble() : prev),
                lineBarsData: [
                  LineChartBarData(
                    spots: trends.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.questionsAnswered.toDouble());
                    }).toList(),
                    isCurved: true,
                    color: AppColors.darkBlue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: AppColors.darkBlue,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.darkBlue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSessionItem(StudySession session) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.limeYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(
                  Icons.assignment_turned_in,
                  color: AppColors.darkBlue,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.topicsStudied.isNotEmpty
                        ? session.topicsStudied.join(', ')
                        : (_selectedExam?.title ?? context.tr('practice_session')),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.formattedDate} • ${session.questionsAnswered} ${context.tr('questions')}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getProgressColor(_safeDouble(session.accuracy) / 100).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_safeToInt(session.accuracy)}%',
                style: TextStyle(
                  color: _getProgressColor(_safeDouble(session.accuracy) / 100),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.bar_chart, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSummaryCards(PerformanceSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: context.tr('total_questions'),
            value: summary.totalQuestions.toString(),
            icon: Icons.quiz,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: context.tr('accuracy'),
            value: '${_safeToInt(summary.accuracy)}%',
            icon: Icons.check_circle,
            color: _getProgressColor(_safeDouble(summary.accuracy) / 100),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: context.tr('avg_time'),
            value: _formatTime(summary.averageTimePerQuestion),
            icon: Icons.timer,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    if (seconds < 60) {
      return '${_safeToInt(seconds)}s';
    } else {
      final minutes = (seconds / 60).floor();
      final remainingSeconds = (seconds % 60).round();
      return '${minutes}m ${remainingSeconds}s';
    }
  }

  Widget _buildPerformanceAnalysis(List<TopicPerformance> topicPerformance, List<DifficultyPerformance> difficultyPerformance) {
    if (topicPerformance.isEmpty && difficultyPerformance.isEmpty) {
      return _buildEmptyState(context.tr('no_performance_data'));
    }

    // Calculate overall stats
    double avgAccuracy = 0;
    int totalQuestions = 0;
    if (topicPerformance.isNotEmpty) {
      final totalAccuracy = topicPerformance.fold(0.0, (sum, topic) => sum + _safeDouble(topic.accuracy));
      avgAccuracy = totalAccuracy / topicPerformance.length;
      totalQuestions = topicPerformance.fold(0, (sum, topic) => sum + topic.questionsAnswered);
    }

    String performanceLevel = '';
    Color levelColor = Colors.grey;
    if (avgAccuracy >= 80) {
      performanceLevel = context.tr('excellent');
      levelColor = Colors.green;
    } else if (avgAccuracy >= 70) {
      performanceLevel = context.tr('good');
      levelColor = Colors.blue;
    } else if (avgAccuracy >= 60) {
      performanceLevel = context.tr('average');
      levelColor = Colors.orange;
    } else {
      performanceLevel = context.tr('needs_improvement');
      levelColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: levelColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: levelColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: levelColor),
              const SizedBox(width: 8),
              Text(
                context.tr('performance_analysis'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: levelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${context.tr('overall_performance_level')}: $performanceLevel (${_safeToInt(avgAccuracy)}%)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '${context.tr('total_questions_attempted')}: $totalQuestions',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            '${context.tr('topics_covered')}: ${topicPerformance.length}',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyBreakdown(List<DifficultyPerformance> difficultyPerformance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context.tr('difficulty_breakdown')),
        const SizedBox(height: 12),
        ...difficultyPerformance.map((difficulty) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      difficulty.difficulty,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${difficulty.questionsAnswered} ${context.tr('questions')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _safeProgress(difficulty.accuracy),
                      color: _getDifficultyColor(difficulty.difficulty),
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_safeToInt(difficulty.accuracy)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getDifficultyColor(difficulty.difficulty),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.blue;
      case 'hard':
        return Colors.orange;
      case 'very hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStudyOverviewCards(PerformanceSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: context.tr('total_time'),
            value: _formatStudyTime(summary.totalTimeSpentSeconds),
            icon: Icons.access_time,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: context.tr('points_earned'),
            value: _safeToInt(summary.totalPointsEarned).toString(),
            icon: Icons.star,
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: context.tr('completion_rate'),
            value: '${_safePercentage(summary.totalPointsEarned, summary.totalPointsPossible)}%',
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  String _formatStudyTime(int totalSeconds) {
    if (totalSeconds < 3600) {
      final minutes = (totalSeconds / 60).floor();
      return '${minutes}m';
    } else {
      final hours = (totalSeconds / 3600).floor();
      final minutes = ((totalSeconds % 3600) / 60).floor();
      return '${hours}h ${minutes}m';
    }
  }

  Widget _buildTopicProgressList(List<TopicProgress> topicProgress) {
    return Column(
      children: topicProgress.take(8).map((progress) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    progress.topicName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_safeToInt(progress.completionPercentage)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getProgressColor(_safeDouble(progress.completionPercentage) / 100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _safeProgress(progress.completionPercentage),
              color: _getProgressColor(_safeDouble(progress.completionPercentage) / 100),
              backgroundColor: Colors.grey.withOpacity(0.2),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.questionsAttempted}/${progress.totalQuestionsInTopic} ${context.tr('questions')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${context.tr('completion')}: ${_safeToInt(progress.completionPercentage)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      )).toList(),
    );
  }

  Color _getProgressColor(double progress) {
    // Handle NaN and infinity cases
    if (progress.isNaN || progress.isInfinite || progress < 0) {
      return Colors.grey;
    }
    
    if (progress >= 0.7) {
      return Colors.green;
    } else if (progress >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Future<void> _loadAnalyticsData() async {
    if (kDebugMode) {
      print('_loadAnalyticsData called - Auth status: ${context.authService.isAuthenticated}');
    }
    
    if (!context.authService.isAuthenticated) {
      if (kDebugMode) {
        print('User not authenticated, skipping analytics data load');
      }
      return;
    }
    
    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      _isLoading = true;
    });
    
    try {
      final token = context.authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not available');
      }
      
      if (kDebugMode) {
        print('Loading analytics data with token: ${token.substring(0, 20)}...');
        print('Selected exam: ${_selectedExam?.title ?? "None"}');
        print('Selected exam ID: ${_selectedExam?.id ?? "None"}');
        print('Date range: ${_dateRange.start} to ${_dateRange.end}');
      }
      
      // Use the new comprehensive analytics loading method
      await context.analyticsService.fetchAllAnalyticsData(
        token,
        examId: _selectedExam?.id,
        dateRange: _dateRange,
      );
      
      if (kDebugMode) {
        print('Analytics data loading completed');
        print('Performance summary: ${context.analyticsService.performanceSummary != null ? "✓" : "✗"}');
        print('Topic performance count: ${context.analyticsService.topicPerformance.length}');
        print('Difficulty performance count: ${context.analyticsService.difficultyPerformance.length}');
        print('Performance trends count: ${context.analyticsService.performanceTrends.length}');
        print('Topic progress count: ${context.analyticsService.topicProgress.length}');
        print('Study sessions count: ${context.analyticsService.studySessions.length}');
        
        // Print sample data if available
        if (context.analyticsService.topicPerformance.isNotEmpty) {
          final first = context.analyticsService.topicPerformance.first;
          print('First topic: ${first.topicName} - ${first.accuracy}% accuracy');
        }
        if (context.analyticsService.performanceTrends.isNotEmpty) {
          final first = context.analyticsService.performanceTrends.first;
          print('First trend: ${first.date} - ${first.accuracy}% accuracy');
        }
        if (context.analyticsService.performanceSummary != null) {
          final summary = context.analyticsService.performanceSummary!;
          print('Summary: ${summary.totalQuestions} questions, ${summary.accuracy}% accuracy');
        }
      }
      
      // Extract topics and difficulties for filters
      if (context.analyticsService.topicPerformance.isNotEmpty) {
        _topics = context.analyticsService.topicPerformance
            .map((topic) => topic.topicName)
            .toSet()
            .toList();
      }
      
      if (context.analyticsService.difficultyPerformance.isNotEmpty) {
        _difficulties = context.analyticsService.difficultyPerformance
            .map((diff) => diff.difficulty)
            .toSet()
            .toList();
      }
      
      // Set isDataLoaded flag to true
      if (mounted) {
        setState(() {
          _isDataLoaded = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading analytics data: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load analytics data: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadAnalyticsData,
            ),
          ),
        );
      }
    }
  }
  

  
  // Method to apply filters and reload data
  Future<void> _applyFilters() async {
    if (!context.authService.isAuthenticated) return;
    
    final token = context.authService.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('authentication_required'))),
      );
      return;
    }
    
    if (kDebugMode) {
      print('Applying filters - Exam: ${_selectedExam?.title}, Exam ID: ${_selectedExam?.id}, Date Range: ${_dateRange.start} to ${_dateRange.end}');
    }
    
    // Use the comprehensive analytics loading method with filters
    await context.analyticsService.fetchAllAnalyticsData(
      token,
      examId: _selectedExam?.id,
      dateRange: _dateRange,
    );
    
    // Update UI
    if (mounted) {
      setState(() {
        // Refresh the UI with new data
      });
    }
  }

  // Helper functions to safely handle NaN values
  int _safeToInt(num value) {
    if (value.isNaN || value.isInfinite) {
      return 0;
    }
    return value.toInt();
  }

  int _safePercentage(num numerator, num denominator) {
    if (denominator == 0 || numerator.isNaN || denominator.isNaN) {
      return 0;
    }
    final percentage = (numerator / denominator) * 100;
    if (percentage.isNaN || percentage.isInfinite) {
      return 0;
    }
    return percentage.toInt();
  }

  double _safeDouble(num value) {
    if (value.isNaN || value.isInfinite) {
      return 0.0;
    }
    return value.toDouble();
  }

  double _safeProgress(num value) {
    if (value.isNaN || value.isInfinite || value < 0) {
      return 0.0;
    }
    // Clamp between 0 and 1 for progress indicators
    return (value / 100).clamp(0.0, 1.0).toDouble();
  }
} 