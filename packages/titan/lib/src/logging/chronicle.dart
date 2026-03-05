/// **Chronicle** — Records all that transpires.
///
/// A lightweight, structured logging system for Titan applications.
/// Named loggers, configurable levels, and pluggable sinks.
///
/// ## Quick Start
///
/// ```dart
/// // Get a named logger
/// final log = Chronicle('AuthPillar');
///
/// log.debug('Attempting login...');
/// log.info('User logged in', {'userId': user.id});
/// log.warning('Token expires soon');
/// log.error('Login failed', error, stackTrace);
///
/// // Inside a Pillar — auto-named logger via `log`
/// class AuthPillar extends Pillar {
///   @override
///   void onInit() {
///     log.info('AuthPillar initialized');
///   }
/// }
/// ```
///
/// ## Configuration
///
/// ```dart
/// // Set global minimum level
/// Chronicle.level = LogLevel.info; // Suppress debug/trace
///
/// // Add custom sinks (default: console)
/// Chronicle.addSink(MyFileSink());
/// Chronicle.addSink(MyNetworkSink());
///
/// // Remove default console sink
/// Chronicle.removeSink(Chronicle.consoleSink);
/// ```
library;

// ---------------------------------------------------------------------------
// Log Level
// ---------------------------------------------------------------------------

/// Log severity levels, ordered from least to most severe.
enum LogLevel {
  /// Fine-grained diagnostic information.
  trace,

  /// Detailed debugging information.
  debug,

  /// General informational messages.
  info,

  /// Potential issues that aren't errors.
  warning,

  /// Recoverable errors.
  error,

  /// Critical failures.
  fatal,

  /// Disables all logging.
  off,
}

// ---------------------------------------------------------------------------
// Log Entry
// ---------------------------------------------------------------------------

/// A structured log entry with level, message, and optional context.
class LogEntry {
  /// The name of the logger that created this entry.
  final String loggerName;

  /// The severity level.
  final LogLevel level;

  /// The log message.
  final String message;

  /// Optional structured data attached to the log.
  final Map<String, dynamic>? data;

  /// Optional error object.
  final Object? error;

  /// Optional stack trace.
  final StackTrace? stackTrace;

  /// When the entry was created.
  ///
  /// The timestamp is captured lazily on first access rather than at
  /// construction time, eliminating the [DateTime.now] syscall overhead
  /// for log entries whose timestamp is never read (e.g. when sinks only
  /// inspect level and message).
  DateTime get timestamp => _timestamp ??= DateTime.now();
  DateTime? _timestamp;

  /// Creates a [LogEntry].
  LogEntry({
    required this.loggerName,
    required this.level,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
    DateTime? timestamp,
  }) : _timestamp = timestamp;

  @override
  String toString() {
    final buf = StringBuffer()
      ..write('[${level.name.toUpperCase()}]')
      ..write(' $loggerName: $message');
    if (data != null && data!.isNotEmpty) buf.write(' $data');
    if (error != null) buf.write(' | Error: $error');
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// Log Sink
// ---------------------------------------------------------------------------

/// A pluggable output destination for log entries.
///
/// Implement this to route logs to files, network services, or custom
/// dashboards.
///
/// ```dart
/// class FileLogSink extends LogSink {
///   final File file;
///   FileLogSink(this.file);
///
///   @override
///   void write(LogEntry entry) {
///     file.writeAsStringSync('${entry}\n', mode: FileMode.append);
///   }
/// }
/// ```
abstract class LogSink {
  /// Write a log entry to this sink.
  void write(LogEntry entry);
}

/// A console [LogSink] with formatted, colorized output.
///
/// ```dart
/// Chronicle.addSink(ConsoleLogSink());
/// ```
class ConsoleLogSink extends LogSink {
  /// Minimum level to print. Defaults to [LogLevel.trace] (all).
  final LogLevel minLevel;

  /// Creates a [ConsoleLogSink].
  ConsoleLogSink({this.minLevel = LogLevel.trace});

  static const _levelIcons = {
    LogLevel.trace: '⚬',
    LogLevel.debug: '◈',
    LogLevel.info: 'ℹ',
    LogLevel.warning: '⚠',
    LogLevel.error: '✖',
    LogLevel.fatal: '☠',
  };

  @override
  void write(LogEntry entry) {
    if (entry.level.index < minLevel.index) return;

    final icon = _levelIcons[entry.level] ?? '•';
    final time = _formatTime(entry.timestamp);
    final buf = StringBuffer()
      ..write('$icon $time ')
      ..write('[${entry.loggerName}] ')
      ..write(entry.message);

    if (entry.data != null && entry.data!.isNotEmpty) {
      buf.write(' ${entry.data}');
    }

    if (entry.error != null) {
      buf.write('\n  Error: ${entry.error}');
    }

    if (entry.stackTrace != null) {
      final lines = entry.stackTrace.toString().split('\n').take(5);
      for (final line in lines) {
        buf.write('\n  $line');
      }
    }

    // ignore: avoid_print
    print(buf);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

// ---------------------------------------------------------------------------
// Chronicle — The Logger
// ---------------------------------------------------------------------------

/// **Chronicle** — Titan's structured logging system.
///
/// Each Chronicle instance is a named logger. All loggers share global
/// configuration (level, sinks).
///
/// ```dart
/// final log = Chronicle('MyFeature');
/// log.info('Something happened');
/// log.error('Failed', error, stackTrace);
/// ```
///
/// Inside a Pillar, use the built-in `log` getter:
///
/// ```dart
/// class AuthPillar extends Pillar {
///   @override
///   void onInit() {
///     log.info('AuthPillar initialized');
///   }
/// }
/// ```
class Chronicle {
  /// The name of this logger.
  final String name;

  // ---------------------------------------------------------------------------
  // Global configuration
  // ---------------------------------------------------------------------------

  static LogLevel level = LogLevel.debug;
  static final List<LogSink> _sinks = [];

  /// The default console sink instance.
  static final ConsoleLogSink consoleSink = ConsoleLogSink();

  static bool _initialized = false;

  static void _ensureInitialized() {
    if (!_initialized) {
      _sinks.add(consoleSink);
      _initialized = true;
    }
  }

  /// The global minimum log level. Messages below this are suppressed.
  ///
  /// Defaults to [LogLevel.debug].
  ///
  /// ```dart
  /// Chronicle.level = LogLevel.info; // Suppress trace and debug
  /// Chronicle.level = LogLevel.off;  // Disable all logging
  /// ```

  /// Add a log sink.
  ///
  /// ```dart
  /// Chronicle.addSink(FileLogSink('app.log'));
  /// ```
  static void addSink(LogSink sink) {
    _ensureInitialized();
    _sinks.add(sink);
  }

  /// Remove a log sink.
  static void removeSink(LogSink sink) {
    _sinks.remove(sink);
  }

  /// Get a read-only view of registered sinks.
  static List<LogSink> get sinks {
    _ensureInitialized();
    return List.unmodifiable(_sinks);
  }

  /// Reset Chronicle — clear all sinks, restore defaults.
  ///
  /// ```dart
  /// tearDown(() => Chronicle.reset());
  /// ```
  static void reset() {
    _sinks.clear();
    level = LogLevel.debug;
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // Instance
  // ---------------------------------------------------------------------------

  /// Creates a named [Chronicle] logger.
  ///
  /// ```dart
  /// final log = Chronicle('AuthService');
  /// log.info('User logged in');
  /// ```
  const Chronicle(this.name);

  // ---------------------------------------------------------------------------
  // Log methods
  // ---------------------------------------------------------------------------

  /// Log a trace-level message.
  void trace(String message, [Map<String, dynamic>? data]) =>
      _log(LogLevel.trace, message, data: data);

  /// Log a debug-level message.
  void debug(String message, [Map<String, dynamic>? data]) =>
      _log(LogLevel.debug, message, data: data);

  /// Log an info-level message.
  void info(String message, [Map<String, dynamic>? data]) =>
      _log(LogLevel.info, message, data: data);

  /// Log a warning-level message.
  void warning(String message, [Map<String, dynamic>? data]) =>
      _log(LogLevel.warning, message, data: data);

  /// Log an error-level message with optional error and stack trace.
  void error(
    String message, [
    Object? errorObj,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  ]) => _log(
    LogLevel.error,
    message,
    error: errorObj,
    stackTrace: stackTrace,
    data: data,
  );

  /// Log a fatal-level message with optional error and stack trace.
  void fatal(
    String message, [
    Object? errorObj,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  ]) => _log(
    LogLevel.fatal,
    message,
    error: errorObj,
    stackTrace: stackTrace,
    data: data,
  );

  /// Log a message at the given level.
  void call(
    LogLevel lvl,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(lvl, message, data: data, error: error, stackTrace: stackTrace);

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _log(
    LogLevel lvl,
    String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (lvl.index < level.index) return;

    _ensureInitialized();

    final entry = LogEntry(
      loggerName: name,
      level: lvl,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );

    for (final sink in _sinks) {
      try {
        sink.write(entry);
      } catch (_) {
        // Don't let sink errors cascade
      }
    }
  }
}
