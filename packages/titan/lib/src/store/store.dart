import 'package:meta/meta.dart';

import '../core/computed.dart';
import '../core/effect.dart';
import '../core/reactive.dart';
import '../core/state.dart';

/// Base class for organized state containers.
///
/// [TitanStore] provides a structured way to group related state,
/// computed values, and business logic. It manages the lifecycle of
/// all reactive primitives it creates.
///
/// **Note**: For new code, prefer [Pillar] which provides a more modern API
/// with additional features like `strike()`, `watch()`, `derived()`, and
/// built-in error handling via [Vigil].
///
/// ## Usage
///
/// ```dart
/// class CounterStore extends TitanStore {
///   late final count = createState(0, name: 'count');
///   late final doubleCount = createComputed(
///     () => count.value * 2,
///     name: 'doubleCount',
///   );
///   late final isEven = createComputed(
///     () => count.value % 2 == 0,
///     name: 'isEven',
///   );
///
///   void increment() => count.value++;
///   void decrement() => count.value--;
///   void reset() => count.value = 0;
/// }
/// ```
///
/// ## Lifecycle
///
/// - [onInit] is called once after the store is created
/// - [onDispose] is called when the store is disposed
/// - All reactive primitives created via [createState], [createComputed],
///   and [createEffect] are automatically disposed with the store
///
/// ## SOLID Principles
///
/// - **Single Responsibility**: Each store manages one domain/feature
/// - **Open/Closed**: Extend stores without modifying them
/// - **Liskov Substitution**: Stores are interchangeable via interfaces
/// - **Interface Segregation**: Keep stores focused and small
/// - **Dependency Inversion**: Depend on abstractions, inject stores via DI
abstract class TitanStore {
  final List<ReactiveNode> _managedNodes = [];
  final List<TitanEffect> _managedEffects = [];
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Whether this store has been initialized.
  bool get isInitialized => _isInitialized;

  /// Whether this store has been disposed.
  bool get isDisposed => _isDisposed;

  /// Creates a managed [TitanState] that will be disposed with this store.
  ///
  /// ```dart
  /// late final count = createState(0, name: 'count');
  /// ```
  @protected
  TitanState<T> createState<T>(
    T initialValue, {
    String? name,
    bool Function(T previous, T next)? equals,
  }) {
    _assertNotDisposed();
    final state = TitanState<T>(initialValue, name: name, equals: equals);
    _managedNodes.add(state);
    return state;
  }

  /// Creates a managed [TitanComputed] that will be disposed with this store.
  ///
  /// ```dart
  /// late final doubleCount = createComputed(
  ///   () => count.value * 2,
  ///   name: 'doubleCount',
  /// );
  /// ```
  @protected
  TitanComputed<T> createComputed<T>(
    T Function() compute, {
    String? name,
    bool Function(T previous, T next)? equals,
  }) {
    _assertNotDisposed();
    final computed = TitanComputed<T>(compute, name: name, equals: equals);
    _managedNodes.add(computed);
    return computed;
  }

  /// Creates a managed [TitanEffect] that will be disposed with this store.
  ///
  /// ```dart
  /// late final logEffect = createEffect(
  ///   () => print('Count: ${count.value}'),
  ///   name: 'logEffect',
  /// );
  /// ```
  @protected
  TitanEffect createEffect(
    Function() fn, {
    String? name,
    bool fireImmediately = true,
  }) {
    _assertNotDisposed();
    final effect = TitanEffect(
      fn,
      name: name,
      fireImmediately: fireImmediately,
    );
    _managedEffects.add(effect);
    return effect;
  }

  /// Called once after the store is created and registered.
  ///
  /// Override to perform initialization logic like loading initial data.
  @protected
  void onInit() {}

  /// Called when the store is being disposed.
  ///
  /// Override to perform cleanup logic.
  @protected
  void onDispose() {}

  /// Initializes the store. Called automatically by the DI container.
  @internal
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    onInit();
  }

  /// Disposes the store and all its managed reactive primitives.
  @mustCallSuper
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    onDispose();

    // Dispose effects first (they may reference state/computed)
    for (final effect in _managedEffects) {
      effect.dispose();
    }
    _managedEffects.clear();

    // Then dispose state and computed nodes
    for (final node in _managedNodes) {
      node.dispose();
    }
    _managedNodes.clear();
  }

  void _assertNotDisposed() {
    assert(!_isDisposed, '$runtimeType has already been disposed.');
  }
}
