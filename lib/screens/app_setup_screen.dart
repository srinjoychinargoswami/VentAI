import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/setup_state_provider.dart';
import '../theme/app_colors.dart';
import 'model_license_screen.dart';
import '../utils/platform_utils.dart';

class AppSetupScreen extends StatefulWidget {
  final String message;

  const AppSetupScreen(
      {Key? key, this.message = 'Setting up your AI companion...'})
      : super(key: key);

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

  bool _failureDialogOpen = false;

  /// Shown when a download fails. Retry restarts the download; Cancel clears
  /// the license acceptance and returns to the license screen.
  Future<void> _showFailureDialog(SetupStateProvider setup) async {
    _failureDialogOpen = true;
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Download failed',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Text(
            'The AI model could not be downloaded, so Vent AI cannot start yet.\n\n'
            '${setup.errorMessage ?? 'Unknown error'}\n\n'
            'Check your internet connection (a stable Wi-Fi connection is recommended) and retry.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textTertiary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    _failureDialogOpen = false;
    if (!mounted) return;
    if (retry == true) {
      setup.startDownloading();
    } else {
      await setup.cancelAfterFailure();
    }
  }

  /// Size disclosure shown before the download starts. Returns true only if
  /// the user explicitly taps Download.
  Future<bool> _confirmDownload(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        title: const Text(
          'Download Gemma 4 E2B Model?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Size: ~2.6GB',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Estimated download time: 10-15 minutes on typical WiFi, '
              'faster on stronger connections',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'A stable Wi-Fi connection is recommended for this ~2.6GB download. '
              'Keep the app open while it downloads.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.textTertiary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  double get _progressPercentage => (_currentStage + 1) / _setupStages.length;

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupStateProvider>(
      builder: (context, setupState, child) {
        // Show license screen ONLY if accepting license AND not yet accepted
        // (Message will say "Please accept" if not accepted, "Ready to download" if accepted)
        // Failure dialog: once per failure, after the failed attempt has settled.
        if (setupState.currentStage == SetupStage.error &&
            !setupState.isInitializing &&
            !_failureDialogOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                !_failureDialogOpen &&
                setupState.currentStage == SetupStage.error &&
                !setupState.isInitializing) {
              _showFailureDialog(setupState);
            }
          });
        }

        final isAcceptingLicense =
            setupState.currentStage == SetupStage.acceptingLicense;
        final needsAcceptance =
            setupState.setupMessage.contains('Please accept');

        debugPrint(
            '🏗️ [SETUP-SCREEN] Build: stage=${setupState.currentStage}, '
            'needsAcceptance=$needsAcceptance, msg="${setupState.setupMessage}"');

        if (isAcceptingLicense && needsAcceptance) {
          debugPrint('📜 [SETUP-SCREEN] Showing license screen');
          return const ModelLicenseScreen();
        }

        // Otherwise show setup progress screen
        debugPrint('🏗️ [SETUP-SCREEN] Showing progress screen');
        return _buildSetupProgressScreen(context, setupState);
      },
    );
  }

  /// Build the setup progress screen
  Widget _buildSetupProgressScreen(
      BuildContext context, SetupStateProvider setupState) {
    final stats = setupState.downloadStats;
    final platformEmoji = isMobileOS() ? '📱' : '🖥️';
    final platformName = isMobileOS() ? 'Mobile' : 'Desktop';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
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
                  if (stats != null &&
                      stats.percent < 100 &&
                      !setupState.isSetupComplete &&
                      setupState.currentStage != SetupStage.error) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            'Downloading Gemma 4 E2B... ${stats.percent}%',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: stats.percent / 100.0,
                            minHeight: 6,
                            backgroundColor: AppColors.surface,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Speed: ${stats.speedMBps.toStringAsFixed(1)} MB/s',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stats.stalled
                                ? 'Download seems slow. Check your connection; it will continue when it improves.'
                                : 'Time remaining: ${stats.remainingText}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: stats.stalled
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.warning.withOpacity(0.3)),
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
                        color: _hasError
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Start Download button (shown when license accepted, waiting for user action)
                  Consumer<SetupStateProvider>(
                    builder: (context, setupProvider, child) {
                      final readyToDownload = setupProvider.currentStage ==
                              SetupStage.acceptingLicense &&
                          !_isComplete &&
                          !_hasError &&
                          setupProvider.setupMessage.contains('Ready');

                      if (setupProvider.currentStage == SetupStage.error &&
                          !setupProvider.isInitializing) {
                        return SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => setupProvider.startDownloading(),
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('Retry Download'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }

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
                              onPressed: () async {
                                debugPrint('User tapping "Start Download"...');
                                final confirmed =
                                    await _confirmDownload(context);
                                if (!confirmed) {
                                  debugPrint(
                                      'User cancelled download at size disclosure');
                                  return;
                                }
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1.5),
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
                  if (_currentStage >= (isMobileOS() ? 2 : 4)) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.3),
                            width: 1.5),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
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
      ),
    );
  }
}
