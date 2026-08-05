import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vent_ai/themes/app_colors.dart';

class ChatMessageOptionsWidget extends StatefulWidget {
  final String messageContent;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;

  const ChatMessageOptionsWidget({
    required this.messageContent,
    required this.onRegenerate,
    required this.onDelete,
  });

  @override
  State<ChatMessageOptionsWidget> createState() =>
      _ChatMessageOptionsWidgetState();
}

class _ChatMessageOptionsWidgetState extends State<ChatMessageOptionsWidget> {
  bool _copied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.messageContent));
    setState(() => _copied = true);
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            icon: Icon(_copied ? Icons.check : Icons.content_copy, size: 16),
            label: Text(_copied ? 'Copied' : 'Copy'),
            onPressed: _copyToClipboard,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle:
                  TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 8),
          TextButton.icon(
            icon: Icon(Icons.refresh, size: 16),
            label: Text('Regenerate'),
            onPressed: widget.onRegenerate,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
          SizedBox(width: 8),
          TextButton.icon(
            icon: Icon(Icons.delete_outline, size: 16),
            label: Text('Delete'),
            onPressed: widget.onDelete,
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
