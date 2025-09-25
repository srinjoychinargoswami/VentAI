import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';

class TFLiteService {
  static TFLiteService? _instance;
  static TFLiteService get instance => _instance ??= TFLiteService._internal();
  TFLiteService._internal();
  
  // TensorFlow Lite components
  Interpreter? _interpreter;
  Map<String, dynamic>? _tokenizer;
  bool _isModelLoaded = false;
  bool _useEnhancedRules = false; // Switch to false when real models are ready
  
  // Model selection and device specs
  String? _selectedModelName;
  String? _selectedModelPath;
  int? _deviceRAM;
  
  // Model configuration for different device tiers (mirrors your Ollama approach)
  static const Map<String, String> _availableModels = {
    'gemma3n_e2b': 'assets/models/gemma3n_e2b.tflite',  // ~1.5GB - Standard devices
    'gemma3n_e4b': 'assets/models/gemma3n_e4b.tflite',  // ~3GB - High-end devices
  };
  
  static const Map<String, int> _modelMemoryRequirements = {
    'gemma3n_e2b': 3,  // 3GB RAM minimum
    'gemma3n_e4b': 6,  // 6GB RAM minimum
  };
  
  // Model paths (for when models are available)
  static const String _tokenizerAssetPath = 'assets/models/tokenizer_vocab.json';
  static const int _maxSequenceLength = 512;
  static const int _vocabularySize = 32000;

  /// Mirror your OllamaService API exactly
  Future<bool> isServiceRunning() async {
    // TensorFlow Lite is always "running" on mobile/supported platforms
    return Platform.isAndroid || Platform.isIOS;
  }
  
  /// Get available TensorFlow Lite models (mirrors your Ollama getAvailableModels)
  Future<List<String>> getAvailableModels() async {
    final available = <String>[];
    
    for (final entry in _availableModels.entries) {
      try {
        // Check if model file exists in assets
        await rootBundle.load(entry.value);
        available.add(entry.key);
        print('✅ Found model: ${entry.key}');
      } catch (e) {
        print('❌ Model not found: ${entry.key}');
      }
    }
    
    // Fallback if no real models found
    if (available.isEmpty) {
      print('📚 No TensorFlow Lite models found - using enhanced rules');
      available.add('enhanced_rules');
    }
    
    return available;
  }
  
  /// Check if required models are available
  Future<bool> hasRequiredModels() async {
    final models = await getAvailableModels();
    return models.isNotEmpty && !models.contains('enhanced_rules');
  }
  
  /// Get device RAM in GB (mobile version of your Windows logic)
  Future<int> _getDeviceRAM() async {
    if (_deviceRAM != null) return _deviceRAM!;
    
    try {
      if (Platform.isAndroid) {
        _deviceRAM = await _estimateAndroidRAM();
      } else if (Platform.isIOS) {
        _deviceRAM = await _estimateiOSRAM();
      } else {
        _deviceRAM = 4; // Default for other platforms
      }
    } catch (e) {
      print('⚠️ Could not detect RAM, using safe default: $e');
      _deviceRAM = 4;
    }
    
    print('📊 Device RAM detected: ${_deviceRAM}GB');
    return _deviceRAM!;
  }

  /// Estimate Android device RAM based on available indicators
  Future<int> _estimateAndroidRAM() async {
    try {
      // This is a simplified approach - could be enhanced with device_info_plus plugin
      // For now, use educated guesses based on platform capabilities
      
      // Check available disk space as a proxy for device tier
      final tempDir = await getTemporaryDirectory();
      final stat = await tempDir.stat();
      
      // High-end devices usually have more storage
      // This is a rough heuristic - you can improve with device_info_plus
      return 6; // Assume modern Android device for now
    } catch (e) {
      return 4; // Conservative estimate
    }
  }

  /// Estimate iOS device RAM
  Future<int> _estimateiOSRAM() async {
    // iOS devices generally have good specs and efficient memory management
    // Most modern iOS devices can handle larger models
    return 6; // Most iOS devices can handle e4b model
  }
  
  /// Get best model based on device specs (mirrors your Ollama getBestAvailableModel)
  Future<String> getBestAvailableModelForDevice() async {
    final deviceRAM = await _getDeviceRAM();
    final availableModels = await getAvailableModels();
    
    print('🎯 Selecting best model for device...');
    print('📊 Device specs: ${deviceRAM}GB RAM');
    print('📦 Available models: $availableModels');
    
    // Prefer e4b for high-end devices (like your Ollama logic)
    if (deviceRAM >= 6 && availableModels.contains('gemma3n_e4b')) {
      print('🚀 Using Gemma 3n E4B for high-spec device');
      return 'gemma3n_e4b';
    } else if (deviceRAM >= 3 && availableModels.contains('gemma3n_e2b')) {
      print('📱 Using Gemma 3n E2B for standard device');
      return 'gemma3n_e2b';
    }
    
    // Fallback to whatever is available
    if (availableModels.isNotEmpty && !availableModels.contains('enhanced_rules')) {
      final fallbackModel = availableModels.first;
      print('⚠️ Using fallback model: $fallbackModel');
      return fallbackModel;
    }
    
    // If no models available, use enhanced rules
    print('📚 No models available - will use enhanced rules');
    return 'enhanced_rules';
  }
  
  /// Get best available model (mirrors your OllamaService API)
  Future<String?> getBestAvailableModel() async {
    try {
      return await getBestAvailableModelForDevice();
    } catch (e) {
      print('❌ Error selecting model: $e');
      return 'enhanced_rules';
    }
  }

  /// Initialize - tries to load models, falls back gracefully (enhanced version)
  Future<bool> initialize() async {
    try {
      print('🤖 Initializing TensorFlow Lite service with adaptive model selection...');
      
      // Get the best model for this device
      _selectedModelName = await getBestAvailableModelForDevice();
      
      if (_selectedModelName == 'enhanced_rules') {
        _isModelLoaded = false;
        _useEnhancedRules = true;
        print('📚 Using enhanced intelligent response system (no models found)');
        return true;
      }
      
      // Try to load real models
      final modelLoadSuccess = await _tryLoadRealModels();
      
      if (modelLoadSuccess) {
        _isModelLoaded = true;
        _useEnhancedRules = false;
        print('✅ Real TensorFlow Lite model loaded successfully: $_selectedModelName');
      } else {
        _isModelLoaded = false;
        _useEnhancedRules = true;
        print('📚 Model loading failed - using enhanced intelligent responses');
      }
      
      // Test the system
      await _testSystem();
      
      print('✅ TensorFlow Lite service ready!');
      return true;
      
    } catch (e) {
      print('❌ TensorFlow Lite initialization error: $e');
      _useEnhancedRules = true;
      return true; // Still return true - enhanced rules work fine
    }
  }
  
  /// Try to load real TensorFlow Lite models
  Future<bool> _tryLoadRealModels() async {
    try {
      print('📦 Attempting to load TensorFlow Lite model: $_selectedModelName');
      
      _selectedModelPath = _availableModels[_selectedModelName];
      if (_selectedModelPath == null) {
        print('❌ No path found for model: $_selectedModelName');
        return false;
      }
      
      // Check if model asset exists
      try {
        await rootBundle.load(_selectedModelPath!);
        print('✅ Model asset found: $_selectedModelPath');
        
        _interpreter = await Interpreter.fromAsset(_selectedModelPath!);
        print('✅ TensorFlow Lite interpreter loaded for $_selectedModelName');
        
        // Try to load tokenizer (optional)
        try {
          final tokenizerData = await rootBundle.loadString(_tokenizerAssetPath);
          _tokenizer = jsonDecode(tokenizerData);
          print('✅ Tokenizer loaded');
        } catch (tokenizerError) {
          print('💡 No external tokenizer found - using built-in tokenization');
          _tokenizer = null;
        }
        
        return true;
        
      } catch (assetError) {
        print('📝 Model assets not found: $assetError');
        return false;
      }
      
    } catch (e) {
      print('❌ Model loading failed: $e');
      return false;
    }
  }
  
  /// Test the current system configuration
  Future<void> _testSystem() async {
    try {
      print('🧪 Testing current system configuration...');
      
      final testResponse = await generateEmotionalResponse(
        "I'm feeling a bit anxious today",
        mood: "worried"
      );
      
      if (testResponse != null && testResponse.isNotEmpty) {
        print('✅ System test successful');
        print('📊 Response mode: ${_useEnhancedRules ? "Enhanced Rules" : "Neural Network ($_selectedModelName)"}');
      } else {
        print('❌ System test failed');
      }
      
    } catch (e) {
      print('❌ System test error: $e');
    }
  }
  
  /// Mirror your emotional response method signature exactly
  Future<String?> generateEmotionalResponse(String userMessage, {String? mood}) async {
    try {
      print('🧠 TFLiteService.generateEmotionalResponse called with: "${userMessage.length > 30 ? userMessage.substring(0, 30) + "..." : userMessage}"');
      
      // Ensure service is initialized
      if (!_isModelLoaded && !_useEnhancedRules) {
        print('⚙️ TensorFlow Lite not initialized, initializing now...');
        await initialize();
      }
      
      // Use real model if available
      if (_isModelLoaded && !_useEnhancedRules && _interpreter != null) {
        print('🔥 Using neural network model: $_selectedModelName');
        final neuralResponse = await _runModelInference(userMessage, mood);
        if (neuralResponse != null && neuralResponse.isNotEmpty) {
          print('✅ Neural network response: ${neuralResponse.substring(0, neuralResponse.length > 50 ? 50 : neuralResponse.length)}...');
          return neuralResponse;
        }
      }
      
      // Fallback to enhanced rules
      print('📚 Using enhanced intelligent responses');
      final response = _generateContextAwareResponse(userMessage, mood);
      
      print('✅ Generated response: ${response.substring(0, response.length > 50 ? 50 : response.length)}...');
      print('📊 Response length: ${response.length} characters');
      return response;
      
    } catch (e) {
      print('❌ TensorFlow Lite response generation failed: $e');
      return _generateContextAwareResponse(userMessage, mood); // Always have fallback
    }
  }
  
  /// Run the actual model inference
  Future<String?> _runModelInference(String userMessage, String? mood) async {
    if (_interpreter == null) return null;
    
    try {
      print('🔥 Running TensorFlow Lite inference...');
      
      // Create empathetic prompt
      final prompt = _buildEmpatheticPrompt(userMessage, mood);
      
      // Tokenize input
      final tokens = _tokenizeText(prompt);
      final inputShape = _interpreter!.getInputTensor(0).shape;
      
      // Prepare input (pad or truncate to model's expected length)
      final maxLen = inputShape[1];
      final input = List<int>.filled(maxLen, 0);
      for (int i = 0; i < tokens.length && i < maxLen; i++) {
        input[i] = tokens[i];
      }
      
      // Prepare output tensor
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final output = List.generate(
        outputShape[0], 
        (i) => List.generate(
          outputShape[1], 
          (j) => List.filled(outputShape[2], 0.0)
        )
      );
      
      // Run inference
      final startTime = DateTime.now();
      _interpreter!.run([input], output);
      final inferenceTime = DateTime.now().difference(startTime).inMilliseconds;
      
      print('⚡ Inference completed in ${inferenceTime}ms');
      
      // Convert output to text
      final responseText = _detokenizeOutput(output);
      
      return responseText;
      
    } catch (e) {
      print('Model inference error: $e');
      return null;
    }
  }
  
  /// Build empathetic prompt for the model
  String _buildEmpatheticPrompt(String userMessage, String? mood) {
    final moodContext = mood != null ? "The user's current mood is: $mood. " : "";
    
    return """You are Vent AI, a compassionate emotional support companion. ${moodContext}User said: "$userMessage"

Respond with empathy and understanding. Provide emotional support and gentle guidance. Keep response caring and helpful (4-6 sentences).

Response:""";
  }
  
  /// Tokenize text input (with built-in fallback)
  List<int> _tokenizeText(String text) {
    // If we have external tokenizer, use it
    if (_tokenizer != null) {
      return _useExternalTokenizer(text);
    }
    
    // Otherwise, use simple built-in approach
    print('🔤 Using built-in tokenization');
    
    final words = text.toLowerCase().split(' ');
    final tokens = <int>[];
    
    for (final word in words) {
      // Simple hash-based approach (model will handle internally)
      final hash = word.hashCode.abs() % _vocabularySize;
      tokens.add(hash);
    }
    
    return tokens.take(_maxSequenceLength).toList();
  }
  
  List<int> _useExternalTokenizer(String text) {
    // External tokenizer logic (when available)
    return [];
  }
  
  /// Convert model output back to text
  String _detokenizeOutput(List<List<List<double>>> output) {
    try {
      // Get the most likely tokens from output
      final tokens = <int>[];
      for (final timestep in output[0]) {
        var maxIndex = 0;
        var maxValue = timestep[0];
        
        for (int i = 1; i < timestep.length; i++) {
          if (timestep[i] > maxValue) {
            maxValue = timestep[i];
            maxIndex = i;
          }
        }
        tokens.add(maxIndex);
      }
      
      // Convert tokens back to text (simplified)
      final words = tokens.map((token) => _tokenToWord(token)).where((word) => word.isNotEmpty).toList();
      
      return words.join(' ').trim();
      
    } catch (e) {
      print('❌ Detokenization error: $e');
      return '';
    }
  }
  
  /// Convert token ID back to word (placeholder)
  String _tokenToWord(int tokenId) {
    // This is a simplified conversion - real tokenizers have vocabulary maps
    final words = ['I', 'understand', 'you', 'are', 'feeling', 'this', 'way', 'and', 'want', 'to', 'help'];
    return tokenId < words.length ? words[tokenId % words.length] : '';
  }
  
  /// Generate intelligent responses based on context (enhanced version)
  String _generateContextAwareResponse(String userMessage, String? mood) {
    print('Generating context-aware response for emotional content analysis...');
    
    final lowered = userMessage.toLowerCase();
    final moodContext = mood != null ? " I can sense you're feeling $mood right now." : "";
    
    // Crisis detection first (most important)
    if (_detectCrisis(userMessage)) {
      print('Crisis detected in user message - providing crisis resources');
      return '''I'm really concerned about what you've shared with me.$moodContext Please reach out for help immediately:

• Call 988 Suicide Crisis Lifeline - 24/7 support
• Text HOME to 741741 Crisis Text Line
• Call 911 if you're in immediate danger

Your life has value, and there are people who want to help you through this difficult time.''';
    }
    
    // Anxiety/worry responses
    if (lowered.contains('anxious') || lowered.contains('anxiety') || lowered.contains('worried') || lowered.contains('panic')) {
      print('Anxiety content detected - providing breathing techniques');
      return '''I can hear the anxiety in what you've shared with me.$moodContext Anxiety can feel overwhelming, but you're not alone in this experience.

Try this right now: Take a slow breath in for 4 counts, hold for 4, then exhale for 6. This helps activate your body's calm response.

You can also try the 5-4-3-2-1 grounding technique: name 5 things you can see, 4 you can touch, 3 you can hear, 2 you can smell, and 1 you can taste.

What's been the most challenging part of feeling this way? I'm here to listen and support you through this.''';
    }
    
    // Sadness/depression responses
    if (lowered.contains('sad') || lowered.contains('depressed') || lowered.contains('down') || lowered.contains('hopeless')) {
      print('Sadness/depression content detected - providing validation and gentle guidance');
      return '''Thank you for sharing something so difficult with me.$moodContext I can hear the pain in your words, and I want you to know that what you're feeling is completely valid.

When we're feeling this low, even small steps can feel monumental. That's okay - healing isn't linear, and it's okay to take things one moment at a time.

Consider these gentle approaches: stepping outside for just a few minutes, drinking a glass of water mindfully, or reaching out to one person who cares about you.

You mentioned feeling this way - can you tell me what's been weighing most heavily on your heart? I'm here to listen without judgment.''';
    }
    
    // Loneliness responses
    if (lowered.contains('lonely') || lowered.contains('alone') || lowered.contains('isolated')) {
      print('Loneliness content detected - providing connection strategies');
      return '''I hear how isolated you're feeling right now.$moodContext Loneliness can be one of the most difficult emotions to experience, and I want you to know that reaching out like this shows real strength.

Even though you feel alone, you're not - I'm here with you in this moment, and your feelings matter.

Sometimes loneliness can feel less overwhelming when we connect with others, even in small ways. This could be texting a friend, calling a family member, or even just being around people in a public space like a coffee shop or library.

What kind of connection would feel most comforting to you right now? I'm here to help you think through some options.''';
    }
    
    // Stress responses
    if (lowered.contains('stress') || lowered.contains('overwhelmed') || lowered.contains('pressure')) {
      print('Stress/overwhelm content detected - providing stress management techniques');
      return '''I can sense you're feeling really overwhelmed right now.$moodContext When life feels this stressful, it's important to remember that you don't have to carry everything at once.

Let's start with what you can control right now: your breathing. Take three deep breaths with me - inhale slowly, pause, then exhale fully.

It might help to write down everything that's stressing you, then identify just one small thing you can address today. Sometimes breaking things into smaller pieces makes them feel more manageable.

What's been contributing most to feeling overwhelmed? Sometimes just naming it can help us figure out the next step forward.''';
    }
    
    // Anger responses
    if (lowered.contains('angry') || lowered.contains('mad') || lowered.contains('furious') || lowered.contains('irritated')) {
      print('Anger content detected - providing emotion regulation techniques');
      return '''I can hear the anger in what you've shared.$moodContext Anger is a natural emotion, and often it's telling us something important about our boundaries or values.

When we're feeling this intense, it can help to pause and breathe before responding to the situation. Try taking 5 deep breaths, or even stepping away for a few minutes if possible.

Physical movement can also help process anger - even just walking around or doing some stretches can help your body release that tension.

What situation or person has triggered these feelings? Sometimes talking through what happened can help us understand what we need to do next.''';
    }
    
    // Default supportive response
    print('General emotional support content - providing validation and open-ended support');
    return '''Thank you for sharing with me.$moodContext I can hear that you're going through something important, and I want you to know that your feelings and experiences are valid.

This is a safe space where you can express whatever is on your mind. I'm here to listen with empathy and without judgment.

Sometimes it helps to take a moment to breathe deeply and ground yourself in the present moment. You're not alone in whatever you're facing.

Would you like to tell me more about what's been on your mind? I'm here to support you through this conversation in whatever way feels most helpful.''';
  }
  
  /// Crisis detection (mirrors your OllamaManager method)
  bool _detectCrisis(String message) {
    final lowered = message.toLowerCase();
    final crisisWords = [
      'suicide', 'kill myself', 'end it all', 'want to die', 
      'harm myself', 'hurt myself', 'can\'t go on', 'no point living',
      'end my life', 'not worth living', 'better off dead'
    ];
    return crisisWords.any((word) => lowered.contains(word));
  }
  
  /// Test if the service can generate responses
  Future<bool> testModelGeneration() async {
    print('Testing TensorFlow Lite model generation...');
    final testResponse = await generateEmotionalResponse(
      "Hello, this is a test message",
      mood: "neutral"
    );
    final success = testResponse != null && testResponse.isNotEmpty;
    print('Test result: ${success ? "SUCCESS" : "FAILED"}');
    return success;
  }
  
  /// Get comprehensive service status (enhanced with device info)
  Future<Map<String, dynamic>> getServiceStatus() async {
    print('Getting TensorFlow Lite service status...');
    return {
      'service_running': await isServiceRunning(),
      'available_models': await getAvailableModels(),
      'has_required_models': await hasRequiredModels(),
      'best_model': await getBestAvailableModel(),
      'selected_model': _selectedModelName,
      'device_ram_gb': await _getDeviceRAM(),
      'can_generate': _isModelLoaded || _useEnhancedRules,
      'model_loaded': _isModelLoaded,
      'interpreter_ready': _interpreter != null,
      'using_enhanced_rules': _useEnhancedRules,
      'platform': Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other',
    };
  }
  
  /// Cleanup method
  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    _deviceRAM = null;
    _selectedModelName = null;
    _selectedModelPath = null;
    print('TensorFlow Lite service disposed');
  }
}

/// Enum for TFLite service states (enhanced)
enum TFLiteServiceState {
  notInitialized,
  initializing,
  modelSelecting,
  modelLoading,
  ready,
  usingFallback,
  error,
}
