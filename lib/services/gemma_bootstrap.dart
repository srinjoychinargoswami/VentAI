import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import '../utils/app_paths.dart';

/// Inference engine for VentAI
/// MediaPipeEngine: For .task models (universal compatibility on x86_64 and ARM64)
const kVentAIInferenceEngines = [
  MediaPipeEngine(),
];

/// Bootstrap Gemma model: initialize and download on first launch
/// Uses Gemma 3n E2B .task format (MediaPipe backend)
///
/// Progress tracking:
/// 0% - Download starting
/// 50% - Model file detected (download complete)
/// 100% - Installation complete
Future<bool> bootstrapGemma({
  required Function(int) onProgress,
}) async {
  try {
    debugPrint('📱 Starting Gemma model bootstrap...');

    // Initialize with MediaPipe engine for .task models
    await FlutterGemma.initialize(
      inferenceEngines: kVentAIInferenceEngines,
    );
    debugPrint('✅ FlutterGemma initialized (MediaPipe engine)');

    // Check if model already installed
    try {
      final model = await FlutterGemma.getActiveModel();
      debugPrint('✅ Model already installed (NOT closing - model stays alive)');
      onProgress(100);
      return true;
    } catch (e) {
      debugPrint('📥 Model not installed, proceeding with download...');
    }

    debugPrint('📥 Starting model download...');

    // Get HuggingFace token from environment (compile-time define)
    const String hfToken = String.fromEnvironment('HUGGINGFACE_TOKEN');
    if (hfToken.isNotEmpty) {
      debugPrint('✅ Using HuggingFace token: ${hfToken.substring(0, 10)}...');
    }

    // Download and install Gemma 3 1B .task model (MediaPipe format)
    // Lightweight model (~500MB) for fast downloads and mobile inference
    // .task format works on both x86_64 emulator and ARM64 phones
    debugPrint('📥 Starting model download with foreground service (3-5 minutes)...');
    debugPrint('📦 Model: Gemma 3 1B (~500MB)');

    // Report download starting
    onProgress(0);

    // Start file existence checker in background
    final fileChecker = _startFileExistenceChecker(onProgress);

    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task, // ← CRITICAL: .task format
      ).fromNetwork(
        'https://huggingface.co/AfiOne/gemma3-1b-it-int4.task/resolve/main/gemma3-1b-it-int4.task',
        token: hfToken.isNotEmpty ? hfToken : null,
        foreground: true, // ← Use foreground service for reliable downloads
      ).install();

      debugPrint('✅ Model installed successfully');

      // Stop file checker and report completion
      fileChecker.cancel();
      onProgress(100);
      return true;
    } catch (e) {
      fileChecker.cancel();
      rethrow;
    }

  } catch (e) {
    debugPrint('❌ Bootstrap failed: $e');
    return false;
  }
}

/// Monitor model file existence
/// 0% → download starting
/// 50% → file detected (download complete)
/// 100% → install complete (reported separately)
Timer _startFileExistenceChecker(Function(int) onProgress) {
  bool fileDetected = false;

  return Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
    try {
      final modelsPath = await AppPaths.getModelsDirectory();
      final modelDir = Directory(modelsPath);

      if (!await modelDir.exists()) {
        return;
      }

      // Check if any .task files exist
      await for (final entity in modelDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.task')) {
          if (!fileDetected) {
            fileDetected = true;
            debugPrint('📥 Download complete - model file detected');
            onProgress(50);
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ File checker error: $e');
    }
  });
}

/// Check if Gemma model is ready for inference
/// NOTE: Do NOT close model - it needs to stay alive for entire app
Future<bool> isGemmaModelReady() async {
  try {
    final model = await FlutterGemma.getActiveModel();
    debugPrint('✅ Model is ready (NOT closing - stays alive)');
    return true;
  } catch (e) {
    debugPrint('⚠️ Error checking model status: $e');
    return false;
  }
}
