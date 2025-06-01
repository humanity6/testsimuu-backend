import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../models/topic.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../services/admin_service.dart';
import '../../../utils/api_config.dart';
import '../../../utils/responsive_utils.dart';
import '../../../widgets/responsive_admin_widgets.dart';

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({Key? key}) : super(key: key);

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  bool _isLoading = true;
  List<Topic> _topics = [];
  String? _errorMessage;
  late AdminService _adminService;
  final TextEditingController _searchController = TextEditingController();
  List<Topic> _filteredTopics = [];

  @override
  void initState() {
    super.initState();
    _initializeAdminService();
    _searchController.addListener(_filterTopics);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeAdminService() {
    try {
      final authService = context.authService;
      final user = authService.currentUser;
      final accessToken = authService.accessToken;
      
      if (user != null && accessToken != null && user.isStaff) {
        _adminService = AdminService(accessToken: accessToken);
        _checkApiAndLoadData();
      } else {
        // Handle case where user is not available or not authenticated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = context.tr('auth_error');
        _isLoading = false;
      });
    }
  }
  
  void _filterTopics() {
    if (_topics.isEmpty) return;
    
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      if (searchTerm.isEmpty) {
        _filteredTopics = List.from(_topics);
      } else {
        _filteredTopics = _topics.where((topic) {
          return topic.name.toLowerCase().contains(searchTerm) ||
              (topic.description?.toLowerCase().contains(searchTerm) ?? false);
        }).toList();
      }
    });
  }
  
  Future<void> _checkApiAndLoadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Check if API is available first
      final isApiAvailable = await ApiConfig.checkApiAvailability();
      if (!isApiAvailable) {
        if (mounted) {
          setState(() {
            _errorMessage = context.tr('api_unavailable');
            _isLoading = false;
          });
        }
        return;
      }

      // API is available, proceed with loading topics
      _loadTopics();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all topics (no exam filter for topics management screen)
      final topics = await _adminService.getTopics();
      
      setState(() {
        _topics = topics;
        _filteredTopics = List.from(_topics);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load topics: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading topics: $e');
    }
  }

  Future<void> _deleteTopic(String topicId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _adminService.deleteTopic(topicId);
      
      setState(() {
        _topics.removeWhere((topic) => topic.id == topicId);
        _filteredTopics.removeWhere((topic) => topic.id == topicId);
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('topic_deleted_successfully'))),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('failed_to_delete_topic')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Topic topic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete')),
        content: Text(context.tr('delete_topic_confirmation', params: {'name': topic.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTopic(topic.id);
            },
            child: Text(
              context.tr('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddEditTopic([Topic? topic]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TopicFormScreen(topic: topic),
        fullscreenDialog: true,
      ),
    ).then((_) => _loadTopics());
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAdminScaffold(
      title: context.tr('topics_management'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditTopic(),
        backgroundColor: AppColors.darkBlue,
        child: Icon(
          Icons.add,
          size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            _buildHeaderSection(),
            Expanded(
              child: _errorMessage != null
                ? _buildErrorState()
                : _topics.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : _buildTopicsContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Padding(
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: ResponsiveUtils.getCardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 8)),
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.category_outlined,
                      color: AppColors.darkBlue,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 26, desktopSize: 28),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('topics_management'),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBlue,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                        Text(
                          context.tr('manage_your_topics_and_subtopics'),
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                            color: AppColors.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!ResponsiveUtils.isMobile(context))
                    _buildAddTopicButton(),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.tr('search_topics'),
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                    vertical: ResponsiveUtils.getSpacing(context, base: 12),
                  ),
                  fillColor: Colors.grey.shade50,
                  filled: true,
                ),
              ),
              if (_topics.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: ResponsiveUtils.getSpacing(context, base: 16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_filteredTopics.length} ${context.tr('topics_found')}',
                        style: TextStyle(
                          color: AppColors.darkGrey,
                          fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        ),
                      ),
                      if (ResponsiveUtils.isMobile(context))
                        _buildAddTopicButton(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddTopicButton() {
    return ElevatedButton.icon(
      onPressed: () => _navigateToAddEditTopic(),
      icon: Icon(
        Icons.add,
        size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
      ),
      label: Text(context.tr('add_topic')),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkBlue,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getSpacing(context, base: 16),
          vertical: ResponsiveUtils.getSpacing(context, base: 10),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveUtils.getScreenPadding(context),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded, 
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 40, desktopSize: 40), 
                  color: Colors.red,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
              Text(
                context.tr('error_loading_topics'),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
              Container(
                constraints: BoxConstraints(maxWidth: 500),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 32)),
              CustomButton(
                onPressed: _checkApiAndLoadData,
                text: context.tr('retry'),
                icon: Icons.refresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadTopics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveUtils.getScreenPadding(context),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 24)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.category_outlined, 
                    size: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 40, desktopSize: 40), 
                    color: AppColors.lightBlue,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
                Text(
                  context.tr('no_topics_found'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                Container(
                  constraints: BoxConstraints(maxWidth: 500),
                  child: Text(
                    context.tr('add_first_topic'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 32)),
                CustomButton(
                  onPressed: () => _navigateToAddEditTopic(),
                  text: context.tr('add_first_topic_button'),
                  icon: Icons.add,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopicsContent() {
    return RefreshIndicator(
      onRefresh: _loadTopics,
      child: _filteredTopics.isEmpty && _searchController.text.isNotEmpty
          ? _buildNoSearchResultsState()
          : _buildTopicsList(context),
    );
  }

  Widget _buildNoSearchResultsState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: ResponsiveUtils.getScreenPadding(context),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off, 
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 40, desktopSize: 40), 
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
              Text(
                context.tr('no_search_results'),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
              Container(
                constraints: BoxConstraints(maxWidth: 500),
                child: Text(
                  context.tr('try_different_search'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 32)),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                },
                icon: Icon(Icons.clear),
                label: Text(context.tr('clear_search')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicsList(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = ResponsiveUtils.isDesktop(context);
        final isTablet = ResponsiveUtils.isTablet(context);
        
        if (isDesktop) {
          // Desktop: Grid layout with 2-3 columns
          final crossAxisCount = constraints.maxWidth > 1200 ? 3 : 2;
          return _buildTopicsGrid(context, crossAxisCount: crossAxisCount);
        } else if (isTablet) {
          // Tablet: Grid layout with 2 columns
          return _buildTopicsGrid(context, crossAxisCount: 2);
        } else {
          // Mobile: Single column list
          return _buildTopicsListView(context);
        }
      },
    );
  }

  Widget _buildTopicsGrid(BuildContext context, {required int crossAxisCount}) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: ResponsiveUtils.getScreenPadding(context),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: ResponsiveUtils.getSpacing(context, base: 16),
            mainAxisSpacing: ResponsiveUtils.getSpacing(context, base: 16),
            childAspectRatio: 1.0,
          ),
          itemCount: _filteredTopics.length,
          itemBuilder: (context, index) {
            final topic = _filteredTopics[index];
            return _buildTopicCard(topic);
          },
        ),
      ),
    );
  }

  Widget _buildTopicsListView(BuildContext context) {
    return ListView.builder(
      padding: ResponsiveUtils.getScreenPadding(context),
      itemCount: _filteredTopics.length,
      itemBuilder: (context, index) {
        final topic = _filteredTopics[index];
        return Padding(
          padding: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, base: 12)),
          child: _buildTopicCard(topic),
        );
      },
    );
  }

  Widget _buildTopicCard(Topic topic) {
    final bool isSubtopic = topic.parentTopicId != null;
    final String? parentName = isSubtopic
        ? _topics
            .firstWhere((t) => t.id == topic.parentTopicId,
                orElse: () => Topic(
                  id: '', 
                  name: 'Unknown', 
                  slug: '', 
                  displayOrder: 0, 
                  isActive: true,
                ))
            .name
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveUtils.isMobile(context);
        final isDesktop = ResponsiveUtils.isDesktop(context);
        
        if (isDesktop && constraints.maxWidth > 300) {
          // Desktop grid card layout
          return _buildGridTopicCard(topic, isSubtopic, parentName);
        } else {
          // Mobile/tablet list tile layout
          return _buildListTopicCard(topic, isSubtopic, parentName, isMobile);
        }
      },
    );
  }

  Widget _buildGridTopicCard(Topic topic, bool isSubtopic, String? parentName) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToAddEditTopic(topic),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with colored background
            Container(
              padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
              decoration: BoxDecoration(
                color: isSubtopic ? AppColors.lightBlue.withOpacity(0.9) : AppColors.darkBlue.withOpacity(0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                    backgroundColor: Colors.white.withOpacity(0.9),
                    child: Icon(
                      isSubtopic ? Icons.subdirectory_arrow_right : Icons.category,
                      color: isSubtopic ? AppColors.lightBlue : AppColors.darkBlue,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                    ),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 12)),
                  Expanded(
                    child: Text(
                      topic.name,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status indicator
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 8),
                        vertical: ResponsiveUtils.getSpacing(context, base: 4),
                      ),
                      decoration: BoxDecoration(
                        color: topic.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        topic.isActive ? context.tr('active') : context.tr('inactive'),
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                          fontWeight: FontWeight.w500,
                          color: topic.isActive ? Colors.green : Colors.grey,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                    
                    // Description
                    if (topic.description != null && topic.description!.isNotEmpty)
                      Expanded(
                        child: Text(
                          topic.description!,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                            color: Colors.grey[700],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Expanded(
                        child: Center(
                          child: Text(
                            context.tr('no_description'),
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    
                    // Parent topic info
                    if (isSubtopic && parentName != null) ...[
                      SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
                      Container(
                        padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 8)),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_tree_outlined,
                              size: ResponsiveUtils.getIconSize(context, mobileSize: 14, tabletSize: 14, desktopSize: 14),
                              color: AppColors.darkBlue,
                            ),
                            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                            Expanded(
                              child: Text(
                                '${context.tr('parent_topic')}: $parentName',
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                                  color: Colors.grey[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Action buttons
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getSpacing(context, base: 12),
                vertical: ResponsiveUtils.getSpacing(context, base: 8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Display order
                  Text(
                    '${context.tr('order')}: ${topic.displayOrder}',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                      color: Colors.grey[600],
                    ),
                  ),
                  // Action buttons
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.edit, 
                          color: AppColors.darkBlue,
                          size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                        ),
                        onPressed: () => _navigateToAddEditTopic(topic),
                        tooltip: context.tr('edit_topic'),
                        padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 4)),
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                      IconButton(
                        icon: Icon(
                          Icons.delete, 
                          color: Colors.red,
                          size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                        ),
                        onPressed: () => _showDeleteConfirmation(topic),
                        tooltip: context.tr('delete_topic'),
                        padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 4)),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTopicCard(Topic topic, bool isSubtopic, String? parentName, bool isMobile) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(
        left: isSubtopic && !isMobile ? ResponsiveUtils.getSpacing(context, base: 16) : 0,
        right: 0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => _navigateToAddEditTopic(topic),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: ResponsiveUtils.getCardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                    backgroundColor: isSubtopic ? AppColors.lightBlue : AppColors.darkBlue,
                    child: Icon(
                      isSubtopic ? Icons.subdirectory_arrow_right : Icons.category,
                      color: Colors.white,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
                    ),
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
                                topic.name,
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.getSpacing(context, base: 8),
                                vertical: ResponsiveUtils.getSpacing(context, base: 4),
                              ),
                              decoration: BoxDecoration(
                                color: topic.isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                topic.isActive ? context.tr('active') : context.tr('inactive'),
                                style: TextStyle(
                                  fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                                  fontWeight: FontWeight.w500,
                                  color: topic.isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (topic.description != null && topic.description!.isNotEmpty) ...[
                          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
                          Text(
                            topic.description!,
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                              color: Colors.grey[600],
                            ),
                            maxLines: isMobile ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (isSubtopic && parentName != null) ...[
                          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.getSpacing(context, base: 8),
                              vertical: ResponsiveUtils.getSpacing(context, base: 4),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.account_tree_outlined,
                                  size: ResponsiveUtils.getIconSize(context, mobileSize: 14, tabletSize: 14, desktopSize: 14),
                                  color: AppColors.darkBlue,
                                ),
                                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 4)),
                                Flexible(
                                  child: Text(
                                    '${context.tr('parent_topic')}: $parentName',
                                    style: TextStyle(
                                      fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Display order
                  Text(
                    '${context.tr('order')}: ${topic.displayOrder}',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                      color: Colors.grey[600],
                    ),
                  ),
                  // Actions
                  isMobile 
                    ? PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _navigateToAddEditTopic(topic);
                          } else if (value == 'delete') {
                            _showDeleteConfirmation(topic);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit, color: AppColors.darkBlue),
                                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                                Text(context.tr('edit')),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                                Text(context.tr('delete')),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            icon: Icon(
                              Icons.edit, 
                              color: AppColors.darkBlue,
                              size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
                            ),
                            label: Text(
                              context.tr('edit'),
                              style: TextStyle(
                                color: AppColors.darkBlue,
                                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                              ),
                            ),
                            onPressed: () => _navigateToAddEditTopic(topic),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.getSpacing(context, base: 12),
                                vertical: ResponsiveUtils.getSpacing(context, base: 8),
                              ),
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                          TextButton.icon(
                            icon: Icon(
                              Icons.delete, 
                              color: Colors.red,
                              size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
                            ),
                            label: Text(
                              context.tr('delete'),
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                              ),
                            ),
                            onPressed: () => _showDeleteConfirmation(topic),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: ResponsiveUtils.getSpacing(context, base: 12),
                                vertical: ResponsiveUtils.getSpacing(context, base: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopicFormScreen extends StatefulWidget {
  final Topic? topic;

  const TopicFormScreen({
    Key? key,
    this.topic,
  }) : super(key: key);

  @override
  State<TopicFormScreen> createState() => _TopicFormScreenState();
}

class _TopicFormScreenState extends State<TopicFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _slugController = TextEditingController();
  String? _selectedParentId;
  int _displayOrder = 0;
  bool _isActive = true;
  bool _isLoading = false;
  List<Topic> _parentTopics = [];
  late AdminService _adminService;

  @override
  void initState() {
    super.initState();
    _initializeAdminService();
  }

  void _initializeAdminService() {
    try {
      final authService = context.authService;
      final user = authService.currentUser;
      final accessToken = authService.accessToken;
      
      if (user != null && accessToken != null && user.isStaff) {
        _adminService = AdminService(accessToken: accessToken);
        _loadParentTopics();

        if (widget.topic != null) {
          _nameController.text = widget.topic!.name;
          _descriptionController.text = widget.topic!.description ?? '';
          _slugController.text = widget.topic!.slug;
          _selectedParentId = widget.topic!.parentTopicId;
          _displayOrder = widget.topic!.displayOrder;
          _isActive = widget.topic!.isActive;
        }
      } else {
        // Handle case where user is not available or not authenticated
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('auth_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _loadParentTopics() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load all topics (no exam filter for parent topic selection)
      final topics = await _adminService.getTopics();
      
      // Filter out the current topic if we're in edit mode to avoid circular parent references
      final filteredTopics = widget.topic != null 
        ? topics.where((t) => t.id != widget.topic!.id).toList()
        : topics;
      
      setState(() {
        _parentTopics = filteredTopics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.tr('failed_to_load_parent_topics')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateSlug() {
    if (_nameController.text.isNotEmpty) {
      final slug = _nameController.text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-');
      
      setState(() {
        _slugController.text = slug;
      });
    }
  }

  Future<void> _saveTopic() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final topic = Topic(
        id: widget.topic?.id ?? '',
        name: _nameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        slug: _slugController.text,
        parentTopicId: _selectedParentId,
        displayOrder: _displayOrder,
        isActive: _isActive,
      );
      
      if (widget.topic == null) {
        // Create new topic
        await _adminService.createTopic(topic);
        print('Created new topic: ${topic.name}');
      } else {
        // Update existing topic
        await _adminService.updateTopic(widget.topic!.id, topic);
        print('Updated topic: ${topic.name}');
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.topic == null
                  ? context.tr('topic_created_successfully')
                  : context.tr('topic_updated_successfully'),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.topic == null
                  ? context.tr('failed_to_create_topic')
                  : context.tr('failed_to_update_topic')}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: context.tr('retry'),
              textColor: Colors.white,
              onPressed: _saveTopic,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.topic == null
              ? context.tr('add_topic')
              : context.tr('edit_topic'),
        ),
        elevation: 2,
        backgroundColor: AppColors.darkBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
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
        ),
        actions: [
          if (widget.topic != null)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                Navigator.of(context).pop();
                // Pass the topic back to the parent screen to handle deletion
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && Navigator.of(context).canPop()) {
                    final state = context.findAncestorStateOfType<_TopicsScreenState>();
                    if (state != null) {
                      state._showDeleteConfirmation(widget.topic!);
                    }
                  }
                });
              },
              tooltip: context.tr('delete_topic'),
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
              child: _parentTopics.isEmpty && !_isLoading
                  ? _buildErrorState()
                  : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline, 
                size: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 40, desktopSize: 40), 
                color: Colors.orange,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
            Text(
              context.tr('failed_to_load_parent_topics'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            Text(
              context.tr('need_parent_topics_to_create'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 32)),
            CustomButton(
              onPressed: _loadParentTopics,
              text: context.tr('retry'),
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: ResponsiveUtils.getCardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form header
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 8)),
                        decoration: BoxDecoration(
                          color: AppColors.darkBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          widget.topic == null ? Icons.add_circle_outline : Icons.edit_outlined,
                          color: AppColors.darkBlue,
                          size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getSpacing(context, base: 12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.topic == null
                                  ? context.tr('add_new_topic')
                                  : context.tr('edit_existing_topic'),
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkBlue,
                              ),
                            ),
                            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                            Text(
                              widget.topic == null
                                  ? context.tr('create_new_topic_description')
                                  : context.tr('edit_topic_description'),
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                                color: AppColors.mediumGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
                  
                  // Basic info section
                  Text(
                    context.tr('basic_information'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                  
                  // Topic name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.tr('topic_name'),
                      hintText: context.tr('enter_topic_name'),
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
                      prefixIcon: Icon(Icons.title, color: AppColors.darkBlue.withOpacity(0.7)),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                        vertical: ResponsiveUtils.getSpacing(context, base: 12),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('topic_name_required');
                      }
                      return null;
                    },
                    onChanged: (_) => _generateSlug(),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                  
                  // Description field
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: context.tr('topic_description'),
                      hintText: context.tr('enter_topic_description'),
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
                      prefixIcon: Icon(Icons.description, color: AppColors.darkBlue.withOpacity(0.7)),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                        vertical: ResponsiveUtils.getSpacing(context, base: 12),
                      ),
                      alignLabelWithHint: true,
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 15),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                  
                  // Slug field
                  TextFormField(
                    controller: _slugController,
                    decoration: InputDecoration(
                      labelText: context.tr('topic_slug'),
                      hintText: context.tr('enter_topic_slug'),
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
                      prefixIcon: Icon(Icons.link, color: AppColors.darkBlue.withOpacity(0.7)),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.refresh, color: AppColors.darkBlue),
                        onPressed: _generateSlug,
                        tooltip: context.tr('generate_slug'),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                        vertical: ResponsiveUtils.getSpacing(context, base: 12),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 15),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('topic_slug_required');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 20)),
          
          // Advanced settings card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: ResponsiveUtils.getCardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Text(
                    context.tr('advanced_settings'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                  
                  // Parent topic field
                  DropdownButtonFormField<String?>(
                    value: _selectedParentId,
                    decoration: InputDecoration(
                      labelText: context.tr('parent_topic'),
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
                      prefixIcon: Icon(Icons.account_tree, color: AppColors.darkBlue.withOpacity(0.7)),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                        vertical: ResponsiveUtils.getSpacing(context, base: 12),
                      ),
                    ),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 15),
                      color: AppColors.darkGrey,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(context.tr('no_parent_topic')),
                      ),
                      ..._parentTopics.map((topic) {
                        return DropdownMenuItem<String?>(
                          value: topic.id,
                          child: Text(
                            topic.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedParentId = value;
                      });
                    },
                    icon: Icon(Icons.arrow_drop_down, color: AppColors.darkBlue),
                    isExpanded: true,
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                  
                  // Display order and active status
                  ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isTablet(context)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildDisplayOrderField(),
                          ),
                          SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                          Expanded(
                            child: _buildActiveSwitch(),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildDisplayOrderField(),
                          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                          _buildActiveSwitch(),
                        ],
                      ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
          
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(
                widget.topic == null ? Icons.add : Icons.save,
                size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
              ),
              label: Text(
                widget.topic == null
                    ? context.tr('create_topic')
                    : context.tr('update_topic'),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _saveTopic,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.getSpacing(context, base: 16),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
          
          // Cancel button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              child: Text(
                context.tr('cancel'),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkGrey,
                side: BorderSide(color: Colors.grey.shade300),
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.getSpacing(context, base: 16),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDisplayOrderField() {
    return TextFormField(
      initialValue: _displayOrder.toString(),
      decoration: InputDecoration(
        labelText: context.tr('display_order'),
        hintText: context.tr('enter_display_order'),
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
        prefixIcon: Icon(Icons.sort, color: AppColors.darkBlue.withOpacity(0.7)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getSpacing(context, base: 16),
          vertical: ResponsiveUtils.getSpacing(context, base: 12),
        ),
      ),
      style: TextStyle(
        fontSize: ResponsiveUtils.getFontSize(context, base: 15),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return context.tr('display_order_required');
        }
        if (int.tryParse(value) == null) {
          return context.tr('display_order_must_be_number');
        }
        return null;
      },
      onChanged: (value) {
        setState(() {
          _displayOrder = int.tryParse(value) ?? _displayOrder;
        });
      },
    );
  }
  
  Widget _buildActiveSwitch() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        title: Text(
          context.tr('active'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 15),
          ),
        ),
        subtitle: Text(
          context.tr('topic_active_description'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 13),
            color: AppColors.mediumGrey,
          ),
        ),
        value: _isActive,
        onChanged: (value) {
          setState(() {
            _isActive = value;
          });
        },
        activeColor: AppColors.darkBlue,
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getSpacing(context, base: 16),
          vertical: ResponsiveUtils.getSpacing(context, base: 4),
        ),
      ),
    );
  }
} 
