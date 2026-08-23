import 'package:flutter/material.dart';
import 'package:vent_ai/themes/app_colors.dart';
import 'chat_message_options.dart';

class ChatMessageWidget extends StatefulWidget {
  final String content;
  final bool isUserMessage;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;

  const ChatMessageWidget({
    required this.content,
    required this.isUserMessage,
    required this.onRegenerate,
    required this.onDelete,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  bool _showOptions = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => setState(() => _showOptions = !_showOptions),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: widget.isUserMessage
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isUserMessage)
              Padding(
                padding: EdgeInsets.only(right: 12, top: 4),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surface,
                  child: Icon(
                    Icons.lightbulb,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            Flexible(
              child: Column(
                crossAxisAlignment: widget.isUserMessage
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: widget.isUserMessage
                          ? AppColors.userMessage
                          : AppColors.aiMessage,
                      borderRadius: widget.isUserMessage
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                              bottomRight: Radius.circular(0),
                              bottomLeft: Radius.circular(24),
                            )
                          : const BorderRadius.only(
                              topLeft: Radius.circular(0),
                              topRight: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                              bottomLeft: Radius.circular(24),
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.overlay.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.content,
                      style: TextStyle(
                        color: widget.isUserMessage
                            ? AppColors.textPrimary
                            : AppColors.aiText,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (_showOptions && !widget.isUserMessage)
                    ChatMessageOptionsWidget(
                      messageContent: widget.content,
                      onRegenerate: widget.onRegenerate,
                      onDelete: widget.onDelete,
                    ),
                ],
              ),
            ),
            if (widget.isUserMessage)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.userMessage,
                  child: const Icon(
                    Icons.person,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
