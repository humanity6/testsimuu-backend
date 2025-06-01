import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/language_selector.dart';
import '../../../services/admin_service.dart';
import '../../../utils/api_config.dart';
import '../../../utils/responsive_utils.dart';
import '../../../utils/string_utils.dart';

class ReferralProgramsScreen extends StatefulWidget {
  const ReferralProgramsScreen({Key? key}) : super(key: key);

  @override
  State<ReferralProgramsScreen> createState() => _ReferralProgramsScreenState();
}

class _ReferralProgramsScreenState extends State<ReferralProgramsScreen> {
  bool _isLoading = true;
  List<ReferralProgram> _programs = [];
  ReferralProgram? _selectedProgram;
  bool _showAddEditForm = false;
  String? _error;
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
        _loadPrograms();
      } else if (user == null || accessToken == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/login');
          }
        });
      } else if (!user.isStaff) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _error = 'You do not have admin privileges to access this panel';
              _isLoading = false;
            });
          }
        });
      }
    } catch (e) {
      print('Error initializing admin service: $e');
      _adminService = AdminService(accessToken: null);
      setState(() {
        _error = 'Authentication error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPrograms() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check if API is available first
      final isApiAvailable = await ApiConfig.checkApiAvailability();
      if (!isApiAvailable) {
        if (mounted) {
          setState(() {
            _error = context.tr('api_unavailable');
            _isLoading = false;
          });
        }
        return;
      }

      final response = await _adminService.getReferralPrograms();
      final programs = response.map((data) => ReferralProgram.fromJson(data)).toList();
      
      setState(() {
        _programs = programs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load referral programs: $e';
        _isLoading = false;
      });
      print('Error loading referral programs: $e');
      
      // Show user-friendly error message for common issues
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        setState(() {
          _error = 'Authentication failed. Please check your admin permissions.';
        });
      } else if (e.toString().contains('403')) {
        setState(() {
          _error = 'You do not have permission to access referral programs.';
        });
      } else if (e.toString().contains('404')) {
        setState(() {
          _error = 'Referral programs endpoint not found. Please contact support.';
        });
      }
    }
  }

  void _addNewProgram() {
    setState(() {
      _selectedProgram = null;
      _showAddEditForm = true;
    });
  }

  void _editProgram(ReferralProgram program) {
    setState(() {
      _selectedProgram = program;
      _showAddEditForm = true;
    });
  }

  Future<void> _toggleProgramStatus(String programId, bool isActive) async {
    try {
      await _adminService.toggleReferralProgramStatus(programId);
      await _loadPrograms(); // Reload the data
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Program ${isActive ? 'activated' : 'deactivated'} successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update program status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteProgram(ReferralProgram program) async {
    try {
      await _adminService.deleteReferralProgram(program.id.toString());
      await _loadPrograms(); // Reload the data
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Program deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete program: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Referral Programs')),
        actions: [
          if (!_showAddEditForm)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPrograms,
              tooltip: 'Refresh',
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
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPrograms,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _showAddEditForm
                  ? _buildReferralForm(
                      formKey: GlobalKey<FormState>(),
                      nameController: TextEditingController(),
                      descriptionController: TextEditingController(),
                      rewardValueController: TextEditingController(),
                      referrerRewardValueController: TextEditingController(),
                      usageLimitController: TextEditingController(),
                      minPurchaseController: TextEditingController(),
                      selectedRewardType: '',
                      selectedReferrerRewardType: '',
                      isActive: true,
                      validFrom: null,
                      validUntil: null,
                      isEditing: false,
                    )
                  : _buildProgramsList(),
      floatingActionButton: !_showAddEditForm && _error == null
          ? FloatingActionButton(
              onPressed: _addNewProgram,
              backgroundColor: AppColors.darkBlue,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildProgramsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            context.tr('Manage referral programs'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Expanded(
          child: _programs.isEmpty
              ? Center(
                  child: Text(context.tr('No programs found')),
                )
              : ResponsiveUtils.isMobile(context)
                  ? _buildMobileList()
                  : _buildDesktopTable(),
        ),
      ],
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _programs.length,
      itemBuilder: (context, index) {
        final program = _programs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        program.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: program.isActive ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        program.isActive ? context.tr('active') : context.tr('inactive'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(context.tr('Reward type'), _formatRewardType(program.rewardType)),
                _buildInfoRow(context.tr('Reward value'), _formatRewardValue(program.rewardValue, program.rewardType)),
                _buildInfoRow(context.tr('Referrer reward'), _formatRewardValue(program.referrerRewardValue, program.referrerRewardType)),
                _buildInfoRow(context.tr('Validity period'), _formatValidityPeriod(program.validFrom, program.validUntil)),
                _buildInfoRow(context.tr('Usage count'), program.usageCount?.toString() ?? '0'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(context.tr('Status')),
                          const SizedBox(width: 8),
                          Switch(
                            value: program.isActive,
                            onChanged: (value) => _toggleProgramStatus(program.id.toString(), value),
                            activeColor: AppColors.darkBlue,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.darkBlue),
                          onPressed: () => _editProgram(program),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteConfirmation(program),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(context.tr('Name'))),
          DataColumn(label: Text(context.tr('Reward type'))),
          DataColumn(label: Text(context.tr('Reward value'))),
          DataColumn(label: Text(context.tr('Referrer reward'))),
          DataColumn(label: Text(context.tr('Validity period'))),
          DataColumn(label: Text(context.tr('Usage count'))),
          DataColumn(label: Text(context.tr('Status'))),
          DataColumn(label: Text(context.tr('actions'))),
        ],
        rows: _programs.map((program) {
          return DataRow(
            cells: [
              DataCell(Text(program.name)),
              DataCell(Text(_formatRewardType(program.rewardType))),
              DataCell(Text(_formatRewardValue(program.rewardValue, program.rewardType))),
              DataCell(Text(_formatRewardValue(program.referrerRewardValue, program.referrerRewardType))),
              DataCell(Text(_formatValidityPeriod(program.validFrom, program.validUntil))),
              DataCell(Text(program.usageCount?.toString() ?? '0')),
              DataCell(
                Switch(
                  value: program.isActive,
                  onChanged: (value) => _toggleProgramStatus(program.id.toString(), value),
                  activeColor: AppColors.darkBlue,
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.darkBlue),
                      onPressed: () => _editProgram(program),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmation(program),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReferralForm({
    required GlobalKey<FormState> formKey,
    required TextEditingController nameController,
    required TextEditingController descriptionController,
    required TextEditingController rewardValueController,
    required TextEditingController referrerRewardValueController,
    required TextEditingController usageLimitController,
    required TextEditingController minPurchaseController,
    required String selectedRewardType,
    required String selectedReferrerRewardType,
    required bool isActive,
    required DateTime? validFrom,
    required DateTime? validUntil,
    required bool isEditing,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Form(
          key: formKey,
          child: SingleChildScrollView(
            child: ResponsiveUtils.isMobile(context)
                ? _buildMobileForm(
                    formKey,
                    nameController,
                    descriptionController,
                    rewardValueController,
                    referrerRewardValueController,
                    usageLimitController,
                    minPurchaseController,
                    selectedRewardType,
                    selectedReferrerRewardType,
                    isActive,
                    validFrom,
                    validUntil,
                    isEditing,
                    setState,
                  )
                : _buildDesktopForm(
                    formKey,
                    nameController,
                    descriptionController,
                    rewardValueController,
                    referrerRewardValueController,
                    usageLimitController,
                    minPurchaseController,
                    selectedRewardType,
                    selectedReferrerRewardType,
                    isActive,
                    validFrom,
                    validUntil,
                    isEditing,
                    setState,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildMobileForm(
    GlobalKey<FormState> formKey,
    TextEditingController nameController,
    TextEditingController descriptionController,
    TextEditingController rewardValueController,
    TextEditingController referrerRewardValueController,
    TextEditingController usageLimitController,
    TextEditingController minPurchaseController,
    String selectedRewardType,
    String selectedReferrerRewardType,
    bool isActive,
    DateTime? validFrom,
    DateTime? validUntil,
    bool isEditing,
    StateSetter setState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEditing ? context.tr('Edit Referral Program') : context.tr('Add New Referral Program'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        
        // Basic Information Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Basic information'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('Program name'),
                    hintText: context.tr('Enter program name'),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('Program name required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: context.tr('Description'),
                    hintText: context.tr('Enter description'),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('Description required');
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Reward Configuration Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Reward Configuration'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRewardType,
                  decoration: InputDecoration(
                    labelText: context.tr('Reward type'),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: 'DISCOUNT PERCENTAGE',
                      child: Text(context.tr('Percentage discount')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'DISCOUNT FIXED',
                      child: Text(context.tr('Fixed amount discount')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'EXTEND SUBSCRIPTION DAYS',
                      child: Text(context.tr('Extend subscription')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'CREDIT',
                      child: Text(context.tr('Account credit')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedRewardType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: rewardValueController,
                  decoration: InputDecoration(
                    labelText: context.tr('Reward value'),
                    hintText: _getRewardValueHint(selectedRewardType),
                    suffixText: _getRewardValueSuffix(selectedRewardType),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('Reward value required');
                    }
                    if (double.tryParse(value) == null) {
                      return context.tr('Invalid reward value');
                    }
                    if (selectedRewardType == 'DISCOUNT_PERCENTAGE') {
                      final percentage = double.parse(value);
                      if (percentage <= 0 || percentage > 100) {
                        return context.tr('Percentage range error');
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReferrerRewardType,
                  decoration: InputDecoration(
                    labelText: context.tr('Referrer reward type'),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: 'DISCOUNT PERCENTAGE',
                      child: Text(context.tr('Percentage discount')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'DISCOUNT FIXED',
                      child: Text(context.tr('Fixed amount discount')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'EXTEND SUBSCRIPTION DAYS',
                      child: Text(context.tr('Extend subscription')),
                    ),
                    DropdownMenuItem<String>(
                      value: 'CREDIT',
                      child: Text(context.tr('Account credit')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedReferrerRewardType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: referrerRewardValueController,
                  decoration: InputDecoration(
                    labelText: context.tr('Referrer reward value'),
                    hintText: _getRewardValueHint(selectedReferrerRewardType),
                    suffixText: _getRewardValueSuffix(selectedReferrerRewardType),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('Referrer reward value required');
                    }
                    if (double.tryParse(value) == null) {
                      return context.tr('Invalid reward value');
                    }
                    if (selectedReferrerRewardType == 'DISCOUNT_PERCENTAGE') {
                      final percentage = double.parse(value);
                      if (percentage <= 0 || percentage > 100) {
                        return context.tr('Percentage range error');
                      }
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Limits and Validity Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Limits and Validity'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: usageLimitController,
                  decoration: InputDecoration(
                    labelText: context.tr('Usage limit'),
                    hintText: context.tr('Usage limit hint'),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('Usage limit required');
                    }
                    if (int.tryParse(value) == null) {
                      return context.tr('Invalid usage limit');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: minPurchaseController,
                  decoration: InputDecoration(
                    labelText: context.tr('Minimum purchase amount'),
                    hintText: '0.00',
                    suffixText: '\$',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('Minimum purchase required');
                    }
                    if (double.tryParse(value) == null) {
                      return context.tr('Invalid amount');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('Valid from')),
                  subtitle: Text(validFrom?.toString().split(' ')[0] ?? context.tr('Not set')),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: validFrom ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (date != null) {
                      setState(() {
                        validFrom = date;
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('Valid until')),
                  subtitle: Text(validUntil?.toString().split(' ')[0] ?? context.tr('No expiry')),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: validUntil ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: validFrom ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (date != null) {
                      setState(() {
                        validUntil = date;
                      });
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('Active')),
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      isActive = value;
                    });
                  },
                  activeColor: AppColors.darkBlue,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        // Form actions
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    await _saveProgram(
                      nameController.text,
                      descriptionController.text,
                      selectedRewardType,
                      double.parse(rewardValueController.text),
                      selectedReferrerRewardType,
                      double.parse(referrerRewardValueController.text),
                      int.parse(usageLimitController.text),
                      double.parse(minPurchaseController.text),
                      validFrom,
                      validUntil,
                      isActive,
                      isEditing,
                    );
                  }
                },
                child: Text(isEditing ? context.tr('Update program') : context.tr('Save program')),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _showAddEditForm = false;
                  });
                },
                child: Text(context.tr('Cancel')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopForm(
    GlobalKey<FormState> formKey,
    TextEditingController nameController,
    TextEditingController descriptionController,
    TextEditingController rewardValueController,
    TextEditingController referrerRewardValueController,
    TextEditingController usageLimitController,
    TextEditingController minPurchaseController,
    String selectedRewardType,
    String selectedReferrerRewardType,
    bool isActive,
    DateTime? validFrom,
    DateTime? validUntil,
    bool isEditing,
    StateSetter setState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEditing ? context.tr('Edit Referral Program') : context.tr('Add New Referral Program'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column
            Expanded(
              child: Column(
                children: [
                  // Name field
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: context.tr('Program name'),
                      hintText: context.tr('Enter program name'),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Program name required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Description field
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: context.tr('Description'),
                      hintText: context.tr('Enter description'),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Description required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Reward Type
                  DropdownButtonFormField<String>(
                    value: selectedRewardType,
                    decoration: InputDecoration(
                      labelText: context.tr('Reward type'),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: 'DISCOUNT PERCENTAGE',
                        child: Text(context.tr('Percentage discount')),
                      ),
                      DropdownMenuItem<String>(
                        value: 'DISCOUNT FIXED',
                        child: Text(context.tr('Fixed amount discount')),
                      ),
                      DropdownMenuItem<String>(
                        value: 'EXTEND SUBSCRIPTION DAYS',
                        child: Text(context.tr('Extend subscription')),
                      ),
                      DropdownMenuItem<String>(
                        value: 'CREDIT',
                        child: Text(context.tr('Account credit')),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedRewardType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Reward Value
                  TextFormField(
                    controller: rewardValueController,
                    decoration: InputDecoration(
                      labelText: context.tr('Reward value'),
                      hintText: _getRewardValueHint(selectedRewardType),
                      suffixText: _getRewardValueSuffix(selectedRewardType),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Reward value required');
                      }
                      if (double.tryParse(value) == null) {
                        return context.tr('Invalid reward value');
                      }
                      if (selectedRewardType == 'DISCOUNT_PERCENTAGE') {
                        final percentage = double.parse(value);
                        if (percentage <= 0 || percentage > 100) {
                          return context.tr('Percentage range error');
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            
            // Right Column
            Expanded(
              child: Column(
                children: [
                  // Referrer Reward Type
                  DropdownButtonFormField<String>(
                    value: selectedReferrerRewardType,
                    decoration: InputDecoration(
                      labelText: context.tr('Referrer reward type'),
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: 'DISCOUNT PERCENTAGE',
                        child: Text(context.tr('Percentage discount')),
                      ),
                      DropdownMenuItem<String>(
                        value: 'DISCOUNT FIXED',
                        child: Text(context.tr('Fixed amount discount')),
                      ),
                      DropdownMenuItem<String>(
                        value: 'EXTEND SUBSCRIPTION DAYS',
                        child: Text(context.tr('Extend subscription')),
                      ),
                      DropdownMenuItem<String>(
                        value: 'CREDIT',
                        child: Text(context.tr('Account credit')),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedReferrerRewardType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Referrer Reward Value
                  TextFormField(
                    controller: referrerRewardValueController,
                    decoration: InputDecoration(
                      labelText: context.tr('Referrer reward value'),
                      hintText: _getRewardValueHint(selectedReferrerRewardType),
                      suffixText: _getRewardValueSuffix(selectedReferrerRewardType),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Referrer reward value required');
                      }
                      if (double.tryParse(value) == null) {
                        return context.tr('Invalid reward value');
                      }
                      if (selectedReferrerRewardType == 'DISCOUNT_PERCENTAGE') {
                        final percentage = double.parse(value);
                        if (percentage <= 0 || percentage > 100) {
                          return context.tr('Percentage range error');
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Usage Limit
                  TextFormField(
                    controller: usageLimitController,
                    decoration: InputDecoration(
                      labelText: context.tr('Usage limit'),
                      hintText: context.tr('Usage limit hint'),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Usage limit required');
                      }
                      if (int.tryParse(value) == null) {
                        return context.tr('Invalid usage limit');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Minimum Purchase Amount
                  TextFormField(
                    controller: minPurchaseController,
                    decoration: InputDecoration(
                      labelText: context.tr('Minimum purchase amount'),
                      hintText: '0.00',
                      suffixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('Minimum purchase required');
                      }
                      if (double.tryParse(value) == null) {
                        return context.tr('Invalid amount');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Valid From
        ListTile(
          title: Text(context.tr('Valid from')),
          subtitle: Text(validFrom?.toString().split(' ')[0] ?? context.tr('Not set')),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: validFrom ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (date != null) {
              setState(() {
                validFrom = date;
              });
            }
          },
        ),
        
        // Valid Until
        ListTile(
          title: Text(context.tr('Valid until')),
          subtitle: Text(validUntil?.toString().split(' ')[0] ?? context.tr('No expiry')),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: validUntil ?? DateTime.now().add(const Duration(days: 30)),
              firstDate: validFrom ?? DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (date != null) {
              setState(() {
                validUntil = date;
              });
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Active toggle
        SwitchListTile(
          title: Text(context.tr('Active')),
          value: isActive,
          onChanged: (value) {
            setState(() {
              isActive = value;
            });
          },
          activeColor: AppColors.darkBlue,
        ),
        
        const SizedBox(height: 32),
        
        // Form actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _showAddEditForm = false;
                });
              },
              child: Text(context.tr('cancel')),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await _saveProgram(
                    nameController.text,
                    descriptionController.text,
                    selectedRewardType,
                    double.parse(rewardValueController.text),
                    selectedReferrerRewardType,
                    double.parse(referrerRewardValueController.text),
                    int.parse(usageLimitController.text),
                    double.parse(minPurchaseController.text),
                    validFrom,
                    validUntil,
                    isActive,
                    isEditing,
                  );
                }
              },
              child: Text(isEditing ? context.tr('Update program') : context.tr('Save program')),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveProgram(
    String name,
    String description,
    String rewardType,
    double rewardValue,
    String referrerRewardType,
    double referrerRewardValue,
    int usageLimit,
    double minPurchaseAmount,
    DateTime? validFrom,
    DateTime? validUntil,
    bool isActive,
    bool isEditing,
  ) async {
    try {
      final programData = {
        'name': name,
        'description': description,
        'reward_type': rewardType,
        'reward_value': rewardValue,
        'referrer_reward_type': referrerRewardType,
        'referrer_reward_value': referrerRewardValue,
        'usage_limit': usageLimit,
        'min_purchase_amount': minPurchaseAmount,
        'valid_from': validFrom?.toIso8601String().split('T')[0],
        'valid_until': validUntil?.toIso8601String().split('T')[0],
        'is_active': isActive,
      };

      if (isEditing) {
        await _adminService.updateReferralProgram(_selectedProgram!.id.toString(), programData);
      } else {
        await _adminService.createReferralProgram(programData);
      }

      setState(() {
        _showAddEditForm = false;
      });

      await _loadPrograms(); // Reload the data

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? context.tr('Program updated')
                : context.tr('Program added'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save program: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(ReferralProgram program) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.tr('Confirm Delete')),
          content: Text(
            context.tr('Delete program confirmation', params: {'name': program.name}),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProgram(program);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.tr('Delete')),
            ),
          ],
        );
      },
    );
  }

  String _formatRewardType(String rewardType) {
    // Try to get localized version first
    switch (rewardType) {
      case 'DISCOUNT PERCENTAGE':
        return context.tr('Percentage discount');
      case 'DISCOUNT FIXED':
        return context.tr('Fixed amount discount');
      case 'EXTEND SUBSCRIPTION DAYS':
        return context.tr('Extend subscription');
      case 'CREDIT':
        return context.tr('Account credit');
      default:
        // Fallback to formatted string if no translation available
        return StringUtils.formatEnumValue(rewardType);
    }
  }

  String _formatRewardValue(double value, String rewardType) {
    switch (rewardType) {
      case 'DISCOUNT_PERCENTAGE':
        return '${value.toInt()}%';
      case 'DISCOUNT_FIXED':
        return '\$${value.toStringAsFixed(2)}';
      case 'EXTEND SUBSCRIPTION DAYS':
        return '${value.toInt()} ${context.tr('days')}';
      case 'CREDIT':
        return '\$${value.toStringAsFixed(2)}';
      default:
        return value.toString();
    }
  }

  String _formatValidityPeriod(DateTime? validFrom, DateTime? validUntil) {
    if (validFrom == null && validUntil == null) {
      return context.tr('No limit');
    }
    
    final from = validFrom?.toString().split(' ')[0] ?? context.tr('Indefinite');
    final until = validUntil?.toString().split(' ')[0] ?? context.tr('Indefinite');
    
    return '$from - $until';
  }

  String _getRewardValueHint(String rewardType) {
    switch (rewardType) {
      case 'DISCOUNT PERCENTAGE':
        return '10';
      case 'DISCOUNT FIXED':
        return '5.99';
      case 'EXTEND SUBSCRIPTION DAYS':
        return '30';
      case 'CREDIT':
        return '10.00';
      default:
        return '';
    }
  }

  String _getRewardValueSuffix(String rewardType) {
    switch (rewardType) {
      case 'DISCOUNT_PERCENTAGE':
        return '%';
      case 'DISCOUNT_FIXED':
        return '\$';
      case 'EXTEND SUBSCRIPTION DAYS':
        return context.tr('Days');
      case 'CREDIT':
        return '\$';
      default:
        return '';
    }
  }
}

class ReferralProgram {
  final int id;
  final String name;
  final String description;
  final String rewardType;
  final double rewardValue;
  final String referrerRewardType;
  final double referrerRewardValue;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final int usageLimit;
  final double minPurchaseAmount;
  final int? usageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ReferralProgram({
    required this.id,
    required this.name,
    required this.description,
    required this.rewardType,
    required this.rewardValue,
    required this.referrerRewardType,
    required this.referrerRewardValue,
    required this.isActive,
    this.validFrom,
    this.validUntil,
    required this.usageLimit,
    required this.minPurchaseAmount,
    this.usageCount,
    this.createdAt,
    this.updatedAt,
  });

  factory ReferralProgram.fromJson(Map<String, dynamic> json) {
    return ReferralProgram(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      rewardType: json['reward_type'] ?? 'DISCOUNT PERCENTAGE',
      rewardValue: double.parse(json['reward_value']?.toString() ?? '0'),
      referrerRewardType: json['referrer_reward_type'] ?? 'DISCOUNT PERCENTAGE',
      referrerRewardValue: double.parse(json['referrer_reward_value']?.toString() ?? '0'),
      isActive: json['is_active'] ?? true,
      validFrom: json['valid_from'] != null ? DateTime.parse(json['valid_from']) : null,
      validUntil: json['valid_until'] != null ? DateTime.parse(json['valid_until']) : null,
      usageLimit: json['usage_limit'] ?? 0,
      minPurchaseAmount: double.parse(json['min_purchase_amount']?.toString() ?? '0'),
      usageCount: json['usage_count'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  ReferralProgram copyWith({
    int? id,
    String? name,
    String? description,
    String? rewardType,
    double? rewardValue,
    String? referrerRewardType,
    double? referrerRewardValue,
    bool? isActive,
    DateTime? validFrom,
    DateTime? validUntil,
    int? usageLimit,
    double? minPurchaseAmount,
    int? usageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReferralProgram(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      rewardType: rewardType ?? this.rewardType,
      rewardValue: rewardValue ?? this.rewardValue,
      referrerRewardType: referrerRewardType ?? this.referrerRewardType,
      referrerRewardValue: referrerRewardValue ?? this.referrerRewardValue,
      isActive: isActive ?? this.isActive,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      usageLimit: usageLimit ?? this.usageLimit,
      minPurchaseAmount: minPurchaseAmount ?? this.minPurchaseAmount,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 
