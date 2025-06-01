import 'package:flutter/material.dart';
import '../../models/user_exam.dart';
import '../../providers/app_providers.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/section_header.dart';
import '../../widgets/user_exam_card.dart';
import '../../theme.dart';
import '../exams/exams_screen.dart';
import '../../services/notification_service.dart';

class MyExamsScreen extends StatefulWidget {
  const MyExamsScreen({Key? key}) : super(key: key);

  @override
  State<MyExamsScreen> createState() => _MyExamsScreenState();
}

class _MyExamsScreenState extends State<MyExamsScreen> {
  late Future<void> _userExamsFuture;
  bool _isGridView = true; // Toggle between grid and list view

  @override
  void initState() {
    super.initState();
    _userExamsFuture = _loadData();
  }

  Future<void> _loadData() async {
    // Use a small delay to ensure the widget is fully built before making API calls
    await Future.delayed(Duration.zero);
    return context.userExamService.fetchUserExams();
  }

  void _navigateToExams() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExamsScreen()),
    );
  }

  void _openExam(UserExam userExam) {
    // Navigate to the exam session screen to start a new session
    Navigator.pushNamed(
      context,
      '/exams/${userExam.exam.id}/session/',
    );
    
    // Show notification
    context.notificationService.addNotification(
      context.tr('starting_exam_session'),
      type: NotificationType.info
    );
  }

  void _renewSubscription(UserExam userExam) {
    // Navigate to pricing screen for renewal
    Navigator.pushNamed(
      context,
      '/pricing',
      arguments: {
        'selectedExam': userExam.exam,
        'isRenewal': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const NotificationBell(),
                const SizedBox(width: 8),
                const LanguageSelector(isCompact: true),
              ],
            ),
          ),

          // Page title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('my_exams'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                  // Toggle view button
                  IconButton(
                    icon: Icon(
                      _isGridView ? Icons.list : Icons.grid_view,
                      color: AppColors.darkBlue,
                    ),
                    onPressed: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: FutureBuilder<void>(
              future: _userExamsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active exams section
                      _buildActiveExamsSection(),
                      
                      // Expired exams section (if any)
                      _buildExpiredExamsSection(),
                      
                      // Browse available exams section
                      _buildBrowseExamsSection(),
                      
                      const SizedBox(height: 32),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveExamsSection() {
    final activeExams = context.userExamService.activeExams;
    final isLoading = context.userExamService.isLoading;
    final error = context.userExamService.error;

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

    if (activeExams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.menu_book,
                size: 48,
                color: AppColors.mediumGrey,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('no_active_exams'),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.darkGrey,
                ),
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.tr('active_subscriptions'),
          hasDivider: false,
        ),
        _isGridView
            ? _buildExamsGrid(activeExams)
            : _buildExamsList(activeExams),
      ],
    );
  }

  Widget _buildExpiredExamsSection() {
    final expiredExams = context.userExamService.expiredExams;

    if (expiredExams.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.tr('expired_subscriptions'),
          hasDivider: true,
        ),
        _isGridView
            ? _buildExamsGrid(expiredExams)
            : _buildExamsList(expiredExams),
      ],
    );
  }

  Widget _buildBrowseExamsSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.limeYellow.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.new_releases,
                color: AppColors.darkBlue,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('discover_more_exams'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('discover_exams_description'),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToExams,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(context.tr('browse_available_exams')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsGrid(List<UserExam> exams) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate responsive grid parameters based on screen width
          final screenWidth = constraints.maxWidth;
          int crossAxisCount = 2;
          double childAspectRatio = 0.85;
          
          // Adjust for different screen sizes
          if (screenWidth < 600) {
            // Mobile phones - more height needed
            crossAxisCount = 2;
            childAspectRatio = 0.65; // Even more height for mobile to prevent overflow
          } else if (screenWidth < 900) {
            // Tablets
            crossAxisCount = 3;
            childAspectRatio = 0.8;
          } else {
            // Desktop
            crossAxisCount = 4;
            childAspectRatio = 0.85;
          }
          
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: exams.length,
            itemBuilder: (context, index) {
              final userExam = exams[index];
              return UserExamCard(
                userExam: userExam,
                onOpenTap: () => _openExam(userExam),
                onRenewTap: () => _renewSubscription(userExam),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildExamsList(List<UserExam> exams) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final userExam = exams[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: UserExamCard(
            userExam: userExam,
            onOpenTap: () => _openExam(userExam),
            onRenewTap: () => _renewSubscription(userExam),
          ),
        );
      },
    );
  }
} 