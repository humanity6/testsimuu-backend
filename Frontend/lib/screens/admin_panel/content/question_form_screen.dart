import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../models/question.dart';
import '../../../models/topic.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/loading_overlay.dart';
import '../../../services/admin_service.dart';
import 'dart:convert';

class QuestionFormScreen extends StatefulWidget {
  final Question? question;
  final String? preSelectedExamId;

  const QuestionFormScreen({
    Key? key,
    this.question,
    this.preSelectedExamId,
  }) : super(key: key);

  @override
  State<QuestionFormScreen> createState() => _QuestionFormScreenState();
}

class _QuestionFormScreenState extends State<QuestionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  
  String _selectedType = 'mcq';
  String? _selectedTopicId;
  String? _selectedExamId;
  String _selectedDifficulty = 'medium';
  bool _isLoading = false;
  
  // For MCQ questions
  final List<QuestionOption> _options = [];
  
  // For open-ended questions
  final List<TextEditingController> _modelAnswerControllers = [];
  
  // For calculation questions
  final _formulaController = TextEditingController();
  final Map<String, TextEditingController> _variableControllers = {};
  final _answerController = TextEditingController();
  
  // Filter options
  final List<String> _questionTypes = ['mcq', 'open_ended', 'calculation'];
  List<Topic> _topics = [];
  List<Map<String, dynamic>> _exams = [];
  final List<String> _difficulties = ['easy', 'medium', 'hard', 'very_hard'];
  
  late AdminService _adminService;

  @override
  void initState() {
    super.initState();
    
    // Set preselected exam ID if provided
    if (widget.preSelectedExamId != null) {
      _selectedExamId = widget.preSelectedExamId;
    }
    
    _loadData();
    
    if (widget.question != null) {
      _initializeQuestionData();
    } else {
      // Add default options for new MCQ questions
      if (_selectedType == 'mcq') {
        _addOption();
        _addOption();
      }
      
      // Add default model answer for new open-ended questions
      if (_selectedType == 'open_ended') {
        _addModelAnswer();
      }
    }
  }

  void _initializeQuestionData() {
    _textController.text = widget.question!.text;
    _selectedType = widget.question!.type;
    _selectedTopicId = widget.question!.topicId?.toString();
    _selectedExamId = widget.question!.examId?.toString();
    _selectedDifficulty = widget.question!.difficulty;
    
    print('Initializing question data:');
    print('Type: $_selectedType');
    print('Options: ${widget.question!.options}');
    print('Model answers: ${widget.question!.modelAnswers}');
    print('Calculation params: ${widget.question!.calculationParams}');
    
    // Initialize type-specific fields
    if (_selectedType == 'mcq' && widget.question!.options != null) {
      _options.clear();
      _options.addAll(widget.question!.options!);
      print('Added ${_options.length} MCQ options');
    } else if (_selectedType == 'open_ended' && widget.question!.modelAnswers != null) {
      _modelAnswerControllers.clear();
      for (final answer in widget.question!.modelAnswers!) {
        final controller = TextEditingController(text: answer);
        _modelAnswerControllers.add(controller);
      }
      print('Added ${_modelAnswerControllers.length} model answers');
    } else if (_selectedType == 'calculation' && widget.question!.calculationParams != null) {
      final params = widget.question!.calculationParams!;
      _formulaController.text = params['formula'] ?? '';
      _answerController.text = params['answer']?.toString() ?? '';
      
      _variableControllers.clear();
      if (params['variables'] != null) {
        final variables = params['variables'];
        
        // Handle case where variables is a Map
        if (variables is Map<String, dynamic>) {
          variables.forEach((key, value) {
            _variableControllers[key] = TextEditingController(text: value.toString());
          });
        }
        // Handle case where variables is a List
        else if (variables is List) {
          for (int i = 0; i < variables.length; i++) {
            _variableControllers['variable_${i + 1}'] = TextEditingController(text: variables[i].toString());
          }
        }
      }
      print('Added ${_variableControllers.length} calculation variables');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _formulaController.dispose();
    _answerController.dispose();
    
    for (final controller in _modelAnswerControllers) {
      controller.dispose();
    }
    
    for (final controller in _variableControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize AdminService with access token from AuthService
      final authService = context.authService;
      final accessToken = authService.accessToken;
      _adminService = AdminService(accessToken: accessToken);
      
      final exams = await _adminService.getExamsForQuestionForm();
      
      setState(() {
        _exams = exams;
        
        // Set default exam if none selected and no preselected exam and exams are available
        if (_selectedExamId == null && widget.preSelectedExamId == null && _exams.isNotEmpty) {
          _selectedExamId = _exams.first['id'].toString();
        }
        
        // Verify that the selected exam ID exists in the loaded exams
        if (_selectedExamId != null && !_exams.any((exam) => exam['id'].toString() == _selectedExamId)) {
          print('Selected exam ID $_selectedExamId not found in loaded exams');
          _selectedExamId = _exams.isNotEmpty ? _exams.first['id'].toString() : null;
        }
        
        _isLoading = false;
      });

      // Load topics for the selected exam
      await _loadTopicsForExam();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTopicsForExam() async {
    if (_selectedExamId == null) return;

    try {
      final topics = await _adminService.getTopics(examId: _selectedExamId!);
      
      setState(() {
        _topics = topics;
        
        // Reset topic selection if current topic is not available for this exam
        if (_selectedTopicId != null && !_topics.any((topic) => topic.id == _selectedTopicId)) {
          _selectedTopicId = null;
        }
        
        // Set default topic if none selected and topics are available
        if (_selectedTopicId == null && _topics.isNotEmpty) {
          _selectedTopicId = _topics.first.id;
        }
      });
    } catch (e) {
      print('Failed to load topics for exam $_selectedExamId: $e');
      setState(() {
        _topics = [];
        _selectedTopicId = null;
      });
    }
  }

  void _addOption() {
    setState(() {
      _options.add(
        QuestionOption(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: '',
          isCorrect: _options.isEmpty, // Make the first option correct by default
        ),
      );
    });
  }

  void _removeOption(int index) {
    setState(() {
      _options.removeAt(index);
      
      // Ensure at least one option is marked as correct
      if (_options.isNotEmpty && !_options.any((o) => o.isCorrect)) {
        _options[0] = QuestionOption(
          id: _options[0].id,
          text: _options[0].text,
          isCorrect: true,
        );
      }
    });
  }

  void _updateOption(int index, {String? text, bool? isCorrect}) {
    setState(() {
      _options[index] = QuestionOption(
        id: _options[index].id,
        text: text ?? _options[index].text,
        isCorrect: isCorrect ?? _options[index].isCorrect,
      );
    });
  }

  void _addModelAnswer() {
    setState(() {
      _modelAnswerControllers.add(TextEditingController());
    });
  }

  void _removeModelAnswer(int index) {
    setState(() {
      _modelAnswerControllers[index].dispose();
      _modelAnswerControllers.removeAt(index);
    });
  }

  void _addVariable() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final valueController = TextEditingController();
        
        return AlertDialog(
          title: Text(context.tr('add_variable')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.tr('variable_name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: valueController,
                decoration: InputDecoration(
                  labelText: context.tr('variable_value'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && valueController.text.isNotEmpty) {
                  setState(() {
                    _variableControllers[nameController.text] = valueController;
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text(context.tr('add')),
            ),
          ],
        );
      },
    );
  }

  void _removeVariable(String name) {
    setState(() {
      _variableControllers[name]?.dispose();
      _variableControllers.remove(name);
    });
  }

  void _changeQuestionType(String? newType) {
    if (newType == null || newType == _selectedType) return;
    
    // Show confirmation dialog if changing type with existing data
    if (widget.question != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('change_question_type')),
          content: Text(context.tr('change_question_type_warning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateQuestionType(newType);
              },
              child: Text(context.tr('continue')),
            ),
          ],
        ),
      );
    } else {
      _updateQuestionType(newType);
    }
  }

  void _updateQuestionType(String newType) {
    setState(() {
      _selectedType = newType;
      
      // Initialize default values for the new type
      if (newType == 'mcq' && _options.isEmpty) {
        _addOption();
        _addOption();
      } else if (newType == 'open_ended' && _modelAnswerControllers.isEmpty) {
        _addModelAnswer();
      }
    });
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that an exam is selected
    if (_selectedExamId == null || _selectedExamId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('exam_required')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate type-specific fields
    if (_selectedType == 'mcq') {
      if (_options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('add_at_least_one_option')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (!_options.any((o) => o.isCorrect)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('select_at_least_one_correct_option')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      for (final option in _options) {
        if (option.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('option_text_cannot_be_empty')),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } else if (_selectedType == 'open_ended') {
      if (_modelAnswerControllers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('add_at_least_one_model_answer')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      for (final controller in _modelAnswerControllers) {
        if (controller.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('model_answer_cannot_be_empty')),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } else if (_selectedType == 'calculation') {
      if (_formulaController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('formula_cannot_be_empty')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_variableControllers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('add_at_least_one_variable')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (_answerController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('answer_cannot_be_empty')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize AdminService if not already done
      final authService = context.authService;
      final accessToken = authService.accessToken;
      _adminService = AdminService(accessToken: accessToken);
      
      // Prepare question data
      final questionData = {
        'text': _textController.text,
        'question_type': _selectedType.toUpperCase(),
        'difficulty': _selectedDifficulty.toUpperCase(),
        'topic': _selectedTopicId,
        'exam': _selectedExamId,
        'estimated_time_seconds': 60, // Default value
        'points': 1, // Default value
        'is_active': true,
      };

      // Add type-specific data
      if (_selectedType == 'mcq') {
        questionData['choices'] = _options.map((option) => {
          'choice_text': option.text,
          'is_correct': option.isCorrect,
          'display_order': _options.indexOf(option) + 1,
          'explanation': '', // Add explanation field as required by backend
        }).toList();
      } else if (_selectedType == 'open_ended') {
        questionData['model_answer_text'] = _modelAnswerControllers
            .map((controller) => controller.text)
            .join('\n');
      } else if (_selectedType == 'calculation') {
        questionData['model_calculation_logic'] = {
          'formula': _formulaController.text,
          'variables': _variableControllers.map((key, controller) => 
              MapEntry(key, double.tryParse(controller.text) ?? 0.0)),
          'answer': double.tryParse(_answerController.text) ?? 0.0,
        };
      }

      print('Sending question data: ${json.encode(questionData)}');

      if (widget.question == null) {
        await _adminService.createQuestion(questionData);
      } else {
        await _adminService.updateQuestion(widget.question!.id, questionData);
      }
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.question == null
                  ? context.tr('question_created_successfully')
                  : context.tr('question_updated_successfully'),
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
              widget.question == null
                  ? context.tr('failed_to_create_question')
                  : context.tr('failed_to_update_question'),
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
          widget.question == null
              ? context.tr('add_question')
              : context.tr('edit_question'),
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
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: context.tr('question_text'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.tr('question_text_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: context.tr('question_type'),
                          border: const OutlineInputBorder(),
                        ),
                        items: _questionTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(_getQuestionTypeLabel(type)),
                          );
                        }).toList(),
                        onChanged: _changeQuestionType,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDifficulty,
                        decoration: InputDecoration(
                          labelText: context.tr('difficulty'),
                          border: const OutlineInputBorder(),
                        ),
                        items: _difficulties.map((difficulty) {
                          return DropdownMenuItem<String>(
                            value: difficulty,
                            child: Text(_getDifficultyLabel(difficulty)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDifficulty = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_exams.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    value: _selectedExamId,
                    decoration: InputDecoration(
                      labelText: context.tr('exam'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _exams.map((exam) {
                      return DropdownMenuItem<String?>(
                        value: exam['id'].toString(),
                        child: Text(exam['name'] ?? exam['title'] ?? 'Unknown Exam'),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.tr('exam_required');
                      }
                      return null;
                    },
                    onChanged: (value) async {
                      setState(() {
                        _selectedExamId = value;
                        // Reset topic selection when exam changes
                        _selectedTopicId = null;
                        _topics = [];
                      });
                      
                      // Load topics for the new exam
                      await _loadTopicsForExam();
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Loading exams...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_topics.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    value: _selectedTopicId,
                    decoration: InputDecoration(
                      labelText: context.tr('topic'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _topics.map((topic) {
                      return DropdownMenuItem<String?>(
                        value: topic.id,
                        child: Text(topic.name),
                      );
                    }).toList(),
                    validator: (value) {
                      // Topic is optional, exam is required
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _selectedTopicId = value;
                      });
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Loading topics...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                const SizedBox(height: 24),
                _buildTypeSpecificFields(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    onPressed: _saveQuestion,
                    text: widget.question == null
                        ? context.tr('create_question')
                        : context.tr('update_question'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (_selectedType) {
      case 'mcq':
        return _buildMCQFields();
      case 'open_ended':
        return _buildOpenEndedFields();
      case 'calculation':
        return _buildCalculationFields();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMCQFields() {
    print('Building MCQ fields with ${_options.length} options');
    for (int i = 0; i < _options.length; i++) {
      print('Option $i: ${_options[i].text} (correct: ${_options[i].isCorrect})');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('options'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add),
              label: Text(context.tr('add_option')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Checkbox(
                    value: option.isCorrect,
                    onChanged: (value) {
                      _updateOption(index, isCorrect: value ?? false);
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: option.text,
                      decoration: InputDecoration(
                        labelText: context.tr('option_text'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _updateOption(index, text: value);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _options.length > 1 ? () => _removeOption(index) : null,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildOpenEndedFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('model_answers'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: _addModelAnswer,
              icon: const Icon(Icons.add),
              label: Text(context.tr('add_model_answer')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._modelAnswerControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: context.tr('model_answer'),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _modelAnswerControllers.length > 1 
                        ? () => _removeModelAnswer(index) 
                        : null,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCalculationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('formula'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _formulaController,
          decoration: InputDecoration(
            labelText: context.tr('formula'),
            border: const OutlineInputBorder(),
            hintText: 'stroke_volume * heart_rate / 1000',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('variables'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton.icon(
              onPressed: _addVariable,
              icon: const Icon(Icons.add),
              label: Text(context.tr('add_variable')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._variableControllers.entries.map((entry) {
          final name = entry.key;
          final controller = entry.value;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: context.tr('value'),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeVariable(name),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        Text(
          context.tr('correct_answer'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _answerController,
          decoration: InputDecoration(
            labelText: context.tr('answer'),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  String _getQuestionTypeLabel(String type) {
    switch (type) {
      case 'mcq':
        return context.tr('mcq');
      case 'open_ended':
        return context.tr('open_ended');
      case 'calculation':
        return context.tr('calculation');
      default:
        return type;
    }
  }

  String _getDifficultyLabel(String difficulty) {
    return context.tr(difficulty);
  }
} 