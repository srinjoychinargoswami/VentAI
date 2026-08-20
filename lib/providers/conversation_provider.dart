import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/hive_database.dart';
import '../services/gemma_service.dart';
import '../providers/setup_state_provider.dart';
import '../models/conversation_model.dart';

class ConversationProvider extends ChangeNotifier {
  final SetupStateProvider? _setupStateProvider;

  List<Conversation> _conversations = [];
  bool _isLoading = false;
  bool _isSendingMessage = false;
  String _lastErrorMessage = '';

  // Multi-conversation management
  List<Conversation> _conversationSessions = [];
  String? _activeConversationId;

  // Conversation context tracking
  final List<String> _recentMessages = [];
  final List<String> _recentResponses = [];
  final int _maxContextMessages = 3;
  String? _currentSessionId;

  // Platform detection
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  ConversationProvider({
    SetupStateProvider? setupStateProvider
  }) : _setupStateProvider = setupStateProvider {
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

  // Multi-conversation getters
  List<Conversation> get conversationSessions => _conversationSessions;
  String? get activeConversationId => _activeConversationId;

  Conversation? get activeConversation =>
    _activeConversationId != null
      ? _conversationSessions.firstWhere(
          (c) => c.id == _activeConversationId,
          orElse: () => _conversationSessions.first,
        )
      : null;

  /// Load conversations
  Future<void> _loadConversations() async {
    _isLoading = true;
    _lastErrorMessage = '';
    notifyListeners();

    try {
      final convMaps = await HiveDatabase.getRecentConversations(limit: 100);
      _conversations = convMaps.map((map) => _mapToConversation(map)).toList();

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

  Conversation _mapToConversation(Map<String, dynamic> map) {
    final messages = <ChatMessage>[];

    final userMsg = map['userMessage'] as String? ?? '';
    final aiMsg = map['aiResponse'] as String? ?? '';
    final timestamp = DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now();

    if (userMsg.isNotEmpty && userMsg != '[Message processed]') {
      messages.add(ChatMessage(
        role: 'user',
        content: userMsg,
        timestamp: timestamp,
      ));
    }

    if (aiMsg.isNotEmpty) {
      messages.add(ChatMessage(
        role: 'assistant',
        content: aiMsg,
        timestamp: timestamp.add(const Duration(milliseconds: 100)),
      ));
    }

    return Conversation(
      title: 'Chat',
      messages: messages,
      createdAt: timestamp,
      lastModifiedAt: timestamp,
    );
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
      debugPrint('Adding ${isUser ? 'user' : 'AI'} message...');

      if (isUser) {
        await HiveDatabase.saveConversation(
          userMessage: message,
          aiResponse: '',
          mood: mood,
          sessionId: _currentSessionId,
          isOffline: true,
        );
      } else {
        await HiveDatabase.saveConversation(
          userMessage: '[Message processed]',
          aiResponse: message,
          mood: mood,
          sessionId: _currentSessionId,
          isOffline: true,
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

      // Use Gemma AI for both mobile and desktop
      Map<String, dynamic> aiResponseData;

      try {
        final platformPrefix = _isMobile ? '📱' : '🖥️';
        debugPrint('$platformPrefix Using Gemma AI');
        aiResponseData = await _generateGemmaAIResponse(enhancedMessage, mood);
      } catch (e) {
        debugPrint('Gemma AI failed: $e - using fallback');
        aiResponseData = await _generateFallbackResponse(userMessage, mood);
      }

      final aiResponse = aiResponseData['response'] as String? ?? 
          'I\'m here to listen. Could you tell me more?';

      // Add to context
      _addToContext(userMessage, aiResponse);

      // Insert conversation via Hive
      await HiveDatabase.saveConversation(
        userMessage: userMessage.trim(),
        aiResponse: aiResponse,
        mood: mood,
        sessionId: _currentSessionId,
        isOffline: true,
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

        await HiveDatabase.saveConversation(
          userMessage: userMessage.trim(),
          aiResponse: fallbackResponse,
          mood: mood,
          sessionId: _currentSessionId,
          isOffline: true,
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

  /// Generate Gemma AI response for both mobile and desktop
  Future<Map<String, dynamic>> _generateGemmaAIResponse(String message, String? mood) async {
    try {
      final platformPrefix = _isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix Generating Gemma AI response...');

      // Use GemmaService directly (singleton, already initialized)
      final response = await GemmaService().generateEmotionalResponse(message);

      if (response.isNotEmpty) {
        final source = _isMobile ? 'gemma_mobile' : 'gemma_desktop';
        debugPrint('$platformPrefix Gemma AI response generated successfully');
        return {
          'response': response,
          'source': source,
        };
      } else {
        debugPrint('$platformPrefix Gemma AI returned empty - using fallback');
        return await _generateFallbackResponse(message, mood);
      }

    } catch (e) {
      final platformPrefix = _isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix Gemma AI generation failed: $e');
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
      // Get last user message
      final userMessages = conversation.messages
        .where((m) => m.role == 'user')
        .toList();
      if (userMessages.isNotEmpty) {
        _recentMessages.add(userMessages.last.content);
      }

      // Get last AI message
      final aiMessages = conversation.messages
        .where((m) => m.role == 'assistant')
        .toList();
      if (aiMessages.isNotEmpty) {
        _recentResponses.add(aiMessages.last.content);
      }
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
      await HiveDatabase.deleteConversationById(conversationId);
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
      await HiveDatabase.deleteAllConversations();
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
      if (conversationId >= 0 && conversationId < _conversations.length) {
        return _conversations[conversationId];
      }
      return null;
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
    return _conversations.where((conversation) {
      final conversationText = conversation.messages
        .map((m) => m.content)
        .join(' ')
        .toLowerCase();
      return conversationText.contains(lowercaseQuery);
    }).toList();
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

    for (final conversation in _conversations) {
      moodCounts['neutral'] = (moodCounts['neutral'] ?? 0) + 1;

      final userMsgs = conversation.messages
        .where((m) => m.role == 'user')
        .map((m) => m.content.length)
        .fold<int>(0, (a, b) => a + b);
      totalUserMessageLength += userMsgs;

      final userMessages = conversation.messages
        .where((m) => m.role == 'user')
        .map((m) => m.content)
        .toList();

      for (final msg in userMessages) {
        if (_detectCrisis(msg)) {
          crisisCount++;
        }
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

  // ===== Multi-Conversation Management =====

  /// Create new conversation session
  void createNewConversation() {
    final newConversation = Conversation(
      title: 'New Chat',
    );
    _conversationSessions.insert(0, newConversation);
    _activeConversationId = newConversation.id;
    notifyListeners();
    debugPrint('✅ New conversation created: ${newConversation.id}');
  }

  /// Switch to conversation
  void switchConversation(String conversationId) {
    if (_conversationSessions.any((c) => c.id == conversationId)) {
      _activeConversationId = conversationId;
      notifyListeners();
      debugPrint('🔄 Switched to conversation: $conversationId');
    }
  }

  /// Add message to active conversation session
  void addMessageToSession(String role, String content) {
    if (_activeConversationId == null) {
      createNewConversation();
    }

    final messageIndex = _conversationSessions.indexWhere(
      (c) => c.id == _activeConversationId,
    );

    if (messageIndex >= 0) {
      final conversation = _conversationSessions[messageIndex];
      final newMessage = ChatMessage(
        role: role,
        content: content,
      );

      // Auto-generate title from first user message
      String? newTitle = conversation.title;
      if (conversation.title == 'New Chat' && role == 'user') {
        newTitle = _generateTitleFromMessage(content);
      }

      final updatedConversation = conversation.copyWith(
        messages: [...conversation.messages, newMessage],
        lastModifiedAt: DateTime.now(),
        title: newTitle ?? conversation.title,
      );

      _conversationSessions[messageIndex] = updatedConversation;
      notifyListeners();
      debugPrint('💬 Message added to ${conversation.id}');
    }
  }

  /// Generate a title from the first message
  String _generateTitleFromMessage(String message) {
    // Remove extra whitespace
    final trimmed = message.trim();

    if (trimmed.isEmpty) return 'New Chat';

    // Find first sentence or use first 40 characters
    final endOfSentence = trimmed.indexOf(RegExp(r'[.!?]'));
    final title = endOfSentence > 0 && endOfSentence < 60
        ? trimmed.substring(0, endOfSentence).trim()
        : trimmed.length > 50
            ? '${trimmed.substring(0, 50).trim()}...'
            : trimmed;

    return title.isNotEmpty ? title : 'New Chat';
  }

  /// Delete message from active conversation
  void deleteMessageFromSession(String messageId) {
    if (_activeConversationId == null) return;

    final messageIndex = _conversationSessions.indexWhere(
      (c) => c.id == _activeConversationId,
    );

    if (messageIndex >= 0) {
      final conversation = _conversationSessions[messageIndex];
      final updatedMessages = conversation.messages
        .where((m) => m.id != messageId)
        .toList();

      final updatedConversation = conversation.copyWith(
        messages: updatedMessages,
        lastModifiedAt: DateTime.now(),
      );

      _conversationSessions[messageIndex] = updatedConversation;
      notifyListeners();
      debugPrint('🗑️ Message deleted: $messageId');
    }
  }

  /// Delete single conversation session
  void deleteConversationSession(String conversationId) {
    _conversationSessions.removeWhere((c) => c.id == conversationId);

    if (_activeConversationId == conversationId) {
      _activeConversationId = _conversationSessions.isNotEmpty
        ? _conversationSessions.first.id
        : null;

      if (_conversationSessions.isEmpty) {
        createNewConversation();
      }
    }

    notifyListeners();
    debugPrint('🗑️ Conversation deleted: $conversationId');
  }

  /// Delete ALL conversation sessions
  void deleteAllConversationSessions() {
    _conversationSessions.clear();
    _activeConversationId = null;
    createNewConversation();
    notifyListeners();
    debugPrint('🗑️ All conversation sessions cleared from memory');
  }

  /// Completely clear all conversations (memory + Hive)
  Future<void> clearAllConversationsCompletely() async {
    try {
      // Clear old single-conversation system from Hive
      await clearAllConversations();

      // Clear new multi-conversation system
      _conversationSessions.clear();
      _activeConversationId = null;
      _conversations.clear();
      _recentMessages.clear();
      _recentResponses.clear();

      // Create fresh new conversation
      createNewConversation();

      notifyListeners();
      debugPrint('✅ All conversations completely cleared from Hive + Memory');
    } catch (e) {
      debugPrint('❌ Error clearing conversations: $e');
      _lastErrorMessage = 'Failed to clear conversations: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Rename conversation session
  void renameConversationSession(String conversationId, String newTitle) {
    final index = _conversationSessions.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      _conversationSessions[index] = _conversationSessions[index].copyWith(title: newTitle);
      notifyListeners();
      debugPrint('✏️ Conversation renamed: $newTitle');
    }
  }

  @override
  void notifyListeners() {
    debugPrint('ConversationProvider: Notifying (${_conversations.length} conversations, ${_conversationSessions.length} sessions)');
    super.notifyListeners();
  }
}