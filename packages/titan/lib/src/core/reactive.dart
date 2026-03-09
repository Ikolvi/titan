import 'package:meta/meta.dart';

/// Global reactive tracking scope.
///
/// Manages dependency tracking between reactive nodes. When a [TitanComputed]
/// or [TitanEffect] evaluates, it pushes itself as the current tracker.
/// Any [TitanState] read during evaluation automatically registers itself
/// as a dependency of the tracker.
class ReactiveScope {
  ReactiveScope._();

  static ReactiveNode? _currentTracker;
  static bool _isBatching = false;
  static final Set<ReactiveNode> _pendingNodes = {};

  /// Returns the currently active tracker, if any.
  static ReactiveNode? get currentTracker => _currentTracker;

  /// Whether updates are currently being batched.
  static bool get isBatching => _isBatching;

  /// Pushes a new tracker onto the tracking stack.
  @internal
  static ReactiveNode? pushTracker(ReactiveNode? tracker) {
    final previous = _currentTracker;
    _currentTracker = tracker;
    return previous;
  }

  /// Pops the current tracker, restoring the previous one.
  @internal
  static void popTracker(ReactiveNode? previous) {
    _currentTracker = previous;
  }

  /// Begins a batching scope. State changes within a batch will be
  /// deferred until the batch completes.
  @internal
  static void beginBatch() {
    _isBatching = true;
  }

  /// Ends a batching scope and flushes all pending notifications.
  @internal
  static void endBatch() {
    _isBatching = false;
    _flushPending();
  }

  /// Schedules a node for notification when the current batch ends.
  @internal
  static void schedulePending(ReactiveNode node) {
    _pendingNodes.add(node);
  }

  static void _flushPending() {
    if (_pendingNodes.isEmpty) return;
    // Swap-and-drain: avoids toList() allocation while preventing
    // concurrent modification if a notification schedules more pending nodes.
    final nodes = _pendingNodes.toSet();
    _pendingNodes.clear();
    for (final node in nodes) {
      node.notifyDependents();
    }
  }
}

/// Callback signature for listening to reactive node changes.
typedef ReactiveListener = void Function();

/// Base class for all reactive primitives in Titan.
///
/// A [ReactiveNode] participates in the reactive dependency graph.
/// It can track dependents (nodes that depend on it) and be tracked
/// as a dependency when read within a reactive scope.
abstract class ReactiveNode {
  // Lazy-initialized: most nodes never acquire dependents or listeners,
  // so we avoid allocating a Set/List per node.
  Set<ReactiveNode>? _dependents;
  List<ReactiveListener>? _listeners;
  bool _isDisposed = false;
  bool _isNotifying = false;

  /// Whether this node has been disposed.
  bool get isDisposed => _isDisposed;

  /// The number of active dependents.
  int get dependentCount => _dependents?.length ?? 0;

  /// The number of active listeners.
  int get listenerCount => _listeners?.length ?? 0;

  /// Registers the current tracker (if any) as a dependent of this node.
  ///
  /// Called automatically when a reactive value is read inside a
  /// [TitanComputed] or [TitanEffect].
  @protected
  void track() {
    final tracker = ReactiveScope.currentTracker;
    if (tracker != null && tracker != this) {
      (_dependents ??= {}).add(tracker);
      tracker.onTracked(this);
    }
  }

  /// Called when this node is registered as tracking [source].
  ///
  /// Override in subclasses to maintain a dependency set for cleanup.
  @protected
  void onTracked(ReactiveNode source) {}

  /// Notifies all dependents and listeners that this node changed.
  @protected
  void notifyDependents() {
    if (_isDisposed) return;

    if (ReactiveScope.isBatching) {
      ReactiveScope.schedulePending(this);
      return;
    }

    final deps = _dependents;
    final listeners = _listeners;

    // Fast path: nothing to notify.
    if (deps == null && listeners == null) return;

    _isNotifying = true;

    // Notify dependent reactive nodes.
    // We must snapshot because dependents may re-register during notification
    // (computed nodes clear and re-track their dependencies).
    if (deps != null && deps.isNotEmpty) {
      final snapshot = deps.toList(growable: false);
      for (var i = 0; i < snapshot.length; i++) {
        final dep = snapshot[i];
        if (!dep.isDisposed) {
          dep.onDependencyChanged(this);
        }
      }
    }

    // Notify imperative listeners (iterate by index — no allocation).
    // Listeners that remove themselves during callback are handled safely
    // via snapshot if the list was modified during iteration.
    if (listeners != null && listeners.isNotEmpty) {
      for (var i = 0; i < listeners.length; i++) {
        listeners[i]();
      }
    }

    _isNotifying = false;
  }

  /// Called when a dependency of this node has changed.
  ///
  /// Override to implement custom update logic (e.g., recomputation).
  @protected
  void onDependencyChanged(ReactiveNode dependency) {}

  /// Adds an imperative listener that is called when this node changes.
  void addListener(ReactiveListener listener) {
    if (_isNotifying) {
      // Copy-on-write: don't mutate the list being iterated
      _listeners = List.of(_listeners ?? [])..add(listener);
    } else {
      (_listeners ??= []).add(listener);
    }
  }

  /// Removes a previously added listener.
  void removeListener(ReactiveListener listener) {
    final listeners = _listeners;
    if (listeners == null) return;
    if (_isNotifying) {
      _listeners = List.of(listeners)..remove(listener);
    } else {
      listeners.remove(listener);
    }
  }

  /// Removes a specific dependent from this node.
  @internal
  void removeDependent(ReactiveNode dependent) {
    _dependents?.remove(dependent);
  }

  /// Disposes this node, clearing all dependents and listeners.
  @mustCallSuper
  void dispose() {
    _isDisposed = true;
    _dependents = null;
    _listeners = null;
  }
}
