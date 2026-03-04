import '../store/store.dart';

/// A lightweight dependency injection container for Titan stores.
///
/// [TitanContainer] manages the lifecycle of [TitanStore] instances,
/// supporting both lazy and eager instantiation, scoping, and
/// automatic disposal.
///
/// ## Usage
///
/// ```dart
/// final container = TitanContainer();
///
/// // Register stores
/// container.register(() => CounterStore());
/// container.register(() => AuthStore());
///
/// // Retrieve (lazily created on first access)
/// final counterStore = container.get<CounterStore>();
///
/// // Dispose all
/// container.dispose();
/// ```
///
/// ## Scoping
///
/// Create child containers that inherit parent registrations but can
/// override them locally:
///
/// ```dart
/// final child = container.createChild();
/// child.register(() => MockCounterStore()); // overrides parent
/// ```
class TitanContainer {
  final Map<Type, _Registration> _registrations = {};
  final Map<Type, TitanStore> _instances = {};
  final TitanContainer? _parent;
  final List<TitanContainer> _children = [];
  bool _isDisposed = false;

  /// Creates a new container.
  ///
  /// - [parent] — Optional parent container for hierarchical scoping.
  TitanContainer({TitanContainer? parent}) : _parent = parent;

  /// Registers a factory function for a [TitanStore] type.
  ///
  /// - [factory] — Function that creates the store instance.
  /// - [lazy] — If `true` (default), the store is created on first access.
  ///   If `false`, it's created immediately.
  void register<T extends TitanStore>(
    T Function() factory, {
    bool lazy = true,
  }) {
    _assertNotDisposed();
    _registrations[T] = _Registration<T>(factory);

    if (!lazy) {
      _resolveAndInit<T>();
    }
  }

  /// Retrieves a [TitanStore] of type [T].
  ///
  /// If the store hasn't been created yet, it will be lazily instantiated
  /// and initialized. Looks up the parent container if not found locally.
  ///
  /// Throws [StateError] if no registration is found.
  T get<T extends TitanStore>() {
    _assertNotDisposed();
    return _resolve<T>();
  }

  /// Checks whether a store of type [T] is registered.
  bool has<T extends TitanStore>() {
    return _registrations.containsKey(T) ||
        _instances.containsKey(T) ||
        (_parent?.has<T>() ?? false);
  }

  /// Register only if [T] is not already registered locally.
  ///
  /// Returns `true` if the factory was registered, `false` if [T]
  /// was already present. Does NOT check parent containers.
  ///
  /// ```dart
  /// container.registerIfAbsent(() => AnalyticsStore());
  /// container.registerIfAbsent(() => AnalyticsStore()); // No-op
  /// ```
  bool registerIfAbsent<T extends TitanStore>(
    T Function() factory, {
    bool lazy = true,
  }) {
    _assertNotDisposed();
    if (_registrations.containsKey(T) || _instances.containsKey(T)) {
      return false;
    }
    register<T>(factory, lazy: lazy);
    return true;
  }

  /// Unregister and dispose a store of type [T].
  ///
  /// Returns the disposed instance, or `null` if not found.
  T? unregister<T extends TitanStore>() {
    _assertNotDisposed();
    _registrations.remove(T);
    final instance = _instances.remove(T);
    if (instance is TitanStore) {
      instance.dispose();
    }
    return instance as T?;
  }

  /// Creates a child container that inherits this container's registrations.
  ///
  /// Child containers can override parent registrations and will be
  /// disposed when the parent is disposed.
  TitanContainer createChild() {
    _assertNotDisposed();
    final child = TitanContainer(parent: this);
    _children.add(child);
    return child;
  }

  /// Disposes all stores and child containers.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    // Dispose children first
    for (final child in _children) {
      child.dispose();
    }
    _children.clear();

    // Dispose all store instances
    for (final instance in _instances.values) {
      instance.dispose();
    }
    _instances.clear();
    _registrations.clear();
  }

  T _resolve<T extends TitanStore>() {
    // Check local instances first
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }

    // Check local registrations
    if (_registrations.containsKey(T)) {
      return _resolveAndInit<T>();
    }

    // Check parent
    if (_parent != null) {
      return _parent.get<T>();
    }

    throw StateError(
      'No registration found for $T. '
      'Did you forget to call container.register(() => $T())?',
    );
  }

  T _resolveAndInit<T extends TitanStore>() {
    final registration = _registrations[T]! as _Registration<T>;
    final instance = registration.factory();
    _instances[T] = instance;
    instance.initialize();
    return instance;
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('TitanContainer has already been disposed.');
    }
  }
}

class _Registration<T extends TitanStore> {
  final T Function() factory;

  const _Registration(this.factory);
}
