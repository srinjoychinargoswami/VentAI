import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_storage.dart';
import '../widgets/empathy_chat_widget.dart';
import '../widgets/mood_selector.dart';
import '../providers/conversation_provider.dart';
import '../providers/setup_state_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedMood;
  
  @override
  void initState() {
    super.initState();
    
    // Load conversations when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Vent AI'),
            Consumer2<ConversationProvider, SetupStateProvider>(
              builder: (context, conversationProvider, setupProvider, child) {
                // Status display
                final isAdvancedAI = setupProvider.hasAdvancedAI;
                final statusText = isAdvancedAI 
                  ? 'AI Ready • Privacy Protected' 
                  : 'Offline Mode • Data Stays Local';
                final statusColor = isAdvancedAI ? Colors.green : Colors.blue;
                
                return Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.normal,
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          // Clear conversations button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearConversationsDialog(),
            tooltip: 'Clear all conversations',
          ),
        ],
      ),
      body: Column(
        children: [
          // Mood selector
          Container(
            padding: const EdgeInsets.all(16),
            child: MoodSelector(
              selectedMood: _selectedMood,
              onMoodSelected: (mood) => setState(() => _selectedMood = mood),
            ),
          ),
          
          // Chat messages
          Expanded(
            child: Consumer<ConversationProvider>(
              builder: (context, provider, child) {
                // Handle empty state and errors
                if (provider.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading conversations...'),
                      ],
                    ),
                  );
                }
                
                if (provider.lastErrorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${provider.lastErrorMessage}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            provider.clearError();
                            provider.refresh();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                
                return EmpathyChatWidget(
                  conversations: provider.conversations,
                  isLoading: provider.isSendingMessage,
                  scrollController: _scrollController,
                );
              },
            ),
          ),
          
          // Message input (text only)
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Build text message input widget
  Widget _buildMessageInput() {
    return Consumer<ConversationProvider>(
      builder: (context, provider, child) {
        final isSending = provider.isSendingMessage;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // Progress indicator while sending
              if (isSending) 
                const LinearProgressIndicator(minHeight: 2),
              
              if (isSending) const SizedBox(height: 8),
              
              // Text input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: isSending 
                          ? 'Generating response...' 
                          : 'Share what\'s on your mind...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !isSending,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: isSending ? null : _sendMessage,
                    mini: true,
                    child: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Send message and get AI response
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final provider = context.read<ConversationProvider>();
    
    // Prevent multiple simultaneous operations
    if (provider.isSendingMessage) return;

    try {
      // Clear input immediately for better UX
      _messageController.clear();
      
      // Send message with enhanced error handling
      await provider.sendMessage(message, mood: _selectedMood);
      
      // Clear mood selection after successful send
      setState(() {
        _selectedMood = null;
      });

      // Scroll to bottom
      _scrollToBottom();

    } catch (e) {
      debugPrint('Error sending message: $e');
      
      // Restore message if there was an error
      _messageController.text = message;
      
      // Enhanced error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed to send message',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString().length > 60 
                    ? "${e.toString().substring(0, 60)}..."
                    : e.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _sendMessage(),
            ),
          ),
        );
      }
    }
  }

  /// Scroll to bottom of chat
  void _scrollToBottom() {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        try {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        } catch (e) {
          debugPrint('Scroll error: $e');
          // Fallback: Try immediate jump if animation fails
          try {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          } catch (jumpError) {
            debugPrint('Jump scroll also failed: $jumpError');
          }
        }
      }
    });
  }

  /// Show dialog to clear all conversations
  void _showClearConversationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Clear All Conversations'),
            ],
          ),
          content: const Text(
            'This will permanently delete all your conversations including:\n\n'
            '• All text messages and AI responses\n'
            '• Mood selections and conversation history\n\n'
            'This action cannot be undone.\n\n'
            'Are you sure you want to continue?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllConversations();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  /// Clear all conversations
  Future<void> _clearAllConversations() async {
    try {
      await context.read<ConversationProvider>().clearAllConversations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('All conversations cleared successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing conversations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed to clear conversations',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _clearAllConversations(),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}