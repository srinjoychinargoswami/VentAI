import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Snapshot of download progress, emitted at most once per second.
class DownloadStats {
  final int percent; // 0-100
  final double speedMBps; // smoothed
  final Duration? remaining; // null until speed is known
  final double totalMB;
  const DownloadStats(this.percent, this.speedMBps, this.remaining, this.totalMB);

  String get remainingText {
    final r = remaining;
    if (r == null) return 'calculating...';
    if (r.inSeconds < 60) return '${r.inSeconds} seconds';
    final m = (r.inSeconds / 60).ceil();
    return m == 1 ? '1 minute' : '$m minutes';
  }
}

/// Approximate size used for speed/ETA when the real size can't be fetched.
const double _fallbackModelMB = 2400;
const String _modelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

/// Best-effort Content-Length lookup (HEAD, follows redirects). Never throws.
Future<double> _fetchModelSizeMB(String token) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await client.headUrl(Uri.parse(_modelUrl));
    if (token.isNotEmpty) req.headers.set('Authorization', 'Bearer $token');
    final res = await req.close().timeout(const Duration(seconds: 8));
    await res.drain<void>();
    if (res.contentLength > 0) return res.contentLength / (1024 * 1024);
  } catch (e) {
    debugPrint('⚠️ [DOWNLOAD] Could not fetch model size: $e');
  } finally {
    client.close(force: true);
  }
  return _fallbackModelMB;
}

/// Bootstrap Gemma model: initialize and download on first launch
/// Uses Gemma 4 E2B .litertlm format (LiteRT-LM backend)
///
/// Progress tracking:
/// Real percent from flutter_gemma's withProgress(), plus MB/s and ETA via onStats.
Future<bool> bootstrapGemma({
  required Function(int) onProgress,
  void Function(DownloadStats)? onStats,
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
      debugPrint('✅ Using HuggingFace token');
    }

    // Download and install Gemma 4 E2B .litertlm model (LiteRT-LM format)
    // Lightweight model (~500MB) for fast downloads and ARM64 mobile inference
    // .litertlm format optimized for ARM64 architecture (NOT compatible with x86_64 emulator)
    debugPrint('📥 Starting model download (no notifications, no background service)...');
    debugPrint('📦 Model: Gemma 4 E2B (~500MB) - ARM64 optimized');

    // Report download starting
    onProgress(0);

    final totalMB = await _fetchModelSizeMB(hfToken);
    debugPrint('📦 [DOWNLOAD] Model size: ${totalMB.toStringAsFixed(0)} MB');
    final tracker = _ProgressTracker(totalMB, onProgress, onStats);

    try {
      debugPrint('📥 [DOWNLOAD STEP 1] Creating installModel builder...');
      final builder = FlutterGemma.installModel(
        modelType: ModelType.gemma4,
        fileType: ModelFileType.litertlm,
      );
      debugPrint('✅ [DOWNLOAD STEP 1] Builder created');

      debugPrint('📥 [DOWNLOAD STEP 2] Configuring network source...');
      final networkBuilder = builder.fromNetwork(
        _modelUrl,
        token: hfToken.isNotEmpty ? hfToken : null,
      ).withProgress(tracker.update);
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
        final activeModel = await FlutterGemma.getActiveModel(maxTokens: 1024);  // Matches .litertlm minimum context window
        debugPrint('✅ [DOWNLOAD STEP 5] Verified - Active model ready');
      } catch (e) {
        debugPrint('⚠️ [DOWNLOAD STEP 5] Could not verify: $e');
      }

      // Stop file checker and report completion
      tracker.finish();
      return true;
    } catch (e) {
      debugPrint('❌ [DOWNLOAD ERROR] Failed at step: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      tracker.dispose();
      rethrow;
    }

  } catch (e) {
    debugPrint('❌ Bootstrap failed: $e');
    return false;
  }
}

/// Turns raw percent callbacks into percent + MB/s + ETA, throttled to 1/s.
/// Speed is an exponential moving average so the ETA doesn't jump around.
class _ProgressTracker {
  final double totalMB;
  final Function(int) onProgress;
  final void Function(DownloadStats)? onStats;

  final Stopwatch _clock = Stopwatch()..start();
  int _lastPercent = 0;
  int _lastEmitMs = -1000;
  int _lastSampleMs = 0;
  int _lastSamplePercent = 0;
  double _speed = 0;
  Timer? _ticker;

  _ProgressTracker(this.totalMB, this.onProgress, this.onStats) {
    // Re-emit every second even if the percent hasn't moved, so the UI
    // (and log) keeps showing life during slow stretches.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emit(force: true));
    _emit(force: true);
  }

  void update(int percent) {
    _lastPercent = percent.clamp(0, 100);
    _emit();
  }

  void _emit({bool force = false}) {
    final now = _clock.elapsedMilliseconds;
    if (!force && now - _lastEmitMs < 1000) return;
    _lastEmitMs = now;

    final dtSec = (now - _lastSampleMs) / 1000.0;
    if (dtSec >= 1.0) {
      final deltaMB = (_lastPercent - _lastSamplePercent) / 100.0 * totalMB;
      final inst = deltaMB / dtSec;
      _speed = _speed == 0 ? inst : _speed * 0.7 + inst * 0.3;
      _lastSampleMs = now;
      _lastSamplePercent = _lastPercent;
    }

    Duration? remaining;
    if (_speed > 0.01) {
      final leftMB = (100 - _lastPercent) / 100.0 * totalMB;
      remaining = Duration(seconds: (leftMB / _speed).round());
    }
    final stats = DownloadStats(_lastPercent, _speed, remaining, totalMB);
    debugPrint('⬇️ [DOWNLOAD] Downloading Gemma 4 E2B... $_lastPercent% | '
        'Speed: ${_speed.toStringAsFixed(1)} MB/s | '
        'Time remaining: ${stats.remainingText}');
    onProgress(_lastPercent);
    onStats?.call(stats);
  }

  void finish() {
    dispose();
    _lastPercent = 100;
    debugPrint('✅ [DOWNLOAD] Complete in ${_clock.elapsed.inSeconds}s');
    onProgress(100);
    onStats?.call(DownloadStats(100, _speed, Duration.zero, totalMB));
  }

  void dispose() => _ticker?.cancel();
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
