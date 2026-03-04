/// Moat — Reactive token-bucket rate limiter with per-key quotas.
///
/// A Moat controls the rate of operations using a token-bucket algorithm.
/// Tokens are consumed on each request and replenished at a fixed rate.
/// When no tokens remain, requests are rejected (or optionally queued).
/// All quota state is reactive, making remaining tokens and rejection
/// counts visible in the UI.
///
/// ## Why "Moat"?
///
/// A moat is a defensive barrier controlling access to a fortification.
/// Titan's Moat controls the flow of operations, preventing resource
/// abuse and protecting your services from being overwhelmed.
///
/// ## Usage
///
/// ```dart
/// class ApiPillar extends Pillar {
///   late final apiLimiter = moat(
///     maxTokens: 10,
///     refillRate: Duration(seconds: 1),
///     name: 'api',
///   );
///
///   Future<void> fetchData() async {
///     if (apiLimiter.tryConsume()) {
///       await api.getData();
///     } else {
///       log.warn('Rate limited! Retry in ${apiLimiter.timeToNextToken}');
///     }
///   }
/// }
/// ```
///
/// ## Features
///
/// - **Token bucket** — configurable capacity with timed replenishment
/// - **Per-key limiting** — independent quotas via `MoatPool`
/// - **Reactive state** — `remainingTokens`, `rejections` are live Cores
/// - **Burst support** — configurable initial burst capacity
/// - **Auto-refill** — tokens replenish at a steady rate
/// - **Cost-based** — operations can consume multiple tokens
/// - **Pillar integration** — `moat()` factory with auto-disposal
///
/// ## Per-Key Rate Limiting
///
/// ```dart
/// // Each API endpoint gets its own rate limit
/// final pool = MoatPool(
///   maxTokens: 5,
///   refillRate: Duration(seconds: 1),
/// );
///
/// pool.tryConsume('users-endpoint');   // uses 'users-endpoint' bucket
/// pool.tryConsume('search-endpoint');  // uses 'search-endpoint' bucket
/// ```
library;

import 'dart:async';

import 'package:titan/titan.dart';

/// A reactive token-bucket rate limiter.
///
/// Controls operation throughput by maintaining a bucket of tokens.
/// Each operation consumes one or more tokens. Tokens replenish at
/// a fixed rate. When the bucket is empty, operations are rejected.
///
/// All state is reactive — [remainingTokens] and [rejections] are
/// [Core]s that trigger UI rebuilds automatically.
///
/// ```dart
/// final limiter = Moat(maxTokens: 10, refillRate: Duration(seconds: 1));
///
/// if (limiter.tryConsume()) {
///   // Allowed — proceed
/// } else {
///   // Rate limited — wait or show message
/// }
/// ```
class Moat {
  /// Maximum tokens the bucket can hold.
  final int maxTokens;

  /// How often one token is added to the bucket.
  final Duration refillRate;

  /// Called when a request is rejected due to rate limiting.
  final void Function()? onReject;

  /// Internal refill timer.
  Timer? _refillTimer;

  /// Timestamp of last refill for fractional token tracking.
  DateTime _lastRefill;

  /// Internal fractional token accumulator for sub-second precision.
  double _fractionalTokens;

  /// Pending token waiters (Completer-based, no polling).
  final List<_MoatWaiter> _waiters = [];

  // ---------------------------------------------------------------------------
  // Reactive state
  // ---------------------------------------------------------------------------

  /// Current number of available tokens (reactive).
  final TitanState<int> _remaining;

  /// Total number of rejected requests (reactive).
  final TitanState<int> _rejections;

  /// Total number of consumed tokens (reactive).
  final TitanState<int> _consumed;

  /// Creates a rate limiter.
  ///
  /// - [maxTokens] — Maximum bucket capacity (default: 10).
  /// - [refillRate] — Duration per token refill (default: 1 second).
  /// - [initialTokens] — Starting token count (default: same as [maxTokens]).
  /// - [onReject] — Called when a request is rejected.
  /// - [name] — Debug name prefix for internal Cores.
  ///
  /// ```dart
  /// final limiter = Moat(
  ///   maxTokens: 60,
  ///   refillRate: Duration(seconds: 1),
  ///   name: 'api',
  /// );
  /// ```
  Moat({
    this.maxTokens = 10,
    this.refillRate = const Duration(seconds: 1),
    int? initialTokens,
    this.onReject,
    String? name,
  }) : _lastRefill = DateTime.now(),
       _fractionalTokens = 0.0,
       _remaining = TitanState<int>(
         initialTokens ?? maxTokens,
         name: '${name ?? 'moat'}_remaining',
       ),
       _rejections = TitanState<int>(0, name: '${name ?? 'moat'}_rejections'),
       _consumed = TitanState<int>(0, name: '${name ?? 'moat'}_consumed') {
    if (maxTokens <= 0) {
      throw ArgumentError.value(maxTokens, 'maxTokens', 'must be positive');
    }
    _startRefillTimer();
  }

  // ---------------------------------------------------------------------------
  // Reactive getters
  // ---------------------------------------------------------------------------

  /// Current number of available tokens (reactive Core).
  TitanState<int> get remainingTokens => _remaining;

  /// Total number of rejected requests (reactive Core).
  TitanState<int> get rejections => _rejections;

  /// Total number of consumed tokens (reactive Core).
  TitanState<int> get consumed => _consumed;

  /// Whether the bucket has tokens available.
  bool get hasTokens => _remaining.value > 0;

  /// Whether the bucket is empty.
  bool get isEmpty => _remaining.value <= 0;

  /// Percentage of bucket filled (0.0–100.0).
  double get fillPercentage => (_remaining.value / maxTokens) * 100.0;

  /// Estimated duration until the next token is available.
  ///
  /// Returns [Duration.zero] if tokens are available.
  Duration get timeToNextToken {
    if (hasTokens) return Duration.zero;
    return refillRate;
  }

  /// All managed reactive nodes (for Pillar disposal).
  List<TitanState<dynamic>> get managedNodes => [
    _remaining,
    _rejections,
    _consumed,
  ];

  // ---------------------------------------------------------------------------
  // Core operations
  // ---------------------------------------------------------------------------

  /// Try to consume one token. Returns `true` if allowed, `false` if rejected.
  ///
  /// ```dart
  /// if (limiter.tryConsume()) {
  ///   await performAction();
  /// }
  /// ```
  bool tryConsume([int tokens = 1]) {
    if (tokens <= 0) {
      throw ArgumentError.value(tokens, 'tokens', 'must be positive');
    }
    _refillTokens();
    if (_remaining.value >= tokens) {
      _remaining.value -= tokens;
      _consumed.value += tokens;
      return true;
    }
    _rejections.value++;
    onReject?.call();
    return false;
  }

  /// Consume a token, waiting if necessary until one is available.
  ///
  /// This will wait for tokens to replenish before proceeding.
  /// Use [timeout] to limit how long to wait.
  ///
  /// ```dart
  /// await limiter.consume(); // waits if bucket is empty
  /// await performAction();
  /// ```
  Future<bool> consume({int tokens = 1, Duration? timeout}) async {
    if (tokens <= 0) {
      throw ArgumentError.value(tokens, 'tokens', 'must be positive');
    }
    if (tryConsume(tokens)) return true;

    final completer = Completer<bool>();
    Timer? timer;
    final waiter = _MoatWaiter(tokens: tokens, completer: completer);
    _waiters.add(waiter);

    if (timeout != null) {
      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          _waiters.remove(waiter);
          _rejections.value++;
          onReject?.call();
          completer.complete(false);
        }
      });
    }

    final result = await completer.future;
    timer?.cancel();
    return result;
  }

  /// Execute an action if a token is available, otherwise call [onLimit].
  ///
  /// Returns the action's result, or `null` if rate limited.
  ///
  /// ```dart
  /// final result = await limiter.guard(
  ///   () async => await api.fetchData(),
  ///   onLimit: () => showSnackBar('Too many requests'),
  /// );
  /// ```
  Future<T?> guard<T>(
    Future<T> Function() action, {
    void Function()? onLimit,
    int tokens = 1,
  }) async {
    if (tryConsume(tokens)) {
      return action();
    }
    onLimit?.call();
    return null;
  }

  /// Reset the bucket to full capacity and clear statistics.
  void reset() {
    _remaining.value = maxTokens;
    _rejections.value = 0;
    _consumed.value = 0;
    _lastRefill = DateTime.now();
    _fractionalTokens = 0.0;
  }

  /// Dispose the rate limiter, cancelling the refill timer.
  void dispose() {
    _refillTimer?.cancel();
    _refillTimer = null;
    // Reject all pending waiters.
    for (final waiter in _waiters) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.complete(false);
      }
    }
    _waiters.clear();
    _remaining.dispose();
    _rejections.dispose();
    _consumed.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Start the periodic refill timer.
  void _startRefillTimer() {
    // Refill on a granular timer (min 10ms, max refillRate)
    final interval = refillRate.inMilliseconds > 100
        ? const Duration(milliseconds: 100)
        : refillRate;
    _refillTimer = Timer.periodic(interval, (_) => _refillTokens());
  }

  /// Refill tokens based on elapsed time.
  void _refillTokens() {
    if (_remaining.value >= maxTokens) {
      _lastRefill = DateTime.now();
      _fractionalTokens = 0.0;
      _fulfillWaiters();
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill);
    final tokensToAdd =
        elapsed.inMicroseconds / refillRate.inMicroseconds + _fractionalTokens;
    final wholeTokens = tokensToAdd.floor();

    if (wholeTokens > 0) {
      final newValue = _remaining.value + wholeTokens;
      _remaining.value = newValue > maxTokens ? maxTokens : newValue;
      _lastRefill = now;
      _fractionalTokens = tokensToAdd - wholeTokens;
      _fulfillWaiters();
    }
  }

  /// Attempt to fulfill pending waiters with available tokens.
  void _fulfillWaiters() {
    if (_waiters.isEmpty) return;

    final fulfilled = <_MoatWaiter>[];
    for (final waiter in _waiters) {
      if (waiter.completer.isCompleted) {
        fulfilled.add(waiter);
        continue;
      }
      if (_remaining.value >= waiter.tokens) {
        _remaining.value -= waiter.tokens;
        _consumed.value += waiter.tokens;
        waiter.completer.complete(true);
        fulfilled.add(waiter);
      }
    }
    for (final w in fulfilled) {
      _waiters.remove(w);
    }
  }

  @override
  String toString() =>
      'Moat(remaining: ${_remaining.value}/$maxTokens, '
      'consumed: ${_consumed.value}, rejected: ${_rejections.value})';
}

/// A pool of per-key rate limiters sharing the same configuration.
///
/// Creates independent [Moat] instances per key, lazily, with shared
/// configuration. Useful for per-endpoint, per-user, or per-resource
/// rate limiting.
///
/// ```dart
/// final pool = MoatPool(
///   maxTokens: 5,
///   refillRate: Duration(seconds: 1),
/// );
///
/// // Each key gets its own independent bucket
/// pool.tryConsume('search');      // search bucket
/// pool.tryConsume('users');       // users bucket
/// pool.tryConsume('search');      // search bucket (same)
/// ```
class MoatPool {
  /// Maximum tokens per bucket.
  final int maxTokens;

  /// Refill rate per bucket.
  final Duration refillRate;

  /// Called with the key when a request is rejected.
  final void Function(String key)? onReject;

  /// Active limiters by key.
  final Map<String, Moat> _limiters = {};

  /// Creates a pool of rate limiters.
  ///
  /// - [maxTokens] — Max tokens per bucket (default: 10).
  /// - [refillRate] — Duration per token refill (default: 1 second).
  /// - [onReject] — Called with the key when a request is rejected.
  ///
  /// ```dart
  /// final pool = MoatPool(maxTokens: 30, refillRate: Duration(seconds: 1));
  /// ```
  MoatPool({
    this.maxTokens = 10,
    this.refillRate = const Duration(seconds: 1),
    this.onReject,
  });

  /// Try to consume a token for the given key.
  ///
  /// Creates a new [Moat] for the key if it doesn't exist.
  bool tryConsume(String key, [int tokens = 1]) {
    final limiter = _limiters.putIfAbsent(
      key,
      () => Moat(
        maxTokens: maxTokens,
        refillRate: refillRate,
        onReject: onReject != null ? () => onReject!(key) : null,
        name: 'pool_$key',
      ),
    );
    return limiter.tryConsume(tokens);
  }

  /// Get the limiter for a specific key (creates if absent).
  Moat operator [](String key) {
    return _limiters.putIfAbsent(
      key,
      () => Moat(
        maxTokens: maxTokens,
        refillRate: refillRate,
        onReject: onReject != null ? () => onReject!(key) : null,
        name: 'pool_$key',
      ),
    );
  }

  /// All active key names.
  Iterable<String> get keys => _limiters.keys;

  /// Number of active limiters.
  int get activeCount => _limiters.length;

  /// Remove a specific key's limiter.
  void remove(String key) {
    _limiters.remove(key)?.dispose();
  }

  /// Reset all limiters to full capacity.
  void resetAll() {
    for (final limiter in _limiters.values) {
      limiter.reset();
    }
  }

  /// Dispose all limiters.
  void dispose() {
    for (final limiter in _limiters.values) {
      limiter.dispose();
    }
    _limiters.clear();
  }
}

/// Internal waiter record for Completer-based token consumption.
class _MoatWaiter {
  final int tokens;
  final Completer<bool> completer;

  const _MoatWaiter({required this.tokens, required this.completer});
}
