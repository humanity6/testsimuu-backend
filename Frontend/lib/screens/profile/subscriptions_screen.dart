import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../services/payment_service.dart';
import '../../models/user_subscription.dart';
import 'payment_history_screen.dart';
import '../../providers/auth_provider.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _showActive = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isAuthenticated && authProvider.token != null) {
      final paymentService = context.read<PaymentService>();
      await paymentService.getUserSubscriptions(authProvider.token!);
    }
  }

  List<UserSubscription> _getFilteredSubscriptions(List<UserSubscription> subscriptions) {
    if (_showActive) {
      return subscriptions.where((sub) => sub.status == 'Active').toList();
    } else {
      return subscriptions.where((sub) => sub.status == 'Expired' || sub.status == 'Canceled').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('my_subscriptions')),
        actions: const [
          LanguageSelector(isCompact: true),
        ],
      ),
      body: Consumer<PaymentService>(
        builder: (context, paymentService, child) {
          if (paymentService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final filteredSubscriptions = _getFilteredSubscriptions(paymentService.subscriptions);
          
          return Column(
            children: [
              _buildSegmentedControl(),
              Expanded(
                child: filteredSubscriptions.isEmpty
                    ? _buildEmptyState()
                    : _buildSubscriptionsList(filteredSubscriptions),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _showActive = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _showActive ? AppColors.darkBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.tr('active'),
                  style: TextStyle(
                    color: _showActive ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _showActive = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !_showActive ? AppColors.darkBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.tr('past'),
                  style: TextStyle(
                    color: !_showActive ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showActive ? Icons.subscriptions_outlined : Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _showActive
                ? context.tr('no_active_subscriptions')
                : context.tr('no_past_subscriptions'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showActive
                ? context.tr('subscribe_to_get_started')
                : context.tr('check_active_tab'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          if (_showActive)
            ElevatedButton(
              onPressed: () {
                // Navigate to pricing screen
              },
              child: Text(context.tr('browse_plans')),
            ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsList(List<UserSubscription> subscriptions) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: subscriptions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final subscription = subscriptions[index];
        return _buildSubscriptionCard(subscription);
      },
    );
  }

  Widget _buildSubscriptionCard(UserSubscription subscription) {
    final daysRemaining = subscription.endDate?.difference(DateTime.now()).inDays ?? 0;
    final isExpiringSoon = daysRemaining <= 7 && daysRemaining > 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.examName ?? 'Unknown Exam',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subscription.planName,
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (subscription.status == 'Active' && isExpiringSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.tr('exam_detail_subscription_expiring_soon'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow(
              context.tr('start_date'),
              '${subscription.startDate.day}/${subscription.startDate.month}/${subscription.startDate.year}',
            ),
            if (subscription.status == 'Active' && subscription.autoRenew)
              _buildDetailRow(
                context.tr('renewal_date'),
                subscription.endDate != null 
                  ? '${subscription.endDate!.day}/${subscription.endDate!.month}/${subscription.endDate!.year}'
                  : 'Not available',
              )
            else
              _buildDetailRow(
                context.tr('end_date'),
                subscription.endDate != null 
                  ? '${subscription.endDate!.day}/${subscription.endDate!.month}/${subscription.endDate!.year}'
                  : 'Not available',
              ),
            _buildDetailRow(
              context.tr('price_paid'),
              '\$${subscription.pricePaid.toStringAsFixed(2)}',
            ),
            if (subscription.status == 'Active')
              _buildDetailRow(
                context.tr('auto_renew_on'),
                subscription.autoRenew ? context.tr('yes') : context.tr('no'),
              ),
            const SizedBox(height: 16),
            if (subscription.status == 'Active') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentHistoryScreen(
                              subscriptionId: subscription.id.toString(),
                            ),
                          ),
                        );
                      },
                      child: Text(context.tr('view_payments')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: subscription.autoRenew
                        ? OutlinedButton(
                            onPressed: () => _showCancelConfirmation(subscription),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: Text(context.tr('cancel_renewal')),
                          )
                        : ElevatedButton(
                            onPressed: () => _toggleAutoRenew(subscription),
                            child: Text(context.tr('renew')),
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAutoRenew(UserSubscription subscription) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null) return;
    
    final paymentService = context.read<PaymentService>();
    
    try {
      final success = await paymentService.toggleAutoRenew(
        authProvider.token!, 
        subscription.id.toString(), 
        !subscription.autoRenew
      );
      
      if (success) {
        await _loadSubscriptions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(subscription.autoRenew 
                ? context.tr('auto_renew_disabled')
                : context.tr('auto_renew_enabled')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating auto-renew: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCancelConfirmation(UserSubscription subscription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_cancellation')),
        content: Text(context.tr('cancel_confirmation_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('keep_subscription')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _toggleAutoRenew(subscription);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(context.tr('confirm_cancel')),
          ),
        ],
      ),
    );
  }
} 