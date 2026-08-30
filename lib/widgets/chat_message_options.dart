import 'package:flutter/material.dart';
import 'package:vent_ai/themes/app_colors.dart';

class ChatMessageOptionsWidget extends StatelessWidget {
  final String messageContent;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;

  const ChatMessageOptionsWidget({
    required this.messageContent,
    required this.onRegenerate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            icon: Icon(Icons.refresh, size: 16),
            label: Text('Regenerate'),
            onPressed: onRegenerate,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
          SizedBox(width: 8),
          TextButton.icon(
            icon: Icon(Icons.delete_outline, size: 16),
            label: Text('Delete'),
            onPressed: onDelete,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }
}
