import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

/// Voice Input Service for VentAI
/// Handles voice recording, permission management, and audio processing
/// Integrates with existing multimodal fusion service
class VoiceInputService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static bool _isRecording = false;
  static bool _isInitialized = false;
  static String? _currentRecordingPath;
  
  /// Initialize the voice input service with permissions
  static Future<bool> initialize() async {
    try {
      debugPrint('Initializing VoiceInputService...');
      
      // Check if already initialized
      if (_isInitialized) {
        debugPrint('VoiceInputService already initialized');
        return true;
      }
      
      // Request microphone permissions
      final permissionStatus = await _requestMicrophonePermission();
      if (!permissionStatus) {
        debugPrint('Microphone permission denied');
        return false;
      }
      
      // Check if recorder is available
      final isAvailable = await _recorder.hasPermission();
      if (!isAvailable) {
        debugPrint('Audio recorder not available');
        return false;
      }
      
      _isInitialized = true;
      debugPrint('VoiceInputService initialized successfully');
      return true;
      
    } catch (e) {
      debugPrint('VoiceInputService initialization error: $e');
      return false;
    }
  }
  
  /// Request microphone permission with proper handling
  static Future<bool> _requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      
      if (status.isGranted) {
        debugPrint('Microphone permission already granted');
        return true;
      }
      
      if (status.isDenied) {
        debugPrint('Requesting microphone permission...');
        final result = await Permission.microphone.request();
        return result.isGranted;
      }
      
      if (status.isPermanentlyDenied) {
        debugPrint('Microphone permission permanently denied');
        // Could open app settings here if needed
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }
  
  /// Start voice recording with optimized settings for emotion analysis
  static Future<bool> startRecording() async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) return false;
      }
      
      if (_isRecording) {
        debugPrint('Recording already in progress');
        return false;
      }
      
      // Get temporary directory for audio file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'vent_ai_recording_$timestamp.wav';
      final recordingPath = '${tempDir.path}/$fileName'; // Local non-nullable variable
      
      // Store it in the class variable
      _currentRecordingPath = recordingPath;
      
      // Configure recording settings optimized for voice emotion analysis
      const config = RecordConfig(
        encoder: AudioEncoder.wav,          // Uncompressed for better analysis
        sampleRate: 16000,                  // Good for voice analysis
        bitRate: 128000,                    // Sufficient quality
        numChannels: 1,                     // Mono for emotion analysis
        autoGain: true,                     // Normalize volume
        echoCancel: true,                   // Reduce echo
        noiseSuppress: true,                // Reduce background noise
      );
      
      // Start recording with guaranteed non-null path
      await _recorder.start(config, path: recordingPath);
      _isRecording = true;
      
      debugPrint('Recording started: $recordingPath');
      return true;
      
    } catch (e) {
      debugPrint('Start recording error: $e');
      _isRecording = false;
      return false;
    }
  }
  
  /// Stop recording and return audio data
  static Future<Map<String, dynamic>?> stopRecording() async {
    try {
      if (!_isRecording) {
        debugPrint('No recording in progress');
        return null;
      }
      
      // Stop the recording
      final path = await _recorder.stop();
      _isRecording = false;
      
      if (path == null || path.isEmpty) {
        debugPrint('Recording failed - no audio file created');
        return null;
      }
      
      // Verify file exists and has content
      final audioFile = File(path);
      if (!await audioFile.exists()) {
        debugPrint('Audio file does not exist: $path');
        return null;
      }
      
      final fileSize = await audioFile.length();
      if (fileSize < 1000) { // Less than 1KB indicates likely failure
        debugPrint('Audio file too small (${fileSize}B) - recording may have failed');
        return null;
      }
      
      debugPrint('Recording completed: ${fileSize}B audio file');
      
      // Convert to base64 for multimodal processing
      final audioBase64 = await _convertAudioToBase64(path);
      if (audioBase64 == null) {
        debugPrint('Failed to convert audio to base64');
        return null;
      }
      
      // Get basic audio metadata
      final metadata = await _getAudioMetadata(path);
      
      // Return comprehensive result
      return {
        'success': true,
        'audio_path': path,
        'audio_base64': audioBase64,
        'file_size': fileSize,
        'duration_seconds': metadata['duration'] ?? 0.0,
        'sample_rate': metadata['sample_rate'] ?? 16000,
        'recording_timestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      debugPrint('Stop recording error: $e');
      _isRecording = false;
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Convert audio file to base64 string for multimodal processing
  static Future<String?> _convertAudioToBase64(String audioPath) async {
    try {
      final audioFile = File(audioPath);
      final audioBytes = await audioFile.readAsBytes();
      final base64String = base64Encode(audioBytes);
      
      debugPrint('Audio converted to base64: ${base64String.length} characters');
      return base64String;
      
    } catch (e) {
      debugPrint('Base64 conversion error: $e');
      return null;
    }
  }
  
  /// Get basic audio metadata for analysis
  static Future<Map<String, dynamic>> _getAudioMetadata(String audioPath) async {
    try {
      final audioFile = File(audioPath);
      final fileSize = await audioFile.length();
      
      // Estimate duration based on file size and recording config
      // For 16kHz mono WAV: ~32KB per second
      final estimatedDuration = fileSize / 32000.0;
      
      return {
        'duration': estimatedDuration,
        'sample_rate': 16000,
        'channels': 1,
        'file_size': fileSize,
      };
      
    } catch (e) {
      debugPrint('Metadata extraction error: $e');
      return {
        'duration': 0.0,
        'sample_rate': 16000,
        'channels': 1,
        'file_size': 0,
      };
    }
  }
  
  /// Test audio playback (useful for debugging)
  static Future<bool> playLastRecording() async {
    try {
      if (_currentRecordingPath == null) {
        debugPrint('No recording available to play');
        return false;
      }
      
      final audioFile = File(_currentRecordingPath!);
      if (!await audioFile.exists()) {
        debugPrint('Audio file no longer exists');
        return false;
      }
      
      debugPrint('Playing back recording...');
      await _player.setFilePath(_currentRecordingPath!);
      await _player.play();
      
      return true;
      
    } catch (e) {
      debugPrint('Playback error: $e');
      return false;
    }
  }
  
  /// Stop any ongoing playback
  static Future<void> stopPlayback() async {
    try {
      await _player.stop();
      debugPrint('Playback stopped');
    } catch (e) {
      debugPrint('Stop playback error: $e');
    }
  }
  
  /// Clean up temporary audio files
  static Future<void> cleanupTempFiles() async {
    try {
      if (_currentRecordingPath != null) {
        final audioFile = File(_currentRecordingPath!);
        if (await audioFile.exists()) {
          await audioFile.delete();
          debugPrint('🧹 Cleaned up temp audio file');
        }
        _currentRecordingPath = null;
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }
  
  /// Get current recording status
  static bool get isRecording => _isRecording;
  
  /// Get initialization status
  static bool get isInitialized => _isInitialized;
  
  /// Get current recording path
  static String? get currentRecordingPath => _currentRecordingPath;
  
  /// Check if microphone permission is granted
  static Future<bool> hasPermission() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }
  
  /// Dispose of resources
  static Future<void> dispose() async {
    try {
      debugPrint('Disposing VoiceInputService...');
      
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
      }
      
      await _player.dispose();
      await cleanupTempFiles();
      
      _isInitialized = false;
      debugPrint('VoiceInputService disposed');
      
    } catch (e) {
      debugPrint('Dispose error: $e');
    }
  }
  
  /// Quick voice recording method for easy integration
  /// Records for specified duration and returns processed result
  static Future<Map<String, dynamic>?> quickRecord({
    int durationSeconds = 5,
    bool autoCleanup = true,
  }) async {
    try {
      debugPrint('🎤 Starting quick recording for ${durationSeconds}s...');
      
      // Start recording
      final started = await startRecording();
      if (!started) {
        debugPrint('Failed to start quick recording');
        return null;
      }
      
      // Wait for specified duration
      await Future.delayed(Duration(seconds: durationSeconds));
      
      // Stop and get result
      final result = await stopRecording();
      
      // Cleanup if requested
      if (autoCleanup && result != null) {
        // Keep the audio data but clean up the file
        await cleanupTempFiles();
      }
      
      return result;
      
    } catch (e) {
      debugPrint('Quick record error: $e');
      return null;
    }
  }
  
  /// Integration method for your existing multimodal fusion service
  /// Records voice and returns base64 data ready for processing
  static Future<String?> recordForMultimodalAnalysis({
    int maxDurationSeconds = 10,
  }) async {
    try {
      debugPrint('Recording voice for multimodal analysis...');
      
      final started = await startRecording();
      if (!started) return null;
      
      // Wait for recording (could be user-controlled in UI)
      await Future.delayed(Duration(seconds: maxDurationSeconds));
      
      final result = await stopRecording();
      if (result == null || result['success'] != true) {
        debugPrint('Voice recording failed for multimodal analysis');
        return null;
      }
      
      final audioBase64 = result['audio_base64'] as String?;
      debugPrint('Voice recording ready for multimodal analysis');
      
      return audioBase64;
      
    } catch (e) {
      debugPrint('Multimodal recording error: $e');
      return null;
    }
  }
}
