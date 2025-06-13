/// Exception thrown when a Duppix regex operation fails.
///
/// This includes compilation errors, invalid patterns, and runtime errors
/// during pattern matching operations.
class DuppixException implements Exception {
  /// The error message describing what went wrong.
  final String message;

  /// The position in the pattern where the error occurred (if applicable).
  final int? position;

  /// The original pattern that caused the error (if applicable).
  final String? pattern;

  /// The error code (for compatibility with Oniguruma error codes).
  final int? errorCode;

  /// Additional context or details about the error.
  final Map<String, dynamic>? context;

  const DuppixException(
      this.message, {
        this.position,
        this.pattern,
        this.errorCode,
        this.context,
      });

  /// Creates a compilation error exception.
  factory DuppixException.compilation(
      String message,
      String pattern, {
        int? position,
        int? errorCode,
      }) {
    return DuppixException(
      'Regex compilation error: $message',
      position: position,
      pattern: pattern,
      errorCode: errorCode,
      context: {'type': 'compilation'},
    );
  }

  /// Creates a runtime error exception.
  factory DuppixException.runtime(
      String message, {
        String? pattern,
        int? errorCode,
        Map<String, dynamic>? context,
      }) {
    return DuppixException(
      'Regex runtime error: $message',
      pattern: pattern,
      errorCode: errorCode,
      context: {'type': 'runtime', ...?context},
    );
  }

  /// Creates an invalid pattern exception.
  factory DuppixException.invalidPattern(
      String message,
      String pattern, {
        int? position,
      }) {
    return DuppixException(
      'Invalid regex pattern: $message',
      position: position,
      pattern: pattern,
      errorCode: -1,
      context: {'type': 'invalid_pattern'},
    );
  }

  /// Creates an unsupported feature exception.
  factory DuppixException.unsupportedFeature(
      String feature,
      String pattern, {
        int? position,
        String? suggestion,
      }) {
    return DuppixException(
      'Unsupported regex feature: $feature${suggestion != null ? '. $suggestion' : ''}',
      position: position,
      pattern: pattern,
      errorCode: -2,
      context: {
        'type': 'unsupported_feature',
        'feature': feature,
        if (suggestion != null) 'suggestion': suggestion,
      },
    );
  }

  /// Gets a detailed error message with position information.
  String get detailedMessage {
    final buffer = StringBuffer(message);

    if (pattern != null && position != null) {
      buffer.writeln();
      buffer.writeln('Pattern: $pattern');
      buffer.writeln('Position: $position');

      // Show position indicator
      if (position! >= 0 && position! <= pattern!.length) {
        buffer.write('         ');
        for (int i = 0; i < position!; i++) {
          buffer.write(' ');
        }
        buffer.writeln('^');
      }
    } else if (pattern != null) {
      buffer.writeln();
      buffer.writeln('Pattern: $pattern');
    }

    if (errorCode != null) {
      buffer.writeln('Error code: $errorCode');
    }

    return buffer.toString();
  }

  /// Gets the type of error from the context.
  String? get errorType => context?['type'] as String?;

  /// Gets the feature name for unsupported feature errors.
  String? get unsupportedFeature => context?['feature'] as String?;

  /// Gets a suggestion for fixing the error (if available).
  String? get suggestion => context?['suggestion'] as String?;

  @override
  String toString() => 'DuppixException: $message';

  /// Returns a user-friendly error message.
  String toUserString() {
    switch (errorType) {
      case 'compilation':
        return 'The regex pattern could not be compiled: $message';
      case 'runtime':
        return 'An error occurred while matching: $message';
      case 'invalid_pattern':
        return 'The regex pattern is invalid: $message';
      case 'unsupported_feature':
        return 'This regex feature is not supported: $unsupportedFeature${suggestion != null ? '. Try: $suggestion' : ''}';
      default:
        return message;
    }
  }
}