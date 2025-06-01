import 'package:flutter/material.dart';
import '../../models/affiliate.dart';
import '../../services/affiliate_service.dart';
import '../../providers/app_providers.dart';
import '../../theme.dart';
import '../../widgets/custom_button.dart';
import 'affiliate_application_screen.dart';
import 'affiliate_dashboard_screen.dart';

class AffiliateScreen extends StatefulWidget {
  const AffiliateScreen({Key? key}) : super(key: key);

  @override
  State<AffiliateScreen> createState() => _AffiliateScreenState();
}

class _AffiliateScreenState extends State<AffiliateScreen> {
  final AffiliateService _affiliateService = AffiliateService();
  bool _isLoading = true;
  String? _error;
  
  // User status data
  bool _isAffiliate = false;
  bool _hasPendingApplication = false;
  bool _canApply = false;
  
  // Data objects
  Affiliate? _affiliate;
  AffiliateApplication? _pendingApplication;
  List<AffiliatePlan> _availablePlans = [];

  @override
  void initState() {
    super.initState();
    _loadAffiliateStatus();
  }

  Future<void> _loadAffiliateStatus() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = context.authService;
      if (authService.isAuthenticated && authService.accessToken != null) {
        // Get user affiliate status and opportunities
        final results = await Future.wait([
          _affiliateService.getUserAffiliateStatus(authService.accessToken!),
          _affiliateService.getAffiliateOpportunities(authService.accessToken!),
        ]);

        final statusData = results[0] as Map<String, dynamic>;
        final opportunitiesData = results[1] as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            // Safely handle boolean values that might be null
            _isAffiliate = statusData['is_affiliate'] ?? false;
            _hasPendingApplication = statusData['has_pending_application'] ?? false;
            _canApply = opportunitiesData['can_apply'] ?? false;
            
            if (_isAffiliate && statusData['affiliate_data'] != null) {
              _affiliate = Affiliate.fromJson(statusData['affiliate_data']);
            }
            
            if (_hasPendingApplication && statusData['application'] != null) {
              _pendingApplication = AffiliateApplication.fromJson(statusData['application']);
            }
            
            // Parse available plans
            final plansData = opportunitiesData['available_plans'] as List<dynamic>? ?? [];
            _availablePlans = plansData.map((json) => AffiliatePlan.fromJson(json)).toList();
            
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
    return Scaffold(
      backgroundColor: AppColors.limeYellow,
      appBar: AppBar(
        title: const Text('Affiliate Program'),
        backgroundColor: AppColors.limeYellow,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAffiliateStatus,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildContent(),
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load affiliate data',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Retry',
              onPressed: _loadAffiliateStatus,
              type: ButtonType.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isAffiliate && _affiliate != null) {
      // User is already an affiliate - navigate to dashboard instead of embedding it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AffiliateDashboardScreen(affiliate: _affiliate!),
          ),
        );
      });
      
      // Show a loading indicator temporarily while navigation happens
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_hasPendingApplication && _pendingApplication != null) {
      // User has pending application - show status
      return _buildPendingApplicationStatus();
    } else if (_canApply) {
      // User can apply - show application form or opportunities
      return _buildApplicationOpportunities();
    } else {
      // User cannot apply (possibly already has rejected application)
      return _buildNotEligible();
    }
  }

  Widget _buildPendingApplicationStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          'Application Pending',
          'Your affiliate application is currently being reviewed.',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pending, color: Colors.orange[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Application Status: ${_pendingApplication!.statusDisplay}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Applied for: ${_pendingApplication!.planName}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Application Date: ${_pendingApplication!.createdAt.day}/${_pendingApplication!.createdAt.month}/${_pendingApplication!.createdAt.year}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.darkGrey,
                ),
              ),
              if (_pendingApplication!.adminNotes?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Admin Notes:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pendingApplication!.adminNotes!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'What happens next?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          Icons.schedule,
          'Review Process',
          'Our team will review your application within 2-3 business days.',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          Icons.email,
          'Notification',
          'You\'ll receive an email notification once your application is reviewed.',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          Icons.dashboard,
          'Next Steps',
          'If approved, you\'ll gain access to your affiliate dashboard and tracking tools.',
        ),
      ],
    );
  }

  Widget _buildApplicationOpportunities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          'Join Our Affiliate Program',
          'Earn money by promoting our exam preparation app to your audience.',
        ),
        const SizedBox(height: 24),
        _buildBenefitsSection(),
        const SizedBox(height: 24),
        _buildAvailablePlans(),
        const SizedBox(height: 32),
        CustomButton(
          text: 'Apply Now',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AffiliateApplicationScreen(
                  availablePlans: _availablePlans,
                ),
              ),
            ).then((_) {
              // Refresh status when returning from application
              _loadAffiliateStatus();
            });
          },
          type: ButtonType.primary,
          icon: Icons.send,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildNotEligible() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          'Affiliate Program',
          'Join our affiliate program to earn commissions.',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Column(
            children: [
              Icon(Icons.info_outline, color: Colors.red[600], size: 48),
              const SizedBox(height: 16),
              Text(
                'Application Not Available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You are currently not eligible to apply for the affiliate program. This could be due to a previous application or account restrictions.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildBenefitsSection(),
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.darkGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why Join Our Affiliate Program?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          Icons.euro,
          'Earn Commission',
          'Get paid for every successful referral and subscription you generate.',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          Icons.analytics,
          'Track Performance',
          'Access detailed analytics and track your clicks, conversions, and earnings.',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          Icons.support_agent,
          'Dedicated Support',
          'Get dedicated support from our affiliate team to maximize your earnings.',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          Icons.payment,
          'Regular Payouts',
          'Receive monthly payments directly to your preferred payment method.',
        ),
      ],
    );
  }

  Widget _buildAvailablePlans() {
    if (_availablePlans.isEmpty) return Container();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Plans',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        ..._availablePlans.map((plan) => _buildPlanCard(plan)).toList(),
      ],
    );
  }

  Widget _buildPlanCard(AffiliatePlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
              if (plan.isAutoApproval)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Auto-Approval',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Commission: ${plan.commissionSummary}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          if (plan.minimumFollowers > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Minimum followers: ${plan.minimumFollowers}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.darkGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.darkBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.darkBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.darkGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 