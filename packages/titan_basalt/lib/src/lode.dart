/// Lode — Reactive resource pool.
///
/// Manages a bounded pool of reusable expensive resources (database
/// connections, HTTP clients, WebSocket channels, worker isolates)
/// with lifecycle management, health validation, and reactive pool
/// metrics.
///
/// ## Why "Lode"?
///
/// A lode is a rich vein of ore from which valuable resources are
/// extracted and returned. Titan's Lode manages your application's
/// resource veins — creating, checking out, validating, returning,
/// and destroying pooled resources on demand.
///
/// ## Usage
///
/// ```dart
/// class DbPillar extends Pillar {
///   late final pool = lode<DbConnection>(
///     create: () async => DbConnection.open('postgres://...'),
///     destroy: (conn) async => conn.close(),
///     validate: (conn) async => conn.isOpen,
///     maxSize: 10,
///   );
///
///   Future<List<Row>> query(String sql) async {
///     return pool.withResource((conn) => conn.query(sql));
///   }
/// }
/// ```
///
/// ## Reactive State
///
/// | Property      | Type               | Description                        |
/// |---------------|--------------------|------------------------------------|
/// | `available`   | `Core<int>`        | Idle resources ready for checkout   |
/// | `inUse`       | `Core<int>`        | Resources currently checked out     |
/// | `size`        | `Core<int>`        | Total pool size (available + inUse) |
/// | `waiters`     | `Core<int>`        | Callers waiting for a resource      |
/// | `utilization` | `Derived<double>`  | inUse / maxSize (0.0–1.0)           |
///
/// ## Key Methods
///
/// | Method                    | Description                              |
/// |---------------------------|------------------------------------------|
/// | `acquire({timeout})`      | Check out a resource (returns LodeLease) |
/// | `withResource(fn)`        | Auto-acquire, execute, auto-release      |
/// | `warmup(count)`           | Pre-create resources                     |
/// | `drain()`                 | Return all idle resources to destruction |
/// | `dispose()`               | Destroy all resources                    |
library;

import 'dart:async';
import 'dart:collection';

import 'package:titan/titan.dart';

/// Status of a [Lode] resource pool.
enum LodeStatus {
  /// Pool is idle (no resources checked out).
  idle,

  /// Pool has resources checked out but is not exhausted.
  active,

  /// All resources are in use; new requests wait.
  exhausted,

  /// Pool is draining or disposed.
  draining,
}

/// A checked-out resource from a [Lode] pool.
///
/// Call [release] when done to return the resource to the pool.
/// Call [invalidate] if the resource is in a bad state and should
/// be destroyed instead of returned.
class LodeLease<T> {
  LodeLease._(this._resource, this._pool);

  final T _resource;
  final Lode<T> _pool;
  bool _released = false;

  /// The pooled resource.
  T get resource {
    if (_released) {
      throw StateError('Cannot access a released LodeLease');
    }
    return _resource;
  }

  /// Return the resource to the pool for reuse.
  void release() {
    if (_released) return;
    _released = true;
    _pool._return(_resource);
  }

  /// Destroy the resource instead of returning it to the pool.
  ///
  /// Use this when the resource is in a bad state (e.g. broken
  /// connection) and should not be reused.
  Future<void> invalidate() async {
    if (_released) return;
    _released = true;
    await _pool._destroy(_resource);
  }
}

/// Reactive resource pool.
///
/// Manages a bounded pool of reusable resources with create/destroy
/// lifecycle, optional health validation, and reactive metrics.
///
/// ```dart
/// final pool = Lode<HttpClient>(
///   create: () async => HttpClient(),
///   destroy: (c) async => c.close(),
///   maxSize: 5,
/// );
///
/// await pool.warmup(2); // Pre-create 2 clients
///
/// final result = await pool.withResource((client) async {
///   return client.get('https://api.example.com/data');
/// });
/// ```
class Lode<T> {
  /// Creates a resource pool.
  ///
  /// [create] is called to produce new resource instances.
  /// [destroy] is called when a resource is evicted or the pool is disposed.
  /// [validate] is called before returning a checked-out resource; if it
  /// returns `false`, the resource is destroyed and a new one is created.
  Lode({
    required Future<T> Function() create,
    Future<void> Function(T resource)? destroy,
    Future<bool> Function(T resource)? validate,
    int maxSize = 10,
    String? name,
  }) : _create = create,
       _destroy_ = destroy,
       _validate = validate,
       _maxSize = maxSize {
    if (maxSize <= 0) {
      throw ArgumentError.value(maxSize, 'maxSize', 'must be positive');
    }
    final prefix = name ?? 'lode';

    _available = TitanState<int>(0, name: '${prefix}_available');
    _inUse = TitanState<int>(0, name: '${prefix}_inUse');
    _size = TitanState<int>(0, name: '${prefix}_size');
    _waiters = TitanState<int>(0, name: '${prefix}_waiters');
    _utilization = TitanComputed<double>(
      () => _maxSize > 0 ? _inUse.value / _maxSize : 0.0,
      name: '${prefix}_utilization',
    );

    _nodes = [_available, _inUse, _size, _waiters, _utilization];
  }

  final Future<T> Function() _create;
  final Future<void> Function(T resource)? _destroy_;
  final Future<bool> Function(T resource)? _validate;
  final int _maxSize;

  // Pool storage
  final Queue<T> _idle = Queue<T>();
  final Set<T> _checkedOut = {};
  final Queue<Completer<T>> _waiting = Queue<Completer<T>>();

  // Reactive state
  late final TitanState<int> _available;
  late final TitanState<int> _inUse;
  late final TitanState<int> _size;
  late final TitanState<int> _waiters;
  late final TitanComputed<double> _utilization;

  late final List<ReactiveNode> _nodes;
  bool _disposed = false;

  // ─── Public reactive state ───────────────────────────────────

  /// Number of idle resources available for checkout.
  Core<int> get available => _available;

  /// Number of resources currently checked out.
  Core<int> get inUse => _inUse;

  /// Total pool size (available + inUse).
  Core<int> get size => _size;

  /// Number of callers waiting for a resource.
  Core<int> get waiters => _waiters;

  /// Pool utilization ratio (0.0–1.0). Equals `inUse / maxSize`.
  Derived<double> get utilization => _utilization;

  /// Maximum pool size.
  int get maxSize => _maxSize;

  /// Current pool status.
  LodeStatus get status {
    if (_disposed) return LodeStatus.draining;
    if (_checkedOut.isEmpty && _idle.isEmpty) return LodeStatus.idle;
    if (_checkedOut.length >= _maxSize) return LodeStatus.exhausted;
    return LodeStatus.active;
  }

  /// Reactive nodes for Pillar lifecycle management.
  List<ReactiveNode> get managedNodes => _nodes;

  // ─── Public API ──────────────────────────────────────────────

  /// Acquire a resource from the pool.
  ///
  /// If an idle resource is available and passes validation, it is
  /// returned immediately. Otherwise, a new resource is created
  /// (up to [maxSize]). If the pool is exhausted, the call waits
  /// until a resource becomes available or [timeout] expires.
  ///
  /// Returns a [LodeLease] — call [LodeLease.release] when done.
  Future<LodeLease<T>> acquire({Duration? timeout}) async {
    _assertNotDisposed();

    // Try to get an idle resource
    while (_idle.isNotEmpty) {
      final resource = _idle.removeFirst();
      if (_validate != null && !await _validate(resource)) {
        await _destroyResource(resource);
        continue;
      }
      _checkedOut.add(resource);
      _syncMetrics();
      return LodeLease._(resource, this);
    }

    // Create a new resource if under capacity
    if (_size.value < _maxSize) {
      final resource = await _create();
      _checkedOut.add(resource);
      _syncMetrics();
      return LodeLease._(resource, this);
    }

    // Wait for a resource to become available
    final completer = Completer<T>();
    _waiting.add(completer);
    _waiters.value = _waiting.length;

    if (timeout != null) {
      final timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          _waiting.remove(completer);
          _waiters.value = _waiting.length;
          completer.completeError(
            TimeoutException('Lode: timed out waiting for resource', timeout),
          );
        }
      });

      try {
        final resource = await completer.future;
        timer.cancel();
        return LodeLease._(resource, this);
      } catch (e) {
        timer.cancel();
        rethrow;
      }
    }

    final resource = await completer.future;
    return LodeLease._(resource, this);
  }

  /// Acquire a resource, execute [action], then auto-release.
  ///
  /// If [action] throws, the resource is still released (not
  /// invalidated). Use [acquire] directly if you need to
  /// invalidate on error.
  Future<R> withResource<R>(
    Future<R> Function(T resource) action, {
    Duration? timeout,
  }) async {
    final lease = await acquire(timeout: timeout);
    try {
      return await action(lease.resource);
    } finally {
      lease.release();
    }
  }

  /// Pre-create [count] resources to warm up the pool.
  ///
  /// Creates resources up to [maxSize]. Useful for avoiding
  /// cold-start latency on the first few requests.
  Future<void> warmup(int count) async {
    _assertNotDisposed();
    final toCreate = count.clamp(
      0,
      _maxSize - _idle.length - _checkedOut.length,
    );
    for (var i = 0; i < toCreate; i++) {
      final resource = await _create();
      _idle.add(resource);
    }
    _syncMetrics();
  }

  /// Destroy all idle resources in the pool.
  ///
  /// Checked-out resources are unaffected. They will be destroyed
  /// when released (via [LodeLease.invalidate]) or when the pool
  /// is disposed.
  Future<void> drain() async {
    _assertNotDisposed();
    while (_idle.isNotEmpty) {
      await _destroyResource(_idle.removeFirst());
    }
    _syncMetrics();
  }

  /// Dispose the pool, destroying all resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    // Cancel all waiters
    while (_waiting.isNotEmpty) {
      final completer = _waiting.removeFirst();
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Lode: pool disposed while waiting for resource'),
        );
      }
    }

    // Destroy idle resources
    while (_idle.isNotEmpty) {
      await _destroyResource(_idle.removeFirst());
    }

    // Destroy checked-out resources
    for (final resource in _checkedOut.toList()) {
      await _destroyResource(resource);
    }
    _checkedOut.clear();

    _syncMetrics();
    for (final node in _nodes) {
      node.dispose();
    }
  }

  // ─── Internal ────────────────────────────────────────────────

  void _return(T resource) {
    _checkedOut.remove(resource);

    if (_disposed) {
      _destroyResource(resource);
      return;
    }

    // If someone is waiting, hand the resource directly
    if (_waiting.isNotEmpty) {
      final completer = _waiting.removeFirst();
      _checkedOut.add(resource);
      _waiters.value = _waiting.length;
      _syncMetrics();
      completer.complete(resource);
      return;
    }

    _idle.add(resource);
    _syncMetrics();
  }

  Future<void> _destroy(T resource) async {
    _checkedOut.remove(resource);
    await _destroyResource(resource);
    _syncMetrics();
  }

  Future<void> _destroyResource(T resource) async {
    if (_destroy_ != null) {
      await _destroy_(resource);
    }
  }

  void _syncMetrics() {
    _available.value = _idle.length;
    _inUse.value = _checkedOut.length;
    _size.value = _idle.length + _checkedOut.length;
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('Cannot use a disposed Lode');
    }
  }
}
