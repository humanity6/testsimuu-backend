import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../services/chatbot_service.dart';
import '../../theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/app_title_widget.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({Key? key}) : super(key: key);

  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  late ChatbotService _chatbotService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _chatbotService = ChatbotService();
    _initializeChatbot();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeChatbot() async {
    try {
      await _chatbotService.getActiveConversation();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing chatbot: $e');
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Clear the input field immediately
    _messageController.clear();
    
    // Add user message to UI
    _chatbotService.addUserMessage(message);
    _scrollToBottom();

    // Send message to backend and get AI response
    final aiResponse = await _chatbotService.sendMessage(message);
    
    if (aiResponse != null) {
      _scrollToBottom();
    } else {
      // Show error if message failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_chatbotService.error ?? context.tr('failed_to_send_message')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(ChatbotMessage message) {
    final isUser = message.isUser;
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.primaryColor,
              child: const Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser 
                    ? theme.primaryColor 
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: isUser 
                    ? null 
                    : Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isUser 
                      ? Text(
                          message.content,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: 16,
                            ),
                            h1: TextStyle(
                              color: theme.textTheme.headlineMedium?.color,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: TextStyle(
                              color: theme.textTheme.headlineSmall?.color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: TextStyle(
                              color: theme.textTheme.titleLarge?.color,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            strong: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                            ),
                            em: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontStyle: FontStyle.italic,
                            ),
                            listBullet: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontSize: 16,
                            ),
                          ),
                        ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          color: isUser 
                              ? Colors.white70 
                              : theme.textTheme.bodySmall?.color,
                          fontSize: 12,
                        ),
                      ),
                      if (!isUser && message.processingTimeMs != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${message.processingTimeMs}ms',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondary,
              child: Icon(
                Icons.person,
                color: theme.colorScheme.onSecondary,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('ai_is_typing'),
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                decoration: InputDecoration(
                  hintText: context.tr('ask_me_anything_about_exams'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Consumer<ChatbotService>(
              builder: (context, chatbotService, child) {
                return FloatingActionButton(
                  onPressed: chatbotService.isLoading ? null : _sendMessage,
                  mini: true,
                  child: chatbotService.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.smart_toy,
            size: 48,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('welcome_to_ai_assistant'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('chatbot_welcome_message'),
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSuggestionChip(context.tr('study_tips_and_strategies')),
              _buildSuggestionChip(context.tr('exam_schedules_and_deadlines')),
              _buildSuggestionChip(context.tr('subject_specific_questions')),
              _buildSuggestionChip(context.tr('performance_analysis')),
              _buildSuggestionChip(context.tr('subscription_information')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return ActionChip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () {
        _messageController.text = text;
        _messageFocusNode.requestFocus();
      },
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      side: BorderSide(
        color: Theme.of(context).primaryColor.withOpacity(0.3),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return context.tr('just_now');
    } else if (difference.inHours < 1) {
      return context.tr('minutes_ago', params: {'minutes': '${difference.inMinutes}'});
    } else if (difference.inDays < 1) {
      return context.tr('hours_ago', params: {'hours': '${difference.inHours}'});
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _chatbotService,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const AppTitleWidget(
                isDarkGreenBackground: true,
                fontSize: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('ai_assistant_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            Consumer<ChatbotService>(
              builder: (context, chatbotService, child) {
                return PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'new_conversation':
                        await chatbotService.createConversation();
                        _scrollToBottom();
                        break;
                      case 'conversation_history':
                        // TODO: Implement conversation history screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.tr('conversation_history_coming_soon')),
                          ),
                        );
                        break;
                      case 'clear_history':
                        // Show confirmation dialog before clearing
                        final shouldClear = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(context.tr('clear_chat_history')),
                            content: Text(context.tr('clear_chat_confirmation')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: Text(context.tr('cancel')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: Text(context.tr('clear')),
                              ),
                            ],
                          ),
                        );
                        
                        if (shouldClear == true) {
                          final success = await chatbotService.clearChatHistory();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success 
                                  ? context.tr('chat_history_cleared_success')
                                  : context.tr('chat_history_cleared_failure')),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        }
                        break;
                      case 'end_conversation':
                        if (chatbotService.activeConversation != null) {
                          await chatbotService.endConversation(
                            chatbotService.activeConversation!.id,
                          );
                          await chatbotService.createConversation();
                        }
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'new_conversation',
                      child: Row(
                        children: [
                          const Icon(Icons.add_comment),
                          const SizedBox(width: 8),
                          Text(context.tr('new_conversation')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'conversation_history',
                      child: Row(
                        children: [
                          const Icon(Icons.history),
                          const SizedBox(width: 8),
                          Text(context.tr('history')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear_history',
                      child: Row(
                        children: [
                          const Icon(Icons.clear_all, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(context.tr('clear_chat_history'), style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'end_conversation',
                      child: Row(
                        children: [
                          const Icon(Icons.stop_circle),
                          const SizedBox(width: 8),
                          Text(context.tr('end_conversation')),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: !_isInitialized
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(context.tr('initializing_ai_assistant')),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: Consumer<ChatbotService>(
                      builder: (context, chatbotService, child) {
                        final conversation = chatbotService.activeConversation;
                        final messages = conversation?.messages ?? [];
                        
                        if (chatbotService.error != null) {
                          return Center(
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
                                  context.tr('error_with_message', params: {'error': chatbotService.error ?? ''}),
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    chatbotService.clearError();
                                    _initializeChatbot();
                                  },
                                  child: Text(context.tr('retry')),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: messages.isEmpty 
                              ? 1 
                              : messages.length + (chatbotService.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (messages.isEmpty) {
                              return _buildWelcomeMessage();
                            }
                            
                            if (index == messages.length && chatbotService.isLoading) {
                              return _buildTypingIndicator();
                            }
                            
                            return _buildMessageBubble(messages[index]);
                          },
                        );
                      },
                    ),
                  ),
                  _buildMessageInput(),
                ],
              ),
      ),
    );
  }
} 