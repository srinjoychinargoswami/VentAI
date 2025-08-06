import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/ollama_manager.dart';
import '../services/voice_emotion_analyzer.dart';

class MultimodalFusionService {
  // Combine text and voice inputs for comprehensive emotional analysis
  static Future<Map<String, dynamic>> fuseMultimodalInputs({
    String? textMessage,
    String? audioPath,
  }) async {
    try {
      // Prepare multimodal data
      final audios = <String>[];
      
      // Convert audio file path to base64 if provided
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
      
      // Get voice emotion analysis if audio is available - WITH TIMEOUT
      Map<String, dynamic>? voiceAnalysis;
      if (audios.isNotEmpty) {
        try {
          voiceAnalysis = await VoiceEmotionAnalyzer.analyzeVoiceEmotion(audios.first)
              .timeout(const Duration(seconds: 15));
          debugPrint('Voice emotion analysis completed: ${voiceAnalysis['emotional_tone']}');
        } on TimeoutException {
          debugPrint('Voice emotion analysis timed out');
        } catch (e) {
          debugPrint('Voice emotion analysis failed: $e');
        }
      }
      
      // Build comprehensive prompt for Gemma 3n model
      final promptBuffer = StringBuffer();
      promptBuffer.writeln('You are Vent AI, an empathetic emotional support companion.');
      promptBuffer.writeln('');
      promptBuffer.writeln('Available inputs:');
      
      if (textMessage != null && textMessage.isNotEmpty) {
        promptBuffer.writeln('- Text message: "$textMessage"');
      }
      if (audios.isNotEmpty) {
        promptBuffer.writeln('- Voice recording: [audio data provided]');
        
        // Add voice emotion context if available
        if (voiceAnalysis != null && voiceAnalysis['status'] == 'success') {
          final emotion = voiceAnalysis['emotional_tone'] ?? 'neutral';
          final confidence = voiceAnalysis['confidence'] ?? 0.5;
          final intensity = voiceAnalysis['intensity'] ?? 5;
          
          promptBuffer.writeln('- Voice analysis detected: $emotion emotional tone (${(confidence * 100).round()}% confidence, intensity: $intensity/10)');
          
          // Add specific guidance based on detected emotion
          if (emotion == 'anxious' || emotion == 'stressed') {
            promptBuffer.writeln('- IMPORTANT: Voice patterns indicate anxiety/stress - provide calming language and breathing techniques');
          } else if (emotion == 'sad' || emotion == 'depressed') {
            promptBuffer.writeln('- IMPORTANT: Voice patterns indicate sadness/depression - provide extra validation and hope');
          } else if (emotion == 'angry') {
            promptBuffer.writeln('- IMPORTANT: Voice patterns indicate frustration/anger - acknowledge feelings and provide grounding techniques');
          }
        }
      }
      
      promptBuffer.writeln('');
      promptBuffer.writeln('Provide a supportive, empathetic response that addresses their emotional state.');
      promptBuffer.writeln('Be warm, understanding, and offer practical emotional support.');
      promptBuffer.writeln('Do not use JSON format - respond naturally as a caring friend.');
      
      //  Use Gemma 3n model directly via Ollama for response generation
      final bestModel = await _getBestAvailableModel();
      
      debugPrint('Sending request to Gemma model: $bestModel');
      
      //  Send request to Gemma with timeout protection
      try {
        final response = await http.post(
          Uri.parse('http://localhost:11434/api/generate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': bestModel,
            'prompt': promptBuffer.toString(),
            'stream': false,
            'options': {
              'temperature': 0.8,
              'top_p': 0.9,
              'num_predict': 300,
            }
          }),
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final gemmaResponse = data['response'] as String? ?? 'I hear you and I\'m here to support you.';
          
          debugPrint('✅ Gemma 3n response received: ${gemmaResponse.substring(0, gemmaResponse.length.clamp(0, 100))}...');
          
          // Return the structured result with actual Gemma response
          final result = {
            'primary_emotion': voiceAnalysis?['emotional_tone'] ?? 'neutral',
            'intensity': voiceAnalysis?['intensity'] ?? 5,
            'confidence': voiceAnalysis?['confidence'] ?? 0.7,
            'crisis_detected': _detectCrisis(gemmaResponse) || _detectCrisis(textMessage ?? ''),
            'voice_emotion_detected': voiceAnalysis?['emotional_tone'] ?? 'none',
            //  Use actual Gemma response instead of hardcoded fallback
            'response_recommendation': gemmaResponse,
            'source': 'gemma3n_ollama',
            'raw_response': gemmaResponse,
          };
          
          // Combine with voice analysis results
          if (voiceAnalysis != null && voiceAnalysis['status'] == 'success') {
            result['voice_analysis'] = voiceAnalysis;
            result['analysis_source'] = 'voice_priority';
          }
          
          // Add metadata about what modalities were processed
          result['modalities_processed'] = {
            'text': textMessage != null && textMessage.isNotEmpty,
            'voice': audios.isNotEmpty,
            'voice_analysis_success': voiceAnalysis?['status'] == 'success',
          };
          result['model_used'] = bestModel;
          
          debugPrint('Voice-enhanced analysis completed with $bestModel');
          return result;
        } else {
          debugPrint('Ollama API error: ${response.statusCode}');
          debugPrint('Response body: ${response.body}');
          throw Exception('API call failed with status ${response.statusCode}');
        }
      } on TimeoutException {
        debugPrint('HTTP request timed out, using fallback');
        return await _provideFallbackAnalysis(textMessage, audioPath);
      }
      
    } catch (e) {
      debugPrint('Voice-enhanced fusion error: $e');
      return await _provideFallbackAnalysis(textMessage, audioPath);
    }
  }
  
  //  Voice-focused method that accepts base64 encoded audio directly
  static Future<Map<String, dynamic>> fuseVoiceAndTextBase64({
    String? textMessage,
    String? audioBase64,
  }) async {
    try {
      // Get voice emotion analysis if audio is available - WITH TIMEOUT
      Map<String, dynamic>? voiceAnalysis;
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        try {
          voiceAnalysis = await VoiceEmotionAnalyzer.analyzeVoiceEmotion(audioBase64)
              .timeout(const Duration(seconds: 15));
          debugPrint('Voice emotion analysis completed: ${voiceAnalysis['emotional_tone']}');
        } on TimeoutException {
          debugPrint('Voice emotion analysis timed out');
        } catch (e) {
          debugPrint('Voice emotion analysis failed: $e');
        }
      }
      
      //  Build proper prompt for Gemma 3n to generate natural response
      final promptBuffer = StringBuffer();
      promptBuffer.writeln('You are Vent AI, a compassionate emotional support companion.');
      promptBuffer.writeln('');
      
      if (textMessage != null && textMessage.isNotEmpty) {
        promptBuffer.writeln('User says: "$textMessage"');
      }
      
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        promptBuffer.writeln('User also provided voice input with the following emotional analysis:');
        
        // Add voice emotion context
        if (voiceAnalysis != null && voiceAnalysis['status'] == 'success') {
          final emotion = voiceAnalysis['emotional_tone'] ?? 'neutral';
          final confidence = voiceAnalysis['confidence'] ?? 0.5;
          final intensity = voiceAnalysis['intensity'] ?? 5;
          
          promptBuffer.writeln('- Voice emotion detected: $emotion (${(confidence * 100).round()}% confidence, intensity: $intensity/10)');
          promptBuffer.writeln('- Voice analysis: ${voiceAnalysis['transcribed_text'] ?? '[voice input processed]'}');
          
          // Emotion-specific guidance for Gemma
          if (emotion == 'anxious' || emotion == 'stressed') {
            promptBuffer.writeln('- Important: I can hear anxiety/stress in their voice - provide calming support and breathing techniques');
          } else if (emotion == 'sad' || emotion == 'depressed') {
            promptBuffer.writeln('- Important: I can hear sadness in their voice - provide extra empathy, validation, and hope');
          } else if (emotion == 'angry') {
            promptBuffer.writeln('- Important: I can hear frustration in their voice - acknowledge their anger and provide grounding techniques');
          }
        }
      }
      
      promptBuffer.writeln('');
      promptBuffer.writeln('Respond as a caring, empathetic friend who truly understands their emotional state.');
      promptBuffer.writeln('Acknowledge what you can "hear" in their voice if applicable.');
      promptBuffer.writeln('Provide genuine emotional support, validation, and practical suggestions.');
      promptBuffer.writeln('Keep your response warm, personal, and under 150 words.');
      
      final bestModel = await _getBestAvailableModel();
      
      debugPrint('Sending voice input to Gemma model: $bestModel');
      
      //  HTTP request with timeout protection - USE GEMMA DIRECTLY
      try {
        final response = await http.post(
          Uri.parse('http://localhost:11434/api/generate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': bestModel,
            'prompt': promptBuffer.toString(),
            'stream': false,
            'options': {
              'temperature': 0.8,
              'top_p': 0.9,
              'num_predict': 200,
            }
          }),
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final gemmaResponse = data['response'] as String? ?? 'I hear you and I\'m here to support you.';
          
          debugPrint('Gemma 3n voice response: ${gemmaResponse.substring(0, gemmaResponse.length.clamp(0, 100))}...');
          
          // Build result with Gemma's actual response
          final result = {
            'primary_emotion': voiceAnalysis?['emotional_tone'] ?? 'neutral',
            'intensity': voiceAnalysis?['intensity'] ?? 5,
            'confidence': voiceAnalysis?['confidence'] ?? 0.7,
            'crisis_detected': _detectCrisis(gemmaResponse) || _detectCrisis(textMessage ?? ''),
            'voice_emotion_detected': voiceAnalysis?['emotional_tone'] ?? 'none',
            // Use actual Gemma-generated response
            'response_recommendation': gemmaResponse,
            'source': 'gemma3n_voice_enhanced',
            'raw_response': gemmaResponse,
          };
          
          // Integrate voice analysis
          if (voiceAnalysis != null && voiceAnalysis['status'] == 'success') {
            result['voice_analysis'] = voiceAnalysis;
            
            // Prefer voice analysis for emotion if confidence is high
            final voiceConfidence = voiceAnalysis['confidence'] ?? 0.0;
            if (voiceConfidence > 0.7) {
              result['primary_emotion'] = voiceAnalysis['emotional_tone'];
              result['confidence'] = voiceConfidence;
              result['analysis_source'] = 'voice_priority';
            }
          }
          
          result['modalities_processed'] = {
            'text': textMessage != null && textMessage.isNotEmpty,
            'voice': audioBase64 != null && audioBase64.isNotEmpty,
            'voice_analysis_success': voiceAnalysis?['status'] == 'success',
          };
          return result;
        } else {
          debugPrint('Ollama API error: ${response.statusCode}');
          throw Exception('API call failed');
        }
      } on TimeoutException {
        debugPrint('HTTP request timed out');
        return await _provideFallbackAnalysis(textMessage, null);
      }
      
    } catch (e) {
      debugPrint('Voice+text fusion error: $e');
      return await _provideFallbackAnalysis(textMessage, null);
    }
  }
  
  // Get best available model dynamically with timeout
  static Future<String> _getBestAvailableModel() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:11434/api/tags'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List? ?? [])
            .map((m) => m['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        
        // Priority order for voice-capable models
        if (models.any((m) => m.contains('gemma3n:e4b'))) {
          return 'gemma3n:e4b';
        } else if (models.any((m) => m.contains('gemma3n:e2b'))) {
          return 'gemma3n:e2b';
        } else if (models.any((m) => m.contains('gemma'))) {
          // Use any available Gemma model
          return models.firstWhere((m) => m.contains('gemma'));
        }
      }
    } on TimeoutException {
      debugPrint('Model list request timed out');
    } catch (e) {
      debugPrint('Failed to get available models: $e');
    }
    
    return 'gemma3n:e2b'; // Safe fallback
  }
  
  // REMOVED: The old _parseMultimodalResponse method that was causing hardcoded responses
  
  // Simple crisis detection helper
  static bool _detectCrisis(String text) {
    final lowerText = text.toLowerCase();
    final crisisKeywords = [
      'suicide', 'kill myself', 'end it all', 'want to die',
      'harm myself', 'hurt myself', 'no point living', 'better off dead'
    ];
    return crisisKeywords.any((keyword) => lowerText.contains(keyword));
  }
  
  // ENHANCED: Voice-focused fallback analysis with timeout protection
  static Future<Map<String, dynamic>> _provideFallbackAnalysis(
    String? textMessage, 
    String? audioPath
  ) async {
    debugPrint('🔄 Providing voice-focused fallback analysis');
    
    // Try voice analysis first if available
    if (audioPath != null) {
      try {
        final audioFile = File(audioPath);
        if (await audioFile.exists()) {
          final audioBytes = await audioFile.readAsBytes();
          final audioBase64 = base64Encode(audioBytes);
          final voiceAnalysis = await VoiceEmotionAnalyzer.analyzeVoiceEmotion(audioBase64)
              .timeout(const Duration(seconds: 10));
          
          if (voiceAnalysis['status'] == 'success') {
            debugPrint('Voice fallback analysis successful');
            return {
              'primary_emotion': voiceAnalysis['emotional_tone'],
              'intensity': voiceAnalysis['intensity'],
              'confidence': voiceAnalysis['confidence'],
              'crisis_detected': false,
              'response_recommendation': _generateVoiceBasedResponse(voiceAnalysis['emotional_tone']),
              'voice_analysis': voiceAnalysis,
              'source': 'voice_fallback',
              'modalities_processed': {
                'text': textMessage != null && textMessage.isNotEmpty,
                'voice': true,
                'voice_analysis_success': true,
              }
            };
          }
        }
      } on TimeoutException {
        debugPrint('Voice fallback analysis timed out');
      } catch (e) {
        debugPrint('Voice fallback analysis failed: $e');
      }
    }
    
    // If we have text, use OllamaManager for text analysis with timeout
    if (textMessage != null && textMessage.isNotEmpty) {
      try {
        final textResponse = await OllamaManager.generateEmpatheticResponse(textMessage)
            .timeout(const Duration(seconds: 20));
        final aiResponse = textResponse['response'] as String? ?? 'I\'m here to support you.';
        final crisisDetected = textResponse['crisisDetected'] as bool? ?? false;
        
        return {
          'primary_emotion': 'neutral',
          'intensity': 5,
          'confidence': 0.6,
          'crisis_detected': crisisDetected,
          'response_recommendation': aiResponse,
          'source': 'ollama_text_fallback',
          'modalities_processed': {
            'text': true,
            'voice': audioPath != null,
            'voice_analysis_success': false,
          }
        };
      } on TimeoutException {
        debugPrint('Text fallback analysis timed out');
      } catch (e) {
        debugPrint('Text fallback also failed: $e');
      }
    }
    
    // Ultimate fallback
    return {
      'primary_emotion': 'neutral',
      'intensity': 5,
      'confidence': 0.3,
      'crisis_detected': false,
      'response_recommendation': 'I want you to know that I\'m here for you. This is a safe space to express yourself, and your feelings matter.',
      'source': 'system_fallback',
      'modalities_processed': {
        'text': textMessage != null && textMessage.isNotEmpty,
        'voice': audioPath != null,
        'voice_analysis_success': false,
      }
    };
  }
  
  static String _generateVoiceBasedResponse(String emotion) {
    switch (emotion) {
      case 'anxious':
        return 'I can hear the anxiety in your voice, and I want you to know that what you\'re feeling is completely valid. Let\'s try some deep breathing together - in for 4, hold for 7, out for 8.';
      case 'sad':
        return 'I can hear the sadness in your voice, and I want you to know that it\'s okay to feel this way. Your emotions are valid, and you don\'t have to carry this alone.';
      case 'stressed':
        return 'I can hear the stress in your voice. It sounds like you\'re under a lot of pressure right now. Let\'s take this one step at a time.';
      case 'angry':
        return 'I can hear the frustration in your voice, and those feelings are completely understandable. It takes courage to reach out when you\'re feeling this way.';
      case 'depressed':
        return 'I can hear that you\'re going through something really difficult right now. I want you to know that I\'m here with you, and your life has value.';
      default:
        return 'I can hear that you\'re reaching out, and I want you to know that I\'m here to listen. Whatever you\'re going through, you don\'t have to face it alone.';
    }
  }
  
  // Check voice-focused capabilities with timeout
  static Future<Map<String, bool>> checkVoiceCapabilities() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:11434/api/tags'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = ((data['models'] as List?) ?? [])
            .map((m) => m['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        
        debugPrint('Available models: $models');
        
        return {
          'text_support': models.any((m) => m.contains('gemma')),
          'voice_support': models.any((m) => m.contains('gemma3n')),
          'voice_analysis_ready': await VoiceEmotionAnalyzer.isReady(),
          'ollama_running': true,
        };
      }
    } on TimeoutException {
      debugPrint('Voice capabilities check timed out');
    } catch (e) {
      debugPrint('Error checking voice capabilities: $e');
    }
    
    return {
      'text_support': false,
      'voice_support': false,
      'voice_analysis_ready': false,
      'ollama_running': false,
    };
  }
  
  // Validate voice-focused inputs
  static Map<String, bool> validateVoiceInputs({
    String? textMessage,
    String? audioPath,
    String? audioBase64,
  }) {
    return {
      'has_text': textMessage != null && textMessage.trim().isNotEmpty,
      'has_audio_path': audioPath != null && audioPath.isNotEmpty,
      'has_audio_base64': audioBase64 != null && audioBase64.isNotEmpty,
      'has_any_input': (textMessage?.trim().isNotEmpty ?? false) ||
                       (audioPath?.isNotEmpty ?? false) ||
                       (audioBase64?.isNotEmpty ?? false),
    };
  }
  
  // qVoice-focused health check with timeout
  static Future<bool> isVoiceServiceHealthy() async {
    try {
      final capabilities = await checkVoiceCapabilities()
          .timeout(const Duration(seconds: 15));
      final voiceReady = await VoiceEmotionAnalyzer.isReady();
      return capabilities['ollama_running'] == true && 
             capabilities['text_support'] == true && 
             voiceReady;
    } on TimeoutException {
      debugPrint('Voice health check timed out');
      return false;
    } catch (e) {
      debugPrint('Voice health check failed: $e');
      return false;
    }
  }
}
