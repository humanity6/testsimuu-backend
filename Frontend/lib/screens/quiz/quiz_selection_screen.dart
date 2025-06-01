import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/quiz.dart';
import '../../theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/quiz_card.dart';
import '../../utils/api_config.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'quiz_screen.dart';

class QuizSelectionScreen extends StatefulWidget {
  final String category;

  const QuizSelectionScreen({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  State<QuizSelectionScreen> createState() => _QuizSelectionScreenState();
}

class _QuizSelectionScreenState extends State<QuizSelectionScreen> {
  List<Quiz> _quizzes = [];
  String _selectedDifficulty = 'Alle';
  String _selectedDuration = 'Alle';
  String _selectedSort = 'Neueste';
  final List<String> _difficulties = ['Alle', 'Einfach', 'Mittel', 'Schwer'];
  final List<String> _durations = ['Alle', 'Kurz (≤15min)', 'Mittel (15-30min)', 'Lang (>30min)'];
  final List<String> _sortOptions = ['Neueste', 'Beliebteste', 'Schwierigkeit (aufsteigend)', 'Schwierigkeit (absteigend)'];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        setState(() {
          _errorMessage = 'Not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Build the URL with category filter if specified
      String url = '${ApiConfig.baseUrl}/api/quizzes/';
      if (widget.category.isNotEmpty && widget.category.toLowerCase() != 'alle') {
        url += '?category=${Uri.encodeComponent(widget.category)}';
      }

      // Add difficulty filter if selected
      if (_selectedDifficulty != 'Alle') {
        String difficultyParam = _selectedDifficulty.toUpperCase();
        url += url.contains('?') ? '&difficulty=$difficultyParam' : '?difficulty=$difficultyParam';
      }
      
      // Add duration filter (assuming backend supports this parameter)
      if (_selectedDuration != 'Alle') {
        String durationParam;
        switch (_selectedDuration) {
          case 'Kurz (≤15min)':
            durationParam = 'SHORT';
            break;
          case 'Mittel (15-30min)':
            durationParam = 'MEDIUM';
            break;
          case 'Lang (>30min)':
            durationParam = 'LONG';
            break;
          default:
            durationParam = '';
        }
        
        if (durationParam.isNotEmpty) {
          url += url.contains('?') ? '&duration=$durationParam' : '?duration=$durationParam';
        }
      }
      
      // Add sorting parameter (assuming backend supports this)
      String sortParam;
      switch (_selectedSort) {
        case 'Neueste':
          sortParam = 'newest';
          break;
        case 'Beliebteste':
          sortParam = 'popular';
          break;
        case 'Schwierigkeit (aufsteigend)':
          sortParam = 'difficulty_asc';
          break;
        case 'Schwierigkeit (absteigend)':
          sortParam = 'difficulty_desc';
          break;
        default:
          sortParam = 'newest';
      }
      
      url += url.contains('?') ? '&sort=$sortParam' : '?sort=$sortParam';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Quiz> fetchedQuizzes = [];

        // Handle different response formats
        if (data is List) {
          fetchedQuizzes = data.map((json) => Quiz.fromJson(json)).toList();
        } else if (data is Map && data.containsKey('results')) {
          fetchedQuizzes = (data['results'] as List).map((json) => Quiz.fromJson(json)).toList();
        }

        setState(() {
          _quizzes = fetchedQuizzes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load quizzes: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading quizzes: $e';
        _isLoading = false;
      });
    }
  }

  void _onDifficultyChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedDifficulty = value;
      });
    }
  }
  
  void _onDurationChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedDuration = value;
      });
    }
  }
  
  void _onSortOptionChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedSort = value;
      });
    }
  }
  
  void _applyFilters() {
    _fetchQuizzes();
    setState(() {
      _showFilters = false;
    });
  }
  
  void _resetFilters() {
    setState(() {
      _selectedDifficulty = 'Alle';
      _selectedDuration = 'Alle';
      _selectedSort = 'Neueste';
      _showFilters = false;
    });
    _fetchQuizzes();
  }

  void _onQuizTap(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(quiz: quiz),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.limeYellow,
      appBar: AppBar(
        title: Text(widget.category),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchQuizzes,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wähle ein Quiz für ${widget.category}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        
                        // Filter summary row (always visible)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.filter_alt, color: AppColors.darkBlue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Schwierigkeit: $_selectedDifficulty | Dauer: $_selectedDuration',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        // Expanded filter panel
                        if (_showFilters) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Filter',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.darkBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Difficulty filter
                                Text(
                                  'Schwierigkeit',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                InputDecorator(
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: AppColors.lightGrey),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.white,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedDifficulty,
                                      icon: const Icon(Icons.keyboard_arrow_down),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      isExpanded: true,
                                      onChanged: _onDifficultyChanged,
                                      items: _difficulties.map<DropdownMenuItem<String>>((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Duration filter
                                Text(
                                  'Dauer',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                InputDecorator(
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: AppColors.lightGrey),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.white,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedDuration,
                                      icon: const Icon(Icons.keyboard_arrow_down),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      isExpanded: true,
                                      onChanged: _onDurationChanged,
                                      items: _durations.map<DropdownMenuItem<String>>((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Sort options
                                Text(
                                  'Sortierung',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                InputDecorator(
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: AppColors.lightGrey),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.white,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedSort,
                                      icon: const Icon(Icons.keyboard_arrow_down),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      isExpanded: true,
                                      onChanged: _onSortOptionChanged,
                                      items: _sortOptions.map<DropdownMenuItem<String>>((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Filter action buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomButton(
                                        text: 'Filter zurücksetzen',
                                        onPressed: _resetFilters,
                                        type: ButtonType.outline,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: CustomButton(
                                        text: 'Anwenden',
                                        onPressed: _applyFilters,
                                        type: ButtonType.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        Expanded(
                          child: _quizzes.isEmpty
                              ? Center(
                                  child: Text(
                                    'Keine Quizze für diese Auswahl gefunden.',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _quizzes.length,
                                  itemBuilder: (context, index) {
                                    return QuizCard(
                                      quiz: _quizzes[index],
                                      onTap: () => _onQuizTap(_quizzes[index]),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
} 