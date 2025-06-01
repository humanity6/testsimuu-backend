import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../models/performance_data.dart';

class AnalyticsService with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  
  // Performance data
  PerformanceSummary? _performanceSummary;
  List<TopicPerformance> _topicPerformance = [];
  List<DifficultyPerformance> _difficultyPerformance = [];
  List<PerformanceTrend> _performanceTrends = [];
  List<StudySession> _studySessions = [];
  List<TopicProgress> _topicProgress = [];
  
  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  PerformanceSummary? get performanceSummary => _performanceSummary;
  List<TopicPerformance> get topicPerformance => _topicPerformance;
  List<DifficultyPerformance> get difficultyPerformance => _difficultyPerformance;
  List<PerformanceTrend> get performanceTrends => _performanceTrends;
  List<StudySession> get studySessions => _studySessions;
  List<TopicProgress> get topicProgress => _topicProgress;
  
  // Fetch performance summary
  Future<void> fetchPerformanceSummary(String token) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.performanceSummaryEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (kDebugMode) {
          print('Performance Summary Response Data: $data');
        }
        _performanceSummary = PerformanceSummary.fromJson(data);
        if (kDebugMode) {
          print('Performance Summary Parsed: $_performanceSummary');
        }
        notifyListeners();
      } else {
        throw Exception('Failed to load performance summary: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching performance summary: ${e.toString()}');
      }
      throw e;
    }
  }
  
  // Fetch performance by topic
  Future<void> fetchPerformanceByTopic(String token, {String? examId}) async {
    try {
      String url = ApiConfig.performanceByTopicEndpoint;
      if (examId != null && examId.isNotEmpty) {
        url += '?exam_id=$examId';
        if (kDebugMode) {
          print('Performance by topic URL: $url');
        }
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('Topic Performance Response Data: $data');
        }
        
        if (data is List) {
          _topicPerformance = data.map((item) => TopicPerformance.fromJson(item)).toList();
        } else if (data is Map && data.containsKey('results')) {
          _topicPerformance = (data['results'] as List)
              .map((item) => TopicPerformance.fromJson(item))
              .toList();
        } else {
          _topicPerformance = [];
        }
        
        if (kDebugMode) {
          print('Topic Performance Parsed Count: ${_topicPerformance.length}');
        }
        
        notifyListeners();
      } else {
        throw Exception('Failed to load topic performance: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching topic performance: ${e.toString()}');
      }
      throw e;
    }
  }
  
  // Fetch performance by difficulty
  Future<void> fetchPerformanceByDifficulty(String token, {String? examId}) async {
    try {
      String url = ApiConfig.performanceByDifficultyEndpoint;
      if (examId != null && examId.isNotEmpty) {
        url += '?exam_id=$examId';
        if (kDebugMode) {
          print('Performance by difficulty URL: $url');
        }
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          _difficultyPerformance = data.map((item) => DifficultyPerformance.fromJson(item)).toList();
        } else if (data is Map && data.containsKey('results')) {
          _difficultyPerformance = (data['results'] as List)
              .map((item) => DifficultyPerformance.fromJson(item))
              .toList();
        } else {
          _difficultyPerformance = [];
        }
        
        notifyListeners();
      } else {
        throw Exception('Failed to load difficulty performance: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching difficulty performance: ${e.toString()}');
      }
      throw e;
    }
  }
  
  // Fetch performance trends
  Future<void> fetchPerformanceTrends(String token, {String? examId, DateTimeRange? dateRange}) async {
    try {
      String url = ApiConfig.performanceTrendsEndpoint;
      
      // Add query parameters if provided
      List<String> queryParams = [];
      if (examId != null && examId.isNotEmpty) {
        queryParams.add('exam_id=$examId');
      }
      
      if (dateRange != null) {
        queryParams.add('start_date=${dateRange.start.toIso8601String().split('T')[0]}');
        queryParams.add('end_date=${dateRange.end.toIso8601String().split('T')[0]}');
      }
      
      if (queryParams.isNotEmpty) {
        url += '?' + queryParams.join('&');
      }
      
      if (kDebugMode) {
        print('Performance trends URL: $url');
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('Performance trends data: $data');
          print('Data type: ${data.runtimeType}');
        }
        
        try {
          if (data is List) {
            // Direct list of trend objects
            _performanceTrends = data.map((item) {
              if (item is Map<String, dynamic>) {
                return PerformanceTrend.fromJson(item);
              } else {
                return PerformanceTrend.fromJson(Map<String, dynamic>.from(item));
              }
            }).toList();
          } else if (data is Map) {
            if (data.containsKey('results') && data['results'] is List) {
              // Paginated response format
              _performanceTrends = (data['results'] as List)
                  .map((item) {
                    if (item is Map<String, dynamic>) {
                      return PerformanceTrend.fromJson(item);
                    } else {
                      return PerformanceTrend.fromJson(Map<String, dynamic>.from(item));
                    }
                  })
                  .toList();
            } else if (data.containsKey('data_points') && data['data_points'] is List) {
              // API format: {time_unit: "daily", data_points: [...]}
              final dataPoints = data['data_points'] as List;
              _performanceTrends = dataPoints
                  .map((item) {
                    if (item is Map<String, dynamic>) {
                      return PerformanceTrend.fromJson(item);
                    } else {
                      return PerformanceTrend.fromJson(Map<String, dynamic>.from(item));
                    }
                  })
                  .toList();
              
              if (kDebugMode) {
                print('Parsed trends from data_points format. Time unit: ${data['time_unit']}');
              }
            } else {
              // If it's a single object, wrap it in a list
              if (data is Map<String, dynamic>) {
                _performanceTrends = [PerformanceTrend.fromJson(data)];
              } else {
                _performanceTrends = [PerformanceTrend.fromJson(Map<String, dynamic>.from(data))];
              }
            }
          } else {
            _performanceTrends = [];
          }
          
          if (kDebugMode) {
            print('Successfully parsed ${_performanceTrends.length} performance trends');
            if (_performanceTrends.isNotEmpty) {
              print('First trend: ${_performanceTrends.first.date} - ${_performanceTrends.first.accuracy}%');
              print('Last trend: ${_performanceTrends.last.date} - ${_performanceTrends.last.accuracy}%');
            }
          }
        } catch (parseError) {
          if (kDebugMode) {
            print('Error parsing performance trends: $parseError');
            print('Raw data: $data');
            print('Data type: ${data.runtimeType}');
            if (data is Map) {
              print('Map keys: ${data.keys}');
              if (data.containsKey('data_points')) {
                print('Data points type: ${data['data_points'].runtimeType}');
                print('Data points length: ${(data['data_points'] as List?)?.length}');
              }
            }
          }
          _performanceTrends = [];
        }
        
        notifyListeners();
      } else {
        throw Exception('Failed to load performance trends: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching performance trends: ${e.toString()}');
      }
      throw e;
    }
  }
  
  // Fetch study sessions (exam sessions from the backend)
  Future<void> fetchStudySessions(String token, {String? examId, DateTimeRange? dateRange}) async {
    try {
      String url = ApiConfig.examSessionsEndpoint; // Use examSessionsEndpoint instead of studySessionsEndpoint
      
      // Add query parameters if provided
      List<String> queryParams = [];
      
      // Always add include_questions=false for analytics to avoid loading massive question data
      queryParams.add('include_questions=false');
      
      if (examId != null && examId.isNotEmpty) {
        queryParams.add('exam_id=$examId');
      }
      
      if (dateRange != null) {
        queryParams.add('start_date=${dateRange.start.toIso8601String().split('T')[0]}');
        queryParams.add('end_date=${dateRange.end.toIso8601String().split('T')[0]}');
      }
      
      url += '?' + queryParams.join('&');
      
      if (kDebugMode) {
        print('Study sessions URL: $url');
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('Study sessions (exam sessions) data: $data');
        }
        
        try {
          if (data is List) {
            _studySessions = data.map((item) => StudySession.fromExamSessionJson(item)).toList();
          } else if (data is Map && data.containsKey('results')) {
            _studySessions = (data['results'] as List)
                .map((item) => StudySession.fromExamSessionJson(item))
                .toList();
          } else {
            _studySessions = [];
          }
        } catch (parseError) {
          if (kDebugMode) {
            print('Error parsing study sessions: $parseError');
            print('Raw data: $data');
          }
          _studySessions = [];
        }
        
        notifyListeners();
      } else {
        throw Exception('Failed to load study sessions: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching study sessions: ${e.toString()}');
      }
      throw e;
    }
  }
  
  // Fetch user progress by topic
  Future<void> fetchProgressByTopic(String token, {String? examId}) async {
    try {
      String url = ApiConfig.progressByTopicEndpoint;
      if (examId != null && examId.isNotEmpty) {
        url += '?exam_id=$examId';
      } else {
        // For general analytics (no specific exam), only return topics with progress
        url += '?only_with_progress=true';
      }
      
      if (kDebugMode) {
        print('Progress by topic URL: $url');
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
          print('Progress by topic data: $data');
        }
        
        if (data is List) {
          _topicProgress = data.map((item) => TopicProgress.fromJson(item)).toList();
        } else if (data is Map && data.containsKey('results')) {
          _topicProgress = (data['results'] as List)
              .map((item) => TopicProgress.fromJson(item))
              .toList();
        } else {
          _topicProgress = [];
        }
        
        notifyListeners();
      } else {
        throw Exception('Failed to load topic progress: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching topic progress: ${e.toString()}');
      }
      throw e;
    }
  }
  
  // Helper method to set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _error = null;
    }
    notifyListeners();
  }
  
  // Helper method to handle errors
  void _handleError(String errorMessage) {
    _isLoading = false;
    _error = errorMessage;
    if (kDebugMode) {
      print(errorMessage);
    }
    notifyListeners();
  }
  
  // Clear all data
  void clearData() {
    _performanceSummary = null;
    _topicPerformance.clear();
    _difficultyPerformance.clear();
    _performanceTrends.clear();
    _studySessions.clear();
    _topicProgress.clear();
    _error = null;
    notifyListeners();
  }

  // Fetch all analytics data at once
  Future<void> fetchAllAnalyticsData(String token, {String? examId, DateTimeRange? dateRange}) async {
    if (_isLoading) return;
    
    _setLoading(true);
    clearData();
    
    try {
      if (kDebugMode) {
        print('Fetching all analytics data...');
        print('Exam ID parameter: $examId');
        print('Date range parameter: $dateRange');
      }
      
      // Fetch data sequentially to avoid race conditions and better error handling
      try {
        await fetchPerformanceSummary(token);
        if (kDebugMode) print('✓ Performance summary loaded');
      } catch (e) {
        if (kDebugMode) print('✗ Performance summary error: $e');
      }
      
      try {
        await fetchPerformanceByTopic(token, examId: examId);
        if (kDebugMode) print('✓ Performance by topic loaded: ${_topicPerformance.length} items');
      } catch (e) {
        if (kDebugMode) print('✗ Performance by topic error: $e');
      }
      
      try {
        await fetchPerformanceByDifficulty(token, examId: examId);
        if (kDebugMode) print('✓ Performance by difficulty loaded: ${_difficultyPerformance.length} items');
      } catch (e) {
        if (kDebugMode) print('✗ Performance by difficulty error: $e');
      }
      
      try {
        await fetchPerformanceTrends(token, examId: examId, dateRange: dateRange);
        if (kDebugMode) print('✓ Performance trends loaded: ${_performanceTrends.length} items');
      } catch (e) {
        if (kDebugMode) print('✗ Performance trends error: $e');
      }
      
      try {
        await fetchProgressByTopic(token, examId: examId);
        if (kDebugMode) print('✓ Progress by topic loaded: ${_topicProgress.length} items');
      } catch (e) {
        if (kDebugMode) print('✗ Progress by topic error: $e');
      }
      
      try {
        await fetchStudySessions(token, examId: examId, dateRange: dateRange);
        if (kDebugMode) print('✓ Study sessions loaded: ${_studySessions.length} items');
      } catch (e) {
        if (kDebugMode) print('✗ Study sessions error: $e');
      }
      
      if (kDebugMode) {
        print('All analytics data fetching completed');
        print('Summary: ${_performanceSummary != null ? "✓" : "✗"}');
        print('Topic Performance: ${_topicPerformance.length} items');
        print('Difficulty Performance: ${_difficultyPerformance.length} items');
        print('Performance Trends: ${_performanceTrends.length} items');
        print('Topic Progress: ${_topicProgress.length} items');
        print('Study Sessions: ${_studySessions.length} items');
      }
      
      _setLoading(false);
    } catch (e) {
      _handleError('Failed to load analytics data: ${e.toString()}');
    }
  }
} 