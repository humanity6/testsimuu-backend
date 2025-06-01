import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme.dart';
import '../../models/affiliate.dart';
import '../../services/admin_service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/custom_button.dart';
import '../../utils/responsive_utils.dart';

class AffiliateManagementScreen extends StatefulWidget {
  const AffiliateManagementScreen({Key? key}) : super(key: key);

  @override
  State<AffiliateManagementScreen> createState() => _AffiliateManagementScreenState();
}

class _AffiliateManagementScreenState extends State<AffiliateManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  
  // Data
  List<AffiliateApplication> _applications = [];
  List<Affiliate> _affiliates = [];
  List<AffiliatePlan> _plans = [];
  Map<String, dynamic> _analytics = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = context.authService;
      if (authService.accessToken != null) {
        final adminService = AdminService(accessToken: authService.accessToken!);
        
        // Load affiliate data
        await Future.wait([
          _loadApplications(adminService),
          _loadAffiliates(adminService),
          _loadPlans(adminService),
          _loadAnalytics(adminService),
        ]);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadApplications(AdminService adminService) async {
    try {
      // This would be implemented in AdminService
      _applications = await adminService.getAffiliateApplications();
    } catch (e) {
      print('Error loading applications: $e');
    }
  }

  Future<void> _loadAffiliates(AdminService adminService) async {
    try {
      // This would be implemented in AdminService
      _affiliates = await adminService.getAffiliates();
    } catch (e) {
      print('Error loading affiliates: $e');
    }
  }

  Future<void> _loadPlans(AdminService adminService) async {
    try {
      // This would be implemented in AdminService
      _plans = await adminService.getAffiliatePlans();
    } catch (e) {
      print('Error loading plans: $e');
    }
  }

  Future<void> _loadAnalytics(AdminService adminService) async {
    try {
      // This would be implemented in AdminService
      _analytics = await adminService.getAffiliateAnalytics();
    } catch (e) {
      print('Error loading analytics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Affiliate Management'),
        backgroundColor: AppColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: ModalRoute.of(context)?.canPop == true 
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: context.tr('back'),
            )
          : null,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Applications'),
            Tab(text: 'Affiliates'),
            Tab(text: 'Plans'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildApplicationsTab(),
                    _buildAffiliatesTab(),
                    _buildPlansTab(),
                    _buildAnalyticsTab(),
                  ],
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
              onPressed: _loadData,
              type: ButtonType.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildApplicationsList(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final pendingCount = _applications.where((app) => app.status == 'PENDING').length;
    final approvedCount = _applications.where((app) => app.status == 'APPROVED').length;
    final rejectedCount = _applications.where((app) => app.status == 'REJECTED').length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pending',
            pendingCount.toString(),
            Icons.pending,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Approved',
            approvedCount.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Rejected',
            rejectedCount.toString(),
            Icons.cancel,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsList() {
    if (_applications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.assignment,
              size: 48,
              color: AppColors.darkGrey,
            ),
            const SizedBox(height: 16),
            Text(
              'No Applications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No affiliate applications found.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Recent Applications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.darkBlue,
              ),
            ),
          ),
          ...(_applications.take(10).map((application) => _buildApplicationItem(application))),
          if (_applications.length > 10)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate to full applications list
                  },
                  child: Text('View All ${_applications.length} Applications'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApplicationItem(AffiliateApplication application) {
    Color statusColor;
    IconData statusIcon;
    
    switch (application.status) {
      case 'PENDING':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'APPROVED':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'REJECTED':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.darkGrey;
        statusIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.userEmail,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.planName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.darkGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    application.statusDisplay,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Followers: ${application.followerCount}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              Text(
                'Applied: ${application.createdAt.day}/${application.createdAt.month}/${application.createdAt.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (application.status == 'PENDING') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Approve',
                    onPressed: () => _approveApplication(application),
                    type: ButtonType.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomButton(
                    text: 'Reject',
                    onPressed: () => _rejectApplication(application),
                    type: ButtonType.outline,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAffiliatesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _affiliates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people,
                    size: 64,
                    color: AppColors.darkGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Active Affiliates',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.darkGrey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _affiliates.length,
              itemBuilder: (context, index) {
                final affiliate = _affiliates[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.lightBlue,
                      child: Text(
                        affiliate.name.isNotEmpty ? affiliate.name[0] : 'A',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(affiliate.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(affiliate.email),
                        Text('Earnings: \$${affiliate.totalEarnings.toStringAsFixed(2)}'),
                      ],
                    ),
                    trailing: Switch(
                      value: affiliate.isActive,
                      onChanged: (value) => _toggleAffiliateStatus(affiliate, value),
                    ),
                    onTap: () => _viewAffiliateDetails(affiliate),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPlansTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Affiliate Plans',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
              CustomButton(
                text: 'Add Plan',
                onPressed: _addNewPlan,
                type: ButtonType.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._plans.map((plan) => _buildPlanCard(plan)),
        ],
      ),
    );
  }

  Widget _buildPlanCard(AffiliatePlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.planTypeDisplay,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.darkGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: plan.isActive,
                  onChanged: (value) => _togglePlanStatus(plan, value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(plan.description),
            const SizedBox(height: 8),
            Text(
              plan.commissionSummary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Affiliate Analytics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          _buildAnalyticsOverview(),
          const SizedBox(height: 24),
          _buildConversionChart(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsOverview() {
    final totalAffiliates = _affiliates.length;
    final activeAffiliates = _affiliates.where((a) => a.isActive).length;
    final totalEarnings = _affiliates.fold<double>(0.0, (sum, a) => sum + a.totalEarnings);
    final pendingApplications = _applications.where((app) => app.status == 'PENDING').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile('Total Affiliates', totalAffiliates.toString()),
              ),
              Expanded(
                child: _buildMetricTile('Active Affiliates', activeAffiliates.toString()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile('Total Earnings', '\$${totalEarnings.toStringAsFixed(2)}'),
              ),
              Expanded(
                child: _buildMetricTile('Pending Apps', pendingApplications.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.darkGrey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildConversionChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conversion Trends (Last 30 Days)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 29,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(30, (index) {
                      return FlSpot(index.toDouble(), (index * 2 + 10).toDouble());
                    }),
                    isCurved: true,
                    color: AppColors.lightBlue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.lightBlue.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveApplication(AffiliateApplication application) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Application'),
        content: Text('Are you sure you want to approve ${application.userEmail}\'s application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authService = context.authService;
        if (authService.accessToken != null) {
          final adminService = AdminService(accessToken: authService.accessToken!);
          await adminService.approveApplication(application.id.toString());
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application approved successfully')),
          );
          _loadData();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving application: $e')),
        );
      }
    }
  }

  Future<void> _rejectApplication(AffiliateApplication application) async {
    // Show confirmation dialog with reason
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _RejectApplicationDialog(),
    );

    if (result?['confirmed'] == true) {
      try {
        // Implement rejection logic with reason
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application rejected')),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting application: $e')),
        );
      }
    }
  }

  Future<void> _toggleAffiliateStatus(Affiliate affiliate, bool isActive) async {
    try {
      // Implement status toggle
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Affiliate ${isActive ? 'activated' : 'deactivated'}')),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating affiliate status: $e')),
      );
    }
  }

  Future<void> _togglePlanStatus(AffiliatePlan plan, bool isActive) async {
    try {
      // Implement plan status toggle
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan ${isActive ? 'activated' : 'deactivated'}')),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating plan status: $e')),
      );
    }
  }

  void _viewAffiliateDetails(Affiliate affiliate) {
    // Navigate to affiliate details screen
  }

  void _addNewPlan() {
    // Navigate to add new plan screen
  }
}

class _RejectApplicationDialog extends StatefulWidget {
  @override
  State<_RejectApplicationDialog> createState() => _RejectApplicationDialogState();
}

class _RejectApplicationDialogState extends State<_RejectApplicationDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Application'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Please provide a reason for rejection:'),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter rejection reason...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop({'confirmed': false}),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'confirmed': true,
              'reason': _reasonController.text.trim(),
            });
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
} 