import 'package:flutter/material.dart';
import '../../models/exam.dart';
import '../../models/detailed_exam.dart';
import '../../services/detailed_exam_service.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import 'practice_screen.dart';
import 'exam_session_screen.dart';
import 'exam_mode_selection_screen.dart';

class ExamDetailsScreen extends StatefulWidget {
  final String examId;

  const ExamDetailsScreen({
    Key? key,
    required this.examId,
  }) : super(key: key);

  @override
  State<ExamDetailsScreen> createState() => _ExamDetailsScreenState();
}

class _ExamDetailsScreenState extends State<ExamDetailsScreen> {
  final DetailedExamService _detailedExamService = DetailedExamService();
  DetailedExam? _exam;
  List<PricingPlan> _pricingPlans = [];
  bool _isLoading = true;
  String? _error;
  bool _hasActiveSubscription = false;

  @override
  void initState() {
    super.initState();
    _loadExamDetails();
  }

  Future<void> _loadExamDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch exam details
      final exam = await _detailedExamService.getExamDetails(widget.examId);
      
      if (exam != null) {
        setState(() {
          _exam = exam;
        });

        // Fetch pricing plans for this exam
        final plans = await _detailedExamService.getExamPricingPlans(widget.examId);
        setState(() {
          _pricingPlans = plans;
        });

        // Check if user has active subscription
        await _checkSubscriptionStatus();
      } else {
        setState(() {
          _error = _detailedExamService.error ?? 'Failed to load exam details';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading exam details: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      // Check user's subscriptions to see if they have access to this exam
      await context.userExamService.fetchUserExams();
      final userExams = context.userExamService.activeExams;
      
      setState(() {
        _hasActiveSubscription = userExams.any((userExam) => 
          userExam.exam.id == widget.examId && 
          userExam.status == 'ACTIVE'
        );
      });
    } catch (e) {
      // Subscription check failed, assume no subscription
      setState(() {
        _hasActiveSubscription = false;
      });
    }
  }

  Future<void> _purchaseExam(String planId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _detailedExamService.purchaseExam(widget.examId, planId);
      
      if (success) {
        // Show success message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Purchase Successful')),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the screen to show new subscription status
        await _loadExamDetails();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Purchase Failed', params: {'error': _detailedExamService.error ?? 'Unknown error'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Purchase Failed', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startPracticeSession() async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExamModeSelectionScreen(
            examId: widget.examId,
            examTitle: _exam?.title ?? 'Exam',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_to_navigate', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startTimedExam() async {
    // For backward compatibility, we can still support direct timed exam start
    // but route through mode selection for consistency
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExamModeSelectionScreen(
            examId: widget.examId,
            examTitle: _exam?.title ?? 'Exam',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_to_navigate', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          _exam?.title ?? context.tr('exam_details'),
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [
          LanguageSelector(isCompact: true),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.darkBlue),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('error_loading_exam'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadExamDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                foregroundColor: AppColors.white,
              ),
              child: Text(context.tr('try_again')),
            ),
          ],
        ),
      );
    }

    if (_exam == null) {
      return Center(
        child: Text(
          context.tr('exam_not_found'),
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.darkGrey,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExamHeader(),
          const SizedBox(height: 24),
          _buildExamDescription(),
          const SizedBox(height: 24),
          _buildExamStats(),
          const SizedBox(height: 24),
          if (_hasActiveSubscription) ...[
            _buildActionButtons(),
          ] else ...[
            _buildSubscriptionOptions(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildExamHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                             Expanded(
                 child: Text(
                   _exam!.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
              if (_hasActiveSubscription)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.tr('subscribed'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (_exam!.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _exam!.description,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.darkGrey,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExamDescription() {
    if (_exam!.description.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('about_this_exam'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _exam!.description,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.darkGrey,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildExamStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('exam_details'),
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
                icon: Icons.help_outline,
                label: context.tr('questions'),
                value: '${_exam!.questionCount ?? 'N/A'}',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.timer,
                label: context.tr('time_limit'),
                value: _formatTimeLimit(_exam!.timeLimit),
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.signal_cellular_alt,
                label: context.tr('difficulty'),
                value: _exam!.difficulty ?? 'Medium',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                             child: _buildStatCard(
                 icon: Icons.category,
                 label: context.tr('category'),
                 value: _exam!.subject ?? 'General',
                 color: Colors.purple,
               ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.darkGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('start_studying'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startPracticeSession,
            icon: const Icon(Icons.play_arrow),
            label: Text(context.tr('start_exam')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startPracticeSession,
                icon: const Icon(Icons.school),
                label: Text(context.tr('practice_mode')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkBlue,
                  side: const BorderSide(color: AppColors.darkBlue),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _startTimedExam,
                icon: const Icon(Icons.timer),
                label: Text(context.tr('real_exam')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkBlue,
                  side: const BorderSide(color: AppColors.darkBlue),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubscriptionOptions() {
    if (_pricingPlans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.lock, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            Text(
              context.tr('subscription_required'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('subscription_required_message'),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('subscription_plans'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        ..._pricingPlans.map((plan) => _buildPricingPlanCard(plan)),
      ],
    );
  }

  Widget _buildPricingPlanCard(PricingPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBlue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  plan.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
              Text(
                '${plan.currency} ${plan.price}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.billingCycle,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.darkGrey,
            ),
          ),
          if (plan.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              plan.description,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGrey,
                height: 1.4,
              ),
            ),
          ],
          if (plan.features.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...plan.features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.darkGrey,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _purchaseExam(plan.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(context.tr('subscribe_now')),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeLimit(int? timeLimitSeconds) {
    if (timeLimitSeconds == null || timeLimitSeconds == 0) {
      return context.tr('unlimited');
    }
    
    final hours = timeLimitSeconds ~/ 3600;
    final minutes = (timeLimitSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
} 