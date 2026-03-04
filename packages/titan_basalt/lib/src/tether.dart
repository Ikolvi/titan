/// Tether — Typed request-response channels between Pillars.
///
/// Tether enables structured, typed communication between Pillars
/// beyond Herald's fire-and-forget events. A Pillar exposes a Tether
/// that other Pillars can invoke to request data and `await` a response.
///
/// ## Why "Tether"?
///
/// A tether connects two points with a strong link. Titan's Tether
/// provides typed, bidirectional communication between Pillars without
/// tight coupling.
///
/// ## Usage
///
/// ```dart
/// // Instance-based with Pillar integration
/// class AuthPillar extends Pillar {
///   late final rpc = tether(name: 'auth');
///
///   @override
///   void onInit() {
///     rpc.register<String, User>('getUser', (userId) async {
///       return await fetchUser(userId);
///     });
///   }
/// }
///
/// // Consumer Pillar calls the tether
/// class ProfilePillar extends Pillar {
///   Future<void> loadProfile(String userId) async {
///     final user = await Tether.global.call<String, User>('getUser', userId);
///     profile.value = user;
///   }
/// }
/// ```
///
/// ## Static convenience API
///
/// The static methods on [Tether] delegate to [Tether.global] for
/// backward compatibility:
///
/// ```dart
/// Tether.registerGlobal<String, User>('getUser', handler);
/// final user = await Tether.callGlobal<String, User>('getUser', 'id');
/// ```
library;

import 'dart:async';

import 'package:titan/titan.dart';

/// A registered tether handler entry.
class _TetherEntry {
  final Function handler;
  final Duration? timeout;

  const _TetherEntry({required this.handler, this.timeout});
}

/// Typed request-response channel registry for Pillar inter-communication.
///
/// Tether provides a decoupled way for Pillars to communicate via
/// named, typed channels. One Pillar registers a handler, and other
/// Pillars invoke it by name.
///
/// Supports both instance-based (with reactive state and Pillar
/// integration) and static global usage.
///
/// ```dart
/// // Instance-based (preferred)
/// final rpc = Tether(name: 'myService');
/// rpc.register<String, int>('getAge', (name) async => lookupAge(name));
/// final age = await rpc.call<String, int>('getAge', 'Alice');
///
/// // Static global (convenience)
/// Tether.registerGlobal<String, int>('getAge', (n) async => lookupAge(n));
/// final age = await Tether.callGlobal<String, int>('getAge', 'Alice');
/// ```
class Tether {
  /// The global shared Tether instance.
  ///
  /// Use for simple cross-Pillar communication without instance management.
  static final Tether global = Tether._internal(name: 'global');

  /// Internal registry of tether handlers.
  final Map<String, _TetherEntry> _handlers = {};

  // Reactive state
  final TitanState<int> _registeredCount;
  final TitanState<int> _errorCount;

  /// Plain call counter (non-reactive for hot-path performance).
  int _callCount = 0;

  /// Last call timestamp (computed lazily to avoid DateTime.now() overhead).
  DateTime? _lastCallTime;
  bool _lastCallTimeDirty = false;

  final String? _name;
  bool _isDisposed = false;

  /// Creates a new Tether instance with reactive state.
  ///
  /// - [name] — Debug name prefix for internal Cores.
  ///
  /// ```dart
  /// final rpc = Tether(name: 'authRpc');
  /// rpc.register<String, User>('getUser', handler);
  /// ```
  Tether({String? name}) : this._internal(name: name);

  Tether._internal({String? name})
    : _name = name,
      _registeredCount = TitanState<int>(
        0,
        name: '${name ?? 'tether'}_registeredCount',
      ),
      _errorCount = TitanState<int>(0, name: '${name ?? 'tether'}_errorCount');

  // ---------------------------------------------------------------------------
  // Reactive state
  // ---------------------------------------------------------------------------

  /// Number of registered handlers (reactive).
  int get registeredCount => _registeredCount.value;

  /// Total number of calls made.
  int get callCount => _callCount;

  /// Timestamp of the last call.
  ///
  /// Computed lazily on first access after a call to avoid
  /// `DateTime.now()` overhead on the hot path.
  DateTime? get lastCallTime {
    if (_lastCallTimeDirty) {
      _lastCallTime = DateTime.now();
      _lastCallTimeDirty = false;
    }
    return _lastCallTime;
  }

  /// Total number of errors during calls (reactive).
  int get errorCount => _errorCount.value;

  /// Whether this Tether has been disposed.
  bool get isDisposed => _isDisposed;

  /// Debug name.
  String? get name => _name;

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Register a typed request-response handler.
  ///
  /// Only one handler can be registered per [name]. Registering again
  /// replaces the previous handler.
  ///
  /// - [name] — Unique identifier for this tether.
  /// - [handler] — Async function that processes the request and returns
  ///   a response.
  /// - [timeout] — Optional per-tether timeout for calls.
  ///
  /// ```dart
  /// tether.register<String, User>('getUser', (userId) async {
  ///   return await userRepository.find(userId);
  /// });
  /// ```
  void register<Req, Res>(
    String name,
    Future<Res> Function(Req request) handler, {
    Duration? timeout,
  }) {
    _assertNotDisposed();
    final isNew = !_handlers.containsKey(name);
    _handlers[name] = _TetherEntry(handler: handler, timeout: timeout);
    if (isNew) {
      _registeredCount.value = _handlers.length;
    }
  }

  /// Unregister a tether handler.
  ///
  /// Returns `true` if the handler existed and was removed.
  bool unregister(String name) {
    _assertNotDisposed();
    final removed = _handlers.remove(name) != null;
    if (removed) {
      _registeredCount.value = _handlers.length;
    }
    return removed;
  }

  /// Whether a tether with the given name is registered.
  bool has(String name) => _handlers.containsKey(name);

  /// The names of all registered tethers.
  Set<String> get names => Set.unmodifiable(_handlers.keys.toSet());

  // ---------------------------------------------------------------------------
  // Invocation
  // ---------------------------------------------------------------------------

  /// Call a registered tether and await its response.
  ///
  /// Throws [StateError] if no handler is registered for [name].
  /// Throws [TimeoutException] if the handler exceeds its timeout.
  ///
  /// - [name] — The tether name to invoke.
  /// - [request] — The request payload.
  /// - [timeout] — Override the tether's default timeout.
  ///
  /// ```dart
  /// final user = await tether.call<String, User>('getUser', 'user_123');
  /// ```
  Future<Res> call<Req, Res>(String name, Req request, {Duration? timeout}) {
    _assertNotDisposed();
    final entry = _handlers[name];
    if (entry == null) {
      throw StateError('Tether "$name" is not registered.');
    }

    final handler = entry.handler as Future<Res> Function(Req);
    final effectiveTimeout = timeout ?? entry.timeout;

    _callCount++;
    _lastCallTimeDirty = true;

    if (effectiveTimeout != null) {
      return handler(request)
          .timeout(
            effectiveTimeout,
            onTimeout: () => throw TimeoutException(
              'Tether "$name" timed out after '
              '${effectiveTimeout.inMilliseconds}ms',
              effectiveTimeout,
            ),
          )
          .onError<Object>((e, s) {
            _errorCount.value++;
            // ignore: only_throw_errors
            throw e;
          });
    }
    return handler(request).onError<Object>((e, s) {
      _errorCount.value++;
      // ignore: only_throw_errors
      throw e;
    });
  }

  /// Try to call a tether, returning null if not registered.
  ///
  /// Unlike [call], this does not throw if the tether is not registered.
  /// Still throws on handler errors or timeouts.
  ///
  /// ```dart
  /// final user = await tether.tryCall<String, User>('getUser', 'user_123');
  /// if (user != null) { /* use user */ }
  /// ```
  Future<Res?> tryCall<Req, Res>(
    String name,
    Req request, {
    Duration? timeout,
  }) {
    if (!has(name)) return Future.value();
    return call<Req, Res>(name, request, timeout: timeout);
  }

  // ---------------------------------------------------------------------------
  // Management
  // ---------------------------------------------------------------------------

  /// Clear all registered tethers and reset reactive state.
  void reset() {
    _handlers.clear();
    _registeredCount.value = 0;
    _callCount = 0;
    _lastCallTime = null;
    _lastCallTimeDirty = false;
    _errorCount.value = 0;
  }

  /// All managed reactive nodes (for Pillar disposal).
  List<TitanState<dynamic>> get managedNodes => [_registeredCount, _errorCount];

  /// Dispose the Tether and all reactive state.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _handlers.clear();
    _registeredCount.dispose();
    _errorCount.dispose();
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError(
        'Cannot use a disposed Tether${_name != null ? ' ($_name)' : ''}',
      );
    }
  }

  @override
  String toString() =>
      'Tether(${_name ?? 'unnamed'}, '
      'handlers: ${_handlers.length}, '
      'calls: $_callCount, '
      'errors: ${_errorCount.peek()})';

  // ---------------------------------------------------------------------------
  // Static convenience API — delegates to Tether.global
  // ---------------------------------------------------------------------------

  /// Register a handler on the global Tether.
  ///
  /// Convenience for `Tether.global.register(...)`.
  static void registerGlobal<Req, Res>(
    String name,
    Future<Res> Function(Req request) handler, {
    Duration? timeout,
  }) {
    global.register<Req, Res>(name, handler, timeout: timeout);
  }

  /// Unregister a handler from the global Tether.
  static bool unregisterGlobal(String name) => global.unregister(name);

  /// Whether the global Tether has a handler for [name].
  static bool hasGlobal(String name) => global.has(name);

  /// All registered names on the global Tether.
  static Set<String> get globalNames => global.names;

  /// Call a handler on the global Tether.
  static Future<Res> callGlobal<Req, Res>(
    String name,
    Req request, {
    Duration? timeout,
  }) {
    return global.call<Req, Res>(name, request, timeout: timeout);
  }

  /// Try to call a handler on the global Tether.
  static Future<Res?> tryCallGlobal<Req, Res>(
    String name,
    Req request, {
    Duration? timeout,
  }) {
    return global.tryCall<Req, Res>(name, request, timeout: timeout);
  }

  /// Reset the global Tether (clear all handlers).
  static void resetGlobal() => global.reset();
}
