/// Embargo — Reactive async mutex/semaphore.
///
/// Controls concurrent access to shared resources using permits.
/// In mutex mode (`permits: 1`, the default), only one task runs at
/// a time. In semaphore mode (`permits: N`), up to N tasks run
/// concurrently. All coordination state — active count, queue length,
/// lock status — is reactive, making it visible in the UI via Vestige.
///
/// ## Why "Embargo"?
///
/// An embargo is a restriction that controls the flow of operations.
/// Titan's Embargo controls concurrent access to critical sections,
/// preventing double-submits, serializing writes, and coordinating
/// parallel work.
///
/// ## Usage
///
/// ```dart
/// class CheckoutPillar extends Pillar {
///   // Mutex — prevent double-submit.
///   late final submitLock = embargo(name: 'submit');
///
///   // Semaphore — max 3 concurrent API calls.
///   late final apiPool = embargo(permits: 3, name: 'api');
///
///   Future<void> submit() async {
///     final result = await submitLock.guard(() async {
///       return await api.placeOrder();
///     });
///   }
///
///   Future<void> fetchMany(List<String> ids) async {
///     final futures = ids.map((id) =>
///       apiPool.guard(() => api.fetch(id)));
///     await Future.wait(futures);
///   }
/// }
/// ```
///
/// ## Reactive State
///
/// | Property       | Type              | Description                      |
/// |----------------|-------------------|----------------------------------|
/// | `isLocked`     | `Core<bool>`      | All permits currently acquired   |
/// | `activeCount`  | `ReadCore<int>`   | Number of currently held permits |
/// | `queueLength`  | `ReadCore<int>`   | Number of waiting acquirers      |
/// | `totalAcquires`| `ReadCore<int>`   | Lifetime acquire count           |
/// | `status`       | `Derived<EmbargoStatus>` | available/busy/contended  |
/// | `isAvailable`  | `Derived<bool>`   | Has a free permit now            |
///
/// ## Pillar Integration
///
/// Use the `embargo()` extension method on Pillar for lifecycle-managed
/// instances:
///
/// ```dart
/// late final lock = embargo(name: 'lock');
/// late final pool = embargo(permits: 5, name: 'pool');
/// ```
library;

import 'dart:async';
import 'dart:collection';

import 'package:titan/titan.dart';

/// The operational status of an [Embargo].
enum EmbargoStatus {
  /// Has free permits — next [Embargo.guard] call executes immediately.
  available,

  /// All permits acquired, but no waiters queued.
  busy,

  /// All permits acquired AND waiters are queued.
  contended,
}

/// Thrown when [Embargo.guard] or [Embargo.acquire] exceeds the timeout
/// while waiting for a permit.
class EmbargoTimeoutException implements Exception {
  /// Creates an [EmbargoTimeoutException].
  const EmbargoTimeoutException({
    required this.embargoName,
    required this.timeout,
    required this.queueLength,
  });

  /// The name of the embargo that timed out.
  final String embargoName;

  /// The timeout that was exceeded.
  final Duration timeout;

  /// How many tasks were waiting when the timeout occurred.
  final int queueLength;

  @override
  String toString() =>
      'EmbargoTimeoutException: "$embargoName" timed out after '
      '${timeout.inMilliseconds}ms with $queueLength waiting';
}

/// A handle representing an acquired permit from an [Embargo].
///
/// Must be [release]d when the critical section is complete.
/// Prefer [Embargo.guard] for automatic release.
class EmbargoLease {
  EmbargoLease._(this._embargo, this._acquiredAt);

  final Embargo _embargo;
  final DateTime _acquiredAt;
  bool _released = false;

  /// Whether this lease has been released.
  bool get isReleased => _released;

  /// How long this permit has been held.
  Duration get holdDuration => DateTime.now().difference(_acquiredAt);

  /// Return the permit to the embargo.
  ///
  /// Throws [StateError] if already released.
  void release() {
    if (_released) {
      throw StateError('EmbargoLease already released');
    }
    _released = true;
    _embargo._release();
  }
}

/// Reactive async mutex/semaphore.
///
/// Controls concurrent access to shared resources with configurable
/// permit count, optional timeout, and reactive state tracking.
///
/// See the library documentation for full usage examples.
class Embargo {
  /// Creates an [Embargo] with [permits] concurrent slots.
  ///
  /// - [permits] defaults to 1 (mutex mode).
  /// - [timeout] sets the default wait timeout for [guard] and [acquire].
  /// - [name] is used for debug output and [managedNodes] naming.
  Embargo({this.permits = 1, this.timeout, this.name}) {
    if (permits <= 0) {
      throw ArgumentError.value(permits, 'permits', 'must be > 0');
    }
    final n = name ?? 'embargo';
    _activeCount = TitanState<int>(0, name: '${n}_active');
    _queueLength = TitanState<int>(0, name: '${n}_queue');
    _totalAcquires = TitanState<int>(0, name: '${n}_total');
    _isLocked = TitanComputed<bool>(
      () => _activeCount.value >= permits,
      name: '${n}_locked',
    );
    _status = TitanComputed<EmbargoStatus>(() {
      if (_activeCount.value < permits) return EmbargoStatus.available;
      if (_queueLength.value > 0) return EmbargoStatus.contended;
      return EmbargoStatus.busy;
    }, name: '${n}_status');
    _isAvailable = TitanComputed<bool>(
      () => _activeCount.value < permits,
      name: '${n}_available',
    );
  }

  /// Maximum concurrent permits.
  final int permits;

  /// Default timeout for [guard] and [acquire]. `null` means wait forever.
  final Duration? timeout;

  /// Debug name.
  final String? name;

  // ── Internal state ─────────────────────────────────────────────────────

  late final TitanState<int> _activeCount;
  late final TitanState<int> _queueLength;
  late final TitanState<int> _totalAcquires;
  late final TitanComputed<bool> _isLocked;
  late final TitanComputed<EmbargoStatus> _status;
  late final TitanComputed<bool> _isAvailable;

  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  // ── Reactive properties ────────────────────────────────────────────────

  /// Whether all permits are currently acquired (reactive).
  Derived<bool> get isLocked => _isLocked;

  /// Number of currently held permits (reactive).
  ReadCore<int> get activeCount => _activeCount;

  /// Number of tasks waiting for a permit (reactive).
  ReadCore<int> get queueLength => _queueLength;

  /// Lifetime count of successful acquires (reactive).
  ReadCore<int> get totalAcquires => _totalAcquires;

  /// Operational status: available, busy, or contended (reactive).
  Derived<EmbargoStatus> get status => _status;

  /// Whether a permit can be acquired immediately (reactive).
  Derived<bool> get isAvailable => _isAvailable;

  /// Whether a permit can be acquired right now without waiting.
  bool get canAcquire => _activeCount.value < permits;

  // ── Primary API ────────────────────────────────────────────────────────

  /// Execute [action] while holding a permit.
  ///
  /// Acquires a permit, runs [action], and releases the permit when
  /// [action] completes (or throws). Returns the action's result.
  ///
  /// If no permit is available, waits in FIFO order until one is released.
  /// Throws [EmbargoTimeoutException] if [timeout] (or the instance
  /// default) elapses while waiting.
  ///
  /// ```dart
  /// final result = await lock.guard(() async {
  ///   return await api.placeOrder(cart);
  /// });
  /// ```
  Future<T> guard<T>(Future<T> Function() action, {Duration? timeout}) async {
    final lease = await acquire(timeout: timeout);
    try {
      return await action();
    } finally {
      lease.release();
    }
  }

  /// Manually acquire a permit.
  ///
  /// Returns an [EmbargoLease] that **must** be [EmbargoLease.release]d.
  /// Prefer [guard] for automatic release.
  ///
  /// Throws [EmbargoTimeoutException] if [timeout] elapses while waiting.
  Future<EmbargoLease> acquire({Duration? timeout}) async {
    if (_activeCount.value < permits) {
      // Permit available immediately.
      _activeCount.value++;
      _totalAcquires.value++;
      return EmbargoLease._(this, DateTime.now());
    }

    // Must wait.
    final completer = Completer<void>();
    _waiters.addLast(completer);
    _queueLength.value = _waiters.length;

    final effectiveTimeout = timeout ?? this.timeout;

    if (effectiveTimeout != null) {
      final timer = Timer(effectiveTimeout, () {
        if (!completer.isCompleted) {
          _waiters.remove(completer);
          _queueLength.value = _waiters.length;
          completer.completeError(
            EmbargoTimeoutException(
              embargoName: name ?? 'embargo',
              timeout: effectiveTimeout,
              queueLength: _waiters.length,
            ),
          );
        }
      });

      try {
        await completer.future;
        timer.cancel();
      } catch (_) {
        timer.cancel();
        rethrow;
      }
    } else {
      await completer.future;
    }

    _totalAcquires.value++;
    return EmbargoLease._(this, DateTime.now());
  }

  /// Release all permits and cancel all waiting tasks.
  ///
  /// Waiters receive a [StateError]. After reset, the Embargo returns
  /// to its initial state and can be reused.
  void reset() {
    _activeCount.value = 0;
    _totalAcquires.value = 0;

    // Cancel all waiters.
    while (_waiters.isNotEmpty) {
      final w = _waiters.removeFirst();
      if (!w.isCompleted) {
        w.completeError(StateError('Embargo reset while waiting'));
      }
    }
    _queueLength.value = 0;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Reactive nodes managed by this Embargo for Pillar integration.
  Iterable<ReactiveNode> get managedNodes => [
    _activeCount,
    _queueLength,
    _totalAcquires,
  ];

  // ── Internal ───────────────────────────────────────────────────────────

  void _release() {
    if (_activeCount.value <= 0) return;

    if (_waiters.isNotEmpty) {
      // Hand the permit directly to the next waiter.
      final next = _waiters.removeFirst();
      _queueLength.value = _waiters.length;
      if (!next.isCompleted) {
        // activeCount stays the same — transferred, not released.
        next.complete();
      }
    } else {
      _activeCount.value--;
    }
  }
}
