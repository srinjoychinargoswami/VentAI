import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/installation_progress_widget.dart';
import '../services/gemma_service.dart';
import '../services/gemma_bootstrap.dart';
import '../providers/setup_state_provider.dart';
import '../theme/app_colors.dart';
import 'model_license_screen.dart';

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
  double _downloadProgress = 0.0;
  
  /// Platform-specific setup stages (same for both platforms now)
  List<String> get _setupStages {
    return [
      'Checking system requirements...',
      'Initializing Gemma AI...',
      'Loading AI model...',
      'Configuring AI...',
      'Testing AI functionality...',
      'Setup complete!'
    ];
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

    // CRITICAL: Start setup through provider (not screen's _runCompleteSetup)
    // Provider will pause at license screen, requiring explicit user action
    Future.microtask(() async {
      if (mounted) {
        final setupProvider = context.read<SetupStateProvider>();
        await setupProvider.startCompleteSetup();
      }
    });
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

      // Download and setup model with real progress tracking
      final success = await bootstrapGemma(
        onProgress: (progress) {
          if (mounted) {
            final message = progress == 0
                ? 'Starting download...'
                : progress == 50
                    ? 'Download complete, installing...'
                    : 'Installation complete';

            setState(() {
              _downloadProgress = progress / 100.0;
              _statusMessage = 'Downloading Gemma 4 E2B model...';
              _detailMessage = message;
              _currentStage = 1;
            });
            debugPrint('📱 Progress: $progress% - $message');
          }
        },
      );

      if (!success) {
        await _handleSetupFailure('Model download failed');
        return;
      }

      if (!mounted) return;

      // Initialize GemmaService after download
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

  /// Desktop-specific setup (now same as mobile - using Gemma)
  Future<void> _runDesktopSetup() async {
    try {
      final platformPrefix = '🖥️';

      await _updateStage(1); // Initializing Gemma AI
      if (!mounted) return;
      debugPrint('$platformPrefix Initializing Gemma...');

      // Download and setup model with real progress tracking (same as mobile)
      final success = await bootstrapGemma(
        onProgress: (progress) {
          if (mounted) {
            final message = progress == 0
                ? 'Starting download...'
                : progress == 50
                    ? 'Download complete, installing...'
                    : 'Installation complete';

            setState(() {
              _downloadProgress = progress / 100.0;
              _statusMessage = 'Downloading Gemma 4 E2B model...';
              _detailMessage = message;
              _currentStage = 1;
            });
            debugPrint('🖥️ Progress: $progress% - $message');
          }
        },
      );

      if (!success) {
        await _handleSetupFailure('Model download failed');
        return;
      }

      if (!mounted) return;

      // Initialize GemmaService after download
      await GemmaService().initialize();

      if (!mounted) return;
      await _updateStage(2); // Loading AI model
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      await _updateStage(3); // Configuring AI
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      await _updateStage(4); // Testing AI functionality
      await _testDesktopAIResponse();

      if (!mounted) return;
      await _updateStage(5); // Setup complete
      await _completeSetup('gemma_desktop');

    } catch (e) {
      debugPrint('🖥️ Desktop setup failed: $e');
      await _handleSetupFailure('Desktop setup failed: $e');
    }
  }

  /// Update stage with platform-specific messaging
  Future<void> _updateStage(int stageIndex) async {
    if (!mounted) return;
    
    if (stageIndex < _setupStages.length) {
      setState(() {
        _currentStage = stageIndex;
        _statusMessage = _setupStages[stageIndex];
        
        // Platform-agnostic detail messages (same for both)
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

  /// Test desktop AI response using Gemma
  Future<void> _testDesktopAIResponse() async {
    try {
      debugPrint('🖥️ Testing Gemma AI...');

      final response = await GemmaService().generateEmotionalResponse(
        "Hello, this is a test"
      );

      if (response.isNotEmpty) {
        final displayText = response.length > 50
            ? '${response.substring(0, 50)}...'
            : response;
        debugPrint('🖥️ Gemma Test Response: $displayText');
      }

      if (!mounted) return;
      setState(() {
        _detailMessage = response.isNotEmpty
            ? 'Gemma AI is responding correctly!'
            : 'Gemma AI test completed';
      });

    } catch (e) {
      debugPrint('🖥️ Gemma test failed: $e');
      if (!mounted) return;
      setState(() {
        _detailMessage = 'Gemma test completed with warnings';
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
      _detailMessage = 'Your emotional support companion is ready';
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
    return Consumer<SetupStateProvider>(
      builder: (context, setupState, child) {
        // Show license screen ONLY if accepting license AND not yet accepted
        // (Message will say "Please accept" if not accepted, "Ready to download" if accepted)
        if (setupState.currentStage == SetupStage.acceptingLicense &&
            setupState.setupMessage.contains('Please accept')) {
          return const ModelLicenseScreen();
        }

        // Otherwise show setup progress screen
        return _buildSetupProgressScreen(context);
      },
    );
  }

  /// Build the setup progress screen
  Widget _buildSetupProgressScreen(BuildContext context) {
    final platformEmoji = _isMobile ? '📱' : '🖥️';
    final platformName = _isMobile ? 'Mobile' : 'Desktop';

    return Scaffold(
      backgroundColor: AppColors.background,
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
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology,
                    size: 60,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Vent AI',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Your personal emotional support companion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Download progress bar - simple and clean
                if (_downloadProgress > 0 && _downloadProgress < 1.0 && !_isComplete && !_hasError) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Text(
                          'Downloading Gemma 4 E2B model...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          minHeight: 6,
                          backgroundColor: AppColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 20,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Keep the app open during download.\nDo not close or minimize.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Installation progress (single unified display)
                const InstallationProgressWidget(),

                const SizedBox(height: 40),

                // Success/Error icon
                if (_isComplete) ...[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 40,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (_hasError) ...[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.warning.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      size: 40,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Status message (Primary message)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    _statusMessage,
                    key: ValueKey(_statusMessage),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _hasError
                        ? AppColors.warning
                        : _isComplete
                          ? AppColors.success
                          : AppColors.textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Detail message (Secondary message)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    _detailMessage,
                    key: ValueKey(_detailMessage),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: _hasError ? AppColors.warning : AppColors.textSecondary,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                
                const SizedBox(height: 28),

                // Start Download button (shown when license accepted, waiting for user action)
                Consumer<SetupStateProvider>(
                  builder: (context, setupProvider, child) {
                    final readyToDownload = setupProvider.currentStage == SetupStage.acceptingLicense &&
                        !_isComplete &&
                        !_hasError &&
                        setupProvider.setupMessage.contains('Ready');

                    if (readyToDownload) {
                      return Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              debugPrint('User tapping "Start Download"...');
                              setupProvider.startDownloading();
                            },
                            icon: const Icon(Icons.download, size: 20),
                            label: const Text(
                              'Start Download',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 24),

                // Platform indicator
                if (!_isComplete && !_hasError) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          platformEmoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$platformName AI Setup',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Offline AI indicator
                if (_currentStage >= (_isMobile ? 2 : 4)) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.1),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Privacy Protected • Offline AI',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Debug: $_errorDetails',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
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