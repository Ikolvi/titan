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

// IMPORTANT: Top-level strike() and strikeAsync() functions have been
// intentionally removed. Dart's name resolution causes top-level functions
// to shadow Pillar instance methods of the same name, even in regular method
// bodies — not just `late final` initializers. This means:
//
//   class MyPillar extends Pillar {
//     void increment() => strike(() => count.value++);
//   }
//
// Would call the TOP-LEVEL strike() instead of Pillar.strike(), bypassing
// _assertNotDisposed() and auto-capture in strikeAsync().
//
// Use titanBatch() / titanBatchAsync() for standalone batching outside
// of Pillars, or call this.strike() / this.strikeAsync() in Pillar methods.

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
      instance.onAutoDispose = () => remove<T>();
      instance.initialize();
    }
  }

  /// Register a [Pillar] using its runtime type.
  ///
  /// Unlike [put], which uses the compile-time generic type `T`,
  /// this uses the actual `runtimeType` of the Pillar. Essential
  /// for dynamic registration (e.g., route-scoped Pillars in Atlas).
  ///
  /// ```dart
  /// Pillar pillar = AuthPillar();
  /// Titan.forge(pillar); // Registered as AuthPillar, not Pillar
  /// Titan.get<AuthPillar>(); // Works!
  /// ```
  static void forge(Pillar pillar) {
    _instances[pillar.runtimeType] = pillar;
    pillar.onAutoDispose = () => removeByType(pillar.runtimeType);
    pillar.initialize();
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

  /// Register only if [T] is not already registered.
  ///
  /// Returns `true` if the instance was registered, `false` if [T]
  /// was already present. Useful for idempotent plugin initialization.
  ///
  /// ```dart
  /// Titan.putIfAbsent(AnalyticsPillar()); // Registers
  /// Titan.putIfAbsent(AnalyticsPillar()); // No-op, returns false
  /// ```
  static bool putIfAbsent<T>(T instance) {
    if (has<T>()) return false;
    put<T>(instance);
    return true;
  }

  /// Replace an existing registration with a new instance.
  ///
  /// If [T] is already registered, the old instance is disposed (if it
  /// is a [Pillar]) and replaced. If not registered, behaves like [put].
  ///
  /// Useful for hot-reloading or swapping implementations at runtime.
  ///
  /// ```dart
  /// // Initial registration
  /// Titan.put<AuthService>(RealAuthService());
  ///
  /// // Hot-swap with mock
  /// Titan.replace<AuthService>(MockAuthService());
  /// ```
  static void replace<T>(T instance) {
    if (_instances.containsKey(T)) {
      final old = _instances[T];
      if (old is Pillar) {
        old.dispose();
      }
    }
    _factories.remove(T);
    put<T>(instance);
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
        instance.onAutoDispose = () => remove<T>();
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

  /// Remove an instance by its runtime [Type].
  ///
  /// Used for cases where the type is known at runtime but not at
  /// compile time (e.g., route-scoped Pillar management in Atlas).
  ///
  /// If the instance is a [Pillar], it will be disposed automatically.
  ///
  /// ```dart
  /// Titan.put(AuthPillar());
  /// Titan.removeByType(AuthPillar); // Same as Titan.remove<AuthPillar>()
  /// ```
  static dynamic removeByType(Type type) {
    _factories.remove(type);
    final instance = _instances.remove(type);
    if (instance is Pillar) {
      instance.dispose();
    }
    return instance;
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

  // ---------------------------------------------------------------------------
  // Debug / Introspection — used by Lens (debug overlay)
  // ---------------------------------------------------------------------------

  /// Returns the set of currently registered types (instances + factories).
  ///
  /// Useful for debug tools like [Lens] to display active registrations.
  static Set<Type> get registeredTypes => {
    ..._instances.keys,
    ..._factories.keys,
  };

  /// Returns all currently instantiated instances.
  ///
  /// Does NOT trigger lazy factory creation. Only returns instances that
  /// have already been created (via [put], [forge], or previously resolved
  /// [lazy] registrations).
  ///
  /// Useful for debug tools like [Lens] to inspect active Pillars.
  static Map<Type, dynamic> get instances => Map.unmodifiable(_instances);
}
