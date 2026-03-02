/// Loom — A reactive finite state machine built on Titan's signal system.
///
/// The Loom weaves states together with transition rules, providing
/// predictable, guarded state progression with lifecycle callbacks.
///
/// ```dart
/// enum AuthState { unauthenticated, authenticating, authenticated, error }
/// enum AuthEvent { login, success, failure, logout }
///
/// class AuthPillar extends Pillar {
///   late final auth = loom<AuthState, AuthEvent>(
///     initial: AuthState.unauthenticated,
///     transitions: {
///       (AuthState.unauthenticated, AuthEvent.login): AuthState.authenticating,
///       (AuthState.authenticating, AuthEvent.success): AuthState.authenticated,
///       (AuthState.authenticating, AuthEvent.failure): AuthState.error,
///       (AuthState.authenticated, AuthEvent.logout): AuthState.unauthenticated,
///       (AuthState.error, AuthEvent.login): AuthState.authenticating,
///     },
///     onEnter: {
///       AuthState.authenticated: () => log.info('Welcome!'),
///       AuthState.error: () => log.error('Auth failed'),
///     },
///     onExit: {
///       AuthState.authenticated: () => clearSession(),
///     },
///   );
///
///   void login() => auth.send(AuthEvent.login);
///   void logout() => auth.send(AuthEvent.logout);
/// }
/// ```
library;

import 'state.dart';

/// A reactive finite state machine.
///
/// [Loom] manages a [Core] of state [S] with event-driven transitions.
/// States are typically enums, and transitions are defined as a map
/// of `(currentState, event)` → `nextState`.
///
/// The current state is a [TitanState], which means it's fully reactive —
/// [Vestige] widgets, [Derived] values, and [watch]ers automatically
/// track and respond to state machine transitions.
///
/// ## Features
///
/// - **Guarded transitions** — only valid `(from, event)` pairs trigger changes
/// - **Lifecycle hooks** — `onEnter` / `onExit` callbacks per state
/// - **Side effects** — `onTransition` callback for logging/analytics
/// - **Query API** — `canSend()`, `allowedEvents`, `isIn()`
/// - **Reactive** — built on [Core], works with all Titan reactive primitives
///
/// ```dart
/// final fsm = Loom<TrafficLight, TrafficEvent>(
///   initial: TrafficLight.red,
///   transitions: {
///     (TrafficLight.red, TrafficEvent.next): TrafficLight.green,
///     (TrafficLight.green, TrafficEvent.next): TrafficLight.yellow,
///     (TrafficLight.yellow, TrafficEvent.next): TrafficLight.red,
///   },
/// );
///
/// fsm.send(TrafficEvent.next); // red → green
/// print(fsm.current); // TrafficLight.green
/// ```
class Loom<S, E> {
  /// The underlying reactive state.
  final TitanState<S> _state;

  /// Transition table: (from, event) → to.
  final Map<(S, E), S> _transitions;

  /// Callbacks invoked when entering a state.
  final Map<S, void Function()>? _onEnter;

  /// Callbacks invoked when exiting a state.
  final Map<S, void Function()>? _onExit;

  /// Global transition callback (for logging/analytics).
  final void Function(S from, E event, S to)? _onTransition;

  /// Transition history for debugging.
  final List<LoomTransition<S, E>> _history = [];

  /// Maximum history entries to keep.
  final int _maxHistory;

  /// Creates a reactive finite state machine.
  ///
  /// - [initial] — The starting state.
  /// - [transitions] — Map of `(currentState, event)` → `nextState`.
  /// - [onEnter] — Callbacks when entering specific states.
  /// - [onExit] — Callbacks when exiting specific states.
  /// - [onTransition] — Global callback for every transition.
  /// - [maxHistory] — Max transition records to keep (default: 50).
  /// - [name] — Debug name for the underlying [Core].
  ///
  /// ```dart
  /// final machine = Loom<MyState, MyEvent>(
  ///   initial: MyState.idle,
  ///   transitions: {
  ///     (MyState.idle, MyEvent.start): MyState.running,
  ///     (MyState.running, MyEvent.pause): MyState.paused,
  ///     (MyState.paused, MyEvent.resume): MyState.running,
  ///     (MyState.running, MyEvent.stop): MyState.idle,
  ///   },
  /// );
  /// ```
  Loom({
    required S initial,
    required Map<(S, E), S> transitions,
    Map<S, void Function()>? onEnter,
    Map<S, void Function()>? onExit,
    void Function(S from, E event, S to)? onTransition,
    int maxHistory = 50,
    String? name,
  }) : _state = TitanState<S>(initial, name: name),
       _transitions = Map.unmodifiable(transitions),
       _onEnter = onEnter,
       _onExit = onExit,
       _onTransition = onTransition,
       _maxHistory = maxHistory;

  /// The current state value (auto-tracked in reactive scopes).
  ///
  /// ```dart
  /// // In a Vestige builder:
  /// Text('State: ${auth.current}')
  /// ```
  S get current => _state.value;

  /// The underlying reactive [Core] for this state machine.
  ///
  /// Use this to access reactive features like `.value`, `.listen()`,
  /// `.previousValue`, etc.
  TitanState<S> get state => _state;

  /// Whether the machine is currently in the given state.
  ///
  /// Reads the state reactively (auto-tracked).
  ///
  /// ```dart
  /// if (auth.isIn(AuthState.authenticated)) {
  ///   // ...
  /// }
  /// ```
  bool isIn(S state) => _state.value == state;

  /// Whether the given event can be sent in the current state.
  ///
  /// Returns `true` if a transition exists for `(currentState, event)`.
  /// Does NOT read the state reactively — uses [peek] internally.
  ///
  /// ```dart
  /// if (auth.canSend(AuthEvent.login)) {
  ///   auth.send(AuthEvent.login);
  /// }
  /// ```
  bool canSend(E event) {
    return _transitions.containsKey((_state.peek(), event));
  }

  /// Returns the set of events that are valid in the current state.
  ///
  /// Does NOT read the state reactively — uses [peek] internally.
  ///
  /// ```dart
  /// print(auth.allowedEvents); // {AuthEvent.login}
  /// ```
  Set<E> get allowedEvents {
    final current = _state.peek();
    return _transitions.keys
        .where((key) => key.$1 == current)
        .map((key) => key.$2)
        .toSet();
  }

  /// Send an event to the state machine.
  ///
  /// If a valid transition exists for `(currentState, event)`,
  /// the state changes and lifecycle callbacks fire. If no valid
  /// transition exists, the event is silently ignored.
  ///
  /// Returns `true` if the transition occurred, `false` otherwise.
  ///
  /// ```dart
  /// auth.send(AuthEvent.login);    // true — transition occurred
  /// auth.send(AuthEvent.login);    // false — no transition from authenticating
  /// ```
  bool send(E event) {
    final from = _state.peek();
    final to = _transitions[(_state.peek(), event)];
    if (to == null) return false;

    // Record transition
    _history.add(LoomTransition(from: from, event: event, to: to));
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }

    // Exit old state
    _onExit?[from]?.call();

    // Transition
    _state.value = to;

    // Enter new state
    _onEnter?[to]?.call();

    // Notify global callback
    _onTransition?.call(from, event, to);

    return true;
  }

  /// Send an event, throwing [StateError] if no valid transition exists.
  ///
  /// Use this when you expect the transition to always be valid and
  /// want to catch programming errors early.
  ///
  /// ```dart
  /// auth.sendOrThrow(AuthEvent.login);
  /// ```
  void sendOrThrow(E event) {
    if (!send(event)) {
      throw StateError(
        'Loom: No transition from ${_state.peek()} on $event. '
        'Allowed events: $allowedEvents',
      );
    }
  }

  /// The transition history (most recent last).
  ///
  /// Limited by [maxHistory] (default: 50).
  List<LoomTransition<S, E>> get history => List.unmodifiable(_history);

  /// Resets the state machine to a specific state.
  ///
  /// Does NOT fire `onEnter`/`onExit` callbacks. Clears history.
  /// Use for testing or re-initialization.
  void reset(S state) {
    _state.value = state;
    _history.clear();
  }

  @override
  String toString() {
    final name = _state.name;
    final label = name != null ? '($name)' : '';
    return 'Loom$label<$S, $E>: ${_state.peek()}';
  }
}

/// A record of a state machine transition.
///
/// Captures the from-state, triggering event, and to-state for
/// debugging and audit trail purposes.
class LoomTransition<S, E> {
  /// The state before the transition.
  final S from;

  /// The event that triggered the transition.
  final E event;

  /// The state after the transition.
  final S to;

  /// Creates a transition record.
  const LoomTransition({
    required this.from,
    required this.event,
    required this.to,
  });

  @override
  String toString() => '$from --[$event]--> $to';
}
