import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: widget.onNewChat,
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'New Chat',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          // Recent Conversations Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'RECENT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Conversation List
          Expanded(
            child: Consumer<ConversationProvider>(
              builder: (context, provider, _) {
                if (provider.conversationSessions.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  );
                }

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
                        onEnter: (_) {
                          setState(() {
                            _hoveredConversationId = conversation.id;
                          });
                        },
                        onExit: (_) {
                          setState(() {
                            _hoveredConversationId = null;
                          });
                        },
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              provider.switchConversation(conversation.id);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF6366FF).withOpacity(0.15)
                                    : isHovered
                                        ? const Color(0xFF6366FF).withOpacity(0.08)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isActive
                                      ? const Color(0xFF6366FF)
                                      : const Color(0xFF2D3E52),
                                  width: isActive ? 1.5 : 1.0,
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
                                            fontWeight: isActive
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isActive
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${conversation.messages.length} messages',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isHovered)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18),
                                        color: Colors.red.shade400,
                                        onPressed: () {
                                          _showDeleteConfirmation(context, provider, conversation);
                                        },
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        padding: EdgeInsets.zero,
                                      ),
                                    )
                                  else if (isActive)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ));
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: widget.onClearAll,
                icon: const Icon(Icons.delete_sweep, size: 18),
                label: const Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'VentAI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Privacy Protected',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '100% on-device, fully encrypted',
                  style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
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

  void _showDeleteConfirmation(
    BuildContext context,
    ConversationProvider provider,
    Conversation conversation,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation?'),
        content: Text(
          'This will permanently delete "${conversation.title}" and all its messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteConversationSession(conversation.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
