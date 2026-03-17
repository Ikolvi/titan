// ---------------------------------------------------------------------------
// ColossusServiceLocator — Dependency Lookup Abstraction
// ---------------------------------------------------------------------------

/// **ColossusServiceLocator** — framework-agnostic service locator interface.
///
/// Replaces direct `Titan.put/get/find/remove` usage inside Colossus.
/// When used with `TitanBindings`, instances are stored in Titan's DI
/// container. With `DefaultBindings`, a simple `Map` is used.
///
/// ```dart
/// final locator = ColossusBindings.instance.serviceLocator;
/// locator.register<MyService>(MyService());
///
/// final service = locator.resolve<MyService>();
/// print('Has service: ${locator.has<MyService>()}');
/// print('Total instances: ${locator.instances.length}');
/// ```
abstract class ColossusServiceLocator {
  /// Register an instance.
  void register<T extends Object>(T instance);

  /// Resolve a registered instance. Throws if not found.
  T resolve<T extends Object>();

  /// Resolve a registered instance, or `null` if not found.
  T? tryResolve<T extends Object>();

  /// Remove a registered instance.
  void unregister<T extends Object>();

  /// Whether an instance of type [T] is registered.
  bool has<T extends Object>();

  /// All currently registered instances (read-only).
  ///
  /// Used by Vessel for memory monitoring and Lens for DI inspection.
  Map<Type, dynamic> get instances;

  /// All registered types (read-only).
  Set<Type> get registeredTypes;
}

// ---------------------------------------------------------------------------
// DefaultServiceLocator — Map-backed implementation
// ---------------------------------------------------------------------------

/// Lightweight service locator backed by a `Map<Type, dynamic>`.
///
/// Used by `ColossusBindings.installDefaults()` when no framework
/// adapter is installed.
class DefaultServiceLocator implements ColossusServiceLocator {
  final Map<Type, dynamic> _instances = {};

  @override
  void register<T extends Object>(T instance) => _instances[T] = instance;

  @override
  T resolve<T extends Object>() {
    final instance = _instances[T];
    if (instance == null) {
      throw StateError('No instance registered for $T');
    }
    return instance as T;
  }

  @override
  T? tryResolve<T extends Object>() => _instances[T] as T?;

  @override
  void unregister<T extends Object>() => _instances.remove(T);

  @override
  bool has<T extends Object>() => _instances.containsKey(T);

  @override
  Map<Type, dynamic> get instances => Map.unmodifiable(_instances);

  @override
  Set<Type> get registeredTypes => Set.unmodifiable(_instances.keys.toSet());
}
