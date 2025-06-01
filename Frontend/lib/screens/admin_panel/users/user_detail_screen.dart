import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../models/user.dart';
import '../../../widgets/language_selector.dart';
import '../../../widgets/user_avatar_widget.dart';
import '../../../providers/app_providers.dart';
import '../../../services/admin_service.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;

  const UserDetailScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isLoading = true;
  User? _user;
  Map<String, dynamic> _subscriptions = {};
  Map<String, dynamic> _performanceData = {};
  String? _error;
  late AdminService _adminService;

  @override
  void initState() {
    super.initState();
    _initializeAdminService();
  }

  void _initializeAdminService() {
    final authService = context.authService;
    final user = authService.currentUser;
    final accessToken = authService.accessToken;
    
    if (user != null && accessToken != null && user.isStaff) {
      _adminService = AdminService(accessToken: accessToken);
      _loadUserData();
    } else {
      // Handle case where user is not authenticated or not admin
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load user details
      final user = await _adminService.getUserDetails(widget.userId);

      // Load user's subscriptions
      final subscriptions = await _adminService.getUserSubscriptions(widget.userId);

      // Load user's performance data
      final performanceData = await _adminService.getUserPerformance(widget.userId);

      setState(() {
        _user = user;
        _subscriptions = {
          'active': subscriptions.where((s) => s.status == 'Active').toList(),
          'expired': subscriptions.where((s) => s.status == 'Expired').toList(),
        };
        _performanceData = performanceData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load user data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is admin, redirect if not
    final currentUser = context.authService.currentUser;
    
    if (currentUser == null || !currentUser.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? context.tr('user_details') : _user!.name),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: context.tr('Back to users'),
        ),
        leadingWidth: 56,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('refresh'),
            onPressed: _loadUserData,
          ),
          const LanguageSelector(isCompact: true),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        child: Text(context.tr('retry')),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserInfoCard(),
                      const SizedBox(height: 24),
                      _buildSubscriptionsCard(),
                      const SizedBox(height: 24),
                      _buildPerformanceSummary(),
                      const SizedBox(height: 24),
                      _buildAdminActions(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('user_information'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  avatarUrl: _user!.avatar,
                  size: 80,
                  isAdmin: _user!.isAdmin,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(context.tr('name'), _user!.name),
                      const SizedBox(height: 8),
                      _buildInfoRow(context.tr('email'), _user!.email),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context.tr('role'),
                        _user!.isAdmin ? context.tr('admin') : context.tr('user'),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(context.tr('rank'), _user!.rank.toString()),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context.tr('total_points'),
                        _user!.totalPoints.toString(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionsCard() {
    final activeSubscriptions = _subscriptions['active'] as List;
    final expiredSubscriptions = _subscriptions['expired'] as List;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('subscriptions'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (activeSubscriptions.isEmpty && expiredSubscriptions.isEmpty)
              Center(
                child: Text(
                  context.tr('no_subscriptions'),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              )
            else ...[
              if (activeSubscriptions.isNotEmpty) ...[
                Text(
                  context.tr('active_subscriptions'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...activeSubscriptions.map((sub) => _buildSubscriptionItem(sub)),
                const SizedBox(height: 16),
              ],
              if (expiredSubscriptions.isNotEmpty) ...[
                Text(
                  context.tr('expired_subscriptions'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...expiredSubscriptions.map((sub) => _buildSubscriptionItem(sub)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionItem(dynamic subscription) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(subscription.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.tr('start_date')}: ${subscription.startDate}'),
            Text('${context.tr('end_date')}: ${subscription.endDate}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: subscription.status == 'Active' ? AppColors.green : Colors.grey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            subscription.status,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceSummary() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('performance_summary'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context.tr('completed_quizzes'),
                    _performanceData['completedQuizzes'].toString(),
                    Icons.check_circle,
                    AppColors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context.tr('average_score'),
                    '${_performanceData['averageScore']}%',
                    Icons.analytics,
                    AppColors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('admin_actions'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _resetUserPassword();
                    },
                    icon: const Icon(Icons.lock_reset),
                    label: Text(context.tr('reset_password')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _suspendUser();
                    },
                    icon: Icon(_user!.isActive ? Icons.block : Icons.check_circle),
                    label: Text(_user!.isActive ? 'Suspend User' : 'Unsuspend User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _user!.isActive ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetUserPassword() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Password Reset'),
        content: const Text('Are you sure you want to reset this user\'s password? A password reset email will be sent to their email address.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await _adminService.resetUserPassword(widget.userId);
      
      // Hide loading indicator
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Password reset email sent successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Hide loading indicator
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset password: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _suspendUser() async {
    final action = _user!.isActive ? 'suspend' : 'unsuspend';
    final actionTitle = _user!.isActive ? 'Suspend User' : 'Unsuspend User';
    final actionMessage = _user!.isActive 
        ? 'Are you sure you want to suspend this user? They will not be able to access their account.'
        : 'Are you sure you want to unsuspend this user? They will regain access to their account.';
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actionTitle),
        content: Text(actionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _user!.isActive ? Colors.red : Colors.green,
            ),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await _adminService.suspendUser(widget.userId);
      
      // Hide loading indicator
      Navigator.of(context).pop();

      // Update user status locally
      setState(() {
        _user = _user!.copyWith(isActive: result['is_active']);
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'User status updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Return true to indicate user was updated
      Navigator.of(context).pop(true);
    } catch (e) {
      // Hide loading indicator
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update user status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 