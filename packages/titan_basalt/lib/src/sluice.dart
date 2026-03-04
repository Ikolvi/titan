/// Sluice — Reactive data pipeline.
///
/// Processes items through a configurable sequence of named stages, each
/// of which can transform, filter, or enrich data asynchronously. Every
/// stage exposes reactive metrics (processed, filtered, errors, queued) and
/// the pipeline itself provides aggregate reactive state.
///
/// ## Why "Sluice"?
///
/// A sluice is a controlled gate that regulates the flow of water through
/// a channel. Titan's Sluice regulates the flow of data through processing
/// stages — each gate opens, transforms, filters, and passes items through
/// to the next stage until they emerge completed.
///
/// ## Usage
///
/// ```dart
/// class OrderPillar extends Pillar {
///   late final pipeline = sluice<Order>(
///     stages: [
///       SluiceStage(name: 'validate', process: (o) => validate(o)),
///       SluiceStage(
///         name: 'charge',
///         process: (o) async => await chargeCard(o),
///         maxRetries: 2,
///         timeout: Duration(seconds: 10),
///       ),
///       SluiceStage(name: 'fulfill', process: (o) async => await ship(o)),
///     ],
///     onComplete: (o) => print('Order ${o.id} done'),
///   );
///
///   void submit(Order order) => pipeline.feed(order);
/// }
/// ```
///
/// ## Reactive State
///
/// | Property    | Type              | Description                        |
/// |-------------|-------------------|------------------------------------|
/// | `fed`       | `Core<int>`       | Total items fed into the pipeline  |
/// | `completed` | `Core<int>`       | Items exiting the final stage      |
/// | `failed`    | `Core<int>`       | Items that failed permanently      |
/// | `inFlight`  | `Core<int>`       | Items currently inside pipeline    |
/// | `status`    | `Core<SluiceStatus>` | idle / processing / paused / disposed |
/// | `isIdle`    | `Derived<bool>`   | Whether the pipeline has no work   |
/// | `errorRate` | `Derived<double>` | failed / fed ratio (0.0–1.0)       |
///
/// ## Per-Stage Metrics
///
/// ```dart
/// pipeline.stage('charge').processed.value  // Items through stage
/// pipeline.stage('charge').errors.value     // Failures at stage
/// pipeline.stage('charge').queued.value     // Waiting in stage
/// ```
///
/// ## Overflow Strategies
///
/// | Strategy        | Behavior                                   |
/// |-----------------|--------------------------------------------|
/// | `backpressure`  | `feed()` returns `false` when buffer full   |
/// | `dropOldest`    | Discards oldest queued item to make room    |
/// | `dropNewest`    | Discards the incoming item                  |
library;

import 'dart:async';
import 'dart:collection';

import 'package:titan/titan.dart';

/// Pipeline lifecycle status.
enum SluiceStatus {
  /// Pipeline is idle with no items in-flight.
  idle,

  /// Pipeline is actively processing items.
  processing,

  /// Pipeline is paused — queued items wait until resumed.
  paused,

  /// Pipeline has been disposed and cannot accept items.
  disposed,
}

/// Overflow strategy when the pipeline buffer is full.
enum SluiceOverflow {
  /// `feed()` returns `false` when buffer is full.
  backpressure,

  /// Drops the oldest queued item to accept the new one.
  dropOldest,

  /// Drops the incoming item (returns `false`).
  dropNewest,
}

/// Definition of a single processing stage.
///
/// Each stage receives an item and returns a transformed item,
/// or `null` to filter the item out (it won't proceed to the next stage).
///
/// ```dart
/// SluiceStage<String>(
///   name: 'uppercase',
///   process: (s) => s.toUpperCase(),
/// )
/// ```
class SluiceStage<T> {
  /// Creates a pipeline stage.
  ///
  /// [name] uniquely identifies this stage for metrics lookup.
  /// [process] transforms the item — return `null` to filter it out.
  /// [concurrency] limits parallel processing within this stage.
  /// [maxRetries] retries a failed item up to this many times.
  /// [timeout] maximum duration for a single item in this stage.
  /// [onError] per-stage error callback.
  const SluiceStage({
    required this.name,
    required this.process,
    this.concurrency = 1,
    this.maxRetries = 0,
    this.timeout,
    this.onError,
  }) : assert(concurrency > 0, 'concurrency must be positive');

  /// Unique stage name used for metrics lookup.
  final String name;

  /// Processing function. Return `null` to filter the item out.
  final FutureOr<T?> Function(T item) process;

  /// Maximum concurrent items processed by this stage.
  final int concurrency;

  /// Maximum retry count for failed items.
  final int maxRetries;

  /// Timeout per item in this stage.
  final Duration? timeout;

  /// Per-stage error callback.
  final void Function(T item, Object error)? onError;
}

/// Reactive metrics for a single pipeline stage.
class SluiceStageMetrics {
  SluiceStageMetrics._({required String prefix}) {
    _processed = TitanState<int>(0, name: '${prefix}_processed');
    _filtered = TitanState<int>(0, name: '${prefix}_filtered');
    _errors = TitanState<int>(0, name: '${prefix}_errors');
    _queued = TitanState<int>(0, name: '${prefix}_queued');
    _isIdle = TitanComputed<bool>(
      () => _queued.value == 0,
      name: '${prefix}_idle',
    );
  }

  late final TitanState<int> _processed;
  late final TitanState<int> _filtered;
  late final TitanState<int> _errors;
  late final TitanState<int> _queued;
  late final TitanComputed<bool> _isIdle;

  /// Number of items successfully processed by this stage.
  Core<int> get processed => _processed;

  /// Number of items filtered out (process returned `null`).
  Core<int> get filtered => _filtered;

  /// Number of items that failed permanently in this stage.
  Core<int> get errors => _errors;

  /// Number of items waiting to be processed by this stage.
  Core<int> get queued => _queued;

  /// Whether the stage has no queued or in-flight items.
  Derived<bool> get isIdle => _isIdle;

  /// All reactive nodes for lifecycle management.
  List<ReactiveNode> get _nodes => [
    _processed,
    _filtered,
    _errors,
    _queued,
    _isIdle,
  ];
}

/// Reactive data pipeline.
///
/// Feeds items through a sequence of [SluiceStage]s with per-stage
/// concurrency, retry, timeout, and reactive metrics. Supports
/// pause/resume, overflow strategies, and aggregate observability.
///
/// ```dart
/// final pipeline = Sluice<int>(
///   stages: [
///     SluiceStage(name: 'double', process: (n) => n * 2),
///     SluiceStage(name: 'filter', process: (n) => n > 5 ? n : null),
///   ],
/// );
///
/// pipeline.feed(3);  // 3 → 6 → completed (6 > 5)
/// pipeline.feed(2);  // 2 → 4 → filtered out (4 <= 5)
/// ```
class Sluice<T> {
  /// Creates a reactive data pipeline.
  ///
  /// [stages] defines the ordered processing stages.
  /// [bufferSize] limits the input queue. [overflow] controls behavior
  /// when the buffer is full. [onComplete] fires for each item that
  /// successfully exits the final stage. [onError] fires for permanent
  /// failures. [name] prefixes reactive node names.
  Sluice({
    required List<SluiceStage<T>> stages,
    this.bufferSize = 256,
    this.overflow = SluiceOverflow.backpressure,
    this.onComplete,
    this.onError,
    String? name,
  }) {
    if (stages.isEmpty) {
      throw ArgumentError.value(stages, 'stages', 'must not be empty');
    }
    final prefix = name ?? 'sluice';

    _fed = TitanState<int>(0, name: '${prefix}_fed');
    _completed = TitanState<int>(0, name: '${prefix}_completed');
    _failed = TitanState<int>(0, name: '${prefix}_failed');
    _inFlight = TitanState<int>(0, name: '${prefix}_inFlight');
    _status = TitanState<SluiceStatus>(
      SluiceStatus.idle,
      name: '${prefix}_status',
    );
    _isIdle = TitanComputed<bool>(
      () => _inFlight.value == 0 && _inputQueue.isEmpty,
      name: '${prefix}_isIdle',
    );
    _errorRate = TitanComputed<double>(
      () => _fed.value > 0 ? _failed.value / _fed.value : 0.0,
      name: '${prefix}_errorRate',
    );

    _nodes = [
      _fed,
      _completed,
      _failed,
      _inFlight,
      _status,
      _isIdle,
      _errorRate,
    ];

    // Initialize stages and per-stage metrics.
    for (final stageDef in stages) {
      if (stageDef.concurrency <= 0) {
        throw ArgumentError.value(
          stageDef.concurrency,
          'concurrency',
          'must be positive (stage "${stageDef.name}")',
        );
      }
      final metrics = SluiceStageMetrics._(
        prefix: '${prefix}_${stageDef.name}',
      );
      _stages.add(_SluiceStageRunner<T>(stageDef, metrics));
      _stageMetrics[stageDef.name] = metrics;
      _nodes.addAll(metrics._nodes);
    }

    _stageNames = stages.map((s) => s.name).toList(growable: false);
  }

  /// Maximum number of items in the input buffer.
  final int bufferSize;

  /// Overflow strategy when buffer is full.
  final SluiceOverflow overflow;

  /// Called when an item exits the final stage successfully.
  final void Function(T item)? onComplete;

  /// Called when an item fails permanently.
  final void Function(T item, Object error, String stageName)? onError;

  // ── Internal state ──
  late final TitanState<int> _fed;
  late final TitanState<int> _completed;
  late final TitanState<int> _failed;
  late final TitanState<int> _inFlight;
  late final TitanState<SluiceStatus> _status;
  late final TitanComputed<bool> _isIdle;
  late final TitanComputed<double> _errorRate;

  final List<_SluiceStageRunner<T>> _stages = [];
  final Map<String, SluiceStageMetrics> _stageMetrics = {};
  late final List<String> _stageNames;
  late List<ReactiveNode> _nodes;

  final Queue<T> _inputQueue = Queue<T>();
  bool _disposed = false;
  bool _processing = false;

  // ── Public reactive state ──

  /// Total items fed into the pipeline.
  Core<int> get fed => _fed;

  /// Items that successfully exited the final stage.
  Core<int> get completed => _completed;

  /// Items that failed permanently (after retries).
  Core<int> get failed => _failed;

  /// Items currently in-flight inside the pipeline.
  Core<int> get inFlight => _inFlight;

  /// Current pipeline lifecycle status.
  Core<SluiceStatus> get status => _status;

  /// Whether the pipeline is idle with no items.
  Derived<bool> get isIdle => _isIdle;

  /// Ratio of failed items to fed items (0.0–1.0).
  Derived<double> get errorRate => _errorRate;

  /// Ordered stage names.
  List<String> get stageNames => List.unmodifiable(_stageNames);

  /// Get reactive metrics for a named stage.
  ///
  /// Throws [ArgumentError] if [name] is not a valid stage name.
  SluiceStageMetrics stage(String name) {
    final metrics = _stageMetrics[name];
    if (metrics == null) {
      throw ArgumentError.value(name, 'name', 'Unknown stage');
    }
    return metrics;
  }

  // ── Feed items ──

  /// Feed a single item into the pipeline.
  ///
  /// Returns `true` if the item was accepted, `false` if rejected
  /// (due to backpressure/overflow or disposed state).
  bool feed(T item) {
    if (_disposed) return false;

    if (_inputQueue.length >= bufferSize) {
      switch (overflow) {
        case SluiceOverflow.backpressure:
        case SluiceOverflow.dropNewest:
          return false;
        case SluiceOverflow.dropOldest:
          if (_inputQueue.isNotEmpty) {
            _inputQueue.removeFirst();
            // The dropped item was already fed and in-flight.
            _inFlight.value--;
            if (_stages.isNotEmpty) {
              _stages.first._metrics._queued.value--;
            }
          }
      }
    }

    _inputQueue.addLast(item);
    _fed.value++;
    _inFlight.value++;

    if (_stages.isNotEmpty) {
      _stages.first._metrics._queued.value++;
    }

    _scheduleProcessing();
    return true;
  }

  /// Feed multiple items. Returns the number accepted.
  int feedAll(Iterable<T> items) {
    var accepted = 0;
    for (final item in items) {
      if (feed(item)) accepted++;
    }
    return accepted;
  }

  // ── Pipeline control ──

  /// Pause the pipeline. Queued items remain until [resume] is called.
  void pause() {
    if (_disposed) return;
    _status.value = SluiceStatus.paused;
  }

  /// Resume a paused pipeline and continue processing.
  void resume() {
    if (_disposed) return;
    if (_status.value == SluiceStatus.paused) {
      _status.value = _inFlight.value > 0
          ? SluiceStatus.processing
          : SluiceStatus.idle;
      _scheduleProcessing();
    }
  }

  /// Wait for all in-flight items to finish processing.
  ///
  /// Returns a [Future] that completes when the pipeline is idle.
  Future<void> flush() async {
    if (_disposed) return;
    // Pump until nothing remains.
    while (_inputQueue.isNotEmpty || _inFlight.value > 0) {
      await _processOnce();
    }
  }

  /// Dispose the pipeline and release all resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _inputQueue.clear();
    _status.value = SluiceStatus.disposed;
  }

  /// Reactive nodes for [Pillar.registerNodes].
  List<ReactiveNode> get managedNodes => List.unmodifiable(_nodes);

  // ── Internal processing ──

  void _scheduleProcessing() {
    if (_processing || _disposed || _status.value == SluiceStatus.paused) {
      return;
    }
    _processing = true;
    scheduleMicrotask(_processLoop);
  }

  Future<void> _processLoop() async {
    try {
      while (_inputQueue.isNotEmpty &&
          !_disposed &&
          _status.value != SluiceStatus.paused) {
        await _processOnce();
      }
    } finally {
      _processing = false;
      if (!_disposed) {
        _updateStatus();
      }
    }
  }

  Future<void> _processOnce() async {
    if (_inputQueue.isEmpty) return;
    final item = _inputQueue.removeFirst();

    if (_stages.isNotEmpty) {
      _stages.first._metrics._queued.value--;
    }

    _updateStatus();

    T? current = item;
    for (var i = 0; i < _stages.length; i++) {
      if (_disposed) {
        _inFlight.value--;
        return;
      }
      if (_status.value == SluiceStatus.paused) {
        // Re-queue and exit.
        _inputQueue.addFirst(current as T);
        if (_stages.isNotEmpty) {
          _stages.first._metrics._queued.value++;
        }
        return;
      }

      final runner = _stages[i];
      try {
        current = await runner._execute(current as T);

        if (current == null) {
          // Filtered out by this stage.
          runner._metrics._filtered.value++;
          _inFlight.value--;
          _updateStatus();
          return;
        }
        runner._metrics._processed.value++;
      } on Object catch (e) {
        runner._metrics._errors.value++;
        _failed.value++;
        _inFlight.value--;
        _updateStatus();
        runner._definition.onError?.call(current as T, e);
        onError?.call(current as T, e, runner._definition.name);
        return;
      }
    }

    // Successfully exited all stages.
    _completed.value++;
    _inFlight.value--;
    _updateStatus();
    onComplete?.call(current as T);
  }

  void _updateStatus() {
    if (_disposed) return;
    if (_status.value == SluiceStatus.paused) return;
    _status.value = _inFlight.value > 0 || _inputQueue.isNotEmpty
        ? SluiceStatus.processing
        : SluiceStatus.idle;
  }
}

/// Internal stage runner that handles execution, retries, and timeouts.
class _SluiceStageRunner<T> {
  _SluiceStageRunner(this._definition, this._metrics);

  final SluiceStage<T> _definition;
  final SluiceStageMetrics _metrics;

  /// Execute the stage's process function with retry and timeout support.
  Future<T?> _execute(T item) async {
    var lastError = Object();
    for (var attempt = 0; attempt <= _definition.maxRetries; attempt++) {
      try {
        final result = _definition.process(item);
        if (result is Future<T?>) {
          if (_definition.timeout != null) {
            return await result.timeout(_definition.timeout!);
          }
          return await result;
        }
        return result;
      } on Object catch (e) {
        lastError = e;
        if (attempt < _definition.maxRetries) {
          continue; // Retry.
        }
      }
    }
    throw lastError; // All retries exhausted.
  }
}
