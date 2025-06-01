import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../widgets/language_selector.dart';
import '../../../providers/app_providers.dart';
import '../../../models/payment_transaction.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PaymentTransaction> _transactions = [];
  List<PaymentTransaction> _filteredTransactions = [];
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'All';
  DateTimeRange? _selectedDateRange;
  
  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _searchController.addListener(_filterTransactions);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final adminService = context.adminService;
      final authService = context.authService;
      
      if (authService.accessToken == null) {
        throw Exception('Authentication required');
      }
      
      final transactionsData = await adminService.getPayments();
      final transactions = transactionsData.map((data) => PaymentTransaction.fromJson(data)).toList();
      
      setState(() {
        _transactions = transactions;
        _filteredTransactions = List.from(_transactions);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }
  
  void _filterTransactions() {
    setState(() {
      final searchTerm = _searchController.text.toLowerCase();
      
      _filteredTransactions = _transactions.where((transaction) {
        final matchesSearch = 
            (transaction.userName ?? '').toLowerCase().contains(searchTerm) ||
            transaction.userEmail.toLowerCase().contains(searchTerm) ||
            (transaction.paymentSource ?? '').toLowerCase().contains(searchTerm);
            
        final matchesStatus = _statusFilter == 'All' || 
            transaction.status == _statusFilter;
            
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }
  
  Future<void> _exportTransactions() async {
    try {
      final adminService = context.adminService;
      final authService = context.authService;
      
      if (authService.accessToken == null) {
        throw Exception('Authentication required');
      }
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing export...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // For now, show success message as export functionality needs backend implementation
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('transactions_exported')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('payment_transactions')),
        actions: const [
          LanguageSelector(isCompact: true),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildTransactionsList(),
      floatingActionButton: (_isLoading || _error != null) ? null : FloatingActionButton(
        onPressed: _exportTransactions,
        backgroundColor: AppColors.darkBlue,
        child: const Icon(Icons.file_download),
        tooltip: context.tr('export_transactions'),
      ),
    );
  }

  Widget _buildErrorState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 100), // Add some top spacing
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading transactions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadTransactions,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 1200;
        
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWideScreen ? 1400 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      context.tr('payment_transactions'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Filters Section
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: context.tr('search_transactions'),
                                      prefixIcon: const Icon(Icons.search),
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    value: _statusFilter,
                                    decoration: InputDecoration(
                                      labelText: context.tr('status'),
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    items: ['All', 'SUCCESSFUL', 'PENDING', 'FAILED', 'REFUNDED'].map((status) {
                                      return DropdownMenuItem<String>(
                                        value: status,
                                        child: Text(status == 'All' ? 'All' : status),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _statusFilter = value!;
                                        _filterTransactions();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_filteredTransactions.length} ${context.tr('transactions_found')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkGrey,
                                  ),
                                ),
                                Row(
                                  children: [
                                    _buildDateRangePicker(),
                                    const SizedBox(width: 16),
                                    if (_filteredTransactions.isNotEmpty)
                                      TextButton.icon(
                                        onPressed: _exportTransactions,
                                        icon: const Icon(Icons.download),
                                        label: Text(context.tr('export')),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Transactions List
                    if (_filteredTransactions.isEmpty)
                      Card(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.tr('no_transactions_found'),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('try_adjusting_filters'),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // Responsive Grid/List
                      isWideScreen 
                        ? _buildTransactionsGrid()
                        : _buildTransactionsListView(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionsListView() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredTransactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(PaymentTransaction transaction) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                        transaction.userName ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.userEmail,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.mediumGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${transaction.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(transaction.status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        transaction.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('payment_source'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _getPaymentSourceIcon(transaction.paymentSource ?? 'Credit Card'),
                          const SizedBox(width: 8),
                          Text(
                            transaction.paymentSource ?? 'Credit Card',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('date'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(transaction.timestamp),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('transaction_id'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mediumGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.id.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildDateRangePicker() {
    return OutlinedButton.icon(
      onPressed: () async {
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
        );
        
        if (picked != null) {
          // In a real app, this would filter transactions by date range
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr('date_range_selected', params: {
                  'start': _formatDate(picked.start),
                  'end': _formatDate(picked.end),
                }),
              ),
            ),
          );
        }
      },
      icon: const Icon(Icons.date_range),
      label: Text(context.tr('filter_by_date')),
    );
  }

  Widget _getPaymentSourceIcon(String source) {
    IconData iconData;
    Color color;
    
    switch (source.toLowerCase()) {
      case 'credit card':
        iconData = Icons.credit_card;
        color = Colors.blue;
        break;
      case 'paypal':
        iconData = Icons.account_balance_wallet;
        color = Colors.indigo;
        break;
      case 'bank transfer':
        iconData = Icons.account_balance;
        color = Colors.green;
        break;
      case 'apple pay':
        iconData = Icons.apple;
        color = Colors.black;
        break;
      case 'google pay':
        iconData = Icons.g_mobiledata;
        color = Colors.deepOrange;
        break;
      default:
        iconData = Icons.payment;
        color = AppColors.darkBlue;
    }
    
    return Icon(iconData, color: color, size: 20);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUCCESSFUL':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'FAILED':
        return Colors.red;
      case 'REFUNDED':
        return Colors.purple;
      default:
        return AppColors.mediumGrey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 