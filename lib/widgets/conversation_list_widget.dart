import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vent_ai/providers/conversation_provider.dart';
import 'package:vent_ai/themes/app_colors.dart';

class ConversationListWidget extends StatefulWidget {
  const ConversationListWidget({super.key});

  @override
  State<ConversationListWidget> createState() => _ConversationListWidgetState();
}

class _ConversationListWidgetState extends State<ConversationListWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ConversationProvider>(
      builder: (context, provider, _) {
        debugPrint('🗂️ ConversationListWidget: ${provider.conversationSessions.length} sessions');
        debugPrint('📌 Active conversation: ${provider.activeConversationId}');

        return Column(
          children: [
            // New Chat Button
            Padding(
              padding: EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => provider.createNewConversation(),
                icon: Icon(Icons.add),
                label: Text('New Chat'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
            // Conversations List
            Expanded(
              child: provider.conversationSessions.isEmpty
                ? Center(
                    child: Text(
                      'No conversations',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: provider.conversationSessions.length,
                    itemBuilder: (context, index) {
                      final conversation = provider.conversationSessions[index];
                      final isActive = conversation.id == provider.activeConversationId;
                      debugPrint('🗨️ Rendering conversation: ${conversation.title} (active: $isActive)');

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ConversationTile(
                      conversation: conversation,
                      isActive: isActive,
                      onTap: () => provider.switchConversation(conversation.id),
                      onDelete: () => _showDeleteDialog(context, conversation.id),
                      onRename: () => _showRenameDialog(context, conversation),
                    ),
                  );
                },
              ),
            ),
            // Delete All Button
            Padding(
              padding: EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () => _showDeleteAllDialog(context, provider),
                icon: Icon(Icons.delete_sweep, color: AppColors.error),
                label: Text(
                  'Delete All Chats',
                  style: TextStyle(color: AppColors.error),
                ),
                style: TextButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, String conversationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Conversation?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('This cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ConversationProvider>().deleteConversationSession(conversationId);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context, ConversationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete All Chats?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This will permanently delete all conversations. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteAllConversationSessions();
              Navigator.pop(context);
            },
            child: Text('Delete All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, conversation) {
    final controller = TextEditingController(text: conversation.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Rename Chat', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'New name...',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ConversationProvider>().renameConversationSession(
                conversation.id,
                controller.text,
              );
              Navigator.pop(context);
            },
            child: Text('Rename'),
          ),
        ],
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  final dynamic conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const ConversationTile({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
          ? Border.all(color: AppColors.primary, width: 1)
          : null,
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          conversation.title,
          style: TextStyle(
            color: isActive ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          '${conversation.messages.length} messages',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: PopupMenuButton(
          color: AppColors.surface,
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Text('Rename', style: TextStyle(color: AppColors.textPrimary)),
              onTap: onRename,
            ),
            PopupMenuItem(
              child: Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
