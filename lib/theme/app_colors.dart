import 'package:flutter/material.dart';

class AppColors {
  // Background colors
  static const Color background = Color(0xFF0F172A);      // Dark navy
  static const Color surface = Color(0xFF1E293B);         // Lighter dark
  static const Color surfaceDark = Color(0xFF131314);     // Very dark

  // Primary accent (web version indigo)
  static const Color primary = Color(0xFF6B73FF);         // Indigo (web version)

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);     // White
  static const Color textSecondary = Color(0xFFe2e8f0);   // Light off-white
  static const Color textTertiary = Color(0xFF94A3B8);    // Medium gray
  static const Color textPlaceholder = Color(0xFF94A3B8); // Placeholder gray
  static const Color textOnPrimary = Color(0xFFFFFFFF);   // White on primary

  // Status colors
  static const Color error = Color(0xFFEF4444);           // Red
  static const Color success = Color(0xFF10B981);         // Green
  static const Color warning = Color(0xFFFbbf24);         // Amber

  // UI Element colors
  static const Color borderDark = Color(0xFF2D3E52);      // Dark border
  static const Color borderGray = Color(0xFF374151);      // Gray border
  static const Color borderSubtle = Color(0xFF94A3B8);    // Subtle border

  // Message colors
  static const Color userMessage = Color(0xFF6B73FF);     // Indigo (user messages)
  static const Color aiMessage = Color(0xFF1E293B);       // Dark (AI messages)
  static const Color aiText = Color(0xFFe2e8f0);          // Light (AI text)

  // Special
  static const Color overlay = Color(0x99000000);         // Dark overlay (60% opacity)
  static const Color codeBackground = Color(0x80000000);  // Code background (50% opacity)
  static const Color codeText = Color(0xFF2E96FF);        // Code text (bright blue)
}
