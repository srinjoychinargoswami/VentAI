import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/installation_progress_widget.dart';
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
  
  //Setup stages reflecting auto-download installation process
  final List<String> _setupStages = [
    'Checking system requirements...',
    'Checking for Ollama installation...',
    'Downloading and installing Ollama from official source...',
    'Starting AI service...',
    'Downloading AI models (Gemma 3n)...',
    'Configuring AI system...',
    'Testing AI functionality...',
    'Setup complete!'
  ];
  
  int _currentStage = 0;

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

  ///Run complete setup with auto-download logic
  Future<void> _runCompleteSetup() async {
    SetupStateProvider? setupProvider;
    
    try {
      setupProvider = context.read<SetupStateProvider>();
      
      await _updateStage(0); // Checking system requirements
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _updateStage(1); // Checking for Ollama installation
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 800));
      
      //Check if Ollama exists before attempting download
      bool ollamaExists = await _checkOllamaInstallation();
      
      if (!ollamaExists) {
        await _updateStage(2); // Downloading and installing Ollama
        if (!mounted) return;
        debugPrint('⬇Ollama not found - starting auto-installation process');
      } else {
        await _updateStage(2); // Show installation stage briefly
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('Ollama already installed - proceeding with existing installation');
      }
      
      await _updateStage(3); // Starting AI service
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _updateStage(4); // Downloading AI models
      if (!mounted) return;
      
      //Use the enhanced auto-download initialization
      final success = await OllamaManager.initialize(forceReinstall: false);
      
      if (!mounted) return;
      
      if (success) {
        await _updateStage(5); // Configuring AI system
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (!mounted) return;
        await _updateStage(6); // Testing AI functionality
        await _testAIResponse();
        
        if (!mounted) return;
        await _updateStage(7); // Setup complete
        await _completeSetup('ollama_gemma3n');
        
      } else {
        await _handleSetupFailure('Ollama initialization failed - using intelligent offline fallback');
      }
      
    } catch (e) {
      debugPrint('Setup process error: $e');
      if (mounted) {
        await _handleSetupFailure('Setup error: $e');
      }
    }
  }

  ///Check if Ollama is installed on the system
  Future<bool> _checkOllamaInstallation() async {
    try {
      // Try to detect system Ollama installation
      final result = await Process.run('ollama', ['--version']);
      if (result.exitCode == 0) {
        debugPrint('Found system Ollama installation');
        return true;
      }
    } catch (e) {
      debugPrint('System Ollama not found, checking common locations...');
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
  }

  /// Update current setup stage with enhanced messaging
  Future<void> _updateStage(int stageIndex) async {
    if (!mounted) return;
    
    if (stageIndex < _setupStages.length) {
      setState(() {
        _currentStage = stageIndex;
        _statusMessage = _setupStages[stageIndex];
        
        //Auto-download specific detail messages
        switch (stageIndex) {
          case 2:
            _detailMessage = 'Downloading Ollama from official source (this may take several minutes)';
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
      });
      
      // Animate the update
      if (mounted && _animationController.isAnimating) {
        _animationController.forward().then((_) {
          if (mounted) {
            _animationController.reverse();
          }
        });
      }
    }
  }

  /// Test AI response with auto-downloaded components
  Future<void> _testAIResponse() async {
    try {
      final responseData = await OllamaManager.generateEmpatheticResponse(
        "Hello, this is a test to verify the AI is working with auto-downloaded components."
      );
      
      final aiResponse = responseData['response'] as String? ?? '';
      final responseSource = responseData['source'] as String? ?? 'unknown';
      
      if (aiResponse.isNotEmpty) {
        final displayText = aiResponse.length > 50 
            ? '${aiResponse.substring(0, 50)}...'
            : aiResponse;
        debugPrint('AI Test Response: $displayText');
        debugPrint('Response source: $responseSource');
      } else {
        debugPrint('AI Test Response: <empty response>');
      }
      
      if (!mounted) return;
      setState(() {
        _detailMessage = aiResponse.isNotEmpty 
            ? 'AI is responding correctly with auto-downloaded models!' 
            : 'AI test completed with basic response';
      });
      
    } catch (e) {
      debugPrint('AI test failed: $e');
      if (!mounted) return;
      setState(() {
        _detailMessage = 'AI test completed with warnings';
        _errorDetails = e.toString();
      });
    }
  }

  ///Handle setup completion with auto-download confirmation
  Future<void> _completeSetup(String aiType) async {
    if (!mounted) return;
    
    setState(() {
      _isComplete = true;
      _statusMessage = 'Vent AI is ready!';
      _detailMessage = 'Your emotional support companion is now available with auto-downloaded AI';
    });
    
    _animationController.stop();
    
    try {
      if (mounted) {
        final setupProvider = context.read<SetupStateProvider>();
        await setupProvider.markSetupComplete(aiType);
        debugPrint('Setup marked complete with type: $aiType');
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

  ///Handle setup failure with specific auto-download error messaging
  Future<void> _handleSetupFailure(String error) async {
    if (!mounted) return;
    
    setState(() {
      _hasError = true;
      _errorDetails = error;
    });
    
    // Provide specific error messages for auto-download failures
    if (error.contains('download')) {
      setState(() {
        _statusMessage = 'Download Failed';
        _detailMessage = 'Check internet connection and try again. Using offline mode...';
      });
    } else if (error.contains('permission')) {
      setState(() {
        _statusMessage = 'Permission Issue';
        _detailMessage = 'Installation blocked. Try running as administrator. Using offline mode...';
      });
    } else if (error.contains('space')) {
      setState(() {
        _statusMessage = 'Storage Issue';
        _detailMessage = 'Insufficient disk space (~13GB required). Using offline mode...';
      });
    } else {
      setState(() {
        _statusMessage = 'Setup Issue';
        _detailMessage = 'Auto-installation encountered an issue. Using offline mode...';
      });
    }
    
    _animationController.stop();
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Using intelligent offline mode...';
      _detailMessage = 'Smart emotional support available without AI models';
    });
    
    try {
      if (mounted) {
        final setupProvider = context.read<SetupStateProvider>();
        await setupProvider.markSetupComplete('offline_intelligent');
        debugPrint('Setup completed with intelligent fallback mode');
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
        _detailMessage = 'Offline emotional support companion available';
      });
    }
  }

  double get _progressPercentage => (_currentStage + 1) / _setupStages.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon and branding
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
                
                //Installation progress widget with auto-download feedback
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
                              'Auto-Installing',
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
                
                //Auto-download indicator
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
                        Icon(
                          Icons.download_outlined,
                          size: 16,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-downloading from official sources',
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
                
                // ENHANCED: Offline AI indicator with voice capability
                if (_currentStage >= 4) ...[
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
                          'Offline AI • Voice Enabled • Privacy Protected',
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
                
                // Error details (for debugging)
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
                
                // Setup provider state indicator
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
