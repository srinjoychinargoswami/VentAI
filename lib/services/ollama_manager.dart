import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class OllamaManager {
  static Process? _ollamaProcess;
  static bool _isInitialized = false;
  static String? _ollamaPath;
  static Timer? _healthCheckTimer;
  static Timer? _keepAliveTimer;
  static bool _serviceRunning = false;
  
  // Smart caching variables
  static Map<String, bool> _modelDownloadStatus = {};
  static bool _modelsPersistentlyStored = false;
  
  /// Official Ollama download URL
  static const String _ollamaDownloadUrl = 'https://ollama.com/download/OllamaSetup.exe';
  
  /// PUBLIC GETTERS
  static bool get isInitialized => _isInitialized;
  static bool get isServiceRunning => _serviceRunning;
  
  /// Initialize with auto-download capability - FORCE REINSTALL NOW ENABLED BY DEFAULT
  static Future<bool> initialize({bool forceReinstall = true}) async {
    // **ENHANCED**: Force reinstall is now enabled by default
    if (forceReinstall) {
      print('🔄 Force reinstall enabled - removing existing Ollama installation...');
      await cleanupAllData();
      _isInitialized = false;
      _ollamaPath = null;
    }

    if (_isInitialized && !forceReinstall) return true;

    try {
      print('🚀 Initializing Ollama with auto-installation (force reinstall enabled)...');
      
      // Check if Ollama is already installed on system
      if (await _isOllamaInstalled()) {
        print('Ollama found on system PATH');
        _ollamaPath = await _findOllamaExecutablePath();
      } else {
        print('Ollama not found - starting auto-installation...');
        final installSuccess = await _downloadAndInstallToUserPath();
        if (!installSuccess) {
          print('Failed to auto-install Ollama');
          return false;
        }
        _ollamaPath = await _findOllamaExecutablePath();
      }
      
      // Clean any orphaned processes
      await _killOrphanedOllamaProcesses();
      
      // Start persistent service
      final serviceStarted = await startPersistentService();
      if (!serviceStarted) {
        print('Failed to start Ollama service');
        return false;
      }
      
      // Ensure models are available using smart caching
      final modelsReady = await ensureModelsAvailable();
      if (modelsReady) {
        print('All models cached and ready for use');
      } else {
        print('Some models may not be available, but continuing...');
      }
      
      _isInitialized = true;
      print('🎉 Ollama ready with smart caching and persistent service!');
      return true;
      
    } catch (e) {
      print('❌ Failed to initialize Ollama: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// **NEW**: Trigger a fresh reinstall of Ollama from the official website
  static Future<bool> triggerFreshInstall() async {
    print('🔄 Triggering fresh Ollama installation from website...');
    return await initialize(forceReinstall: true);
  }

  /// **ENHANCED**: Download installer to user-accessible path and install
  static Future<bool> _downloadAndInstallToUserPath() async {
    try {
      print('📥 Downloading Ollama installer to user-accessible path...');
      
      // Get user's Downloads directory (most accessible for users)
      Directory? downloadsDir;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadsDir = Directory(path.join(userProfile, 'Downloads'));
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      // Fallback to application documents directory
      downloadsDir ??= await getApplicationDocumentsDirectory();

      if (!await downloadsDir.exists()) {
        print('❌ Could not access Downloads directory');
        return false;
      }

      final installerPath = path.join(downloadsDir.path, 'OllamaSetup_VentAI.exe');
      
      print('📍 Download location: $installerPath');
      
      // Download the official installer
      final response = await http.get(Uri.parse(_ollamaDownloadUrl));
      if (response.statusCode != 200) {
        print('❌ Failed to download installer: ${response.statusCode}');
        return false;
      }
      
      // Save installer to user-accessible path
      final installerFile = File(installerPath);
      await installerFile.writeAsBytes(response.bodyBytes);
      print('✅ Installer saved to Downloads folder (${response.bodyBytes.length} bytes)');
      
      // Run installer from the Downloads folder
      print('🔧 Running Ollama installer from: $installerPath');
      final installResult = await Process.run(
        installerPath,
        ['/S'], // Silent install flag
        runInShell: true,
      );
      
      if (installResult.exitCode == 0) {
        print('✅ Ollama installer completed successfully');
        
        // Wait for installation to settle
        await Future.delayed(const Duration(seconds: 20));
        
        // Verify installation
        if (await _isOllamaInstalled()) {
          // Clean up installer (optional - user can keep it)
          try {
            await installerFile.delete();
            print('🧹 Cleaned up installer file from Downloads');
          } catch (e) {
            print('💡 Installer file kept in Downloads folder for user reference');
          }
          return true;
        } else {
          print('⚠️ Installation completed but Ollama not detected');
          return false;
        }
      } else {
        print('❌ Installer failed with exit code: ${installResult.exitCode}');
        print('Error output: ${installResult.stderr}');
        return false;
      }
      
    } catch (e) {
      print('❌ Download and install to user path failed: $e');
      return false;
    }
  }

  /// **NEW**: Direct download and install from website to user path (alternative method)
  static Future<bool> downloadAndInstallFromWebsite() async {
    return await _downloadAndInstallToUserPath();
  }

  /// Check if Ollama is installed on the system
  static Future<bool> _isOllamaInstalled() async {
    try {
      // Try to run 'ollama --version' to check if it's in PATH
      final result = await Process.run('ollama', ['--version']);
      if (result.exitCode == 0) {
        print('Ollama version: ${result.stdout}');
        return true;
      }
    } catch (e) {
      print('🔍 Ollama not found in PATH: $e');
    }
    
    // Check common installation locations
    final commonPaths = [
      r'C:\Program Files\Ollama\ollama.exe',
      r'C:\Program Files (x86)\Ollama\ollama.exe',
    ];
    
    // Add user-specific path
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      commonPaths.add(path.join(userProfile, 'AppData', 'Local', 'Programs', 'Ollama', 'ollama.exe'));
    }
    
    for (String checkPath in commonPaths) {
      if (await File(checkPath).exists()) {
        print('Found Ollama at: $checkPath');
        _ollamaPath = checkPath;
        return true;
      }
    }
    
    return false;
  }

  /// Auto-download and install Ollama from official source (legacy method)
  static Future<bool> _autoInstallOllama() async {
    // Redirect to the enhanced method
    return await _downloadAndInstallToUserPath();
  }

  /// Find Ollama executable path
  static Future<String?> _findOllamaExecutablePath() async {
    if (_ollamaPath != null) return _ollamaPath;
    
    // Enhanced search with more locations
    final possiblePaths = [
      // User profile locations
      path.join(Platform.environment['USERPROFILE'] ?? '', 'AppData', 'Local', 'Programs', 'Ollama', 'ollama.exe'),
      path.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Programs', 'Ollama', 'ollama.exe'),
      
      // System-wide locations
      r'C:\Program Files\Ollama\ollama.exe',
      r'C:\Program Files (x86)\Ollama\ollama.exe',
      
      // Check PATH
      'ollama',
    ];
    
    for (String checkPath in possiblePaths) {
      try {
        if (checkPath == 'ollama') {
          // Test PATH availability
          final result = await Process.run('where', ['ollama']);
          if (result.exitCode == 0) {
            final pathResult = result.stdout.toString().trim();
            if (pathResult.isNotEmpty) {
              _ollamaPath = pathResult.split('\n').first;
              print('✅ Found Ollama via PATH: $_ollamaPath');
              return _ollamaPath;
            }
          }
        } else {
          // Test direct file path
          if (await File(checkPath).exists()) {
            _ollamaPath = checkPath;
            print('✅ Found Ollama at: $_ollamaPath');
            return _ollamaPath;
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    print('❌ Ollama executable not found in any location');
    return null;
  }

  /// Start Ollama as a persistent background service
  static Future<bool> startPersistentService() async {
    if (_serviceRunning && _ollamaProcess != null) {
      print('Ollama service already running');
      return true;
    }

    if (_ollamaPath == null) {
      print('Ollama executable path not set');
      return false;
    }

    try {
      print('Starting persistent Ollama service...');
      
      _ollamaProcess = await Process.start(
        _ollamaPath!,
        ['serve'],
        mode: ProcessStartMode.detached,
        runInShell: true, // Use shell execution for better compatibility
      );

      // Wait for service to be ready
      await _waitForServiceReady();
      
      _serviceRunning = true;
      _startHealthMonitoring();
      _startModelKeepAlive();
      
      print('Persistent Ollama service started successfully');
      return true;
      
    } catch (e) {
      print('Error starting Ollama service: $e');
      return false;
    }
  }

  /// Monitor service health and restart if needed
  static void _startHealthMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 120), (timer) async {
      final isHealthy = await _checkServiceHealth();
      if (!isHealthy && _serviceRunning) {
        print('Ollama service health check failed - attempting restart');
        await _restartService();
      } else if (isHealthy) {
        print('Ollama service health check passed');
      }
    });
  }

  /// Check if Ollama service is responding
  static Future<bool> _checkServiceHealth() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:11434'),
      ).timeout(const Duration(seconds: 15));
      
      return response.statusCode == 200 && 
             response.body.contains('Ollama is running');
    } catch (e) {
      print('🩺 Health check failed: $e');
      return false;
    }
  }

  /// Restart service if it dies
  static Future<void> _restartService() async {
    print('Restarting Ollama service...');
    await _stopService();
    await Future.delayed(const Duration(seconds: 3));
    await startPersistentService();
  }

  /// Stop the Ollama service cleanly
  static Future<void> _stopService() async {
    try {
      print('Stopping Ollama service...');
      
      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;
      _keepAliveTimer?.cancel();
      _keepAliveTimer = null;
      
      if (_ollamaProcess != null) {
        _ollamaProcess!.kill(ProcessSignal.sigterm);
        
        try {
          await _ollamaProcess!.exitCode.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              _ollamaProcess!.kill(ProcessSignal.sigkill);
              return -1;
            }
          );
        } catch (e) {
          print('Error during process shutdown: $e');
        }
        
        _ollamaProcess = null;
      }
      
      _serviceRunning = false;
      print('Ollama service stopped cleanly');
    } catch (e) {
      print('Error stopping Ollama service: $e');
    }
  }

  /// Ensure service is running before API calls
  static Future<bool> ensureServiceRunning() async {
    if (!_serviceRunning) {
      print('Service not running, attempting to start...');
      return await startPersistentService();
    }
    
    final isHealthy = await _checkServiceHealth();
    if (!isHealthy) {
      print('Service unhealthy, restarting...');
      await _restartService();
      return _serviceRunning;
    }
    
    return true;
  }

  /// Ensure models are available and cached properly
  static Future<bool> ensureModelsAvailable() async {
    try {
      print('Checking model availability and cache status...');
      
      const requiredModels = ['gemma3n:e2b', 'gemma3n:e4b'];
      
      for (String modelName in requiredModels) {
        if (await _isModelCached(modelName)) {
          print('Model $modelName already cached and available');
          _modelDownloadStatus[modelName] = true;
          continue;
        }
        
        print('Model $modelName not found, downloading...');
        _modelDownloadStatus[modelName] = false;
        
        final downloadSuccess = await _downloadModelWithProgressTracking(modelName);
        if (downloadSuccess) {
          _modelDownloadStatus[modelName] = true;
          print('Model $modelName downloaded and cached successfully');
        } else {
          print('Failed to download model $modelName');
          return false;
        }
      }
      
      final allModelsReady = await _verifyAllModelsReady(requiredModels);
      if (allModelsReady) {
        _modelsPersistentlyStored = true;
        print('All models cached and ready for use');
      }
      
      return allModelsReady;
      
    } catch (e) {
      print('Error ensuring models available: $e');
      return false;
    }
  }

  /// Check if specific model exists in local cache
  static Future<bool> _isModelCached(String modelName) async {
    try {
      final models = await getAvailableModels();
      final isAvailable = models.any((m) => m.contains(modelName));
      
      if (isAvailable) {
        print('Model $modelName found in cache');
        return true;
      } else {
        print('Model $modelName not found in cache');
        return false;
      }
    } catch (e) {
      print('Error checking model cache: $e');
      return false;
    }
  }

  /// Download model with detailed progress tracking
  static Future<bool> _downloadModelWithProgressTracking(String model) async {
    try {
      print('Starting download: $model');
      
      final process = await Process.start(_ollamaPath!, ['pull', model]);
      
      process.stdout.transform(utf8.decoder).listen((data) {
        final progressMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|MB|GB)').firstMatch(data);
        if (progressMatch != null) {
          final progress = progressMatch.group(1);
          print('$model download progress: $progress');
        }
        
        if (data.contains('success') || data.contains('completed')) {
          print('$model download completed successfully');
        }
      });
      
      process.stderr.transform(utf8.decoder).listen((data) {
        if (data.trim().isNotEmpty) {
          print('$model download warning: $data');
        }
      });
      
      final exitCode = await process.exitCode;
      
      if (exitCode == 0) {
        print('$model downloaded successfully');
        
        await Future.delayed(const Duration(seconds: 2));
        final isNowAvailable = await _isModelCached(model);
        
        if (isNowAvailable) {
          print('$model verified and ready for use');
          return true;
        } else {
          print('$model downloaded but not immediately available');
          return false;
        }
      } else {
        print('$model download failed with exit code: $exitCode');
        return false;
      }
      
    } catch (e) {
      print('Error downloading $model: $e');
      return false;
    }
  }

  /// Verify all required models are ready
  static Future<bool> _verifyAllModelsReady(List<String> requiredModels) async {
    try {
      final availableModels = await getAvailableModels();
      
      for (String requiredModel in requiredModels) {
        if (!availableModels.any((m) => m.contains(requiredModel))) {
          print('Required model $requiredModel not available');
          return false;
        }
      }
      
      print('All required models verified and ready');
      return true;
      
    } catch (e) {
      print('Error verifying models: $e');
      return false;
    }
  }

  /// Start model keep-alive with intelligent caching
  static void _startModelKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 3), (timer) async {
      try {
        final bestModel = await getBestAvailableModel();
        
        await http.post(
          Uri.parse('http://localhost:11434/api/generate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': bestModel,
            'prompt': 'ping',
            'stream': false,
            'options': {
              'num_predict': 1,
              'temperature': 0.1,
            }
          }),
        ).timeout(const Duration(seconds: 10));
        
        print('Model keep-alive successful ($bestModel)');
        
      } catch (e) {
        print('Model keep-alive failed: $e');
        if (_serviceRunning) {
          print('Attempting service restart...');
          await _restartService();
        }
      }
    });
  }

  /// Get model cache statistics
  static Future<Map<String, dynamic>> getModelCacheInfo() async {
    try {
      final models = await getAvailableModels();
      final requiredModels = ['gemma3n:e2b', 'gemma3n:e4b'];
      
      return {
        'totalModels': models.length,
        'availableModels': models,
        'requiredModels': requiredModels,
        'allRequiredAvailable': requiredModels.every(
          (required) => models.any((available) => available.contains(required))
        ),
        'cacheStatus': _modelsPersistentlyStored ? 'ready' : 'incomplete',
        'downloadStatus': _modelDownloadStatus,
      };
    } catch (e) {
      print('Error getting cache info: $e');
      return {
        'totalModels': 0,
        'availableModels': [],
        'requiredModels': ['gemma3n:e2b', 'gemma3n:e4b'],
        'allRequiredAvailable': false,
        'cacheStatus': 'error',
        'downloadStatus': {},
      };
    }
  }

  /// Wait for service readiness
  static Future<void> _waitForServiceReady() async {
    print('Waiting for Ollama service to be ready...');
    
    for (int i = 0; i < 30; i++) {
      try {
        final response = await http.get(
          Uri.parse('http://localhost:11434/api/tags')
        ).timeout(const Duration(seconds: 2));
        
        if (response.statusCode == 200) {
          print('Ollama service is ready');
          return;
        }
      } catch (e) {
        // Continue waiting
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    
    throw Exception('Ollama service failed to start within 30 seconds');
  }

  /// Get best model based on device specs
  static Future<String> getBestAvailableModel() async {
    final models = await getAvailableModels();
    
    int estimatedRAM = 8;
    
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'wmic', 
          ['computersystem', 'get', 'TotalPhysicalMemory'], 
          runInShell: true
        );
        final output = result.stdout?.toString() ?? '';
        
        final RegExp ramRegex = RegExp(r'\d+');
        final match = ramRegex.firstMatch(output.replaceAll('TotalPhysicalMemory', ''));
        if (match != null) {
          final ramBytes = int.tryParse(match.group(0) ?? '');
          if (ramBytes != null) {
            estimatedRAM = (ramBytes / (1024 * 1024 * 1024)).round();
          }
        }
      }
    } catch (e) {
      print('Could not detect RAM, using default model selection: $e');
    }
    
    print('Estimated RAM: ${estimatedRAM}GB');
    
    if (models.any((m) => m.contains('gemma3n:e4b')) && estimatedRAM >= 12) {
      print('Using gemma3n:e4b for high-spec device');
      return 'gemma3n:e4b';
    } else if (models.any((m) => m.contains('gemma3n:e2b'))) {
      print('Using gemma3n:e2b for standard device');
      return 'gemma3n:e2b';
    }
    
    return 'gemma3n:e2b';
  }

  /// Generate empathetic response with service health check
  static Future<Map<String, dynamic>> generateEmpatheticResponse(String message, {String? model}) async {
    print('Generating response for: "${message.length > 50 ? message.substring(0, 50) + "..." : message}"');
    
    if (!_isInitialized) {
      await initialize();
    }

    final serviceReady = await ensureServiceRunning();
    if (!serviceReady) {
      print('Ollama service not available, using fallback');
      return _generateFallbackResponse(message);
    }

    final selectedModel = model ?? await getBestAvailableModel();

    try {
      final response = await http.post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': selectedModel,
          'prompt': _buildEmpatheticPrompt(message),
          'stream': false,
          'options': {
            'temperature': 0.8,
            'top_p': 0.9,
          }
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['response']?.toString().trim() ?? '';
        
        if (aiResponse.isNotEmpty) {
          print('Ollama success with $selectedModel: ${aiResponse.substring(0, aiResponse.length > 50 ? 50 : aiResponse.length)}...');
          return {
            'response': aiResponse,
            'source': 'ollama_$selectedModel',
            'mood': 'neutral',
            'crisisDetected': _detectCrisis(message),
            'copingStrategies': ['Take deep breaths', 'Stay present', 'You matter'],
          };
        }
      } else {
        print('Ollama returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating response: $e');
    }

    return _generateFallbackResponse(message);
  }

  /// Generate fallback response when service is unavailable
  static Map<String, dynamic> _generateFallbackResponse(String message) {
    print('Using intelligent fallback response');
    final fallbackResponse = _getIntelligentFallback(message);
    
    return {
      'response': fallbackResponse,
      'source': 'intelligent_fallback',
      'mood': 'neutral',
      'crisisDetected': _detectCrisis(message),
      'copingStrategies': ['Take deep breaths', 'Stay present', 'You matter'],
    };
  }

  /// Build empathetic prompt
  static String _buildEmpatheticPrompt(String message) {
    return '''You are Vent AI, a compassionate emotional support companion. Someone has shared: "$message"

Respond with warmth, empathy, and understanding. Acknowledge their feelings and provide gentle, supportive guidance. Keep your response caring but concise (2-3 sentences).''';
  }

  /// Detect crisis keywords
  static bool _detectCrisis(String message) {
    final lowered = message.toLowerCase();
    final crisisWords = [
      'suicide', 'kill myself', 'end it all', 'want to die', 
      'harm myself', 'hurt myself', 'can\'t go on', 'no point living'
    ];
    return crisisWords.any((word) => lowered.contains(word));
  }

  /// Intelligent fallback responses based on emotional content
  static String _getIntelligentFallback(String message) {
    final lowered = message.toLowerCase();
    
    if (_detectCrisis(message)) {
      return '''I'm really concerned about you right now. Please reach out for help immediately:

• Call 988 Suicide Crisis Lifeline - 24/7 support
• Text HOME to 741741 Crisis Text Line
• Call 911 for emergency assistance

Your life has value, and there are people who want to help you through this.''';
    }
    
    if (lowered.contains('anxious') || lowered.contains('anxiety') || lowered.contains('worried')) {
      return '''I can sense you're feeling anxious right now. That's a really difficult experience, and your feelings are completely valid. Try taking slow, deep breaths - in for 4 counts, hold for 4, out for 4.

What has been weighing on your mind lately?''';
    }
    
    if (lowered.contains('sad') || lowered.contains('depressed') || lowered.contains('down')) {
      return '''I hear that you're going through a tough time, and I want you to know that your feelings are completely valid. It takes courage to reach out when you're feeling this way.

What has been the hardest part for you today?''';
    }
    
    if (lowered.contains('lonely') || lowered.contains('alone')) {
      return '''Feeling lonely can be so isolating and painful. I'm here with you right now, and you're not alone in this moment.

Is there someone in your life you feel comfortable reaching out to?''';
    }
    
    return '''Thank you for sharing with me. I can hear that you're going through something difficult, and I want you to know that your feelings are valid and important.

This is a safe space where you can express yourself freely. What would feel most helpful for you right now?''';
  }

  /// Get available models with correct parsing
  static Future<List<String>> getAvailableModels() async {
    try {
      final result = await Process.run(_ollamaPath!, ['list']);
      final output = result.stdout?.toString() ?? '';
      return output.split('\n')
          .where((line) => line.contains('gemma3n:'))
          .map((line) => line.split(' ')[0])
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Shutdown service with proper cleanup
  static Future<void> shutdown() async {
    print('Shutting down Ollama with cache preservation...');
    
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    
    await _stopService();
    await _killOrphanedOllamaProcesses();
    
    _isInitialized = false;
    
    print('Ollama shutdown complete - cache preserved');
  }

  /// Kill orphaned processes
  static Future<void> _killOrphanedOllamaProcesses() async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/IM', 'ollama.exe'], runInShell: true);
        print('Cleaned orphaned processes');
      }
    } catch (e) {
      // Ignore errors - processes might not be running
    }
  }

  /// Clean up for app startup
  static Future<void> cleanupOrphanedProcesses() async {
    await _killOrphanedOllamaProcesses();
  }

  /// Complete data cleanup
  static Future<void> cleanupAllData() async {
    print('🧹 Performing cleanup...');
    
    await shutdown();
    
    try {
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final systemDir = Directory(path.join(userProfile, '.ollama'));
          if (await systemDir.exists()) {
            await systemDir.delete(recursive: true);
            print('Deleted system .ollama directory');
          }
        }
      }
    } catch (e) {
      print('Cleanup errors (continuing): $e');
    }

    _isInitialized = false;
    _ollamaPath = null;
    _ollamaProcess = null;
  }

  /// Reset for testing
  static void resetForTesting() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    _isInitialized = false;
    _serviceRunning = false;
    _ollamaPath = null;
    _ollamaProcess = null;
    _modelDownloadStatus.clear();
    _modelsPersistentlyStored = false;
    print('Reset for testing');
  }
}
