import 'dart:developer' as developer;

// ---------------------------------------------------------------------------
// ColossusLogger — Structured Logging Abstraction
// ---------------------------------------------------------------------------

/// **ColossusLogger** — framework-agnostic structured logging interface.
///
/// Replaces direct `Chronicle` usage inside Colossus. When used with
/// `TitanBindings`, logs flow through Chronicle. With `DefaultBindings`,
/// logs go to `dart:developer`.
///
/// ```dart
/// final logger = ColossusBindings.instance.createLogger('MyComponent');
/// logger.info('Started successfully');
/// logger.warning('High memory usage', {'pillarCount': 42});
/// logger.error('Failed to connect', error, stackTrace);
/// ```
abstract class ColossusLogger {
  /// Log an informational message.
  void info(String message, [Map<String, dynamic>? data]);

  /// Log a warning message.
  void warning(String message, [Map<String, dynamic>? data]);

  /// Log an error message with optional error object and stack trace.
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Factory that creates named loggers.
///
/// Each component gets its own named logger for easy filtering:
/// ```dart
/// final relayLog = createLogger('Relay');
/// final pulseLog = createLogger('Pulse');
/// ```
typedef ColossusLoggerFactory = ColossusLogger Function(String name);

// ---------------------------------------------------------------------------
// ColossusLogSink — For capturing log output (used by Lens)
// ---------------------------------------------------------------------------

/// Receives structured log entries for display (e.g. in the Lens overlay).
abstract class ColossusLogSink {
  /// Write a log entry to this sink.
  void write(ColossusLogEntry entry);
}

/// A single structured log entry.
class ColossusLogEntry {
  /// The logger that produced this entry.
  final String loggerName;

  /// Log level: `'info'`, `'warning'`, or `'error'`.
  final String level;

  /// The log message.
  final String message;

  /// When the entry was created.
  final DateTime timestamp;

  /// Optional structured data attached to the entry.
  final Map<String, dynamic>? data;

  /// Creates a log entry.
  const ColossusLogEntry({
    required this.loggerName,
    required this.level,
    required this.message,
    required this.timestamp,
    this.data,
  });
}

// ---------------------------------------------------------------------------
// DefaultLogger — dart:developer backed implementation
// ---------------------------------------------------------------------------

/// Lightweight logger backed by `dart:developer.log()`.
///
/// Used by `ColossusBindings.installDefaults()` when no framework
/// adapter is installed. Logs appear in Flutter DevTools and the
/// IDE debug console.
class DefaultLogger implements ColossusLogger {
  /// The name of this logger (appears as the `name` parameter in
  /// `dart:developer.log()`).
  final String name;

  /// Optional sink for capturing entries (e.g. for Lens display).
  final ColossusLogSink? _sink;

  /// Creates a default logger with the given [name].
  DefaultLogger(this.name, {ColossusLogSink? sink}) : _sink = sink;

  @override
  void info(String message, [Map<String, dynamic>? data]) {
    developer.log(message, name: name, level: 800);
    _sink?.write(
      ColossusLogEntry(
        loggerName: name,
        level: 'info',
        message: message,
        timestamp: DateTime.now(),
        data: data,
      ),
    );
  }

  @override
  void warning(String message, [Map<String, dynamic>? data]) {
    developer.log(message, name: name, level: 900);
    _sink?.write(
      ColossusLogEntry(
        loggerName: name,
        level: 'warning',
        message: message,
        timestamp: DateTime.now(),
        data: data,
      ),
    );
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: name,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
    _sink?.write(
      ColossusLogEntry(
        loggerName: name,
        level: 'error',
        message: message,
        timestamp: DateTime.now(),
      ),
    );
  }
}
