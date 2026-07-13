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

CRISIS SUPPORT RESOURCES:
If user mentions crisis, self-harm, or suicide - provide immediate help.
If user types "emergency services [country]" - provide crisis resources for that country.

Examples:
User: "emergency services Canada"
Response: "For Canada, reach out immediately:
- 1-833-456-4566 (Canada Suicide Prevention Service)
- Text TALK to 741741 (Crisis Text Line)
- Call 911 for emergencies
You are not alone. Help is available."

User: "emergency services UK"
Response: "For UK, reach out immediately:
- 116 123 (Samaritans)
- Text SHOUT to 85258 (Crisis Text Line)
- Call 999 for emergencies
You are not alone. Help is available."

User: "emergency services Australia"
Response: "For Australia, reach out immediately:
- 13 11 14 (Lifeline)
- 1800 55 1800 (Beyond Blue)
- Call 000 for emergencies
You are not alone. Help is available."

For USA, use: 988 (Suicide & Crisis Lifeline), 741741 (Crisis Text Line), 911

For other countries: Respond with local emergency numbers (usually 911, 112, or 999) and search suggestion.
If unknown country, respond: "Search [country name] + crisis hotline or suicide prevention hotline for local resources. Emergency number is usually 911, 112, or 999."

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
      'model_name': 'Gemma 4 E2B',
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
