import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/gemma_service.dart';

class InstallationProgressWidget extends StatefulWidget {
  const InstallationProgressWidget({super.key});

  @override
  State<InstallationProgressWidget> createState() => _InstallationProgressWidgetState();
}

class _InstallationProgressWidgetState extends State<InstallationProgressWidget> {
  Timer? _progressTimer;
  double _downloadProgress = 0.0;
  String _currentStatus = 'Initializing...';
  String _detailStatus = '';
  String _errorMessage = '';
  bool _isConnected = false;
  bool _hasError = false;
  List<String> _availableModels = [];
  
  // Platform detection
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;
  bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _startProgressMonitoring();
  }

  void _startProgressMonitoring() {
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _updateProgress();
    });
    _updateProgress(); // Initial update
  }

  /// Platform-specific progress monitoring
  Future<void> _updateProgress() async {
    try {
      if (_isMobile) {
        await _updateMobileProgress();
      } else if (_isDesktop) {
        await _updateDesktopProgress();
      }
    } catch (e) {
      _handleProgressError(e);
    }
  }

  /// Mobile progress monitoring with Gemma
  Future<void> _updateMobileProgress() async {
    try {
      final platformPrefix = '📱';

      // Get Gemma status
      final status = await GemmaService().getStatus();

      final isInitialized = status['initialized'] as bool? ?? false;
      final modelLoaded = status['model_loaded'] as bool? ?? false;
      final canGenerate = status['can_generate'] as bool? ?? false;

      String statusText = 'Initializing Gemma AI...';
      String details = '';
      bool hasError = false;
      String errorMsg = '';

      if (!isInitialized) {
        // Still initializing
        statusText = 'Loading Gemma model...';
        details = 'This may take a moment on first launch';
      } else if (modelLoaded && canGenerate) {
        // Model ready
        statusText = 'Gemma Ready';
        details = 'AI model loaded and ready for conversation';
        _isConnected = true;
      } else if (isInitialized) {
        // Initialized but still loading
        statusText = 'Preparing AI model...';
        details = 'Setting up Gemma for offline use';
      }

      if (mounted) {
        setState(() {
          _currentStatus = '$platformPrefix $statusText';
          _detailStatus = details;
          _hasError = hasError;
          _errorMessage = errorMsg;
          _availableModels = modelLoaded ? ['Gemma 4 E2B'] : [];
        });
      }
    } catch (e) {
      debugPrint('📱 Mobile progress error: $e');
      _handleProgressError(e);
    }
  }

  /// Desktop progress monitoring (same as mobile - using Gemma)
  Future<void> _updateDesktopProgress() async {
    try {
      final platformPrefix = '🖥️';

      // Get Gemma status (same as mobile)
      final status = await GemmaService().getStatus();

      final isInitialized = status['initialized'] as bool? ?? false;
      final modelLoaded = status['model_loaded'] as bool? ?? false;
      final canGenerate = status['can_generate'] as bool? ?? false;

      String statusText = 'Initializing Gemma AI...';
      String details = '';
      bool hasError = false;
      String errorMsg = '';

      if (!isInitialized) {
        // Still initializing
        statusText = 'Loading Gemma model...';
        details = 'This may take a moment on first launch';
      } else if (modelLoaded && canGenerate) {
        // Model ready
        statusText = 'Gemma Ready';
        details = 'AI model loaded and ready for conversation';
        _isConnected = true;
      } else if (isInitialized) {
        // Initialized but still loading
        statusText = 'Preparing AI model...';
        details = 'Setting up Gemma for offline use';
      }

      if (mounted) {
        setState(() {
          _currentStatus = '$platformPrefix $statusText';
          _detailStatus = details;
          _hasError = hasError;
          _errorMessage = errorMsg;
          _availableModels = modelLoaded ? ['Gemma 4 E2B'] : [];
        });
      }
    } catch (e) {
      debugPrint('🖥️ Desktop progress error: $e');
      _handleProgressError(e);
    }
  }

  /// Unified error handling
  void _handleProgressError(dynamic e) {
    String errorType = 'Connection Error';
    String errorDetails = e.toString();
    
    if (errorDetails.contains('download')) {
      errorType = 'Download Failed';
      errorDetails = 'Check internet connection and try again';
    } else if (errorDetails.contains('permission')) {
      errorType = 'Permission Error';
      errorDetails = _isMobile 
          ? 'App permissions issue - check settings'
          : 'Installation blocked - try running as administrator';
    } else if (errorDetails.contains('space') || errorDetails.contains('storage')) {
      errorType = 'Storage Error';
      errorDetails = _isMobile
          ? 'Insufficient storage (model requires ~2GB)'
          : 'Insufficient disk space (~13GB required)';
    } else if (errorDetails.contains('timeout')) {
      errorType = 'Connection Timeout';
      errorDetails = 'Service taking longer than expected';
    }

    if (mounted) {
      setState(() {
        _currentStatus = errorType;
        _detailStatus = errorDetails;
        _errorMessage = e.toString();
        _hasError = true;
        _isConnected = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final platformEmoji = _isMobile ? '📱' : '🖥️';
    final platformName = _isMobile ? 'Mobile' : 'Desktop';
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Header
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _hasError
                        ? AppColors.error
                        : (_isConnected
                            ? AppColors.success
                            : AppColors.warning),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentStatus,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: _hasError ? AppColors.error : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress Bar
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                _hasError
                    ? AppColors.error
                    : (_isConnected ? AppColors.success : AppColors.primary),
              ),
            ),

            const SizedBox(height: 12),

            // Detailed Status
            Text(
              _detailStatus,
              style: TextStyle(
                fontSize: 13,
                color: _hasError ? AppColors.error : AppColors.textTertiary,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 12),

            // Keep App Open Warning
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep the app open during download.\nDo not close or minimize.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error message
            if (_hasError && _errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Text(
                  'Debug: $_errorMessage',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.error,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            
            // Available Models
            if (_availableModels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Models:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _availableModels.join(', '),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }
}