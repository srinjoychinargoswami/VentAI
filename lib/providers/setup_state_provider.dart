import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_paths.dart';
import '../services/gemma_service.dart';
import '../services/gemma_bootstrap.dart';
import '../services/ollama_manager.dart';

enum SetupStage {
  notStarted,
  checkingSystem,
  acceptingLicense,
  extractingAIModel,
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
  static const String _gemmadaLicenseAcceptedKey = 'gemma_license_accepted';

  bool _needsSetup = true;
  bool _isSetupComplete = false;
  String _currentAIType = 'unknown';
  bool _isInitializing = false;
  SetupStage _currentStage = SetupStage.notStarted;
  String _setupMessage = '';
  double _setupProgress = 0.0;
  String? _errorMessage;

  // Platform detection
  bool get isMobile => Platform.isAndroid || Platform.isIOS;
  bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  // Getters
  bool get needsSetup => _needsSetup;
  bool get isSetupComplete => _isSetupComplete;
  String get currentAIType => _currentAIType;
  bool get isInitializing => _isInitializing;
  SetupStage get currentStage => _currentStage;
  String get setupMessage => _setupMessage;
  double get setupProgress => _setupProgress;
  String? get errorMessage => _errorMessage;

  /// Check if Gemma license has been accepted
  Future<bool> isGemmaLicenseAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_gemmadaLicenseAcceptedKey) ?? false;
  }

  /// Initialize and check setup status (called on app startup)
  Future<void> initialize() async {
    final platformPrefix = isMobile ? '📱' : '🖥️';
    debugPrint('$platformPrefix SetupStateProvider initializing...');
    
    try {
      await AppPaths.initialize();
      await checkSetupNeeded();
      debugPrint('$platformPrefix SetupStateProvider initialized');
    } catch (e) {
      debugPrint('$platformPrefix SetupStateProvider initialization failed: $e');
      _errorMessage = 'Failed to initialize: $e';
      notifyListeners();
    }
  }

  /// Accept Gemma license (saves preference, does NOT start download)
  Future<void> acceptLicense() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_gemmadaLicenseAcceptedKey, true);
      debugPrint('📱 Gemma license accepted - ready for download');

      // Show "ready to download" message
      await _updateSetupStage(
        SetupStage.acceptingLicense,
        'License accepted! Ready to download Gemma model.\nTap "Start Download" to begin.',
        0.15,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to save license acceptance: $e');
      _errorMessage = 'Failed to save license acceptance: $e';
      notifyListeners();
    }
  }

  /// Start model download (called AFTER license accepted and user explicitly taps download)
  Future<void> startDownloading() async {
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final platformPrefix = isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix User starting download...');

      if (isMobile) {
        await _downloadAndSetupMobileModel();
      } else {
        await _downloadAndSetupDesktopModel();
      }
    } catch (e) {
      debugPrint('Download failed: $e');
      await _handleInstallationFailure('Download error: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Download and setup mobile model (called AFTER license + user explicit action)
  Future<void> _downloadAndSetupMobileModel() async {
    try {
      await _updateSetupStage(
        SetupStage.downloadingModels,
        'Downloading Gemma 4 E2B model...\n~2.4GB, may take several minutes',
        0.3,
      );

      // Bootstrap Gemma with model download
      final success = await bootstrapGemma(
        onProgress: (progress) async {
          await _updateSetupStage(
            SetupStage.downloadingModels,
            'Downloading Gemma 4 E2B model... $progress%',
            0.3 + (progress / 100.0 * 0.4), // Progress from 30% to 70%
          );
        },
      );

      if (success) {
        // Initialize GemmaService singleton model after download completes
        debugPrint('📱 Initializing GemmaService singleton model...');
        try {
          await GemmaService().initialize();
          debugPrint('✅ GemmaService model initialized - ready for inference');
        } catch (e) {
          debugPrint('⚠️ GemmaService initialization: $e');
        }

        await _updateSetupStage(
          SetupStage.configuringAI,
          'Configuring AI for optimal performance...',
          0.8,
        );

        await _updateSetupStage(
          SetupStage.testing,
          'Testing AI functionality...',
          0.9,
        );

        // Wait for model to fully load before testing
        debugPrint('📥 Waiting for model to fully load into memory...');
        await Future.delayed(const Duration(milliseconds: 500));

        await _verifyMobileAI();

        await markSetupComplete('gemma_mobile');
        debugPrint('📱 DOWNLOAD COMPLETE - Gemma AI ready');
      } else {
        await _handleMobileSetupFailure('AI model download failed');
      }
    } catch (e) {
      debugPrint('📱 Download failed: $e');
      await _handleMobileSetupFailure('Download error: $e');
    }
  }

  /// Download and setup desktop model (called AFTER user explicit action)
  Future<void> _downloadAndSetupDesktopModel() async {
    try {
      await _updateSetupStage(
        SetupStage.downloadingModels,
        'Downloading Ollama and AI models...',
        0.4,
      );

      final success = await OllamaManager.initialize(forceReinstall: false);

      if (success) {
        await _updateSetupStage(
          SetupStage.configuringAI,
          'Configuring AI system...',
          0.8,
        );

        await _updateSetupStage(
          SetupStage.testing,
          'Testing AI functionality...',
          0.9,
        );

        await _verifyAIIsFullyWorking();

        await markSetupComplete('ollama_gemma4');
        debugPrint('🖥️ DOWNLOAD COMPLETE');
      } else {
        await _handleInstallationFailure('Download failed');
      }
    } catch (e) {
      debugPrint('🖥️ Download failed: $e');
      await _handleInstallationFailure('Download error: $e');
    }
  }

  /// Start the complete setup process (checks license, doesn't start download)
  Future<void> startCompleteSetup() async {
    _isInitializing = true;
    _needsSetup = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final platformPrefix = isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix Starting setup...');

      await _updateSetupStage(SetupStage.checkingSystem, 'Checking system requirements...', 0.1);

      if (isMobile) {
        // Check license acceptance on mobile
        final prefs = await SharedPreferences.getInstance();
        final licenseAccepted = prefs.getBool(_gemmadaLicenseAcceptedKey) ?? false;

        if (!licenseAccepted) {
          debugPrint('📱 License not accepted - showing license screen');
          await _updateSetupStage(
            SetupStage.acceptingLicense,
            'Please accept Gemma model license to continue',
            0.15,
          );
          return; // Stop here, app will show license screen
        }

        debugPrint('📱 License already accepted - ready for download');
        await _updateSetupStage(
          SetupStage.acceptingLicense,
          'License accepted! Ready to download Gemma model.\nTap "Start Download" to begin.',
          0.15,
        );
      } else {
        // Desktop: show download ready message
        await _updateSetupStage(
          SetupStage.downloadingModels,
          'Ready to download Ollama and AI models.\nTap "Start Download" to begin.',
          0.2,
        );
      }

    } catch (e) {
      debugPrint('Setup check failed: $e');
      await _handleInstallationFailure('Setup error: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }


  /// Verify mobile AI (Gemma) functionality
  Future<void> _verifyMobileAI() async {
    try {
      debugPrint('Verifying Gemma AI...');
      
      final response = await GemmaService().generateEmotionalResponse(
        "Test message"
      );
      
      if (response.isNotEmpty) {
        debugPrint('✅ Gemma verification successful');
        await _updateSetupStage(
          SetupStage.testing, 
          'Gemma AI verification successful!', 
          0.95
        );
      } else {
        debugPrint('⚠️ Gemma verification returned empty');
        await _updateSetupStage(
          SetupStage.testing, 
          'Gemma AI test completed with warnings', 
          0.95
        );
      }
      
      final gemmaStatus = await GemmaService().getStatus();
      debugPrint('Gemma status: $gemmaStatus');
      
    } catch (e) {
      debugPrint('❌ Gemma verification failed: $e');
      await _updateSetupStage(
        SetupStage.testing, 
        'Gemma verification encountered issues', 
        0.95
      );
    }
  }

  /// Handle mobile setup failures
  Future<void> _handleMobileSetupFailure(String error) async {
    debugPrint('📱 Mobile setup failure: $error');
    
    _errorMessage = error;
    
    await _updateSetupStage(
      SetupStage.error, 
      'Setup issue: $error\nUsing fallback mode...', 
      0.5
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    await markSetupComplete('mobile_fallback');
    debugPrint('📱 Mobile setup completed with fallback');
  }

  /// Check if Ollama is installed (Desktop only)
  Future<bool> _checkOllamaInstallation() async {
    if (isMobile) return false;
    
    try {
      debugPrint('Checking for Ollama...');
      
      try {
        final result = await Process.run('ollama', ['--version']);
        if (result.exitCode == 0) {
          debugPrint('Found system Ollama');
          return true;
        }
      } catch (e) {
        debugPrint('System Ollama not found');
      }
      
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
      
      return false;
    } catch (e) {
      debugPrint('Error checking Ollama: $e');
      return false;
    }
  }

  /// Ensure models are available (Desktop only)
  Future<void> _ensureModelsAvailableWithProgress() async { 
    if (isMobile) return;
    
    try {
      debugPrint('Checking Ollama models...');
      
      await OllamaManager.ensureModelsAvailable();
      
      final cacheInfo = await OllamaManager.getModelCacheInfo();
      final availableModels = cacheInfo['availableModels'] as List<String>? ?? [];
      final allRequired = cacheInfo['allRequiredAvailable'] as bool? ?? false;
      
      if (allRequired) {
        debugPrint('All models ready: $availableModels');
        await _updateSetupStage(
          SetupStage.downloadingModels, 
          'All models ready (${availableModels.length} models)', 
          0.7
        );
      } else {
        await _updateSetupStage(
          SetupStage.downloadingModels, 
          'Caching models...', 
          0.65
        );
      }
    } catch (e) {
      debugPrint('Error ensuring models: $e');
    }
  }

  /// Verify desktop AI (Desktop only)
  Future<void> _verifyAIIsFullyWorking() async {
    if (isMobile) return;
    
    try {
      debugPrint('Verifying Ollama...');
      
      final cacheInfo = await OllamaManager.getModelCacheInfo();
      debugPrint('Cache status: ${cacheInfo['cacheStatus']}');
      
      final response = await OllamaManager.generateEmpatheticResponse(
        "Test message"
      );
      
      final aiResponse = response['response'] as String? ?? '';
      final responseSource = response['source'] as String? ?? 'unknown';
      
      if (aiResponse.isNotEmpty) {
        debugPrint('✅ AI verification successful: $responseSource');
        
        if (responseSource.contains('ollama')) {
          await _updateSetupStage(
            SetupStage.testing, 
            'AI verification successful!', 
            0.95
          );
        }
      } else {
        await _updateSetupStage(
          SetupStage.testing, 
          'AI test completed', 
          0.95
        );
      }
    } catch (e) {
      debugPrint('❌ AI verification failed: $e');
      await _updateSetupStage(
        SetupStage.testing, 
        'AI verification encountered issues', 
        0.95
      );
    }
  }

  /// Handle installation failures
  Future<void> _handleInstallationFailure(String error) async {
    final platformPrefix = isMobile ? '📱' : '🖥️';
    debugPrint('$platformPrefix Installation failure: $error');
    
    _errorMessage = error;
    
    await _updateSetupStage(
      SetupStage.error, 
      'Installation issue: $error\nUsing fallback mode...', 
      0.5
    );
    
    await Future.delayed(const Duration(seconds: 3));
    
    final fallbackType = isMobile ? 'mobile_fallback' : 'desktop_fallback';
    await markSetupComplete(fallbackType);
    debugPrint('$platformPrefix Setup completed with fallback');
  }

  /// Check if setup is needed
  Future<void> checkSetupNeeded() async {
    try {
      final platformPrefix = isMobile ? '📱' : '🖥️';
      
      final prefs = await SharedPreferences.getInstance();
      
      final prefSetupComplete = prefs.getBool(_setupCompleteKey) ?? false;
      final prefAIType = prefs.getString(_aiTypeKey) ?? 'unknown';
      
      final fileSetupComplete = await AppPaths.isSetupComplete();
      
      final isActuallySetup = prefSetupComplete && fileSetupComplete;
      
      if (isActuallySetup) {
        final aiWorking = await _verifyAISystemWithCache(prefAIType);
        
        if (aiWorking) {
          _needsSetup = false;
          _isSetupComplete = true;
          _currentAIType = prefAIType;
          _currentStage = SetupStage.complete;
          _setupMessage = 'Setup verified - AI ready';
          _setupProgress = 1.0;
          debugPrint('$platformPrefix Setup verified: $prefAIType');
        } else {
          debugPrint('$platformPrefix AI not working - requiring setup');
          await _resetSetupState();
        }
      } else {
        _needsSetup = true;
        _isSetupComplete = false;
        _currentAIType = 'unknown';
        _currentStage = SetupStage.notStarted;
        _setupMessage = 'First-time setup required';
        _setupProgress = 0.0;
        debugPrint('$platformPrefix No valid setup found');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking setup: $e');
      _errorMessage = 'Setup check failed: $e';
      _needsSetup = true;
      notifyListeners();
    }
  }

  /// Verify AI system
  Future<bool> _verifyAISystemWithCache(String aiType) async {
    try {
      switch (aiType) {
        case 'gemma_mobile':
          if (isMobile) {
            final status = await GemmaService().getStatus();
            final canGenerate = status['can_generate'] as bool? ?? false;
            debugPrint('Gemma verification: canGenerate=$canGenerate');
            return canGenerate;
          }
          return false;
          
        case 'ollama_gemma4':
        case 'ollama_gemma3n':
          if (isDesktop) {
            if (!OllamaManager.isInitialized) {
              return false;
            }
            
            final cacheInfo = await OllamaManager.getModelCacheInfo();
            final allModelsAvailable = cacheInfo['allRequiredAvailable'] as bool? ?? false;
            
            if (!allModelsAvailable) {
              return false;
            }
            
            final response = await OllamaManager.generateEmpatheticResponse(
              "Verification test", 
              model: null
            );
            
            final isOllamaResponse = response['source']?.toString().contains('ollama') ?? false;
            return isOllamaResponse;
          }
          return false;
          
        case 'mobile_fallback':
        case 'desktop_fallback':
          return true;
          
        default:
          return false;
      }
    } catch (e) {
      debugPrint('AI verification failed: $e');
      return false;
    }
  }

  /// Update setup stage
  Future<void> _updateSetupStage(SetupStage stage, String message, double progress) async {
    _currentStage = stage;
    _setupMessage = message;
    _setupProgress = progress;
    
    final platformPrefix = isMobile ? '📱' : '🖥️';
    debugPrint('$platformPrefix Setup: $stage - $message (${(progress * 100).toInt()}%)');
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Mark setup as complete
  Future<void> markSetupComplete(String aiType) async {
    try {
      _needsSetup = false;
      _isSetupComplete = true;
      _currentAIType = aiType;
      _currentStage = SetupStage.complete;
      _setupProgress = 1.0;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_setupCompleteKey, true);
      await prefs.setString(_aiTypeKey, aiType);
      await prefs.setString(_setupVersionKey, AppPaths.currentVersion ?? 'unknown');
      await prefs.setString(_lastSetupDateKey, DateTime.now().toIso8601String());

      await AppPaths.markSetupComplete();

      final platformPrefix = isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix Setup complete: $aiType');
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to mark setup complete: $e');
      _errorMessage = 'Failed to save: $e';
      notifyListeners();
    }
  }

  /// Reset setup
  Future<void> resetSetup() async {
    try {
      await _resetSetupState();
      
      if (isDesktop) {
        await OllamaManager.cleanupAllData();
      }
      
      final platformPrefix = isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix Setup reset');
      notifyListeners();
    } catch (e) {
      debugPrint('Reset failed: $e');
      _errorMessage = 'Reset failed: $e';
      notifyListeners();
    }
  }

  /// Internal reset state
  Future<void> _resetSetupState() async {
    _needsSetup = true;
    _isSetupComplete = false;
    _currentAIType = 'unknown';
    _isInitializing = false;
    _currentStage = SetupStage.notStarted;
    _setupMessage = 'Ready for setup';
    _setupProgress = 0.0;
    _errorMessage = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_setupCompleteKey);
    await prefs.remove(_aiTypeKey);
    await prefs.remove(_setupVersionKey);
    await prefs.remove(_lastSetupDateKey);
  }

  /// Force setup
  Future<void> forceSetup() async {
    try {
      await _resetSetupState();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      await AppPaths.createFreshInstallation();
      
      final platformPrefix = isMobile ? '📱' : '🖥️';
      debugPrint('$platformPrefix FORCED SETUP');
      notifyListeners();
    } catch (e) {
      debugPrint('Force setup failed: $e');
      _errorMessage = 'Force setup failed: $e';
      notifyListeners();
    }
  }

  /// Get cache information
  Future<Map<String, dynamic>> getCacheInformation() async {
    try {
      if (isMobile) {
        final gemmaStatus = await GemmaService().getStatus();
        return {
          'platform': 'mobile',
          'setupInfo': getSetupInfo(),
          'gemmaStatus': gemmaStatus,
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        final cacheInfo = await OllamaManager.getModelCacheInfo();
        return {
          'platform': 'desktop',
          'setupInfo': getSetupInfo(),
          'cacheInfo': cacheInfo,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      return {
        'platform': isMobile ? 'mobile' : 'desktop',
        'setupInfo': getSetupInfo(),
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get AI description
  String getAIDescription() {
    switch (_currentAIType) {
      case 'gemma_mobile':
        return 'Gemma AI - Offline support';
      case 'ollama_gemma4':
      case 'ollama_gemma3n':
        return 'Gemma AI via Ollama';
      case 'mobile_fallback':
        return 'Mobile fallback mode';
      case 'desktop_fallback':
        return 'Desktop fallback mode';
      default:
        return 'Initializing...';
    }
  }

  /// Feature checks
  bool get hasAdvancedAI => _currentAIType.contains('gemma') || _currentAIType.contains('ollama');
  bool get hasIntelligentAI => !_currentAIType.contains('fallback');

  /// Status text
  String get statusText {
    if (_isInitializing) return _setupMessage.isNotEmpty ? _setupMessage : 'Initializing...';
    if (_currentAIType.contains('gemma_mobile')) return 'Gemma AI Ready';
    if (_currentAIType.contains('ollama')) return 'Desktop AI Ready';
    if (_currentAIType.contains('fallback')) return 'Fallback Mode';
    return 'Basic Support';
  }

  /// Status color
  Color get statusColor {
    if (_errorMessage != null) return Colors.red;
    if (_isInitializing) return Colors.orange;
    if (_currentAIType.contains('gemma') || _currentAIType.contains('ollama')) return Colors.green;
    if (_currentAIType.contains('fallback')) return Colors.blue;
    return Colors.grey;
  }

  /// Progress percentage
  double get setupProgressPercentage => _setupProgress;

  /// Stage description
  String get setupStageDescription {
    if (_errorMessage != null) return 'Setup error: $_errorMessage';
    if (_isSetupComplete) return 'Setup complete - ${getAIDescription()}';
    if (_isInitializing) return _setupMessage;
    if (_needsSetup) return 'Ready to begin setup';
    return 'Finalizing...';
  }

  /// Setup info
  Map<String, dynamic> getSetupInfo() {
    return {
      'platform': isMobile ? 'mobile' : 'desktop',
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

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}