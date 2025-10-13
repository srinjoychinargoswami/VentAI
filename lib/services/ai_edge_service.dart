import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// AI Edge Service - Flutter Gemma Integration for VentAI
/// Provides on-device Gemma 3 Nano with intelligent emotional support fallback
class AIService {
  static AIService? _instance;
  static AIService get instance => _instance ??= AIService._internal();
  AIService._internal();
  
  bool _isInitialized = false;
  bool _isInitializing = false;
  int? _deviceRAM;
  
  // Flutter Gemma instances
  final _gemma = FlutterGemmaPlugin.instance;
  InferenceModel? _inferenceModel;
  InferenceChat? _chat;
  
  // Model state
  bool _isModelDownloaded = false;
  bool _isModelLoading = false;
  double _downloadProgress = 0.0;
  String? _currentModelName;
  
 // Gemma 3 Nano model URLs - UPDATED TO GOOGLE DIRECT DOWNLOADS
  static const _gemma3Nano2B = 'https://storage.googleapis.com/download.tensorflow.org/models/gemma/gemma-3-2b-it-int4.task';
  static const _gemma3Nano4B = 'https://storage.googleapis.com/download.tensorflow.org/models/gemma/gemma-3-4b-it-int4.task';

  
  /// Initialize service AND automatically attempt Gemma download
  Future<bool> initialize({bool autoDownloadModel = true}) async {
    if (_isInitialized) {
      debugPrint('AI Service already initialized');
      return true;
    }
    
    if (_isInitializing) {
      debugPrint('Initialization already in progress, waiting...');
      while (_isInitializing && !_isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }
    
    try {
      _isInitializing = true;
      debugPrint('Initializing AI Edge Service with Flutter Gemma');
      
      await _detectDeviceSpecs();
      
      _isInitialized = true;
      _isInitializing = false;
      
      debugPrint('AI Edge Service initialized successfully');
      debugPrint('Model downloaded: $_isModelDownloaded');
      debugPrint('Using fallback: ${!_isModelDownloaded}');
      
      // AUTO-DOWNLOAD GEMMA MODEL if requested and not already downloaded
      if (autoDownloadModel && !_isModelDownloaded) {
        debugPrint('Auto-downloading Gemma model...');
        // Don't await - let it download in background
        downloadGemmaModel().then((success) {
          if (success) {
            debugPrint('Background Gemma download completed');
          } else {
            debugPrint('Background Gemma download failed, using fallback');
          }
        });
      }
      
      return true;
      
    } catch (e) {
      debugPrint('AI Service initialization error: $e');
      _isInitialized = true; // Mark as initialized anyway (fallback works)
      _isInitializing = false;
      return true;
    }
  }
  
  /// Detect device specifications
  Future<void> _detectDeviceSpecs() async {
    try {
      _deviceRAM = await _getDeviceRAM();
      debugPrint('Device RAM: ${_deviceRAM}GB');
    } catch (e) {
      debugPrint('Could not detect device specs: $e');
      _deviceRAM = 4; // Default assumption
    }
  }
  
  /// Get device RAM estimate
  Future<int> _getDeviceRAM() async {
    if (_deviceRAM != null) return _deviceRAM!;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final model = androidInfo.model.toLowerCase();
        
        if (model.contains('pro') || model.contains('ultra') || model.contains('plus')) {
          _deviceRAM = 8;
        } else if (androidInfo.version.sdkInt >= 30) {
          _deviceRAM = 6;
        } else {
          _deviceRAM = 4;
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final model = iosInfo.model.toLowerCase();
        
        if (model.contains('pro') || model.contains('max')) {
          _deviceRAM = 8;
        } else {
          _deviceRAM = 6;
        }
      } else {
        _deviceRAM = 4;
      }
      
      return _deviceRAM!;
      
    } catch (e) {
      debugPrint('RAM detection error: $e');
      _deviceRAM = 4;
      return 4;
    }
  }
  
  /// Download Gemma model (call when user wants to upgrade from fallback)
Future<bool> downloadGemmaModel({
  Function(double)? onProgress,
}) async {
  if (_isModelDownloaded) {
    debugPrint('Model already downloaded');
    return true;
  }
  
  if (_isModelLoading) {
    debugPrint('Model download already in progress');
    return false;
  }
  
  try {
    _isModelLoading = true;
    _downloadProgress = 0.0;
    
    // Select model based on device RAM
    final modelUrl = (_deviceRAM ?? 4) >= 6 ? _gemma3Nano4B : _gemma3Nano2B;
    final modelName = (_deviceRAM ?? 4) >= 6 ? 'gemma-3-4b-it-int4.task' : 'gemma-3-2b-it-int4.task';
    _currentModelName = modelName;
    
    debugPrint('Starting Gemma download: $modelName');
    debugPrint('Device RAM: ${_deviceRAM}GB');
    debugPrint('Estimated model size: ~${(_deviceRAM ?? 4) >= 6 ? "2.5GB" : "1.5GB"}');
    debugPrint('This may take several minutes...');
    
    final modelManager = _gemma.modelManager;
    
    // ensureModelReady automatically checks if model exists and skips download if so
    debugPrint('⬇Downloading/verifying model from: $modelUrl');
    
    await modelManager.ensureModelReady(
      modelName,
      modelUrl,
    );
    
    debugPrint('Model download complete');
    
    // Initialize the model for inference
    await _initializeModel();
    
    _isModelDownloaded = true;
    _isModelLoading = false;
    _downloadProgress = 100.0;
    
    onProgress?.call(100.0);
    
    debugPrint('Gemma model ready for use!');
    return true;
    
  } catch (e, stackTrace) {
    debugPrint('Model download failed: $e');
    debugPrint('Stack trace: $stackTrace');
    _isModelLoading = false;
    _downloadProgress = 0.0;
    _isModelDownloaded = false;
    return false;
  }
}

  /// Initialize the downloaded model for inference
  Future<void> _initializeModel() async {
    try {
      debugPrint('Initializing Gemma model for inference...');
      
      // Create inference model with GPU backend for better performance
      _inferenceModel = await _gemma.createModel(
        modelType: ModelType.gemmaIt,
        preferredBackend: PreferredBackend.gpu,
        maxTokens: 512, // Appropriate for emotional support responses
      );
      
      debugPrint('Inference model created');
      
      // Create chat instance for conversations with emotional parameters
      _chat = await _inferenceModel!.createChat(
        temperature: 0.8, // Balanced creativity and coherence
        topK: 40, // Good diversity for emotional responses
        randomSeed: 1, // Must provide int value, not null
      );
      
      debugPrint('Gemma chat instance ready for emotional support!');
      
    } catch (e, stackTrace) {
      debugPrint('Model initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      _inferenceModel = null;
      _chat = null;
      _isModelDownloaded = false;
    }
  }
  
  /// Generate emotional response (main API method - mirrors existing interface)
  Future<String?> generateEmotionalResponse(String userMessage, {String? mood}) async {
    try {
      // Try Gemma first if available
      if (_isModelDownloaded && _chat != null) {
        debugPrint('Using Gemma 3 Nano for response...');
        return await _generateGemmaResponse(userMessage, mood);
      }
      
      // Fallback to intelligent rules
      debugPrint('Using intelligent fallback system...');
      return _generateContextAwareResponse(userMessage, mood);
      
    } catch (e) {
      debugPrint('Response generation error: $e');
      return _generateContextAwareResponse(userMessage, mood);
    }
  }
  
  /// Generate response using Gemma model
  Future<String> _generateGemmaResponse(String userMessage, String? mood) async {
    try {
      debugPrint('Generating response with Gemma 3 Nano...');
      
      // Create emotional support prompt
      final systemPrompt = _buildEmotionalSupportPrompt(mood);
      final fullPrompt = '$systemPrompt\n\nUser: $userMessage\n\nAssistant:';
      
      // Add user message to chat
      await _chat!.addQueryChunk(
        Message.text(text: fullPrompt, isUser: true)
      );
      
      // Generate response with streaming
      final responseBuffer = StringBuffer();
      
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          responseBuffer.write(response.token);
        }
      }
      
      final response = responseBuffer.toString().trim();
      
      // Fallback if response is too short or empty
      if (response.isEmpty || response.length < 20) {
        debugPrint('Gemma response too short, using fallback');
        return _generateContextAwareResponse(userMessage, mood);
      }
      
      debugPrint('Gemma response generated successfully');
      return response;
      
    } catch (e, stackTrace) {
      debugPrint('Gemma generation error: $e');
      debugPrint('Stack trace: $stackTrace');
      return _generateContextAwareResponse(userMessage, mood);
    }
  }
  
  /// Build emotional support system prompt for Gemma
  String _buildEmotionalSupportPrompt(String? mood) {
    final moodContext = mood != null 
        ? ' The user has indicated they are feeling $mood.' 
        : '';
    
    return '''You are VentAI, a compassionate emotional support companion. Your role is to provide empathetic, supportive responses to people experiencing difficult emotions.$moodContext

Guidelines:
- Be warm, empathetic, and non-judgmental
- Validate the user's feelings
- Offer gentle coping strategies when appropriate
- Keep responses concise but meaningful (2-4 sentences)
- CRITICAL: If you detect crisis language (suicide, self-harm), immediately provide crisis hotline information: 988 Suicide Crisis Lifeline, text HOME to 741741
- Never claim to be a replacement for professional therapy
- Focus on emotional support and active listening''';
  }
  
  /// Generate empathetic response (mirrors Ollama API for compatibility)
  Future<Map<String, dynamic>> generateEmpatheticResponse(String message, [String? model]) async {
    try {
      final response = await generateEmotionalResponse(message);
      
      if (response != null && response.isNotEmpty) {
        return {
          'response': response,
          'source': _isModelDownloaded ? 'gemma_3_nano' : 'enhanced_rules',
          'model': _isModelDownloaded ? (_currentModelName ?? 'gemma-3n') : 'enhanced_rules_v1',
          'mood': _detectEmotion(message),
          'crisisDetected': _detectCrisis(message),
          'copingStrategies': _extractCopingStrategies(message),
          'platform': Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'mobile',
          'device_ram': _deviceRAM ?? 4,
          'model_downloaded': _isModelDownloaded,
          'unlimited_usage': true,
        };
      }
      
      return {
        'response': "I'm here to listen and support you. Please share what's on your mind.",
        'source': 'fallback',
        'model': 'safety_fallback',
        'mood': 'neutral',
        'crisisDetected': false,
        'copingStrategies': ['Take deep breaths', 'Stay present', 'You matter'],
        'platform': 'mobile',
        'unlimited_usage': true,
      };
      
    } catch (e) {
      debugPrint('Error: $e');
      
      return {
        'response': "I'm experiencing a technical issue, but I'm still here for you. Your feelings matter.",
        'source': 'error_fallback',
        'model': 'error_recovery',
        'mood': 'supportive',
        'crisisDetected': false,
        'copingStrategies': ['Your feelings are valid'],
        'platform': 'mobile',
        'unlimited_usage': true,
      };
    }
  }
  
  /// ENHANCED RULES SYSTEM - Context-aware intelligent responses
  String _generateContextAwareResponse(String userMessage, String? mood) {
    final lowered = userMessage.toLowerCase();
    final moodContext = mood != null ? " I can sense you're feeling $mood right now." : "";
    
    // Crisis detection first (highest priority)
    if (_detectCrisis(userMessage)) {
      return '''I'm really concerned about what you've shared with me.$moodContext Please reach out for help immediately:

• Call 988 Suicide Crisis Lifeline - 24/7 support
• Text HOME to 741741 Crisis Text Line
• Call 911 if you're in immediate danger

Your life has value, and there are people who want to help you through this difficult time.''';
    }
    
    // Anxiety responses
    if (lowered.contains('anxious') || lowered.contains('anxiety') || 
        lowered.contains('worried') || lowered.contains('panic')) {
      return '''I can hear the anxiety in what you've shared with me.$moodContext Anxiety can feel overwhelming, but you're not alone in this experience.

Try this right now: Take a slow breath in for 4 counts, hold for 4, then exhale for 6. This helps activate your body's calm response.

You can also try the 5-4-3-2-1 grounding technique: name 5 things you can see, 4 you can touch, 3 you can hear, 2 you can smell, and 1 you can taste.

What's been the most challenging part of feeling this way? I'm here to listen and support you through this.''';
    }
    
    // Sadness/depression responses
    if (lowered.contains('sad') || lowered.contains('depressed') || 
        lowered.contains('down') || lowered.contains('hopeless')) {
      return '''Thank you for sharing something so difficult with me.$moodContext I can hear the pain in your words, and I want you to know that what you're feeling is completely valid.

When we're feeling this low, even small steps can feel monumental. That's okay - healing isn't linear, and it's okay to take things one moment at a time.

Consider these gentle approaches: stepping outside for just a few minutes, drinking a glass of water mindfully, or reaching out to one person who cares about you.

You mentioned feeling this way - can you tell me what's been weighing most heavily on your heart? I'm here to listen without judgment.''';
    }
    
    // Loneliness responses
    if (lowered.contains('lonely') || lowered.contains('alone') || 
        lowered.contains('isolated')) {
      return '''I hear how isolated you're feeling right now.$moodContext Loneliness can be one of the most difficult emotions to experience, and I want you to know that reaching out like this shows real strength.

Even though you feel alone, you're not - I'm here with you in this moment, and your feelings matter.

Sometimes loneliness can feel less overwhelming when we connect with others, even in small ways. This could be texting a friend, calling a family member, or even just being around people in a public space like a coffee shop or library.

What kind of connection would feel most comforting to you right now? I'm here to help you think through some options.''';
    }
    
    // Stress responses
    if (lowered.contains('stress') || lowered.contains('overwhelmed') || 
        lowered.contains('pressure')) {
      return '''I can sense you're feeling really overwhelmed right now.$moodContext When life feels this stressful, it's important to remember that you don't have to carry everything at once.

Let's start with what you can control right now: your breathing. Take three deep breaths with me - inhale slowly, pause, then exhale fully.

It might help to write down everything that's stressing you, then identify just one small thing you can address today. Sometimes breaking things into smaller pieces makes them feel more manageable.

What's been contributing most to feeling overwhelmed? Sometimes just naming it can help us figure out the next step forward.''';
    }
    
    // Anger responses
    if (lowered.contains('angry') || lowered.contains('mad') || 
        lowered.contains('furious') || lowered.contains('irritated')) {
      return '''I can hear the anger in what you've shared.$moodContext Anger is a natural emotion, and often it's telling us something important about our boundaries or values.

When we're feeling this intense, it can help to pause and breathe before responding to the situation. Try taking 5 deep breaths, or even stepping away for a few minutes if possible.

Physical movement can also help process anger - even just walking around or doing some stretches can help your body release that tension.

What situation or person has triggered these feelings? Sometimes talking through what happened can help us understand what we need to do next.''';
    }
    
    // Fear responses
    if (lowered.contains('scared') || lowered.contains('afraid') || 
        lowered.contains('terrified') || lowered.contains('fear')) {
      return '''I can hear that you're feeling scared right now.$moodContext Fear is our mind's way of trying to protect us, but sometimes it can feel overwhelming.

Let's ground you in this moment: You are safe right now as you read this. Take a deep breath and notice what's around you.

Fear often comes with "what if" thoughts. Let's focus on what is true right now, in this present moment. What can you see, hear, or feel that reminds you that you're okay in this exact moment?

What's making you feel this way? Talking about it can sometimes help us understand if the fear is about something we can address.''';
    }
    
    // Gratitude/positive responses
    if (lowered.contains('happy') || lowered.contains('grateful') || 
        lowered.contains('joyful') || lowered.contains('thankful')) {
      return '''It's wonderful to hear that you're feeling good!$moodContext Moments of happiness and gratitude are precious, and it's beautiful that you're taking time to acknowledge them.

Savoring positive emotions can help strengthen our resilience for more challenging times. Take a moment to really notice what this feeling is like in your body.

What's been bringing you joy or gratitude today? Sharing these moments can help make them even more meaningful.''';
    }
    
    // Default supportive response
    return '''Thank you for sharing with me.$moodContext I can hear that you're going through something important, and I want you to know that your feelings and experiences are valid.

This is a safe space where you can express whatever is on your mind. I'm here to listen with empathy and without judgment.

Sometimes it helps to take a moment to breathe deeply and ground yourself in the present moment. You're not alone in whatever you're facing.

Would you like to tell me more about what's been on your mind? I'm here to support you through this conversation in whatever way feels most helpful.''';
  }
  
  /// Detect emotion from text
  String _detectEmotion(String message) {
    final lowered = message.toLowerCase();
    
    if (lowered.contains('happy') || lowered.contains('joy') || 
        lowered.contains('excited') || lowered.contains('grateful')) {
      return 'happy';
    }
    if (lowered.contains('sad') || lowered.contains('depressed') || 
        lowered.contains('down') || lowered.contains('hopeless')) {
      return 'sad';
    }
    if (lowered.contains('angry') || lowered.contains('mad') || 
        lowered.contains('furious') || lowered.contains('annoyed')) {
      return 'angry';
    }
    if (lowered.contains('anxious') || lowered.contains('anxiety') || 
        lowered.contains('worried') || lowered.contains('nervous')) {
      return 'anxious';
    }
    if (lowered.contains('scared') || lowered.contains('afraid') || 
        lowered.contains('terrified')) {
      return 'fearful';
    }
    if (lowered.contains('lonely') || lowered.contains('alone') || 
        lowered.contains('isolated')) {
      return 'lonely';
    }
    if (lowered.contains('stress') || lowered.contains('overwhelmed')) {
      return 'stressed';
    }
    
    return 'neutral';
  }
  
  /// Extract coping strategies based on message
  List<String> _extractCopingStrategies(String message) {
    final lowered = message.toLowerCase();
    
    if (lowered.contains('anxious') || lowered.contains('panic')) {
      return [
        'Deep breathing (4-4-6 pattern)',
        '5-4-3-2-1 grounding technique',
        'Progressive muscle relaxation'
      ];
    }
    
    if (lowered.contains('sad') || lowered.contains('depressed')) {
      return [
        'Gentle self-care activities',
        'Reach out to trusted friends',
        'Small achievable goals'
      ];
    }
    
    if (lowered.contains('angry') || lowered.contains('frustrated')) {
      return [
        'Physical movement or exercise',
        'Journaling your feelings',
        'Take breaks before responding'
      ];
    }
    
    if (lowered.contains('stressed') || lowered.contains('overwhelmed')) {
      return [
        'Break tasks into smaller steps',
        'Prioritize self-care',
        'Ask for help when needed'
      ];
    }
    
    if (lowered.contains('lonely') || lowered.contains('isolated')) {
      return [
        'Reach out to one person',
        'Join a community or group',
        'Practice self-compassion'
      ];
    }
    
    return [
      'Take deep breaths',
      'Stay present in the moment',
      'You are worthy of support'
    ];
  }
  
  /// Crisis detection
  bool _detectCrisis(String message) {
    final lowered = message.toLowerCase();
    final crisisWords = [
      'suicide', 'suicidal', 'kill myself', 'end it all', 'want to die',
      'harm myself', 'hurt myself', 'can\'t go on', 'cannot go on',
      'no point living', 'end my life', 'not worth living', 'better off dead',
      'take my life', 'end everything', 'no reason to live'
    ];
    return crisisWords.any((word) => lowered.contains(word));
  }
  
  /// Get service status
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'initialized': _isInitialized,
      'using_gemma': _isModelDownloaded,
      'using_enhanced_rules': !_isModelDownloaded,
      'can_generate': true,
      'model_loaded': _isModelDownloaded,
      'model_downloaded': _isModelDownloaded,
      'is_downloading': _isModelLoading,
      'download_progress': _downloadProgress,
      'device_ram_gb': _deviceRAM ?? 4,
      'platform': Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'mobile',
      'available_models': _isModelDownloaded 
          ? ['Gemma 3 Nano', 'Enhanced Rules System']
          : ['Enhanced Rules System'],
      'selected_model': _isModelDownloaded 
          ? (_currentModelName ?? 'gemma-3n') 
          : 'enhanced_rules_v1',
      'backend': _isModelDownloaded ? 'gpu' : 'rules',
    };
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    try {
      await _inferenceModel?.close();
      _chat = null;
      _inferenceModel = null;
      _isInitialized = false;
      _isInitializing = false;
      _deviceRAM = null;
      _isModelDownloaded = false;
      _isModelLoading = false;
      _downloadProgress = 0.0;
      debugPrint('AI Edge Service disposed');
    } catch (e) {
      debugPrint('Dispose error: $e');
    }
  }
}
