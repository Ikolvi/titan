import 'dart:async';

import 'package:meta/meta.dart';

import '../core/batch.dart';
import '../core/computed.dart';
import '../core/conduit.dart';
import '../core/effect.dart';
import '../core/epoch.dart';
import '../core/loom.dart';
import '../core/nexus.dart';
import '../core/observer.dart';
import '../core/prism.dart';
import '../core/reactive.dart';
import '../core/state.dart';
import '../data/mandate.dart';
import '../data/ledger.dart';
import '../data/omen.dart';
import '../testing/snapshot.dart';
import '../errors/vigil.dart';
import '../events/herald.dart';
import '../form/scroll.dart';
import '../logging/chronicle.dart';

/// The fundamental organizing unit of Titan's state management.
///
/// **Titans held up the sky — Pillars hold up your app.**
///
/// A [Pillar] groups related reactive state ([Core]s), derived values
/// ([Derived]s), and business logic into a single, structured unit with
/// lifecycle management and automatic disposal.
///
/// ## Why Pillar?
///
/// - **Structured like Bloc** — organized state with lifecycle hooks
/// - **Simple like plain Dart** — no event classes, no state classes
/// - **Fine-grained reactivity** — each [Core] tracks independently
/// - **Automatic cleanup** — all reactive nodes disposed with the Pillar
///
/// ## Usage
///
/// ```dart
/// class CounterPillar extends Pillar {
///   late final count = core(0);
///   late final doubled = derived(() => count.value * 2);
///
///   void increment() => strike(() => count.value++);
///   void decrement() => strike(() => count.value--);
///   void reset() => strike(() => count.value = 0);
/// }
/// ```
///
/// ## Lifecycle
///
/// - [onInit] — Called once after registration (via [Beacon] or [Titan.put])
/// - [onDispose] — Called when the Pillar is removed or its [Beacon] unmounts
/// - All [Core]s and [Derived]s are auto-disposed with the Pillar
///
/// ## Scaling Up
///
/// ```dart
/// class AuthPillar extends Pillar {
///   late final user = core<User?>(null);
///   late final token = core<String?>(null);
///   late final isLoggedIn = derived(() => user.value != null);
///
///   @override
///   void onInit() {
///     // Reactive watcher — re-runs when tracked cores change
///     watch(() {
///       if (isLoggedIn.value) {
///         analytics.track('user_logged_in');
///       }
///     });
///   }
///
///   Future<void> login(String email, String password) async {
///     final response = await api.login(email, password);
///     strike(() {
///       user.value = response.user;
///       token.value = response.token;
///     });
///   }
///
///   void logout() => strike(() {
///     user.value = null;
///     token.value = null;
///   });
/// }
/// ```
abstract class Pillar {
  final List<ReactiveNode> _managedNodes = [];
  final List<TitanEffect> _managedEffects = [];
  final List<StreamSubscription<dynamic>> _managedSubscriptions = [];
  final List<StrikeMiddleware> _middleware = [];
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _autoDispose = false;
  int _refCount = 0;
  bool _isReadyFlag = false;
  TitanState<bool>? _isReadyCore;

  /// Sentinel used to detect whether [onInitAsync] has been overridden.
  static final Future<void> _completedFuture = Future<void>.value();

  /// Reactive readiness indicator for async initialization.
  ///
  /// Starts as `false`, becomes `true` after [onInitAsync] completes
  /// (including the default no-op implementation).
  ///
  /// The underlying [TitanState] is allocated lazily on first access,
  /// avoiding overhead for Pillars that never read [isReady].
  ///
  /// ```dart
  /// Vestige<MyPillar>(
  ///   builder: (_, p) => p.isReady.value
  ///     ? Text('Ready!')
  ///     : CircularProgressIndicator(),
  /// )
  /// ```
  TitanState<bool> get isReady {
    return _isReadyCore ??= TitanState<bool>(
      _isReadyFlag,
      name: '${runtimeType}_isReady',
    );
  }

  /// Whether this Pillar has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether this Pillar has been disposed.
  bool get isDisposed => _isDisposed;

  /// Whether auto-dispose is enabled for this Pillar.
  ///
  /// When enabled, the Pillar will automatically dispose itself when
  /// the last consumer (Vestige) disconnects.
  bool get autoDispose => _autoDispose;

  /// The current number of active consumer references.
  int get refCount => _refCount;

  // ---------------------------------------------------------------------------
  // Node registration — for extension packages
  // ---------------------------------------------------------------------------

  /// Register reactive nodes for auto-disposal when this Pillar is disposed.
  ///
  /// Satellite packages (e.g. `titan_basalt`) use this to add lifecycle-
  /// managed nodes from extension methods on [Pillar].
  ///
  /// ```dart
  /// // In a satellite package:
  /// extension PillarBasalt on Pillar {
  ///   Trove<K, V> trove<K, V>({...}) {
  ///     final t = Trove<K, V>(...);
  ///     registerNodes(t.managedNodes);
  ///     return t;
  ///   }
  /// }
  /// ```
  void registerNodes(Iterable<ReactiveNode> nodes) {
    _assertNotDisposed();
    _managedNodes.addAll(nodes);
  }

  // ---------------------------------------------------------------------------
  // Core creation — reactive state managed by this Pillar
  // ---------------------------------------------------------------------------

  /// Creates a reactive [Core] (mutable state) managed by this Pillar.
  ///
  /// The Core is automatically disposed when this Pillar is disposed.
  ///
  /// ```dart
  /// late final count = core(0);
  /// late final name = core('untitled', name: 'name');
  /// late final user = core<User?>(null);
  /// late final health = core(100, conduits: [ClampConduit(min: 0, max: 100)]);
  /// ```
  @protected
  TitanState<T> core<T>(
    T initialValue, {
    String? name,
    bool Function(T previous, T next)? equals,
    List<Conduit<T>>? conduits,
  }) {
    _assertNotDisposed();
    final state = TitanState<T>(
      initialValue,
      name: name,
      equals: equals,
      conduits: conduits,
    );
    _managedNodes.add(state);
    return state;
  }

  /// Creates a reactive [Derived] (computed value) managed by this Pillar.
  ///
  /// The computation auto-tracks which [Core]s are accessed and re-evaluates
  /// only when those dependencies change.
  ///
  /// ```dart
  /// late final doubled = derived(() => count.value * 2);
  /// late final fullName = derived(
  ///   () => '${firstName.value} ${lastName.value}',
  /// );
  /// ```
  @protected
  TitanComputed<T> derived<T>(
    T Function() compute, {
    String? name,
    bool Function(T previous, T next)? equals,
  }) {
    _assertNotDisposed();
    final c = TitanComputed<T>(compute, name: name, equals: equals);
    _managedNodes.add(c);
    return c;
  }

  // ---------------------------------------------------------------------------
  // Prism creation — fine-grained state projections
  // ---------------------------------------------------------------------------

  /// Creates a [Prism] (fine-grained state projection) managed by this Pillar.
  ///
  /// A Prism selects a sub-value from a [Core] and only notifies dependents
  /// when that specific projection changes — enabling surgical widget rebuilds.
  ///
  /// ```dart
  /// late final user = core(User(name: 'Kael', level: 10));
  /// late final userName = prism(user, (u) => u.name);
  /// late final userLevel = prism(user, (u) => u.level);
  ///
  /// // userName only rebuilds when name changes, not level
  /// ```
  ///
  /// For collection projections, use [PrismEquals] for structural equality:
  ///
  /// ```dart
  /// late final tags = prism(
  ///   post, (p) => p.tags.toList(),
  ///   equals: PrismEquals.list,
  /// );
  /// ```
  @protected
  Prism<R> prism<S, R>(
    TitanState<S> source,
    R Function(S value) selector, {
    String? name,
    bool Function(R previous, R next)? equals,
  }) {
    _assertNotDisposed();
    final p = Prism<R>(
      source,
      (v) => selector(v as S),
      name: name,
      equals: equals,
    );
    _managedNodes.add(p);
    return p;
  }

  // ---------------------------------------------------------------------------
  // Nexus creation — Reactive collections
  // ---------------------------------------------------------------------------

  /// Creates a [NexusList] (reactive list) managed by this Pillar.
  ///
  /// Unlike `core<List<T>>()` which copies on every mutation, NexusList
  /// mutates in-place with granular change tracking.
  ///
  /// ```dart
  /// late final items = nexusList<String>(['sword', 'shield']);
  /// late final count = derived(() => items.length);
  /// ```
  @protected
  NexusList<T> nexusList<T>([List<T>? initial, String? name]) {
    _assertNotDisposed();
    final list = NexusList<T>(initial: initial, name: name);
    _managedNodes.add(list);
    return list;
  }

  /// Creates a [NexusMap] (reactive map) managed by this Pillar.
  ///
  /// ```dart
  /// late final scores = nexusMap<String, int>({'Alice': 10});
  /// late final topPlayer = derived(() =>
  ///   scores.isEmpty ? 'None' : scores.entries.first.key,
  /// );
  /// ```
  @protected
  NexusMap<K, V> nexusMap<K, V>([Map<K, V>? initial, String? name]) {
    _assertNotDisposed();
    final map = NexusMap<K, V>(initial: initial, name: name);
    _managedNodes.add(map);
    return map;
  }

  /// Creates a [NexusSet] (reactive set) managed by this Pillar.
  ///
  /// ```dart
  /// late final tags = nexusSet<String>({'dart', 'flutter'});
  /// late final hasFlutter = derived(() => tags.contains('flutter'));
  /// ```
  @protected
  NexusSet<T> nexusSet<T>([Set<T>? initial, String? name]) {
    _assertNotDisposed();
    final set = NexusSet<T>(initial: initial, name: name);
    _managedNodes.add(set);
    return set;
  }

  // ---------------------------------------------------------------------------
  // Epoch creation — Cores with undo/redo history
  // ---------------------------------------------------------------------------

  /// Creates an [Epoch] (Core with undo/redo history) managed by this Pillar.
  ///
  /// An Epoch behaves exactly like a Core, but records every value change
  /// for time-travel navigation.
  ///
  /// ```dart
  /// late final text = epoch('', maxHistory: 200);
  ///
  /// void type(String s) => strike(() => text.value = s);
  /// void undo() => text.undo();
  /// void redo() => text.redo();
  /// ```
  @protected
  Epoch<T> epoch<T>(
    T initialValue, {
    int maxHistory = 100,
    String? name,
    bool Function(T previous, T next)? equals,
  }) {
    _assertNotDisposed();
    final e = Epoch<T>(
      initialValue,
      maxHistory: maxHistory,
      name: name,
      equals: equals,
    );
    _managedNodes.add(e);
    return e;
  }

  // ---------------------------------------------------------------------------
  // Loom — finite state machine
  // ---------------------------------------------------------------------------

  /// Creates a [Loom] (finite state machine) managed by this Pillar.
  ///
  /// A Loom manages state transitions with guarded rules, lifecycle
  /// callbacks, and full reactive tracking.
  ///
  /// ```dart
  /// late final auth = loom<AuthState, AuthEvent>(
  ///   initial: AuthState.unauthenticated,
  ///   transitions: {
  ///     (AuthState.unauthenticated, AuthEvent.login): AuthState.authenticating,
  ///     (AuthState.authenticating, AuthEvent.success): AuthState.authenticated,
  ///     (AuthState.authenticated, AuthEvent.logout): AuthState.unauthenticated,
  ///   },
  /// );
  ///
  /// void login() => auth.send(AuthEvent.login);
  /// ```
  @protected
  Loom<S, E> loom<S, E>({
    required S initial,
    required Map<(S, E), S> transitions,
    Map<S, void Function()>? onEnter,
    Map<S, void Function()>? onExit,
    void Function(S from, E event, S to)? onTransition,
    int maxHistory = 50,
    String? name,
  }) {
    _assertNotDisposed();
    final l = Loom<S, E>(
      initial: initial,
      transitions: transitions,
      onEnter: onEnter,
      onExit: onExit,
      onTransition: onTransition,
      maxHistory: maxHistory,
      name: name,
    );
    _managedNodes.add(l.state);
    return l;
  }

  // ---------------------------------------------------------------------------
  // Scroll — form fields with validation
  // ---------------------------------------------------------------------------

  /// Creates a [Scroll] (form field with validation) managed by this Pillar.
  ///
  /// A Scroll is a Core with additional form capabilities: validation,
  /// dirty/pristine tracking, touch state, and reset.
  ///
  /// ```dart
  /// late final email = scroll('',
  ///   validator: (v) => v.contains('@') ? null : 'Invalid email',
  /// );
  ///
  /// void submit() {
  ///   if (email.validate()) {
  ///     // Valid — process
  ///   }
  /// }
  /// ```
  @protected
  Scroll<T> scroll<T>(
    T initialValue, {
    String? Function(T value)? validator,
    Future<String?> Function(T value)? asyncValidator,
    String? name,
    bool Function(T previous, T next)? equals,
  }) {
    _assertNotDisposed();
    final s = Scroll<T>(
      initialValue,
      validator: validator,
      asyncValidator: asyncValidator,
      name: name,
      equals: equals,
    );
    _managedNodes.add(s);
    // Also track the internal error and touched nodes
    _managedNodes.addAll(s.managedNodes);
    return s;
  }

  // ---------------------------------------------------------------------------
  // Omen — Reactive async Derived
  // ---------------------------------------------------------------------------

  /// Creates an [Omen] (reactive async Derived) managed by this Pillar.
  ///
  /// An Omen re-evaluates its async computation whenever the reactive Cores
  /// read inside it change. It is the async counterpart to [derived].
  ///
  /// ```dart
  /// late final query = core('');
  /// late final results = omen<List<Product>>(
  ///   () async => api.search(query.value),
  ///   debounce: Duration(milliseconds: 300),
  /// );
  /// ```
  @protected
  Omen<T> omen<T>(
    Future<T> Function() compute, {
    Duration? debounce,
    bool keepPreviousData = true,
    String? name,
    bool eager = true,
  }) {
    _assertNotDisposed();
    final o = Omen<T>(
      compute,
      debounce: debounce,
      keepPreviousData: keepPreviousData,
      name: name,
      eager: eager,
    );
    _managedNodes.addAll(o.managedNodes);
    return o;
  }

  // ---------------------------------------------------------------------------
  // Mandate — reactive policy engine
  // ---------------------------------------------------------------------------

  /// Creates a [Mandate] (reactive policy engine) managed by this Pillar.
  ///
  /// A Mandate evaluates [Writ] policies reactively — when any [Core]
  /// read inside a Writ's evaluation function changes, the verdict
  /// automatically re-evaluates and downstream Vestige widgets rebuild.
  ///
  /// ```dart
  /// late final editAccess = mandate(
  ///   writs: [
  ///     Writ(
  ///       name: 'authenticated',
  ///       evaluate: () => currentUser.value != null,
  ///       reason: 'Must be logged in',
  ///     ),
  ///     Writ(
  ///       name: 'is-owner',
  ///       evaluate: () => doc.value?.ownerId == currentUser.value?.id,
  ///       reason: 'Only the owner can edit',
  ///     ),
  ///   ],
  ///   name: 'edit-access',
  /// );
  /// ```
  @protected
  Mandate mandate({
    List<Writ> writs = const [],
    MandateStrategy strategy = MandateStrategy.allOf,
    String? name,
  }) {
    _assertNotDisposed();
    final m = Mandate(writs: writs, strategy: strategy, name: name);
    _managedNodes.addAll(m.managedNodes);
    _managedNodes.addAll(m.managedStateNodes);
    return m;
  }

  // ---------------------------------------------------------------------------
  // Ledger — state transactions
  // ---------------------------------------------------------------------------

  /// Creates a [Ledger] (state transaction manager) managed by this Pillar.
  ///
  /// Provides ACID-like transactions for multi-Core mutations:
  /// commit atomically or roll back to pre-transaction state.
  ///
  /// ```dart
  /// late final txManager = ledger(name: 'checkout');
  ///
  /// Future<void> placeOrder() async {
  ///   await txManager.transact((tx) async {
  ///     tx.capture(inventory);
  ///     tx.capture(balance);
  ///     inventory.value -= qty;
  ///     balance.value -= price;
  ///   });
  /// }
  /// ```
  @protected
  Ledger ledger({int maxHistory = 100, String? name}) {
    _assertNotDisposed();
    final l = Ledger(maxHistory: maxHistory, name: name);
    _managedNodes.addAll(l.managedNodes);
    _managedNodes.addAll(l.managedStateNodes);
    return l;
  }

  // ---------------------------------------------------------------------------
  // Strike — batched, tracked mutations
  // ---------------------------------------------------------------------------

  /// Adds a [StrikeMiddleware] to this Pillar's middleware chain.
  ///
  /// Middleware intercepts every [strike] and [strikeAsync] call, enabling
  /// cross-cutting concerns like logging, analytics, rate-limiting, and
  /// auth token refresh.
  ///
  /// Middleware is executed in the order it was added (FIFO).
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   addMiddleware(StrikeMiddleware(
  ///     before: (pillar) => log.debug('Strike starting'),
  ///     after: (pillar) => log.debug('Strike complete'),
  ///     onError: (pillar, error, stackTrace) {
  ///       log.error('Strike failed', error, stackTrace);
  ///     },
  ///   ));
  /// }
  /// ```
  @protected
  void addMiddleware(StrikeMiddleware middleware) {
    _assertNotDisposed();
    _middleware.add(middleware);
  }

  /// Removes a previously added middleware.
  @protected
  void removeMiddleware(StrikeMiddleware middleware) {
    _middleware.remove(middleware);
  }

  /// Executes a **Strike** — a batched, tracked state mutation.
  ///
  /// **Strikes are fast, decisive, and powerful.**
  ///
  /// All [Core] mutations inside a Strike are batched into a single
  /// notification cycle, preventing unnecessary intermediate rebuilds.
  ///
  /// If middleware is registered, each middleware's [StrikeMiddleware.before]
  /// is called before the action, and [StrikeMiddleware.after] is called
  /// after. On error, [StrikeMiddleware.onError] is called.
  ///
  /// ```dart
  /// void increment() => strike(() => count.value++);
  ///
  /// void reset() => strike(() {
  ///   count.value = 0;
  ///   name.value = 'Counter';
  /// });
  /// ```
  @protected
  void strike(void Function() action) {
    _assertNotDisposed();
    if (_middleware.isEmpty) {
      titanBatch(action);
      return;
    }
    // Execute middleware chain
    for (final m in _middleware) {
      m.before?.call(this);
    }
    try {
      titanBatch(action);
      for (final m in _middleware) {
        m.after?.call(this);
      }
    } catch (e, s) {
      for (final m in _middleware) {
        m.onError?.call(this, e, s);
      }
      rethrow;
    }
  }

  /// Async version of [strike].
  ///
  /// Errors thrown inside the action are automatically captured via
  /// [Vigil] with this Pillar's type as the source, then rethrown.
  ///
  /// ```dart
  /// Future<void> login(String email, String pass) => strikeAsync(() async {
  ///   final response = await api.login(email, pass);
  ///   user.value = response.user;
  ///   token.value = response.token;
  /// });
  /// ```
  @protected
  Future<void> strikeAsync(Future<void> Function() action) async {
    _assertNotDisposed();
    for (final m in _middleware) {
      m.before?.call(this);
    }
    try {
      await titanBatchAsync(action);
      for (final m in _middleware) {
        m.after?.call(this);
      }
    } catch (e, s) {
      for (final m in _middleware) {
        m.onError?.call(this, e, s);
      }
      captureError(e, stackTrace: s, action: 'strikeAsync');
      rethrow;
    }
  }

  /// A map of debounce timers keyed by tag.
  final Map<String, Timer> _debounceTimers = {};

  /// A map of throttle timestamps keyed by tag.
  final Map<String, DateTime> _throttleTimestamps = {};

  /// Executes a **debounced Strike** — delays execution until no more
  /// calls arrive within [duration].
  ///
  /// Ideal for search-as-you-type, auto-save, or any scenario where
  /// rapid successive calls should coalesce into a single execution.
  ///
  /// The [tag] groups related debounced strikes — only strikes with the
  /// same tag debounce against each other. Defaults to `'default'`.
  ///
  /// ```dart
  /// void onSearchChanged(String query) {
  ///   strikeDebounced(
  ///     () => searchQuery.value = query,
  ///     duration: Duration(milliseconds: 300),
  ///     tag: 'search',
  ///   );
  /// }
  ///
  /// void onAutoSave() {
  ///   strikeDebounced(
  ///     () => save(document.peek()),
  ///     duration: Duration(seconds: 2),
  ///     tag: 'save',
  ///   );
  /// }
  /// ```
  @protected
  void strikeDebounced(
    void Function() action, {
    required Duration duration,
    String tag = 'default',
  }) {
    _assertNotDisposed();
    _debounceTimers[tag]?.cancel();
    _debounceTimers[tag] = Timer(duration, () {
      _debounceTimers.remove(tag);
      if (!_isDisposed) {
        strike(action);
      }
    });
  }

  /// Executes a **throttled Strike** — ensures at most one execution
  /// per [duration] window.
  ///
  /// Unlike [strikeDebounced] (which waits for silence), throttled
  /// strikes execute immediately on the first call and then ignore
  /// subsequent calls until [duration] has elapsed.
  ///
  /// The [tag] groups related throttled strikes. Defaults to `'default'`.
  ///
  /// ```dart
  /// void onScroll(double offset) {
  ///   strikeThrottled(
  ///     () => scrollPosition.value = offset,
  ///     duration: Duration(milliseconds: 100),
  ///     tag: 'scroll',
  ///   );
  /// }
  /// ```
  @protected
  void strikeThrottled(
    void Function() action, {
    required Duration duration,
    String tag = 'default',
  }) {
    _assertNotDisposed();
    final lastExecution = _throttleTimestamps[tag];
    final now = DateTime.now();
    if (lastExecution == null || now.difference(lastExecution) >= duration) {
      _throttleTimestamps[tag] = now;
      strike(action);
    }
  }

  // ---------------------------------------------------------------------------
  // Watch — reactive effects
  // ---------------------------------------------------------------------------

  /// Creates a managed reactive watcher.
  ///
  /// The [fn] is executed immediately and auto-tracks which [Core]s are read.
  /// When those Cores change, the watcher re-executes automatically.
  ///
  /// The watcher is disposed automatically with this Pillar.
  ///
  /// If [fn] returns a [Function], it's called as cleanup before each re-run
  /// and on disposal.
  ///
  /// If [when] is provided, the watcher only executes when the guard
  /// returns `true`. The guard can read reactive values and will
  /// auto-track its own dependencies.
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   watch(() {
  ///     print('User changed to: ${user.value?.name}');
  ///   });
  ///
  ///   // With cleanup
  ///   watch(() {
  ///     final sub = stream.listen(handler);
  ///     return () => sub.cancel();
  ///   });
  ///
  ///   // With guard — only runs when online
  ///   watch(() {
  ///     syncToServer(data.value);
  ///   }, when: () => isOnline.value);
  /// }
  /// ```
  @protected
  TitanEffect watch(
    Function() fn, {
    String? name,
    bool immediate = true,
    bool Function()? when,
  }) {
    _assertNotDisposed();
    final effect = TitanEffect(
      fn,
      name: name,
      fireImmediately: immediate,
      guard: when,
    );
    _managedEffects.add(effect);
    return effect;
  }

  // ---------------------------------------------------------------------------
  // Herald — cross-Pillar event messaging
  // ---------------------------------------------------------------------------

  /// Listen for [Herald] events of type [T].
  ///
  /// The subscription is automatically cancelled when this Pillar is disposed,
  /// so you never need to manually cancel it.
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   listen<UserLoggedOut>((_) {
  ///     strike(() => items.value = []);
  ///   });
  ///
  ///   listen<ThemeChanged>((event) {
  ///     strike(() => isDark.value = event.isDark);
  ///   });
  /// }
  /// ```
  @protected
  StreamSubscription<T> listen<T>(void Function(T event) handler) {
    _assertNotDisposed();
    final subscription = Herald.on<T>(handler);
    _managedSubscriptions.add(subscription);
    return subscription;
  }

  /// Listen for exactly one [Herald] event of type [T], then auto-cancel.
  ///
  /// The subscription is also cancelled if the Pillar is disposed before
  /// the event arrives.
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   listenOnce<AppReady>((_) => loadData());
  /// }
  /// ```
  @protected
  StreamSubscription<T> listenOnce<T>(void Function(T event) handler) {
    _assertNotDisposed();
    final subscription = Herald.once<T>(handler);
    _managedSubscriptions.add(subscription);
    return subscription;
  }

  /// Emit a [Herald] event of type [T].
  ///
  /// Broadcasts the event to all listeners across the application.
  ///
  /// ```dart
  /// void checkout() {
  ///   processOrder(items.value);
  ///   emit(OrderPlaced(items: items.value));
  ///   strike(() => items.value = []);
  /// }
  /// ```
  @protected
  void emit<T>(T event) {
    _assertNotDisposed();
    Herald.emit<T>(event);
  }

  // ---------------------------------------------------------------------------
  // Vigil — centralized error tracking
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Chronicle — structured logging
  // ---------------------------------------------------------------------------

  /// A named [Chronicle] logger for this Pillar.
  ///
  /// Automatically named after the Pillar's `runtimeType` for easy
  /// identification in log output.
  ///
  /// ```dart
  /// class AuthPillar extends Pillar {
  ///   Future<void> login(String email) async {
  ///     log.info('Attempting login', {'email': email});
  ///     try {
  ///       final user = await api.login(email);
  ///       log.info('Login successful');
  ///     } catch (e, s) {
  ///       log.error('Login failed', e, s);
  ///     }
  ///   }
  /// }
  /// ```
  @protected
  late final Chronicle log = Chronicle('$runtimeType');

  // ---------------------------------------------------------------------------
  // Vigil — centralized error tracking
  // ---------------------------------------------------------------------------

  /// Capture an error via [Vigil] with automatic Pillar context.
  ///
  /// The error is tagged with this Pillar's `runtimeType` as the source.
  /// Use this instead of raw `Vigil.capture` inside Pillars for
  /// richer error context.
  ///
  /// ```dart
  /// Future<void> loadData() async {
  ///   try {
  ///     final data = await api.fetchData();
  ///     strike(() => items.value = data);
  ///   } catch (e, s) {
  ///     captureError(e, stackTrace: s, action: 'loadData');
  ///   }
  /// }
  /// ```
  @protected
  void captureError(
    Object error, {
    StackTrace? stackTrace,
    ErrorSeverity severity = ErrorSeverity.error,
    String? action,
    Map<String, dynamic>? metadata,
  }) {
    Vigil.capture(
      error,
      stackTrace: stackTrace,
      severity: severity,
      context: ErrorContext(
        source: runtimeType,
        action: action,
        metadata: metadata,
      ),
    );
    onError(error, stackTrace);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Called once after the Pillar is created and registered.
  ///
  /// Override to perform initialization: load data, set up watchers, etc.
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   watch(() => print('count = ${count.value}'));
  ///   loadInitialData();
  /// }
  /// ```
  @protected
  void onInit() {}

  /// Called after [onInit] for async initialization.
  ///
  /// Override to perform async setup: loading data from APIs,
  /// reading from databases, authenticating, etc. When this method
  /// completes, [isReady] is automatically set to `true`.
  ///
  /// Errors are caught and forwarded to [onError].
  ///
  /// ```dart
  /// @override
  /// Future<void> onInitAsync() async {
  ///   final data = await api.fetchInitialData();
  ///   items.value = data;
  /// }
  /// ```
  @protected
  Future<void> onInitAsync() => _completedFuture;

  /// Called when the Pillar is being disposed.
  ///
  /// Override to perform cleanup: close connections, cancel timers, etc.
  @protected
  void onDispose() {}

  /// Called when an error occurs during [strikeAsync] or [captureError].
  ///
  /// Override to implement Pillar-specific error recovery, logging,
  /// or user notification. The default implementation does nothing
  /// (errors are still captured by Vigil regardless).
  ///
  /// ```dart
  /// @override
  /// void onError(Object error, StackTrace? stackTrace) {
  ///   showErrorSnackbar(error.toString());
  /// }
  /// ```
  @protected
  void onError(Object error, StackTrace? stackTrace) {}

  /// Enable auto-dispose for this Pillar.
  ///
  /// When enabled, the Pillar will automatically remove itself from
  /// [Titan] and dispose when all consumer references are released.
  /// Call this in [onInit] or before registration.
  ///
  /// ```dart
  /// @override
  /// void onInit() {
  ///   enableAutoDispose();
  ///   loadData();
  /// }
  /// ```
  void enableAutoDispose() {
    _autoDispose = true;
  }

  /// Increment the reference count.
  ///
  /// Called automatically by Vestige when a consumer mounts.
  /// Can also be called manually to keep a Pillar alive.
  void ref() => _refCount++;

  /// Decrement the reference count.
  ///
  /// When auto-dispose is enabled and the reference count drops to
  /// zero, the Pillar's [onAutoDispose] callback is invoked.
  /// By default, [onAutoDispose] removes this Pillar from the
  /// global [Titan] registry (set up automatically by `Titan.put`).
  ///
  /// Called automatically by Vestige when a consumer unmounts.
  void unref() {
    _refCount--;
    if (_autoDispose && _refCount <= 0 && !_isDisposed) {
      onAutoDispose?.call();
    }
  }

  /// Callback invoked when auto-dispose triggers.
  ///
  /// Set automatically by `Titan.put()` to remove the Pillar from
  /// the global registry. Can be overridden for custom disposal logic.
  void Function()? onAutoDispose;

  // ---------------------------------------------------------------------------
  // Snapshot — state capture & restore
  // ---------------------------------------------------------------------------

  /// Capture a snapshot of all named Core values.
  ///
  /// Only [Core] values with a non-null `name` parameter are included.
  /// Computed/Derived values are excluded since they derive from state.
  ///
  /// ```dart
  /// final snap = pillar.snapshot(label: 'before-mutation');
  /// ```
  PillarSnapshot snapshot({String? label}) {
    return Snapshot.captureFromNodes(_managedNodes, label: label);
  }

  /// Restore Core values from a previously captured snapshot.
  ///
  /// By default, values are restored silently (without notifications).
  /// Set [notify] to `true` to trigger reactive updates.
  ///
  /// ```dart
  /// pillar.restore(snap);
  /// ```
  void restore(PillarSnapshot snapshot, {bool notify = false}) {
    Snapshot.restoreToNodes(_managedNodes, snapshot, notify: notify);
  }

  /// Initializes the Pillar. Called automatically by [Beacon] or [Titan].
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    onInit();
    TitanObserver.notifyPillarInit(this);

    // Run async initialization if overridden
    _runInitAsync();
  }

  /// Internal async init runner.
  ///
  /// Uses a sentinel to detect whether [onInitAsync] was overridden.
  /// For sync-only Pillars (the default), this avoids allocating a
  /// [Future] and scheduling microtasks, setting [isReady] synchronously.
  void _runInitAsync() {
    final Future<void> result;
    try {
      result = onInitAsync();
    } catch (e, s) {
      onError(e, s);
      return;
    }

    if (identical(result, _completedFuture)) {
      // Default implementation — no async work. Set ready synchronously.
      _isReadyFlag = true;
      _isReadyCore?.value = true;
      return;
    }

    // Actual async init — await completion without async/await overhead.
    result.then(
      (_) {
        if (!_isDisposed) {
          _isReadyFlag = true;
          _isReadyCore?.value = true;
        }
      },
      onError: (Object e, StackTrace s) {
        onError(e, s);
      },
    );
  }

  /// Disposes the Pillar and all its managed reactive nodes.
  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    onDispose();
    TitanObserver.notifyPillarDispose(this);

    // Cancel debounce timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _throttleTimestamps.clear();

    // Cancel Herald subscriptions first
    for (final subscription in _managedSubscriptions) {
      subscription.cancel();
    }
    _managedSubscriptions.clear();

    // Dispose effects (they may reference cores/derived)
    for (final effect in _managedEffects) {
      effect.dispose();
    }
    _managedEffects.clear();

    // Then dispose cores and derived values
    for (final node in _managedNodes) {
      node.dispose();
    }
    _managedNodes.clear();

    // Dispose isReady Core (only if it was allocated)
    _isReadyCore?.dispose();
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('$runtimeType has already been disposed.');
    }
  }
}

/// Middleware that intercepts [Pillar.strike] and [Pillar.strikeAsync] calls.
///
/// Enables cross-cutting concerns like logging, analytics, rate-limiting,
/// and auth token refresh around state mutations.
///
/// ## Usage
///
/// ```dart
/// class AuthPillar extends Pillar {
///   @override
///   void onInit() {
///     addMiddleware(StrikeMiddleware(
///       before: (pillar) => print('Strike starting on $pillar'),
///       after: (pillar) => print('Strike complete on $pillar'),
///       onError: (pillar, error, stackTrace) {
///         print('Strike failed: $error');
///       },
///     ));
///   }
/// }
/// ```
///
/// ## Analytics Middleware
///
/// ```dart
/// final analyticsMiddleware = StrikeMiddleware(
///   after: (pillar) {
///     analytics.track('state_mutation', {
///       'pillar': pillar.runtimeType.toString(),
///     });
///   },
/// );
/// ```
class StrikeMiddleware {
  /// Called before the strike action executes.
  final void Function(Pillar pillar)? before;

  /// Called after the strike action completes successfully.
  final void Function(Pillar pillar)? after;

  /// Called when the strike action throws an error.
  final void Function(Pillar pillar, Object error, StackTrace stackTrace)?
  onError;

  /// Creates a strike middleware.
  const StrikeMiddleware({this.before, this.after, this.onError});
}
