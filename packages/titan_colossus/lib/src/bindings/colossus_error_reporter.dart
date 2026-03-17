import 'dart:async';

// ---------------------------------------------------------------------------
// ColossusErrorReporter — Error Capture Abstraction
// ---------------------------------------------------------------------------

/// Severity levels for reported errors.
enum ColossusErrorSeverity {
  /// Informational — not an error, but noteworthy.
  info,

  /// Warning — potential issue that should be investigated.
  warning,

  /// Error — something went wrong.
  error,

  /// Fatal — unrecoverable failure.
  fatal,
}

/// **ColossusErrorReporter** — framework-agnostic error reporting interface.
///
/// Replaces direct `Vigil.capture()` usage inside Colossus. When used with
/// `TitanBindings`, errors flow through Vigil. With `DefaultBindings`,
/// errors are stored in-memory.
///
/// ```dart
/// final reporter = ColossusBindings.instance.errorReporter;
/// reporter.capture(
///   'Performance alert: FPS low',
///   severity: ColossusErrorSeverity.warning,
/// );
///
/// reporter.errors.listen((error) => print('Error: $error'));
/// print('History: ${reporter.history.length} entries');
/// ```
abstract class ColossusErrorReporter {
  /// Capture an error or performance issue.
  void capture(
    String message, {
    ColossusErrorSeverity severity = ColossusErrorSeverity.error,
  });

  /// Stream of captured errors.
  Stream<Object> get errors;

  /// History of captured errors (newest last).
  List<Object> get history;

  /// Clear the error history.
  void clearHistory();
}

// ---------------------------------------------------------------------------
// DefaultErrorReporter — In-memory implementation
// ---------------------------------------------------------------------------

/// Lightweight error reporter backed by an in-memory list and
/// broadcast `StreamController`.
///
/// Used by `ColossusBindings.installDefaults()` when no framework
/// adapter is installed.
class DefaultErrorReporter implements ColossusErrorReporter {
  final StreamController<ColossusErrorEntry> _controller =
      StreamController<ColossusErrorEntry>.broadcast();
  final List<ColossusErrorEntry> _history = [];

  /// Maximum number of error entries to retain.
  static const int _maxHistory = 200;

  @override
  void capture(
    String message, {
    ColossusErrorSeverity severity = ColossusErrorSeverity.error,
  }) {
    final entry = ColossusErrorEntry(
      message: message,
      severity: severity,
      timestamp: DateTime.now(),
    );
    _history.add(entry);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
    if (!_controller.isClosed) {
      _controller.add(entry);
    }
  }

  @override
  Stream<Object> get errors => _controller.stream;

  @override
  List<Object> get history => List.unmodifiable(_history);

  @override
  void clearHistory() => _history.clear();
}

/// A single captured error entry.
class ColossusErrorEntry {
  /// The error message.
  final String message;

  /// The severity of this error.
  final ColossusErrorSeverity severity;

  /// When the error was captured.
  final DateTime timestamp;

  /// Creates an error entry.
  const ColossusErrorEntry({
    required this.message,
    required this.severity,
    required this.timestamp,
  });

  @override
  String toString() =>
      'ColossusErrorEntry(${severity.name}: $message @ $timestamp)';
}
