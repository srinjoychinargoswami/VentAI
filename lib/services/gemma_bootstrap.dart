import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import '../utils/app_paths.dart';

/// Bootstrap Gemma model: initialize and download on first launch
/// Uses Gemma 4 E2B .litertlm format (LiteRT-LM backend)
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
    debugPrint('📝 Engine already initialized by main.dart');

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

    // Download and install Gemma 4 E2B .litertlm model (LiteRT-LM format)
    // Lightweight model (~500MB) for fast downloads and ARM64 mobile inference
    // .litertlm format optimized for ARM64 architecture (NOT compatible with x86_64 emulator)
    debugPrint('📥 Starting model download with foreground service (3-5 minutes)...');
    debugPrint('📦 Model: Gemma 4 E2B (~500MB) - ARM64 optimized');

    // Report download starting
    onProgress(0);

    // Start file existence checker in background
    final fileChecker = _startFileExistenceChecker(onProgress);

    try {
      debugPrint('📥 [DOWNLOAD STEP 1] Creating installModel builder...');
      final builder = FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      );
      debugPrint('✅ [DOWNLOAD STEP 1] Builder created');

      debugPrint('📥 [DOWNLOAD STEP 2] Configuring network source...');
      final networkBuilder = builder.fromNetwork(
        'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
        token: hfToken.isNotEmpty ? hfToken : null,
        foreground: true,
      );
      debugPrint('✅ [DOWNLOAD STEP 2] Network source configured');

      debugPrint('📥 [DOWNLOAD STEP 3] Starting actual download & install...');
      await networkBuilder.install();
      debugPrint('✅ [DOWNLOAD STEP 3] Model installed successfully');

      debugPrint('📥 [DOWNLOAD STEP 4] Skipping setActiveModel (auto-set by install)');
      // FlutterGemma automatically sets model as active during installModel()
      // No separate setActiveModel() call needed in v1.3.2
      debugPrint('✅ [DOWNLOAD STEP 4] Model auto-set as active during install');

      // Verify installation
      debugPrint('📥 [DOWNLOAD STEP 5] Verifying model is active...');
      try {
        final activeModel = await FlutterGemma.getActiveModel(maxTokens: 250);
        debugPrint('✅ [DOWNLOAD STEP 5] Verified - Active model ready');
      } catch (e) {
        debugPrint('⚠️ [DOWNLOAD STEP 5] Could not verify: $e');
      }

      // Stop file checker and report completion
      fileChecker.cancel();
      onProgress(100);
      return true;
    } catch (e) {
      debugPrint('❌ [DOWNLOAD ERROR] Failed at step: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
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
  int checkCount = 0;

  return Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
    try {
      checkCount++;
      final modelsPath = await AppPaths.getModelsDirectory();
      final modelDir = Directory(modelsPath);

      if (!await modelDir.exists()) {
        if (checkCount % 5 == 0) {
          debugPrint('📁 [FILE CHECK #$checkCount] Models dir does not exist yet: $modelsPath');
        }
        return;
      }

      // Check if any .litertlm files exist (Gemma 4 E2B format)
      await for (final entity in modelDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.litertlm')) {
          if (!fileDetected) {
            fileDetected = true;
            debugPrint('✅ [FILE CHECK #$checkCount] 📥 Download complete - model file detected');
            debugPrint('📦 Model file: ${entity.path}');
            debugPrint('📊 File size: ${await entity.length()} bytes');
            onProgress(50);
          }
          return;
        }
      }

      if (checkCount % 10 == 0) {
        debugPrint('📁 [FILE CHECK #$checkCount] Checking models dir for .litertlm files...');
      }
    } catch (e) {
      debugPrint('⚠️ File checker error (check #$checkCount): $e');
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
