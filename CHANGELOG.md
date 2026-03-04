# Changelog

All notable changes to the Titan packages will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-03-04

### Added
- **titan_bastion** (v1.1.0): `TitanPlugin` — abstract plugin interface for Beacon lifecycle hooks. Beacon now accepts `plugins` parameter for modular integrations.
- **titan_colossus** (v1.1.0): `ColossusPlugin` — one-line `TitanPlugin` adapter for full Colossus integration. Add/remove all performance monitoring with a single plugin declaration.

## [1.1.1] - 2026-03-04

### Changed
- **titan** (v1.1.1): All debug-only `assert` statements converted to runtime errors across all packages — catches bugs in release builds:
  - `ClampConduit`: `ArgumentError` for invalid min/max range
  - `Pillar`, `TitanStore`, `TitanContainer`, `Relic`: `StateError` for use-after-dispose
  - `Aegis.run()` / `Aegis.runWithConfig()`: `ArgumentError` for `maxAttempts <= 0`
- **titan_basalt** (v1.12.3): All debug-only `assert` statements converted to runtime errors:
  - `Embargo`, `Trove`, `Volley`, `Census`, `Moat`, `Pyre`: `ArgumentError` for invalid constructor parameters
  - `Arbiter`, `Tithe`, `Lode`: `StateError` for use-after-dispose, `ArgumentError` for invalid values
  - `Warden`: `ArgumentError` for empty services list
  - `Clarion`, `Tapestry`: `StateError` for duplicate registration
  - `Banner`: `ArgumentError` for rollout values outside 0.0–1.0 (validated at registration time)
  - `Sluice`: `ArgumentError` for non-positive stage concurrency (validated at pipeline creation)
- **titan_colossus** (v1.0.4): `Phantom` speedMultiplier and `Colossus.instance` changed from `assert` to runtime errors

## [1.1.0] - 2026-03-04

### Added
- **titan**: **ReadCore\<T\>** — Read-only abstract interface for `Core<T>` (compile-time type narrowing, recommended convention for Pillar fields)
- **titan_basalt**: New package — Infrastructure & Resilience Toolkit
- **titan_basalt**: **Trove** — Reactive in-memory cache with TTL expiry, LRU eviction, O(1) operations, reactive stats, Pillar integration
- **titan_basalt**: **Moat** — Token-bucket rate limiter with `MoatPool` per-key quotas, `guard()` pattern, reactive state, Pillar integration
- **titan_basalt**: **Portcullis** — Reactive circuit breaker with three-state lifecycle (closed/open/halfOpen), `protect()` guarded execution, configurable thresholds, `shouldTrip` filter, `PortcullisOpenException`, trip history, Pillar integration
- **titan_basalt**: **Anvil** — Reactive dead letter & retry queue with configurable backoff (exponential/linear/constant + jitter), dead letter lifecycle, `retryDeadLetters()`, `purge()`, reactive counters, Pillar integration
- **titan_basalt**: **Pyre** — Priority task queue with concurrency control, backpressure, retry, `PyreResult`, reactive state, Pillar integration
- **titan**: **Omen** — Reactive async derived with auto-tracking, debounce, stale-while-revalidate, cancellation, Pillar integration
- **titan**: **Mandate** — Reactive policy engine with declarative `Writ` rules, `MandateStrategy` (allOf/anyOf/majority), sealed `MandateVerdict`, dynamic writ management, Pillar integration
- **titan**: **Ledger** — State transaction manager with atomic commit/rollback, `capture()` snapshots, `transact()` auto-scope, `LedgerRecord` audit history, reactive counters, Pillar integration
- **titan**: `Pillar.registerNodes()` — Public API for satellite packages to register lifecycle-managed reactive nodes

### Changed
- **titan**: Moved Trove, Moat, Portcullis, Anvil, Pyre to `titan_basalt` package (infrastructure/resilience separation)

## [1.0.2] - 2026-03-03

### Changed
- **titan**: Fixed screenshot to meet pub.dev minimum width requirement
- **titan_argus**: Added example file, updated `titan` and `titan_atlas` dependencies to `^1.0.1`
- **titan_colossus**: Added example file, updated `titan`, `titan_bastion`, and `titan_atlas` dependencies to `^1.0.1`
- **titan_bastion**: Updated `titan` dependency to `^1.0.1`
- **titan_atlas**: Updated `titan` dependency to `^1.0.1`

## [1.0.1] - 2026-03-03

### Changed
- **Lens** — Moved `Lens`, `LensPlugin`, and `LensLogSink` from `titan_bastion` to `titan_colossus`. Import from `package:titan_colossus/titan_colossus.dart`.

## [1.0.0] - 2026-03-02

### 🎉 Stable Release

All Titan packages reach 1.0.0 — the complete architecture is now considered stable.
No breaking changes are planned for the 1.x series.

**1,130+ tests** across all packages.

#### Titan Core (`titan` 1.0.0)
- **useStream** — Spark hook for reactive stream consumption
- **Performance optimizations**: nullable conduits, lazy `isReady`, sentinel Future,
  `notifyDependents` fast-path, observer fast-path, Saga pre-allocated results
- **Benchmark infrastructure**: noise floor filtering, Mermaid trend charts in CI reports

#### Bastion — Flutter Widgets (`titan_bastion` 1.0.0)
- **Spark** — Hooks-style reactive widget with 13 hooks
  - `useCore`, `useDerived`, `useEffect`, `useMemo`, `useRef`, `useStream`
  - `useTextController`, `useAnimationController`, `useFocusNode`
  - `useScrollController`, `useTabController`, `usePageController`, `usePillar`

#### Atlas — Routing (`titan_atlas` 1.0.0)
- Stable release, no feature changes since 0.2.0

## [0.3.0] - 2026-03-02

### Added

#### Bastion — Flutter Widgets (`titan_bastion`)
- **Spark** — Hooks-style reactive widget eliminating StatefulWidget boilerplate
  - `Spark` base class replacing `StatefulWidget` with `ignite()` + hooks
  - Reactive hooks: `useCore<T>`, `useDerived<T>`
  - Lifecycle hooks: `useEffect`, `useMemo`, `useRef`
  - Controller hooks: `useTextController`, `useAnimationController`, `useFocusNode`, `useScrollController`, `useTabController`, `usePageController`
  - Titan integration: `usePillar<P>` for Beacon lookup
  - 39 tests
  - Story chapter XXI: "The Spark Ignites"

## [0.2.0] - 2026-03-02

### Added

#### Titan Core (`titan`)
- **Conduit** — Core-level middleware pipeline
  - Intercept, transform, validate, or reject individual Core value changes
  - 5 built-in Conduits: `ClampConduit`, `TransformConduit`, `ValidateConduit`, `FreezeConduit`, `ThrottleConduit`
  - Pillar integration via `core(value, conduits: [...])`
  - Story chapter XVIII: "The Conduit Flows"
- **Prism** — Fine-grained, memoized state projections
  - `Prism<T>` class extending `TitanComputed<T>` for focused sub-value selection
  - Type-safe factories: `Prism.of`, `Prism.combine2/3/4`, `Prism.fromDerived`
  - `PrismEquals` structural comparators for `List`, `Set`, `Map`
  - `.prism()` extension on `Core<T>` for ergonomic API
  - Pillar integration via `prism(source, selector)`
  - 25 tests, benchmark #29
  - Story chapter XIX: "The Prism Reveals"
- **Nexus** — Reactive collections with in-place mutation
  - `NexusList<T>`, `NexusMap<K,V>`, `NexusSet<T>` — zero copy-on-write overhead
  - `NexusChange<T>` sealed class hierarchy for granular change records
  - Pillar factories: `nexusList()`, `nexusMap()`, `nexusSet()`
  - 90 tests, benchmark #30
  - Story chapter XX: "The Nexus Connects"

## [0.0.3] - 2025-07-12

### Added

#### Titan Core (`titan`)
- **Herald** — Cross-domain event bus for decoupled Pillar-to-Pillar communication
  - `Herald.emit<T>()`, `Herald.on<T>()`, `Herald.once<T>()`, `Herald.stream<T>()`
  - `Herald.last<T>()` — replay the most recently emitted event
  - `Herald.hasListeners<T>()`, `Herald.reset()`
- **Pillar.listen<T>()** — Managed Herald subscription (auto-cancelled on dispose)
- **Pillar.listenOnce<T>()** — Managed one-shot Herald subscription
- **Pillar.emit<T>()** — Convenience to emit Herald events from a Pillar
- **Vigil** — Centralized error tracking with pluggable handlers
  - `Vigil.capture()`, `Vigil.guard()`, `Vigil.guardAsync()`, `Vigil.captureAndRethrow()`
  - `ConsoleErrorHandler`, `FilteredErrorHandler` — built-in handler implementations
  - `Vigil.history`, `Vigil.lastError`, `Vigil.bySeverity()`, `Vigil.bySource()`
  - `Vigil.errors` — real-time error stream
- **Pillar.captureError()** — Managed Vigil capture with automatic Pillar context
- **Pillar.strikeAsync** now auto-captures errors via Vigil before rethrowing
- **Chronicle** — Structured logging with named loggers and pluggable sinks
  - `Chronicle('name')` — named logger instances
  - Log levels: `trace`, `debug`, `info`, `warning`, `error`, `fatal`
  - `LogSink`, `ConsoleLogSink` — pluggable output destinations
  - `Chronicle.level`, `Chronicle.addSink()`, `Chronicle.removeSink()`
- **Pillar.log** — Auto-named Chronicle logger per Pillar
- **Epoch** — Core with undo/redo history (time-travel state)
  - `Epoch<T>` — `undo()`, `redo()`, `canUndo`, `canRedo`, `history`, `clearHistory()`
  - Configurable `maxHistory` depth (default 100)
- **Pillar.epoch()** — Create managed Epoch (Core with history)
- **Flux** — Stream-like operators for reactive Cores
  - `core.debounce(duration)` — debounced state propagation
  - `core.throttle(duration)` — throttled state propagation
  - `core.asStream()` — convert Core to typed `Stream<T>`
  - `node.onChange` — stream of change signals
- **Relic** — Persistence & hydration for Cores
  - `RelicAdapter` — pluggable storage backend interface
  - `InMemoryRelicAdapter` — built-in adapter for testing
  - `RelicEntry<T>` — typed serialization config per Core
  - `Relic.hydrate()`, `Relic.persist()`, `Relic.enableAutoSave()`
  - Configurable key prefix (default `'titan:'`)
- **Scroll** — Form field validation with dirty/touch tracking
  - `Scroll<T>` — validated form field extending `TitanState<T>`
  - `validate()`, `touch()`, `reset()`, `setError()`, `clearError()`
  - Properties: `error`, `isDirty`, `isPristine`, `isTouched`, `isValid`
  - `ScrollGroup` — aggregate form state (`validateAll()`, `resetAll()`, `touchAll()`)
- **Pillar.scroll()** — Create managed Scroll (form field with validation)
- **Codex** — Paginated data management
  - `Codex<T>` — generic paginator with offset and cursor modes
  - `loadFirst()`, `loadNext()`, `refresh()`
  - Reactive state: `items`, `isLoading`, `hasMore`, `currentPage`, `error`
  - `CodexPage<T>`, `CodexRequest` — typed page/request models
- **Pillar.codex()** — Create managed Codex (paginated data)
- **Quarry** — Data fetching with stale-while-revalidate, retry, and deduplication
  - `Quarry<T>` — managed data fetcher with SWR semantics
  - `fetch()`, `refetch()`, `invalidate()`, `setData()`, `reset()`
  - Reactive state: `data`, `isLoading`, `isFetching`, `error`, `isStale`, `hasData`
  - `QuarryRetry` — exponential backoff config (`maxAttempts`, `baseDelay`)
  - Request deduplication via `Completer<T>`
- **Pillar.quarry()** — Create managed Quarry (data fetching)
- **Herald.allEvents** — Global event stream for debug tooling
  - `HeraldEvent` — typed wrapper with `type`, `payload`, `timestamp`
- **Titan.registeredTypes** — Set of all registered types (instances + factories)
- **Titan.instances** — Unmodifiable map of active instances (debug introspection)
- 132 new tests (Herald +12, Scroll: 25, Codex: 15, Quarry: 18) — 291 total in titan core

#### Bastion — Flutter Widgets (`titan_bastion`)
- **Confluence** — Multi-Pillar consumer widgets
  - `Confluence2<A,B>`, `Confluence3<A,B,C>`, `Confluence4<A,B,C,D>`
  - Typed builders, Beacon/Titan resolution, auto-tracking via TitanEffect
- **Lens** — In-app debug overlay (now in `titan_colossus`)
  - `Lens` — floating debug panel with 4 tabs (Pillars, Herald, Vigil, Chronicle)
  - `LensLogSink` — buffered Chronicle log capture for overlay display
  - Static control: `Lens.show()`, `Lens.hide()`, `Lens.toggle()`
  - Zero-overhead in production via `enabled` flag
- 21 new tests (Confluence: 8, Lens: 13) — 40 total in titan_bastion

#### Atlas — Routing (`titan_atlas`)
- **HeraldAtlasObserver** — Bridges Atlas lifecycle to Herald events
  - `AtlasRouteChanged` — emitted on navigate/pop/replace/reset
  - `AtlasGuardRedirect` — emitted when Sentinel redirects
  - `AtlasDriftRedirect` — emitted when Drift redirects
  - `AtlasRouteNotFound` — emitted on 404
- 9 new tests — 92 total in titan_atlas

#### Documentation
- **The Chronicles of Titan** — 5 new story chapters (IX–XIII)
  - Chapter IX: The Scroll Inscribes (form validation)
  - Chapter X: The Codex Opens (pagination)
  - Chapter XI: The Quarry Yields (data fetching)
  - Chapter XII: The Confluence Converges (multi-Pillar consumers)
  - Chapter XIII: The Lens Reveals (debug overlay)
- Updated API reference and advanced patterns docs
- Updated all READMEs with new features, lexicon entries, and comparison tables

### Fixed
- **Top-level function shadowing**: Removed `strike()` / `strikeAsync()` from `api.dart` — Dart resolves top-level functions over inherited instance methods, bypassing `_assertNotDisposed()` and auto-capture. Use `titanBatch()` / `titanBatchAsync()` for standalone batching.

---

## [0.0.2] - 2025-07-12

### Added

#### Atlas — Routing & Navigation (`titan_atlas` 0.0.1 → 0.0.2)
- **Atlas** — Declarative router with Navigator 2.0, deep linking, and zero-boilerplate API
- **Passage** — Route definitions with static, dynamic (`:param`), and wildcard (`*`) patterns
- **Sanctum** — Shell routes for persistent layouts (tab bars, nav rails, drawers)
- **Sentinel** — Route guards with sync/async, `only()`, and `except()` modes
- **Shift** — Page transitions: `fade()`, `slide()`, `slideUp()`, `scale()`, `none()`, `custom()`
- **Waypoint** — Route state with Runes (path params), query params, and extra data
- **Drift** — Global redirect function applied before Sentinels
- **RouteTrie** — O(k) trie-based route matcher with static > dynamic > wildcard priority
- **AtlasObserver** — Navigation lifecycle observer (`onNavigate`, `onPop`, `onReset`, `onGuardRedirect`, etc.)
- **AtlasLoggingObserver** — Built-in console logging observer
- **Async Sentinel resolution** — Async route guards fully evaluated during navigation
- **Type-safe Rune accessors** — `waypoint.intRune('id')`, `doubleRune()`, `boolRune()`, + query equivalents
- **Per-route redirects** — `Passage('/old', ..., redirect: (wp) => '/new')`
- **Route metadata** — `Passage('/admin', ..., metadata: {'title': 'Admin'})` via `waypoint.metadata`

#### Atlas DI Integration
- **Global Pillars** — `Atlas(pillars: [AuthPillar.new])` — zero-boilerplate DI, no Beacon wrapper needed
- **Route-scoped Pillars** — `Passage('/checkout', ..., pillars: [CheckoutPillar.new])` — auto-created on push, auto-disposed on pop
- **Shell-scoped Pillars** — `Sanctum(pillars: [...])` — Pillars scoped to shell lifetime

#### Titan Core (`titan`)
- **`Titan.forge()`** — Register Pillar by runtime type (for dynamic registration)
- **`Titan.removeByType()`** — Remove Pillar by runtime Type (no generic parameter needed)
- 186 tests across all packages

---

## [0.0.1] - 2025-07-11

### Added

#### Titan Architecture
- **Pillar** — Structured state management base class with lifecycle (`onInit`/`onDispose`), managed reactives, and auto-disposal
- **Core** (`core()` / `Core()`) — Fine-grained reactive mutable state with auto-tracking, custom equality, `peek()`, `update()`, `silent()`, and `listen()`
- **Derived** (`derived()` / `Derived()`) — Auto-computed reactive values with lazy evaluation, caching, and auto-dependency tracking
- **Strike** (`strike()`) — Batched state mutations that coalesce notifications
- **Watch** (`watch()`) — Managed reactive side effects with cleanup and `fireImmediately`

#### Reactive Engine (`titan`)
- `TitanState<T>` — Signal-based mutable reactive node
- `TitanComputed<T>` — Derived reactive node with dependency tracking
- `TitanEffect` — Reactive side effect with cleanup functions and `onNotify` callback
- `titanBatch()` / `titanBatchAsync()` — Batch multiple state changes into a single notification cycle
- `TitanStore` — Legacy abstract base class for organized state containers
- `TitanContainer` — Type-safe DI container with lazy singletons, scoped child containers, and auto-disposal
- `TitanModule` / `TitanSimpleModule` — Module system for grouping DI registrations
- `AsyncValue<T>` — Sealed class (`AsyncData`, `AsyncLoading`, `AsyncError`) with `when()` and `maybeWhen()`
- `TitanAsyncState<T>` — Reactive async state wrapper with `load()`, `refresh()`, `setValue()`, `setError()`, `reset()`
- `TitanObserver` — Global state change observer
- `TitanLoggingObserver` / `TitanHistoryObserver` — Console logging and time-travel debugging
- `TitanConfig` — Global configuration with `debugMode` and `enableLogging()`
- `Titan` — Global Pillar registry with `put()`, `lazy()`, `get()`, `find()`, `has()`, `remove()`, `reset()`

#### Flutter Integration (`titan_bastion`)
- **Vestige** — Auto-tracking consumer widget; only rebuilds when accessed Cores change
- **Beacon** — Scoped Pillar provider with lifecycle management and auto-disposal
- `BeaconScope` / `BeaconContext` — `context.pillar<P>()` and `context.hasPillar<P>()` extensions
- `VestigeRaw` — Untyped consumer for standalone Cores (non-Pillar usage)
- `TitanScope` — InheritedWidget-based scope for `TitanContainer`
- `TitanBuilder` — Auto-tracking builder widget
- `TitanConsumer<T>` — Typed store consumer widget
- `TitanSelector<T>` — Fine-grained selector with custom equality
- `TitanAsyncBuilder<T>` — Pattern-matched widget for `AsyncValue` states
- `TitanStateMixin` — Mixin for `StatefulWidget` with `watch()` and `titanEffect()`

#### Documentation
- 11 comprehensive documentation files covering all concepts
- Migration guides from Provider, Bloc, Riverpod, and GetX
- Architecture documentation for contributors

#### Example
- Counter demo with Pillar, Beacon, and Vestige
- Todo app demo with filtering and CRUD operations
