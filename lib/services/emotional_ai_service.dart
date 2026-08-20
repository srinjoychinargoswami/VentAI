import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/gemma_service.dart';

class EmotionalAIService {
  static final EmotionalAIService _instance = EmotionalAIService._internal();

  factory EmotionalAIService() => _instance;
  EmotionalAIService._internal();

  late GemmaService _gemmaService;
  bool _initialized = false;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Initialize Gemma AI for both mobile and desktop
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final platformPrefix = _isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix Initializing Gemma AI...');
      _gemmaService = GemmaService();
      await _gemmaService.initialize();
      debugPrint('✅ Gemma AI initialized');

      _initialized = true;
    } catch (e) {
      debugPrint('❌ AI initialization failed: $e');
      _initialized = false;
      rethrow;
    }
  }

  /// Generate empathetic response using Gemma (both platforms)
  Future<Map<String, dynamic>> generateEmpatheticResponse(String message) async {
    if (!_initialized) {
      throw Exception('AI service not initialized');
    }

    try {
      // Use Gemma on both mobile and desktop
      final response = await _gemmaService.generateEmotionalResponse(message);
      final source = _isMobile ? 'gemma_mobile' : 'gemma_desktop';

      return {
        'response': response,
        'source': source,
        'crisisDetected': _detectCrisis(message),
      };
    } catch (e) {
      debugPrint('Error generating response: $e');
      return {
        'response': _generateFallbackResponse(message),
        'source': 'fallback',
        'crisisDetected': _detectCrisis(message),
      };
    }
  }

  /// Detect crisis signals in message
  bool _detectCrisis(String message) {
    final lower = message.toLowerCase();
    final crisisWords = [
      'suicide', 'suicidal', 'kill myself', 'end it all',
      'want to die', 'harm myself', 'hurt myself',
      'no point', 'better off dead', 'cannot go on'
    ];
    return crisisWords.any((word) => lower.contains(word));
  }

  /// Fallback response when AI is unavailable
  String _generateFallbackResponse(String message) {
    final lower = message.toLowerCase();
    
    if (_detectCrisis(message)) {
      return '''I'm really concerned about you right now. Please reach out for help:

🆘 988 Suicide & Crisis Lifeline (US)
📱 Text HOME to 741741 Crisis Text Line
📞 911 for emergency

Your life has value. There are people who want to help you.''';
    }

    if (lower.contains('anxi') || lower.contains('worry') || lower.contains('nervous')) {
      return '''I can sense you're feeling anxious right now. That's completely valid.

Try this breathing technique: Breathe in for 4 counts, hold for 4, exhale for 6. This activates your body's calming response.

What's one thing you know is safe or stable right now?''';
    }

    if (lower.contains('sad') || lower.contains('depress') || lower.contains('down')) {
      return '''I hear that you're going through a difficult time, and your feelings are completely valid.

It takes courage to reach out when you're feeling this way. You don't have to carry this alone.

What's been the hardest part for you today?''';
    }

    return '''Thank you for sharing with me. I'm here to listen.

This is a safe space for you to express yourself. Your feelings matter, and I want to understand what you're going through.

What would feel most helpful right now?''';
  }

  /// Get current AI service status
  Future<Map<String, dynamic>> getStatus() async {
    return await _gemmaService.getStatus();
  }

  /// Verify AI is working with a test message
  Future<bool> verify() async {
    try {
      final result = await generateEmpatheticResponse('Test message');
      final response = result['response'] as String? ?? '';
      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Verification failed: $e');
      return false;
    }
  }

  void dispose() {
    if (_isMobile) {
      _gemmaService.dispose();
    }
    _initialized = false;
  }
}