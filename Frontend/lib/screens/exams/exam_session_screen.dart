import 'package:flutter/material.dart';
import '../../models/exam_session.dart';
import '../../models/quiz.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/language_selector.dart';
import 'package:provider/provider.dart';
import '../../services/exam_session_service.dart';
import 'package:flutter/foundation.dart';

class ExamSessionScreen extends StatefulWidget {
  final String examId;
  final String sessionId;

  const ExamSessionScreen({
    Key? key,
    required this.examId,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends State<ExamSessionScreen> {
  late Future<bool> _sessionFuture;
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  final TextEditingController _answerController = TextEditingController();
  bool _isLoading = false;
  
  // Store reference to examSessionService
  late final ExamSessionService _examSessionService;
  
  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadData();
    
    // Save reference to examSessionService
    _examSessionService = context.examSessionService;
    
    // Add listener to answer controller to enable submit button
    _answerController.addListener(() {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild when text changes
        });
      }
    });
    
    // Set up auto-submit callback for when time runs out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _examSessionService.setAutoSubmitCallback((sessionId) {
        if (mounted) {
          // Navigate to results when auto-submitted
          Navigator.pushReplacementNamed(
            context, 
            '/results/$sessionId'
          );
        }
      });
    });
  }
  
  @override
  void dispose() {
    _answerController.dispose();
    // Clean up auto-submit callback using stored reference
    _examSessionService.setAutoSubmitCallback(null);
    super.dispose();
  }

  Future<bool> _loadData() async {
    // Fetch the session if it already exists
    if (widget.sessionId.isNotEmpty) {
      return context.examSessionService.fetchExamSession(widget.sessionId);
    }
    
    // Start a new session if the sessionId is empty
    return context.examSessionService.startExamSession(widget.examId);
  }
  
  SessionQuestion? get _currentQuestion {
    final questions = context.examSessionService.currentSession?.questions;
    if (questions == null || questions.isEmpty || _currentQuestionIndex >= questions.length) {
      return null;
    }
    return questions[_currentQuestionIndex];
  }
  
  bool get _isLastQuestion {
    final questionCount = context.examSessionService.currentSession?.questions.length ?? 0;
    return _currentQuestionIndex == questionCount - 1;
  }
  
  bool get _canSubmitExam {
    final questions = context.examSessionService.currentSession?.questions ?? [];
    return questions.every((q) => q.userAnswer != null && q.userAnswer!.isNotEmpty);
  }
  
  bool get _hasMarkedForReview {
    final questions = context.examSessionService.currentSession?.questions ?? [];
    return questions.any((q) => q.isMarkedForReview);
  }

  void _onAnswerSelected(String answerId) {
    setState(() {
      _selectedAnswer = answerId;
    });
  }

  void _nextQuestion() async {
    final questions = context.examSessionService.currentSession?.questions;
    
    // Show loading indicator when submitting answers
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Save the current answer
      if (_currentQuestion != null && questions != null) {
        if (_currentQuestion!.type == QuestionType.multipleChoice) {
          if (_selectedAnswer != null) {
            // For MCQ, pass the selected choice ID as an array
            await context.examSessionService.submitAnswer(
              _currentQuestion!.id, 
              _selectedAnswer!,
              mcqChoiceIds: [_selectedAnswer!],
            );
          }
        } else {
          final answerText = _answerController.text.trim();
          if (answerText.isNotEmpty) {
            await context.examSessionService.submitAnswer(_currentQuestion!.id, answerText);
          }
        }
      }
      
      // Move to the next question
      if (!_isLastQuestion) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _answerController.clear();
        });
      }
      
      // Prefill the answer field if there's a previously saved answer
      if (_currentQuestion != null && _currentQuestion!.userAnswer != null) {
        if (_currentQuestion!.type == QuestionType.multipleChoice) {
          setState(() {
            _selectedAnswer = _currentQuestion!.userAnswer;
          });
        } else {
          _answerController.text = _currentQuestion!.userAnswer ?? '';
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in _nextQuestion: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error: {error}', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _previousQuestion() async {
    final questions = context.examSessionService.currentSession?.questions;
    
    // Show loading indicator when submitting answers
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Save the current answer
      if (_currentQuestion != null && questions != null) {
        if (_currentQuestion!.type == QuestionType.multipleChoice) {
          if (_selectedAnswer != null) {
            // For MCQ, pass the selected choice ID as an array
            await context.examSessionService.submitAnswer(
              _currentQuestion!.id, 
              _selectedAnswer!,
              mcqChoiceIds: [_selectedAnswer!],
            );
          }
        } else {
          final answerText = _answerController.text.trim();
          if (answerText.isNotEmpty) {
            await context.examSessionService.submitAnswer(_currentQuestion!.id, answerText);
          }
        }
      }
      
      // Move to the previous question
      if (_currentQuestionIndex > 0) {
        setState(() {
          _currentQuestionIndex--;
          _selectedAnswer = null;
          _answerController.clear();
        });
      }
      
      // Prefill the answer field if there's a previously saved answer
      if (_currentQuestion != null && _currentQuestion!.userAnswer != null) {
        if (_currentQuestion!.type == QuestionType.multipleChoice) {
          setState(() {
            _selectedAnswer = _currentQuestion!.userAnswer;
          });
        } else {
          _answerController.text = _currentQuestion!.userAnswer ?? '';
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in _previousQuestion: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Error: {error}', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _toggleMarkForReview() {
    if (_currentQuestion != null) {
      context.examSessionService.toggleMarkForReview(_currentQuestion!.id);
      setState(() {}); // Refresh UI
    }
  }

  void _submitExam() async {
    // First save the current answer
    if (_currentQuestion != null) {
      if (_currentQuestion!.type == QuestionType.multipleChoice) {
        if (_selectedAnswer != null) {
          // For MCQ, pass the selected choice ID as an array
          await context.examSessionService.submitAnswer(
            _currentQuestion!.id, 
            _selectedAnswer!,
            mcqChoiceIds: [_selectedAnswer!],
          );
        }
      } else {
        await context.examSessionService.submitAnswer(_currentQuestion!.id, _answerController.text);
      }
    }
    
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Exam Submit Confirmation Title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Exam Submit Confirmation Message')),
            if (_hasMarkedForReview)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  context.tr('Exam Marked For Review Warning'),
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await context.examSessionService.submitExam();
              if (success) {
                if (!mounted) return;
                Navigator.pushReplacementNamed(
                  context, 
                  '/results/${context.examSessionService.currentSession!.id}'
                );
              }
            },
            child: Text(context.tr('Exam Submit')),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPagination() {
    final questions = context.examSessionService.currentSession?.questions ?? [];
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final question = questions[index];
          final isSelected = index == _currentQuestionIndex;
          final hasAnswer = question.userAnswer != null && question.userAnswer!.isNotEmpty;
          final isMarked = question.isMarkedForReview;
          
          Color bgColor;
          if (isSelected) {
            bgColor = AppColors.darkBlue;
          } else if (isMarked) {
            bgColor = Colors.orange;
          } else if (hasAnswer) {
            bgColor = Colors.green;
          } else {
            bgColor = AppColors.lightGrey;
          }
          
          return GestureDetector(
            onTap: () async {
              // Save current answer before jumping
              if (_currentQuestion != null) {
                if (_currentQuestion!.type == QuestionType.multipleChoice) {
                  if (_selectedAnswer != null) {
                    // For MCQ, pass the selected choice ID as an array
                    await context.examSessionService.submitAnswer(
                      _currentQuestion!.id, 
                      _selectedAnswer!,
                      mcqChoiceIds: [_selectedAnswer!],
                    );
                  }
                } else {
                  await context.examSessionService.submitAnswer(_currentQuestion!.id, _answerController.text);
                }
              }
              
              setState(() {
                _currentQuestionIndex = index;
                _selectedAnswer = null;
                _answerController.clear();
              });
              
              // Prefill if there's a saved answer
              if (questions[index].userAnswer != null) {
                if (questions[index].type == QuestionType.multipleChoice) {
                  setState(() {
                    _selectedAnswer = questions[index].userAnswer;
                  });
                } else {
                  _answerController.text = questions[index].userAnswer ?? '';
                }
              }
            },
            child: Container(
              width: 40,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: isSelected 
                  ? Border.all(color: AppColors.darkBlue, width: 2)
                  : null,
              ),
              child: Center(
                child: Text(
                  (index + 1).toString(),
                  style: TextStyle(
                    color: isSelected || hasAnswer || isMarked ? Colors.white : AppColors.darkGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.examSessionService.currentSession?.examName ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Consumer<ExamSessionService>(
                    builder: (context, service, _) => Text(
                      context.tr('Exam Time Remaining', params: {'time': service.formattedTimeRemaining}),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const LanguageSelector(isCompact: true),
          ],
        ),
      ),
      body: FutureBuilder<bool>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || snapshot.data == false) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Exam Session Error'),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('Go Back')),
                  ),
                ],
              ),
            );
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
        _buildQuestionPagination(),
        Expanded(
          child: _currentQuestion != null
              ? _buildQuestionContent()
              : Center(
                  child: Text(context.tr('No Questions Found')),
                ),
        ),
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildQuestionContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${context.tr('Question')} ${_currentQuestionIndex + 1}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(_currentQuestion!.difficulty).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _currentQuestion!.difficulty,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getDifficultyColor(_currentQuestion!.difficulty),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getQuestionTypeColor(_currentQuestion!.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getQuestionTypeText(_currentQuestion!.type),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getQuestionTypeColor(_currentQuestion!.type),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleMarkForReview,
                    icon: Icon(
                      _currentQuestion!.isMarkedForReview
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: _currentQuestion!.isMarkedForReview
                          ? Colors.orange
                          : AppColors.mediumGrey,
                    ),
                    tooltip: context.tr('Mark For Review'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Question text
          Text(
            _currentQuestion!.text,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkBlue,
            ),
          ),

          const SizedBox(height: 24),

          // Answer section - show the answer section directly
          Expanded(
            child: _buildAnswerSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerSection() {
    switch (_currentQuestion!.type) {
      case QuestionType.multipleChoice:
        return _buildMultipleChoiceAnswers();
      case QuestionType.openEnded:
        return _buildTextAnswerField();
      case QuestionType.calculation:
        return _buildCalculationView(_currentQuestion!);
    }
  }

  Widget _buildMultipleChoiceAnswers() {
    final options = _currentQuestion!.options ?? [];
    
    // No options to display
    if (options.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              context.tr('No options available'),
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }
    
    // If not submitted yet, show in "selection mode"
    if (_currentQuestion!.userAnswer == null || _currentQuestion!.userAnswer!.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = _selectedAnswer == option.id;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _onAnswerSelected(option.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.lightBlue.withOpacity(0.1) : Colors.white,
                        border: Border.all(
                          color: isSelected ? AppColors.darkBlue : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppColors.darkBlue : Colors.white,
                              border: Border.all(
                                color: isSelected ? AppColors.darkBlue : Colors.grey.shade400,
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
                                color: isSelected ? AppColors.darkBlue : AppColors.darkGrey,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : () async {
                if (_selectedAnswer == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('Please select an answer')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                // Prevent multiple submissions
                if (_isLoading) return;
                
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  // Submit the answer with the choice ID
                  final success = await context.examSessionService.submitAnswer(
                    _currentQuestion!.id, 
                    _selectedAnswer!,
                    mcqChoiceIds: [_selectedAnswer!],
                  );
                  
                  if (success) {
                    // Show success message without fetching session again (service already updated)
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('Answer Submitted')),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  } else {
                    // Show error from service
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.examSessionService.error ?? context.tr('Failed to submit answer')),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Error submitting answer: $e');
                  }
                  
                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Error: {error}', params: {'error': e.toString()})),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  // Hide loading state
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      context.tr('Submit Answer'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      );
    }

    // Check if the answer has been evaluated
    final hasBeenEvaluated = _currentQuestion!.isCorrect != null;
    final userAnswerId = _currentQuestion!.userAnswer;
    final correctAnswerId = _currentQuestion!.correctAnswer;
    
    // Debug output to help understand option and correctAnswer mismatch
    if (kDebugMode) {
      print('=========== MCQ DEBUG ===========');
      print('Correct answer ID: $correctAnswerId (${correctAnswerId.runtimeType})');
      print('User answer ID: $userAnswerId');
      if (_currentQuestion!.options != null) {
        print('Available options:');
        for (var option in _currentQuestion!.options!) {
          print('Option ID: ${option.id} (${option.id.runtimeType}), Text: ${option.text}');
        }
      } else {
        print('No options available!');
      }
      print('================================');
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = _selectedAnswer == option.id;
              final wasSubmitted = userAnswerId == option.id;
              final isCorrectAnswer = correctAnswerId == option.id;
              
              // Determine colors based on state
              Color borderColor = isSelected ? AppColors.darkBlue : AppColors.mediumGrey;
              Color bgColor = isSelected ? AppColors.darkBlueTransparent : Colors.white;
              
              // If answer has been evaluated, show correct/incorrect styling
              if (hasBeenEvaluated) {
                if (isCorrectAnswer) {
                  borderColor = Colors.green;
                  bgColor = Colors.green.withOpacity(0.1);
                } else if (wasSubmitted) {
                  borderColor = Colors.red;
                  bgColor = Colors.red.withOpacity(0.1);
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: hasBeenEvaluated ? null : () => _onAnswerSelected(option.id),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(
                        color: borderColor,
                        width: (isSelected || isCorrectAnswer || wasSubmitted) ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isSelected || isCorrectAnswer || wasSubmitted) ? 
                                  (isCorrectAnswer ? Colors.green : 
                                   wasSubmitted ? Colors.red : AppColors.darkBlue) : 
                                  Colors.white,
                            border: Border.all(
                              color: (isSelected || isCorrectAnswer || wasSubmitted) ? 
                                     (isCorrectAnswer ? Colors.green : 
                                      wasSubmitted ? Colors.red : AppColors.darkBlue) : 
                                     AppColors.mediumGrey,
                              width: 2,
                            ),
                          ),
                          child: (isSelected || isCorrectAnswer || wasSubmitted)
                              ? Icon(
                                  isCorrectAnswer ? Icons.check : 
                                  wasSubmitted ? Icons.close : Icons.circle,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.text,
                            style: TextStyle(
                              color: (isSelected || isCorrectAnswer || wasSubmitted) ? 
                                    (isCorrectAnswer ? Colors.green.shade800 : 
                                     wasSubmitted ? Colors.red.shade800 : AppColors.darkBlue) : 
                                    AppColors.darkGrey,
                              fontWeight: (isSelected || isCorrectAnswer || wasSubmitted) ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (hasBeenEvaluated && isCorrectAnswer)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                        if (hasBeenEvaluated && wasSubmitted && !isCorrectAnswer)
                          const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 16),
          child: ElevatedButton(
            onPressed: _isLoading ? null : () async {
              if (_selectedAnswer == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.tr('Please select an answer')),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Prevent multiple submissions
              if (_isLoading) return;
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                // Submit the answer with the choice ID
                final success = await context.examSessionService.submitAnswer(
                  _currentQuestion!.id, 
                  _selectedAnswer!,
                  mcqChoiceIds: [_selectedAnswer!],
                );
                
                if (success) {
                  // Show success message without fetching session again (service already updated)
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Answer Submitted')),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                } else {
                  // Show error from service
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.examSessionService.error ?? context.tr('Failed to submit answer')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Error submitting answer: $e');
                }
                
                // Show error message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('Error: {error}', params: {'error': e.toString()})),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                // Hide loading state
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkBlue,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    context.tr('Submit Answer'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        
        // Show correct answer message
        if (hasBeenEvaluated)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _currentQuestion!.isCorrect == true ? 
                    Colors.green.withOpacity(0.1) : 
                    Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentQuestion!.isCorrect == true ? Colors.green : Colors.red,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _currentQuestion!.isCorrect == true ? 
                      Icons.check_circle : 
                      Icons.cancel,
                      color: _currentQuestion!.isCorrect == true ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currentQuestion!.isCorrect == true ?
                      context.tr('correct_answer') :
                      context.tr('incorrect_answer'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentQuestion!.isCorrect == true ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                if (_currentQuestion!.isCorrect == false && _currentQuestion!.correctAnswer != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('correct_answer_is'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String>(
                    future: context.examSessionService.getCorrectAnswerText(_currentQuestion!.correctAnswer!),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.hasData ? snapshot.data! : _currentQuestion!.correctAnswer!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
                if (_currentQuestion!.explanation != null && _currentQuestion!.explanation!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('explanation'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_currentQuestion!.explanation!),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTextAnswerField() {
    final hasBeenEvaluated = _currentQuestion!.isCorrect != null;
    
    // If not yet answered, show the input field
    if (_currentQuestion!.userAnswer == null || _currentQuestion!.userAnswer!.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: TextField(
              controller: _answerController,
              decoration: InputDecoration(
                labelText: context.tr('Your Answer'),
                hintText: context.tr('Type your answer here'),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading || _answerController.text.trim().isEmpty ? null : () async {
                // Prevent multiple submissions
                if (_isLoading) return;
                
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  final answer = _answerController.text.trim();
                  if (answer.isNotEmpty) {
                    // Submit the answer
                    final success = await context.examSessionService.submitAnswer(
                      _currentQuestion!.id, 
                      answer,
                    );
                    
                    if (success) {
                      // Show success message without fetching session again (service already updated)
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('Answer Submitted')),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    } else {
                      // Show error from service
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.examSessionService.error ?? context.tr('Failed to submit answer')),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Please enter an answer')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Error submitting answer: $e');
                  }
                  
                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Error: {error}', params: {'error': e.toString()})),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  // Hide loading state
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.darkBlue,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      context.tr('Submit Answer'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      );
    }
    
    // If already answered, show the response with feedback
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User's answer
          Text(
            context.tr('Your Answer'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(_currentQuestion!.userAnswer ?? ''),
          ),
          const SizedBox(height: 16),
          
          // Evaluation result
          if (hasBeenEvaluated) 
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _currentQuestion!.isCorrect == true ? 
                      Colors.green.withOpacity(0.1) : 
                      Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _currentQuestion!.isCorrect == true ? Colors.green : Colors.red,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _currentQuestion!.isCorrect == true ? 
                        Icons.check_circle : 
                        Icons.cancel,
                        color: _currentQuestion!.isCorrect == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentQuestion!.isCorrect == true ?
                        context.tr('correct_answer') :
                        context.tr('incorrect_answer'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _currentQuestion!.isCorrect == true ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (_currentQuestion!.isCorrect == false && _currentQuestion!.correctAnswer != null) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('correct_answer_is'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentQuestion!.correctAnswer!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (_currentQuestion!.explanation != null && _currentQuestion!.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('explanation'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_currentQuestion!.explanation!),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalculationView(SessionQuestion question) {
    final hasBeenEvaluated = question.isCorrect != null;
    
    // If the question has not been answered yet
    if (question.userAnswer == null || question.userAnswer!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Optional workspace for calculations
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
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
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: context.tr('show_your_work_here'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
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
                  child: TextField(
                    controller: _answerController,
                    decoration: InputDecoration(
                      hintText: context.tr('enter_your_calculation_result'),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 1,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
          
          const SizedBox(height: 16),
          
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading || _answerController.text.trim().isEmpty ? null : () async {
                // Prevent multiple submissions
                if (_isLoading) return;
                
                setState(() {
                  _isLoading = true;
                });
                
                try {
                  final answer = _answerController.text.trim();
                  if (answer.isNotEmpty) {
                    // Submit the answer
                    final success = await context.examSessionService.submitAnswer(
                      _currentQuestion!.id, 
                      answer,
                    );
                    
                    if (success) {
                      // Show success message without fetching session again (service already updated)
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('Answer Submitted')),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    } else {
                      // Show error from service
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.examSessionService.error ?? context.tr('Failed to submit answer')),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Please enter an answer')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Error submitting answer: $e');
                  }
                  
                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('Error: {error}', params: {'error': e.toString()})),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  // Hide loading state
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.darkBlue,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      context.tr('Submit Answer'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      );
    }
    
    // If already answered, show the response with feedback
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User's answer
          Text(
            context.tr('Your Answer'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(question.userAnswer ?? ''),
          ),
          const SizedBox(height: 16),
          
          // Evaluation result
          if (hasBeenEvaluated) 
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: question.isCorrect == true ? 
                      Colors.green.withOpacity(0.1) : 
                      Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: question.isCorrect == true ? Colors.green : Colors.red,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        question.isCorrect == true ? 
                        Icons.check_circle : 
                        Icons.cancel,
                        color: question.isCorrect == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        question.isCorrect == true ?
                        context.tr('correct_answer') :
                        context.tr('incorrect_answer'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: question.isCorrect == true ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (question.isCorrect == false && question.correctAnswer != null) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('correct_answer_is'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question.correctAnswer!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('explanation'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(question.explanation!),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Submit button when all questions are answered (but not on last question)
          if (_canSubmitExam && !_isLastQuestion)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                onPressed: _submitExam,
                icon: const Icon(Icons.check_circle),
                label: Text(context.tr('submit_exam_all_answered')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          
          // Navigation row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button
              SizedBox(
                width: 100,
                child: _currentQuestionIndex > 0
                    ? OutlinedButton(
                        onPressed: _previousQuestion,
                        child: Text(context.tr('previous')),
                      )
                    : const SizedBox(),
              ),
              
              // Middle button - Mark for Review
              OutlinedButton.icon(
                onPressed: _toggleMarkForReview,
                icon: Icon(
                  _currentQuestion!.isMarkedForReview
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: _currentQuestion!.isMarkedForReview
                      ? Colors.orange
                      : null,
                ),
                label: Text(
                  _currentQuestion!.isMarkedForReview
                      ? context.tr('marked')
                      : context.tr('mark_for_review'),
                  style: TextStyle(
                    color: _currentQuestion!.isMarkedForReview
                        ? Colors.orange
                        : null,
                  ),
                ),
              ),
              
              // Next/Submit button
              SizedBox(
                width: 100,
                child: _isLastQuestion
                    ? ElevatedButton(
                        onPressed: _submitExam,
                        child: Text(context.tr('submit')),
                      )
                    : ElevatedButton(
                        onPressed: _nextQuestion,
                        child: Text(context.tr('next')),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'EASY':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'HARD':
        return Colors.red;
      default:
        return AppColors.darkBlue;
    }
  }

  Color _getQuestionTypeColor(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return Colors.purple;
      case QuestionType.openEnded:
        return Colors.teal;
      case QuestionType.calculation:
        return Colors.blue;
    }
  }

  String _getQuestionTypeText(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return context.tr('mcqs');
      case QuestionType.openEnded:
        return context.tr('open_ended');
      case QuestionType.calculation:
        return context.tr('calculation');
    }
  }
} 
