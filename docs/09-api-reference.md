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

#### Vigil Integration (Protected)

| Method | Return | Description |
|--------|--------|-------------|
| `captureError(Object error, {...})` | `void` | Capture via Vigil with Pillar context |

#### Chronicle Integration (Protected)

| Property | Type | Description |
|----------|------|-------------|
| `log` | `Chronicle` | Auto-named logger (named after `runtimeType`) |

#### Factory Methods (Protected)

| Method | Return | Description |
|--------|--------|-------------|
| `core<T>(T value, {String? name, bool Function(T,T)? equals})` | `TitanState<T>` | Create a managed reactive Core |
| `derived<T>(T Function() compute, {String? name})` | `TitanComputed<T>` | Create a managed Derived value |
| `epoch<T>(T value, {int maxHistory, String? name})` | `Epoch<T>` | Create a managed Core with undo/redo |
| `watch(dynamic Function() fn, {bool fireImmediately})` | `TitanEffect` | Create a managed reactive side effect |

#### Mutation

| Method | Return | Description |
|--------|--------|-------------|
| `strike(void Function() fn)` | `void` | Batched synchronous mutation |
| `strikeAsync(Future<void> Function() fn)` | `Future<void>` | Batched async mutation |

#### Herald Integration (Protected)

| Method | Return | Description |
|--------|--------|-------------|
| `listen<T>(void Function(T) handler)` | `StreamSubscription<T>` | Managed Herald listener (auto-disposed) |
| `listenOnce<T>(void Function(T) handler)` | `StreamSubscription<T>` | One-shot managed listener |
| `emit<T>(T event)` | `void` | Broadcast event via Herald |

---

### Herald

Cross-domain event bus for decoupled Pillar-to-Pillar communication.

```dart
abstract final class Herald
```

| Method | Return | Description |
|--------|--------|-------------|
| `emit<T>(T event)` | `void` | Broadcast event to all listeners of type T |
| `on<T>(void Function(T) handler)` | `StreamSubscription<T>` | Listen for events of type T |
| `once<T>(void Function(T) handler)` | `StreamSubscription<T>` | Listen for one event, then auto-cancel |
| `stream<T>()` | `Stream<T>` | Get broadcast stream of events |
| `last<T>()` | `T?` | Get last emitted event of type T |
| `hasListeners<T>()` | `bool` | Check for active listeners |
| `clearLast<T>()` | `void` | Clear last-event cache for type T |
| `reset()` | `void` | Close all streams, clear history |

---

### Vigil

Centralized error tracking with pluggable handlers.

```dart
abstract final class Vigil
```

#### Capture

| Method | Return | Description |
|--------|--------|-------------|
| `capture(Object error, {StackTrace?, ErrorSeverity, ErrorContext?})` | `void` | Capture error with context |
| `guard<T>(T Function() fn, {...})` | `T?` | Execute sync, capture on failure, return null |
| `guardAsync<T>(Future<T> Function() fn, {...})` | `Future<T?>` | Execute async, capture on failure, return null |
| `captureAndRethrow<T>(Future<T> Function() fn, {...})` | `Future<T>` | Capture then rethrow |

#### Handlers

| Method | Return | Description |
|--------|--------|-------------|
| `addHandler(ErrorHandler handler)` | `void` | Add pluggable error handler |
| `removeHandler(ErrorHandler handler)` | `void` | Remove a handler |
| `handlers` | `List<ErrorHandler>` | Read-only list of registered handlers |

#### History & Query

| Property/Method | Return | Description |
|-----------------|--------|-------------|
| `history` | `List<TitanError>` | All captured errors (most recent last) |
| `lastError` | `TitanError?` | Most recently captured error |
| `bySeverity(ErrorSeverity)` | `List<TitanError>` | Filter history by severity |
| `bySource(Type)` | `List<TitanError>` | Filter history by source Pillar type |
| `errors` | `Stream<TitanError>` | Real-time broadcast stream of errors |
| `clearHistory()` | `void` | Clear the error history |
| `maxHistorySize` | `int` | Max errors to keep (default: 100) |
| `reset()` | `void` | Remove all handlers, clear history |

#### Built-in Handlers

| Class | Description |
|-------|-------------|
| `ConsoleErrorHandler` | Formatted console output with severity filter |
| `FilteredErrorHandler` | Route errors by condition to another handler |

#### Supporting Types

| Type | Description |
|------|-------------|
| `TitanError` | Captured error with `error`, `stackTrace`, `severity`, `context`, `timestamp` |
| `ErrorContext` | Context with `source` (Type), `action` (String), `metadata` (Map) |
| `ErrorSeverity` | `debug`, `info`, `warning`, `error`, `fatal` |
| `ErrorHandler` | Abstract base — implement `handle(TitanError)` |

---

### Chronicle

Structured logging system with named loggers and pluggable sinks.

```dart
class Chronicle
```

#### Static Configuration

| Property/Method | Return | Description |
|-----------------|--------|-------------|
| `Chronicle.level` | `LogLevel` | Global min log level (default: `debug`) |
| `Chronicle.addSink(LogSink sink)` | `void` | Add output destination |
| `Chronicle.removeSink(LogSink sink)` | `void` | Remove output destination |
| `Chronicle.sinks` | `List<LogSink>` | Read-only list of registered sinks |
| `Chronicle.consoleSink` | `ConsoleLogSink` | Default built-in console sink |
| `Chronicle.reset()` | `void` | Clear sinks, restore defaults |

#### Instance Methods

| Method | Description |
|--------|-------------|
| `trace(String message, [Map?])` | Log at trace level |
| `debug(String message, [Map?])` | Log at debug level |
| `info(String message, [Map?])` | Log at info level |
| `warning(String message, [Map?])` | Log at warning level |
| `error(String message, [Object?, StackTrace?, Map?])` | Log at error level |
| `fatal(String message, [Object?, StackTrace?, Map?])` | Log at fatal level |

#### Supporting Types

| Type | Description |
|------|-------------|
| `LogLevel` | `trace`, `debug`, `info`, `warning`, `error`, `fatal`, `off` |
| `LogEntry` | Structured entry with `loggerName`, `level`, `message`, `data`, `error`, `stackTrace`, `timestamp` |
| `LogSink` | Abstract base — implement `write(LogEntry)` |
| `ConsoleLogSink` | Built-in formatted console output with icons |

---

### Epoch\<T\>

Core with undo/redo history (time-travel state). Extends `TitanState<T>`.

```dart
Epoch<T>(T initialValue, {int maxHistory = 100, String? name})
```

| Method/Property | Type | Description |
|-----------------|------|-------------|
| `undo()` | `void` | Revert to previous value |
| `redo()` | `void` | Replay next value |
| `canUndo` | `bool` | Whether undo is available |
| `canRedo` | `bool` | Whether redo is available |
| `undoCount` | `int` | Number of undo steps |
| `redoCount` | `int` | Number of redo steps |
| `history` | `List<T>` | Read-only list of past values |
| `clearHistory()` | `void` | Wipe history, keep current value |
| `maxHistory` | `int` | Max undo depth (default 100) |

---

### Flux (Stream Operators)

Extensions on `TitanState<T>` for stream-like composition.

#### FluxStateExtensions\<T\>

| Method | Return | Description |
|--------|--------|-------------|
| `debounce(Duration)` | `DebouncedState<T>` | Value updates after quiet period |
| `throttle(Duration)` | `ThrottledState<T>` | Value updates at most once per duration |
| `asStream()` | `Stream<T>` | Convert to typed broadcast stream |

#### FluxNodeExtensions

| Property | Type | Description |
|----------|------|-------------|
| `onChange` | `Stream<void>` | Emits on every change (any ReactiveNode) |

---

### Relic

Persistence & hydration manager for Cores.

```dart
Relic({required RelicAdapter adapter, required Map<String, RelicEntry> entries, String prefix = 'titan:'})
```

| Method | Return | Description |
|--------|--------|-------------|
| `hydrate()` | `Future<void>` | Restore all values from storage |
| `hydrateKey(String key)` | `Future<bool>` | Restore single value |
| `persist()` | `Future<void>` | Save all values to storage |
| `persistKey(String key)` | `Future<bool>` | Save single value |
| `enableAutoSave()` | `void` | Auto-persist on every Core change |
| `disableAutoSave()` | `void` | Stop auto-persisting |
| `clear()` | `Future<void>` | Remove all persisted data |
| `clearKey(String key)` | `Future<bool>` | Remove single key |
| `keys` | `Iterable<String>` | Registered entry keys |
| `dispose()` | `void` | Stop auto-save, release resources |

#### Supporting Types

| Type | Description |
|------|-------------|
| `RelicAdapter` | Abstract storage backend — implement `read`, `write`, `delete` |
| `InMemoryRelicAdapter` | Built-in adapter for testing |
| `RelicEntry<T>` | Typed config: `core`, `toJson`, `fromJson` |

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
| `onInit()` | `void` | Lifecycle hook |
| `onDispose()` | `void` | Lifecycle hook |
| `dispose()` | `void` | Dispose store and all managed nodes |

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

## Atlas Integration (package:titan_atlas)

### HeraldAtlasObserver

An `AtlasObserver` that emits Herald events for all navigation actions.

```dart
Atlas(
  passages: [...],
  observers: [HeraldAtlasObserver()],
);
```

#### Events

| Event | Description |
|-------|-------------|
| `AtlasRouteChanged` | Navigation event with `from` (Waypoint?), `to` (Waypoint), `type` (AtlasNavigationType) |
| `AtlasGuardRedirect` | Guard redirect with `originalPath`, `redirectPath` |
| `AtlasDriftRedirect` | Drift redirect with `originalPath`, `redirectPath` |
| `AtlasRouteNotFound` | 404 event with `path` |

| `AtlasNavigationType` | Description |
|------------------------|-------------|
| `push` | Forward navigation via `Atlas.to()` |
| `pop` | Backward navigation via `Atlas.back()` |
| `replace` | Replace current route via `Atlas.replace()` |
| `reset` | Reset stack via `Atlas.reset()` |

---

## Form Management (package:titan)

### Scroll\<T\>

Reactive form field with validation, dirty tracking, and reset. Extends `TitanState<T>`.

#### Constructor

```dart
Scroll<T>(
  T initialValue, {
  String? Function(T value)? validator,
  String? name,
  bool Function(T, T)? equals,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | `T` | Get/set current value (inherited from Core) |
| `error` | `String?` | Current validation error, or `null` if valid |
| `isDirty` | `bool` | Whether the value differs from the initial value |
| `isPristine` | `bool` | Whether the value equals the initial value |
| `isTouched` | `bool` | Whether the field has been touched |
| `isValid` | `bool` | Whether the field has no validation error |
| `initialValue` | `T` | The initial value this field was created with |
| `managedNodes` | `List<ReactiveNode>` | Internal reactive nodes (error, touched) |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `validate()` | `bool` | Run validator, update `error`, return `true` if valid |
| `touch()` | `void` | Mark the field as touched |
| `reset()` | `void` | Reset to initial value, clear error and touched state |
| `setError(String?)` | `void` | Set error manually (e.g., server-side validation) |
| `clearError()` | `void` | Clear error without re-validating |
| `dispose()` | `void` | Dispose field and internal nodes |

#### Pillar Factory Method

```dart
@protected
Scroll<T> scroll<T>(T value, {String? Function(T)? validator, String? name, bool Function(T, T)? equals})
```

---

### ScrollGroup

Manages a collection of `Scroll` fields as a form.

#### Constructor

```dart
ScrollGroup(List<Scroll<dynamic>> fields)
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isValid` | `bool` | Whether all fields are valid |
| `isDirty` | `bool` | Whether any field has been modified |
| `isPristine` | `bool` | Whether all fields have their initial values |
| `isTouched` | `bool` | Whether any field has been touched |
| `invalidFields` | `List<Scroll>` | Fields that currently have errors |
| `fieldCount` | `int` | Number of fields in the group |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `validateAll()` | `bool` | Validate all fields, return `true` if all valid |
| `resetAll()` | `void` | Reset all fields to initial values and clear errors |
| `touchAll()` | `void` | Touch all fields |
| `clearAllErrors()` | `void` | Clear all errors without re-validating |

---

## Data Layer (package:titan)

### Codex\<T\>

Paginated data management with reactive state.

#### Constructor

```dart
Codex<T>({
  required Future<CodexPage<T>> Function(CodexRequest request) fetcher,
  int pageSize = 20,
  String? name,
})
```

#### Reactive State

| Property | Type | Description |
|----------|------|-------------|
| `items` | `TitanState<List<T>>` | All accumulated items across loaded pages |
| `isLoading` | `TitanState<bool>` | Whether a page is currently being fetched |
| `hasMore` | `TitanState<bool>` | Whether more pages are available |
| `currentPage` | `TitanState<int>` | Current page number (0-indexed) |
| `error` | `TitanState<Object?>` | Most recent error, or `null` |

#### Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| `isEmpty` | `bool` | Whether items are empty and not loading |
| `isNotEmpty` | `bool` | Whether any items have been loaded |
| `itemCount` | `int` | Total number of items loaded so far |
| `managedNodes` | `List<TitanState>` | All internal reactive nodes |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `loadFirst()` | `Future<void>` | Load first page, clearing existing data |
| `loadNext()` | `Future<void>` | Load next page, appending to existing items |
| `refresh()` | `Future<void>` | Reload from page 0 (alias for `loadFirst`) |
| `dispose()` | `void` | Dispose all managed state |

#### Pillar Factory Method

```dart
@protected
Codex<T> codex<T>(Future<CodexPage<T>> Function(CodexRequest) fetcher, {int pageSize = 20, String? name})
```

#### Supporting Types

| Type | Description |
|------|-------------|
| `CodexPage<T>` | Page result: `items` (List\<T\>), `hasMore` (bool), `nextCursor` (String?) |
| `CodexRequest` | Page request: `page` (int), `pageSize` (int), `cursor` (String?) |

---

### Quarry\<T\>

Reactive data fetching with caching, stale-while-revalidate, and retry.

#### Constructor

```dart
Quarry<T>({
  required Future<T> Function() fetcher,
  Duration? staleTime,
  QuarryRetry retry = const QuarryRetry(maxAttempts: 0),
  String? name,
})
```

#### Reactive State

| Property | Type | Description |
|----------|------|-------------|
| `data` | `TitanState<T?>` | Fetched data, or `null` if not yet fetched |
| `isLoading` | `TitanState<bool>` | Whether the initial fetch is in progress (no data yet) |
| `isFetching` | `TitanState<bool>` | Whether a background refetch is in progress (data exists) |
| `error` | `TitanState<Object?>` | Most recent error, or `null` |

#### Computed Properties

| Property | Type | Description |
|----------|------|-------------|
| `hasData` | `bool` | Whether data exists |
| `hasError` | `bool` | Whether there is an error |
| `isStale` | `bool` | Whether cached data is stale |
| `managedNodes` | `List<TitanState>` | All internal reactive nodes |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `fetch()` | `Future<void>` | Fetch data (stale-while-revalidate, deduplication) |
| `refetch()` | `Future<void>` | Force refetch, ignoring staleness |
| `invalidate()` | `void` | Mark data stale without refetching |
| `setData(T)` | `void` | Set data manually (optimistic update) |
| `reset()` | `void` | Clear all data, errors, and timing |
| `dispose()` | `void` | Dispose all managed state |

#### Pillar Factory Method

```dart
@protected
Quarry<T> quarry<T>({required Future<T> Function() fetcher, Duration? staleTime, QuarryRetry retry, String? name})
```

#### Supporting Types

| Type | Description |
|------|-------------|
| `QuarryRetry` | Retry config: `maxAttempts` (int, default 3), `baseDelay` (Duration, default 1s). Exponential backoff. |

---

## Multi-Pillar Widgets (package:titan_bastion)

### Confluence

Auto-tracking consumer widgets that combine multiple typed Pillars in a single builder.

Each Pillar is resolved independently using the same order as Vestige:
1. Nearest **Beacon** in the widget tree
2. Global **Titan** registry

#### Confluence2\<A, B\>

```dart
const Confluence2<A extends Pillar, B extends Pillar>({
  required Widget Function(BuildContext context, A pillarA, B pillarB) builder,
})
```

#### Confluence3\<A, B, C\>

```dart
const Confluence3<A extends Pillar, B extends Pillar, C extends Pillar>({
  required Widget Function(BuildContext context, A pillarA, B pillarB, C pillarC) builder,
})
```

#### Confluence4\<A, B, C, D\>

```dart
const Confluence4<A extends Pillar, B extends Pillar, C extends Pillar, D extends Pillar>({
  required Widget Function(BuildContext context, A pillarA, B pillarB, C pillarC, D pillarD) builder,
})
```

---

## Debug Overlay (package:titan_bastion)

### Lens

In-app debug overlay displaying real-time Pillars, Herald events, Vigil errors, and Chronicle logs.

#### Constructor

```dart
const Lens({
  required Widget child,
  bool enabled = true,
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `child` | `Widget` | The app widget to wrap |
| `enabled` | `bool` | Whether the overlay is enabled (typically `kDebugMode`) |

#### Static Methods

| Method | Return | Description |
|--------|--------|-------------|
| `Lens.show()` | `void` | Show the debug overlay |
| `Lens.hide()` | `void` | Hide the debug overlay |
| `Lens.toggle()` | `void` | Toggle overlay visibility |

#### Overlay Tabs

| Tab | Content |
|-----|--------|
| Pillars | All registered Pillars and their types |
| Herald | Recent cross-domain events |
| Vigil | Captured errors with severity and context |
| Chronicle | Structured log output |

---

### LensLogSink

A `LogSink` that captures log entries into a bounded buffer for display by Lens.

#### Constructor

```dart
LensLogSink({int maxEntries = 200})
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `entries` | `List<LogEntry>` | All captured log entries (read-only, newest last) |
| `maxEntries` | `int` | Maximum entries to retain (default: 200) |
| `onEntry` | `void Function()?` | Callback invoked when a new entry is captured |
| `clear()` | `void` | Clear all captured entries |

---

[← Advanced Patterns](08-advanced-patterns.md) · [Migration Guide →](10-migration-guide.md)
