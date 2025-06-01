import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../widgets/language_selector.dart';
import '../../../providers/app_providers.dart';
import '../../../services/admin_service.dart';
import '../../../models/ai_alert.dart';
import '../../../utils/responsive_utils.dart';
import '../../../widgets/responsive_admin_widgets.dart';
import 'alert_detail_screen.dart';

class AdminAIAlertsScreen extends StatefulWidget {
  const AdminAIAlertsScreen({Key? key}) : super(key: key);

  @override
  State<AdminAIAlertsScreen> createState() => _AdminAIAlertsScreenState();
}

class _AdminAIAlertsScreenState extends State<AdminAIAlertsScreen> {
  bool _isLoading = true;
  List<AIAlert> _alerts = [];
  List<AIAlert> _filteredAlerts = [];
  String _statusFilter = 'All';
  String _priorityFilter = 'All';
  String? _error;
  late AdminService _adminService;
  int _currentPage = 1;
  bool _hasMoreData = true;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;

  final ScrollController _scrollController = ScrollController();
  final List<String> _statusOptions = ['All', 'New', 'Under Review', 'Action Taken', 'Dismissed'];
  final List<String> _priorityOptions = ['All', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _initializeAdminService();
    _setupScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeAdminService() {
    final authService = context.authService;
    final user = authService.currentUser;
    final accessToken = authService.accessToken;
    
    if (user != null && accessToken != null && user.isStaff) {
      _adminService = AdminService(accessToken: accessToken);
      _loadAlerts();
    } else {
      // Handle case where user is not authenticated or not admin
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
    }
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoadingMore &&
          _hasMoreData) {
        _loadMoreAlerts();
      }
    });
  }

  Future<void> _loadAlerts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
      });

      final alerts = await _adminService.getAIAlerts(
        status: _statusFilter != 'All' ? _statusFilter.toUpperCase() : null,
        priority: _priorityFilter != 'All' ? _priorityFilter.toUpperCase() : null,
        page: _currentPage,
        pageSize: _pageSize,
      );

      setState(() {
        _alerts = alerts;
        _filteredAlerts = alerts;
        _hasMoreData = alerts.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load alerts: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreAlerts() async {
    if (_isLoadingMore) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final nextPage = _currentPage + 1;
      final moreAlerts = await _adminService.getAIAlerts(
        status: _statusFilter != 'All' ? _statusFilter.toUpperCase() : null,
        priority: _priorityFilter != 'All' ? _priorityFilter.toUpperCase() : null,
        page: nextPage,
        pageSize: _pageSize,
      );

      if (moreAlerts.isNotEmpty) {
        setState(() {
          _alerts.addAll(moreAlerts);
          _filteredAlerts = _alerts;
          _currentPage = nextPage;
          _hasMoreData = moreAlerts.length == _pageSize;
        });
      } else {
        setState(() {
          _hasMoreData = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load more alerts: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Widget _buildFilters() {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Container(
      padding: ResponsiveUtils.getScreenPadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: context.tr('status'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  value: _statusFilter,
                  items: _statusOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _statusFilter = newValue!;
                    });
                    _loadAlerts();
                  },
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: context.tr('priority'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  value: _priorityFilter,
                  items: _priorityOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _priorityFilter = newValue!;
                    });
                    _loadAlerts();
                  },
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: context.tr('status'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    value: _statusFilter,
                    items: _statusOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _statusFilter = newValue!;
                      });
                      _loadAlerts();
                    },
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: context.tr('priority'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    value: _priorityFilter,
                    items: _priorityOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _priorityFilter = newValue!;
                      });
                      _loadAlerts();
                    },
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is admin, redirect if not
    final user = context.authService.currentUser;
    
    if (user == null || !user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return ResponsiveAdminScaffold(
      title: context.tr('ai_alerts'),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
          ),
          tooltip: context.tr('refresh'),
          onPressed: _loadAlerts,
        ),
      ],
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: ResponsiveUtils.getScreenPadding(context),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: ResponsiveUtils.getIconSize(context, mobileSize: 64, tabletSize: 64, desktopSize: 64),
                                color: Colors.red[400],
                              ),
                              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                              ElevatedButton(
                                onPressed: _loadAlerts,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.darkBlue,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  context.tr('retry'),
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredAlerts.isEmpty
                        ? Center(
                            child: Padding(
                              padding: ResponsiveUtils.getScreenPadding(context),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none,
                                    size: ResponsiveUtils.getIconSize(context, mobileSize: 64, tabletSize: 64, desktopSize: 64),
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                                  Text(
                                    context.tr('no_alerts_found'),
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _filteredAlerts.length + (_hasMoreData ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _filteredAlerts.length) {
                                return Container(
                                  padding: ResponsiveUtils.getScreenPadding(context),
                                  alignment: Alignment.center,
                                  child: _isLoadingMore
                                      ? const CircularProgressIndicator()
                                      : TextButton(
                                          onPressed: _loadMoreAlerts,
                                          child: Text(
                                            context.tr('load_more'),
                                            style: TextStyle(
                                              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                                            ),
                                          ),
                                        ),
                                );
                              }

                              final alert = _filteredAlerts[index];
                              return _buildAlertCard(alert);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AIAlert alert) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
        vertical: ResponsiveUtils.getSpacing(context, base: 8),
      ),
      child: isMobile ? _buildMobileAlertCard(alert) : _buildDesktopAlertCard(alert),
    );
  }

  Widget _buildMobileAlertCard(AIAlert alert) {
    return Padding(
      padding: ResponsiveUtils.getCardPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert.title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: ResponsiveUtils.getFontSize(context, base: 16),
            ),
            overflow: TextOverflow.visible,
            maxLines: 2,
          ),
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
          Text(
            alert.source,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
          Text(
            '${context.tr('confidence')}: ${(alert.confidenceScore * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
              color: alert.confidenceScore >= 0.8
                  ? Colors.green
                  : alert.confidenceScore >= 0.6
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
          Row(
            children: [
              _buildStatusChip(alert.status),
              SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
              _buildPriorityChip(alert.priority),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AlertDetailScreen(alertId: alert.id),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAlertCard(AIAlert alert) {
    return ListTile(
      title: Text(
        alert.title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: ResponsiveUtils.getFontSize(context, base: 16),
        ),
        overflow: TextOverflow.visible,
        maxLines: 2,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert.source,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
          Text(
            '${context.tr('confidence')}: ${(alert.confidenceScore * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
              color: alert.confidenceScore >= 0.8
                  ? Colors.green
                  : alert.confidenceScore >= 0.6
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusChip(alert.status),
          SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
          _buildPriorityChip(alert.priority),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlertDetailScreen(alertId: alert.id),
          ),
        );
      },
      isThreeLine: true,
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'NEW':
        color = Colors.blue;
        break;
      case 'UNDER_REVIEW':
        color = Colors.orange;
        break;
      case 'ACTION_TAKEN':
        color = Colors.green;
        break;
      case 'DISMISSED':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    switch (priority.toUpperCase()) {
      case 'HIGH':
        color = Colors.red;
        break;
      case 'MEDIUM':
        color = Colors.orange;
        break;
      case 'LOW':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(priority),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
    );
  }
} 
