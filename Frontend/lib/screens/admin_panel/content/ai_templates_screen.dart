import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../models/ai_template.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_overlay.dart';

class AITemplatesScreen extends StatefulWidget {
  const AITemplatesScreen({Key? key}) : super(key: key);

  @override
  State<AITemplatesScreen> createState() => _AITemplatesScreenState();
}

class _AITemplatesScreenState extends State<AITemplatesScreen> {
  bool _isLoading = true;
  List<AITemplate> _templates = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final adminService = context.adminService;
      final templates = await adminService.getAITemplates();
      
      setState(() {
        _templates = templates.map((template) => AITemplate.fromJson(template)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load templates: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteTemplate(String templateId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final adminService = context.adminService;
      await adminService.deleteAITemplate(templateId);
      
      setState(() {
        _templates.removeWhere((template) => template.id.toString() == templateId);
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('template_deleted_successfully'))),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete template: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(AITemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete')),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTemplate(template.id.toString());
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

  void _navigateToAddEditTemplate([AITemplate? template]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TemplateFormScreen(template: template),
        fullscreenDialog: true,
      ),
    ).then((_) => _loadTemplates());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            CustomButton(
              onPressed: _loadTemplates,
              text: 'Retry',
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadTemplates,
          child: _templates.isEmpty
              ? Center(
                  child: Text(
                    'No AI templates found. Create your first template to get started.',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return _buildTemplateCard(template);
                  },
                ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _navigateToAddEditTemplate(),
            backgroundColor: AppColors.darkBlue,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(AITemplate template) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: template.isActive ? AppColors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          child: Icon(
            Icons.psychology,
            color: template.isActive ? AppColors.green : Colors.grey,
          ),
        ),
        title: Text(template.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${template.questionType.replaceAll('_', ' ')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              template.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: template.isActive,
              onChanged: (value) => _toggleTemplateStatus(template),
              activeColor: AppColors.green,
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.darkBlue),
              onPressed: () => _navigateToAddEditTemplate(template),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(template),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text(
                  'Template Content',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(template.template),
                ),
                if (template.variables.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Variables',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: template.variables.map((variable) {
                      return Chip(
                        label: Text(variable),
                        backgroundColor: AppColors.lightBlue.withOpacity(0.2),
                        labelStyle: TextStyle(color: AppColors.darkBlue),
                      );
                    }).toList(),
                  ),
                ],
                if (template.createdAt != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Created: ${DateTime.parse(template.createdAt!).toLocal().toString().split('.')[0]}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTemplateStatus(AITemplate template) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final adminService = context.adminService;
      await adminService.toggleAITemplateStatus(template.id.toString());
      
      setState(() {
        final index = _templates.indexWhere((t) => t.id == template.id);
        if (index != -1) {
          _templates[index] = AITemplate(
            id: template.id,
            templateName: template.templateName,
            questionType: template.questionType,
            templateContent: template.templateContent,
            isActive: !template.isActive,
            createdAt: template.createdAt,
            updatedAt: template.updatedAt,
          );
        }
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              template.isActive
                  ? 'Template deactivated successfully'
                  : 'Template activated successfully',
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
            content: Text('Failed to update template status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class TemplateFormScreen extends StatefulWidget {
  final AITemplate? template;

  const TemplateFormScreen({
    Key? key,
    this.template,
  }) : super(key: key);

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _templateController = TextEditingController();
  String _selectedQuestionType = 'OPEN_ENDED';
  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _questionTypes = ['OPEN_ENDED', 'CALCULATION'];

  @override
  void initState() {
    super.initState();
    
    if (widget.template != null) {
      _nameController.text = widget.template!.templateName;
      _templateController.text = widget.template!.templateContent;
      _selectedQuestionType = widget.template!.questionType;
      _isActive = widget.template!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final adminService = context.adminService;
      final templateData = {
        'template_name': _nameController.text,
        'question_type': _selectedQuestionType,
        'template_content': _templateController.text,
        'is_active': _isActive,
      };

      if (widget.template == null) {
        // Create new template
        await adminService.createAITemplate(templateData);
      } else {
        // Update existing template
        await adminService.updateAITemplate(widget.template!.id.toString(), templateData);
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.template == null
                  ? 'Template created successfully'
                  : 'Template updated successfully',
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
              'Failed to ${widget.template == null ? 'create' : 'update'} template: ${e.toString()}',
            ),
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
        title: Text(
          widget.template == null
              ? 'Add AI Template'
              : 'Edit AI Template',
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Template Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Template name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Question Type',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedQuestionType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedQuestionType = newValue;
                      });
                    }
                  },
                  items: _questionTypes.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.replaceAll('_', ' ')),
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Question type is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Template Content',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _templateController,
                  decoration: const InputDecoration(
                    labelText: 'Template Content',
                    border: OutlineInputBorder(),
                    hintText: 'Your answer is {correctness}. {feedback}',
                    helperText: 'Use {variable_name} for template variables',
                  ),
                  maxLines: 8,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Template content is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    onPressed: _saveTemplate,
                    text: widget.template == null
                        ? 'Create Template'
                        : 'Update Template',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 