// ---------------------------------------------------------------------------
// FrameworkError — Captured Flutter framework error
// ---------------------------------------------------------------------------

/// Category of a captured Flutter framework error.
///
/// Used to classify errors from [FlutterError.onError] by their
/// origin in the Flutter rendering pipeline.
enum FrameworkErrorCategory {
  /// RenderFlex / RenderBox overflow ("overflowed by X pixels").
  overflow,

  /// Widget build failure (exception thrown during `build()`).
  build,

  /// Layout error (exception during `performLayout()`).
  layout,

  /// Paint error (exception during `paint()`).
  paint,

  /// Gesture / hit-test error.
  gesture,

  /// Any other framework error.
  other,
}

/// A Flutter framework error captured by Colossus.
///
/// Wraps the information from [FlutterErrorDetails] into a
/// serializable format for MCP, Relay, and Scry consumption.
///
/// ## Categories
///
/// Errors are auto-classified by inspecting the exception message
/// and the reporting library:
///
/// | Category | Trigger |
/// |----------|---------|
/// | `overflow` | "overflowed by" in message |
/// | `build` | "widgets library" or "during build" |
/// | `layout` | "during performLayout" or "rendering library" layout |
/// | `paint` | "during paint" |
/// | `gesture` | "gesture library" |
/// | `other` | Everything else |
///
/// ```dart
/// for (final error in colossus.frameworkErrors) {
///   if (error.category == FrameworkErrorCategory.overflow) {
///     print('Overflow: ${error.message}');
///   }
/// }
/// ```
class FrameworkError {
  /// Creates a [FrameworkError].
  const FrameworkError({
    required this.category,
    required this.message,
    required this.timestamp,
    this.library,
    this.stackTrace,
  });

  /// The error category.
  final FrameworkErrorCategory category;

  /// Human-readable error summary (first line or truncated).
  final String message;

  /// When the error was captured.
  final DateTime timestamp;

  /// The Flutter library that reported the error (e.g., "rendering library").
  final String? library;

  /// Truncated stack trace (top 5 frames).
  final String? stackTrace;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toMap() => {
    'category': category.name,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    if (library != null) 'library': library,
    if (stackTrace != null) 'stackTrace': stackTrace,
  };

  /// Classify a Flutter error by its exception message, context, and library.
  ///
  /// Called internally by Colossus when capturing errors from
  /// [FlutterError.onError].
  static FrameworkErrorCategory classify({
    required String message,
    String? library,
    String? context,
  }) {
    final lower = message.toLowerCase();
    final contextLower = context?.toLowerCase() ?? '';

    // Overflow — "overflowed by" is definitive
    if (lower.contains('overflowed by') || lower.contains('overflow')) {
      return FrameworkErrorCategory.overflow;
    }

    // Build — widgets library or "during build" context
    if (library == 'widgets library' || contextLower.contains('during build')) {
      return FrameworkErrorCategory.build;
    }

    // Layout — rendering library + performLayout context
    if (contextLower.contains('during performlayout') ||
        contextLower.contains('during layout')) {
      return FrameworkErrorCategory.layout;
    }

    // Paint — "during paint" context
    if (contextLower.contains('during paint')) {
      return FrameworkErrorCategory.paint;
    }

    // Gesture — gesture library
    if (library == 'gesture library' ||
        contextLower.contains('during a gesture')) {
      return FrameworkErrorCategory.gesture;
    }

    return FrameworkErrorCategory.other;
  }
}
