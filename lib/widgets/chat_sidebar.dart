import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/conversation_provider.dart';
import '../models/conversation_model.dart';

class ChatSidebar extends StatefulWidget {
  final VoidCallback onNewChat;
  final VoidCallback onClearAll;

  const ChatSidebar({
    Key? key,
    required this.onNewChat,
    required this.onClearAll,
  }) : super(key: key);

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  String? _hoveredConversationId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          right: BorderSide(
            color: Color(0xFF94A3B8).withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // ✅ HEADER: New Chat Button - NO TOP PADDING
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 0, bottom: 12),
            child: ElevatedButton(
              onPressed: widget.onNewChat,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '+ ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'New Chat',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // ✅ RECENT LABEL (always visible)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'RECENT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // ✅ CONVERSATION LIST (empty state shows nothing)
          Expanded(
            child: Consumer<ConversationProvider>(
              builder: (context, provider, _) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: provider.conversationSessions.length,
                  itemBuilder: (context, index) {
                    final conversation = provider.conversationSessions[index];
                    final isActive = conversation.id == provider.activeConversationId;
                    final isHovered = _hoveredConversationId == conversation.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _hoveredConversationId = conversation.id),
                        onExit: (_) => setState(() => _hoveredConversationId = null),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => provider.switchConversation(conversation.id),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.primary.withOpacity(0.15) : isHovered ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isActive ? AppColors.primary : Color(0xFF94A3B8).withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          conversation.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                            color: isActive ? AppColors.primary : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${conversation.messages.length} messages',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isHovered)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        color: AppColors.error,
                                        onPressed: () => _showDeleteConfirmation(context, provider, conversation),
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                      ),
                                    )
                                  else if (isActive)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✅ CLEAR ALL BUTTON
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _showClearAllConfirmation,
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text(
                  'Clear all chats',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.textTertiary,
                  side: BorderSide(
                    color: AppColors.textTertiary.withOpacity(0.3),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // ✅ FOOTER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.textTertiary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Vent AI • Privacy Protected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  '100% on-device, fully encrypted',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Color(0xFF94A3B8).withOpacity(0.3),
            width: 1,
          ),
        ),
        title: const Text(
          'Clear all chats?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will permanently delete your entire chat history. This action cannot be undone.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final provider = context.read<ConversationProvider>();
              await provider.clearAllConversationsCompletely();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(
              'Clear All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    ConversationProvider provider,
    Conversation conversation,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Color(0xFF94A3B8).withOpacity(0.3),
            width: 1,
          ),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Conversation?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will permanently delete "${conversation.title}" and all its messages.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () {
              provider.deleteConversationSession(conversation.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
