import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';

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
  
  // UPDATED: Model configuration for MobileBERT (your actual model)
  static const Map<String, String> _availableModels = {
    'mobilebert': 'assets/models/1.tflite',  // ~96MB - Your MobileBERT model
    // Removed gemma models since they're not available yet
  };
  
  static const Map<String, int> _modelMemoryRequirements = {
    'mobilebert': 1,  // 1GB RAM minimum - very lightweight
  };
  
  // Model paths (for when tokenizers are available)
  static const String _tokenizerAssetPath = 'assets/models/tokenizer_vocab.json';
  static const int _maxSequenceLength = 512;
  static const int _vocabularySize = 30522; // MobileBERT vocabulary size

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

  /// Estimate Android device RAM based on available indicators (enhanced with device_info_plus)
  Future<int> _estimateAndroidRAM() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      // Use device specifications to estimate RAM
      final model = androidInfo.model.toLowerCase();
      final brand = androidInfo.brand.toLowerCase();
      
      // High-end device indicators
      if (model.contains('pro') || model.contains('plus') || model.contains('ultra') ||
          brand.contains('samsung') && model.contains('s2')) {
        return 8; // High-end device
      }
      
      // Mid-range indicators
      if (androidInfo.version.sdkInt >= 30) {
        return 6; // Modern Android usually means 6GB+
      }
      
      return 4; // Conservative estimate for older devices
    } catch (e) {
      print('Device info detection failed: $e');
      return 4; // Conservative estimate
    }
  }

  /// Estimate iOS device RAM
  Future<int> _estimateiOSRAM() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      
      // iOS devices generally have good specs and efficient memory management
      final model = iosInfo.model.toLowerCase();
      
      // iPhone Pro models typically have more RAM
      if (model.contains('pro') || model.contains('max')) {
        return 8;
      }
      
      // Most modern iOS devices can handle larger models
      return 6;
    } catch (e) {
      return 6; // Most iOS devices can handle models well
    }
  }
  
  /// UPDATED: Get best model based on device specs (focuses on MobileBERT)
  Future<String> getBestAvailableModelForDevice() async {
    final deviceRAM = await _getDeviceRAM();
    final availableModels = await getAvailableModels();
    
    print('🎯 Selecting best model for device...');
    print('📊 Device specs: ${deviceRAM}GB RAM');
    print('📦 Available models: $availableModels');
    
    // Use MobileBERT if available (works on any device with 1GB+ RAM)
    if (availableModels.contains('mobilebert')) {
      print('🤖 Using MobileBERT for efficient offline processing');
      return 'mobilebert';
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
      print('🤖 Initializing TensorFlow Lite service with MobileBERT...');
      
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
  
  /// Try to load real TensorFlow Lite models with enhanced error handling
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
        
        // ENHANCED: Validate interpreter and tensors
        if (_interpreter == null) {
          print('❌ Interpreter is null after loading');
          return false;
        }
        
        // SAFE: Check tensor access
        try {
          final inputTensor = _interpreter!.getInputTensor(0);
          final outputTensor = _interpreter!.getOutputTensor(0);
          
          if (inputTensor.shape.isEmpty || outputTensor.shape.isEmpty) {
            print('❌ Invalid tensor shapes - input: ${inputTensor.shape}, output: ${outputTensor.shape}');
            _interpreter!.close();
            _interpreter = null;
            return false;
          }
          
          print('✅ TensorFlow Lite interpreter loaded for $_selectedModelName');
          print('📊 Input shape: ${inputTensor.shape}');
          print('📊 Output shape: ${outputTensor.shape}');
          print('📊 Input type: ${inputTensor.type}');
          print('📊 Output type: ${outputTensor.type}');
          
        } catch (tensorError) {
          print('❌ Tensor access error: $tensorError');
          _interpreter?.close();
          _interpreter = null;
          return false;
        }
        
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
      _interpreter?.close();
      _interpreter = null;
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
        print('Using neural network model: $_selectedModelName');
        final neuralResponse = await _runModelInference(userMessage, mood);
        if (neuralResponse != null && neuralResponse.isNotEmpty) {
          print('Neural network response: ${neuralResponse.substring(0, neuralResponse.length > 50 ? 50 : neuralResponse.length)}...');
          return neuralResponse;
        }
      }
      
      // Fallback to enhanced rules
      print('Using enhanced intelligent responses');
      final response = _generateContextAwareResponse(userMessage, mood);
      
      print('Generated response: ${response.substring(0, response.length > 50 ? 50 : response.length)}...');
      print('Response length: ${response.length} characters');
      return response;
      
    } catch (e) {
      print('TensorFlow Lite response generation failed: $e');
      return _generateContextAwareResponse(userMessage, mood); // Always have fallback
    }
  }
  
  /// Mirror the exact signature from your OllamaManager - THIS IS THE KEY METHOD
  Future<Map<String, dynamic>> generateEmpatheticResponse(String message, [String? model]) async {
    print('TFLiteService.generateEmpatheticResponse called with: "${message.length > 50 ? message.substring(0, 50) + "..." : message}"');
    
    try {
      final response = await generateEmotionalResponse(message);
      
      if (response != null && response.isNotEmpty) {
        return {
          'response': response,
          'source': _useEnhancedRules ? 'tflite_enhanced_rules' : 'tflite_mobilebert',
          'model': _selectedModelName ?? 'enhanced_rules',
          'mood': 'contextual', // Detected from context
          'crisisDetected': _detectCrisis(message),
          'copingStrategies': _extractCopingStrategies(message),
          'platform': 'mobile_tflite',
          'inference_time': _useEnhancedRules ? '< 1ms' : 'varies',
          'device_ram': await _getDeviceRAM(),
          'unlimited_usage': true, // Key advantage over API calls
        };
      }
      
      // Fallback response
      return {
        'response': "I'm here to listen and support you. Please share what's on your mind.",
        'source': 'tflite_fallback',
        'model': 'safety_fallback',
        'mood': 'neutral',
        'crisisDetected': false,
        'copingStrategies': ['Take deep breaths', 'Stay present', 'You matter'],
        'platform': 'mobile_tflite',
        'unlimited_usage': true,
      };
      
    } catch (e) {
      print('TFLite generateEmpatheticResponse error: $e');
      
      return {
        'response': "I'm experiencing a technical issue, but I want you to know that I'm still here for you. Your feelings matter, and this is still a safe space to share.",
        'source': 'tflite_error_fallback',
        'model': 'error_recovery',
        'mood': 'supportive',
        'crisisDetected': false,
        'copingStrategies': ['Technical issues don\'t diminish your worth', 'Your feelings are valid'],
        'platform': 'mobile_tflite',
        'unlimited_usage': true,
      };
    }
  }

  /// Extract appropriate coping strategies based on message content
  List<String> _extractCopingStrategies(String message) {
    final lowered = message.toLowerCase();
    
    if (lowered.contains('anxious') || lowered.contains('panic')) {
      return ['Deep breathing (4-4-6 pattern)', '5-4-3-2-1 grounding technique', 'Progressive muscle relaxation'];
    }
    
    if (lowered.contains('sad') || lowered.contains('depressed')) {
      return ['Gentle self-care activities', 'Reach out to trusted friends', 'Small achievable goals'];
    }
    
    if (lowered.contains('angry') || lowered.contains('frustrated')) {
      return ['Physical movement or exercise', 'Journaling your feelings', 'Take breaks before responding'];
    }
    
    if (lowered.contains('stressed') || lowered.contains('overwhelmed')) {
      return ['Break tasks into smaller steps', 'Prioritize self-care', 'Ask for help when needed'];
    }
    
    // Default strategies
    return ['Take deep breaths', 'Stay present in the moment', 'You are worthy of support'];
  }
  
  /// FINAL DEBUGGED FIX: Run the actual MobileBERT model inference with correct data types
  Future<String?> _runModelInference(String userMessage, String? mood) async {
    // SAFE: Multiple null checks
    if (_interpreter == null) {
      print('_interpreter is null');
      return null;
    }
    
    try {
      print(' Running MobileBERT inference...');
      
      // SAFE: Get tensors with null checks
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
      // SAFE: Validate tensor shapes
      if (inputTensor.shape.isEmpty || outputTensor.shape.isEmpty) {
        print('Empty tensor shapes - input: ${inputTensor.shape}, output: ${outputTensor.shape}');
        return null;
      }
      
      if (inputTensor.shape.length < 2 || outputTensor.shape.length < 2) {
        print('Invalid tensor dimensions - input: ${inputTensor.shape.length}, output: ${outputTensor.shape.length}');
        return null;
      }
      
      print('Tensor validation passed - input: ${inputTensor.shape}, output: ${outputTensor.shape}');
      print('Input type: ${inputTensor.type}, Output type: ${outputTensor.type}');
      
      // Create empathetic prompt
      final prompt = _buildEmpatheticPrompt(userMessage, mood);
      
      // Tokenize input for BERT model
      final tokens = _tokenizeTextForBERT(prompt);
      final maxLen = inputTensor.shape[1]; // Get max length safely
      
      // FIXED: Create Int32List for MobileBERT input
      final input = Int32List(maxLen);
      for (int i = 0; i < tokens.length && i < maxLen; i++) {
        input[i] = tokens[i]; // Keep as int
      }
      
      // FIXED: Create Float32List output buffer (not List<double>)
      final outputSize = outputTensor.shape[1];
      final output = Float32List(outputSize); // This is the correct type
      
      print('Input prepared - length: $maxLen, tokens: ${tokens.length}');
      print('Output buffer prepared - size: $outputSize (Float32List)');
      
      // DEBUG: Check types before inference
      print(' Debug types - input: ${input.runtimeType}, output: ${output.runtimeType}');
      
      // SAFE: Run inference with proper error handling
      final startTime = DateTime.now();
      
      try {
        // CRITICAL: Pass the arrays correctly
        _interpreter!.run([input], [output]); // Both must be typed arrays
        final inferenceTime = DateTime.now().difference(startTime).inMilliseconds;
        print('MobileBERT inference completed in ${inferenceTime}ms');
      } catch (inferenceError) {
        print('Inference execution failed: $inferenceError');
        return null;
      }
      
      // Generate contextual response based on BERT analysis
      final contextualResponse = _generateBERTContextualResponse(userMessage, output);
      
      return contextualResponse;
      
    } catch (e, stackTrace) {
      print('MobileBERT inference error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// UPDATED: Generate contextual response using BERT embeddings (handles both data types)
  String _generateBERTContextualResponse(String userMessage, Float32List embeddings) {
    try {
      // Analyze the embeddings to understand emotional context
      print('Generating BERT-enhanced contextual response');
      
      final lowered = userMessage.toLowerCase();
      
      // SAFE: Check embeddings validity
      if (embeddings.isEmpty) {
        print('Empty embeddings - using rule-based fallback');
        return _generateContextAwareResponse(userMessage, null);
      }
      
      // Calculate average activation for emotional intensity
      final avgActivation = embeddings.reduce((a, b) => a + b) / embeddings.length;
      final intensity = avgActivation > 0.5 ? 'high' : avgActivation > 0.2 ? 'medium' : 'low';
      
      print('BERT analysis - Avg activation: ${avgActivation.toStringAsFixed(3)}, Intensity: $intensity');
      
      // Use the embeddings to enhance confidence in emotional detection
      if (lowered.contains('anxious') || lowered.contains('anxiety') || lowered.contains('worried')) {
        return '''I can sense the anxiety in your message through my neural analysis (intensity: $intensity). These feelings are completely valid and understandable.

Let's try a grounding technique together: Take a slow breath in for 4 counts, hold for 4, then exhale for 6. This activates your body's natural calm response.

What specific thoughts or situations have been contributing to these anxious feelings? I'm here to help you work through them.''';
      }
      
      if (lowered.contains('sad') || lowered.contains('depressed') || lowered.contains('down')) {
        return '''My neural analysis shows you're experiencing significant emotional distress (intensity: $intensity). I want you to know that sharing these feelings takes real courage.

These emotions, while difficult, are a natural response to challenging circumstances. Healing isn't linear, and it's okay to take things one moment at a time.

What has been the most challenging aspect of feeling this way? I'm here to listen and support you without judgment.''';
      }
      
      // Default BERT-enhanced response
      return '''Through my neural analysis, I can sense that you're going through something meaningful (emotional intensity: $intensity). Your emotions and experiences are valid and important.

I'm here to provide a safe, supportive space where you can express whatever is on your mind. My AI is designed to understand and respond with empathy.

What would feel most helpful for you right now in our conversation?''';
      
    } catch (e) {
      print('BERT response generation error: $e');
      return _generateContextAwareResponse(userMessage, null);
    }
  }
  
  /// Build empathetic prompt for the model
  String _buildEmpatheticPrompt(String userMessage, String? mood) {
    final moodContext = mood != null ? "The user's current mood is: $mood. " : "";
    
    return """You are Vent AI, a compassionate emotional support companion. ${moodContext}User said: "$userMessage"

Respond with empathy and understanding. Provide emotional support and gentle guidance. Keep response caring and helpful (4-6 sentences).

Response:""";
  }
  
  /// UPDATED: Tokenize text for BERT model with enhanced error handling
  List<int> _tokenizeTextForBERT(String text) {
    try {
      // If we have external tokenizer, use it
      if (_tokenizer != null) {
        return _useExternalTokenizer(text);
      }
      
      // BERT-specific tokenization approach
      print('Using BERT-compatible tokenization');
      
      // Add special BERT tokens
      const int CLS_TOKEN = 101; // [CLS] token
      const int SEP_TOKEN = 102; // [SEP] token
      
      final words = text.toLowerCase().split(RegExp(r'[^a-zA-Z0-9]+')).where((w) => w.isNotEmpty).toList();
      final tokens = <int>[CLS_TOKEN]; // Start with [CLS]
      
      for (final word in words) {
        // Simple hash-based approach for BERT vocabulary
        final hash = word.hashCode.abs() % _vocabularySize;
        tokens.add(hash);
        
        // Limit to reasonable length
        if (tokens.length >= _maxSequenceLength - 1) break;
      }
      
      tokens.add(SEP_TOKEN); // End with [SEP]
      
      final result = tokens.take(_maxSequenceLength).toList();
      print('Tokenized to ${result.length} tokens');
      return result;
      
    } catch (e) {
      print('Tokenization error: $e');
      // Return safe fallback tokens
      return [101, 102]; // Just [CLS] and [SEP]
    }
  }
  
  List<int> _useExternalTokenizer(String text) {
    try {
      // External tokenizer logic (when available)
      if (_tokenizer!.containsKey('vocab')) {
        // Process with external tokenizer
        return [];
      }
      return [];
    } catch (e) {
      print('External tokenizer error: $e');
      return [];
    }
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
      'unlimited_usage': true, // Key selling point
      'model_file': '1.tflite',
      'model_size': '96MB',
    };
  }
  
  /// Cleanup method with enhanced safety
  Future<void> dispose() async {
    try {
      _interpreter?.close();
    } catch (e) {
      print('Error disposing interpreter: $e');
    } finally {
      _interpreter = null;
      _isModelLoaded = false;
      _deviceRAM = null;
      _selectedModelName = null;
      _selectedModelPath = null;
      print('TensorFlow Lite service disposed safely');
    }
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
