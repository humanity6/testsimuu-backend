import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/language_selector.dart';
import 'exam_details_screen.dart';
import 'learning_material_screen.dart';

class ExamModeSelectionScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const ExamModeSelectionScreen({
    Key? key,
    required this.examId,
    required this.examTitle,
  }) : super(key: key);

  @override
  State<ExamModeSelectionScreen> createState() => _ExamModeSelectionScreenState();
}

class _ExamModeSelectionScreenState extends State<ExamModeSelectionScreen> {
  String? _selectedMode;
  String? _selectedExamType;
  List<Map<String, dynamic>> _availableTopics = [];
  List<String> _selectedTopicIds = [];
  bool _isLoadingTopics = false;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoadingTopics = true;
    });

    try {
      // Load topics for topic-based exam selection
      final topics = await context.examService.getExamTopics(widget.examId);
      setState(() {
        _availableTopics = topics.map((topic) => {
          'id': topic.id,
          'title': topic.title,
          'description': topic.description,
        }).toList();
      });
    } catch (e) {
      print('Error loading topics: $e');
    } finally {
      setState(() {
        _isLoadingTopics = false;
      });
    }
  }

  void _onModeSelected(String mode) {
    setState(() {
      _selectedMode = mode;
      // Reset exam type when mode changes
      _selectedExamType = null;
      _selectedTopicIds.clear();
    });
  }

  void _onExamTypeSelected(String examType) {
    setState(() {
      _selectedExamType = examType;
      if (examType == 'FULL') {
        _selectedTopicIds.clear();
      }
    });
  }

  void _onTopicToggled(String topicId) {
    setState(() {
      if (_selectedTopicIds.contains(topicId)) {
        _selectedTopicIds.remove(topicId);
      } else {
        _selectedTopicIds.add(topicId);
      }
    });
  }

  void _startExam() async {
    if (_selectedMode == null || _selectedExamType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('please_select_mode_and_type')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedExamType == 'TOPIC_BASED' && _selectedTopicIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('please_select_at_least_one_topic')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Create exam session
      final sessionData = {
        'exam_id': int.parse(widget.examId),
        'session_type': _selectedMode,
        'exam_type': _selectedExamType,
        'title': '${widget.examTitle} - ${_selectedMode == 'PRACTICE' ? 'Practice' : 'Real Exam'} Mode',
        'num_questions': 20, // Default number of questions
        'time_limit_seconds': _selectedMode == 'PRACTICE' ? 86400 : 3600, // 24 hours for practice, 1 hour for real exam
      };

      if (_selectedExamType == 'TOPIC_BASED' && _selectedTopicIds.isNotEmpty) {
        sessionData['topic_ids'] = _selectedTopicIds.map((id) => int.parse(id)).toList();
      }

      final session = await context.examService.createExamSession(sessionData);

      if (session != null) {
        // Navigate based on mode
        if (_selectedMode == 'PRACTICE') {
          // Show learning materials first for practice mode
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LearningMaterialScreen(
                examId: widget.examId,
                sessionId: session['id'].toString(),
                examTitle: widget.examTitle,
              ),
            ),
          );
        } else {
          // Go directly to exam for real exam mode
          Navigator.pushNamed(
            context,
            '/exams/${widget.examId}/session/${session['id']}',
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_to_start_exam', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          context.tr('select_exam_mode'),
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [
          LanguageSelector(isCompact: true),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildModeSelection(),
            if (_selectedMode != null) ...[
              const SizedBox(height: 32),
              _buildExamTypeSelection(),
            ],
            if (_selectedExamType == 'TOPIC_BASED') ...[
              const SizedBox(height: 32),
              _buildTopicSelection(),
            ],
            if (_selectedMode != null && _selectedExamType != null) ...[
              const SizedBox(height: 40),
              _buildStartButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.examTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('choose_how_you_want_to_study'),
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.darkGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('study_mode'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        _buildModeCard(
          mode: 'PRACTICE',
          title: context.tr('practice_mode'),
          subtitle: context.tr('practice_mode_description'),
          icon: Icons.school,
          features: [
            context.tr('untimed_practice'),
            context.tr('learning_materials_included'),
            context.tr('immediate_feedback'),
            context.tr('ai_explanations'),
          ],
        ),
        const SizedBox(height: 16),
        _buildModeCard(
          mode: 'REAL_EXAM',
          title: context.tr('real_exam_mode'),
          subtitle: context.tr('real_exam_mode_description'),
          icon: Icons.timer,
          features: [
            context.tr('timed_exam'),
            context.tr('exam_environment'),
            context.tr('final_evaluation'),
            context.tr('comprehensive_report'),
          ],
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> features,
  }) {
    final isSelected = _selectedMode == mode;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.darkBlue : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onModeSelected(mode),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.darkBlue : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : AppColors.darkGrey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.darkBlue : AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.darkGrey.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.darkBlue,
                      size: 24,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check,
                      size: 16,
                      color: isSelected ? AppColors.darkBlue : AppColors.darkGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? AppColors.darkBlue : AppColors.darkGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('exam_type'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildExamTypeCard(
                type: 'FULL',
                title: context.tr('full_exam'),
                subtitle: context.tr('full_exam_description'),
                icon: Icons.quiz,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildExamTypeCard(
                type: 'TOPIC_BASED',
                title: context.tr('topic_based'),
                subtitle: context.tr('topic_based_description'),
                icon: Icons.category,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExamTypeCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedExamType == type;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.darkBlue : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onExamTypeSelected(type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.darkBlue : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppColors.darkGrey,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.darkBlue : AppColors.darkGrey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.darkGrey.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.check_circle,
                    color: AppColors.darkBlue,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('select_topics'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('choose_topics_to_focus_on'),
          style: TextStyle(
            fontSize: 14,
            color: AppColors.darkGrey.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingTopics)
          const Center(child: CircularProgressIndicator())
        else if (_availableTopics.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr('no_topics_available'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.darkGrey),
              ),
            ),
          )
        else
          Column(
            children: _availableTopics.map((topic) {
              final isSelected = _selectedTopicIds.contains(topic['id']);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppColors.darkBlue : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (_) => _onTopicToggled(topic['id']),
                  title: Text(
                    topic['title'],
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.darkBlue : AppColors.darkGrey,
                    ),
                  ),
                  subtitle: topic['description']?.isNotEmpty == true
                      ? Text(
                          topic['description'],
                          style: TextStyle(
                            color: AppColors.darkGrey.withOpacity(0.7),
                          ),
                        )
                      : null,
                  activeColor: AppColors.darkBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildStartButton() {
    final canStart = _selectedMode != null && 
                    _selectedExamType != null && 
                    (_selectedExamType != 'TOPIC_BASED' || _selectedTopicIds.isNotEmpty);
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canStart ? _startExam : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canStart ? 4 : 0,
        ),
        child: Text(
          context.tr('start_exam'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 