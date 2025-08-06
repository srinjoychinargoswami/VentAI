// lib/widgets/empathy_chat_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/offline_storage.dart';

class EmpathyChatWidget extends StatelessWidget {
  final List<Conversation> conversations;
  final bool isLoading;
  final ScrollController scrollController;

  const EmpathyChatWidget({
    super.key,
    required this.conversations,
    required this.isLoading,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty && !isLoading) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: conversations.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == conversations.length) {
          return _buildLoadingIndicator(context);
        }

        final conversation = conversations[index];
        return Column(
          children: [
            _buildUserMessage(context, conversation),
            const SizedBox(height: 8),
            _buildAiResponse(context, conversation),
            const SizedBox(height: 24), // FIXED: Better spacing
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.psychology,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Vent AI',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'I\'m here to listen and support you.\nShare what\'s on your mind, and I\'ll respond with empathy and understanding.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.security,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your conversations stay private and secure',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context, Conversation conversation) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // FIXED: Added mood indicator
            if (conversation.emotionalState != null && conversation.emotionalState!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getMoodColor(conversation.emotionalState!).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getMoodEmoji(conversation.emotionalState!),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      conversation.emotionalState!,
                      style: TextStyle(
                        fontSize: 10,
                        color: _getMoodColor(conversation.emotionalState!),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // User message bubble
            GestureDetector(
              onLongPress: () => _showMessageOptions(context, conversation.userMessage, true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  conversation.userMessage,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Text(
                _formatTimestamp(conversation.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiResponse(BuildContext context, Conversation conversation) {
    //Detect crisis from message content instead of assuming field exists
    final containsCrisisKeywords = _detectCrisisKeywords(conversation.userMessage);
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(right: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI response bubble
            GestureDetector(
              onLongPress: () => _showMessageOptions(context, conversation.aiResponse, false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: containsCrisisKeywords ? Border.all(
                    color: Colors.red.shade300,
                    width: 2,
                  ) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FIXED: Crisis warning indicator
                    if (containsCrisisKeywords) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning,
                              size: 14,
                              color: Colors.red.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Crisis support response',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    Text(
                      conversation.aiResponse,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Response metadata
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FIXED: Better offline indicator based on response content
                  Icon(
                    _getResponseIcon(conversation.aiResponse),
                    size: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getResponseSourceText(conversation.aiResponse),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimestamp(conversation.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Enhanced loading indicator with typing animation
  Widget _buildLoadingIndicator(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 20,
              child: LinearProgressIndicator(
                backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Helper methods for enhanced functionality

  /// Get mood color based on emotional state
  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
      case 'joyful':
      case 'excited':
        return Colors.green;
      case 'sad':
      case 'depressed':
      case 'down':
        return Colors.blue;
      case 'angry':
      case 'frustrated':
      case 'annoyed':
        return Colors.red;
      case 'anxious':
      case 'worried':
      case 'nervous':
        return Colors.orange;
      case 'calm':
      case 'peaceful':
      case 'relaxed':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  /// Get mood emoji based on emotional state
  String _getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy':
      case 'joyful':
      case 'excited':
        return '😊';
      case 'sad':
      case 'depressed':
      case 'down':
        return '😢';
      case 'angry':
      case 'frustrated':
      case 'annoyed':
        return '😠';
      case 'anxious':
      case 'worried':
      case 'nervous':
        return '😰';
      case 'calm':
      case 'peaceful':
      case 'relaxed':
        return '😌';
      case 'lonely':
        return '😔';
      case 'stressed':
        return '😫';
      default:
        return '💭';
    }
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  /// Detect crisis keywords in user message
  bool _detectCrisisKeywords(String message) {
    final lowered = message.toLowerCase();
    final crisisWords = [
      'suicide', 'kill myself', 'end it all', 'want to die', 
      'harm myself', 'hurt myself', 'can\'t go on', 'no point living',
      'better off dead', 'no reason to live', 'want to disappear'
    ];
    return crisisWords.any((word) => lowered.contains(word));
  }

  /// Get response icon based on content analysis
  IconData _getResponseIcon(String response) {
    if (response.contains('988') || response.contains('Crisis')) {
      return Icons.emergency;
    } else if (response.length > 200) {
      return Icons.smart_toy; // Likely AI generated
    } else {
      return Icons.offline_bolt; // Likely fallback
    }
  }

  /// Get response source text
  String _getResponseSourceText(String response) {
    if (response.contains('988') || response.contains('Crisis')) {
      return 'Crisis support';
    } else if (response.length > 200) {
      return 'AI response';
    } else {
      return 'Offline response';
    }
  }

  /// Show message options dialog
  void _showMessageOptions(BuildContext context, String message, bool isUserMessage) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy message'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied to clipboard')),
                  );
                },
              ),
              if (!isUserMessage) ...[
                ListTile(
                  leading: const Icon(Icons.thumb_up_outlined),
                  title: const Text('Helpful response'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thank you for your feedback')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.thumb_down_outlined),
                  title: const Text('Could be better'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feedback noted. We\'re always improving.')),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
