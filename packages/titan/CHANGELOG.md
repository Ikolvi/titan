# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-02

### Added
- **Conduit** — Core-level middleware pipeline for intercepting value changes
  - `Conduit<T>` abstract class with `pipe()` and `onPiped()` hooks
  - Built-in: `ClampConduit`, `TransformConduit`, `ValidateConduit`, `FreezeConduit`, `ThrottleConduit`
  - `ConduitRejectedException` for blocking invalid state changes
  - `Core<T>` now accepts `conduits:` parameter in constructor and `Pillar.core()`
  - Dynamic management: `addConduit()`, `removeConduit()`, `clearConduits()`
  - 25 new tests, benchmark #28 added
- **Prism** — Fine-grained, memoized state projections
  - `Prism<T>` extends `TitanComputed<T>` for read-only reactive sub-value views
  - Type-safe static factories: `Prism.of<S,R>`, `Prism.combine2/3/4`, `Prism.fromDerived`
  - `PrismEquals` abstract final class with `list<T>()`, `set<T>()`, `map<K,V>()` comparators
  - `PrismCoreExtension<T>` — `.prism()` extension method on `TitanState<T>`
  - Pillar factory: `prism<S,R>(source, selector)` with managed lifecycle
  - 25 new tests, benchmark #29 added
- **Nexus** — Reactive collections with in-place mutation and granular change tracking
  - `NexusList<T>` — reactive list with `add`, `addAll`, `insert`, `remove`, `removeAt`, `sort`, `swap`, `move`
  - `NexusMap<K,V>` — reactive map with `[]=`, `putIfChanged`, `putIfAbsent`, `addAll`, `remove`, `removeWhere`
  - `NexusSet<T>` — reactive set with `add`, `remove`, `toggle`, `intersection`, `union`, `difference`
  - `NexusChange<T>` sealed class hierarchy for pattern-matching change records
  - Pillar factories: `nexusList()`, `nexusMap()`, `nexusSet()` with managed lifecycle
  - Zero copy-on-write overhead — O(1) amortized mutations vs O(n) spread copies
  - 90 new tests, benchmark #30 added

## [0.1.1] - 2026-03-02

### Added
- Screenshots and banner image for pub.dev
- Logo and banner assets in package

## [0.1.0] - 2026-03-02

### Added
- **Atlas.go()** navigation support — declarative stack-based navigation
- Pub.dev publish preparation — example file, topics, analysis fixes
- 20 additional tests (gap coverage: Relic, Codex, Quarry, Scroll, Epoch, API)

### Removed
- **TitanMiddleware** — dead code removed (use TitanObserver/Oracle instead)
- **StateChangeEvent** — removed alongside middleware

### Fixed
- `dart format` applied across all source files
- CHANGELOG headers standardized to Keep a Changelog format

## [0.0.3] - 2025-07-12

### Added
- **Herald** — Cross-domain event bus for decoupled Pillar-to-Pillar communication
  - `Herald.emit<T>()` — Broadcast events by type
  - `Herald.on<T>()` — Subscribe to events (returns `StreamSubscription`)
  - `Herald.once<T>()` — One-shot listener (auto-cancels after first event)
  - `Herald.stream<T>()` — Broadcast `Stream<T>` for advanced composition
  - `Herald.last<T>()` — Replay the most recently emitted event
  - `Herald.hasListeners<T>()` — Check for active listeners
  - `Herald.reset()` — Clear all listeners and history (for tests)
- **Pillar.listen<T>()** — Managed Herald subscription (auto-cancelled on dispose)
- **Pillar.listenOnce<T>()** — Managed one-shot Herald subscription
- **Pillar.emit<T>()** — Convenience to emit Herald events from a Pillar
- **Vigil** — Centralized error tracking with pluggable handlers
  - `Vigil.capture()` — Capture errors with severity, context, and stack traces
  - `Vigil.addHandler()` / `Vigil.removeHandler()` — Pluggable error sinks
  - `ConsoleErrorHandler` — Built-in formatted console output
  - `FilteredErrorHandler` — Route errors by condition
  - `Vigil.guard()` / `Vigil.guardAsync()` — Execute with automatic capture
  - `Vigil.captureAndRethrow()` — Capture then propagate
  - `Vigil.history` / `Vigil.lastError` — Error history with configurable max
  - `Vigil.bySeverity()` / `Vigil.bySource()` — Query errors
  - `Vigil.errors` — Real-time error stream
- **Pillar.captureError()** — Managed Vigil capture with automatic Pillar context
- **Pillar.strikeAsync** now auto-captures errors via Vigil before rethrowing
- **Chronicle** — Structured logging system with named loggers
  - `Chronicle('name')` — Named logger instances
  - Log levels: `trace`, `debug`, `info`, `warning`, `error`, `fatal`
  - `LogSink` — Pluggable output destinations
  - `ConsoleLogSink` — Built-in formatted console output with icons
  - `Chronicle.level` — Global minimum log level
  - `Chronicle.addSink()` / `Chronicle.removeSink()` — Manage sinks
- **Pillar.log** — Auto-named Chronicle logger per Pillar
- **Epoch** — Core with undo/redo history (time-travel state)
  - `Epoch<T>` — TitanState with undo/redo stacks
  - `undo()` / `redo()` — Navigate history
  - `canUndo` / `canRedo` — Check capability
  - `history` — Read-only list of past values
  - `clearHistory()` — Wipe history, keep current value
  - Configurable `maxHistory` depth (default 100)
- **Pillar.epoch()** — Create managed Epoch (Core with history)
- **Flux** — Stream-like operators for reactive Cores
  - `core.debounce(duration)` — Debounced state propagation
  - `core.throttle(duration)` — Throttled state propagation
  - `core.asStream()` — Convert Core to typed `Stream<T>`
  - `node.onChange` — Stream of change signals for any ReactiveNode
- **Relic** — Persistence & hydration for Cores
  - `RelicAdapter` — Pluggable storage backend interface
  - `InMemoryRelicAdapter` — Built-in adapter for testing
  - `RelicEntry<T>` — Typed serialization config per Core
  - `Relic.hydrate()` / `Relic.hydrateKey()` — Restore from storage
  - `Relic.persist()` / `Relic.persistKey()` — Save to storage
  - `Relic.enableAutoSave()` / `Relic.disableAutoSave()` — Auto-persist on changes
  - `Relic.clear()` / `Relic.clearKey()` — Remove persisted data
  - Configurable key prefix (default `'titan:'`)
- **Scroll** — Form field validation with dirty/touch tracking
  - `Scroll<T>` — Validated form field extending `TitanState<T>`
  - `validate()`, `touch()`, `reset()`, `setError()`, `clearError()`
  - Properties: `error`, `isDirty`, `isPristine`, `isTouched`, `isValid`
  - `ScrollGroup` — Aggregate form state (`validateAll()`, `resetAll()`, `touchAll()`)
- **Pillar.scroll()** — Create managed Scroll (form field with validation)
- **Codex** — Paginated data management
  - `Codex<T>` — Generic paginator supporting offset and cursor modes
  - `loadFirst()`, `loadNext()`, `refresh()`
  - Reactive state: `items`, `isLoading`, `hasMore`, `currentPage`, `error`
  - `CodexPage<T>`, `CodexRequest` — Typed page/request models
- **Pillar.codex()** — Create managed Codex (paginated data)
- **Quarry** — Data fetching with stale-while-revalidate, retry, and deduplication
  - `Quarry<T>` — Managed data fetcher with SWR semantics
  - `fetch()`, `refetch()`, `invalidate()`, `setData()`, `reset()`
  - Reactive state: `data`, `isLoading`, `isFetching`, `error`, `isStale`, `hasData`
  - `QuarryRetry` — Exponential backoff config (`maxAttempts`, `baseDelay`)
  - Request deduplication via `Completer<T>`
- **Pillar.quarry()** — Create managed Quarry (data fetching)
- **Herald.allEvents** — Global event stream for debug tooling
  - `HeraldEvent` — Typed wrapper with `type`, `payload`, `timestamp`
- **Titan.registeredTypes** — Set of all registered types (instances + factories)
- **Titan.instances** — Unmodifiable map of active instances (debug introspection)

### Fixed
- **Top-level function shadowing**: Removed top-level `strike()` and `strikeAsync()` from `api.dart` — Dart resolves top-level functions over inherited instance methods in ALL contexts (not just `late final` initializers), causing `_assertNotDisposed()` and auto-capture to be bypassed. Use `titanBatch()` / `titanBatchAsync()` for standalone batching.

## [0.0.2] - 2025-07-12

### Added
- **`Titan.forge()`** — Register a Pillar by its runtime type for dynamic registration (e.g., Atlas DI integration)
- **`Titan.removeByType()`** — Remove a Pillar by runtime Type without needing a generic parameter

## [0.0.1] - 2025-07-11

### Added
- **Pillar** — Structured state module with lifecycle (`onInit`, `onDispose`)
- **Core** — Fine-grained reactive mutable state (`core(0)` / `Core(0)`)
- **Derived** — Auto-computed values from Cores, cached and lazy (`derived(() => ...)` / `Derived(() => ...)`)
- **Strike** — Batched state mutations (`strike(() { ... })`)
- **Watch** — Managed reactive side effects (`watch(() { ... })`)
- **Titan** — Global Pillar registry (`Titan.put()`, `Titan.get()`, `Titan.lazy()`)
- **TitanObserver** (Oracle) — Global state change observer
- **TitanContainer** (Vault) — Hierarchical DI container
- **TitanModule** (Forge) — Dependency assembly modules
- **AsyncValue** (Ether) — Loading / error / data async wrapper
- **TitanConfig** (Edict) — Global configuration
