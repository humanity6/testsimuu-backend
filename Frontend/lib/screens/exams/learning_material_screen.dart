import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/language_selector.dart';
import 'practice_screen.dart';

class LearningMaterialScreen extends StatefulWidget {
  final String examId;
  final String sessionId;
  final String examTitle;

  const LearningMaterialScreen({
    Key? key,
    required this.examId,
    required this.sessionId,
    required this.examTitle,
  }) : super(key: key);

  @override
  State<LearningMaterialScreen> createState() => _LearningMaterialScreenState();
}

class _LearningMaterialScreenState extends State<LearningMaterialScreen> {
  List<Map<String, dynamic>> _learningMaterials = [];
  bool _isLoading = true;
  String? _error;
  int _currentMaterialIndex = 0;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadLearningMaterials();
  }

  Future<void> _loadLearningMaterials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load learning materials for the session
      final materials = await context.examService.getLearningMaterials(widget.sessionId);
      setState(() {
        _learningMaterials = materials;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextMaterial() {
    if (_currentMaterialIndex < _learningMaterials.length - 1) {
      setState(() {
        _currentMaterialIndex++;
      });
    } else {
      setState(() {
        _isCompleted = true;
      });
    }
  }

  void _previousMaterial() {
    if (_currentMaterialIndex > 0) {
      setState(() {
        _currentMaterialIndex--;
      });
    }
  }

  void _startPractice() async {
    try {
      // Mark learning materials as viewed
      await context.examService.markLearningMaterialViewed(widget.sessionId);
      
      // Navigate to practice session
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PracticeScreen(
            examId: widget.examId,
            sessionId: widget.sessionId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('failed_to_start_practice', params: {'error': e.toString()})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _skipToExam() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(context.tr('skip_learning_materials')),
          content: Text(context.tr('skip_learning_materials_warning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _startPractice();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkBlue,
              ),
              child: Text(context.tr('skip_and_start')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          context.tr('learning_materials'),
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_learningMaterials.isNotEmpty && !_isCompleted)
            TextButton(
              onPressed: _skipToExam,
              child: Text(
                context.tr('skip'),
                style: const TextStyle(color: AppColors.darkBlue),
              ),
            ),
          const LanguageSelector(isCompact: true),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              context.tr('error_loading_materials'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLearningMaterials,
              child: Text(context.tr('retry')),
            ),
          ],
        ),
      );
    }

    if (_learningMaterials.isEmpty) {
      return _buildNoMaterialsView();
    }

    if (_isCompleted) {
      return _buildCompletionView();
    }

    return _buildMaterialView();
  }

  Widget _buildNoMaterialsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_books, size: 64, color: AppColors.darkBlue),
            const SizedBox(height: 16),
            Text(
              context.tr('no_learning_materials'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('no_learning_materials_description'),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startPractice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  context.tr('start_practice'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              context.tr('materials_completed'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('materials_completed_description'),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.darkGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startPractice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  context.tr('start_practice'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentMaterialIndex = 0;
                  _isCompleted = false;
                });
              },
              child: Text(
                context.tr('review_materials'),
                style: const TextStyle(color: AppColors.darkBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialView() {
    final material = _learningMaterials[_currentMaterialIndex];
    
    return Column(
      children: [
        // Progress indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.limeYellow,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    widget.examTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentMaterialIndex + 1} ${context.tr('of')} ${_learningMaterials.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.darkGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_currentMaterialIndex + 1) / _learningMaterials.length,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.darkBlue),
              ),
            ],
          ),
        ),
        
        // Material content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Material header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.darkBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getMaterialIcon(material['material_type']),
                        color: AppColors.darkBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material['title'] ?? context.tr('untitled_material'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkBlue,
                            ),
                          ),
                          if (material['duration_minutes'] != null)
                            Text(
                              context.tr('estimated_time', params: {
                                'minutes': material['duration_minutes'].toString()
                              }),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.darkGrey.withOpacity(0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Material description
                if (material['description']?.isNotEmpty == true) ...[
                  Text(
                    material['description'],
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.darkGrey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Material content
                _buildMaterialContent(material),
              ],
            ),
          ),
        ),
        
        // Navigation buttons
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_currentMaterialIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousMaterial,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkBlue,
                      side: const BorderSide(color: AppColors.darkBlue),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(context.tr('previous')),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              
              const SizedBox(width: 16),
              
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextMaterial,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentMaterialIndex < _learningMaterials.length - 1
                        ? context.tr('next')
                        : context.tr('complete'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialContent(Map<String, dynamic> material) {
    final materialType = material['material_type'] ?? 'TEXT';
    
    switch (materialType) {
      case 'TEXT':
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              material['content'] ?? context.tr('no_content_available'),
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: AppColors.darkGrey,
              ),
            ),
          ),
        );
        
      case 'VIDEO':
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.play_circle_outline, size: 64, color: AppColors.darkBlue),
                const SizedBox(height: 16),
                Text(
                  context.tr('video_content'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 8),
                if (material['file_url']?.isNotEmpty == true)
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Open video player or external URL
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('video_player_coming_soon')),
                        ),
                      );
                    },
                    child: Text(context.tr('watch_video')),
                  ),
                if (material['content']?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Text(
                    material['content'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.darkGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
        
      case 'PDF':
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.picture_as_pdf, size: 64, color: AppColors.darkBlue),
                const SizedBox(height: 16),
                Text(
                  context.tr('pdf_document'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 8),
                if (material['file_url']?.isNotEmpty == true)
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Open PDF viewer or external URL
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('pdf_viewer_coming_soon')),
                        ),
                      );
                    },
                    child: Text(context.tr('open_pdf')),
                  ),
                if (material['content']?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Text(
                    material['content'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.darkGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
        
      case 'LINK':
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.link, size: 64, color: AppColors.darkBlue),
                const SizedBox(height: 16),
                Text(
                  context.tr('external_resource'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue,
                  ),
                ),
                const SizedBox(height: 8),
                if (material['file_url']?.isNotEmpty == true)
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Open external URL
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr('external_links_coming_soon')),
                        ),
                      );
                    },
                    child: Text(context.tr('open_link')),
                  ),
                if (material['content']?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Text(
                    material['content'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.darkGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
        
      default:
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              material['content'] ?? context.tr('no_content_available'),
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: AppColors.darkGrey,
              ),
            ),
          ),
        );
    }
  }

  IconData _getMaterialIcon(String? materialType) {
    switch (materialType) {
      case 'VIDEO':
        return Icons.play_circle_outline;
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'LINK':
        return Icons.link;
      case 'INTERACTIVE':
        return Icons.touch_app;
      default:
        return Icons.article;
    }
  }
}