import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vent_ai/themes/app_colors.dart';
import 'chat_message_options.dart';
import 'private_message.dart';
import '../utils/platform_utils.dart';

class ChatMessageWidget extends StatefulWidget {
  final String content;
  final bool isUserMessage;
  final VoidCallback onRegenerate;
  final VoidCallback onDelete;
  final bool isPrivacyMode;

  const ChatMessageWidget({
    required this.content,
    required this.isUserMessage,
    required this.onRegenerate,
    required this.onDelete,
    this.isPrivacyMode = false,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  bool _showOptions = false;


  @override
  Widget build(BuildContext context) {
    // Mobile: single tap shows options, long press is reserved for privacy reveal
    // Desktop: long press shows options
    return GestureDetector(
      onTap:
          isMobileOS() ? () => setState(() => _showOptions = !_showOptions) : null,
      onLongPress:
          isMobileOS() ? null : () => setState(() => _showOptions = !_showOptions),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: isMobilePhone(context) ? 8 : 12, horizontal: isMobilePhone(context) ? 12 : 16),
        child: Row(
          mainAxisAlignment: widget.isUserMessage
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isUserMessage)
              Padding(
                padding: EdgeInsets.only(right: isMobilePhone(context) ? 8 : 12, top: 4),
                child: CircleAvatar(
                  radius: isMobilePhone(context) ? 16 : 20,
                  backgroundColor: AppColors.surface,
                  child: Icon(
                    Icons.lightbulb,
                    color: AppColors.primary,
                    size: isMobilePhone(context) ? 18 : 24,
                  ),
                ),
              ),
            Flexible(
              // Cap bubble width: 90% of the screen on phones, 600pt max on iPad.
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      math.min(600.0, MediaQuery.sizeOf(context).width * 0.9),
                ),
                child: Column(
                  crossAxisAlignment: widget.isUserMessage
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    PrivateMessage(
                      isPrivacy: widget.isPrivacyMode,
                      itemId:
                          'msg-${widget.content.hashCode}', // Unique ID based on content hash
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobilePhone(context) ? 12 : 16,
                          vertical: isMobilePhone(context) ? 8 : 12,
                        ),
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
                            fontSize: isMobilePhone(context) ? 14 : 16,
                            height: isMobilePhone(context) ? 1.3 : 1.5,
                          ),
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
