import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/device_memory.dart';

/// Shown instead of downloading or loading the model when the device doesn't
/// have enough memory. The only action is to re-run the check.
class UnsupportedDeviceScreen extends StatefulWidget {
  /// Re-runs the memory check (and continues the flow if it now passes).
  final Future<void> Function() onTryAgain;

  const UnsupportedDeviceScreen({super.key, required this.onTryAgain});

  @override
  State<UnsupportedDeviceScreen> createState() => _UnsupportedDeviceScreenState();
}

class _UnsupportedDeviceScreenState extends State<UnsupportedDeviceScreen> {
  bool _checking = false;

  Future<void> _tryAgain() async {
    setState(() => _checking = true);
    try {
      await widget.onTryAgain();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Icon(Icons.memory, size: 48, color: AppColors.warning),
                  const SizedBox(height: 24),
                  const Text(
                    'Not enough memory',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'VentAI needs about $minMemoryForModelLabel of free memory to run '
                    "its AI model on this device. This device doesn't have enough "
                    'available memory right now. Close other apps and try again. '
                    "If it still doesn't work, this device isn't supported yet.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _checking ? null : _tryAgain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                      ),
                      child: _checking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Try again'),
                    ),
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
