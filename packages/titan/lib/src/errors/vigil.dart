import 'dart:async';

// ---------------------------------------------------------------------------
// Severity
// ---------------------------------------------------------------------------

/// The severity level of a tracked error.
///
/// Used by [ErrorHandler]s to filter, route, or escalate errors.
///
/// ```dart
/// if (error.severity == ErrorSeverity.fatal) {
///   crashlytics.recordFatal(error.error, error.stackTrace);
/// }
/// ```
enum ErrorSeverity {
  /// Diagnostic information, not an actual error.
  debug,

  /// Informational — something noteworthy but not harmful.
  info,

  /// A potential issue that didn't cause failure.
  warning,

  /// A recoverable error — the operation failed.
  error,

  /// A critical failure — the app may be in an unstable state.
  fatal,
}

// ---------------------------------------------------------------------------
// Error Context
// ---------------------------------------------------------------------------

/// Contextual information about where and why an error occurred.
///
/// Attach to [Vigil.capture] for structured error reporting.
///
/// ```dart
/// Vigil.capture(
///   error,
///   stackTrace: stackTrace,
///   context: ErrorContext(
///     source: runtimeType,
///     action: 'loadUsers',
///     metadata: {'userId': userId, 'page': currentPage},
///   ),
/// );
/// ```
class ErrorContext {
  /// The type where the error originated (e.g., a Pillar's `runtimeType`).
  final Type? source;

  /// The action being performed when the error occurred.
  final String? action;

  /// Arbitrary metadata for debugging or reporting.
  final Map<String, dynamic>? metadata;

  /// Creates an [ErrorContext].
  const ErrorContext({this.source, this.action, this.metadata});

  @override
  String toString() {
    final parts = <String>[];
    if (source != null) parts.add('source: $source');
    if (action != null) parts.add('action: $action');
    if (metadata != null && metadata!.isNotEmpty) {
      parts.add('metadata: $metadata');
    }
    return 'ErrorContext(${parts.join(', ')})';
  }
}

// ---------------------------------------------------------------------------
// TitanError
// ---------------------------------------------------------------------------

/// A captured error with full context, severity, and timestamp.
///
/// Created automatically by [Vigil.capture] and delivered to all
/// registered [ErrorHandler]s.
class TitanError {
  /// The error object.
  final Object error;

  /// The stack trace at the point of capture (if available).
  final StackTrace? stackTrace;

  /// The severity level of this error.
  final ErrorSeverity severity;

  /// Contextual information about where the error occurred.
  final ErrorContext? context;

  /// When the error was captured.
  final DateTime timestamp;

  /// Creates a [TitanError].
  TitanError({
    required this.error,
    this.stackTrace,
    this.severity = ErrorSeverity.error,
    this.context,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    final buf = StringBuffer()
      ..write('[${severity.name.toUpperCase()}] ')
      ..write(error);
    if (context?.source != null) {
      buf.write(' (${context!.source})');
    }
    if (context?.action != null) {
      buf.write(' in ${context!.action}');
    }
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// Error Handler
// ---------------------------------------------------------------------------

/// A pluggable error handler (sink) for [Vigil].
///
/// Implement this to route errors to logging services, crash reporters,
/// or custom dashboards.
///
/// ```dart
/// class CrashlyticsHandler extends ErrorHandler {
///   @override
///   void handle(TitanError error) {
///     if (error.severity.index >= ErrorSeverity.error.index) {
///       FirebaseCrashlytics.instance.recordError(
///         error.error,
///         error.stackTrace,
///         reason: error.context?.action,
///         fatal: error.severity == ErrorSeverity.fatal,
///       );
///     }
///   }
/// }
/// ```
abstract class ErrorHandler {
  /// Handle a captured [TitanError].
  void handle(TitanError error);
}

/// A simple [ErrorHandler] that logs errors to the console.
///
/// ```dart
/// Vigil.addHandler(ConsoleErrorHandler());
/// ```
class ConsoleErrorHandler extends ErrorHandler {
  /// Minimum severity level to print. Defaults to [ErrorSeverity.warning].
  final ErrorSeverity minSeverity;

  /// Whether to include stack traces in output.
  final bool includeStackTrace;

  /// Creates a [ConsoleErrorHandler].
  ConsoleErrorHandler({
    this.minSeverity = ErrorSeverity.warning,
    this.includeStackTrace = true,
  });

  @override
  void handle(TitanError error) {
    if (error.severity.index < minSeverity.index) return;

    final buf = StringBuffer()
      ..writeln('┌── Vigil ──────────────────────────────────────')
      ..writeln('│ ${error.severity.name.toUpperCase()}: ${error.error}');

    if (error.context?.source != null) {
      buf.writeln('│ Source: ${error.context!.source}');
    }
    if (error.context?.action != null) {
      buf.writeln('│ Action: ${error.context!.action}');
    }
    if (error.context?.metadata != null &&
        error.context!.metadata!.isNotEmpty) {
      buf.writeln('│ Metadata: ${error.context!.metadata}');
    }
    buf.writeln('│ Time: ${error.timestamp.toIso8601String()}');

    if (includeStackTrace && error.stackTrace != null) {
      buf.writeln('│ Stack trace:');
      for (final line in error.stackTrace.toString().split('\n').take(8)) {
        buf.writeln('│   $line');
      }
    }

    buf.write('└───────────────────────────────────────────────');
    // ignore: avoid_print
    print(buf);
  }
}

/// A filtering [ErrorHandler] that only forwards errors matching a condition.
///
/// ```dart
/// Vigil.addHandler(FilteredErrorHandler(
///   filter: (e) => e.severity == ErrorSeverity.fatal,
///   handler: CrashlyticsHandler(),
/// ));
/// ```
class FilteredErrorHandler extends ErrorHandler {
  /// The condition to evaluate.
  final bool Function(TitanError error) filter;

  /// The handler to forward matching errors to.
  final ErrorHandler handler;

  /// Creates a [FilteredErrorHandler].
  FilteredErrorHandler({required this.filter, required this.handler});

  @override
  void handle(TitanError error) {
    if (filter(error)) {
      handler.handle(error);
    }
  }
}

// ---------------------------------------------------------------------------
// Vigil — The Centralized Error Tracker
// ---------------------------------------------------------------------------

/// **Vigil** — The eternal watch over errors.
///
/// Enterprise-grade centralized error tracking for Titan applications.
/// Capture, contextualize, and route errors to any number of pluggable
/// handlers (console, Crashlytics, Sentry, custom).
///
/// ## Quick Start
///
/// ```dart
/// // 1. Add handlers
/// Vigil.addHandler(ConsoleErrorHandler());
/// Vigil.addHandler(myCrashlyticsHandler);
///
/// // 2. Errors are auto-captured from Pillar.strikeAsync
/// // 3. Or capture manually:
/// try {
///   await riskyOperation();
/// } catch (e, s) {
///   Vigil.capture(e, stackTrace: s);
/// }
/// ```
///
/// ## Inside a Pillar
///
/// Pillars have a managed [captureError] method:
///
/// ```dart
/// class DataPillar extends Pillar {
///   Future<void> loadData() async {
///     try {
///       final data = await api.fetchData();
///       strike(() => items.value = data);
///     } catch (e, s) {
///       captureError(e, stackTrace: s, action: 'loadData');
///     }
///   }
/// }
/// ```
///
/// ## Features
///
/// - **Structured errors** — [TitanError] with severity, context, timestamp
/// - **Pluggable handlers** — Route to any service (console, Crashlytics, etc.)
/// - **Error history** — Keep last N errors for debugging
/// - **Filtered handlers** — Only send fatal to Sentry, log everything to console
/// - **Error stream** — React to errors in real-time
/// - **Zone capture** — Run code in an error-capturing zone
/// - **Pillar integration** — Auto-capture in `strikeAsync`, manual `captureError`
abstract final class Vigil {
  static final List<ErrorHandler> _handlers = [];
  static final StreamController<TitanError> _controller =
      StreamController<TitanError>.broadcast(sync: true);
  static int _maxHistorySize = 100;

  // Ring buffer for O(1) insertion at capacity
  static List<TitanError?> _buffer = List<TitanError?>.filled(100, null);
  static int _head = 0; // next write position
  static int _count = 0;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Set the maximum number of errors to keep in history.
  ///
  /// Defaults to 100. Set to 0 to disable history.
  static set maxHistorySize(int value) {
    if (value == _maxHistorySize) return;
    if (value <= 0) {
      _maxHistorySize = value;
      _buffer = [];
      _head = 0;
      _count = 0;
      return;
    }

    // Rebuild buffer at new size, preserving most recent entries
    final old = _orderedHistory();
    _maxHistorySize = value;
    _buffer = List<TitanError?>.filled(value, null);
    _head = 0;
    _count = 0;
    // Copy most recent entries that fit
    final start = old.length > value ? old.length - value : 0;
    for (var i = start; i < old.length; i++) {
      _buffer[_head] = old[i];
      _head = (_head + 1) % value;
      _count++;
    }
  }

  /// Get the current max history size.
  static int get maxHistorySize => _maxHistorySize;

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  /// Add a pluggable error handler.
  ///
  /// Handlers are called in the order they were added.
  ///
  /// ```dart
  /// Vigil.addHandler(ConsoleErrorHandler());
  /// Vigil.addHandler(SentryHandler());
  /// ```
  static void addHandler(ErrorHandler handler) {
    _handlers.add(handler);
  }

  /// Remove a previously added handler.
  static void removeHandler(ErrorHandler handler) {
    _handlers.remove(handler);
  }

  /// Get a read-only view of registered handlers.
  static List<ErrorHandler> get handlers => List.unmodifiable(_handlers);

  // ---------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------

  /// Capture an error with optional context and severity.
  ///
  /// The error is:
  /// 1. Wrapped in a [TitanError]
  /// 2. Added to the error history
  /// 3. Dispatched to all registered [ErrorHandler]s
  /// 4. Emitted on the [errors] stream
  ///
  /// ```dart
  /// try {
  ///   await api.deleteUser(userId);
  /// } catch (e, s) {
  ///   Vigil.capture(
  ///     e,
  ///     stackTrace: s,
  ///     severity: ErrorSeverity.error,
  ///     context: ErrorContext(
  ///       source: runtimeType,
  ///       action: 'deleteUser',
  ///       metadata: {'userId': userId},
  ///     ),
  ///   );
  /// }
  /// ```
  static void capture(
    Object error, {
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
    ErrorContext? context,
  }) {
    final titanError = TitanError(
      error: error,
      stackTrace: stackTrace,
      severity: severity,
      context: context,
    );

    // Store in history (ring buffer — O(1))
    if (_maxHistorySize > 0) {
      _buffer[_head] = titanError;
      _head = (_head + 1) % _maxHistorySize;
      if (_count < _maxHistorySize) _count++;
    }

    // Dispatch to handlers
    for (final handler in _handlers) {
      try {
        handler.handle(titanError);
      } catch (_) {
        // Don't let handler errors cascade
      }
    }

    // Emit on stream
    if (_controller.hasListener) {
      _controller.add(titanError);
    }
  }

  // ---------------------------------------------------------------------------
  // Stream
  // ---------------------------------------------------------------------------

  /// A broadcast stream of all captured errors.
  ///
  /// Useful for real-time monitoring or reactive error handling.
  ///
  /// ```dart
  /// Vigil.errors.listen((error) {
  ///   if (error.severity == ErrorSeverity.fatal) {
  ///     showErrorDialog(error);
  ///   }
  /// });
  /// ```
  static Stream<TitanError> get errors => _controller.stream;

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  /// Get a read-only view of the error history (most recent last).
  static List<TitanError> get history => _orderedHistory();

  /// Get the most recently captured error, or `null` if none.
  static TitanError? get lastError {
    if (_count == 0) return null;
    // Most recent is at (_head - 1) wrapped around
    final idx = (_head - 1 + _maxHistorySize) % _maxHistorySize;
    return _buffer[idx];
  }

  /// Get all errors matching a severity level.
  static List<TitanError> bySeverity(ErrorSeverity severity) =>
      _orderedHistory().where((e) => e.severity == severity).toList();

  /// Get all errors from a specific source type.
  static List<TitanError> bySource(Type source) =>
      _orderedHistory().where((e) => e.context?.source == source).toList();

  /// Clear the error history.
  static void clearHistory() {
    _buffer = List<TitanError?>.filled(
      _maxHistorySize > 0 ? _maxHistorySize : 1,
      null,
    );
    _head = 0;
    _count = 0;
  }

  // ---------------------------------------------------------------------------
  // Zone Capture
  // ---------------------------------------------------------------------------

  /// Run a synchronous function and capture any thrown errors.
  ///
  /// Returns the result on success, or `null` on failure.
  /// Captured errors are NOT rethrown.
  ///
  /// ```dart
  /// final result = Vigil.guard(() => parseConfig(raw));
  /// ```
  static T? guard<T>(
    T Function() fn, {
    ErrorSeverity severity = ErrorSeverity.error,
    ErrorContext? context,
  }) {
    try {
      return fn();
    } catch (e, s) {
      capture(e, stackTrace: s, severity: severity, context: context);
      return null;
    }
  }

  /// Run an async function and capture any thrown errors.
  ///
  /// Returns the result on success, or `null` on failure.
  /// Captured errors are NOT rethrown.
  ///
  /// ```dart
  /// final users = await Vigil.guardAsync(
  ///   () => api.fetchUsers(),
  ///   context: ErrorContext(action: 'fetchUsers'),
  /// );
  /// ```
  static Future<T?> guardAsync<T>(
    Future<T> Function() fn, {
    ErrorSeverity severity = ErrorSeverity.error,
    ErrorContext? context,
  }) async {
    try {
      return await fn();
    } catch (e, s) {
      capture(e, stackTrace: s, severity: severity, context: context);
      return null;
    }
  }

  /// Run a function and capture errors, but rethrow after capture.
  ///
  /// Useful when you want both error tracking AND propagation.
  ///
  /// ```dart
  /// try {
  ///   await Vigil.captureAndRethrow(() => api.deleteUser(id));
  /// } catch (e) {
  ///   showErrorSnackbar(e);
  /// }
  /// ```
  static Future<T> captureAndRethrow<T>(
    Future<T> Function() fn, {
    ErrorSeverity severity = ErrorSeverity.error,
    ErrorContext? context,
  }) async {
    try {
      return await fn();
    } catch (e, s) {
      capture(e, stackTrace: s, severity: severity, context: context);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Reset Vigil — remove all handlers, clear history.
  ///
  /// ```dart
  /// tearDown(() => Vigil.reset());
  /// ```
  static void reset() {
    _handlers.clear();
    _maxHistorySize = 100;
    _buffer = List<TitanError?>.filled(100, null);
    _head = 0;
    _count = 0;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Returns history entries in chronological order (oldest first).
  static List<TitanError> _orderedHistory() {
    if (_count == 0) return const [];
    final result = <TitanError>[];
    if (_count < _maxHistorySize) {
      for (var i = 0; i < _count; i++) {
        result.add(_buffer[i]!);
      }
    } else {
      for (var i = 0; i < _count; i++) {
        result.add(_buffer[(_head + i) % _maxHistorySize]!);
      }
    }
    return result;
  }
}
