import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../services/admin_service.dart';
import '../../../utils/api_config.dart';

class ExamFormScreen extends StatefulWidget {
  final String? examId;

  const ExamFormScreen({Key? key, this.examId}) : super(key: key);

  @override
  State<ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends State<ExamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late AdminService _adminService;
  bool _isLoading = false;
  bool _isLoadingData = false;
  String? _error;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _slugController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _displayOrderController = TextEditingController();

  // Form state
  String? _selectedParentExam;
  bool _isActive = true;
  List<Map<String, dynamic>> _parentExams = [];
  bool _autoGenerateSlug = true;

  bool get _isEditing => widget.examId != null;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  void _initializeService() {
    try {
      final authService = context.authService;
      final accessToken = authService.accessToken;
      
      if (accessToken != null) {
        _adminService = AdminService(accessToken: accessToken);
        _loadData();
      } else {
        setState(() {
          _error = 'Authentication required';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _error = null;
      });

      // Check API availability
      final isApiAvailable = await ApiConfig.checkApiAvailability();
      if (!isApiAvailable) {
        setState(() {
          _error = context.tr('api_unavailable');
          _isLoadingData = false;
        });
        return;
      }

      // Load parent exams
      final allExams = await _adminService.getAdminExams();
      final parentExams = allExams.where((exam) => exam['parent_exam'] == null).toList();

      // If editing, load exam details
      Map<String, dynamic>? examData;
      if (_isEditing) {
        examData = await _adminService.getAdminExamDetails(widget.examId!);
      }

      setState(() {
        _parentExams = parentExams;
        
        if (examData != null) {
          _nameController.text = examData['name'] ?? '';
          _slugController.text = examData['slug'] ?? '';
          _descriptionController.text = examData['description'] ?? '';
          _displayOrderController.text = examData['display_order']?.toString() ?? '0';
          _selectedParentExam = examData['parent_exam']?.toString();
          _isActive = examData['is_active'] ?? true;
          _autoGenerateSlug = false; // Don't auto-generate when editing
        } else {
          _displayOrderController.text = '0';
        }
        
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoadingData = false;
      });
    }
  }

  String _generateSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  void _onNameChanged(String value) {
    if (_autoGenerateSlug) {
      setState(() {
        _slugController.text = _generateSlug(value);
      });
    }
  }

  Future<void> _saveExam() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final examData = {
        'name': _nameController.text.trim(),
        'slug': _slugController.text.trim(),
        'description': _descriptionController.text.trim(),
        'display_order': int.tryParse(_displayOrderController.text) ?? 0,
        'is_active': _isActive,
      };

      // Add parent exam if selected
      if (_selectedParentExam != null && _selectedParentExam!.isNotEmpty) {
        examData['parent_exam'] = int.parse(_selectedParentExam!);
      }

      if (_isEditing) {
        await _adminService.updateExam(widget.examId!, examData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('exam_updated_successfully')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _adminService.createExam(examData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('exam_created_successfully')),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Failed to save exam: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isEditing ? context.tr('edit_exam') : context.tr('create_exam'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoadingData)
            TextButton.icon(
              onPressed: _isLoading ? null : _saveExam,
              icon: _isLoading 
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                context.tr('save'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoadingData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading exam data...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error Occurred',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: Text(context.tr('retry')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderSection(),
                        const SizedBox(height: 20),
                        _buildBasicInfoSection(),
                        const SizedBox(height: 20),
                        _buildHierarchySection(),
                        const SizedBox(height: 20),
                        _buildSettingsSection(),
                        const SizedBox(height: 32),
                        _buildActionButtons(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkBlue.withOpacity(0.1), Colors.blue.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.darkBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isEditing ? Icons.edit : Icons.add,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? context.tr('edit_exam') : context.tr('create_new_exam'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditing 
                      ? context.tr('modify_exam_details_below')
                      : context.tr('fill_exam_details_below'),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.darkBlue),
                const SizedBox(width: 8),
                Text(
                  context.tr('basic_information'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('exam_name'),
                hintText: context.tr('enter_exam_name'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.quiz, color: AppColors.darkBlue, size: 20),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('exam_name_required');
                }
                if (value.trim().length < 3) {
                  return context.tr('exam_name_too_short');
                }
                return null;
              },
              onChanged: _onNameChanged,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _slugController,
                    decoration: InputDecoration(
                      labelText: context.tr('exam_slug'),
                      hintText: context.tr('enter_exam_slug'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.darkBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.link, color: AppColors.darkBlue, size: 20),
                      ),
                      helperText: context.tr('slug_help_text'),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.tr('exam_slug_required');
                      }
                      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(value.trim())) {
                        return context.tr('invalid_slug_format');
                      }
                      return null;
                    },
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          _autoGenerateSlug = false;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Checkbox(
                              value: _autoGenerateSlug,
                              onChanged: (value) {
                                setState(() {
                                  _autoGenerateSlug = value ?? false;
                                  if (_autoGenerateSlug) {
                                    _slugController.text = _generateSlug(_nameController.text);
                                  }
                                });
                              },
                              activeColor: AppColors.darkBlue,
                            ),
                            Text(
                              context.tr('auto_generate'),
                              style: const TextStyle(fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: context.tr('description'),
                hintText: context.tr('enter_exam_description'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.description, color: AppColors.darkBlue, size: 20),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 3,
              validator: (value) {
                if (value != null && value.trim().length > 500) {
                  return context.tr('description_too_long');
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchySection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree, color: AppColors.darkBlue),
                const SizedBox(width: 8),
                Text(
                  context.tr('hierarchy_settings'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedParentExam,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('parent_exam'),
                hintText: context.tr('select_parent_exam'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.account_tree, color: AppColors.darkBlue, size: 20),
                ),
                helperText: context.tr('parent_exam_help_text'),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(context.tr('no_parent_exam')),
                ),
                ..._parentExams.map((exam) => DropdownMenuItem<String>(
                  value: exam['id'].toString(),
                  child: Text(
                    exam['name'] ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedParentExam = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayOrderController,
              decoration: InputDecoration(
                labelText: context.tr('display_order'),
                hintText: context.tr('enter_display_order'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.sort, color: AppColors.darkBlue, size: 20),
                ),
                helperText: context.tr('display_order_help_text'),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final order = int.tryParse(value);
                  if (order == null) {
                    return context.tr('invalid_display_order');
                  }
                  if (order < 0) {
                    return context.tr('display_order_must_be_positive');
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: AppColors.darkBlue),
                const SizedBox(width: 8),
                Text(
                  context.tr('exam_settings'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Icon(
                      _isActive ? Icons.visibility : Icons.visibility_off,
                      color: _isActive ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('active_status'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(left: 28, top: 4),
                  child: Text(
                    _isActive 
                        ? context.tr('exam_is_active_description')
                        : context.tr('exam_is_inactive_description'),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                activeColor: AppColors.darkBlue,
                activeTrackColor: AppColors.darkBlue.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                label: Text(context.tr('cancel')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveExam,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(_isEditing ? Icons.update : Icons.add),
                label: Text(
                  _isLoading 
                      ? context.tr('saving...')
                      : (_isEditing ? context.tr('update_exam') : context.tr('create_exam')),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 