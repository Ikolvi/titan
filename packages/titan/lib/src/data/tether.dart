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
/// // Provider Pillar registers a tether
/// class AuthPillar extends Pillar {
///   @override
///   void onInit() {
///     Tether.register<String, User>('getUser', (userId) async {
///       return await fetchUser(userId);
///     });
///   }
/// }
///
/// // Consumer Pillar calls the tether
/// class ProfilePillar extends Pillar {
///   Future<void> loadProfile(String userId) async {
///     final user = await Tether.call<String, User>('getUser', userId);
///     profile.value = user;
///   }
/// }
/// ```
library;

import 'dart:async';

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
/// ```dart
/// // Register
/// Tether.register<String, int>('getAge', (name) async {
///   return await lookupAge(name);
/// });
///
/// // Call
/// final age = await Tether.call<String, int>('getAge', 'Alice');
/// ```
class Tether {
  Tether._();

  /// Internal registry of tether handlers.
  static final Map<String, _TetherEntry> _handlers = {};

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Register a typed request-response handler.
  ///
  /// Only one handler can be registered per [name]. Registering again
  /// replaces the previous handler.
  ///
  /// - [name] — Unique identifier for this tether.
  /// - [handler] — Async function that processes the request and returns a response.
  /// - [timeout] — Optional per-tether timeout for calls.
  ///
  /// ```dart
  /// Tether.register<String, User>('getUser', (userId) async {
  ///   return await userRepository.find(userId);
  /// });
  /// ```
  static void register<Req, Res>(
    String name,
    Future<Res> Function(Req request) handler, {
    Duration? timeout,
  }) {
    _handlers[name] = _TetherEntry(handler: handler, timeout: timeout);
  }

  /// Unregister a tether handler.
  ///
  /// Returns `true` if the handler existed and was removed.
  static bool unregister(String name) {
    return _handlers.remove(name) != null;
  }

  /// Whether a tether with the given name is registered.
  static bool has(String name) => _handlers.containsKey(name);

  /// The names of all registered tethers.
  static Set<String> get names => Set.unmodifiable(_handlers.keys.toSet());

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
  /// final user = await Tether.call<String, User>('getUser', 'user_123');
  /// ```
  static Future<Res> call<Req, Res>(
    String name,
    Req request, {
    Duration? timeout,
  }) async {
    final entry = _handlers[name];
    if (entry == null) {
      throw StateError('Tether "$name" is not registered.');
    }

    final handler = entry.handler as Future<Res> Function(Req);
    final effectiveTimeout = timeout ?? entry.timeout;

    if (effectiveTimeout != null) {
      return await handler(request).timeout(
        effectiveTimeout,
        onTimeout: () => throw TimeoutException(
          'Tether "$name" timed out after ${effectiveTimeout.inMilliseconds}ms',
          effectiveTimeout,
        ),
      );
    }

    return await handler(request);
  }

  /// Try to call a tether, returning null if not registered.
  ///
  /// Unlike [call], this does not throw if the tether is not registered.
  /// Still throws on handler errors or timeouts.
  ///
  /// ```dart
  /// final user = await Tether.tryCall<String, User>('getUser', 'user_123');
  /// if (user != null) { /* use user */ }
  /// ```
  static Future<Res?> tryCall<Req, Res>(
    String name,
    Req request, {
    Duration? timeout,
  }) async {
    if (!has(name)) return null;
    return await call<Req, Res>(name, request, timeout: timeout);
  }

  // ---------------------------------------------------------------------------
  // Management
  // ---------------------------------------------------------------------------

  /// Clear all registered tethers.
  ///
  /// Call in test teardown or app shutdown.
  static void reset() {
    _handlers.clear();
  }
}
