import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

class GemmaService {
  static final GemmaService _instance = GemmaService._internal();
  static dynamic _model; // Model reference for lifecycle management

  // Factory constructor - returns SAME instance every time
  factory GemmaService() {
    return _instance;
  }

  GemmaService._internal();

  /// Initialize Gemma model once (flutter_gemma official API)
  /// Subsequent calls reuse the same model - NEVER closes
  Future<void> initialize() async {
    // If model already loaded, reuse it
    if (_model != null) {
      debugPrint('✅ Model already initialized, reusing singleton');
      return;
    }

    try {
      debugPrint('📱 Loading Gemma model...');
      _model = await FlutterGemma.getActiveModel(maxTokens: 2048);
      debugPrint('✅ Model loaded and stored as singleton (will NOT close)');
    } catch (e) {
      debugPrint('⚠️ Failed to load model: $e');
      rethrow;
    }
  }

  /// Generate empathetic response using persistent singleton model
  /// Model stays alive throughout entire app lifecycle
  Future<String> generateEmotionalResponse(String userMessage) async {
    debugPrint('🔵 generateEmotionalResponse called');

    if (_model == null) {
      throw StateError('Model not initialized. Call initialize() first');
    }

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

    try {
      debugPrint('📝 Creating inference session...');
      final session = await _model!.createSession();
      debugPrint('✅ Session created');

      debugPrint('📝 Adding query to session...');
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      debugPrint('✅ Query added');

      debugPrint('📝 Requesting response from Gemma...');
      final response = await session.getResponse();
      debugPrint('📊 Response received: ${response.length} chars');

      debugPrint('📝 Closing session...');
      await session.close();
      debugPrint('✅ Session closed (model stays alive)');

      if (response.isEmpty) {
        debugPrint('⚠️ Empty response from model');
        return 'I hear you. I\'m here to listen.';
      }

      final responsePreview = response.length > 50
        ? response.substring(0, 50)
        : response;
      debugPrint('✅ Response generated: "$responsePreview..."');
      return response;

    } catch (e, stackTrace) {
      debugPrint('❌ Response generation failed: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return 'I hear you. I\'m here to support you. Could you tell me more?';
    }
    // NOTE: Session closes, but model STAYS ALIVE for next inference
  }

  /// Get service status for diagnostics
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'model_loaded': _model != null,
      'can_generate': _model != null,
      'model_name': 'Gemma 3 1B',
    };
  }

  /// Check if model is ready for inference
  bool get isReady => _model != null;

  /// Dispose resources (called on app shutdown only)
  /// Closes the persistent model instance
  Future<void> dispose() async {
    if (_model != null) {
      try {
        await _model!.close();
        debugPrint('📱 Model closed on app shutdown');
      } catch (e) {
        debugPrint('⚠️ Error closing model: $e');
      }
      _model = null;
    }
    debugPrint('📱 GemmaService disposed');
  }
}
