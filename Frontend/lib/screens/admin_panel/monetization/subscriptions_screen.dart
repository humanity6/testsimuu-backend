import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../widgets/language_selector.dart';
import '../../../providers/app_providers.dart';
import '../../../models/subscription.dart';
import '../../../utils/responsive_utils.dart';
import '../../../widgets/responsive_admin_widgets.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Subscription> _subscriptions = [];
  List<Subscription> _filteredSubscriptions = [];
  Subscription? _selectedSubscription;
  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'All';
  
  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
    _searchController.addListener(_filterSubscriptions);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptions() async {
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
      
      final subscriptions = await adminService.getSubscriptions();
      
      setState(() {
        _subscriptions = subscriptions;
        _filteredSubscriptions = List.from(_subscriptions);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }
  
  void _filterSubscriptions() {
    setState(() {
      final searchTerm = _searchController.text.toLowerCase();
      
      _filteredSubscriptions = _subscriptions.where((subscription) {
        final matchesSearch = 
            (subscription.userName ?? '').toLowerCase().contains(searchTerm) ||
            (subscription.userEmail ?? '').toLowerCase().contains(searchTerm) ||
            subscription.planName.toLowerCase().contains(searchTerm);
            
        final matchesStatus = _statusFilter == 'All' || 
            subscription.status == _statusFilter;
            
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }
  
  void _viewSubscriptionDetails(Subscription subscription) {
    setState(() {
      _selectedSubscription = subscription;
    });
  }
  
  void _closeSubscriptionDetails() {
    setState(() {
      _selectedSubscription = null;
    });
  }
  
  Future<void> _updateSubscriptionStatus(String newStatus) async {
    if (_selectedSubscription == null) return;
    
    try {
      final adminService = context.adminService;
      final authService = context.authService;
      
      if (authService.accessToken == null) {
        throw Exception('Authentication required');
      }
      
      // Update subscription status via API
      await adminService.updateSubscription(
        _selectedSubscription!.id,
        {'status': newStatus},
      );
      
      // Reload subscriptions to get updated data
      await _loadSubscriptions();
      
      // Update selected subscription
      _selectedSubscription = _subscriptions.firstWhere(
        (s) => s.id == _selectedSubscription!.id,
        orElse: () => _selectedSubscription!,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('Subscription status updated')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating subscription: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAdminScaffold(
      title: context.tr('Subscriptions'),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _selectedSubscription != null
                  ? SafeArea(child: _buildSubscriptionDetails())
                  : SafeArea(child: _buildSubscriptionsList()),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkBlue),
          ),
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
          Text(
            context.tr('Loading subscriptions...'),
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 16),
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          padding: ResponsiveUtils.getScreenPadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 100)), 
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 40, desktopSize: 40),
                  color: Colors.red,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
              Text(
                'Error loading subscriptions',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              Container(
                constraints: BoxConstraints(maxWidth: 400),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  ),
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 32)),
              ElevatedButton.icon(
                onPressed: _loadSubscriptions,
                icon: Icon(Icons.refresh),
                label: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getSpacing(context, base: 24),
                    vertical: ResponsiveUtils.getSpacing(context, base: 12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionsList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            padding: ResponsiveUtils.getScreenPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, base: 20)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: ResponsiveUtils.getCardPadding(context),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.darkBlue.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.subscriptions_outlined,
                            color: AppColors.darkBlue,
                            size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Manage subscriptions'),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: ResponsiveUtils.getFontSize(context, base: 20),
                                ),
                              ),
                              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                              Text(
                                context.tr('View and manage user subscriptions'),
                                style: TextStyle(
                                  color: AppColors.mediumGrey,
                                  fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                        
                // Filters Section
                _buildFilters(),
                
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
                
                // Subscriptions List
                if (_filteredSubscriptions.isEmpty)
                  _buildEmptyState()
                else
                  // Responsive Grid/List
                  ResponsiveUtils.isMobile(context)
                      ? _buildSubscriptionsListView()
                      : ResponsiveUtils.isTablet(context)
                          ? _buildSubscriptionsGrid(ResponsiveUtils.isWideDesktop(context) ? 3 : 2)
                          : _buildSubscriptionsGrid(ResponsiveUtils.isWideDesktop(context) ? 4 : 3),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: ResponsiveUtils.getSpacing(context, base: 40),
          horizontal: ResponsiveUtils.getSpacing(context, base: 24),
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.subscriptions_outlined,
                size: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 40, desktopSize: 40),
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
            Text(
              context.tr('No subscriptions found'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.darkGrey,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, base: 18),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
            Container(
              constraints: BoxConstraints(maxWidth: 400),
              child: Text(
                _statusFilter != 'All'
                    ? context.tr('No subscriptions match the selected status filter. Try changing your filter options.')
                    : _searchController.text.isNotEmpty
                        ? context.tr('No subscriptions match your search criteria. Try adjusting your search term.')
                        : context.tr('There are no subscriptions in the system yet.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
            if (_statusFilter != 'All' || _searchController.text.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _statusFilter = 'All';
                    _searchController.clear();
                    _filterSubscriptions();
                  });
                },
                icon: Icon(Icons.filter_list_off),
                label: Text(context.tr('Clear filters')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getSpacing(context, base: 20),
                    vertical: ResponsiveUtils.getSpacing(context, base: 12),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isNarrowTablet = ResponsiveUtils.isTablet(context) && screenWidth < 768;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: AppColors.darkBlue,
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                Text(
                  context.tr('Filters'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            if (ResponsiveUtils.isMobile(context) || isNarrowTablet)
              // Mobile or narrow tablet: Stacked layout
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr('Search subscriptions'),
                      prefixIcon: Icon(
                        Icons.search,
                        size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                        color: AppColors.darkBlue.withOpacity(0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.darkBlue),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                        vertical: ResponsiveUtils.getSpacing(context, base: 12),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                  DropdownButtonFormField<String>(
                    value: _statusFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Status'),
                      labelStyle: TextStyle(color: AppColors.darkGrey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.darkBlue),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                        vertical: ResponsiveUtils.getSpacing(context, base: 12),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                      color: AppColors.darkGrey,
                    ),
                    dropdownColor: Colors.white,
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.darkBlue),
                    items: _buildStatusDropdownItems(),
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value!;
                        _filterSubscriptions();
                      });
                    },
                  ),
                ],
              )
            else
              // Desktop/Wide tablet: Horizontal layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: context.tr('Search subscriptions'),
                        prefixIcon: Icon(
                          Icons.search,
                          size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                          color: AppColors.darkBlue.withOpacity(0.7),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.darkBlue),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                          vertical: ResponsiveUtils.getSpacing(context, base: 12),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _statusFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('Status'),
                        labelStyle: TextStyle(color: AppColors.darkGrey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.darkBlue),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                          vertical: ResponsiveUtils.getSpacing(context, base: 12),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        color: AppColors.darkGrey,
                      ),
                      dropdownColor: Colors.white,
                      icon: Icon(Icons.arrow_drop_down, color: AppColors.darkBlue),
                      items: _buildStatusDropdownItems(),
                      onChanged: (value) {
                        setState(() {
                          _statusFilter = value!;
                          _filterSubscriptions();
                        });
                      },
                    ),
                  ),
                ],
              ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            Divider(height: 1),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.list_alt,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                      color: AppColors.darkBlue.withOpacity(0.7),
                    ),
                    SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                    Text(
                      '${_filteredSubscriptions.length} ${context.tr('Subscriptions found')}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGrey,
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                      ),
                    ),
                  ],
                ),
                if (_filteredSubscriptions.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Export functionality placeholder
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.tr('Export feature coming soon'))),
                      );
                    },
                    icon: Icon(
                      Icons.download,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                    ),
                    label: Text(
                      context.tr('Export'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                        vertical: ResponsiveUtils.getSpacing(context, base: 10),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  List<DropdownMenuItem<String>> _buildStatusDropdownItems() {
    return ['All', 'ACTIVE', 'EXPIRED', 'CANCELED', 'PENDING_PAYMENT'].map((status) {
      Color? statusColor = status == 'All' ? null : _getStatusColor(status);
      
      return DropdownMenuItem<String>(
        value: status,
        child: Row(
          children: [
            if (status != 'All') ...[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
            ],
            Text(
              status == 'All' ? context.tr('All') : status,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                color: status == 'All' ? AppColors.darkGrey : statusColor,
                fontWeight: status == _statusFilter ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSubscriptionsGrid(int crossAxisCount) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double aspectRatio;
    final double? mainExtent;
    
    if (ResponsiveUtils.isMobile(context)) {
      aspectRatio = 0.8;
      mainExtent = 225;
    } else if (ResponsiveUtils.isTablet(context)) {
      aspectRatio = screenWidth > 800 ? 1.0 : 0.8;
      mainExtent = screenWidth > 800 ? 225 : 245;
    } else {
      // Desktop
      if (ResponsiveUtils.isWideDesktop(context)) {
        aspectRatio = 1.4;
        mainExtent = 230;
      } else {
        aspectRatio = screenWidth > 1200 ? 1.2 : 0.9;
        mainExtent = screenWidth > 1200 ? 225 : 265;
      }
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth / crossAxisCount) - 16; // 16 is the spacing
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: ResponsiveUtils.getSpacing(context, base: 16),
            mainAxisSpacing: ResponsiveUtils.getSpacing(context, base: 16),
            mainAxisExtent: mainExtent,
          ),
          itemCount: _filteredSubscriptions.length,
          itemBuilder: (context, index) {
            final subscription = _filteredSubscriptions[index];
            return ResponsiveUtils.isMobile(context)
                ? _buildMobileSubscriptionCard(subscription)
                : _buildDesktopSubscriptionCard(subscription, itemWidth);
          },
        );
      },
    );
  }

  Widget _buildSubscriptionsListView() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredSubscriptions.length,
      itemBuilder: (context, index) {
        final subscription = _filteredSubscriptions[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: ResponsiveUtils.getSpacing(context, base: 16),
          ),
          child: _buildMobileSubscriptionCard(subscription),
        );
      },
    );
  }

  Widget _buildMobileSubscriptionCard(Subscription subscription) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVeryNarrow = screenWidth < 360;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _viewSubscriptionDetails(subscription),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: ResponsiveUtils.getCardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: ResponsiveUtils.getSpacing(context, base: 8),
                runSpacing: ResponsiveUtils.getSpacing(context, base: 8),
                children: [
                  Container(
                    width: isVeryNarrow ? screenWidth * 0.5 : screenWidth * 0.6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.userName ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          subscription.userEmail ?? '',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                            color: AppColors.mediumGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getSpacing(context, base: isVeryNarrow ? 8 : 12),
                      vertical: ResponsiveUtils.getSpacing(context, base: 6),
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(subscription.status).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(subscription.status).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    ),
                    child: Text(
                      context.tr(subscription.status),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveUtils.getFontSize(context, base: isVeryNarrow ? 10 : 12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
              const Divider(height: 1),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
              // Info items with icons
              Row(
                children: [
                  Icon(
                    Icons.credit_card_outlined,
                    size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                    color: AppColors.darkBlue.withOpacity(0.7),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                  Flexible(
                    child: Text(
                      '${context.tr('Plan')}: ${subscription.planName}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                    color: AppColors.darkBlue.withOpacity(0.8),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                  Flexible(
                    child: Text(
                      '${context.tr('Start date')}: ${_formatDate(subscription.startDate)}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                    color: AppColors.darkBlue.withOpacity(0.8),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                  Flexible(
                    child: Text(
                      '${context.tr('End date')}: ${subscription.endDate != null ? _formatDate(subscription.endDate!) : 'N/A'}',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_forward,
                    size: ResponsiveUtils.getIconSize(context, mobileSize: 14, tabletSize: 14, desktopSize: 14),
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSubscriptionCard(Subscription subscription, double itemWidth) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _viewSubscriptionDetails(subscription),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: ResponsiveUtils.getCardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.userName ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          subscription.userEmail ?? '',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                            color: AppColors.mediumGrey,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getSpacing(context, base: 12),
                      vertical: ResponsiveUtils.getSpacing(context, base: 6),
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(subscription.status).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(subscription.status).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    ),
                    child: Text(
                      context.tr(subscription.status),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
              const Divider(height: 1),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
              // Use Wrap for responsiveness
              Wrap(
                spacing: ResponsiveUtils.getSpacing(context, base: 16),
                runSpacing: ResponsiveUtils.getSpacing(context, base: 8),
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // Plan info
                  SizedBox(
                    width: itemWidth * 0.28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.credit_card_outlined,
                              size: ResponsiveUtils.getIconSize(context, mobileSize: 14, tabletSize: 15, desktopSize: 16),
                              color: AppColors.darkBlue.withOpacity(0.7),
                            ),
                            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 4)),
                            Text(
                              context.tr('Plan'),
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                                color: AppColors.mediumGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          subscription.planName,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  // Start date info
                  SizedBox(
                    width: itemWidth * 0.28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: ResponsiveUtils.getIconSize(context, mobileSize: 14, tabletSize: 15, desktopSize: 16),
                              color: AppColors.darkBlue.withOpacity(0.8),
                            ),
                            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 4)),
                            Text(
                              context.tr('Start date'),
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                                color: AppColors.mediumGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          _formatDate(subscription.startDate),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  // End date info
                  SizedBox(
                    width: itemWidth * 0.28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: ResponsiveUtils.getIconSize(context, mobileSize: 14, tabletSize: 15, desktopSize: 16),
                              color: AppColors.darkBlue.withOpacity(0.8),
                            ),
                            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 4)),
                            Text(
                              context.tr('End date'),
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                                color: AppColors.mediumGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          subscription.endDate != null ? _formatDate(subscription.endDate!) : 'N/A',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  // Arrow icon with a small circular background
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_forward,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                      color: AppColors.darkBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscriptionDetails() {
    final subscription = _selectedSubscription!;
    
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: ResponsiveUtils.getScreenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with back button
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, base: 20)),
              child: Padding(
                padding: ResponsiveUtils.getCardPadding(context),
                child: Row(
                  children: [
                    Material(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      elevation: 2,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
                          color: Colors.white,
                        ),
                        onPressed: _closeSubscriptionDetails,
                        tooltip: context.tr('Back to subscriptions'),
                        padding: EdgeInsets.all(8),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Subscription details'),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontSize: ResponsiveUtils.getFontSize(context, base: 20),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                          Text(
                            subscription.userName ?? 'Unknown User',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                              color: AppColors.darkGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                        vertical: ResponsiveUtils.getSpacing(context, base: 8),
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(subscription.status).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(subscription.status).withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      ),
                      child: Text(
                        context.tr(subscription.status),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Main content area
            ResponsiveUtils.isMobile(context)
              ? _buildMobileSubscriptionDetailsContent(subscription)
              : _buildDesktopSubscriptionDetailsContent(subscription),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSubscriptionDetailsContent(Subscription subscription) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubscriptionInfoCard(subscription),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 20)),
        _buildStatusUpdateCard(subscription),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 20)),
        _buildStatusHistoryCard(subscription),
      ],
    );
  }

  Widget _buildDesktopSubscriptionDetailsContent(Subscription subscription) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Main info
        Expanded(
          flex: 2,
          child: _buildSubscriptionInfoCard(subscription),
        ),
        SizedBox(width: ResponsiveUtils.getSpacing(context, base: 20)),
        // Right column - Status update and history
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildStatusUpdateCard(subscription),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 20)),
              _buildStatusHistoryCard(subscription),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionInfoCard(Subscription subscription) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ResponsiveUtils.isMobile(context))
              // Mobile: Stacked layout
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(
                    context.tr('User information'),
                    [
                      _buildInfoRow(context.tr('Name'), subscription.userName ?? 'Unknown', Icons.person_outline),
                      _buildInfoRow(context.tr('Email'), subscription.userEmail ?? '', Icons.email_outlined),
                      _buildInfoRow(context.tr('User ID'), subscription.userId, Icons.badge_outlined),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 20)),
                  _buildDetailSection(
                    context.tr('Subscription information'),
                    [
                      _buildInfoRow(context.tr('Plan'), subscription.planName, Icons.credit_card_outlined),
                      _buildInfoRow(context.tr('Subscription ID'), subscription.id, Icons.confirmation_number_outlined),
                      _buildInfoRow(context.tr('Created at'), _formatDateTime(subscription.createdAt), Icons.access_time_outlined),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 20)),
                  _buildDetailSection(
                    context.tr('Billing information'),
                    [
                      _buildInfoRow(context.tr('Amount'), '\$${subscription.amount.toStringAsFixed(2)}', Icons.attach_money_outlined),
                      _buildInfoRow(context.tr('Billing cycle'), subscription.billingCycle, Icons.autorenew_outlined),
                      _buildInfoRow(
                        context.tr('Next billing date'), 
                        subscription.status == 'ACTIVE' && subscription.endDate != null
                            ? _formatDate(subscription.endDate!)
                            : context.tr('Not applicable'),
                        Icons.event_outlined
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 20)),
                  _buildDetailSection(
                    context.tr('Status information'),
                    [
                      _buildInfoRow(
                        context.tr('Current status'),
                        Row(
                          children: [
                            Container(
                              width: ResponsiveUtils.getSpacing(context, base: 12),
                              height: ResponsiveUtils.getSpacing(context, base: 12),
                              decoration: BoxDecoration(
                                color: _getStatusColor(subscription.status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                            Text(
                              context.tr(subscription.status),
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                              ),
                            ),
                          ],
                        ),
                        Icons.info_outline
                      ),
                      _buildInfoRow(
                        context.tr('Start date'), 
                        _formatDateTime(subscription.startDate),
                        Icons.calendar_today_outlined
                      ),
                      _buildInfoRow(
                        context.tr('End date'), 
                        subscription.endDate != null ? _formatDateTime(subscription.endDate!) : 'N/A',
                        Icons.event_outlined
                      ),
                    ],
                  ),
                ],
              )
            else
              // Desktop/Tablet: Grid layout
              Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDetailSection(
                          context.tr('User information'),
                          [
                            _buildInfoRow(context.tr('Name'), subscription.userName ?? 'Unknown', Icons.person_outline),
                            _buildInfoRow(context.tr('Email'), subscription.userEmail ?? '', Icons.email_outlined),
                            _buildInfoRow(context.tr('User ID'), subscription.userId, Icons.badge_outlined),
                          ],
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getSpacing(context, base: 20)),
                      Expanded(
                        child: _buildDetailSection(
                          context.tr('Subscription information'),
                          [
                            _buildInfoRow(context.tr('Plan'), subscription.planName, Icons.credit_card_outlined),
                            _buildInfoRow(context.tr('Subscription id'), subscription.id, Icons.confirmation_number_outlined),
                            _buildInfoRow(context.tr('Created at'), _formatDateTime(subscription.createdAt), Icons.access_time_outlined),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Divider(height: ResponsiveUtils.getSpacing(context, base: 40), thickness: 1),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDetailSection(
                          context.tr('Billing information'),
                          [
                            _buildInfoRow(context.tr('Amount'), '\$${subscription.amount.toStringAsFixed(2)}', Icons.attach_money_outlined),
                            _buildInfoRow(context.tr('Billing cycle'), subscription.billingCycle, Icons.autorenew_outlined),
                            _buildInfoRow(
                              context.tr('Next billing date'), 
                              subscription.status == 'ACTIVE' && subscription.endDate != null
                                ? _formatDate(subscription.endDate!)
                                : context.tr('Not applicable'),
                              Icons.event_outlined
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getSpacing(context, base: 20)),
                      Expanded(
                        child: _buildDetailSection(
                          context.tr('Status information'),
                          [
                            _buildInfoRow(
                              context.tr('Current status'),
                              Row(
                                children: [
                                  Container(
                                    width: ResponsiveUtils.getSpacing(context, base: 12),
                                    height: ResponsiveUtils.getSpacing(context, base: 12),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(subscription.status),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                                  Text(
                                    context.tr(subscription.status),
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                                    ),
                                  ),
                                ],
                              ),
                              Icons.info_outline
                            ),
                            _buildInfoRow(
                              context.tr('Start date'), 
                              _formatDateTime(subscription.startDate),
                              Icons.calendar_today_outlined
                            ),
                            _buildInfoRow(
                              context.tr('End date'), 
                              subscription.endDate != null ? _formatDateTime(subscription.endDate!) : 'N/A',
                              Icons.event_outlined
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusUpdateCard(Subscription subscription) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.update,
                  color: AppColors.darkBlue,
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                Text(
                  context.tr('Update status'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            Wrap(
              spacing: ResponsiveUtils.getSpacing(context, base: 8),
              runSpacing: ResponsiveUtils.getSpacing(context, base: 8),
              children: [
                _buildStatusButton('ACTIVE', subscription.status != 'ACTIVE'),
                _buildStatusButton('EXPIRED', subscription.status != 'EXPIRED'),
                _buildStatusButton('CANCELED', subscription.status != 'CANCELED'),
                _buildStatusButton('PENDING_PAYMENT', subscription.status != 'PENDING_PAYMENT'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHistoryCard(Subscription subscription) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: AppColors.darkBlue,
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                Text(
                  context.tr('status_history'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            if (subscription.statusLogs.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_toggle_off_outlined,
                        size: ResponsiveUtils.getIconSize(context, mobileSize: 48, tabletSize: 48, desktopSize: 48),
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
                      Text(
                        context.tr('No status history available'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subscription.statusLogs.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = subscription.statusLogs[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getSpacing(context, base: 8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          width: ResponsiveUtils.getSpacing(context, base: 12),
                          height: ResponsiveUtils.getSpacing(context, base: 12),
                          decoration: BoxDecoration(
                            color: _getStatusColor(log.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: ResponsiveUtils.getSpacing(context, base: 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    log.status,
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _formatDateTime(log.timestamp),
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                                      color: AppColors.mediumGrey,
                                    ),
                                  ),
                                ],
                              ),
                              if (log.note.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: ResponsiveUtils.getSpacing(context, base: 4)),
                                  child: Text(
                                    log.note,
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getFontSize(context, base: 13),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.only(top: ResponsiveUtils.getSpacing(context, base: 4)),
                                child: Text(
                                  'By: ${log.changedBy}',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.mediumGrey,
                                    fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.darkBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
        ...children,
      ],
    );
  }

  Widget _buildStatusButton(String status, bool enabled) {
    return ElevatedButton(
      onPressed: enabled ? () => _updateSubscriptionStatus(status) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? _getStatusColor(status) : Colors.grey[400],
        foregroundColor: Colors.white,
        elevation: enabled ? 2 : 0,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getSpacing(context, base: 16),
          vertical: ResponsiveUtils.getSpacing(context, base: 10),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: ResponsiveUtils.getFontSize(context, base: 13),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, dynamic value, [IconData? icon]) {
    final valueWidget = value is Widget 
        ? value 
        : Text(
            value.toString(),
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
            ),
          );
            
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, base: 12)),
      child: ResponsiveUtils.isMobile(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                        color: AppColors.darkBlue.withOpacity(0.7),
                      ),
                      SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                    ],
                    Text(
                      '$label:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGrey,
                        fontSize: ResponsiveUtils.getFontSize(context, base: 13),
                      ),
                    ),
                  ],
                ),
                if (icon != null)
                  Padding(
                    padding: EdgeInsets.only(left: ResponsiveUtils.getSpacing(context, base: 24)),
                    child: valueWidget,
                  )
                else
                  Padding(
                    padding: EdgeInsets.only(top: ResponsiveUtils.getSpacing(context, base: 4)),
                    child: valueWidget,
                  ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ResponsiveUtils.getSpacing(context, base: 140),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                          color: AppColors.darkBlue.withOpacity(0.7),
                        ),
                        SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                      ],
                      Flexible(
                        child: Text(
                          '$label:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGrey,
                            fontSize: ResponsiveUtils.getFontSize(context, base: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: valueWidget,
                ),
              ],
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'EXPIRED':
        return Colors.orange;
      case 'CANCELED':
        return Colors.red;
      case 'PENDING PAYMENT':
        return Colors.blue;
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
