import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class ChatbotService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  List<ChatbotConversation> _conversations = [];
  ChatbotConversation? _activeConversation;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ChatbotConversation> get conversations => _conversations;
  ChatbotConversation? get activeConversation => _activeConversation;

  // Singleton instance
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = AuthService().accessToken;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Send a message to the chatbot and get a response
  Future<ChatbotMessage?> sendMessage(String message) async {
    try {
      _setLoading(true);
      _setError(null);

      final headers = await _getHeaders();
      
      // Get current locale for translation
      final currentLocale = LocalizationService().currentLocale;
      
      final response = await http.post(
        Uri.parse(ApiConfig.chatbotSendMessageEndpoint),
        headers: headers,
        body: json.encode({
          'message': message,
          'language': currentLocale.languageCode, // Send language code to backend
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // Create a ChatbotMessage from the response
        final aiMessage = ChatbotMessage(
          id: data['message_id'] as int? ?? 0,
          role: 'ASSISTANT',
          content: data['content'] as String? ?? '',
          createdAt: DateTime.now(),
          processingTimeMs: data['processing_time_ms'] as int?,
        );

        // Update active conversation
        if (_activeConversation != null) {
          _activeConversation!.messages.add(aiMessage);
          _activeConversation!.updatedAt = DateTime.now();
        }

        notifyListeners();
        return aiMessage;
      } else {
        final errorData = json.decode(response.body);
        _setError(errorData['error'] ?? 'Failed to send message');
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      _setError('Network error: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get or create an active conversation
  Future<ChatbotConversation?> getActiveConversation() async {
    try {
      _setLoading(true);
      _setError(null);

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(ApiConfig.chatbotActiveConversationEndpoint),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is Map<String, dynamic>) {
          _activeConversation = ChatbotConversation.fromJson(data);
          notifyListeners();
          return _activeConversation;
        } else {
          _setError('Invalid response format from server');
          return null;
        }
      } else if (response.statusCode == 404) {
        // No active conversation, create a new one
        return await createConversation();
      } else {
        try {
          final errorData = json.decode(response.body);
          _setError(errorData['error'] ?? 'Failed to get conversation');
        } catch (e) {
          _setError('Failed to get conversation: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting active conversation: $e');
      }
      _setError('Network error: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new conversation
  Future<ChatbotConversation?> createConversation() async {
    try {
      _setLoading(true);
      _setError(null);

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(ApiConfig.chatbotConversationsEndpoint),
        headers: headers,
        body: json.encode({}),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data != null && data is Map<String, dynamic>) {
          _activeConversation = ChatbotConversation.fromJson(data);
          
          // Add to conversations list if not already present
          if (!_conversations.any((conv) => conv.id == _activeConversation!.id)) {
            _conversations.insert(0, _activeConversation!);
          }
          
          notifyListeners();
          return _activeConversation;
        } else {
          _setError('Invalid response format from server');
          return null;
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          _setError(errorData['error'] ?? 'Failed to create conversation');
        } catch (e) {
          _setError('Failed to create conversation: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating conversation: $e');
      }
      _setError('Network error: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get conversation history
  Future<List<ChatbotMessage>> getConversationHistory(int conversationId) async {
    try {
      _setLoading(true);
      _setError(null);

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.chatbotConversationHistoryEndpoint}$conversationId/conversation_history/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messages = (data['messages'] as List)
            .map((messageData) => ChatbotMessage.fromJson(messageData))
            .toList();
        
        // Update active conversation if it matches
        if (_activeConversation?.id == conversationId) {
          _activeConversation!.messages = messages;
          notifyListeners();
        }
        
        return messages;
      } else {
        final errorData = json.decode(response.body);
        _setError(errorData['error'] ?? 'Failed to get conversation history');
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting conversation history: $e');
      }
      _setError('Network error: ${e.toString()}');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// List all user conversations
  Future<List<ChatbotConversation>> getConversations() async {
    try {
      _setLoading(true);
      _setError(null);

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.chatbotConversationsEndpoint}conversations/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _conversations = (data as List)
            .map((convData) => ChatbotConversation.fromJson(convData))
            .toList();
        
        notifyListeners();
        return _conversations;
      } else {
        final errorData = json.decode(response.body);
        _setError(errorData['error'] ?? 'Failed to get conversations');
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting conversations: $e');
      }
      _setError('Network error: ${e.toString()}');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// End a conversation
  Future<bool> endConversation(int conversationId) async {
    try {
      _setLoading(true);
      _setError(null);

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.chatbotEndConversationEndpoint}$conversationId/end_conversation/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Remove from active conversation if it matches
        if (_activeConversation?.id == conversationId) {
          _activeConversation = null;
        }
        
        // Update conversation in list
        final index = _conversations.indexWhere((conv) => conv.id == conversationId);
        if (index != -1) {
          _conversations[index].isActive = false;
        }
        
        notifyListeners();
        return true;
      } else {
        final errorData = json.decode(response.body);
        _setError(errorData['error'] ?? 'Failed to end conversation');
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error ending conversation: $e');
      }
      _setError('Network error: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Add a user message to the active conversation (for UI purposes)
  void addUserMessage(String message) {
    if (_activeConversation != null) {
      final userMessage = ChatbotMessage(
        id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
        role: 'USER',
        content: message,
        createdAt: DateTime.now(),
      );
      
      _activeConversation!.messages.add(userMessage);
      _activeConversation!.updatedAt = DateTime.now();
      notifyListeners();
    }
  }

  /// Clear error state
  void clearError() {
    _setError(null);
  }

  /// Clear chat history for the active conversation
  Future<bool> clearChatHistory() async {
    try {
      _setLoading(true);
      _setError(null);

      if (_activeConversation == null) {
        _setError('No active conversation to clear');
        return false;
      }

      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.chatbotConversationHistoryEndpoint}${_activeConversation!.id}/clear_history/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Clear the messages in the active conversation
        _activeConversation!.messages.clear();
        _activeConversation!.updatedAt = DateTime.now();
        notifyListeners();
        return true;
      } else {
        try {
          final errorData = json.decode(response.body);
          _setError(errorData['error'] ?? 'Failed to clear chat history');
        } catch (e) {
          _setError('Failed to clear chat history: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing chat history: $e');
      }
      _setError('Network error: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}

// Data models
class ChatbotConversation {
  final int id;
  final String? title;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isActive;
  List<ChatbotMessage> messages;

  ChatbotConversation({
    required this.id,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.messages,
  });

  factory ChatbotConversation.fromJson(Map<String, dynamic> json) {
    return ChatbotConversation(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
      messages: json['messages'] != null
          ? (json['messages'] as List)
              .map((messageData) => ChatbotMessage.fromJson(messageData))
              .toList()
          : [],
    );
  }
}

class ChatbotMessage {
  final int id;
  final String role;
  final String content;
  final DateTime createdAt;
  final int? processingTimeMs;

  ChatbotMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.processingTimeMs,
  });

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) {
    return ChatbotMessage(
      id: json['id'] as int? ?? 0,
      role: json['role'] as String? ?? 'USER',
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      processingTimeMs: json['processing_time_ms'] as int?,
    );
  }

  bool get isUser => role == 'USER';
  bool get isAssistant => role == 'ASSISTANT';
} 