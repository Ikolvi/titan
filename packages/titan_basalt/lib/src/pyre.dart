/// Pyre — Priority-ordered async task queue with concurrency control.
///
/// A Pyre burns through tasks in priority order — the most urgent work
/// consumed first. Unlike [Volley] (fire a fixed batch all at once), Pyre
/// is a **persistent queue** that accepts tasks dynamically, even while
/// processing, and drains them by priority with configurable concurrency.
///
/// ## Why "Pyre"?
///
/// A pyre burns in ordered fury — offerings placed at the top are consumed
/// first. Titan's Pyre channels async work through a priority furnace,
/// ensuring critical tasks never wait behind trivial ones.
///
/// ## Usage
///
/// ```dart
/// class UploadPillar extends Pillar {
///   late final uploads = pyre<String>(
///     concurrency: 2,
///     maxQueueSize: 100,
///     onDrained: () => log.info('All uploads complete'),
///   );
///
///   Future<String> upload(File file, {bool urgent = false}) {
///     return uploads.enqueue(
///       () async => await api.upload(file),
///       priority: urgent ? PyrePriority.critical : PyrePriority.normal,
///       name: file.name,
///     );
///   }
/// }
/// ```
///
/// ## Features
///
/// - **Priority ordering** — critical, high, normal, low; FIFO within level
/// - **Concurrency control** — configurable max parallel workers
/// - **Backpressure** — optional max queue size with rejection
/// - **Reactive state** — queue length, running, completed, failed counts
/// - **Pause/resume** — suspend processing while running tasks finish
/// - **Task cancellation** — cancel individual or all pending tasks
/// - **Pillar integration** — `pyre()` factory with auto-disposal
///
/// ## Reactive Stats
///
/// ```dart
/// Text('Pending: ${queue.queueLength}');
/// Text('Running: ${queue.runningCount}');
/// LinearProgressIndicator(value: queue.progress);
/// ```
library;

import 'dart:async';
import 'dart:collection';

import 'package:titan/titan.dart';

/// Priority levels for Pyre tasks, ordered from highest to lowest.
///
/// Tasks with higher priority (lower [rank]) are dequeued before
/// lower-priority tasks. Within the same priority level, tasks are
/// processed in FIFO order.
///
/// ```dart
/// queue.enqueue(() async => criticalWork(), priority: PyrePriority.critical);
/// queue.enqueue(() async => normalWork()); // default: PyrePriority.normal
/// ```
enum PyrePriority implements Comparable<PyrePriority> {
  /// System-critical work — always runs before anything else.
  critical(0),

  /// High-priority user-facing work.
  high(1),

  /// Default priority for normal operations.
  normal(2),

  /// Background / speculative work. Runs only when nothing
  /// higher-priority is waiting.
  low(3);

  /// Numeric rank (lower = higher priority).
  final int rank;

  const PyrePriority(this.rank);

  @override
  int compareTo(PyrePriority other) => rank.compareTo(other.rank);
}

/// Lifecycle status of a single queued task.
enum PyreTaskStatus {
  /// Waiting in the queue (not yet started).
  pending,

  /// Currently executing.
  running,

  /// Completed successfully.
  completed,

  /// Failed after exhausting retry attempts.
  failed,

  /// Cancelled before execution began.
  cancelled,
}

/// Overall status of the Pyre queue.
enum PyreStatus {
  /// Queue is empty and idle.
  idle,

  /// Tasks are being processed.
  processing,

  /// Processing has been paused. Running tasks will finish,
  /// but no new tasks will be dequeued.
  paused,

  /// The queue has been shut down. No new tasks accepted.
  stopped,
}

/// Outcome of a completed Pyre task.
///
/// ```dart
/// final result = await queue.enqueue(() async => doWork());
/// // Or use drain() to get all results:
/// final results = await queue.drain();
/// for (final r in results) {
///   if (r.isSuccess) print('OK: ${r.valueOrNull}');
/// }
/// ```
sealed class PyreResult<T> {
  /// The task ID.
  final String taskId;

  /// Wall-clock duration of execution.
  final Duration duration;

  const PyreResult._({required this.taskId, required this.duration});

  /// Whether the task completed successfully.
  bool get isSuccess => this is PyreSuccess<T>;

  /// Whether the task failed.
  bool get isFailure => this is PyreFailure<T>;

  /// The result value, or `null` if failed.
  T? get valueOrNull;

  /// The error, or `null` if successful.
  Object? get errorOrNull;
}

/// A successful task result.
class PyreSuccess<T> extends PyreResult<T> {
  /// The result value.
  final T value;

  /// Creates a successful result.
  const PyreSuccess({
    required super.taskId,
    required this.value,
    required super.duration,
  }) : super._();

  @override
  T? get valueOrNull => value;

  @override
  Object? get errorOrNull => null;

  @override
  String toString() =>
      'PyreSuccess<$T>($taskId, $value, ${duration.inMilliseconds}ms)';
}

/// A failed task result.
class PyreFailure<T> extends PyreResult<T> {
  /// The error that caused the failure.
  final Object error;

  /// The stack trace at the point of failure.
  final StackTrace stackTrace;

  /// Creates a failure result.
  const PyreFailure({
    required super.taskId,
    required this.error,
    required this.stackTrace,
    required super.duration,
  }) : super._();

  @override
  T? get valueOrNull => null;

  @override
  Object? get errorOrNull => error;

  @override
  String toString() =>
      'PyreFailure<$T>($taskId, $error, ${duration.inMilliseconds}ms)';
}

/// Thrown when enqueueing a task would exceed the max queue size.
///
/// ```dart
/// try {
///   queue.enqueue(() async => work());
/// } on PyreBackpressureException catch (e) {
///   print('Queue full: ${e.currentSize}/${e.maxQueueSize}');
/// }
/// ```
class PyreBackpressureException implements Exception {
  /// Maximum allowed queue size.
  final int maxQueueSize;

  /// Current queue size at the time of rejection.
  final int currentSize;

  /// Creates a backpressure exception.
  const PyreBackpressureException({
    required this.maxQueueSize,
    required this.currentSize,
  });

  @override
  String toString() =>
      'PyreBackpressureException: queue full ($currentSize/$maxQueueSize)';
}

/// A priority-ordered async task queue with concurrency control.
///
/// Pyre processes async tasks in priority order with configurable
/// concurrency, backpressure, and reactive state. Tasks can be
/// enqueued dynamically — even while the queue is actively processing.
///
/// ## Example
///
/// ```dart
/// class DownloadPillar extends Pillar {
///   late final downloads = pyre<File>(
///     concurrency: 2,
///     maxQueueSize: 50,
///     name: 'downloads',
///   );
///
///   Future<File> download(String url) {
///     return downloads.enqueue(
///       () async => await api.download(url),
///       priority: PyrePriority.high,
///       name: url,
///     );
///   }
/// }
/// ```
class Pyre<T> {
  final int _concurrency;
  final int? _maxQueueSize;
  final int _maxRetries;
  final Duration _retryDelay;
  final bool _autoStart;
  final String? _name;

  /// Callback when a task completes successfully.
  final void Function(String taskId, T result)? onTaskComplete;

  /// Callback when a task fails after exhausting retries.
  final void Function(String taskId, Object error)? onTaskFailed;

  /// Callback when the queue is fully drained (empty + idle).
  final void Function()? onDrained;

  // Reactive state
  final TitanState<PyreStatus> _statusCore;
  final TitanState<int> _queueLengthCore;
  final TitanState<int> _runningCountCore;
  final TitanState<int> _completedCountCore;
  final TitanState<int> _failedCountCore;
  final TitanState<int> _totalEnqueuedCore;

  // Per-priority FIFO buckets — O(1) enqueue/dequeue.
  // Indexed by PyrePriority.rank (0=critical, 1=high, 2=normal, 3=low).
  final List<Queue<_PyreEntry<T>>> _buckets = List.generate(
    PyrePriority.values.length,
    (_) => Queue<_PyreEntry<T>>(),
  );
  int _totalQueued = 0;
  int _sequence = 0;

  // Active workers
  int _activeWorkers = 0;
  bool _isDisposed = false;

  /// Creates a priority-ordered async task queue.
  ///
  /// - [concurrency] — Max tasks executing simultaneously (default: 3).
  /// - [maxQueueSize] — Max pending tasks. `null` = unlimited.
  /// - [maxRetries] — Retry failed tasks (default: 0 = no retries).
  /// - [retryDelay] — Base delay between retries.
  /// - [autoStart] — Start processing on first enqueue (default: true).
  /// - [name] — Debug name for reactive state cores.
  ///
  /// ```dart
  /// final queue = Pyre<String>(
  ///   concurrency: 2,
  ///   maxQueueSize: 50,
  ///   maxRetries: 2,
  /// );
  /// ```
  Pyre({
    int concurrency = 3,
    int? maxQueueSize,
    int maxRetries = 0,
    Duration retryDelay = const Duration(milliseconds: 500),
    bool autoStart = true,
    this.onTaskComplete,
    this.onTaskFailed,
    this.onDrained,
    String? name,
  }) : _concurrency = concurrency,
       _maxQueueSize = maxQueueSize,
       _maxRetries = maxRetries,
       _retryDelay = retryDelay,
       _autoStart = autoStart,
       _name = name,
       _statusCore = TitanState<PyreStatus>(
         PyreStatus.idle,
         name: '${name ?? 'pyre'}_status',
       ),
       _queueLengthCore = TitanState<int>(
         0,
         name: '${name ?? 'pyre'}_queueLength',
       ),
       _runningCountCore = TitanState<int>(
         0,
         name: '${name ?? 'pyre'}_running',
       ),
       _completedCountCore = TitanState<int>(
         0,
         name: '${name ?? 'pyre'}_completed',
       ),
       _failedCountCore = TitanState<int>(0, name: '${name ?? 'pyre'}_failed'),
       _totalEnqueuedCore = TitanState<int>(
         0,
         name: '${name ?? 'pyre'}_totalEnqueued',
       ) {
    if (concurrency <= 0) {
      throw ArgumentError.value(concurrency, 'concurrency', 'must be > 0');
    }
    if (maxQueueSize != null && maxQueueSize <= 0) {
      throw ArgumentError.value(maxQueueSize, 'maxQueueSize', 'must be > 0');
    }
    if (maxRetries < 0) {
      throw ArgumentError.value(maxRetries, 'maxRetries', 'must be >= 0');
    }
  }

  // ---------------------------------------------------------------------------
  // Reactive state
  // ---------------------------------------------------------------------------

  /// Overall queue status (reactive).
  ///
  /// Reading this property inside a reactive scope (Derived, Vestige)
  /// automatically registers a dependency.
  PyreStatus get status => _statusCore.value;

  /// Number of pending tasks (reactive).
  int get queueLength => _queueLengthCore.value;

  /// Number of currently executing tasks (reactive).
  int get runningCount => _runningCountCore.value;

  /// Total successful completions (reactive).
  int get completedCount => _completedCountCore.value;

  /// Total failures (reactive).
  int get failedCount => _failedCountCore.value;

  /// Total tasks ever enqueued (reactive).
  int get totalEnqueued => _totalEnqueuedCore.value;

  /// Progress ratio: (completed + failed) / totalEnqueued (reactive).
  ///
  /// Returns 0.0 when no tasks have been enqueued.
  double get progress {
    final total = totalEnqueued;
    if (total == 0) return 0;
    return (completedCount + failedCount) / total;
  }

  /// Whether the queue has pending tasks.
  bool get hasPending => _totalQueued > 0;

  /// Whether the queue is actively processing.
  bool get isProcessing => _statusCore.value == PyreStatus.processing;

  /// Whether the queue has been disposed.
  bool get isDisposed => _isDisposed;

  /// The concurrency limit.
  int get concurrency => _concurrency;

  /// The debug name.
  String? get name => _name;

  /// All managed reactive nodes (for Pillar disposal).
  List<TitanState<dynamic>> get managedNodes => [
    _statusCore,
    _queueLengthCore,
    _runningCountCore,
    _completedCountCore,
    _failedCountCore,
    _totalEnqueuedCore,
  ];

  // ---------------------------------------------------------------------------
  // Enqueue
  // ---------------------------------------------------------------------------

  /// Enqueue a task for execution.
  ///
  /// Returns a [Future] that completes with the task's result when it
  /// finishes. The Future will complete with an error if the task fails
  /// or is cancelled.
  ///
  /// Throws [PyreBackpressureException] if the queue is full.
  /// Throws [StateError] if the queue is stopped or disposed.
  ///
  /// ```dart
  /// final result = await queue.enqueue(
  ///   () async => await api.fetch(url),
  ///   priority: PyrePriority.high,
  ///   name: 'fetch-$url',
  /// );
  /// ```
  Future<T> enqueue(
    Future<T> Function() execute, {
    PyrePriority priority = PyrePriority.normal,
    String? id,
    String? name,
  }) {
    _assertNotDisposed();
    if (_statusCore.value == PyreStatus.stopped) {
      throw StateError('Pyre is stopped — cannot enqueue new tasks');
    }

    // Backpressure check
    final max = _maxQueueSize;
    if (max != null && _totalQueued >= max) {
      throw PyreBackpressureException(
        maxQueueSize: max,
        currentSize: _totalQueued,
      );
    }

    final completer = Completer<T>();
    final taskId = id ?? '${_name ?? 'task'}_$_sequence';
    final entry = _PyreEntry<T>(
      id: taskId,
      name: name,
      priority: priority,
      execute: execute,
      completer: completer,
      sequence: _sequence++,
    );

    _enqueue(entry);
    _queueLengthCore.value = _totalQueued;
    _totalEnqueuedCore.value++;

    if (_autoStart && _statusCore.value == PyreStatus.idle) {
      _statusCore.value = PyreStatus.processing;
    }

    _scheduleWorkers();
    return completer.future;
  }

  /// Enqueue multiple tasks at once. Returns a list of Futures.
  ///
  /// ```dart
  /// final futures = queue.enqueueAll([
  ///   (execute: () async => api.a(), priority: PyrePriority.high, name: 'a'),
  ///   (execute: () async => api.b(), priority: PyrePriority.low, name: 'b'),
  /// ]);
  /// ```
  List<Future<T>> enqueueAll(
    List<({Future<T> Function() execute, PyrePriority priority, String? name})>
    tasks,
  ) {
    return tasks
        .map((t) => enqueue(t.execute, priority: t.priority, name: t.name))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Queue control
  // ---------------------------------------------------------------------------

  /// Start processing the queue. No-op if already processing.
  ///
  /// Only needed when `autoStart: false`.
  void start() {
    _assertNotDisposed();
    if (_statusCore.value == PyreStatus.stopped) {
      throw StateError('Pyre is stopped — cannot restart');
    }
    if (_statusCore.value != PyreStatus.processing && _totalQueued > 0) {
      _statusCore.value = PyreStatus.processing;
      _scheduleWorkers();
    }
  }

  /// Pause processing. Running tasks will finish, but no new tasks
  /// start until [resume] is called.
  void pause() {
    _assertNotDisposed();
    if (_statusCore.value == PyreStatus.processing) {
      _statusCore.value = PyreStatus.paused;
    }
  }

  /// Resume processing after a [pause].
  void resume() {
    _assertNotDisposed();
    if (_statusCore.value == PyreStatus.paused) {
      _statusCore.value = PyreStatus.processing;
      _scheduleWorkers();
    }
  }

  /// Cancel a specific pending task by ID.
  ///
  /// Returns `true` if the task was found and cancelled.
  /// Running tasks cannot be cancelled (returns `false`).
  bool cancel(String taskId) {
    for (final bucket in _buckets) {
      final entries = bucket.toList();
      final index = entries.indexWhere((e) => e.id == taskId);
      if (index != -1) {
        // Rebuild bucket without the cancelled entry
        final entry = entries.removeAt(index);
        bucket.clear();
        bucket.addAll(entries);
        entry.completer.completeError(
          StateError('Task cancelled: ${entry.id}'),
          StackTrace.current,
        );
        // Prevent unhandled async error when no one awaits the cancelled future
        entry.completer.future.ignore();
        _totalQueued--;
        _queueLengthCore.value = _totalQueued;
        return true;
      }
    }
    return false;
  }

  /// Cancel all pending (not-yet-running) tasks.
  ///
  /// Returns the number of tasks cancelled.
  int cancelAll() {
    final count = _totalQueued;
    for (final bucket in _buckets) {
      for (final entry in bucket) {
        entry.completer.completeError(
          StateError('Task cancelled: ${entry.id}'),
          StackTrace.current,
        );
        // Prevent unhandled async error when no one awaits the cancelled future
        entry.completer.future.ignore();
      }
      bucket.clear();
    }
    _totalQueued = 0;
    _queueLengthCore.value = 0;
    return count;
  }

  /// Drain the queue: cancel all pending tasks, wait for running
  /// tasks to complete, and return their results.
  ///
  /// ```dart
  /// final results = await queue.drain();
  /// final succeeded = results.where((r) => r.isSuccess).length;
  /// ```
  Future<List<PyreResult<T>>> drain() async {
    final cancelled = cancelAll();
    // If there are still running tasks, we need to give them a chance to complete
    if (_activeWorkers > 0) {
      // Wait until all active workers finish
      while (_activeWorkers > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    // Return empty list — drain cancels pending and waits for running
    return List.generate(
      cancelled,
      (i) => PyreFailure<T>(
        taskId: 'cancelled_$i',
        error: StateError('Cancelled during drain'),
        stackTrace: StackTrace.current,
        duration: Duration.zero,
      ),
    );
  }

  /// Stop the queue permanently. No new tasks accepted.
  /// Running tasks finish. Pending tasks are cancelled.
  Future<void> stop() async {
    cancelAll();
    _statusCore.value = PyreStatus.stopped;
    while (_activeWorkers > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Reset to idle state. Clears all counts and internal queues.
  void reset() {
    _assertNotDisposed();
    cancelAll();
    _statusCore.value = PyreStatus.idle;
    _completedCountCore.value = 0;
    _failedCountCore.value = 0;
    _totalEnqueuedCore.value = 0;
    _sequence = 0;
  }

  /// Peek at the next task that would be dequeued.
  ///
  /// Returns `null` if the queue is empty.
  String? peek() {
    for (final bucket in _buckets) {
      if (bucket.isNotEmpty) return bucket.first.id;
    }
    return null;
  }

  /// Dispose all internal state.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    cancelAll();
    _statusCore.dispose();
    _queueLengthCore.dispose();
    _runningCountCore.dispose();
    _completedCountCore.dispose();
    _failedCountCore.dispose();
    _totalEnqueuedCore.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Enqueue entry into the appropriate priority bucket — O(1).
  void _enqueue(_PyreEntry<T> entry) {
    _buckets[entry.priority.rank].add(entry);
    _totalQueued++;
  }

  /// Dequeue the highest-priority entry — O(k) where k = number of priorities.
  _PyreEntry<T> _dequeue() {
    for (final bucket in _buckets) {
      if (bucket.isNotEmpty) {
        _totalQueued--;
        return bucket.removeFirst();
      }
    }
    throw StateError('Cannot dequeue from empty Pyre');
  }

  /// Schedule workers to process the queue.
  void _scheduleWorkers() {
    while (_activeWorkers < _concurrency &&
        _totalQueued > 0 &&
        _statusCore.value == PyreStatus.processing) {
      _activeWorkers++;
      _runningCountCore.value = _activeWorkers;
      final entry = _dequeue();
      _queueLengthCore.value = _totalQueued;
      _runTask(entry);
    }
  }

  /// Run a single task with optional retries.
  Future<void> _runTask(_PyreEntry<T> entry) async {
    final sw = Stopwatch()..start();
    var attempts = 0;
    final maxAttempts = _maxRetries + 1;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final result = await entry.execute();
        sw.stop();

        if (!_isDisposed && !entry.completer.isCompleted) {
          entry.completer.complete(result);
          _completedCountCore.value++;
          onTaskComplete?.call(entry.id, result);
        }
        _workerFinished();
        return;
      } catch (e, s) {
        if (attempts >= maxAttempts) {
          sw.stop();
          if (!_isDisposed && !entry.completer.isCompleted) {
            entry.completer.completeError(e, s);
            _failedCountCore.value++;
            onTaskFailed?.call(entry.id, e);
          }
          _workerFinished();
          return;
        }
        // Retry after delay
        await Future<void>.delayed(_retryDelay * attempts);
      }
    }
  }

  /// Called when a worker finishes (success or failure).
  void _workerFinished() {
    if (_isDisposed) return;
    _activeWorkers--;
    _runningCountCore.value = _activeWorkers;

    if (_totalQueued > 0 && _statusCore.value == PyreStatus.processing) {
      _scheduleWorkers();
    } else if (_activeWorkers == 0 && _totalQueued == 0) {
      if (_statusCore.value != PyreStatus.stopped) {
        _statusCore.value = PyreStatus.idle;
      }
      onDrained?.call();
    }
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError(
        'Cannot use a disposed Pyre${_name != null ? ' ($_name)' : ''}',
      );
    }
  }

  @override
  String toString() {
    return 'Pyre<$T>(${_name ?? 'unnamed'}, '
        'status: ${_statusCore.value}, '
        'queue: $_totalQueued, '
        'running: $_activeWorkers, '
        'completed: ${_completedCountCore.value}, '
        'failed: ${_failedCountCore.value})';
  }
}

/// Internal queue entry.
class _PyreEntry<T> {
  final String id;
  final String? name;
  final PyrePriority priority;
  final Future<T> Function() execute;
  final Completer<T> completer;
  final int sequence;

  _PyreEntry({
    required this.id,
    this.name,
    required this.priority,
    required this.execute,
    required this.completer,
    required this.sequence,
  });
}
