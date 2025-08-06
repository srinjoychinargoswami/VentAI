// lib/widgets/installation_progress_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ollama_manager.dart';

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

  @override
  void initState() {
    super.initState();
    _startProgressMonitoring();
  }

  void _startProgressMonitoring() {
    _progressTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _updateProgress();
    });
    _updateProgress(); // Initial update
  }

  ///Update progress with auto-installation phase detection
  Future<void> _updateProgress() async {
    try {
      // Check Ollama service status
      final serviceRunning = await OllamaManager.ensureServiceRunning();
      
      // Get model status and cache information
      final models = await OllamaManager.getAvailableModels();
      final cacheInfo = await OllamaManager.getModelCacheInfo();
      
      // Calculate progress and status based on auto-installation phases
      double progress = 0.0;
      String status = 'Connecting...';
      String details = '';
      bool hasError = false;
      String errorMsg = '';

      if (!serviceRunning) {
        // Check if this is initial installation or service restart
        if (await _checkIfOllamaInstalled()) {
          progress = 0.3;
          status = 'Starting Ollama service...';
          details = 'Service initialization in progress';
        } else {
          progress = 0.1;
          status = 'Installing Ollama...';
          details = 'Downloading and installing Ollama from official source';
        }
      } else {
        // Service is running - check model status
        final allModelsAvailable = cacheInfo['allRequiredAvailable'] as bool? ?? false;
        final downloadStatus = cacheInfo['downloadStatus'] as Map<String, dynamic>? ?? {};
        
        if (!allModelsAvailable && models.isEmpty) {
          progress = 0.6;
          status = 'Downloading AI models...';
          details = 'Downloading Gemma models (this may take several minutes)';
          
          //  Show specific model download progress
          if (downloadStatus.isNotEmpty) {
            final downloadingModels = downloadStatus.entries
                .where((e) => e.value == false)
                .map((e) => e.key)
                .toList();
            if (downloadingModels.isNotEmpty) {
              details += '\nCurrently downloading: ${downloadingModels.join(", ")}';
            }
          }
        } else if (models.isNotEmpty) {
          progress = 1.0;
          status = 'AI Ready - All Systems Operational';
          details = 'Models cached and ready: ${models.length} available';
        } else {
          progress = 0.5;
          status = 'AI Service Connected';
          details = 'Service running, preparing models...';
        }
      }

      // Update UI state
      if (mounted) {
        setState(() {
          _isConnected = serviceRunning && models.isNotEmpty;
          _downloadProgress = progress;
          _currentStatus = status;
          _detailStatus = details;
          _availableModels = models;
          _hasError = hasError;
          _errorMessage = errorMsg;
        });
      }
    } catch (e) {
      //Specific error handling for different failure types
      String errorType = 'Connection Error';
      String errorDetails = e.toString();
      
      if (errorDetails.contains('download')) {
        errorType = 'Download Failed';
        errorDetails = 'Check internet connection and try again';
      } else if (errorDetails.contains('permission')) {
        errorType = 'Permission Error';
        errorDetails = 'Installation blocked - try running as administrator';
      } else if (errorDetails.contains('space')) {
        errorType = 'Storage Error';
        errorDetails = 'Insufficient disk space (~13GB required)';
      } else if (errorDetails.contains('timeout')) {
        errorType = 'Connection Timeout';
        errorDetails = 'Service taking longer than expected to respond';
      }

      if (mounted) {
        setState(() {
          _currentStatus = errorType;
          _detailStatus = errorDetails;
          _errorMessage = e.toString();
          _hasError = true;
          _isConnected = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  ///Check if Ollama is installed (simplified version)
  Future<bool> _checkIfOllamaInstalled() async {
    try {
      // This would ideally call a method from OllamaManager
      // For now, we'll use a simple heuristic
      final models = await OllamaManager.getAvailableModels();
      return models.isNotEmpty; // If we can get models, Ollama is likely installed
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            //Status Header with better visual indicators
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _hasError
                        ? Colors.red
                        : (_isConnected
                            ? Colors.green
                            : (_downloadProgress > 0 ? Colors.orange : Colors.grey)),
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
                      color: _hasError ? Colors.red.shade700 : null,
                    ),
                  ),
                ),
                //Progress percentage display
                if (_downloadProgress > 0 && !_hasError && !_isConnected) ...[
                  Text(
                    '${(_downloadProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            
            //Progress Bar with better visual feedback
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _hasError
                    ? Colors.red
                    : (_isConnected ? Colors.green : Colors.blue),
              ),
            ),
            
            const SizedBox(height: 12),
            
            //Detailed Status with auto-installation phases
            Text(
              _detailStatus,
              style: TextStyle(
                fontSize: 13,
                color: _hasError ? Colors.red.shade600 : Colors.grey[700],
                height: 1.3,
              ),
            ),
            
            //Error message display (if any)
            if (_hasError && _errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Debug: $_errorMessage',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.shade600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            
            //Available Models display
            if (_availableModels.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Models:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _availableModels.join(', '),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            //Auto-installation indicator
            if (_downloadProgress > 0 && _downloadProgress < 1.0 && !_hasError) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.download_outlined,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Auto-Installing • Offline AI',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w600,
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
