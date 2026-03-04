/// Arbiter — Reactive conflict resolution.
///
/// Detects and resolves conflicting state updates from multiple sources
/// (offline queues, real-time server pushes, multi-device edits) using
/// pluggable resolution strategies. Tracks conflict history and
/// resolution outcomes reactively.
///
/// ## Why "Arbiter"?
///
/// An arbiter stands between competing claims and renders a fair
/// judgment. Titan's Arbiter arbitrates among conflicting state
/// updates — choosing the winner, merging the differences, or
/// deferring to manual resolution.
///
/// ## Usage
///
/// ```dart
/// class SyncPillar extends Pillar {
///   late final sync = arbiter<UserProfile>(
///     strategy: ArbiterStrategy.lastWriteWins,
///   );
///
///   void receiveRemote(UserProfile remote) {
///     sync.submit('server', remote);
///   }
///
///   void saveLocal(UserProfile local) {
///     sync.submit('local', local);
///   }
/// }
/// ```
///
/// ## Reactive State
///
/// | Property         | Type                                 | Description                      |
/// |------------------|--------------------------------------|----------------------------------|
/// | `conflictCount`  | `Core<int>`                          | Number of pending conflicts      |
/// | `lastResolution` | `Core<ArbiterResolution<T>?>`        | Most recent resolution outcome   |
/// | `hasConflicts`   | `Derived<bool>`                      | Whether unresolved conflicts exist |
/// | `totalResolved`  | `Core<int>`                          | Lifetime resolved count          |
///
/// ## Strategies
///
/// | Strategy          | Behavior                                               |
/// |-------------------|--------------------------------------------------------|
/// | `lastWriteWins`   | Most recent submission wins                             |
/// | `firstWriteWins`  | Earliest submission wins                                |
/// | `merge`           | Custom merge callback combines all submissions          |
/// | `manual`          | No auto-resolve; use `accept()` to pick a winner        |
///
/// ## Key Methods
///
/// | Method                | Description                                  |
/// |-----------------------|----------------------------------------------|
/// | `submit(source, val)` | Submit a value from a named source            |
/// | `resolve()`           | Auto-resolve using the configured strategy    |
/// | `accept(source)`      | Manually accept a specific source's value     |
/// | `reset()`             | Clear all pending conflicts and state         |
/// | `dispose()`           | Release all reactive nodes                    |
library;

import 'package:titan/titan.dart';

/// Strategy for automatic conflict resolution.
enum ArbiterStrategy {
  /// Most recently submitted value wins.
  lastWriteWins,

  /// Earliest submitted value wins.
  firstWriteWins,

  /// Merge all submissions via a custom callback.
  merge,

  /// No automatic resolution — use [Arbiter.accept] to pick a winner.
  manual,
}

/// A single submission in a conflict.
class ArbiterConflict<T> {
  /// Creates a conflict entry.
  const ArbiterConflict({
    required this.source,
    required this.value,
    required this.timestamp,
  });

  /// Identifier for the source (e.g. `'server'`, `'local'`, `'deviceB'`).
  final String source;

  /// The submitted value.
  final T value;

  /// When this value was submitted.
  final DateTime timestamp;

  @override
  String toString() => 'ArbiterConflict($source, $value)';
}

/// The outcome of a conflict resolution.
class ArbiterResolution<T> {
  /// Creates a resolution record.
  const ArbiterResolution({
    required this.resolved,
    required this.strategy,
    required this.candidates,
    required this.timestamp,
  });

  /// The winning/merged value.
  final T resolved;

  /// Which strategy was used.
  final ArbiterStrategy strategy;

  /// All candidates that were in conflict.
  final List<ArbiterConflict<T>> candidates;

  /// When the resolution occurred.
  final DateTime timestamp;

  @override
  String toString() =>
      'ArbiterResolution(${strategy.name}, ${candidates.length} candidates)';
}

/// Reactive conflict resolution engine.
///
/// Submit values from multiple sources. When two or more submissions
/// exist, a conflict is detected and can be resolved automatically
/// (via [ArbiterStrategy]) or manually (via [accept]).
///
/// ```dart
/// final sync = Arbiter<String>(
///   strategy: ArbiterStrategy.lastWriteWins,
/// );
/// sync.submit('local', 'hello');
/// sync.submit('server', 'world');
/// final result = sync.resolve();
/// print(result?.resolved); // 'world' (most recent)
/// ```
class Arbiter<T> {
  /// Creates an Arbiter with the given [strategy].
  ///
  /// For [ArbiterStrategy.merge], a [merge] callback must be provided
  /// that combines all candidate values into a single resolved value.
  ///
  /// Set [autoResolve] to `true` to automatically resolve conflicts
  /// as soon as a second submission arrives.
  Arbiter({
    required ArbiterStrategy strategy,
    T Function(List<ArbiterConflict<T>> candidates)? merge,
    bool autoResolve = false,
    String? name,
  }) : _strategy = strategy,
       _merge = merge,
       _autoResolve = autoResolve {
    if (strategy == ArbiterStrategy.merge && merge == null) {
      throw ArgumentError(
        'A merge callback is required when using ArbiterStrategy.merge',
      );
    }
    final prefix = name ?? 'arbiter';

    _conflictCount = TitanState<int>(0, name: '${prefix}_conflictCount');
    _lastResolution = TitanState<ArbiterResolution<T>?>(
      null,
      name: '${prefix}_lastResolution',
    );
    _totalResolved = TitanState<int>(0, name: '${prefix}_totalResolved');
    _hasConflicts = TitanComputed<bool>(
      () => _conflictCount.value > 1,
      name: '${prefix}_hasConflicts',
    );

    _nodes = [_conflictCount, _lastResolution, _totalResolved, _hasConflicts];
  }

  final ArbiterStrategy _strategy;
  final T Function(List<ArbiterConflict<T>> candidates)? _merge;
  final bool _autoResolve;

  // Reactive state
  late final TitanState<int> _conflictCount;
  late final TitanState<ArbiterResolution<T>?> _lastResolution;
  late final TitanState<int> _totalResolved;
  late final TitanComputed<bool> _hasConflicts;

  // Internal state
  final Map<String, ArbiterConflict<T>> _pending = {};
  final List<ArbiterResolution<T>> _history = [];
  late final List<ReactiveNode> _nodes;
  bool _disposed = false;

  // ─── Public reactive state ───────────────────────────────────

  /// Number of pending conflicts (sources with unresolved submissions).
  Core<int> get conflictCount => _conflictCount;

  /// Most recent resolution outcome, or `null` if none yet.
  Core<ArbiterResolution<T>?> get lastResolution => _lastResolution;

  /// Whether two or more unresolved submissions exist.
  Derived<bool> get hasConflicts => _hasConflicts;

  /// Total number of conflicts resolved over the lifetime.
  Core<int> get totalResolved => _totalResolved;

  // ─── Public API ──────────────────────────────────────────────

  /// Submit a value from a named [source].
  ///
  /// If a submission from the same source already exists, it is
  /// replaced. When two or more sources have pending submissions,
  /// [hasConflicts] becomes `true`.
  ///
  /// If [autoResolve] was enabled and a conflict is detected, the
  /// conflict is resolved immediately and the resolution is returned.
  ArbiterResolution<T>? submit(String source, T value, {DateTime? timestamp}) {
    _assertNotDisposed();
    _pending[source] = ArbiterConflict<T>(
      source: source,
      value: value,
      timestamp: timestamp ?? DateTime.now(),
    );
    _conflictCount.value = _pending.length;

    if (_autoResolve && _pending.length > 1) {
      return resolve();
    }
    return null;
  }

  /// Resolve the current conflict using the configured [ArbiterStrategy].
  ///
  /// Returns the [ArbiterResolution] if there were candidates to
  /// resolve, or `null` if no submissions exist.
  ///
  /// For [ArbiterStrategy.manual], this method returns `null` — use
  /// [accept] instead.
  ArbiterResolution<T>? resolve() {
    _assertNotDisposed();
    if (_pending.isEmpty) return null;
    if (_strategy == ArbiterStrategy.manual) return null;

    final candidates = _pending.values.toList();
    final T resolved;

    switch (_strategy) {
      case ArbiterStrategy.lastWriteWins:
        candidates.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        resolved = candidates.last.value;
      case ArbiterStrategy.firstWriteWins:
        candidates.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        resolved = candidates.first.value;
      case ArbiterStrategy.merge:
        resolved = _merge!(candidates);
      case ArbiterStrategy.manual:
        return null; // Unreachable due to guard above, but Dart requires it.
    }

    return _recordResolution(resolved, candidates);
  }

  /// Manually accept the submission from [source], resolving the conflict.
  ///
  /// Returns the [ArbiterResolution], or `null` if no submission from
  /// that source exists.
  ArbiterResolution<T>? accept(String source) {
    _assertNotDisposed();
    final chosen = _pending[source];
    if (chosen == null) return null;

    final candidates = _pending.values.toList();
    return _recordResolution(chosen.value, candidates);
  }

  /// All pending (unresolved) submissions.
  List<ArbiterConflict<T>> get pending => _pending.values.toList();

  /// The names of all sources with pending submissions.
  List<String> get sources => _pending.keys.toList();

  /// Resolution history (oldest first).
  List<ArbiterResolution<T>> get history => List.unmodifiable(_history);

  /// Reactive nodes for Pillar lifecycle management.
  List<ReactiveNode> get managedNodes => _nodes;

  /// Clear all pending submissions and reset reactive counters.
  ///
  /// Does not clear history.
  void reset() {
    _assertNotDisposed();
    _pending.clear();
    _conflictCount.value = 0;
    _lastResolution.value = null;
    _totalResolved.value = 0;
    _history.clear();
  }

  /// Dispose all reactive nodes.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    for (final node in _nodes) {
      node.dispose();
    }
  }

  // ─── Internals ───────────────────────────────────────────────

  ArbiterResolution<T> _recordResolution(
    T resolved,
    List<ArbiterConflict<T>> candidates,
  ) {
    final resolution = ArbiterResolution<T>(
      resolved: resolved,
      strategy: _strategy,
      candidates: List.unmodifiable(candidates),
      timestamp: DateTime.now(),
    );

    _history.add(resolution);
    _pending.clear();
    _conflictCount.value = 0;
    _lastResolution.value = resolution;
    _totalResolved.value = _totalResolved.value + 1;

    return resolution;
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('Cannot use a disposed Arbiter');
    }
  }
}
