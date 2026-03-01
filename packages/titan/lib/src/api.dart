/// Titan — Total Integrated Transfer Architecture Network
///
/// A uniquely powerful reactive state management architecture.
///
/// ## The Titan Lexicon
///
/// | Concept | Titan Name | Meaning |
/// |---------|------------|---------|
/// | Store / Bloc | **Pillar** | Titans held up the sky; Pillars hold up your app |
/// | Dispatch / Add | **Strike** | Fast, decisive, powerful |
/// | State | **Core** | The indestructible center of the Pillar |
/// | Consumer | **Vestige** | The UI — a visible trace of the underlying power |
/// | Provider | **Beacon** | Shines state down to all children |
///
/// ## Quick Start
///
/// ```dart
/// // Define a Pillar (your app's state module)
/// class CounterPillar extends Pillar {
///   late final count = core(0);
///   late final doubled = derived(() => count.value * 2);
///
///   void increment() => strike(() => count.value++);
///   void reset() => strike(() => count.value = 0);
/// }
///
/// // Wire it up
/// Titan.put(CounterPillar());
///
/// // Consume in UI
/// Vestige<CounterPillar>(
///   builder: (context, counter) => Text('${counter.count.value}'),
/// )
/// ```
library;

import 'core/batch.dart';
import 'core/state.dart';
import 'core/computed.dart';
import 'pillar/pillar.dart';

// ---------------------------------------------------------------------------
// Type aliases — the Titan lexicon
// ---------------------------------------------------------------------------

/// **Core** — The indestructible center of a Pillar.
///
/// A reactive mutable value. Reading `.value` inside a [Derived] or
/// [Vestige] auto-tracks the dependency. Writing `.value` auto-notifies.
///
/// ```dart
/// final count = Core<int>(0);
/// count.value = 5;
/// print(count.value); // 5
/// ```
typedef Core<T> = TitanState<T>;

/// **Derived** — A reactive value forged from Cores.
///
/// Auto-tracks which [Core]s are read during computation and re-evaluates
/// only when those dependencies change. Results are cached.
///
/// ```dart
/// final doubled = Derived<int>(() => count.value * 2);
/// ```
typedef Derived<T> = TitanComputed<T>;

// ---------------------------------------------------------------------------
// Top-level functions
// ---------------------------------------------------------------------------

/// Executes a **Strike** — a batched state mutation.
///
/// All [Core] mutations inside are grouped into a single notification
/// cycle, preventing unnecessary intermediate rebuilds.
///
/// ```dart
/// strike(() {
///   count.value = 0;
///   name.value = '';
///   filter.value = Filter.all;
/// }); // Single notification — dependents see final state only
/// ```
void strike(void Function() fn) => titanBatch(fn);

/// Async version of [strike].
///
/// ```dart
/// await strikeAsync(() async {
///   count.value = await fetchCount();
///   name.value = await fetchName();
/// });
/// ```
Future<void> strikeAsync(Future<void> Function() fn) => titanBatchAsync(fn);

// ---------------------------------------------------------------------------
// Titan — Global service locator & Pillar registry
// ---------------------------------------------------------------------------

/// **Titan** — The global registry for your app's Pillars and services.
///
/// Register [Pillar]s globally for access anywhere, without widget
/// tree ceremony. Pillars registered via [put] are automatically
/// initialized.
///
/// ```dart
/// // In main()
/// Titan.put(AuthPillar());
/// Titan.put(CartPillar());
///
/// // Lazy creation (instantiated on first access)
/// Titan.lazy(() => AnalyticsPillar());
///
/// // Access anywhere
/// final auth = Titan.get<AuthPillar>();
/// final cart = Titan.get<CartPillar>();
///
/// // Check / remove
/// if (Titan.has<AuthPillar>()) { ... }
/// Titan.remove<AuthPillar>();
///
/// // Reset (e.g., in tests)
/// Titan.reset();
/// ```
///
/// For scoped state (feature-level Pillars that should be disposed
/// when a screen is removed), use [Beacon] instead.
abstract final class Titan {
  static final Map<Type, dynamic> _instances = {};
  static final Map<Type, dynamic Function()> _factories = {};

  /// Register and initialize an instance (typically a [Pillar]).
  ///
  /// If the instance is a [Pillar], it will be automatically initialized.
  ///
  /// ```dart
  /// Titan.put(AuthPillar());
  /// Titan.put(CartPillar());
  /// ```
  static void put<T>(T instance) {
    _instances[T] = instance;
    if (instance is Pillar) {
      instance.initialize();
    }
  }

  /// Register a lazy factory. Instance is created on first [get].
  ///
  /// If the created instance is a [Pillar], it will be auto-initialized.
  ///
  /// ```dart
  /// Titan.lazy(() => ExpensiveService());
  /// ```
  static void lazy<T>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Retrieve a registered instance.
  ///
  /// Throws [StateError] if not registered.
  static T get<T>() {
    if (_instances.containsKey(T)) return _instances[T] as T;
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!() as T;
      _instances[T] = instance;
      _factories.remove(T);
      if (instance is Pillar) {
        instance.initialize();
      }
      return instance;
    }
    throw StateError(
      'Titan: No instance of type $T registered.\n'
      'Call Titan.put<$T>() or Titan.lazy<$T>() first.',
    );
  }

  /// Try to retrieve a registered instance, returns null if not found.
  static T? find<T>() {
    try {
      return get<T>();
    } catch (_) {
      return null;
    }
  }

  /// Check if a type is registered.
  static bool has<T>() =>
      _instances.containsKey(T) || _factories.containsKey(T);

  /// Remove and dispose an instance.
  ///
  /// If the instance is a [Pillar], it will be disposed automatically.
  static T? remove<T>() {
    _factories.remove(T);
    final instance = _instances.remove(T);
    if (instance is Pillar) {
      instance.dispose();
    }
    return instance as T?;
  }

  /// Reset all registrations. Disposes all [Pillar] instances.
  ///
  /// ```dart
  /// tearDown(() => Titan.reset());
  /// ```
  static void reset() {
    for (final instance in _instances.values) {
      if (instance is Pillar) {
        instance.dispose();
      }
    }
    _instances.clear();
    _factories.clear();
  }
}
