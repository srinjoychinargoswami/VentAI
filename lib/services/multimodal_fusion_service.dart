// lib/services/multimodal_fusion_engine.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/ollama_manager.dart'; 

class MultimodalFusionService {
  //Combine text, voice, and visual inputs for comprehensive analysis
  static Future<Map<String, dynamic>> fuseMultimodalInputs({
    String? textMessage,
    String? audioPath,
    String? imagePath,
  }) async {
    try {
      // Prepare multimodal data
      final images = <String>[];  
      final audios = <String>[];
      
      // Convert file paths to base64 if provided
      if (imagePath != null) {
        try {
          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            images.add(base64Encode(imageBytes));
            debugPrint('Image loaded: ${imageBytes.length} bytes');
          }
        } catch (e) {
          debugPrint('Error reading image file: $e');
        }
      }
      
      if (audioPath != null) {
        try {
          final audioFile = File(audioPath);
          if (await audioFile.exists()) {
            final audioBytes = await audioFile.readAsBytes();
            audios.add(base64Encode(audioBytes));
            debugPrint('🎵 Audio loaded: ${audioBytes.length} bytes');
          }
        } catch (e) {
          debugPrint('Error reading audio file: $e');
        }
      }
      
      // Build comprehensive prompt
      final promptBuffer = StringBuffer();
      promptBuffer.writeln('You are Vent AI, analyzing multimodal emotional input to provide empathetic support.');
      promptBuffer.writeln('');
      promptBuffer.writeln('Available inputs:');
      
      if (textMessage != null && textMessage.isNotEmpty) {
        promptBuffer.writeln('- Text message: "$textMessage"');
      }
      if (audios.isNotEmpty) {
        promptBuffer.writeln('- Audio data: [voice recording provided]');
      }
      if (images.isNotEmpty) {
        promptBuffer.writeln('- Visual data: [image/photo provided]');
      }
      
      promptBuffer.writeln('');
      promptBuffer.writeln('Provide comprehensive emotional analysis in JSON format:');
      promptBuffer.writeln('{');
      promptBuffer.writeln('  "primary_emotion": "detected emotion (happy/sad/angry/anxious/neutral/etc.)",');
      promptBuffer.writeln('  "intensity": 1-10,');
      promptBuffer.writeln('  "confidence": 0.0-1.0,');
      promptBuffer.writeln('  "modality_conflicts": true/false,');
      promptBuffer.writeln('  "crisis_detected": true/false,');
      promptBuffer.writeln('  "response_recommendation": "empathetic response text"');
      promptBuffer.writeln('}');
      
      //  Use dynamic model selection
      final bestModel = await _getBestAvailableModel();
      
      // Prepare request body
      final requestBody = <String, dynamic>{
        'model': bestModel,
        'prompt': promptBuffer.toString(),
        'stream': false,
        'options': {
          'temperature': 0.7,
          'top_p': 0.9,
          'num_predict': 512,
        }
      };
      
      // Add images if available
      if (images.isNotEmpty) {
        requestBody['images'] = images;
      }
      
      debugPrint('Sending multimodal request to $bestModel');
      
      // Send multimodal request to Gemma
      final response = await http.post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 45));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = _parseMultimodalResponse(data['response']);
        
        // Add metadata about what modalities were processed
        result['modalities_processed'] = {
          'text': textMessage != null && textMessage.isNotEmpty,
          'audio': audios.isNotEmpty,
          'visual': images.isNotEmpty,
        };
        result['model_used'] = bestModel;
        
        debugPrint('Multimodal analysis completed with $bestModel');
        return result;
      } else {
        debugPrint('Ollama API error: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception('API call failed with status ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('Multimodal fusion error: $e');
      // Intelligent fallback based on available inputs
      return await _provideFallbackAnalysis(textMessage, audioPath, imagePath);
    }
  }
  
  // Alternative method that accepts base64 encoded data directly
  static Future<Map<String, dynamic>> fuseMultimodalBase64({
    String? textMessage,
    String? audioBase64,
    String? imageBase64,
  }) async {
    try {
      final promptBuffer = StringBuffer();
      promptBuffer.writeln('You are Vent AI analyzing multimodal emotional input.');
      promptBuffer.writeln('');
      promptBuffer.writeln('Available inputs:');
      
      if (textMessage != null && textMessage.isNotEmpty) {
        promptBuffer.writeln('- Text: "$textMessage"');
      }
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        promptBuffer.writeln('- Audio: [audio data provided]');
      }
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        promptBuffer.writeln('- Image: [image data provided]');
      }
      
      promptBuffer.writeln('');
      promptBuffer.writeln('Analyze emotional state and provide JSON response:');
      promptBuffer.writeln('{"primary_emotion": "...", "intensity": 1-10, "confidence": 0.0-1.0, "crisis_detected": true/false, "response_recommendation": "..."}');
      
      final bestModel = await _getBestAvailableModel();
      
      final requestBody = <String, dynamic>{
        'model': bestModel,
        'prompt': promptBuffer.toString(),
        'stream': false,
        'options': {
          'temperature': 0.7,
          'top_p': 0.9,
        }
      };
      
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        requestBody['images'] = [imageBase64];
      }
      
      final response = await http.post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = _parseMultimodalResponse(data['response']);
        result['modalities_processed'] = {
          'text': textMessage != null && textMessage.isNotEmpty,
          'audio': audioBase64 != null && audioBase64.isNotEmpty,
          'visual': imageBase64 != null && imageBase64.isNotEmpty,
        };
        return result;
      }
      
    } catch (e) {
      debugPrint('Multimodal base64 fusion error: $e');
    }
    
    return await _provideFallbackAnalysis(textMessage, null, null);
  }
  
  // FIXED: Get best available model dynamically
  static Future<String> _getBestAvailableModel() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:11434/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List? ?? [])
            .map((m) => m['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        
        // Priority order for multimodal capabilities
        if (models.any((m) => m.contains('gemma3n:e4b'))) {
          return 'gemma3n:e4b';
        } else if (models.any((m) => m.contains('gemma3n:e2b'))) {
          return 'gemma:e2b';
        }
      }
    } catch (e) {
      debugPrint('Failed to get available models: $e');
    }
    
    return 'gemma3n:e2b'; // Safe fallback
  }
  
  static Map<String, dynamic> _parseMultimodalResponse(String response) {
    try {
      // Try to extract JSON from the response
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}') + 1;
      
      if (jsonStart != -1 && jsonEnd > jsonStart) {
        final jsonString = response.substring(jsonStart, jsonEnd);
        final parsed = jsonDecode(jsonString);
        
        return {
          'primary_emotion': parsed['primary_emotion'] ?? parsed['emotion'] ?? 'neutral',
          'intensity': _parseIntensity(parsed['intensity']),
          'confidence': _parseConfidence(parsed['confidence']),
          'modality_conflicts': parsed['modality_conflicts'] ?? parsed['conflicts'] ?? false,
          'crisis_detected': parsed['crisis_detected'] ?? parsed['crisis'] ?? false,
          'response_recommendation': parsed['response_recommendation'] ?? parsed['response'] ?? 
                                    'I hear you and I\'m here to support you.',
          'source': 'gemma_multimodal',
          'raw_response': response,
        };
      }
    } catch (e) {
      debugPrint('JSON parsing failed, analyzing text response: $e');
    }
    
    // Fallback: extract emotion from text response
    return _extractEmotionFromTextResponse(response);
  }
  
  static int _parseIntensity(dynamic value) {
    if (value is int) return value.clamp(1, 10);
    if (value is double) return value.round().clamp(1, 10);
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed?.clamp(1, 10) ?? 5;
    }
    return 5;
  }
  
  static double _parseConfidence(dynamic value) {
    if (value is double) return value.clamp(0.0, 1.0);
    if (value is int) return (value / 10.0).clamp(0.0, 1.0);
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.clamp(0.0, 1.0) ?? 0.7;
    }
    return 0.7;
  }
  
  static Map<String, dynamic> _extractEmotionFromTextResponse(String response) {
    final text = response.toLowerCase();
    
    String emotion = 'neutral';
    int intensity = 5;
    double confidence = 0.5;
    bool crisisDetected = false;
    
    // Enhanced emotion detection
    if (text.contains('happy') || text.contains('joy') || text.contains('excited') || text.contains('positive')) {
      emotion = 'happy';
      intensity = 7;
      confidence = 0.8;
    } else if (text.contains('sad') || text.contains('depressed') || text.contains('down') || text.contains('grief')) {
      emotion = 'sad';
      intensity = 6;
      confidence = 0.8;
    } else if (text.contains('angry') || text.contains('frustrated') || text.contains('mad') || text.contains('rage')) {
      emotion = 'angry';
      intensity = 7;
      confidence = 0.8;
    } else if (text.contains('anxious') || text.contains('worried') || text.contains('nervous') || text.contains('panic')) {
      emotion = 'anxious';
      intensity = 6;
      confidence = 0.8;
    } else if (text.contains('tired') || text.contains('exhausted') || text.contains('weary') || text.contains('drained')) {
      emotion = 'tired';
      intensity = 5;
      confidence = 0.7;
    } else if (text.contains('confused') || text.contains('uncertain') || text.contains('lost')) {
      emotion = 'confused';
      intensity = 4;
      confidence = 0.7;
    } else if (text.contains('calm') || text.contains('peaceful') || text.contains('relaxed')) {
      emotion = 'calm';
      intensity = 3;
      confidence = 0.7;
    }
    
    // Enhanced crisis detection
    final crisisKeywords = [
      'crisis', 'suicide', 'kill myself', 'end it all', 'want to die',
      'harm myself', 'hurt myself', 'no point living', 'better off dead',
      'emergency', 'danger to myself'
    ];
    
    crisisDetected = crisisKeywords.any((keyword) => text.contains(keyword));
    
    return {
      'primary_emotion': emotion,
      'intensity': intensity,
      'confidence': confidence,
      'modality_conflicts': false,
      'crisis_detected': crisisDetected,
      'response_recommendation': _generateContextualResponse(emotion, crisisDetected),
      'source': 'text_analysis_fallback',
    };
  }
  
  static String _generateContextualResponse(String emotion, bool crisisDetected) {
    if (crisisDetected) {
      return '''I'm deeply concerned about you right now. Please reach out for immediate help:

• Call 988 Suicide Crisis Lifeline - 24/7 support
• Text HOME to 741741 Crisis Text Line
• Call 911 for emergency assistance

You matter, and there are people who want to help you through this.''';
    }
    
    switch (emotion) {
      case 'anxious':
        return 'I can sense your anxiety, and I want you to know that what you\'re feeling is completely valid. Let\'s take this one moment at a time. You\'re not alone in this.';
      case 'sad':
        return 'I hear the sadness in what you\'ve shared, and I want you to know that it\'s okay to feel this way. Your emotions are valid, and I\'m here to support you through this difficult time.';
      case 'angry':
        return 'I can feel your frustration and anger, and those feelings are completely understandable. It takes strength to reach out when you\'re feeling this way.';
      case 'tired':
        return 'It sounds like you\'re carrying a heavy burden right now. It\'s okay to feel exhausted - you\'re doing the best you can, and that\'s enough.';
      case 'happy':
        return 'It\'s wonderful to hear some positivity from you! I\'m glad you\'re experiencing these good feelings. Thank you for sharing this moment with me.';
      default:
        return 'Thank you for sharing with me. Whatever you\'re going through, I want you to know that your feelings are valid and important. I\'m here to listen and support you.';
    }
  }
  
  // FIXED: Use OllamaManager for fallback analysis
  static Future<Map<String, dynamic>> _provideFallbackAnalysis(
    String? textMessage, 
    String? audioPath, 
    String? imagePath
  ) async {
    debugPrint('🔄 Providing fallback multimodal analysis');
    
    // If we have text, use OllamaManager for text analysis
    if (textMessage != null && textMessage.isNotEmpty) {
      try {
        final textResponse = await OllamaManager.generateEmpatheticResponse(textMessage);
        final aiResponse = textResponse['response'] as String? ?? 'I\'m here to support you.';
        final crisisDetected = textResponse['crisisDetected'] as bool? ?? false;
        
        return {
          'primary_emotion': 'neutral',
          'intensity': 5,
          'confidence': 0.6,
          'modality_conflicts': false,
          'crisis_detected': crisisDetected,
          'response_recommendation': aiResponse,
          'source': 'ollama_text_fallback',
          'modalities_processed': {
            'text': true,
            'audio': audioPath != null,
            'visual': imagePath != null,
          }
        };
      } catch (e) {
        debugPrint('Text fallback also failed: $e');
      }
    }
    
    // Ultimate fallback with context awareness
    final hasMultipleModalities = [textMessage, audioPath, imagePath]
        .where((input) => input != null && input.isNotEmpty)
        .length > 1;
    
    return {
      'primary_emotion': 'neutral',
      'intensity': 5,
      'confidence': 0.3,
      'modality_conflicts': false,
      'crisis_detected': false,
      'response_recommendation': hasMultipleModalities
          ? 'I can see you\'ve shared multiple forms of communication with me. Even though I\'m having technical difficulties processing everything right now, I want you to know that I\'m here for you and your feelings matter.'
          : 'I want you to know that I\'m here for you, even when technology isn\'t working perfectly. Your feelings matter, and this is a safe space to express yourself.',
      'source': 'system_fallback',
      'modalities_processed': {
        'text': textMessage != null && textMessage.isNotEmpty,
        'audio': audioPath != null,
        'visual': imagePath != null,
      }
    };
  }
  
  // FIXED: Check multimodal capabilities with correct model names
  static Future<Map<String, bool>> checkMultimodalCapabilities() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:11434/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = ((data['models'] as List?) ?? [])
            .map((m) => m['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        
        debugPrint('🔍 Available models: $models');
        
        return {
          'text_support': models.any((m) => m.contains('gemma')),
          'vision_support': models.any((m) => m.contains('gemma') || m.contains('llava')),
          'audio_support': models.any((m) => m.contains('whisper') || m.contains('gemma')),
          'multimodal_fusion': models.any((m) => m.contains('gemma3n:e4b') || m.contains('gemma3n:e2b')),
          'ollama_running': true,
        };
      }
    } catch (e) {
      debugPrint('Error checking multimodal capabilities: $e');
    }
    
    return {
      'text_support': false,
      'vision_support': false,
      'audio_support': false,
      'multimodal_fusion': false,
      'ollama_running': false,
    };
  }
  
  // ADDED: Utility method to validate input data
  static Map<String, bool> validateInputs({
    String? textMessage,
    String? audioPath,
    String? imagePath,
    String? audioBase64,
    String? imageBase64,
  }) {
    return {
      'has_text': textMessage != null && textMessage.trim().isNotEmpty,
      'has_audio_path': audioPath != null && audioPath.isNotEmpty,
      'has_image_path': imagePath != null && imagePath.isNotEmpty,
      'has_audio_base64': audioBase64 != null && audioBase64.isNotEmpty,
      'has_image_base64': imageBase64 != null && imageBase64.isNotEmpty,
      'has_any_input': (textMessage?.trim().isNotEmpty ?? false) ||
                       (audioPath?.isNotEmpty ?? false) ||
                       (imagePath?.isNotEmpty ?? false) ||
                       (audioBase64?.isNotEmpty ?? false) ||
                       (imageBase64?.isNotEmpty ?? false),
    };
  }
  
  // ADDED: Health check method
  static Future<bool> isServiceHealthy() async {
    try {
      final capabilities = await checkMultimodalCapabilities();
      return capabilities['ollama_running'] == true && capabilities['text_support'] == true;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }
}
