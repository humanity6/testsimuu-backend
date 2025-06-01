import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../services/admin_service.dart';
import '../../models/ai_alert.dart';
import '../../models/scan_config.dart';
import '../../models/exam.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/responsive_admin_widgets.dart';
import 'ai_alerts/alert_detail_screen.dart';

class AdminAISearchManagementScreen extends StatefulWidget {
  const AdminAISearchManagementScreen({Key? key}) : super(key: key);

  @override
  State<AdminAISearchManagementScreen> createState() => _AdminAISearchManagementScreenState();
}

class _AdminAISearchManagementScreenState extends State<AdminAISearchManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  late AdminService _adminService;

  // Alerts data
  List<AIAlert> _alerts = [];
  List<AIAlert> _filteredAlerts = [];
  String _statusFilter = 'All';
  String _priorityFilter = 'All';

  // Scan configs data
  List<ScanConfig> _scanConfigs = [];
  List<Exam> _availableExams = [];

  // Form controllers for new scan config
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _maxQuestionsController = TextEditingController();
  final TextEditingController _promptTemplateController = TextEditingController();
  
  String _selectedFrequency = 'WEEKLY';
  bool _isActive = true;
  List<String> _selectedExamIds = [];

  final List<String> _statusOptions = ['All', 'New', 'Under Review', 'Action Taken', 'Dismissed'];
  final List<String> _priorityOptions = ['All', 'High', 'Medium', 'Low'];
  final List<String> _frequencyOptions = ['DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeAdminService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _maxQuestionsController.dispose();
    _promptTemplateController.dispose();
    super.dispose();
  }

  void _initializeAdminService() {
    final authService = context.authService;
    final user = authService.currentUser;
    final accessToken = authService.accessToken;
    
    if (user != null && accessToken != null && user.isStaff) {
      _adminService = AdminService(accessToken: accessToken);
      _loadAllData();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
    }
  }

  Future<void> _loadAllData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all data concurrently
      final results = await Future.wait([
        _adminService.getAIAlerts(),
        _adminService.getScanConfigs(),
        _adminService.getExams(),
      ]);

      setState(() {
        _alerts = results[0] as List<AIAlert>;
        _filteredAlerts = _alerts;
        _scanConfigs = (results[1] as List).map((config) => ScanConfig.fromJson(config)).toList();
        _availableExams = results[2] as List<Exam>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Alert methods
  void _filterAlerts() {
    setState(() {
      _filteredAlerts = _alerts.where((alert) {
        final statusMatch = _statusFilter == 'All' || 
            alert.status.toLowerCase() == _statusFilter.toLowerCase();
        final priorityMatch = _priorityFilter == 'All' || 
            alert.priority.toLowerCase() == _priorityFilter.toLowerCase();
        return statusMatch && priorityMatch;
      }).toList();
    });
  }

  Future<void> _updateAlertStatus(AIAlert alert, String newStatus) async {
    try {
      await _adminService.updateAlertStatus(alert.id, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('alert_status_updated', params: {'status': newStatus})),
          backgroundColor: Colors.green,
        ),
      );
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_to_update_alert', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Scan config methods
  Future<void> _createScanConfig() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final configData = {
        'name': _nameController.text,
        'frequency': _selectedFrequency,
        'max_questions_per_scan': int.parse(_maxQuestionsController.text),
        'is_active': _isActive,
        'prompt_template': _promptTemplateController.text.isNotEmpty
            ? _promptTemplateController.text
            : _getDefaultPromptTemplate(),
        'exams': _selectedExamIds.map((id) => int.parse(id)).toList(),
      };

      await _adminService.createScanConfig(configData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('scan_config_created')),
          backgroundColor: Colors.green,
        ),
      );

      _clearForm();
      _loadAllData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_to_create_scan_config', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleScanConfig(ScanConfig config) async {
    try {
      await _adminService.toggleScanConfig(config.id.toString());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('scan_config_toggled', params: {'status': config.isActive ? 'deactivated' : 'activated'})),
          backgroundColor: Colors.green,
        ),
      );

      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_to_toggle_scan_config', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _runScanManually(ScanConfig config) async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _adminService.runScanManually(config.id.toString());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('scan_queued_successfully', params: {'name': config.name})),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_to_run_scan', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearForm() {
    _nameController.clear();
    _maxQuestionsController.clear();
    _promptTemplateController.clear();
    setState(() {
      _selectedFrequency = 'WEEKLY';
      _isActive = true;
      _selectedExamIds.clear();
    });
  }

  String _getDefaultPromptTemplate() {
    return "You are an AI assistant helping to update educational content. "
           "Review the following exam questions for {topic_name}: {questions_data}. "
           "Use this additional context from web search: {web_search_results}. "
           "Identify any that may be outdated, incorrect, or could benefit from updates "
           "based on current knowledge and trends. For each question you flag, provide "
           "a brief explanation of why it needs updating.";
  }

  @override
  Widget build(BuildContext context) {
    final user = context.authService.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.search_outlined, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              context.tr('ai_search_management'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppColors.darkBlue,
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
          tabs: [
            Tab(
              icon: const Icon(Icons.dashboard_outlined),
              text: context.tr('overview'),
            ),
            Tab(
              icon: const Icon(Icons.notifications_outlined),
              text: context.tr('alerts'),
            ),
            Tab(
              icon: const Icon(Icons.settings_outlined),
              text: context.tr('settings'),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllData,
            tooltip: context.tr('refresh_data'),
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
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadAllData,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.tr('retry')),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildAlertsTab(),
                    _buildSettingsTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    final totalAlerts = _alerts.length;
    final newAlerts = _alerts.where((a) => a.status.toLowerCase() == 'new').length;
    final highPriorityAlerts = _alerts.where((a) => a.priority.toLowerCase() == 'high').length;
    final activeScanConfigs = _scanConfigs.where((c) => c.isActive).length;

    return SingleChildScrollView(
      padding: ResponsiveUtils.getScreenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Search System Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Statistics Cards
          GridView.count(
            crossAxisCount: ResponsiveUtils.isMobile(context) ? 2 : 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                'Total Alerts',
                totalAlerts.toString(),
                Icons.notifications_outlined,
                AppColors.blue,
              ),
              _buildStatCard(
                'New Alerts',
                newAlerts.toString(),
                Icons.notification_add_outlined,
                AppColors.orange,
              ),
              _buildStatCard(
                'High Priority',
                highPriorityAlerts.toString(),
                Icons.priority_high_outlined,
                AppColors.red,
              ),
              _buildStatCard(
                'Active Scans',
                activeScanConfigs.toString(),
                Icons.search_outlined,
                AppColors.green,
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Recent Alerts
          Text(
            'Recent Alerts',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_alerts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.notification_add_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No alerts found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._alerts.take(5).map((alert) => _buildAlertCard(alert, isCompact: true)),
          
          if (_alerts.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(context.tr('view_all_alerts', params: {'count': _alerts.length.toString()})),
                ),
              ),
            ),
          
          const SizedBox(height: 32),
          
          // Active Scan Configurations
          Text(
            'Active Scan Configurations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_scanConfigs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.settings_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No scan configurations found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ..._scanConfigs.where((c) => c.isActive).map((config) => _buildScanConfigCard(config, isCompact: true)),
          
          if (_scanConfigs.where((c) => c.isActive).length != _scanConfigs.length)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(2),
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(context.tr('manage_all_configurations')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _statusFilter,
                  items: _statusOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _statusFilter = newValue!;
                    });
                    _filterAlerts();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _priorityFilter,
                  items: _priorityOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _priorityFilter = newValue!;
                    });
                    _filterAlerts();
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Alerts List
        Expanded(
          child: _filteredAlerts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No alerts match your filters',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredAlerts.length,
                  itemBuilder: (context, index) {
                    return _buildAlertCard(_filteredAlerts[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: ResponsiveUtils.getScreenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scan Configurations',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Create New Configuration Form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Scan Configuration',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Configuration Name',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Daily Content Review',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a configuration name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Scan Frequency',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedFrequency,
                            items: _frequencyOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value.toLowerCase().replaceAll('_', ' ')),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedFrequency = newValue!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxQuestionsController,
                            decoration: const InputDecoration(
                              labelText: 'Max Questions per Scan',
                              border: OutlineInputBorder(),
                              hintText: '50',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter max questions';
                              }
                              final intValue = int.tryParse(value);
                              if (intValue == null || intValue <= 0) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Exam Selection
                    Text(
                      'Select Exams to Include:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _availableExams.length,
                        itemBuilder: (context, index) {
                          final exam = _availableExams[index];
                          return CheckboxListTile(
                            title: Text(exam.title),
                            subtitle: Text(context.tr('question_count', params: {'count': exam.questionCount.toString()})),
                            value: _selectedExamIds.contains(exam.id.toString()),
                            onChanged: (bool? selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedExamIds.add(exam.id.toString());
                                } else {
                                  _selectedExamIds.remove(exam.id.toString());
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _promptTemplateController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Custom Prompt Template (Optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Leave blank to use default template',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: Text(context.tr('active')),
                      subtitle: Text(context.tr('enable_scan_config')),
                      value: _isActive,
                      onChanged: (bool value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _createScanConfig,
                        icon: const Icon(Icons.add),
                        label: Text(context.tr('create_configuration')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Existing Configurations
          Text(
            'Existing Scan Configurations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_scanConfigs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No scan configurations created yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            ..._scanConfigs.map((config) => _buildScanConfigCard(config)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(AIAlert alert, {bool isCompact = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPriorityColor(alert.priority),
          child: Icon(
            _getPriorityIcon(alert.priority),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: isCompact ? 2 : null,
          overflow: isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.summaryOfPotentialChange,
              maxLines: isCompact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    alert.status,
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(alert.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: !isCompact
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'view') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AlertDetailScreen(alertId: alert.id),
                      ),
                    );
                  } else {
                    _updateAlertStatus(alert, value);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: ListTile(
                      leading: const Icon(Icons.visibility_outlined),
                      title: Text(context.tr('view_details')),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'UNDER_REVIEW',
                    child: ListTile(
                      leading: const Icon(Icons.rate_review_outlined),
                      title: Text(context.tr('mark_under_review')),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ACTION_TAKEN',
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(context.tr('mark_action_taken')),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'DISMISSED',
                    child: ListTile(
                      leading: const Icon(Icons.close_outlined),
                      title: Text(context.tr('dismiss')),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: isCompact
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AlertDetailScreen(alertId: alert.id),
                  ),
                )
            : null,
      ),
    );
  }

  Widget _buildScanConfigCard(ScanConfig config, {bool isCompact = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: config.isActive ? AppColors.green : Colors.grey,
          child: Icon(
            config.isActive ? Icons.play_arrow : Icons.pause,
            color: Colors.white,
          ),
        ),
        title: Text(
          config.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('frequency', params: {'value': config.frequency.toLowerCase()})),
            Text(context.tr('max_questions', params: {'value': config.maxQuestionsPerScan.toString()})),
            if (!isCompact) ...[
              Text(context.tr('last_run', params: {'date': config.lastRun != null ? _formatDate(config.lastRun!) : context.tr('never')})),
              Text(context.tr('next_run', params: {'date': config.nextScheduledRun != null ? _formatDate(config.nextScheduledRun!) : context.tr('not_scheduled')})),
            ],
          ],
        ),
        trailing: !isCompact
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      config.isActive ? Icons.pause : Icons.play_arrow,
                      color: config.isActive ? Colors.orange : AppColors.green,
                    ),
                    onPressed: () => _toggleScanConfig(config),
                    tooltip: config.isActive ? 'Pause' : 'Activate',
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline, color: AppColors.blue),
                    onPressed: config.isActive ? () => _runScanManually(config) : null,
                    tooltip: 'Run Now',
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.red;
      case 'medium':
        return AppColors.orange;
      case 'low':
        return AppColors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.remove;
      case 'low':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 