import 'package:meta/meta.dart';

import '../core/batch.dart';
import '../core/computed.dart';
import '../core/effect.dart';
import '../core/reactive.dart';
import '../core/state.dart';

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
  // Strike — batched, tracked mutations
  // ---------------------------------------------------------------------------

  /// Executes a **Strike** — a batched, tracked state mutation.
  ///
  /// **Strikes are fast, decisive, and powerful.**
  ///
  /// All [Core] mutations inside a Strike are batched into a single
  /// notification cycle, preventing unnecessary intermediate rebuilds.
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
    titanBatch(action);
  }

  /// Async version of [strike].
  ///
  /// ```dart
  /// Future<void> login(String email, String pass) => strikeAsync(() async {
  ///   final response = await api.login(email, pass);
  ///   user.value = response.user;
  ///   token.value = response.token;
  /// });
  /// ```
  @protected
  Future<void> strikeAsync(Future<void> Function() action) {
    _assertNotDisposed();
    return titanBatchAsync(action);
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
  TitanEffect watch(
    Function() fn, {
    String? name,
    bool immediate = true,
  }) {
    _assertNotDisposed();
    final effect = TitanEffect(
      fn,
      name: name,
      fireImmediately: immediate,
    );
    _managedEffects.add(effect);
    return effect;
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

  /// Initializes the Pillar. Called automatically by [Beacon] or [Titan].
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    onInit();
  }

  /// Disposes the Pillar and all its managed reactive nodes.
  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    onDispose();

    // Dispose effects first (they may reference cores/derived)
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
