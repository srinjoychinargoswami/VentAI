import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gemma_service.dart';
import '../theme/app_colors.dart';
import '../widgets/mood_selector.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/chat_sidebar.dart';
import '../widgets/app_footer.dart';
import '../providers/conversation_provider.dart';
import '../providers/setup_state_provider.dart';
import 'legal_page.dart';

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
  bool _sidebarVisible = true;

  // Platform detection
  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  bool get _isLargeScreen => MediaQuery.of(context).size.width >= 600;
  
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
    debugPrint('  - activeConversationId: ${provider.activeConversationId}');

    // Determine if we should show sidebar (desktop layout)
    final showSidebar = _isDesktop || _isLargeScreen;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar (shown on desktop/tablet with toggle)
            if (showSidebar && _sidebarVisible)
              ChatSidebar(
                onNewChat: () {
                  provider.createNewConversation();
                  setState(() {});
                  debugPrint('✨ New conversation created');
                },
                onClearAll: () => _showClearConversationsDialog(),
              ),

            // Main chat area
            Expanded(
              child: Column(
                children: [
                  // CUSTOM FIXED HEADER (pinned, can't be overlapped by messages)
                  Consumer<ConversationProvider>(
                    builder: (context, provider, _) {
                      final hasMessages = provider.activeConversation?.messages.isNotEmpty ?? false;
                      return Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          border: Border(
                            bottom: BorderSide(
                              color: const Color(0xFF94A3B8).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // LEFT: Sidebar toggle or spacer
                            if (showSidebar)
                              IconButton(
                                icon: Icon(
                                  _sidebarVisible ? Icons.chevron_left : Icons.menu,
                                  size: 24,
                                  color: AppColors.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _sidebarVisible = !_sidebarVisible;
                                  });
                                },
                                tooltip: _sidebarVisible ? 'Hide sidebar' : 'Show sidebar',
                              )
                            else
                              Consumer<ConversationProvider>(
                                builder: (context, provider, _) {
                                  return IconButton(
                                    icon: Stack(
                                      children: [
                                        const Icon(Icons.menu, color: AppColors.primary),
                                        if (provider.conversationSessions.length > 1)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: AppColors.error,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              constraints: const BoxConstraints(
                                                minWidth: 16,
                                                minHeight: 16,
                                              ),
                                              child: Text(
                                                '${provider.conversationSessions.length}',
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
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

                            // CENTER: Title and status
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      provider.activeConversation?.title ?? 'VentAI',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Consumer<SetupStateProvider>(
                                      builder: (context, setupProvider, child) {
                                        final isAdvancedAI = setupProvider.hasAdvancedAI;
                                        final statusText = isAdvancedAI
                                          ? 'AI Ready • Privacy Protected'
                                          : 'Offline Mode • Data Stays Local';
                                        final statusColor = isAdvancedAI ? AppColors.success : AppColors.primary;

                                        return Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: statusColor,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // RIGHT: Action buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ℹ️ Info button
                                IconButton(
                                  icon: Text(
                                    'ℹ️',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LegalPage(),
                                      ),
                                    );
                                  },
                                  tooltip: 'Privacy Policy & Disclaimers',
                                ),

                                // 🚨 Crisis button
                                IconButton(
                                  icon: Text(
                                    '🚨',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  onPressed: () => _showCrisisResourcesDialog(),
                                  tooltip: 'Crisis Resources & Help',
                                ),

                                // Delete button (only when sidebar hidden)
                                if (!showSidebar)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                    onPressed: () => _showClearConversationsDialog(),
                                    tooltip: 'Clear all conversations',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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
                                  color: AppColors.error.withOpacity(0.7),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error: ${provider.lastErrorMessage}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.error),
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

                        if (messages.isEmpty && !_isWaitingForResponse) {
                          return Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Icon section: 128x128 circle with bulb
                                  Container(
                                    width: 128,
                                    height: 128,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withOpacity(0.1),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '💡',
                                        style: TextStyle(fontSize: 96),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 36), // Gap between icon and text

                                  // Text section with max-width 512
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 512),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Title: "Welcome to Vent AI" with "Vent AI" in indigo
                                          RichText(
                                            textAlign: TextAlign.center,
                                            text: const TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: 'Welcome to ',
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                    letterSpacing: -0.02,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: 'Vent AI',
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                    letterSpacing: -0.02,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 24), // Gap between title and body

                                          // Body paragraphs
                                          const Text(
                                            "I'm your AI emotional support companion. Share what's on your mind, and I'll respond with empathy and understanding.",
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.6,
                                              color: AppColors.textSecondary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),

                                          // White paragraph (on-device)
                                          const Text(
                                            '100% on-device. Your data stays private and secure.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.6,
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),

                                          // Important disclaimer paragraph
                                          const Text(
                                            "I'm not a substitute for professional mental health care. If you need urgent help, please reach out to local services or crisis hotlines.",
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.6,
                                              color: AppColors.textTertiary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),

                                          // Crisis resources paragraph
                                          const Text(
                                            'In crisis? Call 988 (Suicide & Crisis Lifeline USA) or text HOME to 741741. Tap the 🚨 button for global resources.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.6,
                                              color: AppColors.textTertiary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24), // Extra gap before privacy note

                                          // Privacy policy note (smaller)
                                          const Text(
                                            'Tap the ℹ️ button to view our Privacy Policy and Disclaimers',
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.4,
                                              color: AppColors.textTertiary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                  // Footer
                  const AppFooter(),
                ],
              ),
            ),
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
          padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.background,
                AppColors.background.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border(
                top: BorderSide(
                  color: Color(0xFF94A3B8).withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress indicator while sending
                if (isSending)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),

                // Mood selector
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8),
                  child: MoodSelector(
                    selectedMood: _selectedMood,
                    onMoodSelected: (mood) => setState(() => _selectedMood = mood),
                  ),
                ),

                // Text input
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: isSending
                        ? 'Generating response...'
                        : 'Share what\'s on your mind...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 6,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !isSending,
                    onChanged: (value) => setState(() {}),
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),

                // Bottom action area (character count + send button)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Character count (shows at 3000+)
                      if (_messageController.text.length > 3000)
                        Text(
                          '${_messageController.text.length}/4000',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        )
                      else
                        const SizedBox(width: 0),

                      // Send button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
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
                                  : const Icon(
                                      Icons.send,
                                      size: 20,
                                      color: AppColors.textOnPrimary,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: AppColors.textPrimary,
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
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Color(0xFF94A3B8).withOpacity(0.3),
              width: 1,
            ),
          ),
          title: Row(
            children: const [
              Icon(Icons.emergency, color: AppColors.error, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Crisis Resources & Help',
                  style: TextStyle(
                    color: AppColors.textPrimary,
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
              children: const [
                Text(
                  'IF YOU\'RE IN CRISIS:',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '🇺🇸 USA:\n'
                  '• Call 988 (Suicide & Crisis Lifeline)\n'
                  '• Text HOME to 741741 (Crisis Text Line)\n'
                  '• Call 911 for emergencies',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'FIND HELP IN YOUR COUNTRY:',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Type in chat: "emergency services [country name]"\n\n'
                  'Examples:\n'
                  '• "emergency services Canada"\n'
                  '• "emergency services UK"\n'
                  '• "emergency services Australia"',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.textSecondary),
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
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Color(0xFF94A3B8).withOpacity(0.3),
              width: 1,
            ),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Clear All Conversations',
                  style: TextStyle(
                    color: AppColors.textPrimary,
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
              children: const [
                Text(
                  'This will permanently delete all your conversations including:\n\n'
                  '• All text messages and AI responses\n'
                  '• Mood selections and conversation history\n\n'
                  'This action cannot be undone.\n\n'
                  'Are you sure you want to continue?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
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
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllConversations();
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
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
      await context.read<ConversationProvider>().clearAllConversationsCompletely();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.textPrimary),
                SizedBox(width: 8),
                Text('All conversations cleared successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
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
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: AppColors.textPrimary,
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
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: Color(0xFF94A3B8).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    backgroundColor: AppColors.surface,
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
                                                  const Icon(Icons.check_circle, color: AppColors.textPrimary),
                                                  SizedBox(width: 8),
                                                  Text('All conversations cleared'),
                                                ],
                                              ),
                                              backgroundColor: AppColors.success,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.error,
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
                                backgroundColor: AppColors.error,
                                foregroundColor: AppColors.textPrimary,
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
                              selectedTileColor: AppColors.primary.withOpacity(0.15),
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
                                ? const Icon(Icons.check_circle, color: AppColors.primary)
                                : const Icon(Icons.chat_bubble_outline),
                              onTap: () {
                                debugPrint('🔄 Switching to: ${conv.id}');
                                provider.switchConversation(conv.id);
                                setState(() {}); // Force UI update
                                Navigator.pop(context);
                                debugPrint('✅ Switched to: ${conv.title} (${conv.messages.length} messages)');
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: AppColors.error),
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