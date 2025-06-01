import 'package:flutter/material.dart';
import '../../models/quiz.dart';
import '../../theme.dart';
import '../../widgets/custom_button.dart';
import 'quiz_progress_screen.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizScreen({
    Key? key,
    required this.quiz,
  }) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  String? _userAnswer;
  bool _answerSubmitted = false;
  List<String> _userAnswers = [];
  int? _correctAnswerIndex;

  @override
  void initState() {
    super.initState();
    _userAnswers = List.filled(widget.quiz.questions.length, '');
  }

  Question get _currentQuestion => widget.quiz.questions[_currentQuestionIndex];

  void _onAnswerSelected(String answer) {
    setState(() {
      _selectedAnswer = answer;
    });
  }

  void _onTextAnswerChanged(String value) {
    setState(() {
      _userAnswer = value;
    });
  }

  void _submitAnswer() {
    setState(() {
      _answerSubmitted = true;
      if (_currentQuestion.type == QuestionType.multipleChoice) {
        _userAnswers[_currentQuestionIndex] = _selectedAnswer ?? '';
      } else {
        _userAnswers[_currentQuestionIndex] = _userAnswer ?? '';
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _userAnswer = null;
        _answerSubmitted = false;
      } else {
        // Navigate to results or progress screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizProgressScreen(
              quiz: widget.quiz,
              userAnswers: _userAnswers,
            ),
          ),
        );
      }
    });
  }

  void _skipQuestion() {
    setState(() {
      _userAnswers[_currentQuestionIndex] = '';
      _nextQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text(widget.quiz.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: (_currentQuestionIndex + 1) / widget.quiz.questions.length,
                backgroundColor: AppColors.lightGrey,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.darkBlue),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                'Frage ${_currentQuestionIndex + 1} von ${widget.quiz.questions.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 32),
              
              // Question
              Text(
                _currentQuestion.text,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              
              // Answer options or input
              Expanded(
                child: _buildQuestionContent(),
              ),
              
              // Solution explanation (when answer is submitted)
              if (_answerSubmitted && _currentQuestion.solutionSteps != null)
                _buildSolutionSteps(),
              
              // Bottom buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Überspringen',
                      onPressed: _skipQuestion,
                      type: ButtonType.outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      text: _answerSubmitted ? 'Speichern & Weiter' : 'Antwort prüfen',
                      onPressed: _answerSubmitted ? _nextQuestion : _submitAnswer,
                      type: ButtonType.primary,
                      isFullWidth: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionContent() {
    switch (_currentQuestion.type) {
      case QuestionType.multipleChoice:
        return _buildMultipleChoiceQuestion();
      case QuestionType.openEnded:
        return _buildOpenEndedQuestion();
      case QuestionType.calculation:
        return _buildCalculationQuestion();
    }
  }

  Widget _buildMultipleChoiceQuestion() {
    return ListView.builder(
      itemCount: _currentQuestion.options!.length,
      itemBuilder: (context, index) {
        final option = _currentQuestion.options![index];
        final isSelected = _selectedAnswer == option.id;
        final isCorrect = _answerSubmitted && option.id == _currentQuestion.correctAnswer;
        final isWrong = _answerSubmitted && isSelected && option.id != _currentQuestion.correctAnswer;
        
        // Find the correct answer option index for displaying the letter later
        if (_answerSubmitted && option.id == _currentQuestion.correctAnswer) {
          _correctAnswerIndex = index;
        }
        
        Color backgroundColor;
        Color borderColor;
        Color textColor;
        
        if (isCorrect) {
          backgroundColor = Colors.green.withOpacity(0.1);
          borderColor = Colors.green;
          textColor = Colors.green;
        } else if (isWrong) {
          backgroundColor = Colors.red.withOpacity(0.1);
          borderColor = Colors.red;
          textColor = Colors.red;
        } else {
          backgroundColor = isSelected ? AppColors.darkBlue.withOpacity(0.1) : AppColors.white;
          borderColor = isSelected ? AppColors.darkBlue : AppColors.lightGrey;
          textColor = isSelected ? AppColors.darkBlue : AppColors.darkGrey;
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: _answerSubmitted ? null : () => _onAnswerSelected(option.id),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.darkBlue : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.darkBlue : AppColors.mediumGrey,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getOptionLabel(index),
                        style: TextStyle(
                          color: isSelected ? AppColors.white : AppColors.darkGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      option.text,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isCorrect)
                    const Icon(Icons.check_circle, color: Colors.green),
                  if (isWrong)
                    const Icon(Icons.cancel, color: Colors.red),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpenEndedQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deine Antwort:',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            enabled: !_answerSubmitted,
            maxLines: 8,
            onChanged: _onTextAnswerChanged,
            decoration: InputDecoration(
              hintText: 'Schreibe hier deine Antwort...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: AppColors.white,
            ),
          ),
        ),
        if (_answerSubmitted)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.green,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beispielhafte richtige Antwort:',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getCorrectAnswerText(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalculationQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deine Antwort:',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          enabled: !_answerSubmitted,
          keyboardType: TextInputType.number,
          onChanged: _onTextAnswerChanged,
          decoration: InputDecoration(
            hintText: 'Gib dein Ergebnis ein',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            filled: true,
            fillColor: AppColors.white,
          ),
        ),
        if (_answerSubmitted)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _userAnswer == _currentQuestion.correctAnswer
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _userAnswer == _currentQuestion.correctAnswer
                      ? Colors.green
                      : Colors.red,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _userAnswer == _currentQuestion.correctAnswer
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: _userAnswer == _currentQuestion.correctAnswer
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _userAnswer == _currentQuestion.correctAnswer
                            ? 'Richtig!'
                            : 'Falsch!',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _userAnswer == _currentQuestion.correctAnswer
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Richtige Antwort: ${_getCorrectAnswerText()}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
      ],
    );
  }

  Widget _buildSolutionSteps() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grundlegende Erklärung:',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _currentQuestion.solutionSteps!.map((step) {
              final stepIndex = _currentQuestion.solutionSteps!.indexOf(step);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schritt ${stepIndex + 1}: ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Helper method to convert option index to letter label
  String _getOptionLabel(int index) {
    // Convert index to letter (0 -> A, 1 -> B, etc.)
    return String.fromCharCode(65 + index); // 65 is ASCII for 'A'
  }

  // Display the correct answer using letter labels for MCQ questions
  String _getCorrectAnswerText() {
    if (_currentQuestion.type == QuestionType.multipleChoice && _currentQuestion.options != null) {
      // Find the correct option based on the correctAnswer ID
      for (int i = 0; i < _currentQuestion.options!.length; i++) {
        if (_currentQuestion.options![i].id == _currentQuestion.correctAnswer) {
          return '${_getOptionLabel(i)} - ${_currentQuestion.options![i].text}';
        }
      }
    }
    return _currentQuestion.correctAnswer ?? '';
  }

  // Find option text by ID
  String _findOptionTextById(String? id) {
    if (id == null || _currentQuestion.options == null) return '';
    
    for (var option in _currentQuestion.options!) {
      if (option.id == id) {
        return option.text;
      }
    }
    return '';
  }
} 