/// Tapestry — Reactive event store with CQRS projections.
///
/// An append-only event store that treats immutable domain events as the
/// single source of truth. Current state is derived through reactive
/// projection functions ([TapestryWeave]) that automatically update when
/// new events are appended.
///
/// ## Why "Tapestry"?
///
/// A tapestry is a medieval wall-hung textile where individual threads
/// (events) are woven to form a complete picture (current state). Each
/// new thread changes the whole composition — just as each appended event
/// updates every active projection.
///
/// ## Usage
///
/// ```dart
/// class OrderPillar extends Pillar {
///   late final store = tapestry<OrderEvent>(name: 'orders');
///
///   late final revenue = store.weave<double>(
///     name: 'revenue',
///     initial: 0.0,
///     fold: (total, event) => switch (event) {
///       OrderPlaced(:final amount) => total + amount,
///       OrderRefunded(:final amount) => total - amount,
///       _ => total,
///     },
///   );
///
///   void placeOrder(double amount) {
///     store.append(OrderPlaced(amount: amount));
///     // revenue.state.value is automatically updated.
///   }
/// }
/// ```
///
/// ## Reactive State
///
/// | Property       | Type                     | Description                      |
/// |----------------|--------------------------|----------------------------------|
/// | `eventCount`   | `Core<int>`              | Total events in store            |
/// | `lastSequence` | `Core<int>`              | Latest sequence number           |
/// | `status`       | `Core<TapestryStatus>`   | Store lifecycle                  |
/// | `lastEventTime`| `Core<DateTime?>`        | Most recent event timestamp      |
/// | `weaveCount`   | `Core<int>`              | Number of active projections     |
///
/// ## Per-Weave State
///
/// ```dart
/// store.weave<int>(name: 'count', initial: 0, fold: (s, e) => s + 1);
/// // weave.state.value  - current projected state
/// // weave.version.value - events processed
/// // weave.lag.value     - events behind the log
/// ```
library;

import 'package:titan/titan.dart';

/// Store lifecycle status.
enum TapestryStatus {
  /// Store is idle — ready for operations.
  idle,

  /// Store is appending events.
  appending,

  /// Store is replaying events through projections.
  replaying,

  /// Store has been disposed.
  disposed,
}

/// Immutable event envelope with metadata.
class TapestryStrand<E> {
  /// Creates an event envelope.
  const TapestryStrand({
    required this.sequence,
    required this.event,
    required this.timestamp,
    this.correlationId,
    this.metadata,
  });

  /// Monotonically increasing sequence number (1-based).
  final int sequence;

  /// The domain event.
  final E event;

  /// When this event was appended.
  final DateTime timestamp;

  /// Optional correlation identifier for grouping related events.
  final String? correlationId;

  /// Optional arbitrary metadata.
  final Map<String, dynamic>? metadata;

  @override
  String toString() => 'TapestryStrand(#$sequence, $event)';
}

/// A reactive projection that folds events into state.
class TapestryWeave<E, S> {
  TapestryWeave._({
    required this.name,
    required S initial,
    required this.fold,
    required String prefix,
    this.where,
  }) {
    _state = TitanState<S>(initial, name: '${prefix}_state');
    _version = TitanState<int>(0, name: '${prefix}_version');
    _lastUpdated = TitanState<DateTime?>(null, name: '${prefix}_updated');
    _initialState = initial;
  }

  /// Projection name.
  final String name;

  /// Fold function: (currentState, event) => newState.
  final S Function(S state, E event) fold;

  /// Optional event filter — only matching events are folded.
  final bool Function(E event)? where;

  late final S _initialState;
  late final TitanState<S> _state;
  late final TitanState<int> _version;
  late final TitanState<DateTime?> _lastUpdated;

  /// Current projected state.
  Core<S> get state => _state;

  /// Number of events this weave has processed.
  Core<int> get version => _version;

  /// When the projection was last updated.
  Core<DateTime?> get lastUpdated => _lastUpdated;

  /// Apply a single event to this projection.
  void _apply(E event) {
    if (where != null && !where!(event)) return;
    _state.value = fold(_state.value, event);
    _version.value++;
    _lastUpdated.value = DateTime.now();
  }

  /// Reset projection to initial state.
  void _reset() {
    _state.value = _initialState;
    _version.value = 0;
    _lastUpdated.value = null;
  }

  /// All reactive nodes for lifecycle management.
  List<ReactiveNode> get nodes => [_state, _version, _lastUpdated];
}

/// Snapshot of a projection's state at a given sequence number.
class TapestryFrame<S> {
  /// Creates a snapshot.
  const TapestryFrame({
    required this.weaveName,
    required this.state,
    required this.sequence,
    required this.createdAt,
  });

  /// Name of the weave this frame belongs to.
  final String weaveName;

  /// The projected state at the snapshot point.
  final S state;

  /// The sequence number at which this snapshot was taken.
  final int sequence;

  /// When this snapshot was created.
  final DateTime createdAt;
}

/// Reactive event store with CQRS projections.
///
/// Manages an append-only log of domain events and maintains reactive
/// projections (weaves) that automatically fold new events into state.
///
/// ```dart
/// final store = Tapestry<String>(name: 'log');
/// final wordCount = store.weave<int>(
///   name: 'words',
///   initial: 0,
///   fold: (count, msg) => count + msg.split(' ').length,
/// );
///
/// store.append('hello world');
/// print(wordCount.state.value); // 2
///
/// store.append('foo bar baz');
/// print(wordCount.state.value); // 5
///
/// store.dispose();
/// ```
class Tapestry<E> {
  /// Creates an event store.
  ///
  /// [name] is an optional prefix for reactive node names.
  /// [maxEvents] limits the number of stored events (oldest are dropped
  /// when exceeded, but projections retain their computed state).
  Tapestry({String? name, this.maxEvents}) {
    final prefix = name ?? 'tapestry';

    _eventCount = TitanState<int>(0, name: '${prefix}_eventCount');
    _lastSequence = TitanState<int>(0, name: '${prefix}_lastSeq');
    _status = TitanState<TapestryStatus>(
      TapestryStatus.idle,
      name: '${prefix}_status',
    );
    _lastEventTime = TitanState<DateTime?>(null, name: '${prefix}_lastTime');
    _weaveCount = TitanState<int>(0, name: '${prefix}_weaveCount');

    _nodes = [_eventCount, _lastSequence, _status, _lastEventTime, _weaveCount];
  }

  /// Maximum number of events to retain. `null` means unlimited.
  final int? maxEvents;

  late final TitanState<int> _eventCount;
  late final TitanState<int> _lastSequence;
  late final TitanState<TapestryStatus> _status;
  late final TitanState<DateTime?> _lastEventTime;
  late final TitanState<int> _weaveCount;

  late List<ReactiveNode> _nodes;
  final List<TapestryStrand<E>> _events = [];
  final Map<String, TapestryWeave<E, dynamic>> _weaves = {};
  bool _disposed = false;

  // ── Public reactive state ──

  /// Total events currently in store.
  Core<int> get eventCount => _eventCount;

  /// Latest sequence number assigned.
  Core<int> get lastSequence => _lastSequence;

  /// Store lifecycle status.
  Core<TapestryStatus> get status => _status;

  /// Timestamp of the most recent event.
  Core<DateTime?> get lastEventTime => _lastEventTime;

  /// Number of active projections.
  Core<int> get weaveCount => _weaveCount;

  // ── Appending (write side) ──

  /// Append a single event and return its sequence number.
  ///
  /// All active weaves are updated synchronously.
  int append(E event, {String? correlationId, Map<String, dynamic>? metadata}) {
    if (_disposed) return -1;

    _status.value = TapestryStatus.appending;

    final seq = _lastSequence.value + 1;
    final now = DateTime.now();
    final strand = TapestryStrand<E>(
      sequence: seq,
      event: event,
      timestamp: now,
      correlationId: correlationId,
      metadata: metadata,
    );

    _events.add(strand);
    _lastSequence.value = seq;
    _eventCount.value++;
    _lastEventTime.value = now;

    // Apply to all weaves.
    for (final weave in _weaves.values) {
      weave._apply(event);
    }

    // Enforce maxEvents.
    if (maxEvents != null && _events.length > maxEvents!) {
      final drop = _events.length - maxEvents!;
      _events.removeRange(0, drop);
      _eventCount.value = _events.length;
    }

    _status.value = TapestryStatus.idle;
    return seq;
  }

  /// Append multiple events and return their sequence numbers.
  List<int> appendAll(List<E> events, {String? correlationId}) {
    final sequences = <int>[];
    for (final event in events) {
      sequences.add(append(event, correlationId: correlationId));
    }
    return sequences;
  }

  // ── Projections (read side / CQRS) ──

  /// Create a named reactive projection.
  ///
  /// [name] uniquely identifies the weave. [initial] is the starting state.
  /// [fold] reduces events into state. [where] optionally filters events.
  ///
  /// The weave immediately replays all existing events.
  TapestryWeave<E, S> weave<S>({
    required String name,
    required S initial,
    required S Function(S state, E event) fold,
    bool Function(E event)? where,
  }) {
    if (_weaves.containsKey(name)) {
      throw StateError('Weave "$name" already exists');
    }

    final prefix = '${name}_weave';
    final w = TapestryWeave<E, S>._(
      name: name,
      initial: initial,
      fold: fold,
      prefix: prefix,
      where: where,
    );
    _nodes.addAll(w.nodes);

    // Replay existing events.
    for (final strand in _events) {
      w._apply(strand.event);
    }

    _weaves[name] = w;
    _weaveCount.value++;
    return w;
  }

  /// Get a previously created weave by name.
  ///
  /// Returns `null` if not found.
  TapestryWeave<E, S>? getWeave<S>(String name) {
    final w = _weaves[name];
    if (w == null) return null;
    return w as TapestryWeave<E, S>;
  }

  /// Remove a named weave.
  void removeWeave(String name) {
    final w = _weaves.remove(name);
    if (w != null) {
      _weaveCount.value--;
    }
  }

  /// All registered weave names.
  List<String> get weaveNames => _weaves.keys.toList(growable: false);

  // ── Querying events ──

  /// Query events with optional filters.
  ///
  /// All parameters are optional and combined with AND logic.
  List<TapestryStrand<E>> query({
    int? fromSequence,
    int? toSequence,
    DateTime? after,
    DateTime? before,
    bool Function(E event)? where,
    String? correlationId,
    int? limit,
  }) {
    var results = _events.where((s) {
      if (fromSequence != null && s.sequence < fromSequence) return false;
      if (toSequence != null && s.sequence > toSequence) return false;
      if (after != null && s.timestamp.isBefore(after)) return false;
      if (before != null && s.timestamp.isAfter(before)) return false;
      if (correlationId != null && s.correlationId != correlationId) {
        return false;
      }
      if (where != null && !where(s.event)) return false;
      return true;
    });

    if (limit != null) {
      results = results.take(limit);
    }

    return results.toList();
  }

  /// Get a single event by sequence number.
  TapestryStrand<E>? at(int sequence) {
    for (final strand in _events) {
      if (strand.sequence == sequence) return strand;
    }
    return null;
  }

  /// All events in order.
  List<TapestryStrand<E>> get events => List.unmodifiable(_events);

  // ── Snapshots ──

  /// Create a snapshot of a weave's current state.
  TapestryFrame<S> frame<S>(String weaveName) {
    final w = _weaves[weaveName];
    if (w == null) {
      throw ArgumentError.value(weaveName, 'weaveName', 'Unknown weave');
    }
    return TapestryFrame<S>(
      weaveName: weaveName,
      state: w._state.value as S,
      sequence: _lastSequence.value,
      createdAt: DateTime.now(),
    );
  }

  // ── Replay ──

  /// Replay events through all weaves.
  ///
  /// Resets all weaves to their initial state and re-applies events
  /// from [fromSequence] (default: all).
  void replay({int? fromSequence}) {
    if (_disposed) return;
    _status.value = TapestryStatus.replaying;

    for (final weave in _weaves.values) {
      weave._reset();
    }

    for (final strand in _events) {
      if (fromSequence != null && strand.sequence < fromSequence) continue;
      for (final weave in _weaves.values) {
        weave._apply(strand.event);
      }
    }

    _status.value = TapestryStatus.idle;
  }

  // ── Compaction ──

  /// Remove events up to and including [upToSequence].
  ///
  /// Returns the number of events removed. Projections retain their
  /// computed state — only the raw event log is trimmed.
  int compact(int upToSequence) {
    if (_disposed) return 0;
    final before = _events.length;
    _events.removeWhere((s) => s.sequence <= upToSequence);
    final removed = before - _events.length;
    _eventCount.value = _events.length;
    return removed;
  }

  // ── Lifecycle ──

  /// Reset the store — clear all events and reset all weaves.
  void reset() {
    if (_disposed) return;
    _events.clear();
    _eventCount.value = 0;
    _lastSequence.value = 0;
    _lastEventTime.value = null;
    for (final weave in _weaves.values) {
      weave._reset();
    }
  }

  /// Dispose the store.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _status.value = TapestryStatus.disposed;
  }

  /// Reactive nodes for [Pillar.registerNodes].
  List<ReactiveNode> get managedNodes => List.unmodifiable(_nodes);
}
