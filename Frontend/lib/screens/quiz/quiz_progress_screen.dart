import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/quiz.dart';
import '../../theme.dart';
import '../../widgets/custom_button.dart';
import '../providers/app_providers.dart';

class QuizProgressScreen extends StatelessWidget {
  final Quiz quiz;
  final List<String> userAnswers;

  const QuizProgressScreen({
    Key? key,
    required this.quiz,
    required this.userAnswers,
  }) : super(key: key);

  int get _calculateScore {
    int score = 0;
    for (int i = 0; i < quiz.questions.length; i++) {
      if (userAnswers[i] == quiz.questions[i].correctAnswer) {
        score++;
      }
    }
    return score;
  }

  double get _calculatePercentage {
    return _calculateScore / quiz.questions.length;
  }

  // Helper method to convert option index to letter label
  String _getOptionLabel(int index) {
    // Convert index to letter (0 -> A, 1 -> B, etc.)
    return String.fromCharCode(65 + index); // 65 is ASCII for 'A'
  }

  // Format the correct answer for display
  String _formatCorrectAnswer(Question question) {
    if (question.type == QuestionType.multipleChoice && question.options != null) {
      // Find the index of the correct answer option
      for (int i = 0; i < question.options!.length; i++) {
        if (question.options![i].id == question.correctAnswer) {
          return '${_getOptionLabel(i)} - ${question.options![i].text}';
        }
      }
    }
    return question.correctAnswer ?? '';
  }

  // Format user answer for display
  String _formatUserAnswer(Question question, String userAnswer) {
    if (question.type == QuestionType.multipleChoice && question.options != null && userAnswer.isNotEmpty) {
      // Find the option text for the user's answer
      for (int i = 0; i < question.options!.length; i++) {
        if (question.options![i].id == userAnswer) {
          return '${_getOptionLabel(i)} - ${question.options![i].text}';
        }
      }
    }
    return userAnswer.isEmpty ? 'Keine Antwort' : userAnswer;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: Text(context.tr('Quiz Fortschritt')),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                context.tr('You have completed the quiz!'),
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '${_calculateScore} ${context.tr('of')} ${quiz.questions.length} ${context.tr('questions answered correctly')}',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Results Circle
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getScoreColor(_calculatePercentage).withOpacity(0.2),
                  border: Border.all(
                    color: _getScoreColor(_calculatePercentage),
                    width: 8,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${(_calculatePercentage * 100).toInt()}%',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: _getScoreColor(_calculatePercentage),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Question Grid
              Expanded(
                child: _buildQuestionGrid(context),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Zur Startseite',
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MainScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      type: ButtonType.outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      text: 'Ergebnisse teilen',
                      onPressed: () {},
                      type: ButtonType.primary,
                      icon: Icons.share,
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

  Widget _buildQuestionGrid(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: quiz.questions.length,
      itemBuilder: (context, index) {
        final isCorrect = userAnswers[index] == quiz.questions[index].correctAnswer;
        final isAnswered = userAnswers[index].isNotEmpty;
        
        Color backgroundColor;
        Color textColor;
        
        if (!isAnswered) {
          backgroundColor = AppColors.lightGrey;
          textColor = AppColors.mediumGrey;
        } else if (isCorrect) {
          backgroundColor = Colors.green;
          textColor = AppColors.white;
        } else {
          backgroundColor = Colors.red;
          textColor = AppColors.white;
        }
        
        return InkWell(
          onTap: () => _showQuestionDetailsDialog(context, index),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQuestionDetailsDialog(BuildContext context, int index) {
    final question = quiz.questions[index];
    final userAnswer = userAnswers[index];
    final isCorrect = userAnswer == question.correctAnswer;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Frage ${index + 1}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question.text,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Deine Antwort:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _formatUserAnswer(question, userAnswer),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: userAnswer.isEmpty
                      ? AppColors.mediumGrey
                      : (isCorrect ? Colors.green : Colors.red),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Richtige Antwort:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _formatCorrectAnswer(question),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (question.solutionSteps != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Lösungsschritte:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ...question.solutionSteps!.map((step) {
                  final stepIndex = question.solutionSteps!.indexOf(step);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text('${stepIndex + 1}. $step'),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 0.8) {
      return Colors.green;
    } else if (percentage >= 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
} 