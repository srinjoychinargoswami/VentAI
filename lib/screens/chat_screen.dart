import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_storage.dart';
import '../services/ollama_manager.dart';
import '../widgets/empathy_chat_widget.dart';
import '../widgets/mood_selector.dart';
import '../widgets/voice_input_widget.dart';
import '../providers/conversation_provider.dart';
import '../providers/setup_state_provider.dart';
import '../services/ollama_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedMood;
  
  // Voice input state management
  bool _isVoiceMode = false;
  bool _isVoiceProcessing = false;
  late AnimationController _voiceModeController;
  late Animation<double> _voiceModeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Setup voice mode animation
    _voiceModeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _voiceModeAnimation = CurvedAnimation(
      parent: _voiceModeController,
      curve: Curves.easeInOut,
    );
    
    // Load conversations when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Vent AI'),
            Consumer2<ConversationProvider, SetupStateProvider>(
              builder: (context, conversationProvider, setupProvider, child) {
                // Enhanced status display with voice capability
                final isAdvancedAI = setupProvider.hasAdvancedAI;
                final statusText = isAdvancedAI 
                  ? 'AI Ready • Voice Enabled • Privacy Protected' 
                  : 'Offline Mode • Voice Ready • Data Stays Local';
                final statusColor = isAdvancedAI ? Colors.green : Colors.blue;
                
                return Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.normal,
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          // Voice mode toggle button
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isVoiceMode ? Icons.keyboard : Icons.mic,
                key: ValueKey(_isVoiceMode),
                color: _isVoiceMode 
                  ? Theme.of(context).colorScheme.primary
                  : null,
              ),
            ),
            onPressed: _toggleVoiceMode,
            tooltip: _isVoiceMode ? 'Switch to text' : 'Switch to voice',
          ),
          // Clear conversations button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showClearConversationsDialog(),
            tooltip: 'Clear all conversations',
          ),
        ],
      ),
      body: Column(
        children: [
          // Mood selector
          Container(
            padding: const EdgeInsets.all(16),
            child: MoodSelector(
              selectedMood: _selectedMood,
              onMoodSelected: (mood) => setState(() => _selectedMood = mood),
            ),
          ),
          
          // Chat messages
          Expanded(
            child: Consumer<ConversationProvider>(
              builder: (context, provider, child) {
                // Handle empty state and errors
                if (provider.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading conversations...'),
                      ],
                    ),
                  );
                }
                
                if (provider.lastErrorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${provider.lastErrorMessage}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            provider.clearError();
                            provider.refresh();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                
                return EmpathyChatWidget(
                  conversations: provider.conversations,
                  isLoading: provider.isSendingMessage || _isVoiceProcessing,
                  scrollController: _scrollController,
                );
              },
            ),
          ),
          
          // Message input (text or voice)
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Consumer<ConversationProvider>(
      builder: (context, provider, child) {
        final isSending = provider.isSendingMessage || _isVoiceProcessing;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // Progress indicator while sending
              if (isSending) 
                const LinearProgressIndicator(minHeight: 2),
              
              if (isSending) const SizedBox(height: 8),
              
              // Animated container for input mode switching
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isVoiceMode 
                  ? _buildVoiceInput(isSending)
                  : _buildTextInput(isSending),
              ),
            ],
          ),
        );
      },
    );
  }

  // Voice input interface - widget stays enabled during voice recording
  Widget _buildVoiceInput(bool isSending) {
    return Column(
      children: [
        // Voice mode indicator
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Voice Mode - Speak to VentAI',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Voice input widget - always enabled so users can start/stop recording
        VoiceInputWidget(
          enabled: true,
          onVoiceResponse: _handleVoiceResponse,
          onStartRecording: () {
            if (mounted) {
              setState(() {
                _isVoiceProcessing = true;
              });
            }
            debugPrint('Voice recording started in chat screen');
          },
          onStopRecording: () {
            if (mounted) {
              setState(() {
                _isVoiceProcessing = false;
              });
            }
            debugPrint('Voice recording stopped in chat screen');
          },
        ),
        
        const SizedBox(height: 8),
        
        // Enhanced voice instructions
        Text(
          _isVoiceProcessing 
            ? 'Recording... Tap STOP to finish' 
            : isSending 
              ? 'Processing your voice...' 
              : 'Tap the microphone to speak',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: _isVoiceProcessing ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Text input interface
  Widget _buildTextInput(bool isSending) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: isSending 
                ? 'Generating response...' 
                : 'Share what\'s on your mind...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            enabled: !isSending,
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton(
          onPressed: isSending ? null : _sendMessage,
          mini: true,
          child: isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
        ),
      ],
    );
  }

  // Toggle between voice and text input modes
  void _toggleVoiceMode() {
    setState(() {
      _isVoiceMode = !_isVoiceMode;
    });

    if (_isVoiceMode) {
      _voiceModeController.forward();
      // Clear any text input when switching to voice mode
      _messageController.clear();
    } else {
      _voiceModeController.reverse();
    }

    // Show helpful feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isVoiceMode 
            ? 'Voice mode enabled - tap microphone to speak'
            : 'Text mode enabled - type your message',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // CRITICAL FIX: Enhanced voice response handling with forced UI updates
  Future<void> _handleVoiceResponse(String response, String emotion) async {
    debugPrint('_handleVoiceResponse called with: "$response" and emotion: "$emotion"');
    
    final provider = context.read<ConversationProvider>();
    
    // CRITICAL: Check if widget is still mounted before any setState calls
    if (!mounted) {
      debugPrint('Widget not mounted, skipping voice response handling');
      return;
    }
    
    // CRITICAL FIX: Only prevent if provider is actually sending a text message
    if (provider.isSendingMessage) {
      debugPrint('Provider busy with text message, deferring voice response');
      return;
    }

    try {
      debugPrint('Received voice response: $emotion emotion detected');
      debugPrint('AI Response: ${response.substring(0, response.length.clamp(0, 100))}...');

      const voiceTranscript = '[Voice input processed]';
      
      // Add voice input as user message with proper error handling
      try {
        debugPrint('Adding user voice message to conversation...');
        await provider.addMessage(
          message: voiceTranscript,
          isUser: true,
          mood: _selectedMood,
          messageType: 'voice',
          metadata: {
            'emotion_detected': emotion,
            'processing_type': 'voice_emotion_analysis',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        debugPrint('Adding AI response message to conversation...');
        // Add AI response with proper error handling
        await provider.addMessage(
          message: response,
          isUser: false,
          mood: null,
          messageType: 'voice_response',
          metadata: {
            'emotion_responded_to': emotion,
            'voice_aware_response': true,
            'response_source': 'multimodal_fusion',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        debugPrint('Messages added to database successfully');

        //  Enhanced UI update with multiple refresh attempts
        if (mounted) {
          setState(() {
            _selectedMood = null;
            _isVoiceProcessing = false; // Reset voice processing state
          });
          
          //  Force provider to refresh with multiple attempts
          await provider.refresh();
          
          // Add a slight delay to ensure database writes complete
          await Future.delayed(const Duration(milliseconds: 100));
          
          // Force another refresh to ensure UI updates
          await provider.refresh();
          
          // Force widget tree rebuild by updating state again
          if (mounted) {
            setState(() {
              // Dummy state change to force rebuild
            });
          }
          
          debugPrint('UI state updated with enhanced refresh mechanism');
        }

        // Add debug check to verify messages exist
        try {
          final allConversations = provider.conversations;
          debugPrint('Total conversations after voice: ${allConversations.length}');
          if (allConversations.isNotEmpty) {
            final lastConversation = allConversations.last;
            debugPrint('Last message preview: ${lastConversation.aiResponse.substring(0, 50)}...');
          }
        } catch (e) {
          debugPrint('Error checking conversations: $e');
        }

        // Enhanced scroll to bottom for voice messages
        _scrollToBottom();

        // Show enhanced success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Voice processed - $emotion emotion detected',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  _scrollToBottom();
                },
              ),
            ),
          );
        }

        debugPrint('Voice response handling completed successfully!');

      } catch (dbError) {
        debugPrint('Database error while saving voice messages: $dbError');
        
        // Fallback: Still show a basic response even if database save fails
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voice processed but save failed: ${dbError.toString()}'),
              backgroundColor: Colors.orange.shade600,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  // Retry the voice response handling
                  _handleVoiceResponse(response, emotion);
                },
              ),
            ),
          );
        }
      }

    } catch (e) {
      debugPrint('Error handling voice response: $e');
      
      // Enhanced error feedback with recovery options
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice processing encountered an issue',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Error: ${e.toString().length > 50 ? "${e.toString().substring(0, 50)}..." : e.toString()}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Try Again',
              textColor: Colors.white,
              onPressed: () {
                // Reset voice mode to allow retry
                if (mounted) {
                  setState(() {
                    _isVoiceProcessing = false;
                  });
                }
              },
            ),
          ),
        );
      }
    } finally {
      // CRITICAL: Always reset processing state if widget is still mounted
      if (mounted) {
        setState(() {
          _isVoiceProcessing = false;
        });
        debugPrint('Reset _isVoiceProcessing to false');
      }
    }
  }

  // Enhanced message sending with better error handling
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final provider = context.read<ConversationProvider>();
    
    // Prevent multiple simultaneous operations
    if (provider.isSendingMessage || _isVoiceProcessing) return;

    try {
      // Clear input immediately for better UX
      _messageController.clear();
      
      // Send message with enhanced error handling
      await provider.sendMessage(message, mood: _selectedMood);
      
      // Clear mood selection after successful send
      setState(() {
        _selectedMood = null;
      });

      // Enhanced scroll to bottom
      _scrollToBottom();

    } catch (e) {
      debugPrint('Error sending message: $e');
      
      // Restore message if there was an error
      _messageController.text = message;
      
      // Enhanced error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed to send message',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString().length > 60 
                    ? "${e.toString().substring(0, 60)}..."
                    : e.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _sendMessage(),
            ),
          ),
        );
      }
    }
  }

  // Enhanced scroll to bottom method with better reliability
  void _scrollToBottom() {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        try {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        } catch (e) {
          debugPrint('Scroll error: $e');
          // Fallback: Try immediate jump if animation fails
          try {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          } catch (jumpError) {
            debugPrint('Jump scroll also failed: $jumpError');
          }
        }
      }
    });
  }

  /// Enhanced dialog to clear all conversations
  void _showClearConversationsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Clear All Conversations'),
            ],
          ),
          content: const Text(
            'This will permanently delete all your conversations including:\n\n'
            '• Text messages and AI responses\n'
            '• Voice interactions and emotion analysis\n'
            '• Mood selections and conversation history\n\n'
            'This action cannot be undone.\n\n'
            'Are you sure you want to continue?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAllConversations();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  /// Enhanced clear all conversations with better feedback
  Future<void> _clearAllConversations() async {
    try {
      await context.read<ConversationProvider>().clearAllConversations();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('All conversations cleared successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing conversations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Failed to clear conversations',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  e.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _clearAllConversations(),
            ),
          ),
        );
      }
    }
  }

  /// Enhanced conversation statistics with voice analytics
  void _showConversationStats() {
    final provider = context.read<ConversationProvider>();
    final stats = provider.getConversationStats();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.blue),
              SizedBox(width: 8),
              Text('Conversation Analytics'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow('Total conversations', '${stats['total']}'),
                _buildStatRow('Text messages', '${stats['textMessages'] ?? 0}'),
                _buildStatRow('Voice messages', '${stats['voiceMessages'] ?? 0}'),
                _buildStatRow('Most common mood', '${stats['mostCommonMood']}'),
                _buildStatRow('Average message length', '${stats['averageLength']} characters'),
                
                if (stats['crisisConversations'] > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Crisis conversations: ${stats['crisisConversations']}',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                if (stats['emotionsDetected'] != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Voice emotions detected:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: (stats['emotionsDetected'] as List)
                        .map((emotion) => Chip(
                              label: Text(emotion, style: const TextStyle(fontSize: 10)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _voiceModeController.dispose();
    super.dispose();
  }
}
