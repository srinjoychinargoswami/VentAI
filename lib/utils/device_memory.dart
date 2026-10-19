import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _deviceChannel = MethodChannel('com.ventai.app/device');

/// Minimum memory iOS must still allow this process before loading the ~2.6GB
/// model. Measure on real devices before relying on this value.
const int kMinMemoryForModelBytes = 3500000000; // 3.5 GB

/// Thrown instead of loading the model when the device can't hold it, so the
/// OS doesn't terminate the app mid-load.
class InsufficientMemoryException implements Exception {
  final int availableBytes;
  const InsufficientMemoryException(this.availableBytes);

  @override
  String toString() =>
      'Not enough memory to run the AI model on this device '
      '(${(availableBytes / 1e9).toStringAsFixed(1)} GB available, '
      '${(kMinMemoryForModelBytes / 1e9).toStringAsFixed(1)} GB needed).';
}

/// iOS only: bytes the process can still allocate (os_proc_available_memory).
/// Returns null on other platforms or if the query fails.
Future<int?> availableMemoryBytes() async {
  if (kIsWeb || !Platform.isIOS) return null;
  try {
    return await _deviceChannel.invokeMethod<int>('availableMemory');
  } catch (e) {
    debugPrint('⚠️ Available-memory query failed: $e');
    return null;
  }
}

/// [kMinMemoryForModelBytes] formatted for display, e.g. "3.5 GB".
String get minMemoryForModelLabel =>
    '${(kMinMemoryForModelBytes / 1e9).toStringAsFixed(1)} GB';

/// Result of [checkDeviceCanRunModel].
class DeviceSupportResult {
  /// Bytes iOS reported as available, or null if not queried / unknown.
  final int? availableBytes;
  const DeviceSupportResult(this.availableBytes);

  bool get isSupported =>
      availableBytes == null || availableBytes! >= kMinMemoryForModelBytes;

  double? get availableGb => availableBytes == null ? null : availableBytes! / 1e9;
}

/// Whether this device currently has enough memory for the model.
/// Non-iOS platforms, and a failed native query, count as supported: the
/// check never blocks a device because the check itself failed. The
/// post-download backstop in GemmaService still applies.
Future<DeviceSupportResult> checkDeviceCanRunModel() async {
  final available = await availableMemoryBytes();
  if (available != null) {
    debugPrint('🧠 Available memory: ${(available / 1e9).toStringAsFixed(2)} GB '
        '(needs $minMemoryForModelLabel)');
  }
  return DeviceSupportResult(available);
}

/// Backstop before loading the model: throws [InsufficientMemoryException] if
/// iOS reports less memory than the model needs. Does nothing when unknown.
Future<void> ensureEnoughMemoryForModel() async {
  final result = await checkDeviceCanRunModel();
  if (!result.isSupported) {
    throw InsufficientMemoryException(result.availableBytes!);
  }
}
