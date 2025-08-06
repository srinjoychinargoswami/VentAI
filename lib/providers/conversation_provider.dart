// lib/providers/conversation_provider.dart
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../services/offline_storage.dart';
import '../services/ollama_manager.dart';
import '../providers/setup_state_provider.dart';

class ConversationProvider extends ChangeNotifier {
  final AppDatabase _database;
  final SetupStateProvider? _setupStateProvider;

  List<Conversation> _conversations = [];
  bool _isLoading = false;
  bool _isSendingMessage = false;
  String _lastErrorMessage = '';

  ConversationProvider({
    required AppDatabase database, 
    SetupStateProvider? setupStateProvider
  }) : _database = database, _setupStateProvider = setupStateProvider {
    _loadConversations();
  }

  // Getters
  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;
  bool get isOnline => false; // Your app is offline-first
  String get lastErrorMessage => _lastErrorMessage;

  /// Load all conversations from database
  Future<void> _loadConversations() async {
    _isLoading = true;
    _lastErrorMessage = '';
    notifyListeners();

    try {
      // Use proper Drift-generated method based on your schema
      final conversationsQuery = _database.select(_database.conversations);
      _conversations = await conversationsQuery.get();
      
      debugPrint('Loaded ${_conversations.length} conversations');
    } catch (e) {
      debugPrint('Failed to load conversations: $e');
      _lastErrorMessage = 'Failed to load conversations: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ENHANCED: Send user message and get AI response with service health checks
  Future<void> sendMessage(String userMessage, {String? mood}) async {
    if (userMessage.trim().isEmpty) return;

    _isSendingMessage = true;
    _lastErrorMessage = '';
    notifyListeners();

    try {
      // Generate AI response with service health checks
      Map<String, dynamic> aiResponseData;

      // Check if we have advanced AI setup
      final setupProvider = _setupStateProvider;
      final hasAdvancedAI = setupProvider?.hasAdvancedAI ?? false;

      if (hasAdvancedAI && OllamaManager.isInitialized) {
        // ADDED: Ensure Ollama service is running before making API calls
        debugPrint('Checking Ollama service status...');
        final serviceReady = await OllamaManager.ensureServiceRunning();
        
        if (serviceReady) {
          // Service is healthy, use Ollama for advanced AI responses
          debugPrint('Ollama service ready - using advanced AI');
          aiResponseData = await OllamaManager.generateEmpatheticResponse(
            userMessage, 
            model: null  // Let it choose the best model
          );
        } else {
          // Service failed health check, use intelligent fallback
          debugPrint('Ollama service not ready - using intelligent fallback');
          aiResponseData = await _generateFallbackResponse(userMessage, mood);
        }
      } else {
        // No advanced AI available, use intelligent fallback responses
        debugPrint('Using intelligent fallback response (no advanced AI)');
        aiResponseData = await _generateFallbackResponse(userMessage, mood);
      }

      final aiResponse = aiResponseData['response'] as String? ?? 'I\'m here to listen. Could you tell me more?';

      // Insert conversation with both user message and AI response
      await _database.into(_database.conversations).insert(
        ConversationsCompanion.insert(
          userMessage: userMessage.trim(),
          aiResponse: aiResponse,
          timestamp: DateTime.now(),
          emotionalState: Value(mood),
        )
      );

      await _loadConversations();
      debugPrint('Message sent and response generated');

    } catch (e) {
      debugPrint('Failed to send message: $e');
      _lastErrorMessage = 'Failed to send message: $e';
      
      // ADDED: Emergency fallback if everything fails
      try {
        await _database.into(_database.conversations).insert(
          ConversationsCompanion.insert(
            userMessage: userMessage.trim(),
            aiResponse: 'I\'m experiencing technical difficulties right now, but I want you to know that your feelings are valid and important. Please try again in a moment.',
            timestamp: DateTime.now(),
            emotionalState: Value(mood),
          )
        );
        await _loadConversations();
        debugPrint('Emergency response saved');
      } catch (emergencyError) {
        debugPrint('Emergency fallback also failed: $emergencyError');
      }
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Generate fallback response when Ollama is not available
  Future<Map<String, dynamic>> _generateFallbackResponse(String message, String? mood) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate processing time
    
    final lowered = message.toLowerCase();
    String response;
    bool crisisDetected = false;

    // Crisis detection - highest priority
    if (_detectCrisis(message)) {
      crisisDetected = true;
      response = '''I'm really concerned about you right now. Please reach out for help immediately:

• Call 988 Suicide Crisis Lifeline - 24/7 support
• Text HOME to 741741 Crisis Text Line  
• Call 911 for emergency assistance

Your life has value, and there are people who want to help you through this.''';
    }
    // Emotion-specific responses
    else if (lowered.contains('anxious') || lowered.contains('anxiety') || lowered.contains('worried')) {
      response = '''I can sense you're feeling anxious right now. That's a really difficult experience, and your feelings are completely valid. Try taking slow, deep breaths - in for 4 counts, hold for 4, out for 4.

What has been weighing on your mind lately?''';
    }
    else if (lowered.contains('sad') || lowered.contains('depressed') || lowered.contains('down')) {
      response = '''I hear that you're going through a tough time, and I want you to know that your feelings are completely valid. It takes courage to reach out when you're feeling this way.

What has been the hardest part for you today?''';
    }
    else if (lowered.contains('lonely') || lowered.contains('alone')) {
      response = '''Feeling lonely can be so isolating and painful. I'm here with you right now, and you're not alone in this moment.

Is there someone in your life you feel comfortable reaching out to?''';
    }
    else if (lowered.contains('stressed') || lowered.contains('overwhelmed')) {
      response = '''It sounds like you're carrying a heavy load right now. When everything feels overwhelming, it can help to break things down into smaller, manageable pieces. 

What's the one thing you could focus on right now that would make the biggest difference?''';
    }
    else if (lowered.contains('angry') || lowered.contains('frustrated')) {
      response = '''I can hear the frustration in your words, and that's completely understandable. Your feelings are valid, and it's okay to feel angry sometimes.

What's been the most frustrating part of your situation?''';
    }
    // General supportive response
    else {
      response = '''Thank you for sharing with me. I can hear that you're going through something difficult, and I want you to know that your feelings are valid and important.

This is a safe space where you can express yourself freely. What would feel most helpful for you right now?''';
    }

    return {
      'response': response,
      'source': 'intelligent_fallback',
      'crisisDetected': crisisDetected,
      'mood': mood ?? 'neutral',
    };
  }

  /// Detect crisis keywords
  bool _detectCrisis(String message) {
    final lowered = message.toLowerCase();
    final crisisWords = [
      'suicide', 'kill myself', 'end it all', 'want to die', 
      'harm myself', 'hurt myself', 'can\'t go on', 'no point living',
      'better off dead', 'no reason to live', 'want to disappear'
    ];
    return crisisWords.any((word) => lowered.contains(word));
  }

  /// Delete a conversation
  Future<void> deleteConversation(int conversationId) async {
    try {
      await (_database.delete(_database.conversations)
        ..where((c) => c.id.equals(conversationId))).go();

      await _loadConversations();
      debugPrint('Deleted conversation: $conversationId');
    } catch (e) {
      debugPrint('Failed to delete conversation: $e');
      _lastErrorMessage = 'Failed to delete conversation: $e';
      notifyListeners();
    }
  }

  /// Clear all conversations
  Future<void> clearAllConversations() async {
    try {
      await _database.delete(_database.conversations).go();
      _conversations.clear();
      debugPrint('Cleared all conversations');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to clear conversations: $e');
      _lastErrorMessage = 'Failed to clear conversations: $e';
      notifyListeners();
    }
  }

  /// Refresh conversations from database
  Future<void> refresh() async {
    await _loadConversations();
  }

  /// Get conversation by ID
  Conversation? getConversationById(int conversationId) {
    try {
      return _conversations.firstWhere((conv) => conv.id == conversationId);
    } catch (e) {
      return null;
    }
  }

  /// Get the most recent conversation
  Conversation? get mostRecentConversation {
    if (_conversations.isEmpty) return null;
    
    // Sort by timestamp (most recent first)
    _conversations.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _conversations.first;
  }

  /// Search conversations by user message or AI response
  List<Conversation> searchConversations(String query) {
    if (query.trim().isEmpty) return _conversations;
    
    final lowercaseQuery = query.toLowerCase();
    return _conversations.where((conv) => 
      conv.userMessage.toLowerCase().contains(lowercaseQuery) ||
      conv.aiResponse.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }

  /// Get conversations by emotional state
  List<Conversation> getConversationsByMood(String mood) {
    return _conversations.where((conv) => 
      conv.emotionalState?.toLowerCase() == mood.toLowerCase()
    ).toList();
  }

  /// Get conversation statistics
  Map<String, dynamic> getConversationStats() {
    if (_conversations.isEmpty) {
      return {
        'total': 0,
        'mostCommonMood': 'none',
        'averageLength': 0,
        'crisisConversations': 0,
      };
    }

    final moodCounts = <String, int>{};
    int totalUserMessageLength = 0;
    int crisisCount = 0;

    for (final conv in _conversations) {
      // Count moods
      final mood = conv.emotionalState ?? 'neutral';
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      
      // Calculate average message length
      totalUserMessageLength += conv.userMessage.length;
      
      // Count crisis conversations
      if (_detectCrisis(conv.userMessage)) {
        crisisCount++;
      }
    }

    // Find most common mood
    String mostCommonMood = 'neutral';
    int maxCount = 0;
    moodCounts.forEach((mood, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonMood = mood;
      }
    });

    return {
      'total': _conversations.length,
      'mostCommonMood': mostCommonMood,
      'averageLength': totalUserMessageLength ~/ _conversations.length,
      'crisisConversations': crisisCount,
      'moodDistribution': moodCounts,
    };
  }

  /// Clear error message
  void clearError() {
    _lastErrorMessage = '';
    notifyListeners();
  }

  /// Export conversations as text (for backup/analysis)
  String exportConversationsAsText() {
    if (_conversations.isEmpty) return 'No conversations to export.';

    final buffer = StringBuffer();
    buffer.writeln('Vent AI Conversation Export');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total Conversations: ${_conversations.length}');
    buffer.writeln('${'=' * 50}');

    for (int i = 0; i < _conversations.length; i++) {
      final conv = _conversations[i];
      buffer.writeln('\nConversation ${i + 1}');
      buffer.writeln('Date: ${conv.timestamp.toIso8601String()}');
      if (conv.emotionalState != null) {
        buffer.writeln('Mood: ${conv.emotionalState}');
      }
      buffer.writeln('\nUser: ${conv.userMessage}');
      buffer.writeln('\nAI: ${conv.aiResponse}');
      buffer.writeln('-' * 30);
    }

    return buffer.toString();
  }

  /// Dispose resources
  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}
