# API Reference

Complete reference for all public APIs in the `titan` and `titan_bastion` packages.

---

## Primary API (Pillar Architecture)

### Pillar

Structured state management base class with lifecycle.

```dart
abstract class Pillar
```

#### Lifecycle

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `isInitialized` | `bool` | Whether `onInit()` has been called |
| `isDisposed` | `bool` | Whether the Pillar has been disposed |
| `initialize()` | `void` | Initialize the Pillar (calls `onInit()`) |
| `dispose()` | `void` | Dispose all managed nodes and call `onDispose()` |

#### Hooks (Override)

| Method | Description |
|--------|-------------|
| `onInit()` | Called once after initialization |
| `onDispose()` | Called when the Pillar is disposed |

#### Factory Methods (Protected)

| Method | Return | Description |
|--------|--------|-------------|
| `core<T>(T value, {String? name, bool Function(T,T)? equals})` | `TitanState<T>` | Create a managed reactive Core |
| `derived<T>(T Function() compute, {String? name})` | `TitanComputed<T>` | Create a managed Derived value |
| `watch(dynamic Function() fn, {bool fireImmediately})` | `TitanEffect` | Create a managed reactive side effect |

#### Mutation

| Method | Return | Description |
|--------|--------|-------------|
| `strike(void Function() fn)` | `void` | Batched synchronous mutation |
| `strikeAsync(Future<void> Function() fn)` | `Future<void>` | Batched async mutation |

---

### Core\<T\> (TitanState\<T\>)

Reactive mutable state container. `Core<T>` is a type alias for `TitanState<T>`.

#### Constructor

```dart
Core<T>(T initialValue, {String? name, bool Function(T, T)? equals})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `initialValue` | `T` | Initial value |
| `name` | `String?` | Debug name for logging |
| `equals` | `bool Function(T, T)?` | Custom equality function |

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | `T` | Get/set current value (tracks on read, notifies on write) |
| `name` | `String?` | Debug name |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `peek()` | `T` | Read without dependency tracking |
| `update(T Function(T) updater)` | `void` | Transform current value |
| `silent(T value)` | `void` | Set without notifying dependents |
| `listen(void Function(T) callback)` | `void Function()` | Listen for changes, returns unsubscribe |
| `dispose()` | `void` | Dispose and remove all listeners |

---

### Derived\<T\> (TitanComputed\<T\>)

Derived reactive value with auto-tracking and caching. `Derived<T>` is a type alias for `TitanComputed<T>`.

#### Constructor

```dart
Derived<T>(T Function() compute, {String? name})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | `T` | Get computed value (lazy, cached) |
| `name` | `String?` | Debug name |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `peek()` | `T` | Read cached value without tracking |
| `dispose()` | `void` | Dispose and clear dependencies |

---

### TitanEffect

Reactive side effect with auto-tracking.

#### Constructor

```dart
TitanEffect(
  dynamic Function() fn, {
  String? name,
  bool fireImmediately = true,
  void Function()? onNotify,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `fn` | `dynamic Function()` | Effect function. May return `void Function()` cleanup. |
| `name` | `String?` | Debug name |
| `fireImmediately` | `bool` | Run immediately on creation (default: `true`) |
| `onNotify` | `void Function()?` | Callback when dependencies change (used by widgets) |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `run()` | `void` | Manually execute the effect |
| `dispose()` | `void` | Dispose, run cleanup, clear dependencies |

---

### Batching

```dart
T titanBatch<T>(T Function() fn)     // Sync batch
Future<T> titanBatchAsync<T>(Future<T> Function() fn)  // Async batch

void strike(void Function() fn)       // Sync batch alias
Future<void> strikeAsync(Future<void> Function() fn)   // Async batch alias
```

---

### Titan (Global Registry)

```dart
abstract final class Titan
```

| Method | Return | Description |
|--------|--------|-------------|
| `Titan.put<T extends Pillar>(T instance)` | `void` | Register and auto-initialize |
| `Titan.lazy<T extends Pillar>(T Function() factory)` | `void` | Register lazy factory |
| `Titan.get<T extends Pillar>()` | `T` | Retrieve or throw |
| `Titan.find<T extends Pillar>()` | `T?` | Retrieve or null |
| `Titan.has<T extends Pillar>()` | `bool` | Check registration |
| `Titan.remove<T extends Pillar>()` | `void` | Remove and auto-dispose |
| `Titan.reset()` | `void` | Dispose all and clear |

---

## Flutter Widgets (package:titan_bastion)

### Vestige\<P extends Pillar\>

Auto-tracking consumer widget.

```dart
const Vestige<P extends Pillar>({
  required Widget Function(BuildContext context, P pillar) builder,
})
```

### VestigeRaw

Untyped auto-tracking consumer for standalone Cores.

```dart
const VestigeRaw({
  required Widget Function(BuildContext context) builder,
})
```

### Beacon

Scoped Pillar provider.

```dart
const Beacon({
  required List<Pillar Function()> pillars,
  required Widget child,
})
```

### BeaconScope (Static Helpers)

```dart
class BeaconScope {
  static P? findPillar<P extends Pillar>(BuildContext context);
  static P of<P extends Pillar>(BuildContext context); // throws if not found
}
```

### Context Extensions

```dart
extension BeaconContext on BuildContext {
  P pillar<P extends Pillar>();      // Get Pillar from Beacon
  bool hasPillar<P extends Pillar>(); // Check availability
}
```

---

## Advanced / Legacy APIs

### TitanStore

Legacy abstract base class for organized state containers.

| Method | Return | Description |
|--------|--------|-------------|
| `createState<T>(T value, {String? name, equals?})` | `TitanState<T>` | Create managed state |
| `createComputed<T>(compute, {String? name})` | `TitanComputed<T>` | Create managed computed |
| `createEffect(fn, {name?, fireImmediately?})` | `TitanEffect` | Create managed effect |
| `createAsyncState<T>({String? name})` | `TitanAsyncState<T>` | Create managed async state |
| `addMiddleware(TitanMiddleware)` | `void` | Add middleware |
| `onInit()` | `void` | Lifecycle hook |
| `onDispose()` | `void` | Lifecycle hook |
| `dispose()` | `void` | Dispose store and all managed nodes |

### TitanMiddleware

```dart
abstract class TitanMiddleware {
  void onStateChange<T>(StateChangeEvent<T> event);
  void onError(Object error, StackTrace stackTrace) {}
}
```

### StateChangeEvent\<T\>

```dart
class StateChangeEvent<T> {
  final String storeName;
  final String stateName;
  final T oldValue;
  final T newValue;
  final DateTime timestamp;
}
```

### TitanContainer

| Method | Return | Description |
|--------|--------|-------------|
| `register<T>(T Function() factory)` | `void` | Register factory |
| `get<T>()` | `T` | Retrieve instance (lazy singleton) |
| `has<T>()` | `bool` | Check registration |
| `createChild()` | `TitanContainer` | Create child with parent inheritance |
| `dispose()` | `void` | Dispose all instances |

### TitanModule / TitanSimpleModule

```dart
abstract class TitanModule {
  void register(TitanContainer container);
}

TitanSimpleModule(void Function(TitanContainer) registerFn)
```

### AsyncValue\<T\>

| Subclass | Properties | Description |
|----------|-----------|-------------|
| `AsyncData<T>` | `T value` | Successful data |
| `AsyncLoading<T>` | — | Loading state |
| `AsyncError<T>` | `Object error, StackTrace? stackTrace` | Error |

| Method | Return | Description |
|--------|--------|-------------|
| `when({data, loading, error})` | `R` | Exhaustive pattern matching |
| `maybeWhen({data?, loading?, error?, orElse})` | `R` | Partial pattern matching |
| `isLoading` / `isError` / `isData` | `bool` | State checks |
| `dataOrNull` | `T?` | Data value or null |

### TitanAsyncState\<T\>

| Method | Return | Description |
|--------|--------|-------------|
| `value` | `AsyncValue<T>` | Current async value |
| `load(Future<T> Function() loader)` | `Future<void>` | Load data |
| `refresh(Future<T> Function() loader)` | `Future<void>` | Refresh data |
| `setValue(T value)` | `void` | Manually set data |
| `setError(Object, [StackTrace?])` | `void` | Manually set error |
| `reset()` | `void` | Reset to loading |
| `dispose()` | `void` | Dispose |

### TitanObserver

```dart
abstract class TitanObserver {
  static TitanObserver? instance;
  void onStateChanged<T>(String name, T oldValue, T newValue);
}
```

| Class | Description |
|-------|-------------|
| `TitanLoggingObserver` | Console logging |
| `TitanHistoryObserver` | Time-travel debugging with `history` and `clear()` |

### TitanConfig

```dart
class TitanConfig {
  static bool debugMode = false;
  static void enableLogging();
  static void reset();
}
```

### Legacy Flutter Widgets

| Widget | Description |
|--------|-------------|
| `TitanScope` | InheritedWidget-based DI scope |
| `TitanBuilder` | Auto-tracking builder |
| `TitanConsumer<T>` | Typed store consumer |
| `TitanSelector<T>` | Fine-grained selector |
| `TitanAsyncBuilder<T>` | Async data builder |
| `TitanStateMixin` | Reactive mixin for StatefulWidget |

### Legacy Context Extensions

```dart
extension TitanContextExtensions on BuildContext {
  T titan<T extends TitanStore>();
  bool hasTitan<T extends TitanStore>();
}
```

---

[← Advanced Patterns](08-advanced-patterns.md) · [Migration Guide →](10-migration-guide.md)
