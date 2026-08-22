import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const Text(
        '© 2024-2026 Srinjoy Goswami & Resolveera',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}
