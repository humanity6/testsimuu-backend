import 'package:flutter/material.dart';
import '../models/quiz.dart';
import '../theme.dart';

class QuizCard extends StatelessWidget {
  final Quiz quiz;
  final VoidCallback onTap;

  const QuizCard({
    Key? key,
    required this.quiz,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      quiz.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildDifficultyBadge(context, quiz.difficulty),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Kategorie: ${quiz.category}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${quiz.questions.length} Fragen • ${quiz.timeLimit} Minuten',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mediumGrey,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuestionTypeBadge(context, 'Multiple Choice'),
                  const SizedBox(width: 8),
                  _buildQuestionTypeBadge(context, 'Berechnung'),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    color: AppColors.darkBlue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyBadge(BuildContext context, String difficulty) {
    Color backgroundColor;
    
    switch (difficulty.toLowerCase()) {
      case 'einfach':
        backgroundColor = Colors.green;
        break;
      case 'mittel':
        backgroundColor = Colors.orange;
        break;
      case 'schwer':
        backgroundColor = Colors.red;
        break;
      default:
        backgroundColor = AppColors.mediumGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        difficulty,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildQuestionTypeBadge(BuildContext context, String type) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          type,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.darkGrey,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
} 