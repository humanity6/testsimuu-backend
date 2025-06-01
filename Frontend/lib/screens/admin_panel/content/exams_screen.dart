import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../providers/app_providers.dart';
import '../../../services/admin_service.dart';
import '../../../utils/api_config.dart';
import '../../../utils/responsive_utils.dart';
import 'exam_form_screen.dart';
import 'exam_questions_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({Key? key}) : super(key: key);

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  late AdminService _adminService;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _exams = [];
  Map<String, dynamic> _metrics = {};
  
  // Filters and search
  final TextEditingController _searchController = TextEditingController();
  String? _selectedParentExam;
  bool? _selectedActiveStatus;
  List<Map<String, dynamic>> _parentExams = [];
  bool _isFilterExpanded = false;

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

      // Load metrics and exams in parallel
      final futures = await Future.wait([
        _adminService.getExamMetrics(),
        _adminService.getAdminExams(
          search: _searchController.text.isNotEmpty ? _searchController.text : null,
          parentExamId: _selectedParentExam,
          isActive: _selectedActiveStatus,
          pageSize: 1000, // Load all exams at once with a large page size
        ),
        _adminService.getAdminExams(), // Get all exams for parent selection
      ]);

      final metrics = futures[0] as Map<String, dynamic>;
      final examsResponse = futures[1] as List<Map<String, dynamic>>;
      final allExams = futures[2] as List<Map<String, dynamic>>;

      setState(() {
        _metrics = metrics;
        _exams = examsResponse;
        _parentExams = allExams.where((exam) => exam['parent_exam'] == null).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteExam(String examId, String examName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('confirm_delete')),
        content: Text(context.tr('delete_exam_confirmation', params: {'examName': examName})),
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
        await _adminService.deleteExam(examId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('exam_deleted_successfully')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('failed_to_delete_exam', params: {'error': e.toString()})),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    _loadData();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedParentExam = null;
      _selectedActiveStatus = null;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          context.tr('exam_management'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.darkBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: ModalRoute.of(context)?.canPop == true 
          ? IconButton(
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
            )
          : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: context.tr('refresh'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : _buildMainContent(),
      ),
      floatingActionButton: _error == null ? _buildFloatingActionButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      resizeToAvoidBottomInset: true,
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
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMetricsSection(),
          _buildCompactFiltersSection(),
          _buildExamsList(),
          // Add bottom padding to ensure FAB doesn't cover content
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ExamFormScreen(),
          ),
        );
        if (result == true) {
          _loadData();
        }
      },
      backgroundColor: AppColors.darkBlue,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
      tooltip: context.tr('add_exam'),
    );
  }

  Widget _buildMetricsSection() {
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
          _buildMetricCard(
            title: context.tr('total_exams'),
            value: _metrics['total_exams']?.toString() ?? '0',
            icon: Icons.quiz,
            color: AppColors.darkBlue,
          ),
          _buildMetricCard(
            title: context.tr('active_exams'),
            value: _metrics['active_exams']?.toString() ?? '0',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
          _buildMetricCard(
            title: context.tr('exams_with_questions'),
            value: _metrics['exams_with_questions']?.toString() ?? '0',
            icon: Icons.question_answer,
            color: Colors.orange,
          ),
          _buildMetricCard(
            title: context.tr('avg_questions_per_exam'),
            value: _metrics['avg_questions_per_exam']?.toString() ?? '0',
            icon: Icons.analytics,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
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

  Widget _buildCompactFiltersSection() {
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
                        hintText: context.tr('Search Exams'),
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
                      _buildParentExamDropdown(),
                      const SizedBox(height: 12),
                      _buildStatusDropdown(),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(child: _buildParentExamDropdown()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatusDropdown()),
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

  Widget _buildParentExamDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedParentExam,
      decoration: InputDecoration(
        labelText: context.tr('parent_exam'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(context.tr('all_parent_exams')),
        ),
        ..._parentExams.map((exam) => DropdownMenuItem<String>(
          value: exam['id'].toString(),
          child: Text(
            exam['name'] ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedParentExam = value;
        });
      },
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<bool>(
      value: _selectedActiveStatus,
      decoration: InputDecoration(
        labelText: context.tr('status'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      isExpanded: true,
      items: [
        DropdownMenuItem<bool>(
          value: null,
          child: Text(context.tr('all_statuses')),
        ),
        DropdownMenuItem<bool>(
          value: true,
          child: Text(context.tr('active')),
        ),
        DropdownMenuItem<bool>(
          value: false,
          child: Text(context.tr('inactive')),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedActiveStatus = value;
        });
      },
    );
  }

  Widget _buildExamsList() {
    if (_exams.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: context.isMobile 
          ? _buildMobileExamsList() 
          : _buildDesktopExamsTable(),
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
            context.tr('no_exams_found'),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('try_adjusting_filters'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileExamsList() {
    return ListView.builder(
      itemCount: _exams.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final exam = _exams[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildExamCard(exam),
        );
      },
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
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
                Expanded(
                  child: Text(
                    exam['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(exam['is_active']),
              ],
            ),
            if (exam['description'] != null && exam['description'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                exam['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            _buildExamInfoRow(exam),
            const SizedBox(height: 12),
            _buildActionButtonsRow(exam),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool? isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive == true ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive == true ? context.tr('active') : context.tr('inactive'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildExamInfoRow(Map<String, dynamic> exam) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoItem(
            icon: Icons.account_tree,
            label: context.tr('parent'),
            value: exam['parent_exam_name'] ?? context.tr('none'),
          ),
        ),
        Expanded(
          child: _buildInfoItem(
            icon: Icons.quiz,
            label: context.tr('questions'),
            value: exam['questions_count']?.toString() ?? '0',
          ),
        ),
        Expanded(
          child: _buildInfoItem(
            icon: Icons.sort,
            label: context.tr('order'),
            value: exam['display_order']?.toString() ?? '0',
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

  Widget _buildActionButtonsRow(Map<String, dynamic> exam) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ExamFormScreen(examId: exam['id'].toString()),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
            icon: const Icon(Icons.edit, size: 16),
            label: Text(context.tr('edit')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ExamQuestionsScreen(
                    examId: exam['id'].toString(),
                    examName: exam['name'] ?? '',
                  ),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
            icon: const Icon(Icons.quiz, size: 16),
            label: Text(context.tr('questions')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _deleteExam(exam['id'].toString(), exam['name'] ?? ''),
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: context.tr('delete'),
        ),
      ],
    );
  }

  Widget _buildDesktopExamsTable() {
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
                  context.tr('Exams List'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_exams.length} ${context.tr('exams')}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                DataColumn(label: Text(context.tr('name'))),
                DataColumn(label: Text(context.tr('description'))),
                DataColumn(label: Text(context.tr('parent_exam'))),
                DataColumn(label: Text(context.tr('status'))),
                DataColumn(label: Text(context.tr('questions'))),
                DataColumn(label: Text(context.tr('sub_exams'))),
                DataColumn(label: Text(context.tr('order'))),
                DataColumn(label: Text(context.tr('actions'))),
              ],
              rows: _exams.map((exam) => DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 150,
                      child: Text(
                        exam['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 200,
                      child: Text(
                        exam['description'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(exam['parent_exam_name'] ?? context.tr('none')),
                  ),
                  DataCell(_buildStatusChip(exam['is_active'])),
                  DataCell(
                    Text(exam['questions_count']?.toString() ?? '0'),
                  ),
                  DataCell(
                    Text(exam['sub_exams_count']?.toString() ?? '0'),
                  ),
                  DataCell(
                    Text(exam['display_order']?.toString() ?? '0'),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ExamFormScreen(examId: exam['id'].toString()),
                              ),
                            );
                            if (result == true) {
                              _loadData();
                            }
                          },
                          tooltip: context.tr('edit'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.quiz, size: 18, color: Colors.blue),
                          onPressed: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ExamQuestionsScreen(
                                  examId: exam['id'].toString(),
                                  examName: exam['name'] ?? '',
                                ),
                              ),
                            );
                            if (result == true) {
                              _loadData();
                            }
                          },
                          tooltip: context.tr('manage_questions'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                          onPressed: () => _deleteExam(
                            exam['id'].toString(),
                            exam['name'] ?? '',
                          ),
                          tooltip: context.tr('delete'),
                        ),
                      ],
                    ),
                  ),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
} 