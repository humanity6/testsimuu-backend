import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exam.dart';
import '../../theme.dart';
import '../../widgets/language_selector.dart';
import '../../providers/app_providers.dart';
import '../../services/localization_service.dart';
import 'exam_details_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({Key? key}) : super(key: key);

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  String _searchQuery = '';
  String _selectedSubject = '';
  bool _isLoading = true;
  List<Exam> _filteredExams = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
    });

    await context.examService.fetchAllExams();
    _updateFilteredExams();

    setState(() {
      _isLoading = false;
    });
  }

  void _updateFilteredExams() {
    List<Exam> exams = context.examService.allExams;

    // Apply subject filter
    if (_selectedSubject.isNotEmpty) {
      exams = context.examService.getExamsBySubject(_selectedSubject);
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final lowercaseQuery = _searchQuery.toLowerCase();
      exams = exams.where((exam) {
        return exam.title.toLowerCase().contains(lowercaseQuery) ||
            exam.description.toLowerCase().contains(lowercaseQuery) ||
            exam.subject.toLowerCase().contains(lowercaseQuery);
      }).toList();
    }

    setState(() {
      _filteredExams = exams;
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _updateFilteredExams();
  }

  void _onSubjectSelected(String subject) {
    setState(() {
      _selectedSubject = subject;
    });
    _updateFilteredExams();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = context.examService.subjects;
    final error = context.examService.error;

    return Consumer<LocalizationService>(
      builder: (context, localizationService, child) {
        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            elevation: 0,
            title: Row(
              children: [
                Text(
                  context.tr('app_title'),
                  style: const TextStyle(
                    color: AppColors.darkBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const Spacer(),
                const LanguageSelector(isCompact: true),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.darkBlue),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              _buildSearchAndFilter(context, subjects),
              if (error != null && !_isLoading) _buildErrorView(context, error),
              if (_isLoading) _buildLoadingView(),
              if (!_isLoading && error == null) _buildExamsList(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        color: AppColors.limeYellow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('exams_title'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('exams_subtitle'),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(BuildContext context, List<String> subjects) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: const BoxDecoration(
        color: AppColors.limeYellow,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: context.tr('exams_search_placeholder'),
              prefixIcon: const Icon(Icons.search, color: AppColors.darkBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          // Subject filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  context.tr('exams_filter_all'),
                  _selectedSubject.isEmpty,
                  () => _onSubjectSelected(''),
                ),
                ...subjects.map((subject) {
                  return _buildFilterChip(
                    context,
                    subject,
                    _selectedSubject == subject,
                    () => _onSubjectSelected(subject),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.darkBlue : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppColors.darkBlue.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.white : AppColors.darkBlue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.darkBlue),
            const SizedBox(height: 16),
            Text(
              context.tr('exams_loading'),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.darkGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('exams_error_loading'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadExams,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(context.tr('exams_try_again')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamsList(BuildContext context) {
    if (_filteredExams.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            context.tr('exams_no_results'),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkGrey,
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              context.tr('exams_count').replaceAll('{count}', _filteredExams.length.toString()),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGrey,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int crossAxisCount;
                double childAspectRatio;
                
                if (width < 600) {
                  crossAxisCount = 1;
                  childAspectRatio = 3.5; // Even more height for mobile single column
                } else if (width < 900) {
                  crossAxisCount = 2;
                  childAspectRatio = 2.5; // Even more height for tablets
                } else {
                  crossAxisCount = 3;
                  childAspectRatio = 2.1; // Even more height for desktop
                }
                
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredExams.length,
                  itemBuilder: (context, index) {
                    return _buildExamCard(context, _filteredExams[index]);
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, Exam exam) {
    return InkWell(
      onTap: () => _navigateToExamDetails(exam.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBlue.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section with subject and subscription tag
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: exam.getDifficultyColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        context.tr(exam.getTranslatedDifficulty(context)),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: exam.getDifficultyColor(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (exam.requiresSubscription)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.darkBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.tr('exams_subscription_required'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.tr('exams_free'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Header with title and info icon
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 8, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exam title
                  Expanded(
                    child: Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkBlue,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Enhanced info icon with animations and attention-grabbing design
                  Tooltip(
                    message: context.tr('exams_view_details'),
                    preferBelow: false,
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.9 + (0.1 * value),
                          child: InkWell(
                            onTap: () => _navigateToExamDetails(exam.id),
                            borderRadius: BorderRadius.circular(25),
                            splashColor: AppColors.darkBlue.withOpacity(0.3),
                            highlightColor: AppColors.darkBlue.withOpacity(0.2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.darkBlue,
                                    AppColors.darkBlue.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.darkBlue.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Pulsing background effect
                                  AnimatedContainer(
                                    duration: Duration(milliseconds: (1000 * value).round()),
                                    width: 20 + (4 * value),
                                    height: 20 + (4 * value),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1 * value),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  // Main icon
                                  const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Exam description - now with more space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text(
                  exam.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.darkGrey,
                    height: 1.3,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            
            // Stats row at bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 14,
                    color: AppColors.mediumGrey,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      context.tr('exams_questions').replaceAll('{count}', exam.questionCount.toString()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mediumGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: AppColors.mediumGrey,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      context.tr('exams_minutes').replaceAll('{count}', exam.timeLimit.toString()),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mediumGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToExamDetails(String examId) {
    print('Navigate to exam details: $examId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamDetailsScreen(examId: examId),
      ),
    );
  }
} 