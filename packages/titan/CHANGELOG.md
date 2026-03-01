## 0.0.3

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

### Fixed
- **Top-level function shadowing**: Removed top-level `strike()` and `strikeAsync()` from `api.dart` — Dart resolves top-level functions over inherited instance methods in ALL contexts (not just `late final` initializers), causing `_assertNotDisposed()` and auto-capture to be bypassed. Use `titanBatch()` / `titanBatchAsync()` for standalone batching.

## 0.0.2

### Added
- **`Titan.forge()`** — Register a Pillar by its runtime type for dynamic registration (e.g., Atlas DI integration)
- **`Titan.removeByType()`** — Remove a Pillar by runtime Type without needing a generic parameter

## 0.0.1

### Added
- **Pillar** — Structured state module with lifecycle (`onInit`, `onDispose`)
- **Core** — Fine-grained reactive mutable state (`core(0)` / `Core(0)`)
- **Derived** — Auto-computed values from Cores, cached and lazy (`derived(() => ...)` / `Derived(() => ...)`)
- **Strike** — Batched state mutations (`strike(() { ... })`)
- **Watch** — Managed reactive side effects (`watch(() { ... })`)
- **Titan** — Global Pillar registry (`Titan.put()`, `Titan.get()`, `Titan.lazy()`)
- **TitanObserver** (Oracle) — Global state change observer
- **TitanMiddleware** (Aegis) — State change interceptor
- **TitanContainer** (Vault) — Hierarchical DI container
- **TitanModule** (Forge) — Dependency assembly modules
- **AsyncValue** (Ether) — Loading / error / data async wrapper
- **TitanConfig** (Edict) — Global configuration
