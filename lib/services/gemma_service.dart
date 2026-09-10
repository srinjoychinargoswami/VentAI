import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../utils/secure_logger.dart';

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
    debugPrint('🔍 [GEMMA-INIT] initialize() called');

    // If model already loaded, reuse it
    if (_model != null) {
      debugPrint('✅ [GEMMA-INIT] Model already initialized, reusing singleton');
      SecureLogger.debug('✅ Model already initialized, reusing singleton');
      return;
    }

    try {
      debugPrint('📱 [GEMMA-INIT] Loading Gemma model (maxTokens=2048)...');
      SecureLogger.debug('📱 Loading Gemma model...');

      _model = await FlutterGemma.getActiveModel(maxTokens: 2048);

      if (_model == null) {
        debugPrint('❌ [GEMMA-INIT] Model is null after getActiveModel()');
        throw StateError('getActiveModel() returned null');
      }

      debugPrint('✅ [GEMMA-INIT] Model loaded and stored as singleton (will NOT close)');
      debugPrint('✅ [GEMMA-INIT] Model type: ${_model.runtimeType}');
      SecureLogger.debug('✅ Model loaded and stored as singleton (will NOT close)');
    } catch (e) {
      debugPrint('❌ [GEMMA-INIT] FAILED TO LOAD MODEL: $e');
      debugPrint('❌ [GEMMA-INIT] Stack trace: ${StackTrace.current}');
      SecureLogger.redacted('⚠️ Failed to load model: $e');
      _model = null; // Reset on failure
      rethrow;
    }
  }

  /// Generate empathetic response using persistent singleton model
  /// Model stays alive throughout entire app lifecycle
  Future<String> generateEmotionalResponse(String userMessage, {String? mood}) async {
    SecureLogger.debug('🔵 generateEmotionalResponse called (mood: $mood)');

    if (_model == null) {
      throw StateError('Model not initialized. Call initialize() first');
    }

    final messagePreview = userMessage.length > 50
      ? userMessage.substring(0, 50)
      : userMessage;
    SecureLogger.silent('📱 Generating response for: "$messagePreview..." (mood: $mood)');

    // Build mood context for the prompt
    final moodContext = mood != null && mood.isNotEmpty
      ? 'User\'s current emotional state: $mood.\n\n'
      : '';

    final prompt = '''You are Vent AI, an empathetic emotional support companion.

Your purpose: Listen and respond with genuine understanding. Each conversation is unique—avoid repetitive patterns.

Core principles:
- Respond naturally, not formulaically
- Vary your openings and approaches each time
- Sometimes validate, sometimes explore, sometimes suggest
- Stay under 350 words
- You're not a therapist—just a compassionate listener

CRITICAL - VARY YOUR OPENINGS:
- Never use the same opening phrase twice
- Rotate between: direct acknowledgment, curious questions, perspective shifts, gentle observations
- Examples: "That sounds...", "I hear you...", "It's clear that...", "I'm wondering...", "It makes sense that...", "There's something important in what you said...", "That's a lot to carry..."
- Mix validation with curiosity, perspective, or reflection
- Suggest different coping approaches - NOT always breathing or the Calm Button
- Ask clarifying questions sometimes
- Acknowledge without repeating what they said

CALM BUTTON:
- Only suggest if user explicitly asks about breathing, feeling overwhelmed NOW, or very stressed in the moment
- Don't suggest routinely - keep it occasional and contextual

CRISIS SUPPORT RESOURCES:
If user mentions crisis, self-harm, or suicide - provide immediate help.
If user types "emergency services [country]" - provide crisis resources for that country.

${moodContext}User message: "$userMessage"

Respond naturally and conversationally:''';

    try {
      SecureLogger.debug('📝 Creating inference session...');
      final session = await _model!.createSession();
      SecureLogger.debug('✅ Session created');

      SecureLogger.debug('📝 Adding query to session...');
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      SecureLogger.debug('✅ Query added');

      SecureLogger.debug('📝 Requesting response from Gemma...');
      final response = await session.getResponse();
      SecureLogger.debug('📊 Response received: ${response.length} chars');

      SecureLogger.debug('📝 Closing session...');
      await session.close();
      SecureLogger.debug('✅ Session closed (model stays alive)');

      if (response.isEmpty) {
        SecureLogger.debug('⚠️ Empty response from model');
        return 'I hear you. I\'m here to listen.';
      }

      final responsePreview = response.length > 50
        ? response.substring(0, 50)
        : response;
      SecureLogger.silent('✅ Response generated: "$responsePreview..."');
      return response;

    } catch (e, stackTrace) {
      SecureLogger.redacted('❌ Response generation failed: $e');
      SecureLogger.silent('❌ Stack trace: $stackTrace');
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
        SecureLogger.debug('📱 Model closed on app shutdown');
      } catch (e) {
        SecureLogger.redacted('⚠️ Error closing model: $e');
      }
      _model = null;
    }
    SecureLogger.debug('📱 GemmaService disposed');
  }
}
