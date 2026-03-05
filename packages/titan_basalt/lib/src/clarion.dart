/// Clarion — Reactive job scheduler.
///
/// Executes async tasks on configurable intervals with full reactive
/// observability. Each job's lifecycle — state, run history, error count,
/// next execution — is exposed as reactive signals.
///
/// ## Why "Clarion"?
///
/// A clarion is a medieval trumpet that summons garrisons to action at
/// appointed hours. Titan's Clarion calls your scheduled tasks to
/// execution on time, every time — with full reactive visibility.
///
/// ## Usage
///
/// ```dart
/// class SyncPillar extends Pillar {
///   late final scheduler = clarion(name: 'sync');
///
///   @override
///   void onInit() {
///     scheduler.schedule(
///       'refresh-token',
///       Duration(minutes: 25),
///       () async => await authService.refresh(),
///     );
///     scheduler.schedule(
///       'flush-analytics',
///       Duration(minutes: 1),
///       () async => await analytics.flush(),
///       policy: ClarionPolicy.skipIfRunning,
///     );
///   }
/// }
/// ```
///
/// ## Reactive State
///
/// | Property       | Type                    | Description                     |
/// |----------------|-------------------------|---------------------------------|
/// | `status`       | `ReadCore<ClarionStatus>`   | Scheduler lifecycle             |
/// | `activeCount`  | `ReadCore<int>`             | Jobs currently executing        |
/// | `totalRuns`    | `ReadCore<int>`             | Lifetime execution count        |
/// | `totalErrors`  | `ReadCore<int>`             | Lifetime failure count          |
/// | `successRate`  | `Derived<double>`           | Success ratio (0.0–1.0)         |
/// | `isIdle`       | `Derived<bool>`             | No jobs currently executing     |
/// | `jobCount`     | `ReadCore<int>`             | Number of registered jobs       |
///
/// ## Per-Job State
///
/// ```dart
/// scheduler.job('refresh-token').isRunning.value
/// scheduler.job('refresh-token').runCount.value
/// scheduler.job('refresh-token').lastRun?.duration
/// scheduler.job('refresh-token').nextRun.value
/// ```
///
/// ## Concurrency Policies
///
/// | Policy           | Behavior                                     |
/// |------------------|----------------------------------------------|
/// | `skipIfRunning`  | Skip if previous execution still in progress |
/// | `allowOverlap`   | Allow concurrent executions                  |
library;

import 'dart:async';

import 'package:titan/titan.dart';

/// Scheduler lifecycle status.
enum ClarionStatus {
  /// Scheduler is idle — no jobs executing.
  idle,

  /// Scheduler has active job executions.
  running,

  /// Scheduler is paused — timers frozen.
  paused,

  /// Scheduler has been disposed.
  disposed,
}

/// Concurrency policy for overlapping job executions.
enum ClarionPolicy {
  /// Skip execution if the previous run is still in progress.
  skipIfRunning,

  /// Allow concurrent executions of the same job.
  allowOverlap,
}

/// A single execution record.
class ClarionRun {
  /// Creates an execution record.
  ClarionRun({required this.startedAt, required this.duration, this.error});

  /// When the execution started.
  final DateTime startedAt;

  /// How long the execution took.
  final Duration duration;

  /// Error if the execution failed, `null` if successful.
  final Object? error;

  /// Whether this execution succeeded.
  bool get succeeded => error == null;
}

/// Per-job reactive state and metadata.
class ClarionJobState {
  ClarionJobState._({required String prefix}) {
    _isRunning = TitanState<bool>(false, name: '${prefix}_running');
    _runCount = TitanState<int>(0, name: '${prefix}_runs');
    _errorCount = TitanState<int>(0, name: '${prefix}_errors');
    _lastRun = TitanState<ClarionRun?>(null, name: '${prefix}_lastRun');
    _nextRun = TitanState<DateTime?>(null, name: '${prefix}_nextRun');
  }

  late final TitanState<bool> _isRunning;
  late final TitanState<int> _runCount;
  late final TitanState<int> _errorCount;
  late final TitanState<ClarionRun?> _lastRun;
  late final TitanState<DateTime?> _nextRun;

  /// Whether this job is currently executing.
  ReadCore<bool> get isRunning => _isRunning;

  /// Total times this job has been executed.
  ReadCore<int> get runCount => _runCount;

  /// Total times this job has failed.
  ReadCore<int> get errorCount => _errorCount;

  /// Most recent execution record.
  ReadCore<ClarionRun?> get lastRun => _lastRun;

  /// Next scheduled execution time (null if one-shot completed or unscheduled).
  ReadCore<DateTime?> get nextRun => _nextRun;

  /// All reactive nodes for lifecycle management.
  List<ReactiveNode> get _nodes => [
    _isRunning,
    _runCount,
    _errorCount,
    _lastRun,
    _nextRun,
  ];
}

/// Internal job registration.
class _ClarionEntry {
  _ClarionEntry({
    required this.name,
    required this.handler,
    required this.interval,
    required this.policy,
    required this.state,
    this.isOneShot = false,
  });

  final String name;
  final Future<void> Function() handler;
  final Duration interval;
  final ClarionPolicy policy;
  final ClarionJobState state;
  final bool isOneShot;
  Timer? timer;
  bool paused = false;
}

/// Reactive job scheduler.
///
/// Manages recurring and one-shot async jobs with configurable intervals,
/// concurrency policies, and per-job reactive observability.
///
/// ```dart
/// final scheduler = Clarion(name: 'app');
/// scheduler.schedule(
///   'sync', Duration(minutes: 5),
///   () async => await api.sync(),
/// );
///
/// print(scheduler.totalRuns.value);
/// print(scheduler.job('sync').isRunning.value);
///
/// scheduler.dispose();
/// ```
class Clarion {
  /// Creates a scheduler.
  ///
  /// [name] is an optional prefix for reactive node names.
  Clarion({String? name}) {
    final prefix = name ?? 'clarion';

    _status = TitanState<ClarionStatus>(
      ClarionStatus.idle,
      name: '${prefix}_status',
    );
    _activeCount = TitanState<int>(0, name: '${prefix}_active');
    _totalRuns = TitanState<int>(0, name: '${prefix}_totalRuns');
    _totalErrors = TitanState<int>(0, name: '${prefix}_totalErrors');
    _jobCount = TitanState<int>(0, name: '${prefix}_jobCount');
    _successRate = TitanComputed<double>(
      () => _totalRuns.value > 0
          ? (_totalRuns.value - _totalErrors.value) / _totalRuns.value
          : 1.0,
      name: '${prefix}_successRate',
    );
    _isIdle = TitanComputed<bool>(
      () => _activeCount.value == 0,
      name: '${prefix}_isIdle',
    );

    _nodes = [
      _status,
      _activeCount,
      _totalRuns,
      _totalErrors,
      _jobCount,
      _successRate,
      _isIdle,
    ];
  }

  late final TitanState<ClarionStatus> _status;
  late final TitanState<int> _activeCount;
  late final TitanState<int> _totalRuns;
  late final TitanState<int> _totalErrors;
  late final TitanState<int> _jobCount;
  late final TitanComputed<double> _successRate;
  late final TitanComputed<bool> _isIdle;

  late List<ReactiveNode> _nodes;
  final Map<String, _ClarionEntry> _jobs = {};
  bool _disposed = false;
  bool _globalPaused = false;

  // ── Public reactive state ──

  /// Scheduler lifecycle status.
  ReadCore<ClarionStatus> get status => _status;

  /// Number of jobs currently executing.
  ReadCore<int> get activeCount => _activeCount;

  /// Total lifetime executions across all jobs.
  ReadCore<int> get totalRuns => _totalRuns;

  /// Total lifetime failures across all jobs.
  ReadCore<int> get totalErrors => _totalErrors;

  /// Number of registered jobs.
  ReadCore<int> get jobCount => _jobCount;

  /// Success ratio (1.0 if no runs yet).
  Derived<double> get successRate => _successRate;

  /// Whether no jobs are currently executing.
  Derived<bool> get isIdle => _isIdle;

  /// Get reactive state for a named job.
  ///
  /// Throws [ArgumentError] if [name] is not a registered job.
  ClarionJobState job(String name) {
    final entry = _jobs[name];
    if (entry == null) {
      throw ArgumentError.value(name, 'name', 'Unknown job');
    }
    return entry.state;
  }

  /// All registered job names.
  List<String> get jobNames => _jobs.keys.toList(growable: false);

  // ── Schedule jobs ──

  /// Schedule a recurring job.
  ///
  /// [name] uniquely identifies the job. [interval] is the delay between
  /// executions. [handler] is the async task to run. [policy] controls
  /// behavior when a previous run is still executing. If [immediate] is
  /// true, the job triggers once immediately on registration.
  void schedule(
    String name,
    Duration interval,
    Future<void> Function() handler, {
    ClarionPolicy policy = ClarionPolicy.skipIfRunning,
    bool immediate = false,
  }) {
    if (_disposed) return;
    if (_jobs.containsKey(name)) {
      throw StateError('Job "$name" already registered');
    }

    final prefix = '${name}_job';
    final state = ClarionJobState._(prefix: prefix);
    _nodes.addAll(state._nodes);

    final entry = _ClarionEntry(
      name: name,
      handler: handler,
      interval: interval,
      policy: policy,
      state: state,
    );

    _jobs[name] = entry;
    _jobCount.value++;

    if (immediate) {
      _executeJob(entry);
    }

    _startTimer(entry);
  }

  /// Schedule a one-shot delayed job.
  ///
  /// The job fires once after [delay] and is automatically unregistered.
  void scheduleOnce(
    String name,
    Duration delay,
    Future<void> Function() handler,
  ) {
    if (_disposed) return;
    if (_jobs.containsKey(name)) {
      throw StateError('Job "$name" already registered');
    }

    final prefix = '${name}_job';
    final state = ClarionJobState._(prefix: prefix);
    _nodes.addAll(state._nodes);

    final entry = _ClarionEntry(
      name: name,
      handler: handler,
      interval: delay,
      policy: ClarionPolicy.allowOverlap,
      state: state,
      isOneShot: true,
    );

    _jobs[name] = entry;
    _jobCount.value++;
    state._nextRun.value = DateTime.now().add(delay);

    entry.timer = Timer(delay, () {
      _executeJob(entry);
      // Remove after execution completes.
      Future<void>.delayed(Duration.zero, () {
        if (_jobs.containsKey(name) && entry.isOneShot) {
          _jobs.remove(name);
          _jobCount.value--;
        }
      });
    });
  }

  /// Remove and cancel a registered job.
  void unschedule(String name) {
    final entry = _jobs.remove(name);
    if (entry != null) {
      entry.timer?.cancel();
      _jobCount.value--;
    }
  }

  /// Manually trigger a job immediately, regardless of schedule.
  ///
  /// Respects the job's concurrency policy.
  void trigger(String name) {
    final entry = _jobs[name];
    if (entry == null) {
      throw ArgumentError.value(name, 'name', 'Unknown job');
    }
    _executeJob(entry);
  }

  // ── Pause / resume ──

  /// Pause a specific job by [name], or all jobs if [name] is null.
  void pause([String? name]) {
    if (_disposed) return;
    if (name != null) {
      final entry = _jobs[name];
      if (entry != null) {
        entry.paused = true;
        entry.timer?.cancel();
        entry.state._nextRun.value = null;
      }
    } else {
      _globalPaused = true;
      for (final entry in _jobs.values) {
        entry.paused = true;
        entry.timer?.cancel();
        entry.state._nextRun.value = null;
      }
      _status.value = ClarionStatus.paused;
    }
  }

  /// Resume a specific job by [name], or all jobs if [name] is null.
  void resume([String? name]) {
    if (_disposed) return;
    if (name != null) {
      final entry = _jobs[name];
      if (entry != null && entry.paused) {
        entry.paused = false;
        if (!entry.isOneShot) {
          _startTimer(entry);
        }
      }
    } else {
      _globalPaused = false;
      for (final entry in _jobs.values) {
        if (entry.paused) {
          entry.paused = false;
          if (!entry.isOneShot) {
            _startTimer(entry);
          }
        }
      }
      _updateStatus();
    }
  }

  /// Dispose the scheduler and cancel all timers.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final entry in _jobs.values) {
      entry.timer?.cancel();
    }
    _jobs.clear();
    _status.value = ClarionStatus.disposed;
  }

  /// Reactive nodes for [Pillar.registerNodes].
  List<ReactiveNode> get managedNodes => List.unmodifiable(_nodes);

  // ── Internal ──

  void _startTimer(_ClarionEntry entry) {
    entry.timer?.cancel();
    entry.state._nextRun.value = DateTime.now().add(entry.interval);
    entry.timer = Timer.periodic(entry.interval, (_) {
      if (!entry.paused && !_disposed) {
        _executeJob(entry);
        entry.state._nextRun.value = DateTime.now().add(entry.interval);
      }
    });
  }

  void _executeJob(_ClarionEntry entry) {
    if (_disposed) return;
    if (entry.paused) return;

    // Concurrency policy check.
    if (entry.policy == ClarionPolicy.skipIfRunning &&
        entry.state._isRunning.value) {
      return;
    }

    entry.state._isRunning.value = true;
    _activeCount.value++;
    _updateStatus();

    final startedAt = DateTime.now();

    entry
        .handler()
        .then((_) {
          final duration = DateTime.now().difference(startedAt);
          entry.state._lastRun.value = ClarionRun(
            startedAt: startedAt,
            duration: duration,
          );
          entry.state._runCount.value++;
          _totalRuns.value++;
        })
        .catchError((Object error) {
          final duration = DateTime.now().difference(startedAt);
          entry.state._lastRun.value = ClarionRun(
            startedAt: startedAt,
            duration: duration,
            error: error,
          );
          entry.state._runCount.value++;
          entry.state._errorCount.value++;
          _totalRuns.value++;
          _totalErrors.value++;
        })
        .whenComplete(() {
          entry.state._isRunning.value = false;
          _activeCount.value--;
          _updateStatus();
        });
  }

  void _updateStatus() {
    if (_disposed) return;
    if (_globalPaused) {
      _status.value = ClarionStatus.paused;
    } else if (_activeCount.value > 0) {
      _status.value = ClarionStatus.running;
    } else {
      _status.value = ClarionStatus.idle;
    }
  }
}
