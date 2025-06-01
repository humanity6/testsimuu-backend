import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../models/exam_session.dart';
import '../../models/quiz.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/language_selector.dart';

class ExamResultsScreen extends StatefulWidget {
  final String sessionId;

  const ExamResultsScreen({
    Key? key,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> with SingleTickerProviderStateMixin {
  late Future<bool> _sessionFuture;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _sessionFuture = _loadData();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _loadData() async {
    return context.examSessionService.fetchExamSession(widget.sessionId);
  }
  
  double get _scorePercentage {
    final session = context.examSessionService.currentSession;
    if (session == null || session.totalScoreAchieved == null) return 0.0;
    
    // Calculate the raw percentage and clamp it between 0.0 and 1.0
    final rawPercentage = session.totalScoreAchieved! / session.totalPossibleScore;
    return rawPercentage.clamp(0.0, 1.0);
  }
  
  bool get _isPassed {
    final session = context.examSessionService.currentSession;
    return session?.passed == true;
  }
  
  Map<String, double> get _difficultyBreakdown {
    final questions = context.examSessionService.currentSession?.questions ?? [];
    if (questions.isEmpty) return {};
    
    final Map<String, List<SessionQuestion>> difficultyGroups = {};
    
    // Group questions by difficulty
    for (final question in questions) {
      if (!difficultyGroups.containsKey(question.difficulty)) {
        difficultyGroups[question.difficulty] = [];
      }
      difficultyGroups[question.difficulty]!.add(question);
    }
    
    // Calculate percentage correct for each difficulty
    final Map<String, double> result = {};
    difficultyGroups.forEach((difficulty, qs) {
      final correctCount = qs.where((q) => q.isCorrect == true).length;
      final rawPercentage = correctCount / qs.length;
      result[difficulty] = rawPercentage.clamp(0.0, 1.0);
    });
    
    return result;
  }
  
  Map<String, double> get _questionTypeBreakdown {
    final questions = context.examSessionService.currentSession?.questions ?? [];
    if (questions.isEmpty) return {};
    
    final Map<QuestionType, List<SessionQuestion>> typeGroups = {};
    
    // Group questions by type
    for (final question in questions) {
      if (!typeGroups.containsKey(question.type)) {
        typeGroups[question.type] = [];
      }
      typeGroups[question.type]!.add(question);
    }
    
    // Calculate percentage correct for each type
    final Map<String, double> result = {};
    typeGroups.forEach((type, qs) {
      final correctCount = qs.where((q) => q.isCorrect == true).length;
      final rawPercentage = correctCount / qs.length;
      final typeName = _getQuestionTypeText(type);
      result[typeName] = rawPercentage.clamp(0.0, 1.0);
    });
    
    return result;
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.amber;
    return Colors.red;
  }

  String _getScoreText(double score) {
    if (score >= 0.8) return context.tr('excellent');
    if (score >= 0.6) return context.tr('good');
    return context.tr('needs_improvement');
  }

  String _getQuestionTypeText(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return context.tr('mcq');
      case QuestionType.openEnded:
        return context.tr('open_ended');
      case QuestionType.calculation:
        return context.tr('calculation');
    }
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

  Widget _buildQuestionIcon(QuestionType type, bool isCorrect) {
    IconData icon;
    Color color;
    
    switch (type) {
      case QuestionType.multipleChoice:
        icon = Icons.check_circle_outline;
        break;
      case QuestionType.openEnded:
        icon = Icons.subject;
        break;
      case QuestionType.calculation:
        icon = Icons.calculate_outlined;
        break;
    }
    
    if (isCorrect == true) {
      color = Colors.green;
    } else if (isCorrect == false) {
      color = Colors.red;
    } else {
      color = AppColors.darkGrey;
    }
    
    return Icon(icon, color: color, size: 18);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                context.tr('exam_results'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const LanguageSelector(isCompact: true),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.tr('results_summary')),
            Tab(text: context.tr('question_review')),
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
                    context.tr('results_load_error'),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('go_back')),
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
    final session = context.examSessionService.currentSession;
    if (session == null) return const Center(child: Text('No session data available'));
    
    return TabBarView(
      controller: _tabController,
      children: [
        _buildSummaryTab(session),
        _buildQuestionReviewTab(session),
      ],
    );
  }

  Widget _buildSummaryTab(ExamSession session) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam title and info
          Text(
            session.examName ?? context.tr('exam'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          
          // Session details
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.mediumGrey,
              ),
              const SizedBox(width: 4),
              Text(
                '${context.tr('date')}: ${_formatDate(session.startTime)}',
                style: TextStyle(
                  color: AppColors.mediumGrey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.timer,
                size: 16,
                color: AppColors.mediumGrey,
              ),
              const SizedBox(width: 4),
              Text(
                '${context.tr('duration')}: ${_formatDuration(session.startTime, session.actualEndTime)}',
                style: TextStyle(
                  color: AppColors.mediumGrey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Overall score
          Center(
            child: Column(
              children: [
                // Pass/Fail indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isPassed ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _isPassed ? context.tr('passed') : context.tr('failed'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Circular progress indicator
                CircularPercentIndicator(
                  radius: 70.0,
                  lineWidth: 13.0,
                  animation: true,
                  percent: _scorePercentage,
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(_scorePercentage * 100).toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24.0,
                        ),
                      ),
                      Text(
                        _getScoreText(_scorePercentage),
                        style: TextStyle(
                          color: _getScoreColor(_scorePercentage),
                          fontWeight: FontWeight.bold,
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      '${session.totalScoreAchieved?.toStringAsFixed(1) ?? "0"} / ${session.totalPossibleScore.toStringAsFixed(1)} ${context.tr('points')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                  circularStrokeCap: CircularStrokeCap.round,
                  progressColor: _getScoreColor(_scorePercentage),
                  backgroundColor: AppColors.lightGrey,
                ),
                
                const SizedBox(height: 24),
                
                // Pass threshold
                Text(
                  context.tr('pass_threshold', params: {'threshold': (session.passThreshold * 100).toInt().toString()}),
                  style: TextStyle(
                    color: AppColors.mediumGrey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Score breakdown by difficulty
          _buildBreakdownSection(
            context.tr('performance_by_difficulty'),
            _difficultyBreakdown.entries.map((entry) => 
              _buildBreakdownItem(
                entry.key, 
                entry.value, 
                _getDifficultyColor(entry.key)
              )
            ).toList()
          ),
          
          const SizedBox(height: 24),
          
          // Score breakdown by question type
          _buildBreakdownSection(
            context.tr('performance_by_question_type'),
            _questionTypeBreakdown.entries.map((entry) => 
              _buildBreakdownItem(
                entry.key, 
                entry.value, 
                AppColors.darkBlue
              )
            ).toList()
          ),
          
          const SizedBox(height: 32),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  _tabController.animateTo(1); // Switch to review tab
                },
                icon: const Icon(Icons.rate_review),
                label: Text(context.tr('review_answers')),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.home),
                label: Text(context.tr('go_to_dashboard')),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildBreakdownSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }
  
  Widget _buildBreakdownItem(String label, double percentage, Color color) {
    // Handle NaN and clamp percentage to ensure it's between 0.0 and 1.0
    final percent = percentage.isNaN ? 0.0 : percentage.clamp(0.0, 1.0);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(percent * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(percent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearPercentIndicator(
            lineHeight: 10.0,
            percent: percent,
            backgroundColor: AppColors.lightGrey,
            progressColor: color,
            barRadius: const Radius.circular(5),
            animation: true,
            animationDuration: 1000,
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuestionReviewTab(ExamSession session) {
    final questions = session.questions;
    
    if (questions.isEmpty) {
      return Center(child: Text(context.tr('no_questions')));
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return _buildQuestionReviewItem(question, index);
      },
    );
  }
  
  Widget _buildQuestionReviewItem(SessionQuestion question, int index) {
    final isCorrect = question.isCorrect ?? false;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isCorrect ? Colors.green.shade200 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: _buildQuestionIcon(question.type, isCorrect),
        title: Text(
          'Q${index + 1}: ${question.text.length > 50 ? question.text.substring(0, 50) + '...' : question.text}',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isCorrect ? Colors.green.shade800 : Colors.red.shade800,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getDifficultyColor(question.difficulty).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                question.difficulty,
                style: TextStyle(
                  fontSize: 10,
                  color: _getDifficultyColor(question.difficulty),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isCorrect ? context.tr('correct') : context.tr('incorrect'),
              style: TextStyle(
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full question
                Text(
                  question.text,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.darkBlue,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Question type specific display
                if (question.type == QuestionType.multipleChoice)
                  _buildMCQReview(question)
                else
                  _buildTextAnswerReview(question),
                
                // Explanation if available
                if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('explanation'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.darkGrey,
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
  
  Widget _buildMCQReview(SessionQuestion question) {
    final options = question.options;
    if (options == null || options.isEmpty) {
      return const Text('No options available');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Your answer
        Text(
          context.tr('your_answer'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...options.map((option) {
          final isUserAnswer = question.userAnswer == option.id;
          final isCorrectAnswer = question.correctAnswer == option.id;
          
          Color? bgColor;
          if (isUserAnswer && isCorrectAnswer) {
            bgColor = Colors.green.withOpacity(0.1);
          } else if (isUserAnswer && !isCorrectAnswer) {
            bgColor = Colors.red.withOpacity(0.1);
          } else if (isCorrectAnswer) {
            bgColor = Colors.green.withOpacity(0.1);
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(
                color: isCorrectAnswer 
                  ? Colors.green 
                  : isUserAnswer 
                    ? Colors.red 
                    : AppColors.lightGrey,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isUserAnswer
                    ? isCorrectAnswer
                      ? Icons.check_circle
                      : Icons.cancel
                    : isCorrectAnswer
                      ? Icons.check_circle_outline
                      : Icons.circle_outlined,
                  color: isUserAnswer
                    ? isCorrectAnswer
                      ? Colors.green
                      : Colors.red
                    : isCorrectAnswer
                      ? Colors.green
                      : AppColors.mediumGrey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(option.text),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
  
  Widget _buildTextAnswerReview(SessionQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Your answer
        Text(
          context.tr('your_answer'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (question.isCorrect == true)
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            border: Border.all(
              color: (question.isCorrect == true)
                  ? Colors.green
                  : Colors.red,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            question.userAnswer ?? context.tr('no_answer_provided'),
            style: TextStyle(
              color: AppColors.darkGrey,
              fontStyle: question.userAnswer == null || question.userAnswer!.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ),
        
        // Correct answer if different
        if (question.isCorrect == false && question.correctAnswer != null && question.correctAnswer!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            context.tr('correct_answer'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              question.correctAnswer!,
              style: const TextStyle(
                color: AppColors.darkGrey,
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return '-- min';
    
    final duration = end.difference(start);
    final minutes = duration.inMinutes;
    
    if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = duration.inHours;
      final remainingMinutes = minutes - (hours * 60);
      return '$hours h $remainingMinutes min';
    }
  }
} 