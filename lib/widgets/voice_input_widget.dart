import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voice_input_service.dart';
import '../services/multimodal_fusion_service.dart';

/// Voice Input Widget for VentAI
/// Provides a complete voice recording interface with visual feedback
/// Integrates with VoiceInputService and MultimodalFusionService
class VoiceInputWidget extends StatefulWidget {
  final Function(String response, String emotion) onVoiceResponse;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final bool enabled;

  const VoiceInputWidget({
    Key? key,
    required this.onVoiceResponse,
    this.onStartRecording,
    this.onStopRecording,
    this.enabled = true,
  }) : super(key: key);

  @override
  _VoiceInputWidgetState createState() => _VoiceInputWidgetState();
}

class _VoiceInputWidgetState extends State<VoiceInputWidget>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasPermission = false;
  String _recordingStatus = 'Tap to record';
  
  // Audio level monitoring
  double _currentAmplitude = 0.0;
  StreamSubscription<double>? _amplitudeSubscription;
  Timer? _amplitudeTimer;
  
  // Enhanced cancellation support
  Timer? _processingTimer;
  bool _userCancelled = false;
  
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkPermissions();
    _startAmplitudeListening();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _checkPermissions() async {
    try {
      final hasPermission = await VoiceInputService.hasPermission();
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          if (!hasPermission) {
            _recordingStatus = 'Permission needed';
          }
        });
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _recordingStatus = 'Permission error';
        });
      }
    }
  }

  // Audio amplitude monitoring simulation
  void _startAmplitudeListening() {
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording && mounted) {
        // Simulate amplitude changes during recording
        final random = DateTime.now().millisecondsSinceEpoch % 1000;
        final amplitude = (random / 1000.0) * 0.8 + 0.1; // Range 0.1 to 0.9
        setState(() {
          _currentAmplitude = amplitude;
        });
      } else if (!_isRecording && mounted) {
        setState(() {
          _currentAmplitude = 0.0;
        });
      }
    });
  }

  // Enhanced start/stop control - allows stopping even when widget disabled
  Future<void> _handleVoiceButtonPress() async {
    debugPrint('Voice button pressed - isRecording: $_isRecording, isProcessing: $_isProcessing, enabled: ${widget.enabled}');
    
    // Allow stopping recording even if widget becomes disabled
    if (!widget.enabled && !_isRecording) {
      debugPrint('Widget disabled and not recording, ignoring tap');
      return;
    }
    
    if (_isProcessing && !_isRecording) {
      debugPrint('Currently processing and not recording, ignoring tap');
      return;
    }
    
    HapticFeedback.mediumImpact();
    
    if (_isRecording) {
      debugPrint('Stopping recording...');
      await _stopRecording();
    } else {
      debugPrint('▶Starting recording...');
      await _startRecording();
    }
  }

  // Enhanced manual start with clear feedback and better error handling
  Future<void> _startRecording() async {
    if (_isRecording || _isProcessing) return;
    
    try {
      setState(() {
        _recordingStatus = 'Initializing microphone...';
        _userCancelled = false;
      });

      // Initialize voice service
      final initialized = await VoiceInputService.initialize();
      if (!initialized) {
        _showError('Unable to access microphone. Please check permissions.');
        return;
      }

      // Start recording (no automatic timeout)
      final started = await VoiceInputService.startRecording();
      if (!started) {
        _showError('Failed to start recording. Please try again.');
        return;
      }

      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordingStatus = 'Recording... Tap STOP to finish';
          _hasPermission = true;
        });

        // Start animations
        _pulseController.repeat(reverse: true);
        _rippleController.repeat();

        // Notify parent
        widget.onStartRecording?.call();

        debugPrint('Voice recording started - waiting for user to stop');
      }

    } catch (e) {
      debugPrint('Start recording error: $e');
      _showError('Recording failed: ${e.toString()}');
      _resetWidget();
    }
  }

  // Manual stop with better timeout and cancellation support
  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    
    try {
      setState(() {
        _isProcessing = true;
        _recordingStatus = 'Stopping recording...';
      });

      // Stop animations immediately for better UX
      _pulseController.stop();
      _rippleController.stop();

      // Add processing timeout timer - auto-cancel after 45 seconds
      _processingTimer = Timer(const Duration(seconds: 45), () {
        if (_isProcessing && !_userCancelled && mounted) {
          debugPrint('Processing timeout reached');
          _cancelProcessing();
        }
      });

      debugPrint('Calling VoiceInputService.stopRecording()...');
      final result = await VoiceInputService.stopRecording().timeout(
        const Duration(seconds: 30),
      );
      
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }

      // Check if user cancelled during stop
      if (_userCancelled) {
        debugPrint('User cancelled during stop');
        _resetWidget();
        return;
      }

      // Validate recording result
      if (result == null || (result['success'] as bool?) != true) {
        _showError('Recording failed. Please try speaking for at least 2 seconds.');
        _resetWidget();
        return;
      }

      debugPrint('Recording stopped successfully, processing audio...');
      
      // Process audio with timeout protection
      await _processVoiceInput(result);

      // Notify parent
      widget.onStopRecording?.call();

    } on TimeoutException {
      debugPrint('Recording stop timed out');
      _showError('Recording stop timed out. Please try again.');
      _resetWidget();
    } catch (e) {
      debugPrint('Stop recording error: $e');
      _showError('Stop recording failed: ${e.toString()}');
      _resetWidget();
    } finally {
      _processingTimer?.cancel();
    }
  }

  //  Enhanced voice processing with proper AI response generation and callback
  Future<void> _processVoiceInput(Map<String, dynamic> recordingResult) async {
    if (_userCancelled) return;
    
    try {
      final audioBase64 = recordingResult['audio_base64'] as String?;
      
      if (audioBase64 == null || audioBase64.isEmpty) {
        debugPrint('No audio data received');
        _showError('No audio data received');
        _resetWidget();
        return;
      }

      debugPrint('🎵 Audio data received: ${audioBase64.length} characters');

      if (mounted && !_userCancelled) {
        setState(() {
          _recordingStatus = 'Step 1: Analyzing voice emotion...';
        });
      }

      // Check for cancellation before processing
      if (_userCancelled) {
        debugPrint('Processing cancelled by user before analysis');
        _resetWidget();
        return;
      }

      debugPrint('CALLING MultimodalFusionService.fuseVoiceAndTextBase64...');
      
      //  Call the multimodal fusion service to get AI response
      final response = await MultimodalFusionService.fuseVoiceAndTextBase64(
        audioBase64: audioBase64,
        textMessage: null,
      ).timeout(const Duration(seconds: 45));

      debugPrint('Got response from MultimodalFusionService: ${response.toString()}');

      // Check for cancellation after processing
      if (_userCancelled || !mounted) {
        debugPrint('Processing completed but user cancelled or widget unmounted');
        return;
      }

      if (mounted && !_userCancelled) {
        setState(() {
          _recordingStatus = 'Step 2: Generating AI response...';
        });
      }

      //  Extract response data properly
      final aiResponse = response['response_recommendation'] ?? 
                        response['response'] ?? 
                        'I hear you and I\'m here to support you.';
      
      final detectedEmotion = response['primary_emotion'] ?? 'neutral';
      final confidence = response['confidence'] ?? 0.5;
      
      debugPrint('Voice analysis complete: $detectedEmotion (${(confidence * 100).round()}% confidence)');
      debugPrint('AI Response: "${aiResponse.substring(0, aiResponse.length.clamp(0, 100))}..."');

      // Show success feedback
      if (mounted && !_userCancelled) {
        setState(() {
          _recordingStatus = 'Voice processed successfully!';
        });

        // Brief delay to show success message
        await Future.delayed(const Duration(milliseconds: 800));

        //  This line MUST be called to display text in chat!
        debugPrint('CALLING widget.onVoiceResponse with: "$aiResponse" and emotion: "$detectedEmotion"');
        widget.onVoiceResponse(aiResponse, detectedEmotion);
        debugPrint('Called onVoiceResponse - should appear in chat now!');
      }
      
      _resetWidget();

    } on TimeoutException {
      if (!_userCancelled) {
        debugPrint('Voice analysis timed out');
        _showError('Voice analysis took too long. Please try again.');
        _resetWidget();
      }
    } catch (e) {
      if (!_userCancelled) {
        debugPrint('Voice processing error: $e');
        _showError('AI processing failed. Please try again.');
        _resetWidget();
      }
    }
  }

  // Better cancellation method with user feedback
  void _cancelProcessing() {
    debugPrint('User cancelled voice processing');
    
    setState(() {
      _userCancelled = true;
      _isProcessing = false;
    });
    
    // Cancel timers
    _processingTimer?.cancel();
    
    // Try to cancel any ongoing voice service operations
    try {
      VoiceInputService.dispose();
    } catch (e) {
      debugPrint('Error disposing voice service: $e');
    }
    
    // Show enhanced cancellation feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Voice processing cancelled'),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    
    _resetWidget();
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _resetWidget() {
    if (!mounted) return;
    
    // Cancel all timers
    _processingTimer?.cancel();
    
    setState(() {
      _isProcessing = false;
      _isRecording = false;
      _userCancelled = false;
      _recordingStatus = _hasPermission ? 'Tap to record' : 'Permission needed';
      _currentAmplitude = 0.0;
    });
    
    _pulseController.reset();
    _rippleController.reset();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate volume level for visual feedback
    final volumeLevel = _currentAmplitude.clamp(0.0, 1.0);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recording Status Text with better visibility
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: _isRecording 
                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                : _isProcessing 
                  ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _recordingStatus,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _isRecording 
                    ? Theme.of(context).colorScheme.primary
                    : _isProcessing
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontWeight: (_isRecording || _isProcessing) ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Voice Recording Button with Enhanced Tap Handling
          GestureDetector(
            onTap: _handleVoiceButtonPress,
            child: Container(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple Effect (only when recording)
                  if (_isRecording) ...[
                    AnimatedBuilder(
                      animation: _rippleAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 80 + (40 * _rippleAnimation.value),
                          height: 80 + (40 * _rippleAnimation.value),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary
                                  .withOpacity(0.3 * (1 - _rippleAnimation.value)),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  // Main Button with Volume-Reactive Shadow
                  AnimatedBuilder(
                    animation: _isRecording ? _pulseAnimation : 
                               const AlwaysStoppedAnimation(1.0),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getButtonColor(),
                            boxShadow: [
                              BoxShadow(
                                color: _getButtonColor().withOpacity(0.4 + (0.3 * volumeLevel)),
                                blurRadius: _isRecording ? 15 + (10 * volumeLevel) : 8,
                                spreadRadius: _isRecording ? 2 + (3 * volumeLevel) : 0,
                              ),
                            ],
                          ),
                          child: _buildButtonIcon(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Audio Level Indicator (only when recording)
          if (_isRecording) ...[
            const SizedBox(height: 4),
            Container(
              width: 60,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade300,
              ),
              child: LinearProgressIndicator(
                value: volumeLevel,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  volumeLevel > 0.5 
                    ? Colors.green      // Good audio level
                    : volumeLevel > 0.2 
                      ? Colors.orange   // Moderate audio level
                      : Colors.red,     // Low audio level
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              volumeLevel > 0.5 
                ? 'Good volume - Keep speaking'
                : volumeLevel > 0.2 
                  ? 'Speak louder'
                  : 'Can\'t hear you',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: volumeLevel > 0.5 
                  ? Colors.green.shade700
                  : volumeLevel > 0.2 
                    ? Colors.orange.shade700
                    : Colors.red.shade700,
              ),
            ),
          ],
          
          // Processing Indicator with PROMINENT Cancel Button
          if (_isProcessing) ...[
            const SizedBox(height: 8),
            // Progress bar
            Container(
              width: 120,
              height: 4,
              child: LinearProgressIndicator(
                backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Processing text and ENHANCED cancel button
            Column(
              children: [
                Text(
                  'Processing your voice...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                // PROMINENT CANCEL BUTTON
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextButton(
                    onPressed: _cancelProcessing,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(0, 0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cancel_outlined, 
                          size: 16, 
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Cancel Processing',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getButtonColor() {
    if (!widget.enabled || !_hasPermission) {
      return Theme.of(context).colorScheme.outline.withOpacity(0.3);
    }
    
    if (_isProcessing) {
      return Theme.of(context).colorScheme.secondary;
    }
    
    if (_isRecording) {
      return Colors.red.shade400; // RED when recording (STOP button)
    }
    
    return Theme.of(context).colorScheme.primary; // BLUE when ready (MIC button)
  }

  Widget _buildButtonIcon() {
    IconData iconData;
    Color iconColor = Colors.white;
    
    if (!widget.enabled || !_hasPermission) {
      iconData = Icons.mic_off;
      iconColor = Theme.of(context).colorScheme.outline;
    } else if (_isProcessing) {
      iconData = Icons.psychology; // BRAIN icon when processing
    } else if (_isRecording) {
      iconData = Icons.stop; // STOP icon when recording
    } else {
      iconData = Icons.mic; // MIC icon when ready
    }
    
    return Icon(
      iconData,
      size: 32,
      color: iconColor,
    );
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _processingTimer?.cancel();
    _pulseController.dispose();
    _rippleController.dispose();
    
    // Clean up voice service
    try {
      VoiceInputService.dispose();
    } catch (e) {
      debugPrint('Error disposing voice service: $e');
    }
    
    super.dispose();
  }
}

/// Compact Voice Input Widget for inline use
class CompactVoiceInputWidget extends StatefulWidget {
  final Function(String response, String emotion) onVoiceResponse;
  final bool enabled;

  const CompactVoiceInputWidget({
    Key? key,
    required this.onVoiceResponse,
    this.enabled = true,
  }) : super(key: key);

  @override
  _CompactVoiceInputWidgetState createState() => _CompactVoiceInputWidgetState();
}

class _CompactVoiceInputWidgetState extends State<CompactVoiceInputWidget> {
  bool _isRecording = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      child: VoiceInputWidget(
        enabled: widget.enabled,
        onVoiceResponse: widget.onVoiceResponse,
        onStartRecording: () {
          setState(() => _isRecording = true);
        },
        onStopRecording: () {
          setState(() => _isRecording = false);
        },
      ),
    );
  }
}
