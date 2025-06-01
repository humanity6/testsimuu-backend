import 'package:flutter/material.dart';
import 'dart:async';
import '../../../theme.dart';
import '../../../models/user.dart';
import '../../../widgets/language_selector.dart';
import '../../../widgets/user_avatar_widget.dart';
import '../../../providers/app_providers.dart';
import '../../../services/admin_service.dart';
import '../../../utils/responsive_utils.dart';
import '../../../widgets/responsive_admin_widgets.dart';
import 'user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isLoading = true;
  List<User> _users = [];
  String _searchQuery = '';
  String _filterBy = 'All';
  String _sortBy = 'date_joined';
  String _sortOrder = 'desc';
  String? _error;
  late AdminService _adminService;
  int _currentPage = 1;
  bool _hasMoreData = true;
  static const int _pageSize = 20;
  bool _isLoadingMore = false;
  Timer? _searchDebouncer;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = ['All', 'Admin', 'Active', 'Inactive', 'Verified', 'Unverified'];
  final List<String> _sortOptions = ['Name', 'Email', 'Date Joined', 'Last Active'];
  final Map<String, String> _sortMapping = {
    'Name': 'first_name',
    'Email': 'email',
    'Date Joined': 'date_joined',
    'Last Active': 'last_active',
  };

  // Add display name mappings for filters and sorts
  final Map<String, String> _filterDisplayNames = {
    'All': 'All Users',
    'Admin': 'Admin Users',
    'Active': 'Active Users',
    'Inactive': 'Inactive Users',
    'Verified': 'Verified Users',
    'Unverified': 'Unverified Users',
  };

  final Map<String, String> _sortDisplayNames = {
    'Name': 'Name',
    'Email': 'Email',
    'Date Joined': 'Date Joined',
    'Last Active': 'Last Active',
  };

  @override
  void initState() {
    super.initState();
    _initializeAdminService();
    _setupScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebouncer?.cancel();
    super.dispose();
  }

  void _initializeAdminService() {
    final authService = context.authService;
    final user = authService.currentUser;
    final accessToken = authService.accessToken;
    
    if (user != null && accessToken != null && user.isStaff) {
      _adminService = AdminService(accessToken: accessToken);
      _loadUsers();
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
        _loadMoreUsers();
      }
    });
  }

  // Convert UI filter to API parameters
  Map<String, dynamic> _getFilterParams() {
    final params = <String, dynamic>{};
    
    switch (_filterBy) {
      case 'Active':
        params['is_active'] = true;
        break;
      case 'Inactive':
        params['is_active'] = false;
        break;
      case 'Admin':
        params['is_staff'] = true;
        break;
      case 'Verified':
        params['email_verified'] = true;
        break;
      case 'Unverified':
        params['email_verified'] = false;
        break;
      default:
        // 'All' - no additional filters
        break;
    }
    
    return params;
  }

  Future<void> _loadUsers({bool reset = true}) async {
    if (!mounted) return;
    
    try {
      if (reset) {
        setState(() {
          _isLoading = true;
          _error = null;
          _currentPage = 1;
          _users.clear();
        });
      }

      final filterParams = _getFilterParams();
      print('Loading users with filter: $_filterBy, params: $filterParams'); // Debug
      print('Sort params: sortBy=$_sortBy, sortOrder=$_sortOrder'); // Debug
      
      final users = await _adminService.getUsers(
        searchQuery: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        page: _currentPage,
        pageSize: _pageSize,
        isActive: filterParams['is_active'],
        isStaff: filterParams['is_staff'],
        emailVerified: filterParams['email_verified'],
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );

      if (!mounted) return;

      setState(() {
        if (reset) {
          _users = users;
        } else {
          _users.addAll(users);
        }
        _hasMoreData = users.length == _pageSize;
        _isLoading = false;
      });
      
      print('Loaded ${users.length} users, total: ${_users.length}'); // Debug
    } catch (e) {
      if (!mounted) return;
      
      print('Error loading users: $e'); // Debug
      setState(() {
        _error = 'Failed to load users: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoadingMore) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final nextPage = _currentPage + 1;
      final filterParams = _getFilterParams();
      final moreUsers = await _adminService.getUsers(
        searchQuery: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        page: nextPage,
        pageSize: _pageSize,
        isActive: filterParams['is_active'],
        isStaff: filterParams['is_staff'],
        emailVerified: filterParams['email_verified'],
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );

      if (moreUsers.isNotEmpty) {
        setState(() {
          _users.addAll(moreUsers);
          _currentPage = nextPage;
          _hasMoreData = moreUsers.length == _pageSize;
        });
      } else {
        setState(() {
          _hasMoreData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more users: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    
    // Cancel previous timer
    _searchDebouncer?.cancel();
    
    // Start new timer
    _searchDebouncer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadUsers(reset: true);
      }
    });
  }

     void _onFilterChanged(String? newFilter) {
     if (newFilter != null && newFilter != _filterBy) {
       print('Filter changed from $_filterBy to $newFilter'); // Debug
       setState(() {
         _filterBy = newFilter;
       });
       _loadUsers(reset: true);
     }
   }

  void _onSortChanged(String? newSort) {
    if (newSort != null) {
      final sortField = _sortMapping[newSort];
      if (sortField != null && sortField != _sortBy) {
        setState(() {
          _sortBy = sortField;
        });
        _loadUsers(reset: true);
      }
    }
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
    });
    _loadUsers(reset: true);
  }

     String _getSortDisplayValue() {
     return _sortMapping.entries
         .firstWhere((entry) => entry.value == _sortBy)
         .key;
   }

   String _getActiveFilterDescription() {
     List<String> activeFilters = [];
     
     if (_searchQuery.isNotEmpty) {
       activeFilters.add('Search: "$_searchQuery"');
     }
     
     if (_filterBy != 'All') {
       activeFilters.add('Filter: ${_filterDisplayNames[_filterBy]}');
     }
     
     final sortDisplay = _getSortDisplayValue();
     final sortDirection = _sortOrder == 'asc' ? '↑' : '↓';
     activeFilters.add('Sort: $sortDisplay $sortDirection');
     
     return activeFilters.join(' • ');
   }

     Future<void> _refreshUsers() async {
     await _loadUsers(reset: true);
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('Users list refreshed'),
           backgroundColor: Colors.green,
           duration: Duration(seconds: 2),
         ),
       );
     }
   }

  Widget _buildSearchAndFilters() {
    final isTablet = ResponsiveUtils.isTablet(context);
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
      child: Column(
        children: [
          // Status indicator
          if (_filterBy != 'All' || _searchQuery.isNotEmpty)
            Container(
              width: double.infinity,
              padding: ResponsiveUtils.getCardPadding(context),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                _getActiveFilterDescription(),
                style: TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w500,
                  fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (_filterBy != 'All' || _searchQuery.isNotEmpty)
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
          
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users by name or email...',
              prefixIcon: Icon(
                Icons.search,
                size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
            ),
            onChanged: _onSearchChanged,
          ),
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
          
          // Filters and sorting - responsive layout
          if (isMobile)
            // Mobile: Stack vertically
            Column(
              children: [
                // Filter dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Filter Users',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  value: _filterBy,
                  items: _filterOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        _filterDisplayNames[value] ?? value,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _onFilterChanged,
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                // Sort dropdown with toggle
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Sort By',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                        ),
                        value: _getSortDisplayValue(),
                        items: _sortOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              _sortDisplayNames[value] ?? value,
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: _onSortChanged,
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                    // Sort order toggle
                    IconButton(
                      icon: Icon(
                        _sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                        size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
                      ),
                      tooltip: _sortOrder == 'asc' ? 'Sort Ascending' : 'Sort Descending',
                      onPressed: _toggleSortOrder,
                    ),
                  ],
                ),
              ],
            )
          else
            // Tablet/Desktop: Horizontal layout
            Row(
              children: [
                // Filter dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filter Users',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    value: _filterBy,
                    items: _filterOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          _filterDisplayNames[value] ?? value,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: _onFilterChanged,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                // Sort dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Sort By',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                    ),
                    value: _getSortDisplayValue(),
                    items: _sortOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          _sortDisplayNames[value] ?? value,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: _onSortChanged,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                // Sort order toggle
                IconButton(
                  icon: Icon(
                    _sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                    size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
                  ),
                  tooltip: _sortOrder == 'asc' ? 'Sort Ascending' : 'Sort Descending',
                  onPressed: _toggleSortOrder,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final isActive = user.isActive ?? false;
    final isVerified = user.emailVerified ?? false;
    final isStaff = user.isStaff ?? false;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () => _navigateToUserDetail(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: ResponsiveUtils.getCardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    avatarUrl: user.avatar,
                    userName: '${user.firstName} ${user.lastName}',
                    size: ResponsiveUtils.isDesktop(context) ? 50 : 45,
                    isAdmin: user.isStaff ?? false,
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${user.firstName} ${user.lastName}',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (isStaff)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.darkBlue.withValues(alpha: 230),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.getFontSize(context, base: 10),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          user.email,
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
                ],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              Divider(height: 1, color: Colors.grey.shade200),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              
              // Status indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusIndicator(
                    isActive ? 'Active' : 'Inactive',
                    isActive ? Colors.green : Colors.red,
                    Icons.circle,
                    isActive,
                  ),
                  _buildStatusIndicator(
                    isVerified ? 'Verified' : 'Unverified',
                    isVerified ? Colors.blue : Colors.orange,
                    isVerified ? Icons.verified_user : Icons.warning_amber_rounded,
                    isVerified,
                  ),
                ],
              ),
              
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              
              // Date information
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Joined'),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                            color: AppColors.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          user.dateJoined != null 
                              ? _formatDate(user.dateJoined!)
                              : 'Unknown',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 13),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Last active'),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                            color: AppColors.mediumGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          user.lastActive != null
                              ? _formatDate(user.lastActive!)
                              : 'Never',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 13),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
              
              // View details button
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey.withValues(alpha: 76),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_forward,
                    size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
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

  Widget _buildStatusIndicator(String label, Color color, IconData icon, bool isPositive) {
    return Row(
      children: [
        Icon(
          icon,
          size: ResponsiveUtils.getIconSize(context, mobileSize: 12, tabletSize: 12, desktopSize: 12),
          color: color,
        ),
        SizedBox(width: ResponsiveUtils.getSpacing(context, base: 4)),
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 13),
            fontWeight: FontWeight.w500,
            color: isPositive ? AppColors.darkGrey : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        return 'Just now';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToUserDetail(User user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserDetailScreen(userId: user.id),
      ),
    );
  }

  Widget _buildUsersList() {
    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: ResponsiveUtils.getScreenPadding(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: ResponsiveUtils.getIconSize(context, mobileSize: 64, tabletSize: 64, desktopSize: 64),
                color: Colors.grey[400],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              Text(
                'No users found',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
              Text(
                'Try a different search term or filter',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = ResponsiveUtils.isMobile(context)
            ? 1
            : ResponsiveUtils.isTablet(context)
                ? constraints.maxWidth > 700 ? 2 : 1
                : constraints.maxWidth > 1400
                    ? 4
                    : constraints.maxWidth > 1100
                        ? 3
                        : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: ResponsiveUtils.getCardAspectRatio(
              context,
              mobileRatio: 1.2,
              tabletRatio: 1.3,
              desktopRatio: 1.4,
            ),
            crossAxisSpacing: ResponsiveUtils.getSpacing(context, base: 16),
            mainAxisSpacing: ResponsiveUtils.getSpacing(context, base: 16),
          ),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAdminScaffold(
      title: context.tr('User Management'),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkBlue),
            ),
            SizedBox(height: 16),
            Text(
              context.tr('Loading users...'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                color: AppColors.darkGrey,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshUsers,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, base: 20)),
                      child: Padding(
                        padding: ResponsiveUtils.getCardPadding(context),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.darkBlue.withValues(alpha: 25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.people_alt_outlined,
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
                                    context.tr('Manage Users'),
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: ResponsiveUtils.getFontSize(context, base: 20),
                                    ),
                                  ),
                                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                                  Text(
                                    context.tr('View and manage all registered users'),
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
                    
                    _buildSearchAndFilters(),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
                    
                    // User list
                    _users.isEmpty
                        ? _buildEmptyState()
                        : _buildUserList(),
                    
                    // Loading indicator at bottom during pagination
                    if (_isLoadingMore)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
                  color: Colors.red.withValues(alpha: 25),
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
                context.tr('Error loading users'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
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
                onPressed: () => _loadUsers(),
                icon: const Icon(Icons.refresh),
                label: Text(
                  context.tr('Retry'),
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
                color: AppColors.lightGrey.withValues(alpha: 76),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 40, desktopSize: 40),
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
            Text(
              context.tr('No users found'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.darkGrey,
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, base: 18),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                _searchQuery.isNotEmpty
                    ? context.tr('No users match your search criteria. Try adjusting your search term.')
                    : _filterBy != 'All'
                        ? context.tr('No users match the selected filter. Try changing your filter options.')
                        : context.tr('There are no users in the system yet.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                ),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
            if (_filterBy != 'All' || _searchQuery.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _filterBy = 'All';
                    _searchController.clear();
                    _searchQuery = '';
                  });
                  _loadUsers(reset: true);
                },
                icon: const Icon(Icons.filter_list_off),
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

  Widget _buildUserList() {
    return _buildUsersList();
  }
} 
