import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../services/offline_storage.dart';
import '../services/ollama_manager.dart';
import '../services/gemma_service.dart';
import '../services/emotional_ai_service.dart';
import '../providers/setup_state_provider.dart';

class ConversationProvider extends ChangeNotifier {
  final AppDatabase _database;
  final SetupStateProvider? _setupStateProvider;

  List<Conversation> _conversations = [];
  bool _isLoading = false;
  bool _isSendingMessage = false;
  String _lastErrorMessage = '';

  // Conversation context tracking
  final List<String> _recentMessages = [];
  final List<String> _recentResponses = [];
  final int _maxContextMessages = 3;
  String? _currentSessionId;

  // Platform detection
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  ConversationProvider({
    required AppDatabase database, 
    SetupStateProvider? setupStateProvider
  }) : _database = database, _setupStateProvider = setupStateProvider {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _loadConversations();
  }

  // Getters
  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  bool get isSendingMessage => _isSendingMessage;
  bool get isOnline => false;
  String get lastErrorMessage => _lastErrorMessage;
  String get currentSessionId => _currentSessionId ?? '';
  List<String> get recentMessages => List.unmodifiable(_recentMessages);
  List<String> get recentResponses => List.unmodifiable(_recentResponses);

  /// Load conversations
  Future<void> _loadConversations() async {
    _isLoading = true;
    _lastErrorMessage = '';
    notifyListeners();

    try {
      final conversationsQuery = _database.select(_database.conversations)
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)])
        ..limit(100);
      _conversations = await conversationsQuery.get();
      
      _rebuildContextFromConversations();
      
      debugPrint('Loaded ${_conversations.length} conversations');
    } catch (e) {
      debugPrint('Failed to load conversations: $e');
      _lastErrorMessage = 'Failed to load conversations: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add message
  Future<void> addMessage({
    required String message,
    required bool isUser,
    String? mood,
    String? messageType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final now = DateTime.now();
      
      debugPrint('Adding ${isUser ? 'user' : 'AI'} message...');

      if (isUser) {
        await _database.into(_database.conversations).insert(
          ConversationsCompanion(
            userMessage: Value(message),
            aiResponse: const Value(''),
            timestamp: Value(now),
            emotionalState: Value(mood),
            isOffline: const Value(true),
            sessionId: Value(_currentSessionId),
          )
        );
      } else {
        await _database.into(_database.conversations).insert(
          ConversationsCompanion(
            userMessage: const Value('[Message processed]'),
            aiResponse: Value(message),
            timestamp: Value(now),
            emotionalState: Value(mood),
            isOffline: const Value(true),
            sessionId: Value(_currentSessionId),
          )
        );
      }

      if (isUser) {
        _addToContext(message, '');
      } else {
        _addToContext('', message);
      }

      await _forceRefreshAndNotify();
      
      debugPrint('Added message');
    } catch (e) {
      debugPrint('Failed to add message: $e');
      _lastErrorMessage = 'Failed to add message: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Force refresh
  Future<void> _forceRefreshAndNotify() async {
    try {
      await _loadConversations();
      await Future.delayed(const Duration(milliseconds: 100));
      await _loadConversations();
      notifyListeners();
      
      debugPrint('Force refresh completed');
    } catch (e) {
      debugPrint('Force refresh failed: $e');
      notifyListeners();
    }
  }

  /// Refresh conversations
  Future<void> refresh() async {
    await _forceRefreshAndNotify();
  }

  /// Send message and get AI response
  Future<void> sendMessage(String userMessage, {String? mood}) async {
    if (userMessage.trim().isEmpty) return;

    _isSendingMessage = true;
    _lastErrorMessage = '';
    notifyListeners();

    try {
      // Prepare enhanced message with context
      String enhancedMessage = userMessage;
      if (_isContinuingConversation(userMessage)) {
        final context = _getConversationContext();
        if (context.isNotEmpty) {
          enhancedMessage = '$context\n\nUser: $userMessage';
          debugPrint('Adding conversation context');
        }
      }

      // Platform-specific AI routing
      Map<String, dynamic> aiResponseData;
      final setupProvider = _setupStateProvider;
      final hasAdvancedAI = setupProvider?.hasAdvancedAI ?? false;

      if (_isMobile) {
        // MOBILE: Use Gemma via EmotionalAIService
        debugPrint('📱 Using mobile Gemma AI');
        aiResponseData = await _generateMobileAIResponse(enhancedMessage, mood);
        
      } else if (_isDesktop) {
        // DESKTOP: Use OllamaManager
        if (hasAdvancedAI && OllamaManager.isInitialized) {
          debugPrint('🖥️ Checking Ollama service...');
          final serviceReady = await OllamaManager.ensureServiceRunning();
          
          if (serviceReady) {
            debugPrint('Using Ollama');
            aiResponseData = await OllamaManager.generateEmpatheticResponse(
              enhancedMessage, 
              model: null
            );
          } else {
            debugPrint('Ollama not ready - fallback');
            aiResponseData = await _generateFallbackResponse(userMessage, mood);
          }
        } else {
          debugPrint('Using desktop fallback');
          aiResponseData = await _generateFallbackResponse(userMessage, mood);
        }
        
      } else {
        // Unknown platform - use fallback
        aiResponseData = await _generateFallbackResponse(userMessage, mood);
      }

      final aiResponse = aiResponseData['response'] as String? ?? 
          'I\'m here to listen. Could you tell me more?';

      // Add to context
      _addToContext(userMessage, aiResponse);

      // Insert conversation
      await _database.into(_database.conversations).insert(
        ConversationsCompanion.insert(
          userMessage: userMessage.trim(),
          aiResponse: aiResponse,
          timestamp: DateTime.now(),
          emotionalState: Value(mood),
          isOffline: const Value(true),
          sessionId: Value(_currentSessionId),
        )
      );

      await _forceRefreshAndNotify();
      
      debugPrint('Message sent and response generated');

    } catch (e) {
      debugPrint('Failed to send message: $e');
      _lastErrorMessage = 'Failed to send message: $e';
      
      // Emergency fallback
      try {
        const fallbackResponse = 'I\'m experiencing technical difficulties right now, but I want you to know that your feelings are valid and important. Please try again in a moment.';
        
        _addToContext(userMessage, fallbackResponse);
        
        await _database.into(_database.conversations).insert(
          ConversationsCompanion.insert(
            userMessage: userMessage.trim(),
            aiResponse: fallbackResponse,
            timestamp: DateTime.now(),
            emotionalState: Value(mood),
            isOffline: const Value(true),
            sessionId: Value(_currentSessionId),
          )
        );
        
        await _forceRefreshAndNotify();
        debugPrint('Emergency response saved');
      } catch (emergencyError) {
        debugPrint('Emergency fallback failed: $emergencyError');
      }
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Generate mobile AI response using EmotionalAIService
  Future<Map<String, dynamic>> _generateMobileAIResponse(String message, String? mood) async {
    try {
      debugPrint('📱 Generating mobile AI response...');
      
      // Use EmotionalAIService (routes to GemmaService on mobile)
      final aiService = EmotionalAIService();
      final response = await aiService.generateEmpatheticResponse(message);
      
      if (response['response'] != null && (response['response'] as String).isNotEmpty) {
        debugPrint('📱 Mobile AI response generated successfully');
        return response;
      } else {
        debugPrint('📱 Mobile AI returned empty - using fallback');
        return await _generateFallbackResponse(message, mood);
      }
      
    } catch (e) {
      debugPrint('📱 Mobile AI generation failed: $e');
      return await _generateFallbackResponse(message, mood);
    }
  }

  // Context management
  void _addToContext(String userMessage, String aiResponse) {
    if (userMessage.isNotEmpty) {
      _recentMessages.add(userMessage);
    }
    if (aiResponse.isNotEmpty) {
      _recentResponses.add(aiResponse);
    }

    if (_recentMessages.length > _maxContextMessages) {
      _recentMessages.removeAt(0);
    }
    if (_recentResponses.length > _maxContextMessages) {
      _recentResponses.removeAt(0);
    }
  }

  String _getConversationContext() {
    if (_recentMessages.isEmpty) return '';
    
    final contextPairs = <String>[];
    for (int i = 0; i < _recentMessages.length && i < _recentResponses.length; i++) {
      contextPairs.add('User: ${_recentMessages[i]}');
      contextPairs.add('AI: ${_recentResponses[i]}');
    }
    return 'Recent conversation context:\n${contextPairs.join('\n')}';
  }

  bool _isContinuingConversation(String message) {
    if (_recentMessages.isEmpty) return false;
    
    final messageLower = message.toLowerCase();
    final continuationPhrases = [
      'also', 'and', 'but', 'however', 'speaking of that', 
      'on that topic', 'related to that', 'similarly', 
      'can you tell me more', 'what about', 'how about'
    ];
    
    return continuationPhrases.any((phrase) => messageLower.contains(phrase));
  }

  void _rebuildContextFromConversations() {
    _recentMessages.clear();
    _recentResponses.clear();
    
    final recentConversations = _conversations.take(_maxContextMessages).toList();
    for (final conversation in recentConversations.reversed) {
      _recentMessages.add(conversation.userMessage);
      _recentResponses.add(conversation.aiResponse);
    }
  }

  // Fallback response generation
  Future<Map<String, dynamic>> _generateFallbackResponse(String message, String? mood) async {
    await Future.delayed(const Duration(seconds: 1));
    
    final lowered = message.toLowerCase();
    String response;
    bool crisisDetected = false;

    // Crisis detection
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
      response = '''I can sense you're feeling anxious right now. That's a really difficult experience, and your feelings are completely valid. Let's focus on the present moment together.

Try this breathing technique with me: breathe in slowly for 4 counts, hold for 4 counts, breathe out for 6 counts. This activates your body's natural calm response.

Anxiety often comes with "what if" thoughts. Right now, what's one thing you know for certain that's safe or stable in this moment?''';
    }
    else if (lowered.contains('sad') || lowered.contains('depressed') || lowered.contains('down')) {
      response = '''I hear that you're going through a tough time, and I want you to know that your feelings are completely valid. It takes courage to reach out when you're feeling this way.

Sadness can feel heavy and overwhelming. Sometimes it helps to remember that emotions, even difficult ones, are temporary visitors.

What has been the hardest part for you today? Is there something specific that's contributing to these feelings?''';
    }
    else {
      response = '''Thank you for sharing with me. I can hear that you're going through something, and I want you to know that your feelings are valid and important.

This is a safe space where you can express yourself freely. There's no judgment here, only support and understanding.

What would feel most helpful for you right now?''';
    }

    return {
      'response': response,
      'source': 'intelligent_fallback',
      'crisisDetected': crisisDetected,
      'mood': mood ?? 'neutral',
    };
  }

  bool _detectCrisis(String message) {
    final lowered = message.toLowerCase();
    final crisisWords = [
      'suicide', 'suicidal', 'kill myself', 'end it all', 'want to die', 
      'harm myself', 'hurt myself', 'can\'t go on', 'cannot go on',
      'no point living', 'better off dead', 'no reason to live'
    ];
    return crisisWords.any((word) => lowered.contains(word));
  }

  // Utility methods
  Future<void> deleteConversation(int conversationId) async {
    try {
      await (_database.delete(_database.conversations)
        ..where((c) => c.id.equals(conversationId))).go();
      await _forceRefreshAndNotify();
      debugPrint('Deleted conversation: $conversationId');
    } catch (e) {
      debugPrint('Failed to delete conversation: $e');
      _lastErrorMessage = 'Failed to delete conversation: $e';
      notifyListeners();
    }
  }

  Future<void> clearAllConversations() async {
    try {
      await _database.delete(_database.conversations).go();
      _conversations.clear();
      _recentMessages.clear();
      _recentResponses.clear();
      debugPrint('Cleared all conversations');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to clear conversations: $e');
      _lastErrorMessage = 'Failed to clear conversations: $e';
      notifyListeners();
    }
  }

  void startNewSession() {
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _recentMessages.clear();
    _recentResponses.clear();
    debugPrint('Started new session: $_currentSessionId');
    notifyListeners();
  }

  Conversation? getConversationById(int conversationId) {
    try {
      return _conversations.firstWhere((conv) => conv.id == conversationId);
    } catch (e) {
      return null;
    }
  }

  Conversation? get mostRecentConversation {
    if (_conversations.isEmpty) return null;
    return _conversations.last;
  }

  List<Conversation> searchConversations(String query) {
    if (query.trim().isEmpty) return _conversations;
    
    final lowercaseQuery = query.toLowerCase();
    return _conversations.where((conv) => 
      conv.userMessage.toLowerCase().contains(lowercaseQuery) ||
      conv.aiResponse.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }

  Map<String, dynamic> getConversationStats() {
    if (_conversations.isEmpty) {
      return {
        'total': 0,
        'textMessages': 0,
        'mostCommonMood': 'none',
        'averageLength': 0,
        'crisisConversations': 0,
      };
    }

    final moodCounts = <String, int>{};
    int totalUserMessageLength = 0;
    int crisisCount = 0;
    int textMessages = 0;

    for (final conv in _conversations) {
      final mood = conv.emotionalState ?? 'neutral';
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      
      totalUserMessageLength += conv.userMessage.length;
      
      if (_detectCrisis(conv.userMessage)) {
        crisisCount++;
      }
      
      textMessages++;
    }

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
      'textMessages': textMessages,
      'mostCommonMood': mostCommonMood,
      'averageLength': totalUserMessageLength ~/ _conversations.length,
      'crisisConversations': crisisCount,
    };
  }

  void clearError() {
    _lastErrorMessage = '';
    notifyListeners();
  }

  @override
  void notifyListeners() {
    debugPrint('ConversationProvider: Notifying (${_conversations.length} conversations)');
    super.notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}