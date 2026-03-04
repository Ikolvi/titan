/// Aegis — Resilient async operations with retry and exponential backoff.
///
/// Aegis provides configurable retry logic for unreliable async operations,
/// with exponential backoff, jitter, and per-attempt callbacks. Integrates
/// naturally with Pillar for reactive progress tracking.
///
/// ## Why "Aegis"?
///
/// An aegis is a shield of protection. Titan's Aegis shields your app
/// from transient failures by retrying with intelligent delays.
///
/// ## Usage
///
/// ```dart
/// final result = await Aegis.run(
///   () async => await fetchFromApi(),
///   maxAttempts: 3,
///   baseDelay: Duration(milliseconds: 500),
///   onRetry: (attempt, error, delay) {
///     print('Retry $attempt after ${delay.inMilliseconds}ms: $error');
///   },
/// );
/// ```
///
/// ## In a Pillar
///
/// ```dart
/// class ApiPillar extends Pillar {
///   Future<void> fetchData() => strikeAsync(() async {
///     final data = await Aegis.run(
///       () async => await api.get('/data'),
///       maxAttempts: 3,
///     );
///     items.value = data;
///   });
/// }
/// ```
library;

import 'dart:async';
import 'dart:math';

/// Strategy for calculating retry delays.
enum BackoffStrategy {
  /// Delay increases exponentially: baseDelay * 2^attempt.
  exponential,

  /// Delay remains constant: baseDelay for every retry.
  constant,

  /// Delay increases linearly: baseDelay * attempt.
  linear,
}

/// Configuration for an [Aegis] retry operation.
///
/// ```dart
/// final config = AegisConfig(
///   maxAttempts: 5,
///   baseDelay: Duration(seconds: 1),
///   strategy: BackoffStrategy.exponential,
///   jitter: true,
/// );
/// ```
class AegisConfig {
  /// Maximum number of attempts (including the initial attempt).
  ///
  /// Defaults to 3.
  final int maxAttempts;

  /// Base delay between retries.
  ///
  /// Defaults to 500ms.
  final Duration baseDelay;

  /// Maximum delay cap (prevents unbounded exponential growth).
  ///
  /// Defaults to 30 seconds.
  final Duration maxDelay;

  /// Backoff strategy for calculating delays.
  ///
  /// Defaults to [BackoffStrategy.exponential].
  final BackoffStrategy strategy;

  /// Whether to add random jitter to delays.
  ///
  /// Jitter helps prevent "thundering herd" problems by spreading
  /// out retry times. Adds 0-50% random variation to each delay.
  ///
  /// Defaults to `true`.
  final bool jitter;

  /// Optional predicate to decide if a specific error should be retried.
  ///
  /// Returns `true` to retry, `false` to fail immediately.
  /// Defaults to retrying all errors.
  final bool Function(Object error)? retryIf;

  /// Creates an Aegis configuration.
  const AegisConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.strategy = BackoffStrategy.exponential,
    this.jitter = true,
    this.retryIf,
  }) : assert(maxAttempts > 0, 'maxAttempts must be at least 1');

  /// Default configuration: 3 attempts, 500ms exponential backoff, jitter.
  static const defaults = AegisConfig();
}

/// Result of an [Aegis] retry operation.
///
/// Contains the successful value and metadata about the attempts.
class AegisResult<T> {
  /// The successful result value.
  final T value;

  /// Total number of attempts made (1 = first try succeeded).
  final int attempts;

  /// Total duration across all attempts and delays.
  final Duration totalDuration;

  /// Creates an Aegis result.
  const AegisResult({
    required this.value,
    required this.attempts,
    required this.totalDuration,
  });

  @override
  String toString() =>
      'AegisResult(attempts: $attempts, duration: ${totalDuration.inMilliseconds}ms)';
}

/// Resilient async operations with configurable retry logic.
///
/// ```dart
/// final result = await Aegis.run(
///   () async => await api.fetch('/data'),
///   maxAttempts: 3,
///   baseDelay: Duration(milliseconds: 500),
/// );
/// ```
class Aegis {
  Aegis._();

  static final _random = Random();

  /// Execute an async operation with retry logic.
  ///
  /// Returns the result on success. Throws the last error if all
  /// attempts fail.
  ///
  /// - [operation] — The async operation to execute.
  /// - [maxAttempts] — Max number of attempts (default: 3).
  /// - [baseDelay] — Base delay between retries (default: 500ms).
  /// - [maxDelay] — Maximum delay cap (default: 30s).
  /// - [strategy] — Backoff strategy (default: exponential).
  /// - [jitter] — Add random jitter to delays (default: true).
  /// - [retryIf] — Optional predicate for retryable errors.
  /// - [onRetry] — Callback before each retry attempt.
  ///
  /// ```dart
  /// final data = await Aegis.run(
  ///   () async => await fetchData(),
  ///   maxAttempts: 5,
  ///   baseDelay: Duration(seconds: 1),
  ///   onRetry: (attempt, error, delay) => print('Retry $attempt'),
  /// );
  /// ```
  static Future<T> run<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration baseDelay = const Duration(milliseconds: 500),
    Duration maxDelay = const Duration(seconds: 30),
    BackoffStrategy strategy = BackoffStrategy.exponential,
    bool jitter = true,
    bool Function(Object error)? retryIf,
    void Function(int attempt, Object error, Duration nextDelay)? onRetry,
  }) async {
    if (maxAttempts <= 0) {
      throw ArgumentError.value(
        maxAttempts,
        'maxAttempts',
        'must be at least 1',
      );
    }

    final stopwatch = Stopwatch()..start();
    Object? lastError;
    StackTrace? lastTrace;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final result = await operation();
        stopwatch.stop();
        return result;
      } catch (e, s) {
        lastError = e;
        lastTrace = s;

        // Check if this error should be retried
        if (retryIf != null && !retryIf(e)) {
          break;
        }

        // If we have more attempts, wait and retry
        if (attempt < maxAttempts) {
          final delay = _calculateDelay(
            attempt: attempt,
            baseDelay: baseDelay,
            maxDelay: maxDelay,
            strategy: strategy,
            jitter: jitter,
          );
          onRetry?.call(attempt, e, delay);
          await Future<void>.delayed(delay);
        }
      }
    }

    stopwatch.stop();
    Error.throwWithStackTrace(lastError!, lastTrace!);
  }

  /// Execute an operation with retry using an [AegisConfig].
  ///
  /// Same as [run] but uses a pre-built configuration object.
  ///
  /// ```dart
  /// final config = AegisConfig(maxAttempts: 5, jitter: false);
  /// final result = await Aegis.runWithConfig(
  ///   () async => await fetchData(),
  ///   config: config,
  /// );
  /// ```
  static Future<AegisResult<T>> runWithConfig<T>(
    Future<T> Function() operation, {
    AegisConfig config = AegisConfig.defaults,
    void Function(int attempt, Object error, Duration nextDelay)? onRetry,
  }) async {
    if (config.maxAttempts <= 0) {
      throw ArgumentError.value(
        config.maxAttempts,
        'maxAttempts',
        'must be at least 1',
      );
    }
    final stopwatch = Stopwatch()..start();
    Object? lastError;
    StackTrace? lastTrace;

    for (var attempt = 1; attempt <= config.maxAttempts; attempt++) {
      try {
        final result = await operation();
        stopwatch.stop();
        return AegisResult(
          value: result,
          attempts: attempt,
          totalDuration: stopwatch.elapsed,
        );
      } catch (e, s) {
        lastError = e;
        lastTrace = s;

        if (config.retryIf != null && !config.retryIf!(e)) {
          break;
        }

        if (attempt < config.maxAttempts) {
          final delay = _calculateDelay(
            attempt: attempt,
            baseDelay: config.baseDelay,
            maxDelay: config.maxDelay,
            strategy: config.strategy,
            jitter: config.jitter,
          );
          onRetry?.call(attempt, e, delay);
          await Future<void>.delayed(delay);
        }
      }
    }

    stopwatch.stop();
    Error.throwWithStackTrace(lastError!, lastTrace!);
  }

  /// Calculate the delay for a retry attempt.
  static Duration _calculateDelay({
    required int attempt,
    required Duration baseDelay,
    required Duration maxDelay,
    required BackoffStrategy strategy,
    required bool jitter,
  }) {
    double delayMs;

    switch (strategy) {
      case BackoffStrategy.exponential:
        delayMs = baseDelay.inMilliseconds * pow(2, attempt - 1).toDouble();
      case BackoffStrategy.linear:
        delayMs = baseDelay.inMilliseconds * attempt.toDouble();
      case BackoffStrategy.constant:
        delayMs = baseDelay.inMilliseconds.toDouble();
    }

    // Cap at maxDelay
    delayMs = min(delayMs, maxDelay.inMilliseconds.toDouble());

    // Add jitter (0-50% variation)
    if (jitter) {
      final jitterAmount = delayMs * 0.5 * _random.nextDouble();
      delayMs += jitterAmount;
    }

    return Duration(milliseconds: delayMs.round());
  }
}
