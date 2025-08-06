import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../services/ollama_service.dart';

class VisualEmotionService {
  static final _picker = ImagePicker();
  
  // Capture image and analyze with Gemma 3n vision
  static Future<Map<String, dynamic>> analyzeVisualEmotion() async {
    try {
      // Capture image from camera or gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front, // Selfie for emotion
      );
      
      if (image != null) {
        return await _sendImageToGemma(image.path);
      }
    } catch (e) {
      print('Visual analysis error: $e');
    }
    
    return {'emotion': 'neutral', 'confidence': 0.0};
  }
  
  // Alternative method for gallery selection
  static Future<Map<String, dynamic>> analyzeFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      
      if (image != null) {
        return await _sendImageToGemma(image.path);
      }
    } catch (e) {
      print('Gallery analysis error: $e');
    }
    
    return {'emotion': 'neutral', 'confidence': 0.0};
  }
  
  static Future<Map<String, dynamic>> _sendImageToGemma(String imagePath) async {
    try {
      // Read image as base64
      final imageBytes = await File(imagePath).readAsBytes();
      final imageBase64 = base64Encode(imageBytes);
      
      // Send to Ollama with Gemma 3n vision capabilities
      final response = await http.post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'gemma3n:e2b', // Use e2b for most compatibility, e4b if you have it
          'prompt': '''Analyze the facial expression and body language in this image for emotional state.
          
Focus on:
1. Facial expression (eyes, mouth, eyebrows)
2. Overall body posture and gestures  
3. Emotional state (happy, sad, anxious, angry, confused, tired, neutral)
4. Emotional intensity (1-10 scale)
5. Any signs of distress or crisis

Respond in JSON format: {"emotion": "...", "intensity": 7, "confidence": 0.8, "facial_features": "...", "crisis_detected": false}''',
          'images': [imageBase64],
          'stream': false,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseVisualResponse(data['response']);
      } else {
        print('Ollama API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Gemma vision analysis failed: $e');
    }
    
    return {'emotion': 'neutral', 'confidence': 0.5};
  }
  
  // Parse the JSON response from Gemma 3n
  static Map<String, dynamic> _parseVisualResponse(String response) {
    try {
      // Try to parse JSON response directly
      final parsed = jsonDecode(response);
      return {
        'emotion': parsed['emotion'] ?? 'neutral',
        'intensity': parsed['intensity'] ?? 5,
        'confidence': parsed['confidence'] ?? 0.5,
        'facial_features': parsed['facial_features'] ?? 'Not specified',
        'crisis_detected': parsed['crisis_detected'] ?? false,
        'source': 'gemma3n_vision'
      };
    } catch (e) {
      // If JSON parsing fails, try to extract emotion from text response
      print('JSON parsing failed, analyzing text: $e');
      return _extractEmotionFromText(response);
    }
  }
  
  // Fallback method to extract emotion from text response
  static Map<String, dynamic> _extractEmotionFromText(String response) {
    final text = response.toLowerCase();
    
    String emotion = 'neutral';
    double confidence = 0.3;
    int intensity = 5;
    bool crisisDetected = false;
    
    // Detect emotions from text
    if (text.contains('happy') || text.contains('joy') || text.contains('smile')) {
      emotion = 'happy';
      confidence = 0.7;
      intensity = 7;
    } else if (text.contains('sad') || text.contains('depressed') || text.contains('crying')) {
      emotion = 'sad';
      confidence = 0.7;
      intensity = 6;
    } else if (text.contains('angry') || text.contains('mad') || text.contains('frustrated')) {
      emotion = 'angry';
      confidence = 0.7;
      intensity = 7;
    } else if (text.contains('anxious') || text.contains('worried') || text.contains('stress')) {
      emotion = 'anxious';
      confidence = 0.7;
      intensity = 6;
    } else if (text.contains('tired') || text.contains('exhausted') || text.contains('fatigue')) {
      emotion = 'tired';
      confidence = 0.6;
      intensity = 5;
    }
    
    // Check for crisis indicators
    if (text.contains('distress') || text.contains('crisis') || text.contains('harm')) {
      crisisDetected = true;
    }
    
    return {
      'emotion': emotion,
      'intensity': intensity,
      'confidence': confidence,
      'facial_features': 'Extracted from text analysis',
      'crisis_detected': crisisDetected,
      'source': 'text_analysis_fallback'
    };
  }
  
  // Check if vision analysis is available
  static Future<bool> isVisionAvailable() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:11434/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List).map((m) => m['name']).toList();
        // Check for vision-capable models
        return models.any((model) => 
          model.contains('gemma3n:e4b') || 
          model.contains('gemma3n:e2b') ||
          model.contains('llava') ||
          model.contains('vision')
        );
      }
    } catch (e) {
      print('Error checking vision availability: $e');
    }
    return false;
  }
  
  // Get available vision models
  static Future<List<String>> getAvailableVisionModels() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:11434/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List).map((m) => m['name'].toString()).toList();
        return models.where((model) => 
          model.contains('gemma3n') || 
          model.contains('llava') ||
          model.contains('vision')
        ).toList();
      }
    } catch (e) {
      print('Error getting vision models: $e');
    }
    return [];
  }
}
