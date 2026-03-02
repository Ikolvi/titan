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

import '../core/state.dart';

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
/// )
/// ```
class VolleyTask<T> {
  /// Human-readable name for this task.
  final String name;

  /// The async operation to execute.
  final Future<T> Function() execute;

  /// Creates a volley task.
  const VolleyTask({required this.name, required this.execute});
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
/// ```dart
/// final volley = Volley<String>(concurrency: 3);
///
/// final results = await volley.execute([
///   VolleyTask(name: 'a', execute: () async => 'result-a'),
///   VolleyTask(name: 'b', execute: () async => 'result-b'),
///   VolleyTask(name: 'c', execute: () async => 'result-c'),
/// ]);
///
/// print(volley.status); // VolleyStatus.done
/// print(volley.successCount); // 3
/// ```
class Volley<T> {
  /// Maximum number of concurrent tasks.
  final int concurrency;

  /// Reactive status.
  final TitanState<VolleyStatus> _status;

  /// Reactive progress (0.0 to 1.0).
  final TitanState<double> _progress;

  /// Reactive completed count.
  final TitanState<int> _completedCount;

  /// Reactive total count.
  final TitanState<int> _totalCount;

  /// Whether cancellation has been requested.
  bool _cancelRequested = false;

  /// Creates a Volley executor.
  ///
  /// - [concurrency] — Max parallel tasks (default: 5).
  /// - [name] — Debug name prefix for internal Cores.
  Volley({this.concurrency = 5, String? name})
    : _status = TitanState<VolleyStatus>(
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
      );

  /// Current status (reactive).
  VolleyStatus get status => _status.value;

  /// The underlying reactive status Core.
  TitanState<VolleyStatus> get statusCore => _status;

  /// Current progress as a fraction (0.0 to 1.0, reactive).
  double get progress => _progress.value;

  /// The underlying reactive progress Core.
  TitanState<double> get progressCore => _progress;

  /// Number of completed tasks (reactive).
  int get completedCount => _completedCount.value;

  /// Total number of tasks (reactive).
  int get totalCount => _totalCount.value;

  /// Whether the volley is currently running.
  bool get isRunning => _status.peek() == VolleyStatus.running;

  /// Number of successful results.
  int get successCount => _completedCount.peek();

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
    if (_status.peek() == VolleyStatus.running) {
      throw StateError('Volley is already running.');
    }

    _cancelRequested = false;
    _status.value = VolleyStatus.running;
    _totalCount.value = tasks.length;
    _completedCount.value = 0;
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

    Future<void> worker() async {
      while (!_cancelRequested) {
        final index = nextIndex++;
        if (index >= total) break;

        final task = tasks[index];
        try {
          final value = await task.execute();
          results[index] = VolleySuccess(taskName: task.name, value: value);
        } catch (e, s) {
          results[index] = VolleyFailure(
            taskName: task.name,
            error: e,
            stackTrace: s,
          );
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

  /// Request cancellation of the current execution.
  ///
  /// Already-running tasks will complete, but no new tasks will be started.
  void cancel() {
    _cancelRequested = true;
  }

  /// Reset the volley to idle state.
  void reset() {
    _status.value = VolleyStatus.idle;
    _progress.value = 0.0;
    _completedCount.value = 0;
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
    _status.dispose();
    _progress.dispose();
    _completedCount.dispose();
    _totalCount.dispose();
  }

  @override
  String toString() =>
      'Volley(status: ${_status.peek()}, ${_completedCount.peek()}/${_totalCount.peek()})';
}
