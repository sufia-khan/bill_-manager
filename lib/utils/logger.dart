import 'package:flutter/foundation.dart';

/// Simple logging utility for the application
/// Provides different log levels and formatted output
class Logger {
  static const String _prefix = '[BillManager]';

  /// Log an informational message
  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      debugPrint('$_prefix$tagStr INFO: $message');
    }
  }

  /// Log a warning message
  static void warning(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      debugPrint('$_prefix$tagStr WARNING: $message');
    }
  }

  /// Log an error message with optional error object and stack trace
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      debugPrint('$_prefix$tagStr ERROR: $message');
      if (error != null) {
        debugPrint('$_prefix$tagStr Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('$_prefix$tagStr Stack trace: $stackTrace');
      }
    }
  }

  /// Log a debug message (only in debug mode)
  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      final tagStr = tag != null ? '[$tag]' : '';
      debugPrint('$_prefix$tagStr DEBUG: $message');
    }
  }
}
