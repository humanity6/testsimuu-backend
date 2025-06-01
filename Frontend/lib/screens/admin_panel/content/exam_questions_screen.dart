import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../models/question.dart';
import '../../../models/topic.dart';
import '../../../services/admin_service.dart';
import '../../../utils/api_config.dart';
import '../../../utils/responsive_utils.dart';
import 'question_form_screen.dart';

class ExamQuestionsScreen extends StatefulWidget {
  final String examId;
  final String examName;

  const ExamQuestionsScreen({
    Key? key,
    required this.examId,
    required this.examName,
  }) : super(key: key);

  @override
  State<ExamQuestionsScreen> createState() => _ExamQuestionsScreenState();
}

class _ExamQuestionsScreenState extends State<ExamQuestionsScreen> {
  late AdminService _adminService;
  bool _isLoading = true;
  String? _error;
  List<Question> _questions = [];
  List<Topic> _topics = [];
  
  // Filters and search
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTopic;
  String? _selectedType;
  String? _selectedDifficulty;
  bool _isFilterExpanded = false;
  
  // Filter options
  final List<String> _questionTypes = ['mcq', 'open_ended', 'calculation'];
  final List<String> _difficulties = ['easy', 'medium', 'hard', 'very_hard'];
  
  // Pagination
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeService() {
    try {
      final authService = context.authService;
      final accessToken = authService.accessToken;
      
      if (accessToken != null) {
        _adminService = AdminService(accessToken: accessToken);
        _loadData();
      } else {
        setState(() {
          _error = 'Authentication required';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check API availability
      final isApiAvailable = await ApiConfig.checkApiAvailability();
      if (!isApiAvailable) {
        setState(() {
          _error = context.tr('api_unavailable');
          _isLoading = false;
        });
        return;
      }

      // Load questions for this specific exam and topics
      final futures = await Future.wait([
        _adminService.getQuestions(
          examId: widget.examId,
          topicId: _selectedTopic,
          questionType: _selectedType,
          difficulty: _selectedDifficulty,
          page: _currentPage,
          pageSize: _pageSize,
        ),
        _adminService.getTopics(),
      ]);

      final questions = futures[0] as List<Question>;
      final topics = futures[1] as List<Topic>;

      setState(() {
        _questions = questions;
        _topics = topics;
        _hasNextPage = questions.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  void _deleteQuestion(String questionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete')),
        content: Text(context.tr('delete_question_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.deleteQuestion(questionId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('question_deleted_successfully')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('failed_to_delete_question')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _currentPage = 1;
    });
    _loadData();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedTopic = null;
      _selectedType = null;
      _selectedDifficulty = null;
      _currentPage = 1;
    });
    _loadData();
  }

  String _getTopicName(String? topicId) {
    if (topicId == null) return context.tr('no_topic');
    final topic = _topics.firstWhere(
      (t) => t.id == topicId,
      orElse: () => Topic(
        id: '', 
        name: context.tr('unknown'), 
        slug: '',
        isActive: true,
        displayOrder: 0,
      ),
    );
    return topic.name;
  }

  String _formatQuestionType(String type) {
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

  String _formatDifficulty(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return context.tr('easy');
      case 'medium':
        return context.tr('medium');
      case 'hard':
        return context.tr('hard');
      case 'very_hard':
        return context.tr('very_hard');
      default:
        return difficulty;
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      case 'very_hard':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.darkBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: context.tr('back'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('manage_questions'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.examName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: context.tr('refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading questions...'),
                ],
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _buildMainContent(),
      floatingActionButton: _error == null ? _buildFloatingActionButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('error_occurred'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(context.tr('go_back')),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.tr('retry')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          _buildStatsSection(),
          _buildFiltersSection(),
          Expanded(child: _buildQuestionsSection()),
          if (_questions.length >= _pageSize) _buildPaginationSection(),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuestionFormScreen(
              preSelectedExamId: widget.examId,
            ),
          ),
        );
        if (result == true) {
          _loadData();
        }
      },
      backgroundColor: AppColors.darkBlue,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: Text(context.tr('add_question')),
      elevation: 4,
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: context.isMobile ? 2 : 4,
        childAspectRatio: context.isMobile ? 1.5 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _buildStatCard(
            title: context.tr('total_questions'),
            value: _questions.length.toString(),
            icon: Icons.quiz,
            color: AppColors.darkBlue,
          ),
          _buildStatCard(
            title: context.tr('mcq'),
            value: _questions.where((q) => q.type == 'mcq').length.toString(),
            icon: Icons.radio_button_checked,
            color: Colors.green,
          ),
          _buildStatCard(
            title: context.tr('open_ended'),
            value: _questions.where((q) => q.type == 'open_ended').length.toString(),
            icon: Icons.edit,
            color: Colors.orange,
          ),
          _buildStatCard(
            title: context.tr('calculation'),
            value: _questions.where((q) => q.type == 'calculation').length.toString(),
            icon: Icons.calculate,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: context.isMobile ? 18 : 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Always visible search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: context.tr('search_questions_placeholder'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilters();
                                },
                              ),
                            IconButton(
                              icon: Icon(
                                _isFilterExpanded ? Icons.expand_less : Icons.expand_more,
                                color: AppColors.darkBlue,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isFilterExpanded = !_isFilterExpanded;
                                });
                              },
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _applyFilters(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(context.tr('search')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Expandable advanced filters
            if (_isFilterExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (context.isMobile) ...[
                      _buildTopicDropdown(),
                      const SizedBox(height: 12),
                      _buildTypeDropdown(),
                      const SizedBox(height: 12),
                      _buildDifficultyDropdown(),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: _buildTopicDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTypeDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDifficultyDropdown()),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.clear),
                            label: Text(context.tr('clear_filters')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _applyFilters,
                            icon: const Icon(Icons.filter_list),
                            label: Text(context.tr('apply_filters')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.darkBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopicDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedTopic,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.tr('topic'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(context.tr('all_topics')),
        ),
        ..._topics.map((topic) => DropdownMenuItem<String>(
          value: topic.id,
          child: Text(
            topic.name,
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedTopic = value;
        });
      },
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedType,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.tr('type'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(context.tr('all_types')),
        ),
        ..._questionTypes.map((type) => DropdownMenuItem<String>(
          value: type,
          child: Text(context.tr(type)),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedType = value;
        });
      },
    );
  }

  Widget _buildDifficultyDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDifficulty,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.tr('difficulty'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(context.tr('all_difficulties')),
        ),
        ..._difficulties.map((difficulty) => DropdownMenuItem<String>(
          value: difficulty,
          child: Text(context.tr(difficulty)),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedDifficulty = value;
        });
      },
    );
  }

  Widget _buildQuestionsSection() {
    if (_questions.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: context.isMobile 
          ? _buildMobileQuestionsList() 
          : _buildDesktopQuestionsTable(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('no_questions_found'),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('try_adding_questions'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileQuestionsList() {
    return ListView.separated(
      itemCount: _questions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final question = _questions[index];
        return _buildQuestionCard(question);
      },
    );
  }

  Widget _buildQuestionCard(Question question) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTypeChip(question.type),
                const SizedBox(width: 8),
                _buildDifficultyChip(question.difficulty),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (action) => _handleQuestionAction(action, question),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 16),
                          const SizedBox(width: 8),
                          Text(context.tr('edit')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(context.tr('delete'), style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _buildQuestionInfoRow(question),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final colors = {
      'mcq': Colors.green,
      'open_ended': Colors.orange,
      'calculation': Colors.purple,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors[type] ?? Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.tr(type),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    final colors = {
      'easy': Colors.green,
      'medium': Colors.orange,
      'hard': Colors.red,
      'very_hard': Colors.red[800],
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors[difficulty] ?? Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.tr(difficulty),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildQuestionInfoRow(Question question) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoItem(
            icon: Icons.category,
            label: context.tr('topic'),
            value: _getTopicName(question.topicId),
          ),
        ),
        Expanded(
          child: _buildInfoItem(
            icon: Icons.score,
            label: context.tr('points'),
            value: '1', // Default points value since Question model doesn't have points
          ),
        ),
        if (question.type == 'mcq')
          Expanded(
            child: _buildInfoItem(
              icon: Icons.list,
              label: context.tr('options'),
              value: question.options?.length.toString() ?? '0',
            ),
          ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDesktopQuestionsTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.quiz, color: AppColors.darkBlue),
                const SizedBox(width: 8),
                Text(
                  context.tr('questions_list'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_questions.length} ${context.tr('questions')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: SingleChildScrollView(
                  child: DataTable(
                  columns: [
                    DataColumn(label: Text(context.tr('question'))),
                    DataColumn(label: Text(context.tr('type'))),
                    DataColumn(label: Text(context.tr('difficulty'))),
                    DataColumn(label: Text(context.tr('topic'))),
                    DataColumn(label: Text(context.tr('points'))),
                    DataColumn(label: Text(context.tr('actions'))),
                  ],
                  rows: _questions.map((question) => DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            question.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(_buildTypeChip(question.type)),
                      DataCell(_buildDifficultyChip(question.difficulty)),
                      DataCell(
                        Text(_getTopicName(question.topicId)),
                      ),
                      DataCell(
                        Text('1'), // Default points value
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _handleQuestionAction('edit', question),
                              tooltip: context.tr('edit'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _handleQuestionAction('delete', question),
                              tooltip: context.tr('delete'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleQuestionAction(String action, Question question) {
    switch (action) {
      case 'edit':
        _editQuestion(question);
        break;
      case 'delete':
        _deleteQuestion(question.id);
        break;
    }
  }

  void _editQuestion(Question question) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuestionFormScreen(
          question: question,
          preSelectedExamId: widget.examId,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Widget _buildPaginationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_questions.length} ${context.tr('questions_shown')}',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _questions.length >= _pageSize ? _loadMore : null,
            icon: const Icon(Icons.expand_more),
            label: Text(context.tr('load_more')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _loadMore() {
    setState(() {
      _currentPage++;
    });
    _loadData();
  }
} 