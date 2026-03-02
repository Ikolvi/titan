import 'dart:async';

/// A wrapper for globally-captured Herald events.
///
/// Used by [Herald.allEvents] to provide both the event type and payload
/// in a single object.
class HeraldEvent {
  /// The Dart [Type] of the event.
  final Type type;

  /// The event payload.
  final dynamic payload;

  /// When the event was emitted.
  final DateTime timestamp;

  /// Creates a [HeraldEvent].
  HeraldEvent(this.type, this.payload) : timestamp = DateTime.now();

  @override
  String toString() => 'HeraldEvent($type, $payload)';
}

/// **Herald** — The Titan Event Bus.
///
/// Carries messages between domains — cross-Pillar communication
/// without direct coupling.
///
/// Herald enables type-safe, fire-and-forget event broadcasting
/// across your entire application. Any Pillar (or service) can
/// emit events, and any other Pillar can listen — no imports,
/// no references, no tight coupling.
///
/// ## Quick Start
///
/// ```dart
/// // 1. Define your events (plain Dart classes)
/// class UserLoggedIn {
///   final String userId;
///   UserLoggedIn(this.userId);
/// }
///
/// class CartCleared {}
///
/// // 2. Listen for events
/// Herald.on<UserLoggedIn>((event) {
///   print('User ${event.userId} logged in');
/// });
///
/// // 3. Emit events
/// Herald.emit(UserLoggedIn('user_123'));
/// ```
///
/// ## Inside a Pillar
///
/// Pillars have managed [listen] and [emit] helpers that auto-dispose
/// subscriptions when the Pillar is disposed:
///
/// ```dart
/// class CartPillar extends Pillar {
///   late final items = core<List<CartItem>>([]);
///
///   @override
///   void onInit() {
///     // Auto-disposed when CartPillar is disposed
///     listen<UserLoggedOut>((_) {
///       strike(() => items.value = []);
///     });
///   }
///
///   void checkout() {
///     processOrder(items.value);
///     emit(OrderPlaced(items: items.value));
///     strike(() => items.value = []);
///   }
/// }
/// ```
///
/// ## Features
///
/// - **Type-safe** — Events are dispatched and received by their Dart type
/// - **Decoupled** — No direct references between Pillars
/// - **Managed lifecycle** — Pillar subscriptions auto-dispose
/// - **Replay** — Optionally access the last emitted event of any type
/// - **Stream-based** — Get a `Stream<T>` for advanced composition
abstract final class Herald {
  static final Map<Type, StreamController<dynamic>> _controllers = {};
  static final Map<Type, dynamic> _lastEvents = {};
  static StreamController<HeraldEvent>? _globalController;

  /// Maximum number of event types to cache in `_lastEvents`.
  /// Set to 0 to disable last-event caching entirely.
  /// Defaults to 100.
  static int maxLastEventTypes = 100;

  // ---------------------------------------------------------------------------
  // Emit
  // ---------------------------------------------------------------------------

  /// Emit an event to all listeners of type [T].
  ///
  /// The event is delivered synchronously to all current listeners.
  /// If no listeners are registered for type [T], the event is stored
  /// as the last event but otherwise silently dropped.
  ///
  /// ```dart
  /// Herald.emit(UserLoggedIn(userId: 'abc'));
  /// Herald.emit(CartCleared());
  /// ```
  static void emit<T>(T event) {
    if (maxLastEventTypes > 0) {
      _lastEvents[T] = event;
      // Evict oldest entries if over the cap
      while (_lastEvents.length > maxLastEventTypes) {
        _lastEvents.remove(_lastEvents.keys.first);
      }
    }

    // Notify global listeners (used by Lens debug overlay).
    if (_globalController != null &&
        !_globalController!.isClosed &&
        _globalController!.hasListener) {
      _globalController!.add(HeraldEvent(T, event));
    }

    final controller = _controllers[T];
    if (controller != null && !controller.isClosed && controller.hasListener) {
      controller.add(event);
    }
  }

  // ---------------------------------------------------------------------------
  // Listen
  // ---------------------------------------------------------------------------

  /// Listen for events of type [T].
  ///
  /// Returns a [StreamSubscription] that can be cancelled manually
  /// or automatically via [Pillar.listen].
  ///
  /// ```dart
  /// final sub = Herald.on<UserLoggedIn>((event) {
  ///   print('Welcome, ${event.userId}');
  /// });
  ///
  /// // Later, to stop listening:
  /// sub.cancel();
  /// ```
  static StreamSubscription<T> on<T>(void Function(T event) handler) {
    return _ensureController<T>().stream.listen(handler);
  }

  /// Listen for exactly one event of type [T], then auto-cancel.
  ///
  /// ```dart
  /// Herald.once<AppReady>((event) {
  ///   performOneTimeSetup();
  /// });
  /// ```
  static StreamSubscription<T> once<T>(void Function(T event) handler) {
    late final StreamSubscription<T> subscription;
    subscription = _ensureController<T>().stream.listen((event) {
      handler(event);
      subscription.cancel();
    });
    return subscription;
  }

  /// Listen for events of type [T] that match a [filter].
  ///
  /// Only events for which [filter] returns `true` are delivered to
  /// the [handler]. Returns a cancellable subscription.
  ///
  /// ```dart
  /// Herald.onWhere<UserAction>(
  ///   (e) => e.userId == currentUser.id,
  ///   (event) => handleUserAction(event),
  /// );
  /// ```
  static StreamSubscription<T> onWhere<T>(
    bool Function(T event) filter,
    void Function(T event) handler,
  ) {
    return _ensureController<T>().stream.where(filter).listen(handler);
  }

  // ---------------------------------------------------------------------------
  // Stream
  // ---------------------------------------------------------------------------

  /// Get a broadcast [Stream] of events of type [T].
  ///
  /// Useful for advanced stream composition (e.g., with
  /// `asyncExpand`, `where`, `debounce`).
  ///
  /// ```dart
  /// Herald.stream<UserLoggedIn>()
  ///     .where((e) => e.userId.isNotEmpty)
  ///     .listen(handleLogin);
  /// ```
  static Stream<T> stream<T>() => _ensureController<T>().stream;

  // ---------------------------------------------------------------------------
  // Replay
  // ---------------------------------------------------------------------------

  /// Get the last emitted event of type [T], or `null` if none.
  ///
  /// Useful for late subscribers that need to catch up on the most
  /// recent state of an event channel.
  ///
  /// ```dart
  /// final lastLogin = Herald.last<UserLoggedIn>();
  /// ```
  static T? last<T>() => _lastEvents[T] as T?;

  /// Get a broadcast [Stream] of ALL events, regardless of type.
  ///
  /// Each element is a [HeraldEvent] containing the event type and payload.
  /// Used by [Lens] debug overlay and testing.
  ///
  /// ```dart
  /// Herald.allEvents.listen((e) {
  ///   print('${e.type}: ${e.payload}');
  /// });
  /// ```
  static Stream<HeraldEvent> get allEvents {
    _globalController ??= StreamController<HeraldEvent>.broadcast(sync: true);
    return _globalController!.stream;
  }

  // ---------------------------------------------------------------------------
  // Management
  // ---------------------------------------------------------------------------

  /// Check if there are any active listeners for type [T].
  static bool hasListeners<T>() {
    final controller = _controllers[T];
    return controller != null && !controller.isClosed && controller.hasListener;
  }

  /// Clear the last-event cache for type [T].
  static void clearLast<T>() {
    _lastEvents.remove(T);
  }

  /// Clear the entire last-event cache.
  static void clearAllLast() {
    _lastEvents.clear();
  }

  /// Reset the entire Herald — close all streams and clear history.
  ///
  /// Typically used in tests:
  ///
  /// ```dart
  /// tearDown(() {
  ///   Herald.reset();
  ///   Titan.reset();
  /// });
  /// ```
  static void reset() {
    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
    _lastEvents.clear();
    maxLastEventTypes = 100;
    if (_globalController != null && !_globalController!.isClosed) {
      _globalController!.close();
    }
    _globalController = null;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  static StreamController<T> _ensureController<T>() {
    return (_controllers[T] ??= StreamController<T>.broadcast(sync: true))
        as StreamController<T>;
  }
}
