import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/installation_progress_widget.dart';
import '../services/gemma_service.dart';
import '../services/ollama_manager.dart';
import '../providers/setup_state_provider.dart';

class AppSetupScreen extends StatefulWidget {
  final String message;
  
  const AppSetupScreen({
    Key? key,
    this.message = 'Setting up your AI companion...'
  }) : super(key: key);

  @override
  _AppSetupScreenState createState() => _AppSetupScreenState();
}

class _AppSetupScreenState extends State<AppSetupScreen>
    with SingleTickerProviderStateMixin {
  String _statusMessage = '';
  String _detailMessage = '';
  bool _isComplete = false;
  bool _hasError = false;
  String? _errorDetails;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  /// Platform-specific setup stages
  List<String> get _setupStages {
    if (_isMobile) {
      return [
        'Checking system requirements...',
        'Initializing Gemma AI...',
        'Loading AI model...',
        'Configuring AI...',
        'Testing AI functionality...',
        'Setup complete!'
      ];
    } else {
      return [
        'Checking system requirements...',
        'Checking for Ollama installation...',
        'Downloading and installing Ollama...',
        'Starting AI service...',
        'Downloading AI models...',
        'Configuring AI system...',
        'Testing AI functionality...',
        'Setup complete!'
      ];
    }
  }
  
  int _currentStage = 0;
  
  // Platform detection
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.message;
    _detailMessage = 'Initializing...';
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _animationController.repeat(reverse: true);
    
    _runCompleteSetup();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Platform-specific complete setup
  Future<void> _runCompleteSetup() async {
    SetupStateProvider? setupProvider;
    
    try {
      setupProvider = context.read<SetupStateProvider>();
      
      await _updateStage(0); // Checking system requirements
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_isMobile) {
        await _runMobileSetup();
      } else {
        await _runDesktopSetup();
      }
      
    } catch (e) {
      debugPrint('Setup process error: $e');
      if (mounted) {
        await _handleSetupFailure('Setup error: $e');
      }
    }
  }

  /// Mobile-specific setup with Gemma
  Future<void> _runMobileSetup() async {
    try {
      final platformPrefix = '📱';
      
      await _updateStage(1); // Initializing Gemma AI
      if (!mounted) return;
      debugPrint('$platformPrefix Initializing Gemma...');
      
      // Initialize Gemma
      await GemmaService().initialize();
      
      if (!mounted) return;
      await _updateStage(2); // Loading AI model
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (!mounted) return;
      await _updateStage(3); // Configuring AI
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      await _updateStage(4); // Testing AI functionality
      await _testMobileAIResponse();
      
      if (!mounted) return;
      await _updateStage(5); // Setup complete
      await _completeSetup('gemma_mobile');
      
    } catch (e) {
      debugPrint('📱 Mobile setup failed: $e');
      await _handleSetupFailure('Mobile AI setup failed: $e');
    }
  }

  /// Desktop-specific setup with Ollama
  Future<void> _runDesktopSetup() async {
    try {
      final platformPrefix = '🖥️';
      
      await _updateStage(1); // Checking for Ollama installation
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 800));
      
      bool ollamaExists = await _checkOllamaInstallation();
      
      if (!ollamaExists) {
        await _updateStage(2); // Downloading and installing Ollama
        if (!mounted) return;
        debugPrint('$platformPrefix Ollama not found - starting auto-installation');
      } else {
        await _updateStage(2); // Show installation stage briefly
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('$platformPrefix Ollama already installed');
      }
      
      await _updateStage(3); // Starting AI service
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _updateStage(4); // Downloading AI models
      if (!mounted) return;
      
      final success = await OllamaManager.initialize(forceReinstall: false);
      
      if (!mounted) return;
      
      if (success) {
        await _updateStage(5); // Configuring AI system
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (!mounted) return;
        await _updateStage(6); // Testing AI functionality
        await _testDesktopAIResponse();
        
        if (!mounted) return;
        await _updateStage(7); // Setup complete
        await _completeSetup('ollama_gemma4');
        
      } else {
        await _handleSetupFailure('Ollama initialization failed');
      }
      
    } catch (e) {
      debugPrint('🖥️ Desktop setup failed: $e');
      await _handleSetupFailure('Desktop setup failed: $e');
    }
  }

  /// Check if Ollama is installed (Desktop only)
  Future<bool> _checkOllamaInstallation() async {
    if (_isMobile) return false;
    
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
  }

  /// Update stage with platform-specific messaging
  Future<void> _updateStage(int stageIndex) async {
    if (!mounted) return;
    
    if (stageIndex < _setupStages.length) {
      setState(() {
        _currentStage = stageIndex;
        _statusMessage = _setupStages[stageIndex];
        
        // Platform-specific detail messages
        if (_isMobile) {
          switch (stageIndex) {
            case 2:
              _detailMessage = 'Loading Gemma AI model...';
              break;
            case 4:
              _detailMessage = 'Testing Gemma AI responses...';
              break;
            default:
              _detailMessage = 'Please wait...';
              break;
          }
        } else {
          switch (stageIndex) {
            case 2:
              _detailMessage = 'Downloading Ollama (this may take several minutes)';
              break;
            case 4:
              _detailMessage = 'Downloading Gemma AI models (this may take several minutes)';
              break;
            case 6:
              _detailMessage = 'Testing AI responses with auto-downloaded models...';
              break;
            default:
              _detailMessage = 'Please wait...';
              break;
          }
        }
      });
      
      if (mounted && _animationController.isAnimating) {
        _animationController.forward().then((_) {
          if (mounted) {
            _animationController.reverse();
          }
        });
      }
    }
  }

  /// Test mobile AI response using Gemma
  Future<void> _testMobileAIResponse() async {
    try {
      debugPrint('📱 Testing Gemma AI...');
      
      final response = await GemmaService().generateEmotionalResponse(
        "Hello, this is a test"
      );
      
      if (response.isNotEmpty) {
        final displayText = response.length > 50 
            ? '${response.substring(0, 50)}...'
            : response;
        debugPrint('📱 Gemma Test Response: $displayText');
      }
      
      if (!mounted) return;
      setState(() {
        _detailMessage = response.isNotEmpty
            ? 'Gemma AI is responding correctly!' 
            : 'Gemma AI test completed';
      });
      
    } catch (e) {
      debugPrint('📱 Gemma test failed: $e');
      if (!mounted) return;
      setState(() {
        _detailMessage = 'Gemma test completed with warnings';
        _errorDetails = e.toString();
      });
    }
  }

  /// Test desktop AI response using Ollama
  Future<void> _testDesktopAIResponse() async {
    try {
      debugPrint('🖥️ Testing Ollama...');
      
      final responseData = await OllamaManager.generateEmpatheticResponse(
        "Hello, this is a test to verify the AI is working."
      );
      
      final aiResponse = responseData['response'] as String? ?? '';
      final responseSource = responseData['source'] as String? ?? 'unknown';
      
      if (aiResponse.isNotEmpty) {
        final displayText = aiResponse.length > 50 
            ? '${aiResponse.substring(0, 50)}...'
            : aiResponse;
        debugPrint('🖥️ Ollama Test Response: $displayText');
        debugPrint('Response source: $responseSource');
      }
      
      if (!mounted) return;
      setState(() {
        _detailMessage = aiResponse.isNotEmpty 
            ? 'AI is responding correctly with auto-downloaded models!' 
            : 'AI test completed';
      });
      
    } catch (e) {
      debugPrint('🖥️ Ollama test failed: $e');
      if (!mounted) return;
      setState(() {
        _detailMessage = 'Ollama test completed with warnings';
        _errorDetails = e.toString();
      });
    }
  }

  /// Complete setup
  Future<void> _completeSetup(String aiType) async {
    if (!mounted) return;
    
    final platformPrefix = _isMobile ? '📱' : '🖥️';
    
    setState(() {
      _isComplete = true;
      _statusMessage = 'Vent AI is ready!';
      _detailMessage = _isMobile 
          ? 'Your mobile emotional support companion is ready'
          : 'Your emotional support companion is ready with Ollama';
    });
    
    _animationController.stop();
    
    try {
      if (mounted) {
        final setupProvider = context.read<SetupStateProvider>();
        await setupProvider.markSetupComplete(aiType);
        debugPrint('$platformPrefix Setup complete: $aiType');
      }
    } catch (e) {
      debugPrint('Failed to mark setup complete: $e');
    }
    
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _isComplete) {
      setState(() {
        _statusMessage = 'Loading your companion...';
      });
    }
  }

  /// Handle setup failure with platform-specific messaging
  Future<void> _handleSetupFailure(String error) async {
    if (!mounted) return;
    
    final platformPrefix = _isMobile ? '📱' : '🖥️';
    
    setState(() {
      _hasError = true;
      _errorDetails = error;
    });
    
    // Platform-specific error messages
    if (_isMobile) {
      setState(() {
        _statusMessage = 'Setup Issue';
        _detailMessage = 'Using fallback mode...';
      });
    } else {
      if (error.contains('download')) {
        setState(() {
          _statusMessage = 'Download Failed';
          _detailMessage = 'Check internet connection. Using offline mode...';
        });
      } else if (error.contains('permission')) {
        setState(() {
          _statusMessage = 'Permission Issue';
          _detailMessage = 'Try running as administrator. Using offline mode...';
        });
      } else {
        setState(() {
          _statusMessage = 'Setup Issue';
          _detailMessage = 'Using offline mode...';
        });
      }
    }
    
    _animationController.stop();
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Using intelligent offline mode...';
      _detailMessage = 'Emotional support available';
    });
    
    try {
      if (mounted) {
        final setupProvider = context.read<SetupStateProvider>();
        final fallbackType = _isMobile ? 'mobile_fallback' : 'desktop_fallback';
        await setupProvider.markSetupComplete(fallbackType);
        debugPrint('$platformPrefix Setup completed with fallback');
      }
    } catch (e) {
      debugPrint('Failed to mark fallback setup complete: $e');
    }
    
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _isComplete = true;
        _hasError = false;
        _statusMessage = 'Vent AI is ready!';
        _detailMessage = _isMobile 
            ? 'Mobile emotional support ready'
            : 'Offline emotional support ready';
      });
    }
  }

  double get _progressPercentage => (_currentStage + 1) / _setupStages.length;

  @override
  Widget build(BuildContext context) {
    final platformEmoji = _isMobile ? '📱' : '🖥️';
    final platformName = _isMobile ? 'Mobile' : 'Desktop';
    
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200,
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.psychology,
                    size: 60,
                    color: Colors.blue.shade600,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  'Vent AI',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    letterSpacing: -0.5,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Your personal emotional support companion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Installation progress
                const InstallationProgressWidget(),
                
                const SizedBox(height: 24),
                
                // Progress indicator
                if (!_isComplete && !_hasError) ...[
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 8,
                          backgroundColor: Colors.blue.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade100,
                          ),
                        ),
                        CircularProgressIndicator(
                          value: _progressPercentage,
                          strokeWidth: 8,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade600,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(_progressPercentage * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            Text(
                              _isMobile ? 'Initializing' : 'Auto-Installing',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else if (_isComplete) ...[
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 40,
                      color: Colors.green.shade600,
                    ),
                  ),
                ] else if (_hasError) ...[
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info,
                      size: 40,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Status message
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusMessage,
                    key: ValueKey(_statusMessage),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _hasError 
                        ? Colors.orange.shade700
                        : _isComplete 
                          ? Colors.green.shade700
                          : Colors.blue.shade800,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Detail message
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _detailMessage,
                    key: ValueKey(_detailMessage),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Platform indicator
                if (!_isComplete && !_hasError) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          platformEmoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$platformName AI Setup',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Offline AI indicator
                if (_currentStage >= (_isMobile ? 2 : 4)) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.offline_bolt,
                          size: 16,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Offline AI • Privacy Protected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Error details
                if (_hasError && _errorDetails != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Debug: $_errorDetails',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                
                // Setup provider state
                Consumer<SetupStateProvider>(
                  builder: (context, setupProvider, child) {
                    return Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: setupProvider.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: setupProvider.statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        setupProvider.statusText,
                        style: TextStyle(
                          fontSize: 10,
                          color: setupProvider.statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}