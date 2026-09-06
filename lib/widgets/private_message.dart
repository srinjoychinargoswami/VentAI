import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../providers/conversation_provider.dart';

class PrivateMessage extends StatelessWidget {
  final Widget child;
  final bool isPrivacy;
  final String? tooltip;
  final String? itemId;  // Unique ID for this private message (message ID, conversation ID, "title", etc.)

  const PrivateMessage({
    required this.child,
    required this.isPrivacy,
    this.tooltip,
    this.itemId,
  });

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    // Desktop: hover behavior (no provider state needed for hover)
    if (!_isMobile) {
      return MouseRegion(
        onEnter: (_) {
          if (!isPrivacy || itemId == null) return;
          context.read<ConversationProvider>().togglePrivacyItemReveal(itemId!);
        },
        onExit: (_) {
          if (!isPrivacy || itemId == null) return;
          // On desktop, exiting hover should hide the item
          if (context.read<ConversationProvider>().revealedPrivacyItemId == itemId) {
            context.read<ConversationProvider>().togglePrivacyItemReveal(itemId!);
          }
        },
        child: Consumer<ConversationProvider>(
          builder: (context, provider, _) {
            final isRevealed = itemId != null && provider.revealedPrivacyItemId == itemId;
            return Tooltip(
              message: isPrivacy && !isRevealed ? "Hover to reveal" : "",
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isPrivacy && !isRevealed ? 0.5 : 1.0,
                child: isPrivacy && !isRevealed
                    ? ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: IgnorePointer(
                          child: child,
                        ),
                      )
                    : child,
              ),
            );
          },
        ),
      );
    }

    // Mobile: tap-to-view behavior
    return Consumer<ConversationProvider>(
      builder: (context, provider, _) {
        final isRevealed = itemId != null && provider.revealedPrivacyItemId == itemId;
        return GestureDetector(
          onTap: () {
            if (!isPrivacy || itemId == null) return;
            provider.togglePrivacyItemReveal(itemId!);
          },
          child: Tooltip(
            message: isPrivacy && !isRevealed ? "Tap to reveal" : "",
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isPrivacy && !isRevealed ? 0.5 : 1.0,
              child: isPrivacy && !isRevealed
                  ? ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: IgnorePointer(
                        child: child,
                      ),
                    )
                  : child,
            ),
          ),
        );
      },
    );
  }
}
