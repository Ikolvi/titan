import 'dart:async';

import 'package:meta/meta.dart';

import '../core/batch.dart';
import '../core/computed.dart';
import '../core/effect.dart';
import '../core/epoch.dart';
import '../core/observer.dart';
import '../core/reactive.dart';
import '../core/state.dart';
import '../data/codex.dart';
import '../data/quarry.dart';
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

  /// Whether this Pillar has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether this Pillar has been disposed.
  bool get isDisposed => _isDisposed;

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
  /// ```
  @protected
  TitanState<T> core<T>(
    T initialValue, {
    String? name,
    bool Function(T previous, T next)? equals,
  }) {
    _assertNotDisposed();
    final state = TitanState<T>(initialValue, name: name, equals: equals);
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
  // Codex — paginated data
  // ---------------------------------------------------------------------------

  /// Creates a [Codex] (paginated data manager) managed by this Pillar.
  ///
  /// A Codex handles paginated data loading with reactive state for items,
  /// loading status, errors, and page tracking. Supports both offset-based
  /// and cursor-based pagination.
  ///
  /// ```dart
  /// late final quests = codex<Quest>(
  ///   fetcher: (request) async {
  ///     final result = await api.getQuests(
  ///       page: request.page,
  ///       limit: request.pageSize,
  ///     );
  ///     return CodexPage(
  ///       items: result.items,
  ///       hasMore: result.hasMore,
  ///     );
  ///   },
  ///   pageSize: 20,
  /// );
  ///
  /// Future<void> loadQuests() => quests.loadFirst();
  /// Future<void> loadMore() => quests.loadNext();
  /// ```
  @protected
  Codex<T> codex<T>(
    Future<CodexPage<T>> Function(CodexRequest request) fetcher, {
    int pageSize = 20,
    String? name,
  }) {
    _assertNotDisposed();
    final c = Codex<T>(fetcher: fetcher, pageSize: pageSize, name: name);
    _managedNodes.addAll(c.managedNodes);
    return c;
  }

  // ---------------------------------------------------------------------------
  // Quarry — data fetching with caching
  // ---------------------------------------------------------------------------

  /// Creates a [Quarry] (data fetching query) managed by this Pillar.
  ///
  /// A Quarry manages a single async data resource with reactive state,
  /// stale-while-revalidate caching, automatic deduplication, retry logic,
  /// and optimistic update support.
  ///
  /// ```dart
  /// late final userQuery = quarry<User>(
  ///   fetcher: () => api.getUser(),
  ///   staleTime: Duration(minutes: 5),
  /// );
  ///
  /// @override
  /// void onInit() => userQuery.fetch();
  /// ```
  @protected
  Quarry<T> quarry<T>({
    required Future<T> Function() fetcher,
    Duration? staleTime,
    QuarryRetry retry = const QuarryRetry(maxAttempts: 0),
    void Function(T data)? onSuccess,
    void Function(Object error)? onError,
    String? name,
  }) {
    _assertNotDisposed();
    final q = Quarry<T>(
      fetcher: fetcher,
      staleTime: staleTime,
      retry: retry,
      onSuccess: onSuccess,
      onError: onError,
      name: name,
    );
    _managedNodes.addAll(q.managedNodes);
    return q;
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
  /// }
  /// ```
  @protected
  TitanEffect watch(Function() fn, {String? name, bool immediate = true}) {
    _assertNotDisposed();
    final effect = TitanEffect(fn, name: name, fireImmediately: immediate);
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

  /// Initializes the Pillar. Called automatically by [Beacon] or [Titan].
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    onInit();
    TitanObserver.notifyPillarInit(this);
  }

  /// Disposes the Pillar and all its managed reactive nodes.
  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    onDispose();
    TitanObserver.notifyPillarDispose(this);

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
  }

  void _assertNotDisposed() {
    assert(!_isDisposed, '$runtimeType has already been disposed.');
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
