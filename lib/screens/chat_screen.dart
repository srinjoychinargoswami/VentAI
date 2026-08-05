import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gemma_service.dart';
import '../widgets/empathy_chat_widget.dart';
import '../widgets/mood_selector.dart';
import '../widgets/chat_message_widget.dart';
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
  bool _isWaitingForResponse = false;
  
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
    debugPrint('📱 Building ChatScreen');
    final screenSize = MediaQuery.of(context).size;
    debugPrint('Screen size: ${screenSize.width} x ${screenSize.height}');

    final provider = context.read<ConversationProvider>();
    debugPrint('📊 ChatScreen Provider state:');
    debugPrint('  - conversationSessions: ${provider.conversationSessions.length}');
    debugPrint('  - conversations (old): ${provider.conversations.length}');
    debugPrint('  - activeConversationId: ${provider.activeConversationId}');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Consumer<ConversationProvider>(
              builder: (context, provider, _) {
                final title = provider.activeConversation?.title ?? 'VentAI';
                return Text(
                  title,
                  style: const TextStyle(fontSize: 16),
                );
              },
            ),
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
        leading: Consumer<ConversationProvider>(
          builder: (context, provider, _) {
            return IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.menu),
                  if (provider.conversationSessions.length > 1)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${provider.conversationSessions.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => _showConversationDrawer(),
              tooltip: 'View conversations',
            );
          },
        ),
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

            // Chat messages - Display active conversation's messages
            Expanded(
              child: Consumer<ConversationProvider>(
                builder: (context, provider, child) {
                  debugPrint('📨 Active conversation: ${provider.activeConversation?.title}');
                  debugPrint('📊 Messages count: ${provider.activeConversation?.messages.length ?? 0}');

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

                  // Show active conversation's messages
                  final messages = provider.activeConversation?.messages ?? [];
                  debugPrint('🎯 Rendering ${messages.length} messages from active conversation');

                  if (messages.isEmpty && !provider.isSendingMessage) {
                    return Center(
                      child: Text(
                        'Start a conversation...',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: messages.length + (_isWaitingForResponse ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show thinking bubble at the top (first item when reversed)
                      if (_isWaitingForResponse && index == 0) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Thinking...',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final message = messages[messages.length - 1 - (_isWaitingForResponse ? index - 1 : index)];
                      return ChatMessageWidget(
                        content: message.content,
                        isUserMessage: message.role == 'user',
                        onRegenerate: () {
                          // TODO: Regenerate last AI message
                        },
                        onDelete: () {
                          provider.deleteMessageFromSession(message.id);
                        },
                      );
                    },
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

    // Ensure active conversation exists
    if (provider.activeConversationId == null) {
      debugPrint('❌ No active conversation - creating new one');
      provider.createNewConversation();
    }

    // Prevent multiple simultaneous operations
    if (_isWaitingForResponse) return;

    try {
      debugPrint('📤 Sending message to active conversation: ${provider.activeConversation?.title}');

      // Clear input immediately for better UX
      _messageController.clear();

      // Add user message to active conversation
      provider.addMessageToSession('user', message);
      debugPrint('✅ User message added');

      // Set loading state to show thinking bubble
      setState(() {
        _isWaitingForResponse = true;
        _selectedMood = null;
      });

      debugPrint('⏳ Showing thinking bubble - waiting for AI response...');

      // Generate AI response - this waits for the COMPLETE response
      final response = await GemmaService().generateEmotionalResponse(message);
      debugPrint('✅ AI response received: ${response.length} chars');

      // Add AI response to active conversation
      provider.addMessageToSession('assistant', response);
      debugPrint('✅ AI message added to conversation');

      // Hide thinking bubble and update UI
      setState(() {
        _isWaitingForResponse = false;
      });

      // Scroll to bottom
      _scrollToBottom();

    } catch (e) {
      debugPrint('❌ Error sending message: $e');

      // Restore message if there was an error
      _messageController.text = message;

      // Hide loading state
      setState(() {
        _isWaitingForResponse = false;
      });

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

  /// Show conversation list drawer
  void _showConversationDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Consumer<ConversationProvider>(
          builder: (context, provider, _) {
            debugPrint('🗂️ Showing conversations: ${provider.conversationSessions.length}');
            debugPrint('📌 Current active: ${provider.activeConversationId}');

            return Container(
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Conversations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                provider.createNewConversation();
                                setState(() {});
                                Navigator.pop(context);
                                debugPrint('✨ New conversation created');
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'New',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Show confirmation before deleting all
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete All Conversations?'),
                                    content: const Text(
                                      'This will permanently delete all conversations and messages. This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(dialogContext);
                                          provider.deleteAllConversationSessions();
                                          Navigator.pop(context);
                                          debugPrint('🗑️ All conversations deleted');
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Row(
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.white),
                                                  SizedBox(width: 8),
                                                  Text('All conversations cleared'),
                                                ],
                                              ),
                                              backgroundColor: Colors.green.shade600,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete All'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete_sweep, size: 16),
                              label: const Text(
                                'Clear All',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: provider.conversationSessions.isEmpty
                      ? const Center(
                          child: Text('No conversations yet'),
                        )
                      : ListView.builder(
                          itemCount: provider.conversationSessions.length,
                          itemBuilder: (context, index) {
                            final conv = provider.conversationSessions[index];
                            final isActive = conv.id == provider.activeConversationId;

                            return ListTile(
                              selected: isActive,
                              selectedTileColor: Colors.blue.shade200.withOpacity(0.3),
                              title: Text(
                                conv.title,
                                style: TextStyle(
                                  fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                  fontSize: isActive ? 16 : 14,
                                ),
                              ),
                              subtitle: Text(
                                '${conv.messages.length} messages • ${conv.createdAt.toString().split('.')[0]}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              leading: isActive
                                ? const Icon(Icons.check_circle, color: Colors.blue)
                                : const Icon(Icons.chat_bubble_outline),
                              onTap: () {
                                debugPrint('🔄 Switching to: ${conv.id}');
                                provider.switchConversation(conv.id);
                                setState(() {}); // Force UI update
                                Navigator.pop(context);
                                debugPrint('✅ Switched to: ${conv.title} (${conv.messages.length} messages)');
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  debugPrint('🗑️ Deleting: ${conv.title}');
                                  provider.deleteConversationSession(conv.id);
                                  Navigator.pop(context);
                                  debugPrint('✅ Deleted: ${conv.title}');
                                  // Reopen drawer to show updated list
                                  Future.delayed(const Duration(milliseconds: 500), () {
                                    if (mounted) _showConversationDrawer();
                                  });
                                },
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}