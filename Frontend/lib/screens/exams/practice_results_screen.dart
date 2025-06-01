import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../models/exam_session.dart';
import '../../models/quiz.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/language_selector.dart';

class PracticeResultsScreen extends StatefulWidget {
  final String sessionId;

  const PracticeResultsScreen({
    Key? key,
    required this.sessionId,
  }) : super(key: key);

  @override
  State<PracticeResultsScreen> createState() => _PracticeResultsScreenState();
}

class _PracticeResultsScreenState extends State<PracticeResultsScreen> with SingleTickerProviderStateMixin {
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
  
  // Separate calculation for question-based accuracy (different from score-based percentage)
  double get _accuracyPercentage {
    if (_totalQuestions == 0) return 0.0;
    final rawAccuracy = _correctAnswers / _totalQuestions;
    return rawAccuracy.clamp(0.0, 1.0);
  }
  
  int get _correctAnswers {
    final questions = context.examSessionService.currentSession?.questions ?? [];
    return questions.where((q) => q.isCorrect == true).length;
  }
  
  int get _totalQuestions {
    return context.examSessionService.currentSession?.questions.length ?? 0;
  }

  String get _practiceLevel {
    // Use accuracy for practice level instead of score percentage
    if (_accuracyPercentage >= 0.9) return context.tr('excellent');
    if (_accuracyPercentage >= 0.8) return context.tr('very_good');
    if (_accuracyPercentage >= 0.7) return context.tr('good');
    if (_accuracyPercentage >= 0.6) return context.tr('satisfactory');
    if (_accuracyPercentage >= 0.5) return context.tr('needs_improvement');
    return context.tr('more_practice_needed');
  }
  
  Color get _levelColor {
    if (_accuracyPercentage >= 0.8) return Colors.green;
    if (_accuracyPercentage >= 0.6) return Colors.amber;
    return Colors.red;
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
    
    // Calculate percentage correct for each difficulty and use translated labels
    final Map<String, double> result = {};
    difficultyGroups.forEach((difficulty, qs) {
      final correctCount = qs.where((q) => q.isCorrect == true).length;
      final rawPercentage = correctCount / qs.length;
      final translatedDifficulty = _getDifficultyText(difficulty);
      result[translatedDifficulty] = rawPercentage.clamp(0.0, 1.0);
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

  String _getDifficultyText(String difficulty) {
    switch (difficulty.toUpperCase()) {
      case 'EASY':
        return context.tr('easy');
      case 'MEDIUM':
        return context.tr('medium');
      case 'HARD':
        return context.tr('hard');
      default:
        return difficulty.toLowerCase().replaceAll('_', ' ').split(' ').map((word) => 
          word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '').join(' ');
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toUpperCase()) {
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

  Color _getDifficultyColorByLabel(String label) {
    switch (label.toUpperCase()) {
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
                context.tr('practice_results'),
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
            Tab(text: context.tr('practice_summary')),
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
        children: [
          // Practice completion message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.darkBlue,
                  AppColors.darkBlue.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('practice_completed'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  session.examName ?? context.tr('practice_session'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Score overview
          _buildScoreOverview(),
          
          const SizedBox(height: 24),
          
          // Performance breakdown
          if (_difficultyBreakdown.isNotEmpty || _questionTypeBreakdown.isNotEmpty) ...[
            _buildPerformanceBreakdown(),
            const SizedBox(height: 24),
          ],
          
          // Action buttons
          _buildActionButtons(),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScoreOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Performance level indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _levelColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _practiceLevel,
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
            radius: 60.0,
            lineWidth: 8.0,
            percent: _accuracyPercentage,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(_accuracyPercentage * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                Text(
                  context.tr('accuracy'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.darkGrey,
                  ),
                ),
              ],
            ),
            progressColor: _levelColor,
            backgroundColor: AppColors.lightGrey,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          
          const SizedBox(height: 24),
          
          // Score details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildScoreDetail(
                context.tr('correct_answers'),
                '$_correctAnswers',
                Colors.green,
                Icons.check_circle,
              ),
              _buildScoreDetail(
                context.tr('total_questions'),
                '$_totalQuestions',
                AppColors.darkBlue,
                Icons.help_outline,
              ),
              _buildScoreDetail(
                context.tr('accuracy'),
                '${(_accuracyPercentage * 100).toInt()}%',
                _levelColor,
                Icons.precision_manufacturing,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDetail(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.darkGrey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPerformanceBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('performance_breakdown'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_difficultyBreakdown.isNotEmpty) ...[
            _buildBreakdownSection(
              context.tr('by_difficulty'),
              _difficultyBreakdown.entries.map((entry) => 
                _buildBreakdownItem(
                  entry.key,
                  entry.value,
                  _getDifficultyColorByLabel(entry.key),
                )
              ).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          if (_questionTypeBreakdown.isNotEmpty) ...[
            _buildBreakdownSection(
              context.tr('by_question_type'),
              _questionTypeBreakdown.entries.map((entry) => 
                _buildBreakdownItem(
                  entry.key,
                  entry.value,
                  AppColors.darkBlue,
                )
              ).toList(),
            ),
          ],
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.darkGrey,
          ),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget _buildBreakdownItem(String label, double percentage, Color color) {
    // Clamp percentage to ensure it's between 0.0 and 1.0
    final clampedPercentage = percentage.clamp(0.0, 1.0);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Row(
            children: [
              Container(
                width: 60,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  widthFactor: clampedPercentage,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(clampedPercentage * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
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
                // Navigate back to exam details or practice selection
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.home),
              label: Text(context.tr('go_to_dashboard')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Practice again button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // Go back to practice mode for the same exam
              Navigator.of(context).popUntil((route) => 
                route.settings.name?.contains('exam-mode-selection') == true ||
                route.isFirst
              );
            },
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('practice_again')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionReviewTab(ExamSession session) {
    final questions = session.questions;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildQuestionIcon(question.type, question.isCorrect ?? false),
                    const SizedBox(width: 8),
                    Text(
                      '${context.tr('question')} ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(question.difficulty).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getDifficultyText(question.difficulty),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getDifficultyColor(question.difficulty),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  question.text,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                
                if (question.userAnswer != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('your_answer')}: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          question.userAnswer!,
                          style: TextStyle(
                            fontSize: 12,
                            color: question.isCorrect == true ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                if (question.correctAnswer != null && question.isCorrect != true) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.tr('correct_answer')}: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          question.correctAnswer!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('explanation'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    question.explanation!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.darkGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
} 