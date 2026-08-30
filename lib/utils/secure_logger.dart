import 'package:flutter/foundation.dart';

/// Secure logging utility that suppresses sensitive data in release builds
class SecureLogger {
  /// Log only in debug builds - full output
  /// Use for non-sensitive operational messages
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[VentAI] $message');
    }
  }

  /// Log with sensitive data redaction
  /// Automatically redacts common sensitive keywords in release builds
  /// Use for messages that might contain user data
  static void redacted(String message) {
    if (kDebugMode) {
      debugPrint('[VentAI] $message');
    } else {
      // In release, redact common sensitive keywords
      final redacted = message
        .replaceAll(RegExp(r'(suicid|abuse|harm|kill|die|death|lonely|depressed|anxious)',
            caseSensitive: false), '[REDACTED]')
        .replaceAll(RegExp(r'(password|token|key|secret|auth|api)',
            caseSensitive: false), '[REDACTED]')
        .replaceAll(RegExp(r'(email|phone|name|address|ssn|id)',
            caseSensitive: false), '[REDACTED]');
      debugPrint('[VentAI] $redacted');
    }
  }

  /// Never log - for the most sensitive data
  /// Use for user messages, conversation content, AI responses
  /// Completely suppressed - not logged even in debug
  static void silent(String message) {
    // Intentionally do nothing - some data should never be logged
    // This makes intent explicit in code
  }

  /// Log structured events (non-sensitive metadata only)
  /// Use for operational events: "Model loaded", "Conversation switched", etc.
  static void event(String event, {Map<String, String>? data}) {
    if (kDebugMode) {
      final details = data?.entries.map((e) => '${e.key}=${e.value}').join(', ') ?? '';
      debugPrint('[Event] $event${details.isNotEmpty ? ': $details' : ''}');
    }
  }

  /// Emergency/error logging - logged in all builds but with redaction
  /// Use for error messages that need visibility in production
  static void error(String message, {StackTrace? stackTrace}) {
    final redacted = message
      .replaceAll(RegExp(r'(suicid|abuse|harm)', caseSensitive: false), '[REDACTED]');
    debugPrint('[ERROR] $redacted');
    if (stackTrace != null && kDebugMode) {
      debugPrint('[STACK] $stackTrace');
    }
  }
}
