import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../widgets/language_selector.dart';
import '../../../providers/app_providers.dart';
import '../../../services/admin_service.dart';
import '../../../models/scan_config.dart';
import '../../../models/exam.dart';
import '../../../utils/responsive_utils.dart';
import '../../../widgets/responsive_admin_widgets.dart';

class AdminAISearchSettingsScreen extends StatefulWidget {
  const AdminAISearchSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AdminAISearchSettingsScreen> createState() => _AdminAISearchSettingsScreenState();
}

class _AdminAISearchSettingsScreenState extends State<AdminAISearchSettingsScreen> {
  bool _isLoading = true;
  List<ScanConfig> _scanConfigs = [];
  List<Exam> _availableExams = [];
  String? _error;
  late AdminService _adminService;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _maxQuestionsController = TextEditingController();
  final TextEditingController _promptTemplateController = TextEditingController();
  
  String _selectedFrequency = 'WEEKLY';
  bool _isActive = true;
  List<String> _selectedExamIds = [];

  final List<String> _frequencyOptions = ['DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY'];

  @override
  void initState() {
    super.initState();
    _initializeAdminService();
  }

  @override
  void dispose() {
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
      _loadData();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final scanConfigs = await _adminService.getScanConfigs();
      final exams = await _adminService.getExams();

      setState(() {
        _scanConfigs = scanConfigs;
        _availableExams = exams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

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
          content: Text(context.tr('scan_config_created_successfully')),
          backgroundColor: Colors.green,
        ),
      );

      _clearForm();
      _loadData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create scan configuration: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleScanConfig(ScanConfig config) async {
    try {
      await _adminService.toggleScanConfig(config.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan configuration ${config.isActive ? 'deactivated' : 'activated'}'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle scan configuration: ${e.toString()}'),
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

      await _adminService.runScanManually(config.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan queued successfully for: ${config.name}'),
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
          content: Text('Failed to run scan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteScanConfig(ScanConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_deletion')),
        content: Text('Are you sure you want to delete "${config.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              context.tr('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _adminService.deleteScanConfig(config.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan configuration deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete scan configuration: ${e.toString()}'),
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
    return '''Analyze recent developments in {topic_name} and suggest content updates for the following questions:

{questions_data}

Based on the following web search results:

{web_search_results}

Please provide a JSON response with potential updates needed for the questions.''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr('ai_search_settings'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 24),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: ResponsiveUtils.getIconSize(context),
            ),
            onPressed: _isLoading ? null : _loadData,
          ),
          const LanguageSelector(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: ResponsiveUtils.getIconSize(context, mobileSize: 48, tabletSize: 64, desktopSize: 64),
                        color: Colors.red,
                      ),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text(context.tr('retry')),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: ResponsiveUtils.getScreenPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCreateConfigSection(),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, base: 32)),
                      _buildExistingConfigsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCreateConfigSection() {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Card(
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('create_new_scan_configuration'),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              
              if (isMobile) ...[
                _buildNameField(),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                _buildFrequencyDropdown(),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                _buildMaxQuestionsField(),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                _buildActiveSwitch(),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                _buildExamSelector(),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                _buildPromptTemplateField(),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _buildNameField()),
                    SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                    Expanded(child: _buildFrequencyDropdown()),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                Row(
                  children: [
                    Expanded(child: _buildMaxQuestionsField()),
                    SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                    Expanded(child: _buildActiveSwitch()),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                _buildExamSelector(),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                _buildPromptTemplateField(),
              ],
              
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createScanConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveUtils.getSpacing(context, base: 16),
                    ),
                  ),
                  child: Text(
                    context.tr('create_configuration'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: context.tr('configuration_name'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return context.tr('please_enter_configuration_name');
        }
        return null;
      },
    );
  }

  Widget _buildFrequencyDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: context.tr('scan_frequency'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      value: _selectedFrequency,
      items: _frequencyOptions.map((String value) {
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
          _selectedFrequency = newValue!;
        });
      },
    );
  }

  Widget _buildMaxQuestionsField() {
    return TextFormField(
      controller: _maxQuestionsController,
      decoration: InputDecoration(
        labelText: context.tr('max_questions_per_scan'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return context.tr('please_enter_max_questions');
        }
        final number = int.tryParse(value);
        if (number == null || number <= 0) {
          return context.tr('please_enter_valid_number');
        }
        return null;
      },
    );
  }

  Widget _buildActiveSwitch() {
    return Row(
      children: [
        Text(
          context.tr('is_active'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 16),
          ),
        ),
        const Spacer(),
        Switch(
          value: _isActive,
          onChanged: (value) {
            setState(() {
              _isActive = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildExamSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('select_exams'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 16),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            children: _availableExams.map((exam) {
              final isSelected = _selectedExamIds.contains(exam.id.toString());
              return CheckboxListTile(
                title: Text(exam.name),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedExamIds.add(exam.id.toString());
                    } else {
                      _selectedExamIds.remove(exam.id.toString());
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptTemplateField() {
    return TextFormField(
      controller: _promptTemplateController,
      decoration: InputDecoration(
        labelText: context.tr('custom_prompt_template_optional'),
        hintText: context.tr('leave_empty_for_default_template'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
      maxLines: 5,
    );
  }

  Widget _buildExistingConfigsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('existing_configurations'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
        
        if (_scanConfigs.isEmpty) ...[
          Card(
            child: Padding(
              padding: ResponsiveUtils.getCardPadding(context),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: ResponsiveUtils.getIconSize(context, mobileSize: 48, tabletSize: 64, desktopSize: 64),
                      color: Colors.grey,
                    ),
                    SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
                    Text(
                      context.tr('no_scan_configurations_found'),
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _scanConfigs.length,
            itemBuilder: (context, index) {
              final config = _scanConfigs[index];
              return _buildConfigCard(config);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildConfigCard(ScanConfig config) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getSpacing(context, base: 16),
      ),
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    config.name,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusChip(config.isActive),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
            
            if (isMobile) ...[
              _buildConfigInfo(config),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              _buildConfigActions(config),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildConfigInfo(config),
                  ),
                  SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                  Expanded(
                    flex: 1,
                    child: _buildConfigActions(config),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfigInfo(ScanConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.tr('frequency')}: ${config.frequency}',
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
        Text(
          '${context.tr('max_questions')}: ${config.maxQuestionsPerScan}',
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
        Text(
          '${context.tr('exams')}: ${config.exams.map((e) => e.name).join(', ')}',
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
          ),
        ),
        if (config.lastRun != null) ...[
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
          Text(
            '${context.tr('last_run')}: ${config.lastRun!.toLocal()}',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 12),
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfigActions(ScanConfig config) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(
              config.isActive ? Icons.pause : Icons.play_arrow,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
            ),
            label: Text(config.isActive ? context.tr('deactivate') : context.tr('activate')),
            onPressed: () => _toggleScanConfig(config),
            style: ElevatedButton.styleFrom(
              backgroundColor: config.isActive ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(
              Icons.play_circle,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
            ),
            label: Text(context.tr('run_now')),
            onPressed: config.isActive ? () => _runScanManually(config) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(
              Icons.delete,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
            ),
            label: Text(context.tr('delete')),
            onPressed: () => _deleteScanConfig(config),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Chip(
      label: Text(isActive ? context.tr('active') : context.tr('inactive')),
      backgroundColor: isActive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isActive ? Colors.green : Colors.grey,
        fontSize: ResponsiveUtils.getFontSize(context, base: 12),
      ),
    );
  }
} 