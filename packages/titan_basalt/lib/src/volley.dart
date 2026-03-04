/// Volley — Batch async operations with concurrency control.
///
/// Volley orchestrates multiple async operations in parallel with
/// configurable concurrency limits, progress tracking, partial-failure
/// handling, and cancellation. Unlike [Saga] (sequential with compensation),
/// Volley runs tasks concurrently for throughput.
///
/// ## Why "Volley"?
///
/// A volley is a simultaneous discharge — many actions launched at once.
/// Titan's Volley fires off multiple async operations while keeping
/// them under control.
///
/// ## Usage
///
/// ```dart
/// class UploadPillar extends Pillar {
///   late final upload = volley<String>(
///     concurrency: 3,
///   );
///
///   Future<void> uploadFiles(List<File> files) async {
///     final tasks = files.map((f) => VolleyTask(
///       name: f.name,
///       execute: () async => await api.upload(f),
///     )).toList();
///
///     final results = await upload.execute(tasks);
///     // results contains VolleyResult.success or VolleyResult.failure per task
///   }
/// }
/// ```
library;

import 'dart:async';

import 'package:titan/titan.dart';

/// The status of a [Volley] execution.
enum VolleyStatus {
  /// No execution in progress.
  idle,

  /// Tasks are being executed.
  running,

  /// All tasks completed (some may have failed).
  done,

  /// Execution was cancelled.
  cancelled,
}

/// A single task in a [Volley] batch.
///
/// ```dart
/// VolleyTask(
///   name: 'upload-photo',
///   execute: () async => await uploadPhoto(photo),
///   timeout: Duration(seconds: 30),
/// )
/// ```
class VolleyTask<T> {
  /// Human-readable name for this task.
  final String name;

  /// The async operation to execute.
  final Future<T> Function() execute;

  /// Optional per-task timeout. Overrides [Volley.taskTimeout] if set.
  final Duration? timeout;

  /// Creates a volley task.
  const VolleyTask({required this.name, required this.execute, this.timeout});
}

/// The result of a single [VolleyTask].
///
/// Either [VolleySuccess] or [VolleyFailure].
sealed class VolleyResult<T> {
  /// The task name.
  final String taskName;

  const VolleyResult._({required this.taskName});

  /// Whether this result is a success.
  bool get isSuccess => this is VolleySuccess<T>;

  /// Whether this result is a failure.
  bool get isFailure => this is VolleyFailure<T>;

  /// Get the value if success, or null if failure.
  T? get valueOrNull => switch (this) {
    VolleySuccess<T>(value: final v) => v,
    VolleyFailure<T>() => null,
  };

  /// Get the error if failure, or null if success.
  Object? get errorOrNull => switch (this) {
    VolleySuccess<T>() => null,
    VolleyFailure<T>(error: final e) => e,
  };
}

/// A successful task result.
class VolleySuccess<T> extends VolleyResult<T> {
  /// The result value.
  final T value;

  /// Creates a successful result.
  const VolleySuccess({required super.taskName, required this.value})
    : super._();

  @override
  String toString() => 'VolleySuccess($taskName: $value)';
}

/// A failed task result.
class VolleyFailure<T> extends VolleyResult<T> {
  /// The error that caused the failure.
  final Object error;

  /// The stack trace of the failure.
  final StackTrace stackTrace;

  /// Creates a failed result.
  const VolleyFailure({
    required super.taskName,
    required this.error,
    required this.stackTrace,
  }) : super._();

  @override
  String toString() => 'VolleyFailure($taskName: $error)';
}

/// A batch async executor with concurrency control and progress tracking.
///
/// Executes multiple [VolleyTask]s in parallel with a configurable
/// concurrency limit. All progress is reactive via [Core] state nodes.
///
/// ## Features
///
/// - **Concurrency control** — configurable max parallel workers
/// - **Per-task timeout** — individual or global task timeout
/// - **Retry with backoff** — configurable retries with exponential delay
/// - **Reactive state** — progress, success/failure counts, status
/// - **Callbacks** — `onTaskComplete` and `onTaskFailed` hooks
/// - **Cancellation** — cancel remaining tasks mid-execution
///
/// ```dart
/// final volley = Volley<String>(
///   concurrency: 3,
///   maxRetries: 2,
///   retryDelay: Duration(milliseconds: 100),
/// );
///
/// final results = await volley.execute([
///   VolleyTask(name: 'a', execute: () async => 'result-a'),
///   VolleyTask(name: 'b', execute: () async => 'result-b'),
///   VolleyTask(name: 'c', execute: () async => 'result-c'),
/// ]);
///
/// print(volley.status);       // VolleyStatus.done
/// print(volley.successCount); // 3
/// print(volley.failedCount);  // 0
/// ```
class Volley<T> {
  /// Maximum number of concurrent tasks.
  final int concurrency;

  /// Maximum retries per task (default: 0 = no retries).
  final int maxRetries;

  /// Base delay between retries (multiplied by attempt number).
  final Duration retryDelay;

  /// Default timeout for all tasks. Overridden by [VolleyTask.timeout].
  final Duration? taskTimeout;

  /// Callback when a task completes successfully.
  final void Function(String taskName, T result)? onTaskComplete;

  /// Callback when a task fails after exhausting retries.
  final void Function(String taskName, Object error)? onTaskFailed;

  /// Reactive status.
  final TitanState<VolleyStatus> _status;

  /// Reactive progress (0.0 to 1.0).
  final TitanState<double> _progress;

  /// Reactive completed count (successes + failures).
  final TitanState<int> _completedCount;

  /// Plain success count (non-reactive for hot-path performance).
  int _rawSuccessCount = 0;

  /// Plain failed count (non-reactive for hot-path performance).
  int _rawFailedCount = 0;

  /// Reactive total count.
  final TitanState<int> _totalCount;

  /// Whether cancellation has been requested.
  bool _cancelRequested = false;

  /// Whether the Volley has been disposed.
  bool _isDisposed = false;

  /// Creates a Volley executor.
  ///
  /// - [concurrency] — Max parallel tasks (default: 5).
  /// - [maxRetries] — Retries per failed task (default: 0).
  /// - [retryDelay] — Base delay between retries (default: 100ms).
  /// - [taskTimeout] — Default timeout for all tasks.
  /// - [onTaskComplete] — Called on each task success.
  /// - [onTaskFailed] — Called on each task failure.
  /// - [name] — Debug name prefix for internal Cores.
  Volley({
    this.concurrency = 5,
    this.maxRetries = 0,
    this.retryDelay = const Duration(milliseconds: 100),
    this.taskTimeout,
    this.onTaskComplete,
    this.onTaskFailed,
    String? name,
  }) : _status = TitanState<VolleyStatus>(
         VolleyStatus.idle,
         name: name != null ? '${name}_status' : null,
       ),
       _progress = TitanState<double>(
         0.0,
         name: name != null ? '${name}_progress' : null,
       ),
       _completedCount = TitanState<int>(
         0,
         name: name != null ? '${name}_completed' : null,
       ),
       _totalCount = TitanState<int>(
         0,
         name: name != null ? '${name}_total' : null,
       ) {
    if (concurrency <= 0) {
      throw ArgumentError.value(concurrency, 'concurrency', 'must be > 0');
    }
    if (maxRetries < 0) {
      throw ArgumentError.value(maxRetries, 'maxRetries', 'must be >= 0');
    }
  }

  /// Current status (reactive).
  VolleyStatus get status => _status.value;

  /// The underlying reactive status Core.
  TitanState<VolleyStatus> get statusCore => _status;

  /// Current progress as a fraction (0.0 to 1.0, reactive).
  double get progress => _progress.value;

  /// The underlying reactive progress Core.
  TitanState<double> get progressCore => _progress;

  /// Number of completed tasks — successes + failures (reactive).
  int get completedCount => _completedCount.value;

  /// Number of successful tasks.
  int get successCount => _rawSuccessCount;

  /// Number of failed tasks.
  int get failedCount => _rawFailedCount;

  /// Total number of tasks (reactive).
  int get totalCount => _totalCount.value;

  /// Whether the volley is currently running.
  bool get isRunning => _status.peek() == VolleyStatus.running;

  /// Whether the Volley has been disposed.
  bool get isDisposed => _isDisposed;

  /// Execute a batch of tasks with concurrency control.
  ///
  /// Returns a list of [VolleyResult]s in the same order as the input tasks.
  /// Each result is either [VolleySuccess] or [VolleyFailure].
  ///
  /// ```dart
  /// final results = await volley.execute(tasks);
  /// for (final r in results) {
  ///   if (r.isSuccess) print('OK: ${r.valueOrNull}');
  ///   else print('FAIL: ${r.errorOrNull}');
  /// }
  /// ```
  Future<List<VolleyResult<T>>> execute(List<VolleyTask<T>> tasks) async {
    _assertNotDisposed();
    if (_status.peek() == VolleyStatus.running) {
      throw StateError('Volley is already running.');
    }

    _cancelRequested = false;
    _status.value = VolleyStatus.running;
    _totalCount.value = tasks.length;
    _completedCount.value = 0;
    _rawSuccessCount = 0;
    _rawFailedCount = 0;
    _progress.value = 0.0;

    if (tasks.isEmpty) {
      _status.value = VolleyStatus.done;
      _progress.value = 1.0;
      return [];
    }

    final results = List<VolleyResult<T>?>.filled(tasks.length, null);
    await _executePool(tasks, results);

    if (_cancelRequested) {
      _status.value = VolleyStatus.cancelled;
    } else {
      _status.value = VolleyStatus.done;
    }

    return results
        .map(
          (r) =>
              r ??
              VolleyFailure<T>(
                taskName: 'cancelled',
                error: StateError('Task was cancelled'),
                stackTrace: StackTrace.current,
              ),
        )
        .toList();
  }

  /// Pool-based execution with concurrency limit.
  Future<void> _executePool(
    List<VolleyTask<T>> tasks,
    List<VolleyResult<T>?> results,
  ) async {
    var nextIndex = 0;
    var completed = 0;
    final total = tasks.length;
    // Pre-compute fast-path eligibility (avoids per-task field checks).
    final useFastPath =
        maxRetries == 0 &&
        taskTimeout == null &&
        onTaskComplete == null &&
        onTaskFailed == null;

    Future<void> worker() async {
      while (!_cancelRequested) {
        final index = nextIndex++;
        if (index >= total) break;

        final task = tasks[index];

        if (useFastPath && task.timeout == null) {
          // Inline fast path: no retry, no timeout, no callbacks.
          try {
            final value = await task.execute();
            _rawSuccessCount++;
            results[index] = VolleySuccess(taskName: task.name, value: value);
          } catch (e, s) {
            _rawFailedCount++;
            results[index] = VolleyFailure(
              taskName: task.name,
              error: e,
              stackTrace: s,
            );
          }
        } else {
          results[index] = await _executeWithRetry(task);
        }

        completed++;
        _completedCount.value = completed;
        _progress.value = completed / total;
      }
    }

    // Start `concurrency` workers
    final workerCount = concurrency < total ? concurrency : total;
    final workers = List.generate(workerCount, (_) => worker());
    await Future.wait(workers);
  }

  /// Execute a single task with optional retries and timeout.
  Future<VolleyResult<T>> _executeWithRetry(VolleyTask<T> task) async {
    final maxAttempts = maxRetries + 1;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final effectiveTimeout = task.timeout ?? taskTimeout;
        T value;
        if (effectiveTimeout != null) {
          value = await task.execute().timeout(effectiveTimeout);
        } else {
          value = await task.execute();
        }

        _rawSuccessCount++;
        onTaskComplete?.call(task.name, value);
        return VolleySuccess(taskName: task.name, value: value);
      } catch (e, s) {
        if (attempt >= maxAttempts) {
          _rawFailedCount++;
          onTaskFailed?.call(task.name, e);
          return VolleyFailure(taskName: task.name, error: e, stackTrace: s);
        }
        // Wait before retry with exponential backoff
        await Future<void>.delayed(retryDelay * attempt);
      }
    }

    // Should not reach here, but satisfy the type system
    _rawFailedCount++;
    return VolleyFailure(
      taskName: task.name,
      error: StateError('Exhausted retries'),
      stackTrace: StackTrace.current,
    );
  }

  /// Request cancellation of the current execution.
  ///
  /// Already-running tasks will complete, but no new tasks will be started.
  void cancel() {
    _cancelRequested = true;
  }

  /// Reset the volley to idle state.
  void reset() {
    _assertNotDisposed();
    _status.value = VolleyStatus.idle;
    _progress.value = 0.0;
    _completedCount.value = 0;
    _rawSuccessCount = 0;
    _rawFailedCount = 0;
    _totalCount.value = 0;
    _cancelRequested = false;
  }

  /// All managed reactive nodes (for Pillar disposal).
  List<TitanState<dynamic>> get managedNodes => [
    _status,
    _progress,
    _completedCount,
    _totalCount,
  ];

  /// Dispose all internal state.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _status.dispose();
    _progress.dispose();
    _completedCount.dispose();
    _totalCount.dispose();
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use a disposed Volley');
    }
  }

  @override
  String toString() =>
      'Volley(status: ${_status.peek()}, '
      'success: $_rawSuccessCount, '
      'failed: $_rawFailedCount, '
      'total: ${_totalCount.peek()})';
}
