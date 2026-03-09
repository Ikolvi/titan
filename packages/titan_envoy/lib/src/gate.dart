import 'dart:async';
import 'dart:collection';

import 'courier.dart';
import 'dispatch.dart';
import 'envoy_error.dart';
import 'missive.dart';

/// **Gate** — Request throttling and queue management for [Envoy].
///
/// Limits the number of concurrent HTTP requests to prevent overwhelming
/// servers or exhausting local resources. Excess requests are queued and
/// processed in FIFO order as in-flight requests complete.
///
/// ```dart
/// final envoy = Envoy(baseUrl: 'https://api.example.com');
///
/// envoy.addCourier(Gate(
///   maxConcurrent: 4,
///   maxQueue: 100,
///   queueTimeout: Duration(seconds: 30),
/// ));
///
/// // Only 4 requests run simultaneously.
/// // Additional requests are queued until a slot opens.
/// await Future.wait([
///   envoy.get('/a'),
///   envoy.get('/b'),
///   envoy.get('/c'),
///   envoy.get('/d'),
///   envoy.get('/e'), // queued, waits for a slot
/// ]);
/// ```
class Gate extends Courier {
  /// Creates a new [Gate] with the given concurrency limits.
  ///
  /// - [maxConcurrent]: Maximum simultaneous requests (default: 6).
  /// - [maxQueue]: Maximum queued requests before rejection (default: 100).
  ///   Set to 0 for unlimited queue.
  /// - [queueTimeout]: Maximum time a request waits in queue before
  ///   being rejected with a [TimeoutException].
  Gate({this.maxConcurrent = 6, this.maxQueue = 100, this.queueTimeout})
    : assert(maxConcurrent > 0, 'maxConcurrent must be positive');

  /// Maximum number of concurrent requests.
  final int maxConcurrent;

  /// Maximum queue size. 0 means unlimited.
  final int maxQueue;

  /// Maximum time a request can wait in the queue.
  final Duration? queueTimeout;

  int _active = 0;
  final Queue<Completer<void>> _queue = Queue();

  /// Number of currently active requests.
  int get activeCount => _active;

  /// Number of requests waiting in the queue.
  int get queueLength => _queue.length;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    await _acquireSlot(missive);
    try {
      return await chain.proceed(missive);
    } finally {
      _releaseSlot();
    }
  }

  Future<void> _acquireSlot(Missive missive) async {
    if (_active < maxConcurrent) {
      _active++;
      return;
    }

    if (maxQueue > 0 && _queue.length >= maxQueue) {
      throw EnvoyError(
        type: EnvoyErrorType.unknown,
        missive: missive,
        message: 'Gate queue full ($maxQueue). Request rejected.',
      );
    }

    final completer = Completer<void>();
    _queue.add(completer);

    if (queueTimeout != null) {
      final future = completer.future.timeout(
        queueTimeout!,
        onTimeout: () {
          _queue.remove(completer);
          throw EnvoyError.timeout(missive: missive);
        },
      );
      await future;
    } else {
      await completer.future;
    }
  }

  void _releaseSlot() {
    if (_queue.isNotEmpty) {
      final next = _queue.removeFirst();
      // Don't decrement _active — we're transferring the slot
      next.complete();
    } else {
      _active--;
    }
  }
}
