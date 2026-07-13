import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_storage.dart';
import '../services/gemma_service.dart';
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

    // Initialize GemmaService for chat
    _initializeAI();

    // Load conversations when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().refresh();
    });
  }

  /// Ensure GemmaService is initialized for inference
  Future<void> _initializeAI() async {
    try {
      await GemmaService().initialize();
      debugPrint('✅ GemmaService ready for chat');
    } catch (e) {
      debugPrint('❌ Failed to initialize GemmaService: $e');
    }
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
          // Crisis Resources button
          IconButton(
            icon: const Icon(Icons.emergency),
            onPressed: () => _showCrisisResourcesDialog(),
            tooltip: 'Crisis Resources & Help',
          ),
          // Clear conversations button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearConversationsDialog(),
            tooltip: 'Clear all conversations',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
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
      ),
    );
  }

  /// Build text message input widget
  Widget _buildMessageInput() {
    return Consumer<ConversationProvider>(
      builder: (context, provider, child) {
        final isSending = provider.isSendingMessage;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  const SizedBox(width: 4),
                  // Send button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isSending ? null : _sendMessage,
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: isSending
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.send,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                        ),
                      ),
                    ),
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

  /// Show crisis resources dialog
  void _showCrisisResourcesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          backgroundColor: Colors.grey.shade900,
          title: Row(
            children: [
              Icon(Icons.emergency, color: Colors.red.shade300, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Crisis Resources & Help',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'IF YOU\'RE IN CRISIS:',
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '🇺🇸 USA:\n'
                  '• Call 988 (Suicide & Crisis Lifeline)\n'
                  '• Text HOME to 741741 (Crisis Text Line)\n'
                  '• Call 911 for emergencies',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'FIND HELP IN YOUR COUNTRY:',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Type in chat: "emergency services [country name]"\n\n'
                  'Examples:\n'
                  '• "emergency services Canada"\n'
                  '• "emergency services UK"\n'
                  '• "emergency services Australia"',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: const Text(
                    'I can help you find crisis hotlines and mental health resources for any country.\n\n'
                    'You are not alone. Help is available right now.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog to clear all conversations
  void _showClearConversationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          backgroundColor: Colors.grey.shade900,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Clear All Conversations',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This will permanently delete all your conversations including:\n\n'
                  '• All text messages and AI responses\n'
                  '• Mood selections and conversation history\n\n'
                  'This action cannot be undone.\n\n'
                  'Are you sure you want to continue?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllConversations();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
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