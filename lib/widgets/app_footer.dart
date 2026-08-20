import 'package:flutter/material.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        '© 2024-2026 Srinjoy Goswami & Resolveera',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}
