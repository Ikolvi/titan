/// Bulwark — A reactive circuit breaker for resilient async operations.
///
/// A Bulwark shields your application from cascading failures by
/// tracking error rates and automatically opening the circuit when
/// a failure threshold is breached.
///
/// ## Why "Bulwark"?
///
/// A bulwark is a defensive wall. The Bulwark defends your app
/// against cascading failures from unreliable services.
///
/// ## States
///
/// - **Closed** — Normal operation. Requests pass through.
/// - **Open** — Circuit tripped. Requests fail immediately.
/// - **Half-Open** — Testing recovery. One request allowed through.
///
/// ## Usage
///
/// ```dart
/// class ApiPillar extends Pillar {
///   late final apiBreaker = bulwark<String>(
///     failureThreshold: 3,
///     resetTimeout: Duration(seconds: 30),
///     name: 'api',
///   );
///
///   Future<String> fetchData() async {
///     return apiBreaker.call(() => api.getData());
///   }
/// }
/// ```
library;

import 'dart:async';
import '../core/state.dart';

/// The three states of a circuit breaker.
enum BulwarkState {
  /// Normal operation — requests pass through.
  closed,

  /// Circuit tripped — requests fail immediately with [BulwarkOpenException].
  open,

  /// Recovery testing — one request allowed through.
  halfOpen,
}

/// A reactive circuit breaker.
///
/// Wraps async operations and tracks failures. When failures exceed
/// [failureThreshold], the circuit opens and rejects further calls
/// immediately. After [resetTimeout], one probe request is allowed
/// through (half-open state). On success the circuit closes; on
/// failure it reopens.
///
/// All state fields (`state`, `failureCount`, `lastFailure`) are
/// reactive [Core]s, so [Vestige] widgets and [watch]ers automatically
/// respond to circuit changes.
///
/// ```dart
/// final breaker = Bulwark<Response>(
///   failureThreshold: 3,
///   resetTimeout: Duration(seconds: 30),
/// );
///
/// try {
///   final data = await breaker.call(() => api.fetchData());
/// } on BulwarkOpenException {
///   showError('Service unavailable, try later');
/// }
/// ```
class Bulwark<T> {
  /// Reactive circuit state.
  final TitanState<BulwarkState> _state;

  /// Reactive failure count.
  final TitanState<int> _failureCount;

  /// Reactive last failure timestamp.
  final TitanState<DateTime?> _lastFailureTime;

  /// Reactive last error.
  final TitanState<Object?> _lastError;

  /// Number of consecutive failures before the circuit opens.
  final int failureThreshold;

  /// Duration after which an open circuit transitions to half-open.
  final Duration resetTimeout;

  /// Optional callback when the circuit opens.
  final void Function(Object error)? onOpen;

  /// Optional callback when the circuit closes (recovery).
  final void Function()? onClose;

  /// Optional callback when the circuit moves to half-open.
  final void Function()? onHalfOpen;

  /// Timer for auto-transitioning from open to half-open.
  Timer? _resetTimer;

  /// Creates a circuit breaker.
  ///
  /// - [failureThreshold] — Consecutive failures before opening (default: 3).
  /// - [resetTimeout] — Duration before retrying (default: 30s).
  /// - [onOpen] — Called when circuit opens.
  /// - [onClose] — Called when circuit recovers.
  /// - [onHalfOpen] — Called when circuit starts recovery probe.
  /// - [name] — Debug name prefix for internal Cores.
  Bulwark({
    this.failureThreshold = 3,
    this.resetTimeout = const Duration(seconds: 30),
    this.onOpen,
    this.onClose,
    this.onHalfOpen,
    String? name,
  }) : _state = TitanState<BulwarkState>(
         BulwarkState.closed,
         name: name != null ? '${name}_state' : null,
       ),
       _failureCount = TitanState<int>(
         0,
         name: name != null ? '${name}_failures' : null,
       ),
       _lastFailureTime = TitanState<DateTime?>(
         null,
         name: name != null ? '${name}_lastFailureTime' : null,
       ),
       _lastError = TitanState<Object?>(
         null,
         name: name != null ? '${name}_lastError' : null,
       );

  /// The current circuit state (reactive).
  BulwarkState get state => _state.value;

  /// The underlying reactive state Core.
  TitanState<BulwarkState> get stateCore => _state;

  /// Current consecutive failure count (reactive).
  int get failureCount => _failureCount.value;

  /// The underlying failure count Core.
  TitanState<int> get failureCountCore => _failureCount;

  /// The last failure timestamp (reactive).
  DateTime? get lastFailureTime => _lastFailureTime.value;

  /// The last error that caused a failure (reactive).
  Object? get lastError => _lastError.value;

  /// Whether the circuit is currently closed (normal operation).
  bool get isClosed => _state.peek() == BulwarkState.closed;

  /// Whether the circuit is currently open (rejecting calls).
  bool get isOpen => _state.peek() == BulwarkState.open;

  /// Whether the circuit is in the half-open recovery state.
  bool get isHalfOpen => _state.peek() == BulwarkState.halfOpen;

  /// Execute an async operation through the circuit breaker.
  ///
  /// - **Closed**: Executes normally. On failure, increments failure count.
  ///   If threshold is reached, opens the circuit.
  /// - **Open**: Throws [BulwarkOpenException] immediately.
  /// - **Half-Open**: Allows one probe request. On success, closes circuit.
  ///   On failure, reopens circuit.
  ///
  /// ```dart
  /// try {
  ///   final result = await breaker.call(() => api.getData());
  ///   print(result);
  /// } on BulwarkOpenException {
  ///   print('Circuit is open — service unavailable');
  /// }
  /// ```
  Future<T> call(Future<T> Function() action) async {
    final currentState = _state.peek();

    switch (currentState) {
      case BulwarkState.closed:
        return _executeClosed(action);
      case BulwarkState.open:
        throw BulwarkOpenException(
          failureCount: _failureCount.peek(),
          lastError: _lastError.peek(),
        );
      case BulwarkState.halfOpen:
        return _executeHalfOpen(action);
    }
  }

  Future<T> _executeClosed(Future<T> Function() action) async {
    try {
      final result = await action();
      // Success — reset failure count
      _failureCount.value = 0;
      return result;
    } catch (e) {
      _recordFailure(e);
      if (_failureCount.peek() >= failureThreshold) {
        _open(e);
      }
      rethrow;
    }
  }

  Future<T> _executeHalfOpen(Future<T> Function() action) async {
    try {
      final result = await action();
      // Success — close circuit
      _close();
      return result;
    } catch (e) {
      _recordFailure(e);
      _open(e);
      rethrow;
    }
  }

  void _recordFailure(Object error) {
    _failureCount.value = _failureCount.peek() + 1;
    _lastFailureTime.value = DateTime.now();
    _lastError.value = error;
  }

  void _open(Object error) {
    _state.value = BulwarkState.open;
    onOpen?.call(error);

    // Schedule transition to half-open
    _resetTimer?.cancel();
    _resetTimer = Timer(resetTimeout, () {
      if (_state.peek() == BulwarkState.open) {
        _state.value = BulwarkState.halfOpen;
        onHalfOpen?.call();
      }
    });
  }

  void _close() {
    _resetTimer?.cancel();
    _failureCount.value = 0;
    _lastError.value = null;
    _state.value = BulwarkState.closed;
    onClose?.call();
  }

  /// Manually reset the circuit breaker to closed state.
  ///
  /// Clears failure count and timers.
  void reset() {
    _resetTimer?.cancel();
    _failureCount.value = 0;
    _lastError.value = null;
    _lastFailureTime.value = null;
    _state.value = BulwarkState.closed;
  }

  /// Manually trip the circuit to open state.
  ///
  /// Useful for testing or emergency shutoffs.
  void trip([Object? error]) {
    _open(error ?? StateError('Manually tripped'));
  }

  /// Dispose timers. Call this when the Bulwark is no longer needed.
  void dispose() {
    _resetTimer?.cancel();
    _state.dispose();
    _failureCount.dispose();
    _lastFailureTime.dispose();
    _lastError.dispose();
  }

  /// All managed reactive nodes (for Pillar disposal).
  List<TitanState<dynamic>> get managedNodes => [
    _state,
    _failureCount,
    _lastFailureTime,
    _lastError,
  ];

  @override
  String toString() {
    return 'Bulwark<$T>(${_state.peek()}, '
        'failures: ${_failureCount.peek()})';
  }
}

/// Exception thrown when a call is attempted on an open circuit breaker.
///
/// Indicates the target service is considered unavailable. The circuit
/// will automatically transition to half-open after the reset timeout.
class BulwarkOpenException implements Exception {
  /// The number of consecutive failures that triggered the circuit.
  final int failureCount;

  /// The last error that caused the circuit to open.
  final Object? lastError;

  /// Creates a circuit open exception.
  const BulwarkOpenException({required this.failureCount, this.lastError});

  @override
  String toString() =>
      'BulwarkOpenException: Circuit is open after $failureCount '
      'consecutive failures. Last error: $lastError';
}
