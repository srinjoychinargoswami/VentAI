import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class OllamaService {
  static const String baseUrl = 'http://localhost:11434';
  static const Duration timeout = Duration(seconds: 30);
  
  // Singleton pattern for global access
  static final OllamaService _instance = OllamaService._internal();
  factory OllamaService() => _instance;
  OllamaService._internal();

  /// Check if Ollama service is running and accessible
  Future<bool> isServiceRunning() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('Ollama service check failed: $e');
      return false;
    }
  }

  /// Get all available models on the system
  Future<List<String>> getAvailableModels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final models = data?['models'] as List<dynamic>? ?? [];
        
        return models
            .map((model) {
              final modelData = model as Map<String, dynamic>?;
              return modelData?['name']?.toString() ?? '';
            })
            .where((name) => name.isNotEmpty)
            .toList();
      }
    } catch (e) {
      print('Failed to get models: $e');
    }
    return [];
  }

  /// Check if required Gemma models are available
  Future<bool> hasRequiredModels() async {
    final models = await getAvailableModels();
    return models.any((model) => 
      model.contains('gemma3n:e2b') || model.contains('gemma3n:e4b')
    );
  }

  /// Get the best available Gemma model for device specs
  Future<String?> getBestAvailableModel() async {
    final models = await getAvailableModels();
    
    // Priority order: e4b for high-end, e2b for standard
    if (models.any((m) => m.contains('gemma3n:e4b'))) {
      return 'gemma3n:e4b';
    } else if (models.any((m) => m.contains('gemma3n:e2b'))) {
      return 'gemma3n:e2b';
    }
    
    return null; // No Gemma models found
  }

  /// Download a specific model
  Future<bool> downloadModel(String modelName, {Function(String)? onProgress}) async {
    try {
      print('Starting download for $modelName...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/pull'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': modelName}),
      ).timeout(const Duration(minutes: 30)); // Model downloads take time
      
      if (response.statusCode == 200) {
        print('Model $modelName downloaded successfully');
        return true;
      } else {
        print('Download failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Model download error: $e');
      return false;
    }
  }

  /// Generate AI response for emotional support
  Future<String?> generateEmotionalResponse(String userMessage, {String? mood}) async {
    final model = await getBestAvailableModel();
    
    if (model == null) {
      print('No Gemma models available');
      return null;
    }

    try {
      // Create empathetic prompt
      final prompt = _buildEmpatheticPrompt(userMessage, mood);
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.8, // Warm and varied responses
            'top_p': 0.9,
            'max_tokens': 512,
          }
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final aiResponse = data?['response']?.toString();
        
        if (aiResponse != null && aiResponse.trim().isNotEmpty) {
          print('Generated response with $model');
          return aiResponse.trim();
        }
      }
    } catch (e) {
      print('Response generation failed: $e');
    }
    
    return null;
  }

  /// Test if the AI model can generate responses
  Future<bool> testModelGeneration() async {
    final testResponse = await generateEmotionalResponse(
      "Hello, this is a test message",
      mood: "neutral"
    );
    return testResponse != null && testResponse.isNotEmpty;
  }

  /// Build empathetic prompt for emotional support
  String _buildEmpatheticPrompt(String userMessage, String? mood) {
    final moodContext = mood != null ? "The user's current mood is: $mood. " : "";
    
    return """You are Vent AI, a deeply compassionate and attentive emotional support companion skilled in therapeutic communication. I am here for you to talk to about anything that's on your mind. Please respond with empathy and understanding.

${moodContext}User's message: "$userMessage"

Your response guidelines:
- Address the specific emotions, situations, and details the user shared
- Provide longer, more thoughtful responses (4-6 sentences or 2 paragraphs at minimum) when the topic warrants deeper engagement
- Make it clear that you are genuinely here for them and committed to supporting them through their journey
- Suggest gentle, practical coping strategies such as:
  • Deep breathing exercises (4-7-8 breathing, box breathing)
  • Grounding techniques (5-4-3-2-1 sensory method, mindful observation)
  • Taking purposeful breaks and rest when needed and encouraging them to understand breaks are necessary in life
  • Simple mindfulness practices and gentle movement
  • Creating small, manageable daily routines
- Help them understand that mistakes are a part of growing and learning
- Be patient and understanding, and let them know you are there for them.
- Be aware of your tone and language, and avoid any language that could be perceived as dismissive
- Help them understand that taking rest and breaks are necessary in life and that it's okay to not be okay
- Avoid clinical or medical advice - focus on accessible, everyday wellness strategies
- Use reflective listening to validate their feelings and show you truly heard them
- Offer genuine encouragement and hope, emphasizing that small steps can lead to meaningful change
- End with a thoughtful, open-ended question that invites them to share more or reflect deeper

Remember: You are a caring companion who helps users feel heard, understood, and gently guided toward their own inner strength. Respond with warmth, patience, and genuine care in 4-6 sentences or 2 paragraphs at the minimum.


Response:""";
  }

  /// Get comprehensive service status
  Future<Map<String, dynamic>> getServiceStatus() async {
    final isRunning = await isServiceRunning();
    final models = await getAvailableModels();
    final hasModels = await hasRequiredModels();
    final bestModel = await getBestAvailableModel();
    
    return {
      'service_running': isRunning,
      'available_models': models,
      'has_required_models': hasModels,
      'best_model': bestModel,
      'can_generate': isRunning && hasModels,
    };
  }
}

/// Enum for different service states
enum OllamaServiceState {
  notInstalled,
  installed,
  running,
  modelsReady,
  error,
}
