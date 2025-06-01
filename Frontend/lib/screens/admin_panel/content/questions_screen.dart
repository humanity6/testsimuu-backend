import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../models/question.dart';
import '../../../models/topic.dart';
import '../../../widgets/custom_button.dart' show CustomButton, ButtonType;
import '../../../services/admin_service.dart';
import '../../../utils/responsive_utils.dart';
import '../../../widgets/responsive_admin_widgets.dart';
import 'question_form_screen.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({Key? key}) : super(key: key);

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Question> _questions = [];
  List<Question> _filteredQuestions = [];
  String? _errorMessage;
  late AdminService _adminService;
  
  // Filter state
  String? _selectedType;
  String? _selectedTopic;
  String? _selectedDifficulty;
  
  // Filter options
  final List<String> _questionTypes = ['mcq', 'open_ended', 'calculation'];
  List<Topic> _topics = [];
  final List<String> _difficulties = ['easy', 'medium', 'hard', 'very_hard'];

  @override
  void initState() {
    super.initState();
    _initializeAdminService();
    _searchController.addListener(_filterQuestionsBySearch);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeAdminService() {
    final authService = context.authService;
    final user = authService.currentUser;
    final accessToken = authService.accessToken;
    
    if (user != null && accessToken != null && user.isStaff) {
      _adminService = AdminService(accessToken: accessToken);
      _loadData();
    } else {
      // Handle case where user is not authenticated or not admin
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load topics and questions from the admin service
      // Load all topics (no exam filter for questions management screen)
      final topicsData = await _adminService.getTopics();
      final questionsData = await _adminService.getQuestions(
        topicId: _selectedTopic,
        questionType: _selectedType,
        difficulty: _selectedDifficulty,
      );
      
      setState(() {
        _topics = topicsData;
        _questions = questionsData;
        _filteredQuestions = questionsData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  void _filterQuestionsBySearch() {
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      final searchTerm = _searchController.text.toLowerCase();
      
      _filteredQuestions = _questions.where((question) {
        // Apply text search
        final matchesSearch = searchTerm.isEmpty || 
            question.text.toLowerCase().contains(searchTerm);
        
        // Apply type filter
        if (_selectedType != null && question.type != _selectedType) {
          return false;
        }
        
        // Apply topic filter
        if (_selectedTopic != null && question.topicId != _selectedTopic) {
          return false;
        }
        
        // Apply difficulty filter
        if (_selectedDifficulty != null && question.difficulty != _selectedDifficulty) {
          return false;
        }
        
        return matchesSearch;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedType = null;
      _selectedTopic = null;
      _selectedDifficulty = null;
      _searchController.clear();
      _filteredQuestions = _questions;
    });
  }

  void _navigateToAddQuestion() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuestionFormScreen(),
        fullscreenDialog: true,
      ),
    ).then((_) => _loadData());
  }

  void _navigateToEditQuestion(Question question) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuestionFormScreen(question: question),
        fullscreenDialog: true,
      ),
    ).then((_) => _loadData());
  }

  Future<void> _deleteQuestion(String questionId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Call the API to delete the question
      await _adminService.deleteQuestion(questionId);
      
      setState(() {
        _questions.removeWhere((question) => question.id == questionId);
        _applyFilters();
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('question_deleted_successfully')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
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
            content: Text(context.tr('failed_to_delete_question')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Question question) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete')),
        content: Text(context.tr('delete_question_confirmation')),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteQuestion(question.id);
            },
            icon: const Icon(Icons.delete, size: 18),
            label: Text(
              context.tr('delete'),
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTopicName(String? topicId) {
    if (topicId == null) {
      return context.tr('no_topic');
    }
    final topic = _topics.firstWhere(
      (topic) => topic.id == topicId,
      orElse: () => Topic(id: '', name: context.tr('unknown'), slug: '', displayOrder: 0, isActive: true),
    );
    return topic.name;
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
  
  Color _getTypeColor(String type) {
    switch (type) {
      case 'mcq':
        return AppColors.blue;
      case 'open_ended':
        return AppColors.green;
      case 'calculation':
        return AppColors.purple;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'mcq':
        return Icons.check_box;
      case 'open_ended':
        return Icons.text_fields;
      case 'calculation':
        return Icons.calculate;
      default:
        return Icons.help;
    }
  }
  
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.blue;
      case 'hard':
        return Colors.orange;
      case 'very_hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveAdminScaffold(
      title: context.tr('questions_management'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddQuestion,
        backgroundColor: AppColors.darkBlue,
        icon: Icon(
          Icons.add,
          size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 22, desktopSize: 24),
        ),
        label: Text(
          context.tr('add_question'),
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 14),
          ),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeaderCard(),
                  _buildFilters(),
                  _filteredQuestions.isEmpty
                      ? _buildEmptyState()
                      : Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                            vertical: ResponsiveUtils.getSpacing(context, base: 8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: _filteredQuestions.length,
                            itemBuilder: (context, index) {
                              final question = _filteredQuestions[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: ResponsiveUtils.getSpacing(context, base: 12),
                                ),
                                child: _buildQuestionCard(question),
                              );
                            },
                          ),
                        ),
                  // Add some bottom padding
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 100)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.darkBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.quiz_outlined,
                color: AppColors.darkBlue,
                size: ResponsiveUtils.getIconSize(context, mobileSize: 24, tabletSize: 24, desktopSize: 24),
              ),
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('questions_management'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
                  Text(
                    context.tr('questions_management_description'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                      color: AppColors.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.getSpacing(context, base: 12),
                vertical: ResponsiveUtils.getSpacing(context, base: 8),
              ),
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_filteredQuestions.length} ${context.tr('questions')}',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.darkBlue),
          ),
          SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
          Text(
            context.tr('loading_questions'),
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 16),
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: ResponsiveUtils.getScreenPadding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 44, desktopSize: 48),
                color: Colors.red,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            Text(
              context.tr('error_loading_questions'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
            CustomButton(
              onPressed: _loadData,
              text: context.tr('retry'),
              icon: Icons.refresh,
              type: ButtonType.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool hasFilters = _selectedType != null || _selectedTopic != null || _selectedDifficulty != null || _searchController.text.isNotEmpty;
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getSpacing(context, base: 32)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lightGrey.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.quiz_outlined,
                size: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 44, desktopSize: 48),
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            Text(
              context.tr('no_questions_found'),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 18),
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ResponsiveUtils.getSpacing(context, base: 24)),
              child: Text(
                hasFilters
                    ? context.tr('no_questions_match_filters')
                    : context.tr('no_questions_yet'),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 24)),
            hasFilters
                ? CustomButton(
                    onPressed: _resetFilters,
                    text: context.tr('clear_filters'),
                    icon: Icons.filter_list_off,
                    type: ButtonType.primary,
                  )
                : CustomButton(
                    onPressed: _navigateToAddQuestion,
                    text: context.tr('add_first_question'),
                    icon: Icons.add,
                    type: ButtonType.primary,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question) {
    final typeColor = _getTypeColor(question.type);
    final typeIcon = _getTypeIcon(question.type);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ExpansionTile(
        tilePadding: ResponsiveUtils.getCardPadding(context),
        childrenPadding: ResponsiveUtils.getCardPadding(context).copyWith(top: 0),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        maintainState: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        leading: Container(
          width: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 44, desktopSize: 48),
          height: ResponsiveUtils.getIconSize(context, mobileSize: 40, tabletSize: 44, desktopSize: 48),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              typeIcon, 
              color: typeColor,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 22, desktopSize: 24),
            ),
          ),
        ),
        title: Text(
          question.text,
          style: TextStyle(
            fontSize: ResponsiveUtils.getFontSize(context, base: 16),
            fontWeight: FontWeight.w600,
            color: AppColors.darkGrey,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(top: ResponsiveUtils.getSpacing(context, base: 8)),
          child: _buildQuestionBadges(question, typeColor),
        ),
        trailing: ResponsiveUtils.isMobile(context)
          ? PopupMenuButton<String>(
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.more_vert,
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
                  color: AppColors.darkGrey,
                ),
              ),
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'edit') {
                  _navigateToEditQuestion(question);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(question);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: AppColors.darkBlue, size: 18),
                      SizedBox(width: 8),
                      Text(
                        context.tr('edit'),
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text(
                        context.tr('delete'),
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: Icons.edit,
                  color: AppColors.darkBlue,
                  onTap: () => _navigateToEditQuestion(question),
                  tooltip: context.tr('edit_question'),
                ),
                SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.delete,
                  color: Colors.red,
                  onTap: () => _showDeleteConfirmation(question),
                  tooltip: context.tr('delete_question'),
                ),
              ],
            ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(height: ResponsiveUtils.getSpacing(context, base: 32)),
              if (question.type == 'mcq')
                _buildMCQDetails(question)
              else if (question.type == 'open_ended')
                _buildOpenEndedDetails(question)
              else if (question.type == 'calculation')
                _buildCalculationDetails(question),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              color: color,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuestionBadges(Question question, Color typeColor) {
    return Wrap(
      spacing: ResponsiveUtils.getSpacing(context, base: 8),
      runSpacing: ResponsiveUtils.getSpacing(context, base: 8),
      children: [
        _buildBadge(
          label: _getQuestionTypeLabel(question.type),
          color: typeColor,
          icon: _getTypeIcon(question.type),
        ),
        _buildBadge(
          label: _getTopicName(question.topicId),
          color: AppColors.darkBlue,
          icon: Icons.topic_outlined,
        ),
        _buildBadge(
          label: _getDifficultyLabel(question.difficulty),
          color: _getDifficultyColor(question.difficulty),
          icon: Icons.signal_cellular_alt_outlined,
        ),
      ],
    );
  }
  
  Widget _buildBadge({required String label, required Color color, IconData? icon}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, base: 8),
        vertical: ResponsiveUtils.getSpacing(context, base: 4),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 14, tabletSize: 14, desktopSize: 14),
              color: color,
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 4)),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 12),
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMCQDetails(Question question) {
    if (question.options == null || question.options!.isEmpty) {
      return _buildEmptyDetailCard(context.tr('no_options_available'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_box,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
              color: AppColors.blue,
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
            Text(
              context.tr('options'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, base: 16),
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
        ...question.options!.map((option) {
          return Container(
            margin: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, base: 8)),
            padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 12)),
            decoration: BoxDecoration(
              color: option.isCorrect ? Colors.green.withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: option.isCorrect ? Colors.green.withOpacity(0.3) : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  option.isCorrect ? Icons.check_circle : Icons.circle_outlined,
                  color: option.isCorrect ? Colors.green : Colors.grey,
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 12)),
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                      color: option.isCorrect ? Colors.green.shade800 : Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildOpenEndedDetails(Question question) {
    if (question.modelAnswers == null || question.modelAnswers!.isEmpty) {
      return _buildEmptyDetailCard(context.tr('no_model_answers_available'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.text_fields,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
              color: AppColors.green,
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
            Text(
              context.tr('model_answers'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, base: 16),
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
        ...question.modelAnswers!.asMap().entries.map((entry) {
          final index = entry.key;
          final answer = entry.value;
          
          return Container(
            margin: EdgeInsets.only(bottom: ResponsiveUtils.getSpacing(context, base: 8)),
            padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 12)),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('model_answer')} ${index + 1}',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 12),
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade800,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
                Text(
                  answer,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCalculationDetails(Question question) {
    final params = question.calculationParams;
    if (params == null) {
      return _buildEmptyDetailCard(context.tr('no_calculation_details'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calculate,
              size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
              color: AppColors.purple,
            ),
            SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
            Text(
              context.tr('calculation_details'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getFontSize(context, base: 16),
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
        Container(
          padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (params['formula'] != null) ...[
                _buildCalculationRow(
                  label: context.tr('formula'),
                  value: params['formula'].toString(),
                  icon: Icons.functions,
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
              ],
              if (params['variables'] != null) ...[
                Text(
                  context.tr('variables'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 15),
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGrey,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
                ..._buildVariablesDisplay(params['variables']),
                SizedBox(height: ResponsiveUtils.getSpacing(context, base: 8)),
              ],
              if (params['answer'] != null)
                _buildCalculationRow(
                  label: context.tr('correct_answer'),
                  value: params['answer'].toString(),
                  icon: Icons.check_circle_outline,
                  highlight: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVariablesDisplay(dynamic variables) {
    try {
      // Handle case where variables is a Map
      if (variables is Map<String, dynamic>) {
        return variables.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(
              left: ResponsiveUtils.getSpacing(context, base: 16),
              bottom: ResponsiveUtils.getSpacing(context, base: 8),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                Text(
                  '${entry.key}: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  ),
                ),
                Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      }
      // Handle case where variables is a List
      else if (variables is List) {
        return variables.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(
              left: ResponsiveUtils.getSpacing(context, base: 16),
              bottom: ResponsiveUtils.getSpacing(context, base: 8),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                Text(
                  'Variable ${entry.key + 1}: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  ),
                ),
                Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      }
      // Handle unexpected data types
      else {
        return [
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveUtils.getSpacing(context, base: 16),
              bottom: ResponsiveUtils.getSpacing(context, base: 8),
            ),
            child: Text(
              variables.toString(),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ];
      }
    } catch (e) {
      // Fallback for any parsing errors
      return [
        Padding(
          padding: EdgeInsets.only(
            left: ResponsiveUtils.getSpacing(context, base: 16),
            bottom: ResponsiveUtils.getSpacing(context, base: 8),
          ),
          child: Text(
            'Error displaying variables: $e',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFontSize(context, base: 14),
              color: Colors.red.shade600,
            ),
          ),
        ),
      ];
    }
  }
  
  Widget _buildCalculationRow({
    required String label,
    required String value,
    required IconData icon,
    bool highlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
          color: highlight ? Colors.green : Colors.purple,
        ),
        SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label:',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGrey,
                ),
              ),
              SizedBox(height: ResponsiveUtils.getSpacing(context, base: 4)),
              Container(
                padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 8)),
                decoration: BoxDecoration(
                  color: highlight ? Colors.green.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: highlight ? Colors.green.withOpacity(0.3) : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                    fontFamily: 'monospace',
                    color: highlight ? Colors.green.shade800 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyDetailCard(String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveUtils.getSpacing(context, base: 16)),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: ResponsiveUtils.getIconSize(context, mobileSize: 18, tabletSize: 18, desktopSize: 18),
            color: Colors.grey,
          ),
          SizedBox(width: ResponsiveUtils.getSpacing(context, base: 12)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getSpacing(context, base: 16),
        vertical: ResponsiveUtils.getSpacing(context, base: 8),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: ResponsiveUtils.getCardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: AppColors.darkBlue,
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                ),
                SizedBox(width: ResponsiveUtils.getSpacing(context, base: 8)),
                Text(
                  context.tr('filter_questions'),
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFontSize(context, base: 16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            // Search field - always full width
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.tr('search_questions'),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.darkBlue.withOpacity(0.7),
                  size: ResponsiveUtils.getIconSize(context, mobileSize: 20, tabletSize: 20, desktopSize: 20),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.darkBlue),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                  vertical: ResponsiveUtils.getSpacing(context, base: 12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: TextStyle(
                fontSize: ResponsiveUtils.getFontSize(context, base: 14),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            // Dropdown filters in responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = ResponsiveUtils.isMobile(context);
                final bool isNarrowTablet = !isMobile && constraints.maxWidth < 700;
                
                if (isMobile || isNarrowTablet) {
                  // Mobile or narrow tablet: Stacked layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTypeDropdown(),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                      _buildTopicDropdown(),
                      SizedBox(height: ResponsiveUtils.getSpacing(context, base: 12)),
                      _buildDifficultyDropdown(),
                    ],
                  );
                } else {
                  // Desktop or wide tablet: Row layout
                  return Row(
                    children: [
                      Expanded(child: _buildTypeDropdown()),
                      SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                      Expanded(child: _buildTopicDropdown()),
                      SizedBox(width: ResponsiveUtils.getSpacing(context, base: 16)),
                      Expanded(child: _buildDifficultyDropdown()),
                    ],
                  );
                }
              },
            ),
            SizedBox(height: ResponsiveUtils.getSpacing(context, base: 16)),
            // Button row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: Icon(
                    Icons.clear,
                    size: ResponsiveUtils.getIconSize(context, mobileSize: 16, tabletSize: 16, desktopSize: 16),
                  ),
                  label: Text(
                    context.tr('clear_filters'),
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getFontSize(context, base: 14),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.darkBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getSpacing(context, base: 16),
                      vertical: ResponsiveUtils.getSpacing(context, base: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedType,
      decoration: InputDecoration(
        labelText: context.tr('question_type'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.darkBlue),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getSpacing(context, base: 16),
          vertical: ResponsiveUtils.getSpacing(context, base: 12),
        ),
      ),
      style: TextStyle(
        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
      ),
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: AppColors.darkBlue),
      isExpanded: true,
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(context.tr('all_types')),
        ),
        ..._questionTypes.map((type) {
          final color = _getTypeColor(type);
          final icon = _getTypeIcon(type);
          
          return DropdownMenuItem<String?>(
            value: type,
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                SizedBox(width: 8),
                Text(_getQuestionTypeLabel(type)),
              ],
            ),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _selectedType = value;
          _applyFilters();
        });
      },
    );
  }
  
  Widget _buildTopicDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedTopic,
      decoration: InputDecoration(
        labelText: context.tr('topic'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.darkBlue),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getSpacing(context, base: 16),
          vertical: ResponsiveUtils.getSpacing(context, base: 12),
        ),
      ),
      style: TextStyle(
        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
      ),
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: AppColors.darkBlue),
      isExpanded: true,
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(context.tr('all_topics')),
        ),
        ..._topics.map((topic) {
          return DropdownMenuItem<String?>(
            value: topic.id,
            child: Text(
              topic.name,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _selectedTopic = value;
          _applyFilters();
        });
      },
    );
  }
  
  Widget _buildDifficultyDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedDifficulty,
      decoration: InputDecoration(
        labelText: context.tr('difficulty'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.darkBlue),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getSpacing(context, base: 16),
          vertical: ResponsiveUtils.getSpacing(context, base: 12),
        ),
      ),
      style: TextStyle(
        fontSize: ResponsiveUtils.getFontSize(context, base: 14),
      ),
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: AppColors.darkBlue),
      isExpanded: true,
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(context.tr('all_difficulties')),
        ),
        ..._difficulties.map((difficulty) {
          final color = _getDifficultyColor(difficulty);
          
          return DropdownMenuItem<String?>(
            value: difficulty,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(_getDifficultyLabel(difficulty)),
              ],
            ),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _selectedDifficulty = value;
          _applyFilters();
        });
      },
    );
  }
} 