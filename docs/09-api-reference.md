# API Reference

Complete reference for all public APIs in the `titan`, `titan_bastion`, `titan_atlas`, and `titan_colossus` packages.

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
| `core<T>(T value, {String? name, bool Function(T,T)? equals, List<Conduit<T>>? conduits})` | `TitanState<T>` | Create a managed reactive Core |
| `derived<T>(T Function() compute, {String? name})` | `TitanComputed<T>` | Create a managed Derived value |
| `prism<S, R>(TitanState<S> source, R Function(S) selector, {String? name, bool Function(R, R)? equals})` | `Prism<R>` | Create a managed state projection |
| `nexusList<T>([List<T>? initial, String? name])` | `NexusList<T>` | Create a managed reactive list |
| `nexusMap<K, V>([Map<K, V>? initial, String? name])` | `NexusMap<K, V>` | Create a managed reactive map |
| `nexusSet<T>([Set<T>? initial, String? name])` | `NexusSet<T>` | Create a managed reactive set |
| `epoch<T>(T value, {int maxHistory, String? name})` | `Epoch<T>` | Create a managed Core with undo/redo |
| `watch(dynamic Function() fn, {bool fireImmediately})` | `TitanEffect` | Create a managed reactive side effect |
| `trove<K, V>({Duration? defaultTtl, int? maxEntries, ...})` | `Trove<K, V>` | Create a managed TTL/LRU cache *(titan_basalt extension)* |
| `moat({int maxTokens, Duration refillRate, ...})` | `Moat` | Create a managed token-bucket rate limiter *(titan_basalt extension)* |

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
Core<T>(T initialValue, {String? name, bool Function(T, T)? equals, List<Conduit<T>>? conduits})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `initialValue` | `T` | Initial value |
| `name` | `String?` | Debug name for logging |
| `equals` | `bool Function(T, T)?` | Custom equality function |
| `conduits` | `List<Conduit<T>>?` | Middleware pipeline for value changes |

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | `T` | Get/set current value (tracks on read, notifies on write) |
| `name` | `String?` | Debug name |
| `conduits` | `List<Conduit<T>>` | Attached conduits (unmodifiable) |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `peek()` | `T` | Read without dependency tracking |
| `update(T Function(T) updater)` | `void` | Transform current value |
| `silent(T value)` | `void` | Set without notifying dependents (bypasses conduits) |
| `listen(void Function(T) callback)` | `void Function()` | Listen for changes, returns unsubscribe |
| `addConduit(Conduit<T> conduit)` | `void` | Add a Conduit to the pipeline |
| `removeConduit(Conduit<T> conduit)` | `bool` | Remove a Conduit (returns true if found) |
| `clearConduits()` | `void` | Remove all Conduits |
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

### CoreRefresh

Bridges Titan's reactive `Core` signals to Flutter's `Listenable`. Use with Atlas's `refreshListenable` parameter for reactive Sentinel/Drift re-evaluation.

```dart
class CoreRefresh extends ChangeNotifier
```

#### Constructor

| Parameter | Type | Description |
|-----------|------|-------------|
| `cores` | `List<ReactiveNode>` | Reactive nodes to observe (typically `Core<T>` or `Derived<T>`) |

#### Methods

| Method | Description |
|--------|-------------|
| `dispose()` | Removes all listeners and cleans up |

#### Atlas `refreshListenable` Parameter

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `refreshListenable` | `Listenable?` | `null` | When notified, re-evaluates current path through Drift → Sentinels → per-route redirect |

```dart
final auth = Titan.get<AuthPillar>();
Atlas(
  passages: [...],
  sentinels: [Garrison.authGuard(...)],
  refreshListenable: CoreRefresh([auth.isLoggedIn]),
);
```

### Garrison.guestOnly

Creates a Sentinel that blocks authenticated users from guest-only pages (login, register).

```dart
static Sentinel guestOnly({...})
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `isAuthenticated` | `bool Function()` | required | Auth check callback |
| `guestPaths` | `Set<String>` | required | Paths only accessible to guests |
| `redirectPath` | `String` | required | Default path to redirect authenticated users |
| `useRedirectQuery` | `bool` | `true` | When true, checks for `redirect` query param and navigates there instead |

When `useRedirectQuery` is enabled (default), the Sentinel reads the `redirect` query parameter from the URL and URI-decodes it as the redirect target. This enables seamless post-login redirect when combined with `authGuard`'s `preserveRedirect`.

### Garrison.refreshAuth

Convenience factory that combines `authGuard` + `guestOnly` Sentinels with a `CoreRefresh` listenable in one call.

```dart
static GarrisonAuth refreshAuth({...})
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `isAuthenticated` | `bool Function()` | required | Auth check callback |
| `cores` | `List<ReactiveNode>` | required | Reactive nodes to observe |
| `loginPath` | `String` | required | Path to redirect unauthenticated users |
| `homePath` | `String` | required | Path to redirect authenticated users from guest pages |
| `publicPaths` | `Set<String>` | `{}` | Paths exempt from auth guard |
| `publicPrefixes` | `Set<String>` | `{}` | Path prefixes exempt from auth guard |
| `guestPaths` | `Set<String>?` | `null` | Guest-only paths (if set, adds guestOnly Sentinel) |
| `preserveRedirect` | `bool` | `true` | Store original path in redirect query param |

#### Returns

`GarrisonAuth` with:
- `sentinels` — `List<Sentinel>` to pass to Atlas
- `refresh` — `Listenable` to pass to Atlas's `refreshListenable`

```dart
final auth = Garrison.refreshAuth(
  isAuthenticated: () => pillar.isLoggedIn.value,
  cores: [pillar.isLoggedIn],
  loginPath: '/login',
  homePath: '/',
  guestPaths: {'/login'},
);
Atlas(sentinels: auth.sentinels, refreshListenable: auth.refresh, ...);
```

---

## Authentication & Authorization (package:titan_argus)

### Argus

Abstract base class for auth Pillars. Provides `isLoggedIn` Core, `signIn`/`signOut` lifecycle contract, and `guard()` convenience.

```dart
class AuthPillar extends Argus {
  late final username = core<String?>(null);

  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    await strikeAsync('sign-in', () async {
      username.value = credentials?['name'] as String?;
      isLoggedIn.value = true;
    });
  }

  @override
  void signOut() {
    strike('sign-out', () {
      username.value = null;
      super.signOut();
    });
  }
}
```

#### Properties & Methods

| Member | Type | Description |
|--------|------|-------------|
| `isLoggedIn` | `Core<bool>` | Reactive auth state (starts `false`) |
| `authCores` | `List<ReactiveNode>` | Nodes that trigger route re-evaluation (default: `[isLoggedIn]`) |
| `signIn([credentials])` | `Future<void>` | Override to implement sign-in |
| `signOut()` | `void` | Override to implement sign-out (call `super.signOut()`) |
| `guard(...)` | `GarrisonAuth` | Creates sentinels + refresh in one call |

### Argus.guard()

Convenience method that creates `authGuard` + `guestOnly` Sentinels and a `CoreRefresh` from `authCores`:

```dart
final (:sentinels, :refreshListenable) = auth.guard(
  loginPath: '/login',
  publicPaths: {'/login', '/register'},
  guestPaths: {'/login'},
);

Atlas(sentinels: sentinels, refreshListenable: refreshListenable, ...);
```

### Cartograph

Static utility for deep link parsing, URL building, and named route mapping.

| Method | Return | Description |
|--------|--------|-------------|
| `name(routeName, path)` | `void` | Register a named route |
| `nameAll(Map)` | `void` | Register multiple named routes |
| `build(name, {runes, query})` | `String` | Build URL from named route |
| `buildFromTemplate(template, {runes, query})` | `String` | Build URL from template |
| `parse(Uri)` | `CartographMatch?` | Match URI against registered patterns |
| `handleDeepLink(Uri)` | `bool` | Parse + invoke registered handler |
| `link(template, [handler])` | `void` | Register deep link handler |
| `reset()` | `void` | Clear all registrations |

### Obs

Ultra-simple auto-tracking reactive widget. Rebuilds only when tracked values change.

```dart
Obs(() => Text('${count.value}'))
Obs.builder((context) => Text('${count.value}'))
```

### Rampart

Responsive layout builder that adapts to screen width using Material 3 breakpoints.

| Class | Purpose |
|-------|---------|
| `Rampart` | Main responsive builder with `compact`/`medium`/`expanded` builders |
| `RampartBreakpoints` | Configurable breakpoint thresholds |
| `RampartLayout` | Enum: `compact`, `medium`, `expanded` |
| `RampartValue<T>` | Tier-dependent value with `resolve(layout)` |
| `RampartVisibility` | Show/hide child based on layout tier |
| `RampartContext` | Extension: `context.rampartLayout`, `context.isCompact`, etc. |

---

## Performance Monitoring (package:titan_colossus)

### Colossus

Enterprise performance monitoring Pillar. Extends `Pillar`. Singleton.

```dart
class Colossus extends Pillar
```

| Method | Return | Description |
|--------|--------|-------------|
| `Colossus.init({tremors, vesselConfig, ...})` | `Colossus` | Initialize monitoring singleton |
| `Colossus.shutdown()` | `void` | Stop monitoring and clean up all resources |
| `Colossus.instance` | `Colossus` | Access the singleton instance |
| `Colossus.isActive` | `bool` | Whether Colossus has been initialized |
| `decree()` | `Decree` | Generate a comprehensive performance report |
| `recordRebuild(label)` | `void` | Record a widget rebuild (called by Echo) |
| `reset()` | `void` | Reset all metrics and start fresh |
| `pulse` | `Pulse` | Frame metrics monitor |
| `vessel` | `Vessel` | Memory and leak detection monitor |
| `stride` | `Stride` | Page load timing monitor |
| `rebuildsPerWidget` | `Map<String, int>` | Widget rebuild counts by label |

### Pulse

Frame timing monitor — tracks FPS, jank, build/raster times via `addTimingsCallback`.

```dart
class Pulse
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `fps` | `double` | Current estimated FPS |
| `totalFrames` | `int` | Total frames measured |
| `jankFrames` | `int` | Janky frames (> 16ms) |
| `jankRate` | `double` | Jank percentage (0–100) |
| `avgBuildTime` | `Duration` | Rolling average build duration |
| `avgRasterTime` | `Duration` | Rolling average raster duration |
| `history` | `List<FrameMark>` | Recent frame history |
| `processTimings(timings)` | `void` | Process `List<FrameTiming>` from Flutter |
| `recordFrame({build, raster, total})` | `void` | Manually record a frame |
| `reset()` | `void` | Clear all frame metrics |

### Stride

Page load timing monitor — measures navigation-to-first-paint duration.

```dart
class Stride
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `history` | `List<PageLoadMark>` | Recorded page loads |
| `lastPageLoad` | `PageLoadMark?` | Most recent page load |
| `avgPageLoad` | `Duration` | Average page load duration |
| `startTiming(path, {pattern})` | `void` | Start timing a page load (auto-completes on next frame) |
| `record(path, duration, {pattern})` | `void` | Manually record a page load |
| `reset()` | `void` | Clear all page load data |

### Vessel

Memory monitor — tracks Pillar instances and detects leaks via periodic timer.

```dart
class Vessel
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `pillarCount` | `int` | Live Pillar instances |
| `totalInstances` | `int` | Total Titan DI instances |
| `leakSuspects` | `List<LeakSuspect>` | Suspected memory leaks |
| `exemptTypes` | `Set<String>` | Types exempt from leak detection |
| `snapshot()` | `MemoryMark` | Take a memory snapshot |
| `exempt(typeName)` | `void` | Mark a type as long-lived |
| `start()` / `stop()` | `void` | Start/stop periodic checks |
| `reset()` | `void` | Clear all tracking data |

### Echo

Rebuild tracking widget — wraps a child and counts rebuilds.

```dart
class Echo extends StatelessWidget
```

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | Widget identifier for tracking |
| `child` | `Widget` | The widget to wrap |

### Tremor

Configurable performance alert threshold.

```dart
class Tremor
```

| Factory | Description |
|---------|-------------|
| `Tremor.fps({threshold, severity, once})` | Alert when FPS drops below threshold |
| `Tremor.jankRate({threshold, severity, once})` | Alert when jank rate exceeds threshold |
| `Tremor.pageLoad({threshold, severity, once})` | Alert when page load exceeds duration |
| `Tremor.memory({maxPillars, severity, once})` | Alert when Pillar count exceeds limit |
| `Tremor.rebuilds({threshold, widget, severity, once})` | Alert on excessive widget rebuilds |
| `Tremor.leaks({severity, once})` | Alert when leak suspects are detected |

| Method | Return | Description |
|--------|--------|-------------|
| `evaluate(context)` | `bool` | Check if threshold is breached |
| `reset()` | `void` | Reset fired state |

### Decree

Aggregated performance report with health verdict.

```dart
class Decree
```

| Property | Type | Description |
|----------|------|-------------|
| `totalFrames` / `jankFrames` | `int` | Frame counts |
| `avgFps` | `double` | Average FPS |
| `jankRate` | `double` | Jank percentage |
| `avgBuildTime` / `avgRasterTime` | `Duration` | Average frame durations |
| `pageLoads` | `List<PageLoadMark>` | All recorded page loads |
| `pillarCount` / `totalInstances` | `int` | Memory counts |
| `leakSuspects` | `List<LeakSuspect>` | Leak suspects |
| `rebuildsPerWidget` | `Map<String, int>` | Rebuild counts |
| `health` | `PerformanceHealth` | `good` / `fair` / `poor` |
| `summary` | `String` | Human-readable report |
| `topRebuilders(n)` | `List<MapEntry>` | Top N rebuilding widgets |
| `slowestPageLoad` | `PageLoadMark?` | Slowest recorded page load |

### Mark

Base performance measurement data class.

```dart
class Mark
```

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Human-readable label |
| `category` | `MarkCategory` | `frame` / `pageLoad` / `memory` / `rebuild` / `custom` |
| `duration` | `Duration` | Measured duration |
| `timestamp` | `DateTime` | When recorded |
| `metadata` | `Map<String, dynamic>?` | Optional key-value metadata |

**Subclasses**: `FrameMark`, `PageLoadMark`, `RebuildMark`, `MemoryMark`

### ColossusLensTab

Lens plugin — adds a "Perf" tab to the Lens debug overlay with Pulse/Stride/Vessel/Echo sub-tabs.

```dart
class ColossusLensTab extends LensPlugin
```

### ColossusAtlasObserver

Atlas observer — automatically starts Stride timing on every navigation event.

```dart
class ColossusAtlasObserver extends AtlasObserver
```

### Inscribe

Report exporter — converts a Decree into Markdown, JSON, or a self-contained HTML dashboard.

```dart
class Inscribe
```

| Method | Return | Description |
|--------|--------|-------------|
| `Inscribe.markdown(decree)` | `String` | Markdown report with tables and health badge |
| `Inscribe.json(decree)` | `String` | Pretty-printed JSON using `Decree.toMap()` |
| `Inscribe.html(decree)` | `String` | Self-contained HTML dashboard with embedded CSS |

### InscribeIO

File-based report export — saves Decree to disk. Uses `dart:io` (mobile/desktop/server only).

```dart
class InscribeIO
```

| Method | Return | Description |
|--------|--------|-------------|
| `InscribeIO.saveMarkdown(decree, {directory, filename})` | `Future<String>` | Save Markdown report, returns file path |
| `InscribeIO.saveJson(decree, {directory, filename})` | `Future<String>` | Save JSON report, returns file path |
| `InscribeIO.saveHtml(decree, {directory, filename})` | `Future<String>` | Save HTML dashboard, returns file path |
| `InscribeIO.saveAll(decree, {directory})` | `Future<SaveResult>` | Save all three formats, returns `SaveResult` |

### Shade

Gesture recording controller. Records pointer events as Imprints during user sessions.

#### Methods

| Method / Property | Type | Description |
|-------------------|------|-------------|
| `shade.isRecording` | `bool` | Whether currently recording |
| `shade.currentEventCount` | `int` | Events recorded in current session |
| `shade.elapsed` | `Duration` | Time since recording started |
| `shade.startRecording({name, description, screenSize, devicePixelRatio})` | `void` | Start recording pointer events |
| `shade.stopRecording()` | `ShadeSession` | Stop recording and return the session |
| `shade.cancelRecording()` | `void` | Cancel recording without producing a session |
| `shade.recordPointerEvent(event)` | `void` | Record a single pointer event |
| `shade.onRecordingStarted` | `void Function()?` | Callback when recording starts |
| `shade.onRecordingStopped` | `void Function(ShadeSession)?` | Callback when recording stops |
| `shade.onImprintCaptured` | `void Function(Imprint)?` | Callback per captured event |

### Imprint

A single recorded pointer event with position, timing, and metadata.

#### Constructor

```dart
Imprint({
  required ImprintType type,
  required double positionX,
  required double positionY,
  required Duration timestamp,
  int pointer = 0,
  int deviceKind = 0,
  int buttons = 0,
  double deltaX = 0,
  double deltaY = 0,
  double scrollDeltaX = 0,
  double scrollDeltaY = 0,
  double pressure = 1.0,
})
```

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `toMap()` | `Map<String, dynamic>` | Serialize to JSON-compatible map |
| `Imprint.fromMap(map)` | `Imprint` | Deserialize from map |

### ShadeSession

A complete recorded interaction session with metadata and ordered Imprints.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Unique session identifier |
| `name` | `String` | Human-readable session name |
| `recordedAt` | `DateTime` | When the session was recorded |
| `duration` | `Duration` | Total recording duration |
| `screenWidth` | `double` | Screen width at recording time |
| `screenHeight` | `double` | Screen height at recording time |
| `devicePixelRatio` | `double` | Device pixel ratio at recording time |
| `imprints` | `List<Imprint>` | Ordered list of recorded events |
| `eventCount` | `int` | Number of recorded events |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `toJson()` | `String` | Serialize to JSON string |
| `ShadeSession.fromJson(json)` | `ShadeSession` | Deserialize from JSON string |
| `toMap()` | `Map<String, dynamic>` | Serialize to map |
| `ShadeSession.fromMap(map)` | `ShadeSession` | Deserialize from map |

### Phantom

Replays recorded ShadeSession as synthetic pointer events via GestureBinding.

#### Constructor

```dart
Phantom({
  bool normalizePositions = true,
  double speedMultiplier = 1.0,
  void Function(int current, int total)? onProgress,
  void Function(PhantomResult result)? onComplete,
  void Function()? onCancelled,
})
```

#### Methods

| Method / Property | Type | Description |
|-------------------|------|-------------|
| `phantom.isReplaying` | `bool` | Whether currently replaying |
| `phantom.replay(session)` | `Future<PhantomResult>` | Replay a recorded session |
| `phantom.cancel()` | `void` | Cancel in-progress replay |

### PhantomResult

The outcome of a Phantom replay session.

| Property | Type | Description |
|----------|------|-------------|
| `sessionName` | `String` | Name of the replayed session |
| `eventsDispatched` | `int` | Events successfully dispatched |
| `eventsSkipped` | `int` | Events skipped (unsupported types) |
| `expectedDuration` | `Duration` | Original recording duration |
| `actualDuration` | `Duration` | How long the replay actually took |
| `wasNormalized` | `bool` | Whether positions were normalized |
| `wasCancelled` | `bool` | Whether replay was cancelled |
| `totalEvents` | `int` | Dispatched + skipped |
| `speedRatio` | `double` | Actual / expected duration ratio |

### ShadeListener

Transparent widget that captures all pointer events for Shade recording.

```dart
ShadeListener(
  shade: shade,
  child: MaterialApp(...),
)
```

### ShadeVault

Session persistence and auto-replay configuration for Shade recordings.

```dart
final vault = ShadeVault(directory: '/path/to/sessions');

// Save / load sessions
await vault.save(session);
final summaries = await vault.listSessions(); // List<ShadeSessionSummary>
final loaded = await vault.load(summaries.first.id);

// Auto-replay config
await vault.setAutoReplayConfig(ShadeAutoReplayConfig(
  enabled: true,
  sessionId: session.id,
  speed: 2.0,
));
```

| Method | Return | Description |
|--------|--------|-------------|
| `save(session)` | `Future<void>` | Persist a session to disk |
| `load(id)` | `Future<ShadeSession?>` | Load a session by ID |
| `listSessions()` | `Future<List<ShadeSessionSummary>>` | List all saved sessions |
| `delete(id)` | `Future<void>` | Delete a session |
| `setAutoReplayConfig(config)` | `Future<void>` | Set auto-replay configuration |
| `getAutoReplayConfig()` | `Future<ShadeAutoReplayConfig?>` | Get current config |

### ShadeTextController

Auto-recording `TextEditingController` that registers with Shade for direct text replay.

```dart
final controller = ShadeTextController(
  shade: shade,
  fieldId: 'hero_name',
);

TextField(controller: controller)
```

During replay, Phantom injects text directly via `setValueSilently()`, bypassing the keyboard.

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

## Data Layer (package:titan_basalt)

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

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

## Debug Overlay (package:titan_colossus)

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

## Enterprise Features

### Conduit

Core-level middleware that intercepts, transforms, or rejects individual value changes.

#### Abstract Class

```dart
abstract class Conduit<T> {
  T pipe(T oldValue, T newValue);
  void onPiped(T oldValue, T newValue) {}
}
```

#### Built-in Conduits

| Class | Description |
|-------|-------------|
| `ClampConduit<T extends num>({required T min, required T max})` | Clamp numeric values to a range |
| `TransformConduit<T>(T Function(T old, T new) transform)` | Apply a transformation function |
| `ValidateConduit<T>(String? Function(T old, T new) validator)` | Reject values that fail validation |
| `FreezeConduit<T>(bool Function(T old, T new) freezeWhen)` | Block changes once a condition is met |
| `ThrottleConduit<T>(Duration minInterval)` | Reject changes faster than minimum interval |

#### ConduitRejectedException

| Property | Type | Description |
|----------|------|-------------|
| `message` | `String?` | Why the change was rejected |
| `rejectedValue` | `Object?` | The value that was rejected |

---

### Prism

Fine-grained, memoized state projection from one or more source Cores.

#### Constructors & Static Factories

```dart
Prism<T>(TitanState<dynamic> source, T Function(dynamic) selector, {String? name, bool Function(T, T)? equals})
Prism.of<S, R>(TitanState<S> source, R Function(S) selector, {String? name, bool Function(R, R)? equals})
Prism.combine2<A, B, R>(TitanState<A> s1, TitanState<B> s2, R Function(A, B) combiner, {String? name, bool Function(R, R)? equals})
Prism.combine3<A, B, C, R>(TitanState<A> s1, TitanState<B> s2, TitanState<C> s3, R Function(A, B, C) combiner, {String? name, bool Function(R, R)? equals})
Prism.combine4<A, B, C, D, R>(TitanState<A> s1, TitanState<B> s2, TitanState<C> s3, TitanState<D> s4, R Function(A, B, C, D) combiner, {String? name, bool Function(R, R)? equals})
Prism.fromDerived<S, R>(TitanComputed<S> source, R Function(S) selector, {String? name, bool Function(R, R)? equals})
```

#### Pillar Factory

```dart
prism<S, R>(TitanState<S> source, R Function(S) selector, {String? name, bool Function(R, R)? equals})
```

#### Extension Method

```dart
// On TitanState<T> (Core<T>)
Prism<R> prism<R>(R Function(T) selector, {String? name, bool Function(R, R)? equals})
```

#### PrismEquals

| Method | Type | Description |
|--------|------|-------------|
| `PrismEquals.list<T>` | `bool Function(List<T>, List<T>)` | Element-by-element list comparison |
| `PrismEquals.set<T>` | `bool Function(Set<T>, Set<T>)` | Set contents comparison |
| `PrismEquals.map<K,V>` | `bool Function(Map<K,V>, Map<K,V>)` | Key-value map comparison |

#### Inherited from TitanComputed

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `value` | `T` | Current projected value (read-only) |
| `previousValue` | `T?` | Previous projected value |
| `name` | `String?` | Optional debug name |
| `addListener(callback)` | `void` | Listen for value changes |
| `removeListener(callback)` | `void` | Remove a listener |
| `dispose()` | `void` | Dispose the Prism |

---

### Nexus — Reactive Collections

In-place reactive collections with granular change tracking.

#### NexusList\<T\>

**Constructor**: `NexusList<T>({List<T>? initial, String? name})`

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `value` | `List<T>` | The underlying list (tracked read) |
| `length` | `int` | Number of elements (tracked) |
| `isEmpty` / `isNotEmpty` | `bool` | Emptiness checks (tracked) |
| `first` / `last` | `T` | First/last element (tracked) |
| `[index]` | `T` | Read element at index (tracked) |
| `contains(element)` | `bool` | Check membership (tracked) |
| `indexOf(element)` | `int` | Find index (tracked) |
| `items` | `Iterable<T>` | Iterable view (tracked) |
| `add(element)` | `void` | Append element |
| `addAll(iterable)` | `void` | Append multiple elements |
| `insert(index, element)` | `void` | Insert at index |
| `[index] =` | `void` | Update element (skip if equal) |
| `remove(element)` | `bool` | Remove first occurrence |
| `removeAt(index)` | `T` | Remove at index |
| `removeWhere(test)` | `int` | Remove matching, return count |
| `retainWhere(test)` | `int` | Keep matching, return removed count |
| `sort([compare])` | `void` | Sort in place |
| `replaceRange(start, end, replacement)` | `void` | Replace range |
| `clear()` | `void` | Remove all elements |
| `swap(i, j)` | `void` | Swap two elements |
| `move(from, to)` | `void` | Move element to new position |
| `lastChange` | `NexusChange<T>?` | Most recent change record |

#### NexusMap\<K, V\>

**Constructor**: `NexusMap<K, V>({Map<K, V>? initial, String? name})`

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `value` | `Map<K, V>` | The underlying map (tracked read) |
| `length` | `int` | Number of entries (tracked) |
| `isEmpty` / `isNotEmpty` | `bool` | Emptiness checks (tracked) |
| `keys` / `values` / `entries` | `Iterable` | Map views (tracked) |
| `[key]` | `V?` | Read value for key (tracked) |
| `containsKey(key)` | `bool` | Check key existence (tracked) |
| `containsValue(value)` | `bool` | Check value existence (tracked) |
| `[key] =` | `void` | Set entry |
| `putIfChanged(key, value)` | `bool` | Set only if value differs |
| `putIfAbsent(key, ifAbsent)` | `V` | Set if key absent |
| `addAll(entries)` | `void` | Merge entries |
| `remove(key)` | `V?` | Remove entry |
| `removeWhere(test)` | `int` | Remove matching, return count |
| `updateAll(update)` | `void` | Transform all values |
| `clear()` | `void` | Remove all entries |
| `lastChange` | `NexusChange<MapEntry<K, V>>?` | Most recent change record |

#### NexusSet\<T\>

**Constructor**: `NexusSet<T>({Set<T>? initial, String? name})`

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `value` | `Set<T>` | The underlying set (tracked read) |
| `length` | `int` | Number of elements (tracked) |
| `isEmpty` / `isNotEmpty` | `bool` | Emptiness checks (tracked) |
| `contains(element)` | `bool` | Check membership (tracked) |
| `elements` | `Iterable<T>` | Iterable view (tracked) |
| `add(element)` | `bool` | Add element (false if exists) |
| `addAll(iterable)` | `void` | Add multiple elements |
| `remove(element)` | `bool` | Remove element |
| `toggle(element)` | `bool` | Add if absent, remove if present |
| `removeWhere(test)` | `int` | Remove matching, return count |
| `retainWhere(test)` | `int` | Keep matching, return removed count |
| `clear()` | `void` | Remove all elements |
| `intersection(other)` | `Set<T>` | Intersection (read-only) |
| `union(other)` | `Set<T>` | Union (read-only) |
| `difference(other)` | `Set<T>` | Difference (read-only) |
| `lastChange` | `NexusChange<T>?` | Most recent change record |

#### NexusChange Hierarchy

| Type | Fields | When |
|------|--------|------|
| `NexusInsert<T>` | `index`, `element` | List element inserted |
| `NexusRemove<T>` | `index`, `element` | List element removed |
| `NexusUpdate<T>` | `index`, `oldValue`, `newValue` | List element updated |
| `NexusClear<T>` | `previousLength` | Collection cleared |
| `NexusMapSet<K,V>` | `key`, `oldValue`, `newValue`, `isNew` | Map entry set |
| `NexusMapRemove<K,V>` | `key`, `value` | Map entry removed |
| `NexusSetAdd<T>` | `element` | Set element added |
| `NexusSetRemove<T>` | `element` | Set element removed |
| `NexusBatch<T>` | `operation`, `count` | Batch operation |

---

### Loom

Finite state machine with reactive state, lifecycle hooks, and transition history.

#### Constructor (Pillar factory)

```dart
loom<S, E>({
  required S initial,
  required Map<(S, E), S> transitions,
  Map<S, void Function()>? onEnter,
  Map<S, void Function()>? onExit,
  void Function(S from, E event, S to)? onTransition,
  int maxHistory = 100,
  String? name,
})
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `current` | `S` | Current state (reactive) |
| `state` | `Core<S>` | Underlying reactive Core |
| `isIn(S state)` | `bool` | Check if in a specific state (reactive) |
| `canSend(E event)` | `bool` | Check if an event is valid from current state |
| `allowedEvents` | `Set<E>` | Set of valid events from current state |
| `send(E event)` | `bool` | Attempt transition; returns true on success |
| `sendOrThrow(E event)` | `void` | Attempt transition; throws on invalid |
| `history` | `List<LoomTransition<S, E>>` | Transition history |
| `reset(S state)` | `void` | Reset to a specific state, clear history |

#### LoomTransition

| Property | Type | Description |
|----------|------|-------------|
| `from` | `S` | Source state |
| `event` | `E` | Event that triggered the transition |
| `to` | `S` | Destination state |

---

### Bulwark *(Deprecated)*

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`
>
> **Deprecated:** Use **Portcullis** instead (superset). Bulwark will be removed in v2.0.

Reactive circuit breaker for resilient async operations.

#### Constructor (Pillar factory)

```dart
bulwark<T>({
  int failureThreshold = 3,
  Duration resetTimeout = const Duration(seconds: 30),
  void Function(Object error)? onOpen,
  void Function()? onClose,
  void Function()? onHalfOpen,
  String? name,
})
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `state` | `BulwarkState` | Current state: `closed`, `open`, or `halfOpen` (reactive) |
| `stateCore` | `Core<BulwarkState>` | Underlying reactive Core |
| `failureCount` | `int` | Consecutive failure count (reactive) |
| `lastError` | `Object?` | Most recent error (reactive) |
| `isClosed` | `bool` | Whether the circuit is closed |
| `isOpen` | `bool` | Whether the circuit is open |
| `isHalfOpen` | `bool` | Whether the circuit is in recovery |
| `call(Future<T> Function() action)` | `Future<T>` | Execute through the breaker |
| `reset()` | `void` | Manually close the circuit |
| `trip([Object? error])` | `void` | Manually open the circuit |
| `dispose()` | `void` | Dispose all internal state |

#### BulwarkOpenException

| Property | Type | Description |
|----------|------|-------------|
| `failureCount` | `int` | Failures that triggered the circuit |
| `lastError` | `Object?` | Last error |

---

### Saga

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

Multi-step async workflow with compensation (rollback) on failure.

#### Constructor (Pillar factory)

```dart
saga<T>({
  required List<SagaStep<T>> steps,
  void Function(T? result)? onComplete,
  void Function(Object error, String failedStep)? onError,
  void Function(String stepName, int index, int total)? onStepComplete,
  void Function(Object error, StackTrace stackTrace, String stepName)? onCompensationError,
  String? name,
})
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `status` | `SagaStatus` | `idle`, `running`, `completed`, `compensating`, `failed` (reactive) |
| `currentStep` | `int` | Current step index, -1 when not started (reactive) |
| `currentStepName` | `String?` | Name of current step |
| `progress` | `double` | Progress 0.0–1.0 (reactive) |
| `error` | `Object?` | Error if failed (reactive) |
| `result` | `T?` | Final result if completed (reactive) |
| `compensationErrors` | `List<({Object error, StackTrace stackTrace, String stepName})>` | Errors from failed compensation steps |
| `isRunning` | `bool` | Whether currently executing |
| `totalSteps` | `int` | Total number of steps |
| `run()` | `Future<T?>` | Execute all steps; compensates on failure |
| `reset()` | `void` | Reset to idle (clears compensation errors) |
| `dispose()` | `void` | Dispose internal state |

#### SagaStep

```dart
SagaStep<T>({
  required String name,
  required Future<T?> Function(T? previousResult) execute,
  Future<void> Function(T? result)? compensate,
})
```

---

### Volley

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

Batch async operations with concurrency control and partial-failure handling.

#### Constructor (Pillar factory)

```dart
volley<T>({
  int concurrency = 5,
  int maxRetries = 0,
  Duration retryDelay = const Duration(milliseconds: 100),
  Duration? taskTimeout,
  void Function(String taskName, T value)? onTaskComplete,
  void Function(String taskName, Object error)? onTaskFailed,
  String? name,
})
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `status` | `VolleyStatus` | `idle`, `running`, `done`, `cancelled` (reactive) |
| `progress` | `double` | Progress 0.0–1.0 (reactive) |
| `completedCount` | `int` | Number of completed tasks (reactive) |
| `totalCount` | `int` | Total tasks (reactive) |
| `successCount` | `int` | Number of successful tasks (reactive) |
| `failedCount` | `int` | Number of failed tasks (reactive) |
| `isRunning` | `bool` | Whether currently executing |
| `isDisposed` | `bool` | Whether disposed |
| `execute(List<VolleyTask<T>> tasks)` | `Future<List<VolleyResult<T>>>` | Run batch with concurrency limit |
| `cancel()` | `void` | Cancel execution |
| `reset()` | `void` | Reset to idle |
| `dispose()` | `void` | Dispose internal state |

#### VolleyTask / VolleyResult

```dart
VolleyTask<T>({
  required String name,
  required Future<T> Function() execute,
  Duration? timeout, // per-task timeout override
})
```

`VolleyResult<T>` is a sealed class: `VolleySuccess<T>` (with `value`) or `VolleyFailure<T>` (with `error`, `stackTrace`). Common getters: `taskName`, `isSuccess`, `isFailure`, `valueOrNull`, `errorOrNull`.

---

### Annals

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

Static audit trail for Core mutations. Immutable, append-only, FIFO-evicted.

| Method | Type | Description |
|--------|------|-------------|
| `Annals.enable({int maxEntries})` | `void` | Enable auditing |
| `Annals.disable()` | `void` | Disable auditing |
| `Annals.record(AnnalEntry entry)` | `void` | Record an entry |
| `Annals.entries` | `List<AnnalEntry>` | All entries (unmodifiable) |
| `Annals.length` | `int` | Entry count |
| `Annals.stream` | `Stream<AnnalEntry>` | Broadcast stream of entries (lazy-initialized) |
| `Annals.query({...})` | `List<AnnalEntry>` | Filter by coreName, pillarType, action, userId, after, before, limit |
| `Annals.export({...})` | `List<Map<String, dynamic>>` | Export as serializable maps |
| `Annals.clear()` | `void` | Clear all entries |
| `Annals.reset()` | `void` | Clear, disable, reset max |
| `Annals.dispose()` | `void` | Close stream controller, clear entries, disable |

#### AnnalEntry

```dart
AnnalEntry({
  required String coreName,
  String? pillarType,
  required dynamic oldValue,
  required dynamic newValue,
  DateTime? timestamp,
  String? action,
  String? userId,
  Map<String, dynamic>? metadata,
})
```

---

### Tether

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

Instance-based request-response channels between Pillars with global convenience API.

#### Constructor (Pillar factory)

```dart
tether({String? name})
```

#### Instance API

| Method/Property | Type | Description |
|-----------------|------|-------------|
| `register<Req, Res>(name, handler, {timeout})` | `void` | Register a typed handler |
| `unregister(name)` | `bool` | Remove a handler |
| `has(name)` | `bool` | Check if registered |
| `call<Req, Res>(name, request, {timeout})` | `Future<Res>` | Invoke and await response |
| `tryCall<Req, Res>(name, request, {timeout})` | `Future<Res?>` | Returns null if not registered |
| `names` | `Set<String>` | All registered names |
| `registeredCount` | `int` | Number of registered handlers (reactive) |
| `callCount` | `int` | Total calls made (reactive) |
| `lastCallTime` | `DateTime?` | Timestamp of last call (reactive) |
| `errorCount` | `int` | Total failed calls (reactive) |
| `reset()` | `void` | Clear all registrations |
| `dispose()` | `void` | Dispose instance and reactive state |

#### Global Convenience API (via `Tether.global`)

| Method | Type | Description |
|--------|------|-------------|
| `Tether.registerGlobal<Req, Res>(name, handler, {timeout})` | `void` | Register on global instance |
| `Tether.unregisterGlobal(name)` | `bool` | Remove from global instance |
| `Tether.hasGlobal(name)` | `bool` | Check global registry |
| `Tether.callGlobal<Req, Res>(name, request, {timeout})` | `Future<Res>` | Call on global instance |
| `Tether.tryCallGlobal<Req, Res>(name, request, {timeout})` | `Future<Res?>` | Safe call on global instance |
| `Tether.globalNames` | `Set<String>` | All global names |
| `Tether.resetGlobal()` | `void` | Reset global instance |

---

### Aegis

Static retry utility with configurable backoff strategies.

| Method | Type | Description |
|--------|------|-------------|
| `Aegis.run<T>(operation, {maxAttempts, baseDelay, maxDelay, strategy, jitter, retryIf, onRetry})` | `Future<T>` | Execute with retry |
| `Aegis.runWithConfig<T>(operation, {config, onRetry})` | `Future<AegisResult<T>>` | Execute with config object |

Strategies: `BackoffStrategy.exponential`, `.constant`, `.linear`.

`onRetry` signature: `void Function(int attempt, Object error, Duration nextDelay)?`

---

### Sigil

Static feature flag management with reactive reads.

| Method | Type | Description |
|--------|------|-------------|
| `Sigil.register(name, initialValue)` | `void` | Register a boolean flag |
| `Sigil.loadAll(Map<String, bool>)` | `void` | Bulk-register flags |
| `Sigil.unregister(name)` | `bool` | Remove a flag |
| `Sigil.isEnabled(name)` | `bool` | Reactive read |
| `Sigil.isDisabled(name)` | `bool` | Inverse reactive read |
| `Sigil.has(name)` | `bool` | Check if registered |
| `Sigil.names` | `Set<String>` | All registered names |
| `Sigil.peek(name)` | `bool` | Non-reactive read |
| `Sigil.coreOf(name)` | `Core<bool>?` | Underlying reactive Core |
| `Sigil.enable(name)` | `void` | Set flag true |
| `Sigil.disable(name)` | `void` | Set flag false |
| `Sigil.toggle(name)` | `bool` | Toggle, returns new value |
| `Sigil.set(name, value)` | `void` | Set explicit value |
| `Sigil.override(name, value)` | `void` | Override for testing |
| `Sigil.clearOverride(name)` | `void` | Clear one override |
| `Sigil.clearOverrides()` | `void` | Clear all overrides |
| `Sigil.reset()` | `void` | Dispose all flags |

---

### Trove\<K, V\>

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

Reactive in-memory cache with TTL expiry and LRU eviction. O(1) for all operations.

#### Constructor

```dart
Trove<K, V>({
  Duration? defaultTtl,
  int? maxEntries,
  void Function(K, V, TroveEvictionReason)? onEvict,
  Duration cleanupInterval = const Duration(seconds: 60),
  String? name,
})
```

#### Pillar Factory

```dart
trove<K, V>({Duration? defaultTtl, int? maxEntries, ...}) → Trove<K, V>
```

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `get(key)` | `V?` | Retrieve cached value (lazy expiry) |
| `put(key, value, {ttl})` | `void` | Store value with optional per-entry TTL |
| `putIfAbsent(key, compute)` | `V` | Store only if key absent/expired |
| `getOrPut(key, compute)` | `Future<V>` | Async fetch-or-cache |
| `putAll(map, {ttl})` | `void` | Batch store |
| `getAll(keys)` | `Map<K, V>` | Batch retrieve (skips missing/expired) |
| `evict(key)` | `bool` | Manually evict an entry |
| `clear()` | `void` | Clear all entries |
| `reset()` | `void` | Clear entries and reset stats |
| `containsKey(key)` | `bool` | Check existence (no hit/miss tracking) |
| `remainingTtl(key)` | `Duration?` | Time until entry expires |
| `isExpired(key)` | `bool` | Whether entry has expired |
| `dispose()` | `void` | Dispose cache and timers |

#### Reactive State

| Property | Type | Description |
|----------|------|-------------|
| `size` | `Core<int>` | Current entry count |
| `hits` | `Core<int>` | Total cache hits |
| `misses` | `Core<int>` | Total cache misses |
| `evictions` | `Core<int>` | Total evictions |
| `hitRate` | `double` | Hit rate percentage (0.0–100.0) |
| `missRate` | `double` | Miss rate percentage (0.0–100.0) |

#### TroveEvictionReason

| Value | Description |
|-------|-------------|
| `expired` | TTL elapsed |
| `capacity` | LRU eviction (cache full) |
| `manual` | `evict()` or `clear()` called |

---

### Moat

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

Token-bucket rate limiter with reactive state and per-key quotas.

#### Constructor

```dart
Moat({
  int maxTokens = 10,
  Duration refillRate = const Duration(seconds: 1),
  int? initialTokens,
  void Function()? onReject,
  String? name,
})
```

#### Pillar Factory

```dart
moat({int maxTokens, Duration refillRate, ...}) → Moat
```

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `tryConsume([tokens])` | `bool` | Non-blocking: consume or reject |
| `consume({tokens, timeout})` | `Future<bool>` | Blocking: wait for token with optional timeout |
| `guard<T>(action, {onLimit, tokens})` | `Future<T?>` | Execute if allowed, null if rejected |
| `reset()` | `void` | Refill bucket and clear stats |
| `dispose()` | `void` | Cancel timers and dispose state |

#### Reactive State

| Property | Type | Description |
|----------|------|-------------|
| `remainingTokens` | `Core<int>` | Available tokens |
| `rejections` | `Core<int>` | Total rejected requests |
| `consumed` | `Core<int>` | Total consumed tokens |
| `hasTokens` | `bool` | Whether tokens available |
| `isEmpty` | `bool` | Whether bucket empty |
| `fillPercentage` | `double` | Bucket fill level (0.0–100.0) |
| `timeToNextToken` | `Duration` | Time until next refill |

---

### MoatPool

Per-key rate limiter pool sharing a common configuration.

#### Constructor

```dart
MoatPool({
  int maxTokens = 10,
  Duration refillRate = const Duration(seconds: 1),
  int? initialTokens,
})
```

| Method | Return | Description |
|--------|--------|-------------|
| `tryConsume(key, [tokens])` | `bool` | Consume from key-specific bucket |
| `get(key)` | `Moat` | Get or create limiter for key |
| `containsKey(key)` | `bool` | Check if key has a limiter |
| `remove(key)` | `bool` | Remove and dispose key's limiter |
| `keys` | `Iterable<String>` | All active keys |
| `length` | `int` | Number of active limiters |
| `dispose()` | `void` | Dispose all limiters |

---

### Omen\<T\>

Reactive async computed value with automatic dependency tracking. The async counterpart to `Derived`.

#### Constructor

```dart
Omen<T>(
  Future<T> Function() compute, {
  Duration? debounce,
  bool keepPreviousData = true,
  String? name,
  bool eager = true,
})
```

#### Pillar Factory

```dart
omen<T>(Future<T> Function() compute, {Duration? debounce, ...}) → Omen<T>
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | `AsyncValue<T>` | Current state (reactive — auto-tracked) |
| `state` | `TitanState<AsyncValue<T>>` | Underlying reactive state node |
| `data` | `T?` | Current data if available |
| `isLoading` | `bool` | Whether currently loading |
| `hasData` | `bool` | Whether data is available |
| `hasError` | `bool` | Whether in error state |
| `isRefreshing` | `bool` | Whether refreshing with previous data |
| `executionCount` | `TitanState<int>` | Reactive execution counter |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `refresh()` | `void` | Force re-execution regardless of dependency changes |
| `cancel()` | `void` | Cancel in-flight computation |
| `reset()` | `void` | Clear state, reset counter, re-execute |
| `dispose()` | `void` | Cancel, clear deps, dispose state |

---

### Pyre\<T\>

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

Priority-ordered async task queue with concurrency control, backpressure, and retry.

#### Constructor

```dart
Pyre<T>({
  int concurrency = 3,
  int? maxQueueSize,
  int maxRetries = 0,
  Duration retryDelay = const Duration(milliseconds: 500),
  bool autoStart = true,
  void Function(String taskId, T result)? onTaskComplete,
  void Function(String taskId, Object error)? onTaskFailed,
  void Function()? onDrained,
  String? name,
})
```

#### Pillar Factory

```dart
pyre<T>({int concurrency, int? maxQueueSize, int maxRetries, ...}) → Pyre<T>
```

#### Reactive Properties

| Property | Type | Description |
|----------|------|-------------|
| `status` | `PyreStatus` | Queue status: idle, processing, paused, stopped (reactive) |
| `queueLength` | `int` | Number of pending tasks (reactive) |
| `runningCount` | `int` | Number of currently executing tasks (reactive) |
| `completedCount` | `int` | Total successfully completed tasks (reactive) |
| `failedCount` | `int` | Total failed tasks (reactive) |
| `totalEnqueued` | `int` | Total tasks ever enqueued (reactive) |
| `progress` | `double` | Completion ratio 0.0–1.0 (reactive) |
| `hasPending` | `bool` | Whether tasks are queued |
| `isProcessing` | `bool` | Whether actively processing |
| `isDisposed` | `bool` | Whether disposed |
| `concurrency` | `int` | Concurrency limit |
| `managedNodes` | `List<TitanState>` | All reactive state nodes (for Pillar disposal) |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `enqueue(task, {priority, id})` | `Future<PyreResult<T>>` | Add task, returns result future |
| `enqueueAll(tasks, {priority})` | `List<Future<PyreResult<T>>>` | Batch enqueue |
| `start()` | `void` | Start processing (when `autoStart: false`) |
| `pause()` | `void` | Suspend processing |
| `resume()` | `void` | Resume processing |
| `cancel(id)` | `bool` | Cancel a pending task by ID |
| `cancelAll()` | `void` | Cancel all pending tasks |
| `drain()` | `Future<void>` | Cancel pending, wait for running |
| `stop()` | `void` | Permanently stop the queue |
| `reset()` | `void` | Clear state and restart |
| `peek()` | `String?` | ID of next task to execute |
| `dispose()` | `void` | Stop and dispose all state |

#### Enums & Types

| Type | Values / Fields | Description |
|------|----------------|-------------|
| `PyrePriority` | `critical`, `high`, `normal`, `low` | Task priority levels |
| `PyreStatus` | `idle`, `processing`, `paused`, `stopped` | Queue lifecycle status |
| `PyreResult<T>` | sealed: `PyreSuccess<T>`, `PyreFailure<T>` | Task completion result |
| `PyreBackpressureException` | `message`, `queueSize`, `maxSize` | Thrown when queue is full |

---

### Mandate

Reactive policy evaluation engine with declarative [Writ] rules.

#### Constructor

```
Mandate({
  List<Writ> writs = const [],
  MandateStrategy strategy = MandateStrategy.allOf,
  String? name,
})
```

#### Pillar Factory

```
mandate({List<Writ> writs, MandateStrategy strategy, String? name}) → Mandate
```

#### Reactive Properties

| Property | Type | Description |
|----------|------|-------------|
| `verdict` | `TitanComputed<MandateVerdict>` | Composite reactive verdict |
| `isGranted` | `TitanComputed<bool>` | Convenience: `true` when granted |
| `violations` | `TitanComputed<List<WritViolation>>` | Current violation list (empty when granted) |

#### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `can(name)` | `TitanComputed<bool>` | Query individual writ by name |
| `addWrit(writ)` | `void` | Add a writ (throws if duplicate name) |
| `addWrits(writs)` | `void` | Batch add (single re-evaluation) |
| `removeWrit(name)` | `bool` | Remove writ by name |
| `replaceWrit(writ)` | `void` | Replace writ (same name, new logic) |
| `updateStrategy(strategy)` | `void` | Change combination strategy |
| `dispose()` | `void` | Dispose all internal nodes |

#### Inspection

| Property | Type | Description |
|----------|------|-------------|
| `writNames` | `List<String>` | Names of all registered writs |
| `writCount` | `int` | Number of registered writs |
| `hasWrit(name)` | `bool` | Whether a writ with this name exists |
| `strategy` | `MandateStrategy` | Current combination strategy |
| `name` | `String?` | Debug name |
| `isDisposed` | `bool` | Whether disposed |

#### Types

| Type | Values / Fields | Description |
|------|----------------|-------------|
| `MandateStrategy` | `allOf`, `anyOf`, `majority` | Combination mode |
| `MandateVerdict` | sealed: `MandateGrant`, `MandateDenial` | Evaluation result |
| `MandateGrant` | `isGranted: true`, `violations: []` | All required rules passed |
| `MandateDenial` | `isGranted: false`, `violations: [...]` | One or more rules failed |
| `WritViolation` | `writName`, `reason` | Details of a failed writ |

#### Writ

```
Writ({
  required String name,
  required bool Function() evaluate,
  String? description,
  String? reason,
  int weight = 1,
})
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String` | Unique identifier |
| `evaluate` | `bool Function()` | Reactive rule function |
| `description` | `String?` | Human-readable description |
| `reason` | `String?` | Denial reason |
| `weight` | `int` | Weight for majority strategy (default: 1) |

---

### Ledger

Reactive state transaction manager with atomic commit/rollback.

#### Constructor

```
Ledger({int maxHistory = 100, String? name})
```

#### Pillar Factory

```
ledger({int maxHistory = 100, String? name}) → Ledger
```

#### Reactive Properties

| Property | Type | Description |
|----------|------|-------------|
| `activeCount` | `int` (reactive via `TitanState`) | Number of currently active transactions |
| `commitCount` | `int` (reactive via `TitanState`) | Total committed transactions |
| `rollbackCount` | `int` (reactive via `TitanState`) | Total rolled-back transactions |
| `failCount` | `int` (reactive via `TitanState`) | Total failed transactions |
| `hasActive` | `bool` (reactive via `TitanComputed`) | Whether any transaction is active |
| `history` | `List<LedgerRecord>` | Transaction history (most recent last) |

#### Transaction API

| Method | Return | Description |
|--------|--------|-------------|
| `begin({name})` | `LedgerTransaction` | Start a manual transaction |
| `transact(action, {name})` | `Future<T>` | Auto-commit/rollback async scope |
| `transactSync(action, {name})` | `T` | Auto-commit/rollback sync scope |
| `dispose()` | `void` | Dispose all internal nodes |

#### Inspection

| Property | Type | Description |
|----------|------|-------------|
| `activeTransactionIds` | `List<int>` | IDs of active transactions |
| `lastRecord` | `LedgerRecord?` | Most recent completed record |
| `totalStarted` | `int` | Total transactions ever started |
| `name` | `String?` | Debug name |
| `isDisposed` | `bool` | Whether disposed |

### LedgerTransaction

Individual atomic transaction scope.

| Property / Method | Type / Return | Description |
|-------------------|--------|-------------|
| `id` | `int` | Transaction ID |
| `name` | `String?` | Debug name |
| `status` | `LedgerStatus` | Current status |
| `isActive` | `bool` | Whether still active |
| `coreCount` | `int` | Number of captured Cores |
| `capture(core)` | `void` | Record Core's value before mutation |
| `commit()` | `void` | Commit all changes atomically |
| `rollback()` | `void` | Revert all captured Cores |

### LedgerRecord

Completed transaction audit entry.

| Field | Type | Description |
|-------|------|-------------|
| `id` | `int` | Transaction ID |
| `status` | `LedgerStatus` | Final status |
| `coreCount` | `int` | Number of modified Cores |
| `timestamp` | `DateTime` | When completed |
| `error` | `Object?` | Error (if failed) |
| `name` | `String?` | Transaction name |

### LedgerStatus

| Value | Description |
|-------|-------------|
| `active` | Transaction is open |
| `committed` | Successfully committed |
| `rolledBack` | Manually rolled back |
| `failed` | Failed due to exception |

---

### Portcullis

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

Reactive circuit breaker for service resilience.

#### Constructor

```
Portcullis({
  int failureThreshold = 5,
  Duration resetTimeout = const Duration(seconds: 30),
  int halfOpenMaxProbes = 1,
  bool Function(Object error, StackTrace stack)? shouldTrip,
  int maxTripHistory = 20,
  String? name,
})
```

#### Pillar Factory

```
portcullis({
  int failureThreshold = 5,
  Duration resetTimeout = const Duration(seconds: 30),
  int halfOpenMaxProbes = 1,
  bool Function(Object, StackTrace)? shouldTrip,
  int maxTripHistory = 20,
  String? name,
}) → Portcullis
```

#### Reactive Properties

| Property | Type | Description |
|----------|------|-------------|
| `state` | `PortcullisState` (reactive via `TitanState`) | Current circuit state |
| `failureCount` | `int` (reactive via `TitanState`) | Consecutive failures in current cycle |
| `successCount` | `int` (reactive via `TitanState`) | Total successful calls |
| `tripCount` | `int` (reactive via `TitanState`) | Total circuit trips |
| `lastTrip` | `DateTime?` (reactive via `TitanState`) | When last tripped |
| `lastFailure` | `Object?` (reactive via `TitanState`) | Last error that failed |
| `probeSuccessCount` | `int` (reactive via `TitanState`) | Consecutive probe successes in half-open |
| `isClosed` | `bool` (reactive via `TitanComputed`) | Whether circuit is healthy |

#### Protection API

| Method | Return | Description |
|--------|--------|-------------|
| `protect(action)` | `Future<T>` | Execute with circuit breaker protection |
| `protectSync(action)` | `T` | Synchronous protected execution |
| `trip()` | `void` | Manually open the circuit |
| `reset()` | `void` | Manually close the circuit |
| `dispose()` | `void` | Dispose all internal nodes |

#### Inspection

| Property | Type | Description |
|----------|------|-------------|
| `tripHistory` | `List<PortcullisTripRecord>` | Trip audit records |
| `name` | `String?` | Debug name |
| `isDisposed` | `bool` | Whether disposed |
| `failureThreshold` | `int` | Configured failure threshold |
| `resetTimeout` | `Duration` | Configured reset timeout |
| `halfOpenMaxProbes` | `int` | Probes needed to close |

#### Types

| Type | Values / Fields | Description |
|------|----------------|-------------|
| `PortcullisState` | `closed`, `open`, `halfOpen` | Circuit lifecycle state |
| `PortcullisOpenException` | `name`, `remainingTimeout` | Thrown when circuit is open |
| `PortcullisTripRecord` | `timestamp`, `failureCount`, `lastError` | Trip audit entry |

---

### Crucible

Testing harness for Pillars.

#### Constructor

```dart
Crucible<P extends Pillar>(P Function() factory)
Crucible.from(P pillar)
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `pillar` | `P` | The Pillar under test |
| `isDisposed` | `bool` | Whether disposed |
| `changes` | `List<CoreChange>` | All recorded changes |
| `expectCore<T>(core, expected)` | `void` | Assert a Core's value |
| `expectStrikeSync(action, {before, after})` | `void` | Assert sync Strike |
| `expectStrike(action, {before, after})` | `Future<void>` | Assert async Strike |
| `track<T>(core)` | `void` | Start recording changes on a Core |
| `changesFor<T>(core)` | `List<CoreChange<T>>` | Get changes for a Core |
| `valuesFor<T>(core)` | `List<T>` | Get values for a Core |
| `clearChanges()` | `void` | Clear all recordings |
| `dispose()` | `void` | Dispose Crucible and Pillar |

---

### Snapshot / PillarSnapshot

State capture and restore.

| Method | Type | Description |
|--------|------|-------------|
| `pillar.snapshot({String? label})` | `PillarSnapshot` | Capture all named Cores |
| `pillar.restore(snapshot, {bool notify})` | `void` | Restore from snapshot |
| `Snapshot.diff(a, b)` | `Map<String, (dynamic, dynamic)>` | Compare two snapshots |
| `snapshot.has(name)` | `bool` | Check if Core is captured |
| `snapshot.get<T>(name)` | `T?` | Get captured value |
| `snapshot.length` | `int` | Number of captured Cores |

---

### Additional Pillar Members

| Member | Type | Description |
|--------|------|-------------|
| `isReady` | `Core<bool>` | True after `onInitAsync()` completes |
| `autoDispose` | `bool` | Whether auto-dispose is enabled |
| `refCount` | `int` | Active consumer count |
| `enableAutoDispose()` | `void` | Enable auto-dispose |
| `ref()` | `void` | Increment reference count |
| `unref()` | `void` | Decrement reference count |
| `onInitAsync()` | `Future<void>` | Async initialization lifecycle hook |
| `onError(error, stackTrace)` | `void` | Error handler for strikeAsync/captureError |

---

### Additional Widgets (titan_bastion)

#### VestigeWhen

```dart
VestigeWhen<P extends Pillar>({
  required bool Function(P pillar) condition,
  required Widget Function(BuildContext, P) builder,
})
```

#### AnimatedVestige

```dart
AnimatedVestige<P extends Pillar>({
  required Duration duration,
  required Widget Function(BuildContext, P, Animation<double>) builder,
  Curve? curve,
})
```

#### VestigeSelector

```dart
VestigeSelector<P extends Pillar, T>({
  required T Function(P pillar) selector,
  required Widget Function(BuildContext, P, T) builder,
})
```

#### VestigeListener

```dart
VestigeListener<P extends Pillar>({
  required void Function(BuildContext, P) listener,
  required Widget child,
})
```

#### VestigeConsumer

```dart
VestigeConsumer<P extends Pillar>({
  required void Function(BuildContext, P) listener,
  required Widget Function(BuildContext, P) builder,
})
```

#### PillarScope

```dart
PillarScope({
  required List<Pillar> overrides,
  required Widget child,
})
```

#### Spark

Hooks-style widget that eliminates `StatefulWidget` boilerplate. Override `ignite()` and use hooks for state, lifecycle, and controllers.

```dart
class MySpark extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final count = useCore(0);
    final ctrl = useTextController();
    useEffect(() { /* side effect */ return cleanup; }, []);
    return Text('${count.value}');
  }
}
```

**Available Hooks:**

**Reactive Hooks:**

| Hook | Returns | Purpose |
|------|---------|---------|
| `useCore<T>(initial)` | `Core<T>` | Reactive state, auto-rebuilds |
| `useDerived<T>(compute)` | `Derived<T>` | Auto-tracked computed value |
| `useEffect(fn, [keys])` | `void` | Side effect with cleanup |
| `useMemo<T>(fn, [keys])` | `T` | Memoized computation |
| `useRef<T>(initial)` | `SparkRef<T>` | Mutable ref, no rebuild |
| `usePillar<P>(context)` | `P` | Find Pillar from Beacon/Titan |
| `useStream<T>(stream)` | `AsyncValue<T>` | Subscribe to stream, returns Ether snapshot |
| `useFuture<T>(future)` | `AsyncValue<T>` | Subscribe to Future, returns Ether snapshot |
| `useCallback<T>(fn, [keys])` | `T` | Memoized callback, stable identity |
| `useReducer<S,A>(reducer, init)` | `SparkStore<S,A>` | Redux-style reducer with `state` + `dispatch` |

**Value Hooks:**

| Hook | Returns | Purpose |
|------|---------|---------|
| `usePrevious<T>(value)` | `T?` | Previous value from last build |
| `useValueListenable<T>(vn)` | `T` | Subscribe to ValueListenable |
| `useValueChanged<T,R>(value, cb)` | `R?` | Callback when value changes |
| `useValueNotifier<T>(initial)` | `ValueNotifier<T>` | Auto-disposed ValueNotifier |
| `useDebounced<T>(value, duration)` | `T` | Debounced value, updates after delay |
| `useListenable(listenable)` | `void` | Subscribe to any Listenable |
| `useIsMounted()` | `bool Function()` | Closure checking if widget is mounted |

**Controller Hooks:**

| Hook | Returns | Purpose |
|------|---------|---------|
| `useTextController()` | `TextEditingController` | Auto-disposed |
| `useAnimationController()` | `AnimationController` | Auto-disposed, built-in vsync |
| `useFocusNode()` | `FocusNode` | Auto-disposed |
| `useScrollController()` | `ScrollController` | Auto-disposed |
| `useTabController(length:)` | `TabController` | Auto-disposed, built-in vsync |
| `usePageController()` | `PageController` | Auto-disposed |
| `useStreamController<T>()` | `StreamController<T>` | Auto-disposed |

**Lifecycle Hooks:**

| Hook | Returns | Purpose |
|------|---------|---------|
| `useAnimation(controller)` | `double` | Subscribe to animation, rebuilds on tick |
| `useAppLifecycleState()` | `AppLifecycleState?` | Current app lifecycle state |
| `useOnAppLifecycleStateChange(cb)` | `void` | Callback on lifecycle transitions |
| `useAutomaticKeepAlive({want: true})` | `void` | Keep widget alive in lazy lists |

---

## Anvil — Dead Letter & Retry Queue

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart';`

### Anvil Constructor

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `maxRetries` | `int` | `3` | Maximum retry attempts per entry |
| `backoff` | `AnvilBackoff?` | `exponential()` | Backoff strategy between retries |
| `maxDeadLetters` | `int` | `100` | Max dead letter entries to retain |
| `autoStart` | `bool` | `true` | Auto-process entries on enqueue |
| `name` | `String?` | `null` | Debug name |

### Pillar Factory

```dart
late final retryQueue = anvil<String>(
  maxRetries: 5,
  backoff: AnvilBackoff.exponential(jitter: true),
  name: 'retry',
);
```

### AnvilBackoff Factories

| Factory | Parameters | Description |
|---------|-----------|-------------|
| `AnvilBackoff.exponential()` | `initial`, `multiplier`, `jitter`, `maxDelay` | Delay doubles each attempt |
| `AnvilBackoff.linear()` | `initial`, `increment`, `jitter`, `maxDelay` | Delay increases linearly |
| `AnvilBackoff.constant(delay)` | `jitter` | Same delay every attempt |

### Reactive Properties

| Property | Type | Description |
|----------|------|-------------|
| `pendingCount` | `int` | Entries waiting for retry |
| `retryingCount` | `int` | Entries currently being retried |
| `succeededCount` | `int` | Entries that have succeeded |
| `deadLetterCount` | `int` | Entries in dead letter queue |
| `totalEnqueued` | `int` | Lifetime enqueue count |
| `isProcessing` | `bool` | Whether queue is actively processing |

### Enqueue API

| Method | Returns | Description |
|--------|---------|-------------|
| `enqueue(operation, {id, metadata, onSuccess, onDeadLetter, maxRetries})` | `AnvilEntry<T>` | Add operation to retry queue |
| `processAll()` | `void` | Manually process all pending (for autoStart: false) |
| `retryDeadLetters()` | `int` | Re-enqueue all dead letters, returns count |

### Queue Management

| Method | Returns | Description |
|--------|---------|-------------|
| `purge()` | `int` | Remove all dead letters, returns count |
| `clear()` | `void` | Remove all entries from all queues |
| `remove(id)` | `bool` | Remove entry by ID |
| `findById(id)` | `AnvilEntry<T>?` | Look up entry across all queues |

### Inspection

| Property | Type | Description |
|----------|------|-------------|
| `pending` | `List<AnvilEntry<T>>` | Current pending entries |
| `deadLetters` | `List<AnvilEntry<T>>` | Dead letter entries |
| `succeeded` | `List<AnvilEntry<T>>` | Succeeded entries |
| `name` | `String?` | Debug name |
| `maxRetries` | `int` | Queue default max retries |
| `isDisposed` | `bool` | Whether disposed |

### Types

| Type | Fields | Description |
|------|--------|-------------|
| `AnvilStatus` | `pending`, `retrying`, `succeeded`, `deadLettered` | Entry lifecycle state |
| `AnvilEntry<T>` | `id`, `status`, `attempts`, `maxRetries`, `lastError`, `result`, `metadata` | Individual queue entry |
| `AnvilBackoff` | `initial`, `jitter`, `maxDelay`, `computeDelay` | Backoff strategy config |

---

## Banner — Reactive Feature Flags

> **Package:** `titan_basalt` — `import 'package:titan_basalt/titan_basalt.dart'`

### Banner Constructor

```dart
Banner({
  required List<BannerFlag> flags,
  String? name,
})
```

### BannerFlag Constructor

```dart
const BannerFlag({
  required String name,
  bool defaultValue = false,
  List<BannerRule> rules = const [],
  double? rollout,         // 0.0–1.0
  DateTime? expiresAt,
  String? description,
})
```

### BannerRule Constructor

```dart
const BannerRule({
  required String name,
  required bool Function(Map<String, dynamic> context) evaluate,
  String? reason,
})
```

### Banner Methods

| Method | Return | Description |
|--------|--------|-------------|
| `isEnabled(name, {context, userId})` | `bool` | Evaluate flag with optional context and userId |
| `evaluate(name, {context, userId})` | `BannerEvaluation` | Full evaluation with reason |
| `operator [](name)` | `Core<bool>` | Reactive flag state |
| `setOverride(name, value)` | `void` | Force a flag value |
| `clearOverride(name)` | `void` | Remove override |
| `clearAllOverrides()` | `void` | Remove all overrides |
| `hasOverride(name)` | `bool` | Check if override exists |
| `updateFlags(values)` | `void` | Bulk update from remote config |
| `register(flag)` | `void` | Add flag at runtime |
| `unregister(name)` | `bool` | Remove flag |
| `has(name)` | `bool` | Check flag existence |
| `config(name)` | `BannerFlag?` | Get flag configuration |

### Banner Properties

| Property | Type | Description |
|----------|------|-------------|
| `names` | `List<String>` | All registered flag names |
| `count` | `int` | Number of flags |
| `enabledCount` | `Derived<int>` | Reactive enabled count |
| `totalCount` | `Derived<int>` | Reactive total count |
| `snapshot` | `Map<String, bool>` | All flag states |
| `overrides` | `Map<String, bool>` | Active overrides |
| `managedNodes` | `Iterable<ReactiveNode>` | Pillar lifecycle nodes |

### BannerEvaluation

| Field | Type | Description |
|-------|------|-------------|
| `flagName` | `String` | Evaluated flag |
| `enabled` | `bool` | Resolved value |
| `reason` | `BannerReason` | Why this value |
| `matchedRule` | `String?` | Rule that matched |

### BannerReason

| Value | Description |
|-------|-------------|
| `forceOverride` | Override set via `setOverride()` |
| `rule` | A BannerRule matched |
| `rollout` | Rollout percentage hash |
| `defaultValue` | No rules/rollout, using default |
| `expired` | Flag past expiresAt |
| `notFound` | Flag not registered |

---

## Sieve — Reactive Search, Filter & Sort

> **Package:** `titan_basalt`

### Sieve Constructor

```dart
Sieve<T>({
  List<T> items = const [],
  List<String Function(T)> textFields = const [],
  String? name,
})
```

### Sieve Methods

| Method | Return | Description |
|--------|--------|-------------|
| `setItems(List<T>)` | `void` | Replace the source dataset |
| `clearQuery()` | `void` | Clear the search query |
| `where(key, predicate)` | `void` | Add/replace a named filter |
| `removeWhere(key)` | `void` | Remove a named filter |
| `clearFilters()` | `void` | Remove all filters |
| `sortBy(Comparator<T>?)` | `void` | Set sort comparator (null to remove) |
| `reset()` | `void` | Clear query, filters, and sort |
| `hasFilter(key)` | `bool` | Check if filter exists |

### Sieve Properties

| Property | Type | Description |
|----------|------|-------------|
| `items` | `Core<List<T>>` | Source dataset (reactive) |
| `query` | `Core<String>` | Search query (reactive) |
| `results` | `Derived<List<T>>` | Filtered + sorted results |
| `resultCount` | `Derived<int>` | Count of results |
| `totalCount` | `Derived<int>` | Total source items |
| `isFiltered` | `Derived<bool>` | Any filter/search active |
| `filterKeys` | `List<String>` | Active filter names |
| `filterCount` | `int` | Number of active filters |
| `name` | `String?` | Debug name |
| `managedNodes` | `Iterable<ReactiveNode>` | Lifecycle nodes for Pillar |

### Pillar Extension

```dart
class MyPillar extends Pillar {
  late final search = sieve<Item>(
    items: inventory,
    textFields: [(i) => i.name],
    name: 'search',
  );
}
```

---

## Lattice — Reactive DAG Task Executor

> **Package:** `titan_basalt`

### Lattice Constructor

```dart
Lattice({String? name})
```

### Lattice Methods

| Method | Return | Description |
|--------|--------|-------------|
| `node(id, task, {dependsOn})` | `void` | Register a named task with dependencies |
| `execute()` | `Future<LatticeResult>` | Execute all tasks in dependency order |
| `reset()` | `void` | Reset to idle state for re-execution |
| `dependenciesOf(id)` | `List<String>` | Get dependencies of a node |

### Lattice Properties

| Property | Type | Description |
|----------|------|-------------|
| `status` | `Core<LatticeStatus>` | Current execution status (reactive) |
| `completedCount` | `Core<int>` | Number of completed tasks (reactive) |
| `progress` | `Derived<double>` | Completion ratio 0.0–1.0 (reactive) |
| `nodeCount` | `int` | Total number of registered nodes |
| `nodeIds` | `List<String>` | List of all registered node IDs |
| `hasCycle` | `bool` | Whether the graph has circular dependencies |
| `name` | `String?` | Debug name |
| `managedNodes` | `Iterable<ReactiveNode>` | Lifecycle nodes for Pillar |

### LatticeResult

| Property | Type | Description |
|----------|------|-------------|
| `values` | `Map<String, dynamic>` | Successful node results |
| `errors` | `Map<String, Object>` | Failed node errors |
| `elapsed` | `Duration` | Total wall-clock time |
| `executionOrder` | `List<String>` | Order nodes completed |
| `succeeded` | `bool` | `true` if no errors |

### LatticeStatus

| Value | Description |
|-------|-------------|
| `idle` | Not yet executed |
| `running` | Execution in progress |
| `completed` | All nodes finished successfully |
| `failed` | One or more nodes failed |

### Pillar Extension

```dart
class AppPillar extends Pillar {
  late final startup = lattice(name: 'startup');
}
```

---

## Embargo — Reactive Async Mutex/Semaphore

> **Package:** `titan_basalt`

### Embargo Constructor

```dart
Embargo({
  int permits = 1,
  Duration? timeout,
  String? name,
})
```

### Embargo Methods

| Method | Return | Description |
|--------|--------|-------------|
| `guard<T>(action, {timeout})` | `Future<T>` | Execute action with auto-release |
| `acquire({timeout})` | `Future<EmbargoLease>` | Manual permit acquisition |
| `reset()` | `void` | Release all permits, cancel waiters |

### Embargo Properties

| Property | Type | Description |
|----------|------|-------------|
| `isLocked` | `Derived<bool>` | All permits currently acquired |
| `activeCount` | `Core<int>` | Number of held permits (reactive) |
| `queueLength` | `Core<int>` | Number of waiting tasks (reactive) |
| `totalAcquires` | `Core<int>` | Lifetime acquire count (reactive) |
| `status` | `Derived<EmbargoStatus>` | available/busy/contended |
| `isAvailable` | `Derived<bool>` | Has a free permit |
| `canAcquire` | `bool` | Whether a permit is available now |
| `permits` | `int` | Maximum concurrent permits |
| `timeout` | `Duration?` | Default wait timeout |
| `name` | `String?` | Debug name |
| `managedNodes` | `Iterable<ReactiveNode>` | Lifecycle nodes for Pillar |

### EmbargoLease

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `release()` | `void` | Return the permit |
| `isReleased` | `bool` | Whether already released |
| `holdDuration` | `Duration` | Time permit has been held |

### EmbargoStatus

| Value | Description |
|-------|-------------|
| `available` | Free permits — executes immediately |
| `busy` | All permits held, no queue |
| `contended` | All permits held AND waiters queued |

### Pillar Extension

```dart
class ShopPillar extends Pillar {
  late final lock = embargo(name: 'buy');
  late final pool = embargo(permits: 3, name: 'api');
}
```

---

## Census — Sliding-Window Data Aggregation

### Constructor

```dart
Census<T extends num>({
  required Duration window,
  Core<T>? source,
  int maxEntries = 10000,
  String? name,
})
```

### Census Methods

| Method | Return | Description |
|--------|--------|-------------|
| `record(T value)` | `void` | Record a value into the window |
| `evict()` | `void` | Remove stale entries |
| `percentile(int p)` | `double` | Compute Nth percentile (0–100) |
| `reset()` | `void` | Clear all entries and aggregates |
| `dispose()` | `void` | Cancel source subscription |

### Census Properties

| Property | Type | Description |
|----------|------|-------------|
| `count` | `Core<int>` | Entries in the window (reactive) |
| `sum` | `Core<double>` | Sum of values (reactive) |
| `average` | `Derived<double>` | Mean of values (reactive) |
| `min` | `Core<double>` | Minimum value (reactive) |
| `max` | `Core<double>` | Maximum value (reactive) |
| `last` | `Core<double>` | Most recent value (reactive) |
| `entries` | `List<CensusEntry<T>>` | Snapshot of all entries |
| `window` | `Duration` | Sliding time window |
| `maxEntries` | `int` | Buffer size cap |
| `name` | `String?` | Debug name |
| `managedNodes` | `Iterable<ReactiveNode>` | Lifecycle nodes for Pillar |

### CensusEntry

| Property | Type | Description |
|----------|------|-------------|
| `value` | `T` | The recorded value |
| `timestamp` | `DateTime` | When it was recorded |

### Pillar Extension

```dart
class DashboardPillar extends Pillar {
  late final orderValue = core(0.0);
  late final stats = census<double>(
    source: orderValue,
    window: Duration(minutes: 5),
  );
}
```

---

## Warden

Reactive service health monitor with continuous polling, per-service reactive state, and aggregate health.

### `Warden`

```dart
Warden({
  required List<WardenService> services,
  required Duration interval,
  String? name,
})
```

| Property | Type | Description |
|----------|------|-------------|
| `overallHealth` | `Derived<ServiceStatus>` | Aggregate health of critical services |
| `healthyCount` | `Derived<int>` | Number of healthy services |
| `degradedCount` | `Derived<int>` | Number of degraded services |
| `isChecking` | `Core<bool>` | Whether a check is in progress |
| `totalChecks` | `Core<int>` | Total number of checks performed |
| `serviceNames` | `List<String>` | Names of all registered services |

| Method | Return | Description |
|--------|--------|-------------|
| `start()` | `void` | Start periodic health checks |
| `stop()` | `void` | Cancel all timers |
| `checkService(name)` | `Future<void>` | Force-check a single service |
| `checkAll()` | `Future<void>` | Force-check all services |
| `status(name)` | `Core<ServiceStatus>` | Per-service status |
| `latency(name)` | `Core<int>` | Last check latency in ms |
| `failures(name)` | `Core<int>` | Consecutive failure count |
| `lastChecked(name)` | `Core<DateTime?>` | Timestamp of last check |
| `reset()` | `void` | Reset all state and stop polling |
| `dispose()` | `void` | Dispose all resources |

### `WardenService`

```dart
WardenService({
  required String name,
  required Future<void> Function() check,
  Duration? interval,
  bool critical = true,
  int downThreshold = 3,
})
```

### `ServiceStatus`

```dart
enum ServiceStatus { unknown, healthy, degraded, down }
```

### Pillar Extension

```dart
class ApiPillar extends Pillar {
  late final health = warden(
    interval: Duration(seconds: 30),
    services: [
      WardenService(
        name: 'auth',
        check: () => api.ping('/auth/health'),
      ),
    ],
  );
}
```

---

## Arbiter

Reactive conflict resolution with pluggable strategies, per-submission tracking, and resolution history.

### `Arbiter<T>`

```dart
Arbiter<T>({
  required ArbiterStrategy strategy,
  T Function(List<ArbiterConflict<T>> candidates)? merge,
  bool autoResolve = false,
  String? name,
})
```

| Property | Type | Description |
|----------|------|-------------|
| `conflictCount` | `Core<int>` | Number of pending submissions |
| `lastResolution` | `Core<ArbiterResolution<T>?>` | Most recent resolution |
| `hasConflicts` | `Derived<bool>` | Whether 2+ submissions pending |
| `totalResolved` | `Core<int>` | Lifetime resolved count |

| Method | Return | Description |
|--------|--------|-------------|
| `submit(source, value)` | `ArbiterResolution<T>?` | Submit a value from a source |
| `resolve()` | `ArbiterResolution<T>?` | Auto-resolve using strategy |
| `accept(source)` | `ArbiterResolution<T>?` | Manually accept a source |
| `pending` | `List<ArbiterConflict<T>>` | All pending submissions |
| `sources` | `List<String>` | Names of pending sources |
| `history` | `List<ArbiterResolution<T>>` | All past resolutions |
| `reset()` | `void` | Clear all state |
| `dispose()` | `void` | Release reactive nodes |

### `ArbiterStrategy`

```dart
enum ArbiterStrategy { lastWriteWins, firstWriteWins, merge, manual }
```

### `ArbiterConflict<T>`

| Field | Type | Description |
|-------|------|-------------|
| `source` | `String` | Source identifier |
| `value` | `T` | Submitted value |
| `timestamp` | `DateTime` | When submitted |

### `ArbiterResolution<T>`

| Field | Type | Description |
|-------|------|-------------|
| `resolved` | `T` | Winning/merged value |
| `strategy` | `ArbiterStrategy` | Strategy used |
| `candidates` | `List<ArbiterConflict<T>>` | All candidates |
| `timestamp` | `DateTime` | When resolved |

### Pillar Extension

```dart
class SyncPillar extends Pillar {
  late final sync = arbiter<Quest>(
    strategy: ArbiterStrategy.lastWriteWins,
  );
}
```

---

## Lode

Reactive resource pool for managing reusable resources with lifecycle control.

### `Lode<T>`

```dart
Lode<T>({
  required Future<T> Function() create,
  Future<void> Function(T)? destroy,
  Future<bool> Function(T)? validate,
  int maxSize = 10,
  String? name,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `available` | `Core<int>` | Idle resources |
| `inUse` | `Core<int>` | Checked-out resources |
| `size` | `Core<int>` | Total pool size |
| `waiters` | `Core<int>` | Callers awaiting a resource |
| `utilization` | `Derived<double>` | inUse / maxSize (0.0–1.0) |
| `status` | `LodeStatus` | Current pool status |
| `maxSize` | `int` | Maximum pool capacity |

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `acquire({Duration? timeout})` | `Future<LodeLease<T>>` | Acquire a resource lease |
| `withResource<R>(fn)` | `Future<R>` | Acquire, execute, auto-release |
| `warmup(int count)` | `Future<void>` | Pre-create resources |
| `drain()` | `Future<void>` | Destroy idle resources |
| `dispose()` | `Future<void>` | Shut down the pool |

### `LodeLease<T>`

| Member | Type | Description |
|--------|------|-------------|
| `resource` | `T` | The leased resource |
| `release()` | `void` | Return to pool |
| `invalidate()` | `Future<void>` | Destroy instead of return |

### `LodeStatus`

```dart
enum LodeStatus { idle, active, exhausted, draining }
```

### Pillar Extension

```dart
class PoolPillar extends Pillar {
  late final pool = lode<DbConnection>(
    create: () async => DbConnection.open(),
    destroy: (c) async => c.close(),
    maxSize: 10,
  );
}
```

---

## Tithe

Reactive quota & budget manager for tracking cumulative consumption.

### `Tithe`

```dart
Tithe({
  required int budget,
  Duration? resetInterval,
  String? name,
})
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `consumed` | `Core<int>` | Total consumed in current period |
| `remaining` | `Derived<int>` | Budget - consumed |
| `exceeded` | `Derived<bool>` | Whether budget is exhausted |
| `ratio` | `Derived<double>` | consumed / budget (0.0–1.0+) |
| `breakdown` | `Core<Map<String, int>>` | Per-key consumption |
| `budget` | `int` | Configured budget |

#### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `consume(amount, {key})` | `void` | Deduct from budget, optionally per key |
| `tryConsume(amount, {key})` | `bool` | Consume if within budget, else false |
| `reset()` | `void` | Reset consumption and re-arm thresholds |
| `onThreshold(pct, fn)` | `void` | Register alert at percentage |
| `dispose()` | `void` | Cancel timers, dispose nodes |

### Pillar Extension

```dart
class ApiPillar extends Pillar {
  late final quota = tithe(
    budget: 1000,
    resetInterval: Duration(hours: 1),
  );
}
```

---

## Sluice

Reactive multi-stage data pipeline.

### `Sluice<T>`

```dart
Sluice<T>({
  required List<SluiceStage<T>> stages,
  int bufferSize = 256,
  SluiceOverflow overflow = SluiceOverflow.backpressure,
  void Function(T item)? onComplete,
  void Function(T item, Object error, String stageName)? onError,
  String? name,
})
```

#### Properties

| Property    | Type                   | Description                       |
|-------------|------------------------|-----------------------------------|
| `fed`       | `Core<int>`            | Total items fed                   |
| `completed` | `Core<int>`            | Items exiting final stage         |
| `failed`    | `Core<int>`            | Permanently failed items          |
| `inFlight`  | `Core<int>`            | Items currently in pipeline       |
| `status`    | `Core<SluiceStatus>`   | Pipeline lifecycle status         |
| `isIdle`    | `Derived<bool>`        | No items in pipeline              |
| `errorRate` | `Derived<double>`      | failed / fed ratio                |
| `stageNames`| `List<String>`         | Ordered stage names               |

#### Methods

| Method | Description |
|--------|-------------|
| `feed(T item)` | Feed item, returns `true` if accepted |
| `feedAll(Iterable<T>)` | Feed multiple, returns accepted count |
| `stage(String name)` | Get per-stage metrics |
| `pause()` | Pause processing |
| `resume()` | Resume after pause |
| `flush()` | Wait for all in-flight items |
| `dispose()` | Dispose pipeline |

### `SluiceStage<T>`

```dart
SluiceStage<T>({
  required String name,
  required FutureOr<T?> Function(T item) process,
  int concurrency = 1,
  int maxRetries = 0,
  Duration? timeout,
  void Function(T item, Object error)? onError,
})
```

### `SluiceStageMetrics`

| Property    | Type           | Description                  |
|-------------|----------------|------------------------------|
| `processed` | `Core<int>`    | Successfully processed       |
| `filtered`  | `Core<int>`    | Filtered out (null return)   |
| `errors`    | `Core<int>`    | Permanent failures           |
| `queued`    | `Core<int>`    | Waiting to be processed      |
| `isIdle`    | `Derived<bool>`| No work in this stage        |

### Pillar Extension

```dart
class OrderPillar extends Pillar {
  late final pipeline = sluice<Order>(
    stages: [
      SluiceStage(name: 'validate', process: (o) => validate(o)),
      SluiceStage(name: 'charge', process: (o) async => charge(o)),
    ],
  );
}
```

---

## Clarion API

### `Clarion`

```dart
Clarion({String? name})
```

| Method | Returns | Description |
|---|---|---|
| `schedule(name, interval, handler, {policy, immediate})` | `void` | Register a recurring job |
| `scheduleOnce(name, delay, handler)` | `void` | Register a one-shot delayed job |
| `unschedule(name)` | `void` | Cancel and remove a job |
| `trigger(name)` | `void` | Manually fire a job |
| `pause([name])` | `void` | Pause a job or all jobs |
| `resume([name])` | `void` | Resume a job or all jobs |
| `job(name)` | `ClarionJobState` | Per-job reactive state |
| `jobNames` | `List<String>` | All registered job names |
| `dispose()` | `void` | Cancel all timers |
| `managedNodes` | `List<ReactiveNode>` | Nodes for `Pillar.registerNodes` |

| Reactive Property | Type |
|---|---|
| `status` | `Core<ClarionStatus>` |
| `activeCount` | `Core<int>` |
| `totalRuns` | `Core<int>` |
| `totalErrors` | `Core<int>` |
| `successRate` | `Derived<double>` |
| `isIdle` | `Derived<bool>` |
| `jobCount` | `Core<int>` |

### `ClarionJobState`

| Property | Type |
|---|---|
| `isRunning` | `Core<bool>` |
| `runCount` | `Core<int>` |
| `errorCount` | `Core<int>` |
| `lastRun` | `Core<ClarionRun?>` |
| `nextRun` | `Core<DateTime?>` |

### `ClarionRun`

```dart
ClarionRun({required DateTime startedAt, required Duration duration, Object? error})
```

| Property | Type |
|---|---|
| `startedAt` | `DateTime` |
| `duration` | `Duration` |
| `error` | `Object?` |
| `succeeded` | `bool` |

### `ClarionStatus`

`idle` · `running` · `paused` · `disposed`

### `ClarionPolicy`

`skipIfRunning` · `allowOverlap`

### Pillar Extension

```dart
extension PillarBasaltExtension on Pillar {
  Clarion clarion({String? name}) { ... }
}
```

---

## Tapestry API

### `Tapestry<E>`

```dart
Tapestry({String? name, int? maxEvents})
```

| Method | Returns | Description |
|---|---|---|
| `append(event, {correlationId, metadata})` | `int` | Append event, return sequence |
| `appendAll(events, {correlationId})` | `List<int>` | Append multiple events |
| `weave<S>({name, initial, fold, where})` | `TapestryWeave<E,S>` | Create reactive projection |
| `getWeave<S>(name)` | `TapestryWeave<E,S>?` | Get existing weave |
| `removeWeave(name)` | `void` | Remove a weave |
| `query({fromSequence, toSequence, after, before, where, correlationId, limit})` | `List<TapestryStrand<E>>` | Query events |
| `at(sequence)` | `TapestryStrand<E>?` | Get event by sequence |
| `frame<S>(weaveName)` | `TapestryFrame<S>` | Snapshot weave state |
| `replay({fromSequence})` | `void` | Replay events through weaves |
| `compact(upToSequence)` | `int` | Remove old events |
| `reset()` | `void` | Clear all events and reset weaves |
| `dispose()` | `void` | Dispose store |
| `managedNodes` | `List<ReactiveNode>` | Nodes for `Pillar.registerNodes` |

| Reactive Property | Type |
|---|---|
| `eventCount` | `Core<int>` |
| `lastSequence` | `Core<int>` |
| `status` | `Core<TapestryStatus>` |
| `lastEventTime` | `Core<DateTime?>` |
| `weaveCount` | `Core<int>` |

### `TapestryWeave<E, S>`

| Property | Type |
|---|---|
| `state` | `Core<S>` |
| `version` | `Core<int>` |
| `lastUpdated` | `Core<DateTime?>` |
| `name` | `String` |

### `TapestryStrand<E>`

| Property | Type |
|---|---|
| `sequence` | `int` |
| `event` | `E` |
| `timestamp` | `DateTime` |
| `correlationId` | `String?` |
| `metadata` | `Map<String, dynamic>?` |

### `TapestryFrame<S>`

| Property | Type |
|---|---|
| `weaveName` | `String` |
| `state` | `S` |
| `sequence` | `int` |
| `createdAt` | `DateTime` |

### `TapestryStatus`

`idle` · `appending` · `replaying` · `disposed`

### Pillar Extension

```dart
extension PillarBasaltExtension on Pillar {
  Tapestry<E> tapestry<E>({String? name, int? maxEvents}) { ... }
}
```

---

[← Advanced Patterns](08-advanced-patterns.md) · [Migration Guide →](10-migration-guide.md)
