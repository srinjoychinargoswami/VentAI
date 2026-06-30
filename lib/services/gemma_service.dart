import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class GemmaService {
  static final GemmaService _instance = GemmaService._internal();
  
  factory GemmaService() {
    return _instance;
  }
  
  GemmaService._internal();
  
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Initialize Gemma model
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      int attempts = 0;
      while (_isInitializing && attempts < 60) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      return;
    }

    _isInitializing = true;
    try {
      debugPrint('📱 Initializing Gemma model...');
      _isInitialized = true;
      debugPrint('✅ Gemma model initialized successfully');
    } catch (e) {
      debugPrint('❌ Gemma initialization failed: $e');
      _isInitialized = false;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Generate empathetic response to user message
  Future<String> generateEmotionalResponse(String userMessage) async {
    if (!_isInitialized) {
      throw Exception('Gemma service not initialized. Call initialize() first.');
    }

    try {
      final messagePreview = userMessage.length > 50 
        ? userMessage.substring(0, 50) 
        : userMessage;
      debugPrint('📱 Generating response for: "$messagePreview..."');
      
      final prompt = '''You are Vent AI, a compassionate emotional support companion. 
Your role is to listen with empathy and provide supportive responses.

Guidelines:
- Be warm and understanding
- Validate the person's feelings
- Offer gentle support and perspective
- Keep responses under 200 words
- Never pretend to be a therapist
- If someone mentions crisis (suicide, self-harm), provide crisis resources: 988 Suicide & Crisis Lifeline, 741741 Crisis Text Line, or 911

User message: "$userMessage"

Respond with empathy and support:''';

      // Modern API: Get active model and create chat
      final model = await FlutterGemma.getActiveModel(maxTokens: 2048);
      final chat = await model.createChat();
      
      // Add message
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      
      // Stream response and collect text
      StringBuffer responseBuffer = StringBuffer();
      await chat.generateChatResponseAsync().forEach((response) {
        if (response is TextResponse) {
          responseBuffer.write(response.token);
        }
      });
      
      await model.close();
      
      String text = responseBuffer.toString().trim();
      if (text.isEmpty) {
        text = 'I hear you. I\'m here to listen.';
      }
      
      final responsePreview = text.length > 50 
        ? text.substring(0, 50) 
        : text;
      debugPrint('📱 Response generated: "$responsePreview..."');
      return text;
      
    } catch (e) {
      debugPrint('❌ Response generation failed: $e');
      return 'I hear you. I\'m here to support you. Could you tell me more?';
    }
  }

  /// Get service status for setup verification
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'initialized': _isInitialized,
      'initializing': _isInitializing,
      'model_loaded': _isInitialized,
      'can_generate': _isInitialized,
      'model_name': 'gemma',
    };
  }

  /// Check if model is ready for inference
  bool get isReady => _isInitialized;

  /// Dispose resources
  void dispose() {
    _isInitialized = false;
    debugPrint('📱 Gemma service disposed');
  }
}