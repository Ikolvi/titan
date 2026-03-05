import 'package:titan/titan.dart';

// =============================================================================
// Lattice — Reactive DAG Task Executor
// =============================================================================

/// Callback for a [Lattice] task node.
///
/// The [upstream] map contains results from all completed dependency nodes,
/// keyed by their node ID.
typedef LatticeTask = Future<dynamic> Function(Map<String, dynamic> upstream);

/// Execution status of a [Lattice].
enum LatticeStatus {
  /// No execution in progress or completed.
  idle,

  /// Currently executing tasks.
  running,

  /// All tasks completed successfully.
  completed,

  /// One or more tasks failed.
  failed,
}

/// Result of a [Lattice.execute] call.
class LatticeResult {
  /// Creates a lattice execution result.
  const LatticeResult({
    required this.values,
    required this.errors,
    required this.elapsed,
    required this.executionOrder,
  });

  /// Return values from each successful task, keyed by node ID.
  final Map<String, dynamic> values;

  /// Errors from failed tasks, keyed by node ID.
  final Map<String, Object> errors;

  /// Total wall-clock execution time.
  final Duration elapsed;

  /// Order in which tasks completed.
  final List<String> executionOrder;

  /// Whether all tasks completed without error.
  bool get succeeded => errors.isEmpty;

  @override
  String toString() {
    final ok = values.length;
    final fail = errors.length;
    return 'LatticeResult($ok succeeded, $fail failed, ${elapsed.inMilliseconds} ms)';
  }
}

/// A reactive directed acyclic graph (DAG) task executor.
///
/// **Lattice** resolves task dependencies, maximizes parallelism for
/// independent nodes, and provides reactive progress tracking. It is
/// ideal for complex initialization sequences, data pipeline
/// orchestration, or multi-step workflows where tasks have explicit
/// dependency relationships.
///
/// ## Quick start
///
/// ```dart
/// class AppPillar extends Pillar {
///   late final startup = lattice(name: 'startup');
///
///   @override
///   void onInit() {
///     startup
///       ..node('config', (_) => loadConfig())
///       ..node('auth', (r) => authenticate(r['config']),
///           dependsOn: ['config'])
///       ..node('flags', (r) => loadFlags(r['config']),
///           dependsOn: ['config'])
///       ..node('data', (r) => fetchData(r['auth']),
///           dependsOn: ['auth', 'flags']);
///
///     startup.execute();
///   }
/// }
/// ```
///
/// ## Dependency resolution
///
/// Tasks execute in topological order determined by their `dependsOn`
/// declarations. Independent tasks run in parallel:
///
/// ```text
///   config ──┬──▶ auth ──┬──▶ data
///            └──▶ flags ─┘
/// ```
///
/// In this graph, `auth` and `flags` run in parallel after `config`
/// completes. `data` waits for both `auth` and `flags`.
///
/// ## Reactive outputs
///
/// All outputs are reactive [Core] or [Derived] values:
///
/// ```dart
/// Text('${pillar.startup.completedCount.value}'
///      ' / ${pillar.startup.nodeCount}');
/// LinearProgressIndicator(value: pillar.startup.progress.value);
/// ```
///
/// ## Error handling
///
/// If any task throws, execution stops (fail-fast). The returned
/// [LatticeResult] contains both successful results and errors:
///
/// ```dart
/// final result = await startup.execute();
/// if (!result.succeeded) {
///   for (final entry in result.errors.entries) {
///     print('Task ${entry.key} failed: ${entry.value}');
///   }
/// }
/// ```
class Lattice {
  /// Creates a reactive DAG task executor.
  Lattice({this.name}) {
    _status = TitanState<LatticeStatus>(LatticeStatus.idle);
    _completed = TitanState<int>(0);
    _progress = TitanComputed<double>(() {
      final total = _nodes.length;
      if (total == 0) return 1.0;
      return _completed.value / total;
    });
  }

  /// Optional debug name.
  final String? name;

  final Map<String, _LatticeNode> _nodes = {};

  late final TitanState<LatticeStatus> _status;
  late final TitanState<int> _completed;
  late final TitanComputed<double> _progress;

  // ---------------------------------------------------------------------------
  // Graph definition
  // ---------------------------------------------------------------------------

  /// Registers a named task node with optional dependencies.
  ///
  /// The [task] receives a map of upstream results keyed by node ID.
  /// Nodes can only be added while the lattice is [LatticeStatus.idle].
  ///
  /// ```dart
  /// lattice.node('config', (_) => loadConfig());
  /// lattice.node('auth', (r) => login(r['config']), dependsOn: ['config']);
  /// ```
  ///
  /// Throws [StateError] if the lattice is currently executing.
  void node(String id, LatticeTask task, {List<String> dependsOn = const []}) {
    if (_status.value != LatticeStatus.idle) {
      throw StateError('Cannot add nodes while executing');
    }
    _nodes[id] = _LatticeNode(id, task, List.unmodifiable(dependsOn));
  }

  // ---------------------------------------------------------------------------
  // Execution
  // ---------------------------------------------------------------------------

  /// Executes all tasks in dependency order with maximum parallelism.
  ///
  /// Returns a [LatticeResult] containing results, errors, and timing.
  ///
  /// Throws [StateError] if:
  /// - The lattice is already executing or completed (call [reset] first)
  /// - A dependency references a non-existent node
  /// - The dependency graph contains a cycle
  Future<LatticeResult> execute() async {
    if (_status.value != LatticeStatus.idle) {
      throw StateError(
        'Lattice is ${_status.value.name}. Call reset() before re-executing.',
      );
    }

    if (_nodes.isEmpty) {
      _status.value = LatticeStatus.completed;
      return const LatticeResult(
        values: {},
        errors: {},
        elapsed: Duration.zero,
        executionOrder: [],
      );
    }

    // Validate dependencies exist
    for (final n in _nodes.values) {
      for (final dep in n.dependsOn) {
        if (!_nodes.containsKey(dep)) {
          throw StateError(
            'Node "${n.id}" depends on "$dep" which does not exist',
          );
        }
      }
    }

    // Cycle detection via Kahn's algorithm
    final inDegree = <String, int>{};
    final dependents = <String, List<String>>{};

    for (final n in _nodes.values) {
      inDegree[n.id] = n.dependsOn.length;
      for (final dep in n.dependsOn) {
        (dependents[dep] ??= []).add(n.id);
      }
    }

    // Check for cycles: if no zero-in-degree nodes exist, there's a cycle
    final initialReady = [
      for (final e in inDegree.entries)
        if (e.value == 0) e.key,
    ];

    if (initialReady.isEmpty) {
      _status.value = LatticeStatus.failed;
      throw StateError('Cycle detected in dependency graph');
    }

    // Execute
    _status.value = LatticeStatus.running;
    _completed.value = 0;

    final sw = Stopwatch()..start();
    final results = <String, dynamic>{};
    final errors = <String, Object>{};
    final executionOrder = <String>[];
    final ready = List<String>.of(initialReady);

    var failed = false;

    while (ready.isNotEmpty && !failed) {
      final batch = List<String>.of(ready);
      ready.clear();

      final futures = batch.map((id) async {
        try {
          final result = await _nodes[id]!.task(
            Map<String, dynamic>.unmodifiable(results),
          );
          results[id] = result;
          executionOrder.add(id);
          _completed.value++;
        } catch (e) {
          errors[id] = e;
          failed = true;
        }
      });

      await Future.wait(futures);

      if (failed) break;

      // Update in-degrees and find newly ready nodes
      for (final completedId in batch) {
        for (final dependent in (dependents[completedId] ?? <String>[])) {
          inDegree[dependent] = inDegree[dependent]! - 1;
          if (inDegree[dependent] == 0) {
            ready.add(dependent);
          }
        }
      }
    }

    sw.stop();
    _status.value = errors.isEmpty
        ? LatticeStatus.completed
        : LatticeStatus.failed;

    return LatticeResult(
      values: results,
      errors: errors,
      elapsed: sw.elapsed,
      executionOrder: executionOrder,
    );
  }

  /// Resets the lattice to [LatticeStatus.idle] for re-execution.
  ///
  /// Does not remove registered nodes — only resets execution state.
  void reset() {
    _status.value = LatticeStatus.idle;
    _completed.value = 0;
  }

  // ---------------------------------------------------------------------------
  // Reactive state
  // ---------------------------------------------------------------------------

  /// Current execution status. Reactive — triggers UI rebuilds.
  ReadCore<LatticeStatus> get status => _status;

  /// Number of completed tasks. Reactive.
  ReadCore<int> get completedCount => _completed;

  /// Overall progress from 0.0 to 1.0. Reactive.
  Derived<double> get progress => _progress;

  /// Total number of registered nodes.
  int get nodeCount => _nodes.length;

  // ---------------------------------------------------------------------------
  // Graph inspection
  // ---------------------------------------------------------------------------

  /// Returns the IDs of all registered nodes.
  List<String> get nodeIds => _nodes.keys.toList(growable: false);

  /// Returns the dependency list for a node.
  ///
  /// Returns an empty list if the node does not exist.
  List<String> dependenciesOf(String id) => _nodes[id]?.dependsOn ?? const [];

  /// Whether the dependency graph contains a cycle.
  ///
  /// Uses Kahn's algorithm to check for cycles without executing.
  bool get hasCycle {
    if (_nodes.isEmpty) return false;

    final inDegree = <String, int>{};
    for (final n in _nodes.values) {
      inDegree.putIfAbsent(n.id, () => 0);
      for (final dep in n.dependsOn) {
        inDegree[n.id] = (inDegree[n.id] ?? 0) + 1;
        inDegree.putIfAbsent(dep, () => 0);
      }
    }

    final queue = [
      for (final e in inDegree.entries)
        if (e.value == 0) e.key,
    ];

    var processed = 0;
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      processed++;
      for (final n in _nodes.values) {
        if (n.dependsOn.contains(current)) {
          inDegree[n.id] = inDegree[n.id]! - 1;
          if (inDegree[n.id] == 0) {
            queue.add(n.id);
          }
        }
      }
    }

    return processed < _nodes.length;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Reactive nodes managed by this Lattice for Pillar lifecycle.
  Iterable<ReactiveNode> get managedNodes => [_status, _completed, _progress];

  @override
  String toString() {
    final label = name != null ? ' "$name"' : '';
    return 'Lattice$label(${_nodes.length} nodes, ${_status.value.name})';
  }
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

class _LatticeNode {
  const _LatticeNode(this.id, this.task, this.dependsOn);
  final String id;
  final LatticeTask task;
  final List<String> dependsOn;
}
