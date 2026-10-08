import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'gemma_service.dart';

/// Snapshot of download progress, emitted at most once per second.
class DownloadStats {
  final int percent; // 0-100
  final double speedMBps; // smoothed
  final Duration? remaining; // null until speed is known
  final double totalMB;
  final bool stalled; // no progress for a while
  const DownloadStats(this.percent, this.speedMBps, this.remaining, this.totalMB,
      {this.stalled = false});

  String get remainingText {
    final r = remaining;
    if (r == null) return 'calculating...';
    if (r.inSeconds < 60) return '${r.inSeconds} seconds';
    final m = (r.inSeconds / 60).ceil();
    return m == 1 ? '1 minute' : '$m minutes';
  }
}

/// Approximate size used for speed/ETA when the real size can't be fetched.
const double _fallbackModelMB = 2600;
const String _modelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

/// Best-effort Content-Length lookup (HEAD, follows redirects). Never throws;
/// returns null if the real size could not be determined.
Future<double?> _fetchModelSizeMB(String token) async {
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
  return null;
}

/// Bootstrap Gemma model: initialize and download on first launch
/// Uses Gemma 4 E2B .litertlm format (LiteRT-LM backend)
///
/// Progress tracking:
/// Real percent from flutter_gemma's withProgress(), plus MB/s and ETA via onStats.
Future<bool> bootstrapGemma({
  required Function(int) onProgress,
  void Function(DownloadStats)? onStats,
  void Function(String error)? onError,
}) async {
  try {
    debugPrint('📱 Starting Gemma model bootstrap...');
    debugPrint('📝 Engine already initialized by main.dart');

    // Check if model already installed (cheap: does not load the model)
    if (await GemmaService().isInstalled()) {
      debugPrint('✅ Model already installed');
      onProgress(100);
      return true;
    }
    debugPrint('📥 Model not installed, proceeding with download...');

    debugPrint('📥 Starting model download...');

    // Get HuggingFace token from environment (compile-time define)
    const String hfToken = String.fromEnvironment('HUGGINGFACE_TOKEN');
    if (hfToken.isNotEmpty) {
      debugPrint('✅ Using HuggingFace token');
    }

    // Download and install Gemma 4 E2B .litertlm model (LiteRT-LM format)
    // Lightweight model (~2.6GB) for fast downloads and ARM64 mobile inference
    // .litertlm format optimized for ARM64 architecture (NOT compatible with x86_64 emulator)
    debugPrint('📥 Starting model download (no notifications, no background service)...');
    debugPrint('📦 Model: Gemma 4 E2B (~2.6GB) - ARM64 optimized');

    // Report download starting
    onProgress(0);

    // Start with the fallback size so the progress UI appears immediately;
    // refine the total in the background once the HEAD request returns.
    final tracker = _ProgressTracker(_fallbackModelMB, onProgress, onStats);
    _fetchModelSizeMB(hfToken).then((mb) {
      if (mb == null) {
        debugPrint('📦 [DOWNLOAD] Real size unavailable, keeping estimate '
            '(${_fallbackModelMB.toStringAsFixed(0)} MB)');
        return;
      }
      debugPrint('📦 [DOWNLOAD] Real size confirmed: ${mb.toStringAsFixed(0)} MB '
          '(estimate was ${_fallbackModelMB.toStringAsFixed(0)} MB)');
      // Picked up by the next 1s tick, so speed/ETA correct themselves.
      tracker.totalMB = mb;
    });

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
      // Cheap check only: loading the model here would load 2.6GB twice
      // (GemmaService.initialize() loads it right after).
      if (await GemmaService().isInstalled()) {
        debugPrint('✅ [DOWNLOAD STEP 5] Verified - model installed');
      } else {
        debugPrint('⚠️ [DOWNLOAD STEP 5] Install finished but model not reported as installed');
      }

      // Stop file checker and report completion
      tracker.finish();
      return true;
    } catch (e) {
      debugPrint('❌ [DOWNLOAD ERROR] Failed at step: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      tracker.dispose();
      onError?.call(e.toString());
      rethrow;
    }

  } catch (e) {
    debugPrint('❌ Bootstrap failed: $e');
    onError?.call(e.toString());
    return false;
  }
}

/// Turns raw percent callbacks into percent + MB/s + ETA, throttled to 1/s.
/// Speed is an exponential moving average so the ETA doesn't jump around.
class _ProgressTracker {
  double totalMB;
  final Function(int) onProgress;
  final void Function(DownloadStats)? onStats;

  final Stopwatch _clock = Stopwatch()..start();
  int _lastPercent = 0;
  int _lastEmitMs = -1000;
  int _lastSampleMs = 0;
  int _lastSamplePercent = 0;
  int _lastChangeMs = 0;
  int _seenPercent = 0;
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
    if (_lastPercent != _seenPercent) {
      _seenPercent = _lastPercent;
      _lastChangeMs = now;
    }
    final stalled = now - _lastChangeMs > 45000;
    final stats = DownloadStats(_lastPercent, _speed, remaining, totalMB, stalled: stalled);
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
