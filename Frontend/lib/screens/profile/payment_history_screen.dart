import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../services/payment_service.dart';
import '../../models/payment_transaction.dart';
import '../../providers/auth_provider.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final String? subscriptionId; // Optional: filter for a specific subscription

  const PaymentHistoryScreen({
    Key? key,
    this.subscriptionId,
  }) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isAuthenticated && authProvider.token != null) {
      final paymentService = context.read<PaymentService>();
      await paymentService.getPaymentHistory(authProvider.token!);
    }
  }

  List<PaymentTransaction> _getFilteredTransactions(List<PaymentTransaction> transactions) {
    if (widget.subscriptionId == null) {
      return transactions;
    } else {
      // Filter by subscription ID if provided
      return transactions.where((transaction) => 
        transaction.id.toString() == widget.subscriptionId!).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('payment_history')),
        actions: const [
          LanguageSelector(isCompact: true),
        ],
      ),
      body: Consumer<PaymentService>(
        builder: (context, paymentService, child) {
          if (paymentService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredTransactions = _getFilteredTransactions(paymentService.transactions);
          
          return filteredTransactions.isEmpty
              ? _buildEmptyState()
              : _buildTransactionsList(filteredTransactions);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('no_payment_transactions'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('payments_will_appear_here'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<PaymentTransaction> transactions) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.subscriptionId != null
                      ? context.tr('subscription_payments')
                      : context.tr('all_transactions'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // Download statement or export functionality
                },
                icon: const Icon(Icons.download, size: 16),
                label: Text(context.tr('export')),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey[300]),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return _buildTransactionItem(transaction);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(PaymentTransaction transaction) {
    // Set colors based on status
    Color statusColor;
    IconData statusIcon;
    
    switch (transaction.status) {
      case 'SUCCESSFUL':
      case 'Success':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'FAILED':
      case 'Failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'REFUNDED':
      case 'Refunded':
        statusColor = Colors.orange;
        statusIcon = Icons.replay;
        break;
      case 'PENDING':
      case 'Pending':
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    // Set payment method icon
    IconData paymentIcon;
    switch (transaction.paymentMethod) {
      case 'card':
      case 'Credit Card':
        paymentIcon = Icons.credit_card;
        break;
      case 'paypal':
      case 'PayPal':
        paymentIcon = Icons.account_balance_wallet;
        break;
      default:
        paymentIcon = Icons.payment;
    }

    return InkWell(
      onTap: () {
        _showTransactionDetails(transaction);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.examName ?? 'Unknown Exam',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.planName ?? 'Unknown Plan',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        paymentIcon,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${transaction.paymentMethod ?? 'Card'} •••• ${transaction.last4 ?? '****'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  transaction.amount < 0
                      ? '-\$${transaction.amount.abs().toStringAsFixed(2)}'
                      : '\$${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: transaction.amount < 0 ? Colors.red : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(PaymentTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('transaction_details'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                  context.tr('transaction_id'),
                  transaction.id.toString(),
                ),
                _buildDetailRow(
                  context.tr('date'),
                  '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
                ),
                _buildDetailRow(
                  context.tr('exam'),
                  transaction.examName ?? 'Unknown Exam',
                ),
                _buildDetailRow(
                  context.tr('plan'),
                  transaction.planName ?? 'Unknown Plan',
                ),
                _buildDetailRow(
                  context.tr('amount'),
                  transaction.amount < 0
                      ? '-\$${transaction.amount.abs().toStringAsFixed(2)}'
                      : '\$${transaction.amount.toStringAsFixed(2)}',
                ),
                _buildDetailRow(
                  context.tr('status'),
                  transaction.status,
                  valueColor: _getStatusColor(transaction.status),
                ),
                _buildDetailRow(
                  context.tr('payment_method'),
                  '${transaction.paymentMethod ?? 'Card'} •••• ${transaction.last4 ?? '****'}',
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Download receipt functionality
                    },
                    icon: const Icon(Icons.download),
                    label: Text(context.tr('download_receipt')),
                  ),
                ),
                if (transaction.status == 'Success') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Contact support about this transaction
                        Navigator.pop(context);
                        // Navigate to support screen
                      },
                      icon: const Icon(Icons.contact_support),
                      label: Text(context.tr('contact_support')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUCCESSFUL':
      case 'Success':
        return Colors.green;
      case 'FAILED':
      case 'Failed':
        return Colors.red;
      case 'REFUNDED':
      case 'Refunded':
        return Colors.orange;
      case 'PENDING':
      case 'Pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
} 