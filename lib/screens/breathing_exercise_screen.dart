import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  String _phase = 'inhale';
  String _instruction = 'Breathe In...';
  int _cycleCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 19),
      vsync: this,
    )..repeat();

    _controller.addListener(_updatePhase);
    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _cycleCount++);
    }
  }

  void _updatePhase() {
    final elapsed = _controller.value * 19;
    String newPhase;
    String newInstruction;

    if (elapsed < 4) {
      newPhase = 'inhale';
      newInstruction = 'Breathe In...';
    } else if (elapsed < 11) {
      newPhase = 'hold';
      newInstruction = 'Hold...';
    } else {
      newPhase = 'exhale';
      newInstruction = 'Breathe Out...';
    }

    // Only rebuild if phase changed
    if (newPhase != _phase || newInstruction != _instruction) {
      setState(() {
        _phase = newPhase;
        _instruction = newInstruction;
      });
    }
  }

  double _getScale() {
    final elapsed = _controller.value * 19;

    if (elapsed < 4) {
      // Inhale: scale from 1.0 to 1.5 over 4 seconds
      return 1.0 + (0.5 * (elapsed / 4));
    } else if (elapsed < 11) {
      // Hold: stay at 1.5 for 7 seconds
      return 1.5;
    } else {
      // Exhale: scale from 1.5 to 1.0 over 8 seconds
      return 1.5 - (0.5 * ((elapsed - 11) / 8));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(0),
        child: Container(
          color: AppColors.overlay,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Close button (top-right)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),

              // Centered breathing circle with animation
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Breathing circle
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _getScale(),
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // Instruction text
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _instruction,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Cycle ${_cycleCount + 1}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // Instructions/tips
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: const [
                          Text(
                            '4-7-8 Breathing Technique',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '• Inhale for 4 seconds\n'
                            '• Hold for 7 seconds\n'
                            '• Exhale for 8 seconds\n\n'
                            'This technique helps calm anxiety and promotes relaxation.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Bottom hint
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Text(
                  'Press ESC or click the X to close',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
