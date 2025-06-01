import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/exam.dart';
import '../../models/quiz.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/language_selector.dart';
import '../../services/exam_service.dart';
import '../../services/auth_service.dart';
import '../../services/ai_explanation_service.dart';
import '../../utils/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PracticeScreen extends StatefulWidget {
  final String examId;
  final String? sessionId;
  final String? categoryId;

  const PracticeScreen({
    Key? key,
    required this.examId,
    this.sessionId,
    this.categoryId,
  }) : super(key: key);

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late Future<void> _dataFuture;
  int _currentQuestionIndex = 0;
  final TextEditingController _answerController = TextEditingController();
  bool _isAnswerSubmitted = false;
  bool _isCorrect = false;
  String _explanation = '';
  String _aiFeedback = '';
  String _selectedDifficulty = 'ALL';
  String _selectedQuestionType = 'ALL';
  String _selectedStatus = 'ALL';
  String _selectedTopic = 'ALL';
  bool _isLoading = true;
  
  List<Question> _questions = [];
  List<Question> _filteredQuestions = [];
  Map<String, dynamic>? _sessionData;
  
  // Details about the exam and category
  String _examTitle = '';
  String _categoryTitle = '';
  List<Exam> _examTopics = [];

  // Track answered questions for session-based practice
  final Set<String> _answeredQuestions = {};

  // Check if all questions are answered (for session-based practice)
  bool get _canSubmitPractice {
    if (widget.sessionId == null) return false; // Only for session-based practice
    return _filteredQuestions.every((q) => _answeredQuestions.contains(q.id));
  }

  // Check if this is the last question
  bool get _isLastQuestion {
    return _currentQuestionIndex == _filteredQuestions.length - 1;
  }

  @override
  void initState() {
    super.initState();
    _dataFuture = _initData();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      // If we have a session ID, load the session data
      if (widget.sessionId != null) {
        await _loadSessionData();
      } else {
        // Legacy flow for direct practice access
        await _loadExamData();
      }
      
      await _fetchQuestions();
      _applyFilters();
    } catch (e) {
      print('Error loading practice data: $e');
      // Handle errors properly instead of setting a field that's not used
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading practice data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSessionData() async {
    try {
      // Load session data for questions
      final session = await context.examService.getExamSession(widget.sessionId!);
      if (session != null) {
        setState(() {
          _sessionData = session;
          _examTitle = session['exam_name'] ?? 'Exam';
        });
      }
      
      // Also load the session into ExamSessionService for answer submission and completion
      if (widget.sessionId != null) {
        await context.examSessionService.fetchExamSession(widget.sessionId!);
      }
    } catch (e) {
      print('Error loading session data: $e');
    }
  }
  
  Future<void> _loadExamData() async {
    // Use the exam ID to get the exam details
    final examService = ExamService();
    
    // Set the exam title
    if (widget.examId.isNotEmpty) {
      final exam = await examService.getExamById(widget.examId);
      if (exam != null) {
        setState(() {
          _examTitle = exam.title;
        });
      }
    }
    
    // Set the category title if a category ID is provided
    if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
      final examTopics = await examService.getExamTopics(widget.examId);
      final category = examTopics.firstWhere(
        (topic) => topic.id == widget.categoryId,
        orElse: () => Exam(
          id: widget.categoryId!,
          title: 'Selected Topic',
          description: '',
          subject: '',
          difficulty: '',
          questionCount: 0,
          timeLimit: 0,
        ),
      );
      
      setState(() {
        _categoryTitle = category.title;
      });
    }
    
    // Fetch topics for the exam
    if (widget.examId.isNotEmpty) {
      _examTopics = await examService.getExamTopics(widget.examId);
    } else {
      _examTopics = [];
    }
  }

  Future<void> _fetchQuestions() async {
    try {
      setState(() {
        _isLoading = true;
      });

      String url;
      Map<String, String> headers = {};
      
      // Get auth token
      final authService = AuthService();
      final token = authService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Use session-based questions if we have a session
      if (widget.sessionId != null && _sessionData != null) {
        // Questions are already loaded in session data
        final sessionQuestions = _sessionData!['questions'] as List<dynamic>? ?? [];
        final List<Question> questions = [];
        
        for (var questionData in sessionQuestions) {
          try {
            final question = _parseQuestionFromJson(questionData);
            questions.add(question);
          } catch (e) {
            print('Error parsing question: $e');
            print('Question data: $questionData');
          }
        }
        
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
        return;
      }

      // Legacy approach for direct exam access
      if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
        // Get questions for specific category/topic
        url = '${ApiConfig.questionsEndpoint}?topic_id=${widget.categoryId}';
      } else {
        // Get questions for entire exam
        url = '${ApiConfig.questionsEndpoint}?exam_id=${widget.examId}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> questionsJson = responseData['results'] ?? [];
        
        final List<Question> questions = [];
        
        for (var questionData in questionsJson) {
          try {
            final question = _parseQuestionFromJson(questionData);
            questions.add(question);
          } catch (e) {
            print('Error parsing question: $e');
            print('Question data: $questionData');
          }
        }
        
        setState(() {
          _questions = questions;
        });
      } else {
        throw Exception('Failed to load questions: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // Handle errors properly instead of trying to set an undefined field
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load questions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Question _parseQuestionFromJson(Map<String, dynamic> json) {
    // Determine question type
    QuestionType type;
    switch (json['question_type']) {
      case 'MCQ':
        type = QuestionType.multipleChoice;
        break;
      case 'OPEN_ENDED':
        type = QuestionType.openEnded;
        break;
      case 'CALCULATION':
        type = QuestionType.calculation;
        break;
      default:
        type = QuestionType.multipleChoice;
    }
    
    // Parse multiple choice options if available
    List<Option>? options;
    String? correctOptionId;
    
    if (type == QuestionType.multipleChoice && json['choices'] != null) {
      options = (json['choices'] as List).map<Option>((optionJson) {
        return Option(
          id: optionJson['id']?.toString() ?? '',
          text: optionJson['choice_text'] ?? '',
        );
      }).toList();
      
      // Find the correct answer ID
      for (var choice in json['choices']) {
        if (choice['is_correct'] == true) {
          correctOptionId = choice['id'].toString();
          break;
        }
      }
      
      // Default to first option if no correct answer found
      if (correctOptionId == null && options.isNotEmpty) {
        correctOptionId = options.first.id;
      }
    }
    
    // Parse difficulty
    String difficulty;
    switch (json['difficulty']) {
      case 'EASY':
        difficulty = 'Easy';
        break;
      case 'MEDIUM':
        difficulty = 'Medium';
        break;
      case 'HARD':
        difficulty = 'Hard';
        break;
      default:
        difficulty = 'Medium';
    }
    
    // Create and return Question object
    return Question(
      id: json['id']?.toString() ?? '',
      text: json['text'] ?? '',
      options: options,
      type: type,
      topicId: json['topic_id']?.toString() ?? '',
      difficulty: difficulty,
      correctAnswer: type == QuestionType.multipleChoice 
          ? correctOptionId
          : json['model_answer_text'],
      solutionSteps: json['answer_explanation'] != null 
          ? [json['answer_explanation']] 
          : null,
    );
  }
  
  void _applyFilters() {
    List<Question> filtered = List.from(_questions);
    
    // Apply difficulty filter
    if (_selectedDifficulty != 'ALL') {
      filtered = filtered.where((q) => 
        q.difficulty.toLowerCase() == _selectedDifficulty.toLowerCase()
      ).toList();
    }
    
    // Apply question type filter
    if (_selectedQuestionType != 'ALL') {
      QuestionType type;
      switch (_selectedQuestionType) {
        case 'MCQ':
          type = QuestionType.multipleChoice;
          break;
        case 'OPEN':
          type = QuestionType.openEnded;
          break;
        case 'CALC':
          type = QuestionType.calculation;
          break;
        default:
          type = QuestionType.multipleChoice;
      }
      filtered = filtered.where((q) => q.type == type).toList();
    }
    
    // Apply status filter
    // This would require tracking question statuses in user data
    if (_selectedStatus != 'ALL') {
      // This would be implemented with actual user progress data
    }
    
    // Apply topic filter
    if (_selectedTopic != 'ALL' && widget.categoryId == null) {
      filtered = filtered.where((q) => q.topicId == _selectedTopic).toList();
    }
    
    setState(() {
      _filteredQuestions = filtered;
      _currentQuestionIndex = _filteredQuestions.isEmpty ? -1 : 0;
      _isAnswerSubmitted = false;
      _answerController.clear();
    });
  }
  
  void _submitAnswer() async {
    if (_currentQuestionIndex < 0 || _filteredQuestions.isEmpty) return;
    
    final question = _filteredQuestions[_currentQuestionIndex];
    final userAnswer = _answerController.text.trim();
    
    if (userAnswer.isEmpty) {
      // Show a snackbar to alert the user that they need to provide an answer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('please_enter_an_answer')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    bool isCorrect = false;
    String feedback = '';
    
    try {
      // For session-based practice, first save the answer to the database
      if (widget.sessionId != null) {
        if (kDebugMode) {
          print('Saving answer to database for session: ${widget.sessionId}');
          print('Question ID: ${question.id}');
          print('User Answer: $userAnswer');
          print('Question Type: ${question.type}');
        }
        
        // Save the answer using ExamSessionService
        bool answerSaved = false;
        
        if (question.type == QuestionType.multipleChoice) {
          // For MCQ, pass the selected choice ID
          answerSaved = await context.examSessionService.submitAnswer(
            question.id, 
            userAnswer,
            mcqChoiceIds: [userAnswer],
          );
        } else {
          // For calculation and open-ended questions
          answerSaved = await context.examSessionService.submitAnswer(
            question.id, 
            userAnswer,
          );
        }
        
        if (!answerSaved) {
          throw Exception('Failed to save answer to database: ${context.examSessionService.error ?? "Unknown error"}');
        }
        
        if (kDebugMode) {
          print('✅ Answer saved to database successfully');
        }
      }
      
      // Now handle the evaluation and feedback
      if (question.type == QuestionType.multipleChoice) {
        // For MCQ, find the selected option text to display in feedback
        String selectedOptionText = '';
        if (question.options != null) {
          final selectedOption = question.options!.firstWhere(
            (option) => option.id == userAnswer,
            orElse: () => Option(id: '', text: ''),
          );
          selectedOptionText = selectedOption.text;
        }
        
        // Check if the selected option ID matches the correct answer
        isCorrect = userAnswer == question.correctAnswer;
        
        // Provide specific feedback
        if (isCorrect) {
          feedback = context.tr('correct_answer_feedback', params: {
            'option': selectedOptionText,
          });
        } else {
          // Find the correct option text for feedback
          String correctOptionText = '';
          if (question.options != null && question.correctAnswer != null) {
            final correctOption = question.options!.firstWhere(
              (option) => option.id == question.correctAnswer,
              orElse: () => Option(id: '', text: ''),
            );
            correctOptionText = correctOption.text;
          }
          
          feedback = context.tr('incorrect_answer_feedback', params: {
            'selected_option': selectedOptionText,
            'correct_option': correctOptionText,
          });
        }
      } else if (question.type == QuestionType.calculation || question.type == QuestionType.openEnded) {
        // For calculation and open-ended questions, use AI evaluation for feedback only
        if (kDebugMode) {
          print('Getting AI feedback for display...');
          print('Question ID: ${question.id}');
          print('User Answer: $userAnswer');
          print('Question Type: ${question.type}');
        }
        
        // Get AI feedback for display purposes (the answer is already saved in database)
        final aiExplanationService = AIExplanationService();
        final aiResult = await aiExplanationService.submitAnswerForEvaluation(
          questionId: question.id,
          userAnswer: userAnswer,
          questionType: question.type,
        );
        
        if (aiResult != null) {
          if (kDebugMode) {
            print('AI Result: $aiResult');
          }
          
          feedback = aiResult['ai_feedback'] ?? '';
          isCorrect = aiResult['is_correct'] ?? false;
          
          if (feedback.isEmpty) {
            feedback = isCorrect 
              ? context.tr('ai_correct_feedback') 
              : context.tr('ai_incorrect_feedback');
          }
        } else {
          // Handle AI service error
          if (kDebugMode) {
            print('AI service error: ${aiExplanationService.error}');
          }
          
          feedback = aiExplanationService.error ?? context.tr('ai_evaluation_error');
          
          // Fall back to basic evaluation for open-ended questions
          if (question.correctAnswer != null) {
            // Simple contains check for open-ended
            isCorrect = userAnswer.toLowerCase().contains(question.correctAnswer!.toLowerCase());
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in _submitAnswer: $e');
      }
      feedback = context.tr('answer_submission_error', params: {'error': e.toString()});
      isCorrect = false;
    } finally {
      // Update the UI
      setState(() {
        _isLoading = false;
        _isAnswerSubmitted = true;
        _isCorrect = isCorrect;
        _explanation = question.solutionSteps?.join('\n') ?? 
                       question.explanation ?? 
                       context.tr('no_explanation_available');
        _aiFeedback = feedback;
        
        // Track answered questions for session-based practice
        if (widget.sessionId != null) {
          _answeredQuestions.add(question.id);
        }
      });
    }
  }
  
  void _nextQuestion() {
    if (_currentQuestionIndex < _filteredQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _answerController.clear();
        _isAnswerSubmitted = false;
        _isCorrect = false;
        _explanation = '';
        _aiFeedback = '';
      });
    }
  }
  
  void _prevQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _answerController.clear();
        _isAnswerSubmitted = false;
        _isCorrect = false;
        _explanation = '';
        _aiFeedback = '';
      });
    }
  }

  void _submitPractice() async {
    if (widget.sessionId == null) return;

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('practice_submit_confirmation_title')),
        content: Text(context.tr('practice_submit_confirmation_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                if (kDebugMode) {
                  print('Completing practice session: ${widget.sessionId}');
                }
                
                // Complete the exam session using ExamSessionService
                final success = await context.examSessionService.submitExam();
                
                if (success && mounted) {
                  if (kDebugMode) {
                    print('✅ Practice session completed successfully');
                  }
                  
                  // Navigate to results
                  Navigator.pushReplacementNamed(
                    context, 
                    '/practice-results/${widget.sessionId}'
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('Failed to submit practice session')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Error completing practice session: $e');
                }
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('Error: {error}', params: {'error': e.toString()})),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('Submit Practice')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _examTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_categoryTitle.isNotEmpty)
              Text(
                _categoryTitle,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          const LanguageSelector(isCompact: true),
        ],
      ),
      body: FutureBuilder<void>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return _buildContent();
          }
        },
      ),
    );
  }
  
  Widget _buildContent() {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _filteredQuestions.isEmpty 
            ? _buildNoQuestionsMessage()
            : _buildQuestionContent(),
        ),
      ],
    );
  }
  
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: AppColors.darkBlue),
              const SizedBox(width: 8),
              Text(
                context.tr('Filter Questions'),
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Difficulty filter
                _buildFilterDropdown(
                  context.tr('Difficulty'),
                  _selectedDifficulty,
                  ['ALL', 'EASY', 'MEDIUM', 'HARD'],
                  (value) {
                    setState(() {
                      _selectedDifficulty = value ?? 'ALL';
                    });
                    _applyFilters();
                  },
                  icon: Icons.signal_cellular_alt,
                ),
                const SizedBox(width: 12),
                // Question type filter
                _buildFilterDropdown(
                  context.tr('Question Type'),
                  _selectedQuestionType,
                  ['ALL', 'MCQ', 'OPEN', 'CALC'],
                  (value) {
                    setState(() {
                      _selectedQuestionType = value ?? 'ALL';
                    });
                    _applyFilters();
                  },
                  icon: Icons.question_answer,
                ),
                const SizedBox(width: 12),
                // Status filter
                _buildFilterDropdown(
                  context.tr('Status'),
                  _selectedStatus,
                  ['ALL', 'NOT_ANSWERED', 'CORRECT', 'INCORRECT'],
                  (value) {
                    setState(() {
                      _selectedStatus = value ?? 'ALL';
                    });
                    _applyFilters();
                  },
                  icon: Icons.check_circle_outline,
                ),
                // Topic filter (only show if not already filtered by category)
                if (widget.categoryId == null) ...[
                  const SizedBox(width: 12),
                  _buildFilterDropdown(
                    context.tr('Topic'),
                    _selectedTopic,
                    ['ALL', ..._examTopics.map((t) => t.id)],
                    (value) {
                      setState(() {
                        _selectedTopic = value ?? 'ALL';
                      });
                      _applyFilters();
                    },
                    labelMapper: (value) {
                      if (value == 'ALL') return context.tr('All Topics');
                      final topic = _examTopics
                          .firstWhere((t) => t.id == value, 
                                     orElse: () => Exam(
                                        id: value,
                                        title: value,
                                        description: '',
                                        subject: '',
                                        difficulty: '',
                                        questionCount: 0,
                                        timeLimit: 0,
                                      ));
                      return topic.title;
                    },
                    icon: Icons.category,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Filter counters and reset button
          Row(
            children: [
              Text(
                '${_filteredQuestions.length} ${context.tr('Questions Found')}',
                style: const TextStyle(
                  color: AppColors.darkGrey,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (_selectedDifficulty != 'ALL' || 
                  _selectedQuestionType != 'ALL' || 
                  _selectedStatus != 'ALL' || 
                  (_selectedTopic != 'ALL' && widget.categoryId == null)) 
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDifficulty = 'ALL';
                      _selectedQuestionType = 'ALL';
                      _selectedStatus = 'ALL';
                      _selectedTopic = 'ALL';
                    });
                    _applyFilters();
                  },
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: Text(
                    context.tr('Reset Filters'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterDropdown(
    String label, 
    String value, 
    List<String> options, 
    Function(String?) onChanged, 
    {String Function(String)? labelMapper, IconData? icon}
  ) {
    final selectedLabel = labelMapper != null ? labelMapper(value) : value;
    final displayText = value == 'ALL' 
        ? '$label: ${context.tr('All')}' 
        : '$label: $selectedLabel';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: value == 'ALL' ? AppColors.lightGrey : AppColors.lightBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: value == 'ALL' ? Colors.transparent : AppColors.lightBlue,
          width: 1,
        ),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(label),
        underline: const SizedBox(),
        isDense: true,
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(labelMapper != null ? labelMapper(option) : option),
          );
        }).toList(),
        onChanged: onChanged,
        style: TextStyle(
          color: value == 'ALL' ? AppColors.darkGrey : AppColors.darkBlue,
          fontWeight: value == 'ALL' ? FontWeight.normal : FontWeight.bold,
          fontSize: 14,
        ),
        borderRadius: BorderRadius.circular(8),
        dropdownColor: Colors.white,
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon, 
                size: 16, 
                color: value == 'ALL' ? AppColors.darkGrey : AppColors.darkBlue
              ),
              const SizedBox(width: 4),
            ],
            Text(
              displayText,
              style: TextStyle(
                color: value == 'ALL' ? AppColors.darkGrey : AppColors.darkBlue,
                fontWeight: value == 'ALL' ? FontWeight.normal : FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoQuestionsMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            context.tr('no_questions_found'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('try_different_filters'),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuestionContent() {
    if (_currentQuestionIndex < 0) return const SizedBox.shrink();
    
    final question = _filteredQuestions[_currentQuestionIndex];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question counter
          Text(
            '${context.tr('question')} ${_currentQuestionIndex + 1} ${context.tr('of')} ${_filteredQuestions.length}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 16),
          
          // Question text
          Text(
            question.text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Question type specific content
          _buildQuestionTypeContent(question),
          
          // Answer submission or loading indicator
          if (!_isAnswerSubmitted) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitAnswer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.darkBlue,
                ),
                child: Text(context.tr('check_answer')),
              ),
            ),
          ],
          
          // Explanation and feedback (when answer is submitted)
          if (_isAnswerSubmitted && !_isLoading)
            _buildAnswerFeedback(question),
          
          // Navigation
          const SizedBox(height: 24),
          
          // Submit button when all questions are answered (for session-based practice)
          if (_canSubmitPractice && !_isLastQuestion)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: _submitPractice,
                icon: const Icon(Icons.check_circle),
                label: Text(context.tr('submit_practice_all_answered')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: _currentQuestionIndex > 0 ? _prevQuestion : null,
                child: Text(context.tr('previous')),
              ),
              // Show submit button on last question for session-based practice
              if (_isLastQuestion && widget.sessionId != null)
                ElevatedButton(
                  onPressed: _submitPractice,
                  child: Text(context.tr('Submit Practice')),
                )
              else
                OutlinedButton(
                  onPressed: _currentQuestionIndex < _filteredQuestions.length - 1 ? _nextQuestion : null,
                  child: Text(context.tr('next')),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuestionTypeContent(Question question) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        if (question.options == null || question.options!.isEmpty) {
          return Center(
            child: Text(context.tr('no_options_available')),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: question.options!.map((option) {
            final bool isSelected = _answerController.text == option.id;
            
            return Card(
              elevation: isSelected ? 2 : 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected ? AppColors.lightBlue.withOpacity(0.1) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? AppColors.lightBlue : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: InkWell(
                onTap: _isAnswerSubmitted ? null : () {
                  setState(() {
                    _answerController.text = option.id;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppColors.lightBlue : Colors.white,
                          border: Border.all(
                            color: isSelected ? AppColors.lightBlue : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.text,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
        
      case QuestionType.openEnded:
        return TextField(
          controller: _answerController,
          decoration: InputDecoration(
            hintText: context.tr('enter_your_answer'),
            border: const OutlineInputBorder(),
          ),
          maxLines: 5,
          keyboardType: TextInputType.text,
          enabled: !_isAnswerSubmitted,
        );
        
      case QuestionType.calculation:
        return _buildCalculationView(question);
    }
  }
  
  Widget _buildCalculationView(Question question) {
    // Extract calculation parameters from the question
    final calculationParams = question.calculationParams;
    if (calculationParams == null) {
      return TextField(
        controller: _answerController,
        decoration: InputDecoration(
          hintText: context.tr('enter_your_calculation'),
          border: const OutlineInputBorder(),
        ),
        maxLines: 1,
        keyboardType: TextInputType.number,
        enabled: !_isAnswerSubmitted,
      );
    }
    
    // Extract formula and variables
    final formula = calculationParams['formula'] as String? ?? '';
    final variables = _extractVariables(calculationParams['variables']);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display the formula in a highlighted box
        if (formula.isNotEmpty) 
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.lightBlue),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.functions,
                      color: AppColors.darkBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('formula'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    formula,
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
        // Display the variables
        if (variables.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.data_usage,
                      color: Colors.grey.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('variables'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: variables.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightYellow.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.lightYellow),
                        ),
                        child: Text(
                          '${entry.key} = ${entry.value}',
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        
        // Workspace for calculations
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    color: Colors.grey.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('calculation_workspace'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: context.tr('show_your_work_here'),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                enabled: !_isAnswerSubmitted,
              ),
            ],
          ),
        ),
          
        // Input field for calculation result
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.lightBlue.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calculate,
                    color: AppColors.darkBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('your_answer'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _answerController,
                      decoration: InputDecoration(
                        hintText: context.tr('enter_your_calculation_result'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      maxLines: 1,
                      keyboardType: TextInputType.number,
                      enabled: !_isAnswerSubmitted,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isAnswerSubmitted)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          context.tr('calculation_tip'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAnswerFeedback(Question question) {
    final Color statusColor = _isCorrect ? Colors.green : Colors.red;
    final IconData statusIcon = _isCorrect ? Icons.check_circle : Icons.cancel;
    final String statusText = _isCorrect 
        ? context.tr('correct_answer') 
        : context.tr('incorrect_answer');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // Status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // User's answer
        Text(
          context.tr('your_answer'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _buildAnswerDisplay(question, _answerController.text),
        ),
        const SizedBox(height: 16),
        
        // Correct answer
        Text(
          context.tr('correct_answer_is'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: _buildCorrectAnswerDisplay(question),
        ),
        const SizedBox(height: 16),
        
        // Explanation
        if (_explanation.isNotEmpty) ...[
          Text(
            context.tr('explanation'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(_explanation),
          ),
          const SizedBox(height: 16),
        ],
        
        // AI Feedback - Only show for open-ended and calculation questions
        if ((question.type == QuestionType.openEnded || question.type == QuestionType.calculation) && 
            _aiFeedback.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assistant, color: AppColors.darkBlue),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('ai_feedback'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_aiFeedback),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildAnswerDisplay(Question question, String userAnswer) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        if (question.options == null) return Text(userAnswer);
        
        // Find the selected option text
        final selectedOption = question.options!.firstWhere(
          (option) => option.id == userAnswer,
          orElse: () => Option(id: userAnswer, text: context.tr('option_not_found')),
        );
        
        return Text(selectedOption.text);
        
      case QuestionType.openEnded:
      case QuestionType.calculation:
        return Text(userAnswer);
    }
  }
  
  Widget _buildCorrectAnswerDisplay(Question question) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        if (question.options == null || question.correctAnswer == null) 
          return Text(question.correctAnswer ?? context.tr('no_correct_answer'));
        
        // Find the correct option text
        final correctOption = question.options!.firstWhere(
          (option) => option.id == question.correctAnswer,
          orElse: () => Option(id: question.correctAnswer ?? '', text: question.correctAnswer ?? context.tr('option_not_found')),
        );
        
        return Text(correctOption.text);
        
      case QuestionType.openEnded:
      case QuestionType.calculation:
        return Text(question.correctAnswer ?? context.tr('no_correct_answer'));
    }
  }

  Map<String, dynamic> _extractVariables(dynamic variables) {
    if (variables is Map<String, dynamic>) {
      return variables;
    } else if (variables is List) {
      Map<String, dynamic> extractedVariables = {};
      for (int i = 0; i < variables.length; i++) {
        extractedVariables['variable_${i + 1}'] = variables[i];
      }
      return extractedVariables;
    } else {
      return {};
    }
  }
} 