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

### Bulwark

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

Multi-step async workflow with compensation (rollback) on failure.

#### Constructor (Pillar factory)

```dart
saga<T>({
  required List<SagaStep<T>> steps,
  void Function(T? result)? onComplete,
  void Function(Object error, String failedStep)? onError,
  void Function(String stepName, int index, int total)? onStepComplete,
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
| `isRunning` | `bool` | Whether currently executing |
| `totalSteps` | `int` | Total number of steps |
| `run()` | `Future<T?>` | Execute all steps; compensates on failure |
| `reset()` | `void` | Reset to idle |
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

Batch async operations with concurrency control and partial-failure handling.

#### Constructor (Pillar factory)

```dart
volley<T>({int concurrency = 5, String? name})
```

| Property/Method | Type | Description |
|-----------------|------|-------------|
| `status` | `VolleyStatus` | `idle`, `running`, `done`, `cancelled` (reactive) |
| `progress` | `double` | Progress 0.0–1.0 (reactive) |
| `completedCount` | `int` | Number of completed tasks (reactive) |
| `totalCount` | `int` | Total tasks (reactive) |
| `isRunning` | `bool` | Whether currently executing |
| `successCount` | `int` | Number of successes |
| `execute(List<VolleyTask<T>> tasks)` | `Future<List<VolleyResult<T>>>` | Run batch with concurrency limit |
| `cancel()` | `void` | Cancel execution |
| `reset()` | `void` | Reset to idle |
| `dispose()` | `void` | Dispose internal state |

#### VolleyTask / VolleyResult

```dart
VolleyTask<T>({required String name, required Future<T> Function() execute})
```

`VolleyResult<T>` is a sealed class: `VolleySuccess<T>` (with `value`) or `VolleyFailure<T>` (with `error`, `stackTrace`). Common getters: `taskName`, `isSuccess`, `isFailure`, `valueOrNull`, `errorOrNull`.

---

### Annals

Static audit trail for Core mutations. Immutable, append-only, FIFO-evicted.

| Method | Type | Description |
|--------|------|-------------|
| `Annals.enable({int maxEntries})` | `void` | Enable auditing |
| `Annals.disable()` | `void` | Disable auditing |
| `Annals.record(AnnalEntry entry)` | `void` | Record an entry |
| `Annals.entries` | `List<AnnalEntry>` | All entries (unmodifiable) |
| `Annals.length` | `int` | Entry count |
| `Annals.stream` | `Stream<AnnalEntry>` | Broadcast stream of entries |
| `Annals.query({...})` | `List<AnnalEntry>` | Filter by coreName, pillarType, action, userId, after, before, limit |
| `Annals.export({...})` | `List<Map<String, dynamic>>` | Export as serializable maps |
| `Annals.clear()` | `void` | Clear all entries |
| `Annals.reset()` | `void` | Clear, disable, reset max |

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

Static request-response channels between Pillars.

| Method | Type | Description |
|--------|------|-------------|
| `Tether.register<Req, Res>(name, handler, {timeout})` | `void` | Register a typed handler |
| `Tether.unregister(name)` | `bool` | Remove a handler |
| `Tether.has(name)` | `bool` | Check if registered |
| `Tether.call<Req, Res>(name, request, {timeout})` | `Future<Res>` | Invoke and await response |
| `Tether.tryCall<Req, Res>(name, request, {timeout})` | `Future<Res?>` | Returns null if not registered |
| `Tether.names` | `Set<String>` | All registered names |
| `Tether.reset()` | `void` | Clear all registrations |

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

| Hook | Returns | Purpose |
|------|---------|---------|
| `useCore<T>(initial)` | `Core<T>` | Reactive state, auto-rebuilds |
| `useDerived<T>(compute)` | `Derived<T>` | Auto-tracked computed value |
| `useEffect(fn, [keys])` | `void` | Side effect with cleanup |
| `useMemo<T>(fn, [keys])` | `T` | Memoized computation |
| `useRef<T>(initial)` | `SparkRef<T>` | Mutable ref, no rebuild |
| `useTextController()` | `TextEditingController` | Auto-disposed |
| `useAnimationController()` | `AnimationController` | Auto-disposed, built-in vsync |
| `useFocusNode()` | `FocusNode` | Auto-disposed |
| `useScrollController()` | `ScrollController` | Auto-disposed |
| `useTabController(length:)` | `TabController` | Auto-disposed, built-in vsync |
| `usePageController()` | `PageController` | Auto-disposed |
| `usePillar<P>(context)` | `P` | Find Pillar from Beacon/Titan |
| `useStream<T>(stream)` | `AsyncValue<T>` | Subscribe to stream, returns Ether snapshot |

---

[← Advanced Patterns](08-advanced-patterns.md) · [Migration Guide →](10-migration-guide.md)
