import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vent_ai/providers/conversation_provider.dart';
import 'package:vent_ai/themes/app_colors.dart';
import 'package:vent_ai/widgets/conversation_list_widget.dart';
import 'package:vent_ai/widgets/chat_message_widget.dart';
import 'package:vent_ai/services/gemma_service.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});

  @override
  State<AppMainScreen> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize with first conversation if empty
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ConversationProvider>();
      if (provider.conversationSessions.isEmpty) {
        await provider.createNewConversation();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final provider = context.read<ConversationProvider>();
    provider.addMessageToSession('user', text);

    setState(() => _isLoading = true);

    try {
      // Generate AI response
      final response = await GemmaService().generateEmotionalResponse(text);
      provider.addMessageToSession('assistant', response);

      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      provider.addMessageToSession('assistant', 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 Building AppMainScreen');
    final screenSize = MediaQuery.of(context).size;
    debugPrint('Screen size: ${screenSize.width} x ${screenSize.height}');
    debugPrint('Is portrait: ${screenSize.height > screenSize.width}');

    // Debug provider state
    final provider = context.read<ConversationProvider>();
    debugPrint('📊 Provider state:');
    debugPrint('  - conversationSessions: ${provider.conversationSessions.length}');
    debugPrint('  - conversations (old): ${provider.conversations.length}');
    debugPrint('  - activeConversationId: ${provider.activeConversationId}');
    debugPrint('  - activeConversation: ${provider.activeConversation?.title ?? "null"}');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Consumer<ConversationProvider>(
          builder: (context, provider, _) =>
            Text(provider.activeConversation?.title ?? 'VentAI'),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Row(
          children: [
            // DEBUG: Sidebar with visible border
            Container(
              width: 280,
              color: AppColors.surface,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'CONVERSATIONS',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ConversationListWidget(),
                  ),
                ],
              ),
            ),
            // Main Chat Area
            Expanded(
              child: Consumer<ConversationProvider>(
                builder: (context, provider, _) {
                  final messages = provider.activeConversation?.messages ?? [];
                  debugPrint('📨 Rendering ${messages.length} messages');

                  return Column(
                    children: [
                      // Messages
                      Expanded(
                        child: messages.isEmpty
                          ? Center(
                              child: Text(
                                'Start a conversation...',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              reverse: true,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[messages.length - 1 - index];
                                return ChatMessageWidget(
                                  content: message.content,
                                  isUserMessage: message.role == 'user',
                                  onRegenerate: () {
                                    // TODO: Regenerate
                                  },
                                  onDelete: () {
                                    provider.deleteMessageFromSession(message.id);
                                  },
                                );
                              },
                            ),
                      ),
                      // Input Field
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                enabled: !_isLoading,
                                maxLines: null,
                                style: TextStyle(color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _sendMessage,
                              child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
                                    ),
                                  )
                                : Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Consumer<ConversationProvider>(
      builder: (context, provider, _) {
        final messages = provider.activeConversation?.messages ?? [];

        return Column(
          children: [
            // Messages
            Expanded(
              child: messages.isEmpty
                ? Center(
                    child: Text(
                      'Start a conversation...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return ChatMessageWidget(
                        content: message.content,
                        isUserMessage: message.role == 'user',
                        onRegenerate: () {
                          // Regenerate last AI message
                        },
                        onDelete: () {
                          provider.deleteMessageFromSession(message.id);
                        },
                      );
                    },
                  ),
            ),
            // Input Field
            Padding(
              padding: EdgeInsets.all(16),
              child: _buildMessageInput(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar - Conversation List (280px)
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              right: BorderSide(color: AppColors.background),
            ),
          ),
          child: ConversationListWidget(),
        ),
        // Main Chat Area
        Expanded(
          child: Consumer<ConversationProvider>(
            builder: (context, provider, _) {
              final messages = provider.activeConversation?.messages ?? [];

              return Column(
                children: [
                  // Messages
                  Expanded(
                    child: messages.isEmpty
                      ? Center(
                          child: Text(
                            'Start a conversation...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return ChatMessageWidget(
                              content: message.content,
                              isUserMessage: message.role == 'user',
                              onRegenerate: () {
                                // Regenerate last AI message
                              },
                              onDelete: () {
                                provider.deleteMessageFromSession(message.id);
                              },
                            );
                          },
                        ),
                  ),
                  // Input Field
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: _buildMessageInput(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            enabled: !_isLoading,
            maxLines: null,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Type your message...',
              hintStyle: TextStyle(color: AppColors.textSecondary),
            ),
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendMessage,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation(AppColors.textPrimary),
                ),
              )
            : Icon(Icons.send),
        ),
      ],
    );
  }
}
