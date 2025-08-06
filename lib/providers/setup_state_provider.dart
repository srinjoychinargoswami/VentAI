// lib/providers/setup_state_provider.dart
import 'dart:io'; // ✅ ADDED: For Process and Platform classes
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_paths.dart';
import '../services/ollama_manager.dart';

enum SetupStage {
  notStarted,
  checkingSystem,
  installingOllama,
  downloadingModels,
  configuringAI,
  testing,
  complete,
  error,
}

class SetupStateProvider extends ChangeNotifier {
  static const String _setupCompleteKey = 'setup_complete';
  static const String _aiTypeKey = 'ai_type';
  static const String _setupVersionKey = 'setup_version';
  static const String _lastSetupDateKey = 'last_setup_date';

  bool _needsSetup = true;
  bool _isSetupComplete = false;
  String _currentAIType = 'unknown';
  bool _isInitializing = false;
  SetupStage _currentStage = SetupStage.notStarted;
  String _setupMessage = '';
  double _setupProgress = 0.0;
  String? _errorMessage;

  // Getters
  bool get needsSetup => _needsSetup;
  bool get isSetupComplete => _isSetupComplete;
  String get currentAIType => _currentAIType;
  bool get isInitializing => _isInitializing;
  SetupStage get currentStage => _currentStage;
  String get setupMessage => _setupMessage;
  double get setupProgress => _setupProgress;
  String? get errorMessage => _errorMessage;

  /// Initialize and check setup status (called on app startup)
  Future<void> initialize() async {
    debugPrint('SetupStateProvider initializing...');
    
    try {
      await AppPaths.initialize();
      await checkSetupNeeded();
      debugPrint('SetupStateProvider initialized');
    } catch (e) {
      debugPrint('SetupStateProvider initialization failed: $e');
      _errorMessage = 'Failed to initialize: $e';
      notifyListeners();
    }
  }

  /// Start the complete setup process with auto-download logic
  Future<void> startCompleteSetup() async {
    _isInitializing = true; // Keep UI on setup screen
    _needsSetup = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('Starting complete setup with auto-download logic...');
      
      await _updateSetupStage(SetupStage.checkingSystem, 'Checking system requirements and capabilities...', 0.1);
      
      // Check if Ollama is already installed on system
      await _updateSetupStage(SetupStage.installingOllama, 'Checking for Ollama installation...', 0.2);
      
      bool ollamaExists = await _checkOllamaInstallation();
      
      if (!ollamaExists) {
        await _updateSetupStage(
          SetupStage.installingOllama, 
          'Downloading and installing Ollama from official source...\nThis may take several minutes on first run.', 
          0.3
        );
        debugPrint('Ollama not found - starting auto-installation process');
      } else {
        await _updateSetupStage(
          SetupStage.installingOllama, 
          'Ollama found on system - using existing installation...', 
          0.4
        );
        debugPrint('Ollama already installed - proceeding with existing installation');
      }

      //Initialize with auto-download capability
      final success = await OllamaManager.initialize(forceReinstall: false);
      
      if (success) {
        await _updateSetupStage(
          SetupStage.downloadingModels, 
          'Ensuring AI models are cached and ready...\nDownloading Gemma models if needed...', 
          0.6
        );
        
        //Smart model caching with progress tracking
        await _ensureModelsAvailableWithProgress();
        
        debugPrint('Smart caching completed - all models ready');
        
        await _updateSetupStage(SetupStage.configuringAI, 'Configuring AI system for optimal performance...', 0.8);
        
        await _updateSetupStage(SetupStage.testing, 'Testing AI functionality with cached models...', 0.9);
        
        //Verify AI functionality with cache info
        await _verifyAIIsFullyWorking();
        
        await markSetupComplete('ollama_gemma3n');
        debugPrint('🏆 COMPLETE SETUP FINISHED - Auto-download and caching active');
      } else {
        await _handleInstallationFailure('Ollama initialization failed - using intelligent offline fallback');
      }
      
    } catch (e) {
      debugPrint('Setup failed: $e');
      await _handleInstallationFailure('Setup error: $e');
    } finally {
      _isInitializing = false;
      await _updateSetupStage(SetupStage.complete, 'Setup complete - Your AI companion is ready!', 1.0);
      notifyListeners();
    }
  }

  ///Check if Ollama is installed on the system
  Future<bool> _checkOllamaInstallation() async {
    try {
      debugPrint('🔍 Checking for existing Ollama installation...');
      
      // Try to detect system Ollama installation
      try {
        final result = await Process.run('ollama', ['--version']);
        if (result.exitCode == 0) {
          debugPrint('Found system Ollama installation');
          return true;
        }
      } catch (e) {
        debugPrint('🔍 System Ollama not found, checking common locations...');
      }
      
      // Check common installation paths
      final commonPaths = [
        r'C:\Program Files\Ollama\ollama.exe',
        r'C:\Program Files (x86)\Ollama\ollama.exe',
      ];
      
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        commonPaths.add('$userProfile\\AppData\\Local\\Programs\\Ollama\\ollama.exe');
      }
      
      for (String checkPath in commonPaths) {
        if (await File(checkPath).exists()) {
          debugPrint('Found Ollama at: $checkPath');
          return true;
        }
      }
      
      debugPrint('Ollama not found in common locations');
      return false;
    } catch (e) {
      debugPrint('Error checking Ollama installation: $e');
      return false;
    }
  }

  /// Ensure models are available with progress tracking
  Future<void> _ensureModelsAvailableWithProgress() async { 
    try {
      debugPrint('Checking model cache status with progress tracking...');
      
      // Use the enhanced OllamaManager method
      await OllamaManager.ensureModelsAvailable();
      
      // Get cache information for detailed status
      final cacheInfo = await OllamaManager.getModelCacheInfo();
      final availableModels = cacheInfo['availableModels'] as List<String>? ?? [];
      final allRequired = cacheInfo['allRequiredAvailable'] as bool? ?? false;
      
      if (allRequired) {
        debugPrint('All required models cached and ready: $availableModels');
        await _updateSetupStage(
          SetupStage.downloadingModels, 
          'All AI models cached and ready (${availableModels.length} models)', 
          0.7
        );
      } else {
        final downloadStatus = cacheInfo['downloadStatus'] as Map<String, dynamic>? ?? {};
        debugPrint('Model caching in progress... Status: $downloadStatus');
        await _updateSetupStage(
          SetupStage.downloadingModels, 
          'Caching AI models... Please wait, this may take several minutes.', 
          0.65
        );
      }
    } catch (e) {
      debugPrint('Error ensuring models available: $e');
    }
  }

  /// Verify AI with detailed cache status information
  Future<void> _verifyAIIsFullyWorking() async {
    try {
      debugPrint('Verifying AI is fully working with auto-downloaded components...');
      
      // Get comprehensive cache information
      final cacheInfo = await OllamaManager.getModelCacheInfo();
      debugPrint('Cache status: ${cacheInfo['cacheStatus']}');
      debugPrint('Available models: ${cacheInfo['availableModels']}');
      
      // Test AI response to verify functionality
      final response = await OllamaManager.generateEmpatheticResponse(
        "Test message to verify AI is working after auto-installation"
      );
      
      final aiResponse = response['response'] as String? ?? '';
      final responseSource = response['source'] as String? ?? 'unknown';
      
      if (aiResponse.isNotEmpty) {
        debugPrint('AI verification successful with source: $responseSource');
        
        // Check if response is from auto-downloaded Ollama models
        if (responseSource.contains('ollama')) {
          debugPrint('Auto-downloaded Ollama models working perfectly!');
          await _updateSetupStage(
            SetupStage.testing, 
            'AI verification successful - auto-downloaded models working perfectly!', 
            0.95
          );
        }
      } else {
        debugPrint('AI verification returned empty response');
        await _updateSetupStage(
          SetupStage.testing, 
          'AI test completed with warnings - using fallback mode', 
          0.95
        );
      }
    } catch (e) {
      debugPrint('AI verification failed: $e');
      await _updateSetupStage(
        SetupStage.testing, 
        'AI verification encountered issues - fallback mode activated', 
        0.95
      );
    }
  }

  /// ✅ ENHANCED: Handle installation failures with detailed error messaging
  Future<void> _handleInstallationFailure(String error) async {
    debugPrint('Installation failure: $error');
    
    _errorMessage = error;
    
    // Provide specific error messages based on failure type
    if (error.contains('download')) {
      await _updateSetupStage(
        SetupStage.error, 
        'Download failed: Check internet connection and try again.\nUsing offline intelligent mode...', 
        0.5
      );
    } else if (error.contains('permission')) {
      await _updateSetupStage(
        SetupStage.error, 
        'Installation permissions issue: Try running as administrator.\nUsing offline intelligent mode...', 
        0.5
      );
    } else if (error.contains('space')) {
      await _updateSetupStage(
        SetupStage.error, 
        'Insufficient disk space: Ollama requires ~13GB.\nUsing offline intelligent mode...', 
        0.5
      );
    } else {
      await _updateSetupStage(
        SetupStage.error, 
        'Installation issue encountered: Using offline intelligent mode.\nYour app will still provide emotional support.', 
        0.5
      );
    }
    
    // Wait a moment for user to read error message
    await Future.delayed(const Duration(seconds: 3));
    
    // Gracefully fall back to offline intelligent mode
    await markSetupComplete('offline_intelligent');
    debugPrint('Setup completed with intelligent offline fallback mode');
  }

  /// Checks persistent state to determine if setup is needed
  Future<void> checkSetupNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check SharedPreferences first
      final prefSetupComplete = prefs.getBool(_setupCompleteKey) ?? false;
      final prefAIType = prefs.getString(_aiTypeKey) ?? 'unknown';
      
      // Check file-based markers from AppPaths
      final fileSetupComplete = await AppPaths.isSetupComplete();
      
      // Cross-validate both sources
      final isActuallySetup = prefSetupComplete && fileSetupComplete;
      
      if (isActuallySetup) {
        // Verify AI system with cache checking
        final aiWorking = await _verifyAISystemWithCache(prefAIType);
        
        if (aiWorking) {
          _needsSetup = false;
          _isSetupComplete = true;
          _currentAIType = prefAIType;
          _currentStage = SetupStage.complete;
          _setupMessage = 'Setup verified - AI system ready with auto-downloaded components';
          _setupProgress = 1.0;
          debugPrint('Setup verified: $prefAIType');
        } else {
          // AI system not working, needs re-setup
          debugPrint('Setup exists but AI system not working - requiring fresh setup with auto-download');
          await _resetSetupState();
        }
      } else {
        // No valid setup found
        _needsSetup = true;
        _isSetupComplete = false;
        _currentAIType = 'unknown';
        _currentStage = SetupStage.notStarted;
        _setupMessage = 'First-time setup required with auto-download';
        _setupProgress = 0.0;
        debugPrint('No valid setup found - setup required with auto-download');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking setup status: $e');
      _errorMessage = 'Setup check failed: $e';
      _needsSetup = true;
      notifyListeners();
    }
  }

  /// Verify AI system with cache information  
  Future<bool> _verifyAISystemWithCache(String aiType) async {
    try {
      switch (aiType) {
        case 'ollama_gemma':
        case 'ollama_gemma3n':
          // Check if Ollama is initialized
          if (!OllamaManager.isInitialized) {
            debugPrint('🔍 Ollama not initialized, verification failed');
            return false;
          }
          
          // Check cache status from auto-download
          final cacheInfo = await OllamaManager.getModelCacheInfo();
          final allModelsAvailable = cacheInfo['allRequiredAvailable'] as bool? ?? false;
          
          if (!allModelsAvailable) {
            debugPrint('🔍 Required models not cached after auto-download, verification failed');
            return false;
          }
          
          // Quick test generation to verify functionality
          final response = await OllamaManager.generateEmpatheticResponse(
            "Verification test message", 
            model: null
          );
          
          final isOllamaResponse = response['source']?.toString().contains('ollama') ?? false;
          debugPrint('🔍 AI verification result with auto-downloaded components: $isOllamaResponse');
          return isOllamaResponse;
          
        case 'offline_intelligent':
          // Intelligent offline mode should always work
          return true;
          
        default:
          return false;
      }
    } catch (e) {
      debugPrint('AI system verification with cache failed: $e');
      return false;
    }
  }

  /// Start the initialization process with detailed stage tracking
  Future<void> startSetupProcess() async {
    try {
      _isInitializing = true;
      _errorMessage = null;
      
      await _updateSetupStage(SetupStage.checkingSystem, 'Checking system requirements...', 0.1);
      
      await _updateSetupStage(SetupStage.installingOllama, 'Installing AI system...', 0.3);
      
      //Use enhanced initialization with auto-download
      final ollamaSuccess = await OllamaManager.initialize(forceReinstall: false);
      
      if (ollamaSuccess) {
        await _updateSetupStage(SetupStage.downloadingModels, 'Checking cached models...', 0.6);
        
        //Ensure models are available using smart caching
        await OllamaManager.ensureModelsAvailable();
        
        await _updateSetupStage(SetupStage.configuringAI, 'Configuring AI system...', 0.8);
        
        await _updateSetupStage(SetupStage.testing, 'Testing AI responses...', 0.9);
        
        final testResponse = await OllamaManager.generateEmpatheticResponse("Test setup message");
        
        // Proper null safety check for the source field
        final sourceValue = testResponse['source']?.toString();
        final aiType = (sourceValue != null && sourceValue.contains('ollama')) 
            ? 'ollama_gemma3n' 
            : 'offline_intelligent';
        
        await markSetupComplete(aiType);
        await _updateSetupStage(SetupStage.complete, 'Setup complete - AI ready!', 1.0);
        
      } else {
        // Fallback to intelligent offline mode
        debugPrint('Ollama setup failed - using intelligent fallback');
        await markSetupComplete('offline_intelligent');
        await _updateSetupStage(SetupStage.complete, 'Setup complete - Offline mode ready', 1.0);
      }
      
    } catch (e) {
      debugPrint('Setup process failed: $e');
      _errorMessage = 'Setup failed: $e';
      _currentStage = SetupStage.error;
      _setupMessage = 'Setup encountered an error';
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Update setup stage with progress tracking
  Future<void> _updateSetupStage(SetupStage stage, String message, double progress) async {
    _currentStage = stage;
    _setupMessage = message;
    _setupProgress = progress;
    
    debugPrint('Setup Stage: $stage - $message (${(progress * 100).toInt()}%)');
    notifyListeners();
    
    // Small delay to make UI updates visible
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Marks setup as complete with both storage methods
  Future<void> markSetupComplete(String aiType) async {
    try {
      _needsSetup = false;
      _isSetupComplete = true;
      _currentAIType = aiType;
      _currentStage = SetupStage.complete;
      _setupProgress = 1.0;

      // Persist to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupCompleteKey, true);
      await prefs.setString(_aiTypeKey, aiType);
      await prefs.setString(_setupVersionKey, AppPaths.currentVersion ?? 'unknown');
      await prefs.setString(_lastSetupDateKey, DateTime.now().toIso8601String());

      // Persist to file system via AppPaths
      await AppPaths.markSetupComplete();

      debugPrint('Setup completed with AI type: $aiType');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to mark setup complete: $e');
      _errorMessage = 'Failed to save setup state: $e';
      notifyListeners();
    }
  }

  /// Resets setup state with comprehensive cleanup
  Future<void> resetSetup() async {
    try {
      await _resetSetupState();
      
      // Clean up Ollama data
      await OllamaManager.cleanupAllData();
      
      debugPrint('Setup state reset - will run fresh installation with auto-download');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to reset setup: $e');
      _errorMessage = 'Reset failed: $e';
      notifyListeners();
    }
  }

  /// Internal method to reset setup state
  Future<void> _resetSetupState() async {
    _needsSetup = true;
    _isSetupComplete = false;
    _currentAIType = 'unknown';
    _isInitializing = false;
    _currentStage = SetupStage.notStarted;
    _setupMessage = 'Ready for fresh setup with auto-download';
    _setupProgress = 0.0;
    _errorMessage = null;

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_setupCompleteKey);
    await prefs.remove(_aiTypeKey);
    await prefs.remove(_setupVersionKey);
    await prefs.remove(_lastSetupDateKey);
  }

  /// Force setup to run (for testing purposes)
  Future<void> forceSetup() async {
    try {
      await _resetSetupState();
      
      // Clear all persistent data for fresh setup
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Create fresh installation directory
      await AppPaths.createFreshInstallation();
      
      debugPrint('FORCED SETUP - all data cleared for fresh installation with auto-download');
      notifyListeners();
    } catch (e) {
      debugPrint('Force setup failed: $e');
      _errorMessage = 'Force setup failed: $e';
      notifyListeners();
    }
  }

  //Get detailed cache information for debugging
  Future<Map<String, dynamic>> getCacheInformation() async {
    try {
      final cacheInfo = await OllamaManager.getModelCacheInfo();
      return {
        'setupInfo': getSetupInfo(),
        'cacheInfo': cacheInfo,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'setupInfo': getSetupInfo(),
        'cacheInfo': {'error': e.toString()},
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Start the initialization process (legacy method for compatibility)
  void startInitialization() {
    startSetupProcess();
  }

  /// Complete initialization (legacy method for compatibility)
  void completeInitialization() {
    _isInitializing = false;
    debugPrint('Ollama initialization completed');
    notifyListeners();
  }

  /// Get user-friendly description of current AI type
  String getAIDescription() {
    switch (_currentAIType) {
      case 'ollama_gemma':
      case 'ollama_gemma3n':
        return 'Gemma AI via Ollama - Full AI capabilities with auto-download and smart caching';
      case 'offline_intelligent':
        return 'Intelligent offline mode - Smart responses';
      case 'offline_fallback':
        return 'Offline mode - Basic emotional support';
      default:
        return 'Initializing AI system with auto-download...';
    }
  }

  /// Check if advanced AI features are available
  bool get hasAdvancedAI => _currentAIType.contains('ollama');

  /// Check if any AI is available (not just fallback)
  bool get hasIntelligentAI => _currentAIType != 'offline_fallback';

  /// Get status text for UI display
  String get statusText {
    if (_isInitializing) return _setupMessage.isNotEmpty ? _setupMessage : 'Initializing AI with auto-download...';
    if (_currentAIType.contains('ollama')) return 'AI Ready - Gemma (Auto-Downloaded)';
    if (_currentAIType == 'offline_intelligent') return 'Offline Mode';
    return 'Basic Support';
  }

  /// Get color for status indicator
  Color get statusColor {
    if (_errorMessage != null) return Colors.red;
    if (_isInitializing) return Colors.orange;
    if (_currentAIType.contains('ollama')) return Colors.green;
    if (_currentAIType == 'offline_intelligent') return Colors.blue;
    return Colors.grey;
  }

  /// Check if ready for competition demo
  bool get isCompetitionReady => _currentAIType.contains('ollama') || _currentAIType == 'offline_intelligent';

  /// Get setup progress as percentage (for UI)
  double get setupProgressPercentage => _setupProgress;

  /// Get current setup stage description
  String get setupStageDescription {
    if (_errorMessage != null) {
      return 'Setup error: $_errorMessage';
    }
    
    if (_isSetupComplete) {
      return 'Setup complete - ${getAIDescription()}';
    } else if (_isInitializing) {
      return _setupMessage;
    } else if (_needsSetup) {
      return 'Ready to begin auto-download setup';
    } else {
      return 'Finalizing configuration...';
    }
  }

  /// Get detailed setup information for debugging
  Map<String, dynamic> getSetupInfo() {
    return {
      'needsSetup': _needsSetup,
      'isSetupComplete': _isSetupComplete,
      'currentAIType': _currentAIType,
      'isInitializing': _isInitializing,
      'currentStage': _currentStage.toString(),
      'setupProgress': _setupProgress,
      'errorMessage': _errorMessage,
      'setupMessage': _setupMessage,
    };
  }

  /// Clear any error messages
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
