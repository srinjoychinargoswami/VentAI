import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class PrivateMessage extends StatefulWidget {
  final Widget child;
  final bool isPrivacy;
  final String? tooltip;

  const PrivateMessage({
    required this.child,
    required this.isPrivacy,
    this.tooltip,
  });

  @override
  State<PrivateMessage> createState() => _PrivateMessageState();
}

class _PrivateMessageState extends State<PrivateMessage> {
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (widget.isPrivacy) {
          setState(() => _isRevealed = true);
        }
      },
      onExit: (_) {
        if (widget.isPrivacy) {
          setState(() => _isRevealed = false);
        }
      },
      child: Tooltip(
        message: widget.isPrivacy && !_isRevealed ? "Hover to reveal" : "",
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: widget.isPrivacy && !_isRevealed ? 0.5 : 1.0,
          child: widget.isPrivacy && !_isRevealed
              ? ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: IgnorePointer(
                    child: widget.child,
                  ),
                )
              : widget.child,
        ),
      ),
    );
  }
}
