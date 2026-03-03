# Changelog

All notable changes to the Titan packages will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-03-03

### Changed
- Updated `titan` dependency to `^1.0.1`

## [1.0.1] - 2026-03-02

- No API changes. Version bump to align with workspace release.

## [1.1.0] - 2025-07-23

### Added
- `CoreRefresh` — bridges Titan's reactive `Core` signals to Flutter's `Listenable` for automatic route re-evaluation
- `refreshListenable` parameter on `Atlas` constructor — triggers Sentinel/Drift re-evaluation when the provided `Listenable` notifies
- Automatic cleanup of old refresh listeners when Atlas is replaced
- Re-entrant guard (`_isRefreshing`) prevents cascading refresh calls
- Both sync and async Sentinel support during refresh
- `Garrison.refreshAuth` — one-call factory combining `authGuard` + `guestOnly` + `CoreRefresh`
- `GarrisonAuth` — result type with `sentinels` and `refresh` fields
- Post-login redirect: `guestOnly` now reads `redirect` query parameter (via `useRedirectQuery`) for seamless return to originally requested page
- `_onRefresh` preserves query parameters during re-evaluation (uses `waypoint.uri` instead of `waypoint.path`)
- 26 tests for CoreRefresh, refreshListenable, Garrison.refreshAuth, and post-login redirect
- 200 tests passing

## [1.0.0] - 2026-03-02

### 🎉 Stable Release

Titan Atlas reaches 1.0.0 — the routing system (Atlas, Passage, Sanctum, Sentinel, Shift) is now
considered stable. No breaking changes are planned for the 1.x series.

### Changed
- Updated `titan` dependency to `^1.0.0`
- 174 tests passing

## [0.2.0] - 2026-03-02

### Changed
- Updated `titan` dependency to `^0.2.0` (Conduit support)

## [0.1.1] - 2026-03-02

### Added
- Screenshots and banner image for pub.dev
- Banner in README header

## [0.1.0] - 2026-03-02

### Added
- **Atlas.go()** / **context.atlas.go()** — declarative navigation that reuses
  existing stack entries or replaces the stack. Ideal for tab/bottom-nav switching
  (prevents duplicate page keys)
- Pub.dev publish preparation — example file, topics, analysis fixes
- 3 new tests for `go()` behavior (reuse, fresh, no-op)

### Fixed
- **Duplicate page key crash** when switching Sanctum tabs via `Atlas.to()`
- `WidgetsBinding` initialized defensively in `Atlas.config` getter
- `dart format` applied across all source files

## [0.0.2] - 2025-07-12

### Added

#### Enterprise Features
- **AtlasObserver** — Navigation lifecycle observer for analytics, logging, and debugging
  - `onNavigate`, `onReplace`, `onPop`, `onReset`, `onGuardRedirect`, `onDriftRedirect`, `onNotFound`
- **AtlasLoggingObserver** — Built-in console logging observer
- **Async Sentinel resolution** — Async route guards now fully evaluated during navigation
- **Type-safe Rune accessors** — `waypoint.intRune('id')`, `doubleRune()`, `boolRune()` + query equivalents
- **Per-route redirects** — `Passage('/old', ..., redirect: (wp) => '/new')`
- **Route metadata** — `Passage('/admin', ..., metadata: {'title': 'Admin'})` accessible via `waypoint.metadata`
- **Route name on Waypoint** — `waypoint.name` returns the Passage's named identifier

#### DI Integration
- **Global Pillars** — `Atlas(pillars: [AuthPillar.new])` registers Pillars via `Titan.forge()` on construction
- **Route-scoped Pillars** — `Passage('/checkout', ..., pillars: [CheckoutPillar.new])` auto-creates on push, auto-disposes on pop
- **Shell-scoped Pillars** — `Sanctum(pillars: [DashboardPillar.new], ...)` Pillars live with the shell
- **`Titan.forge()`** — Registers a Pillar by its runtime type (for dynamic registration)
- **`Titan.removeByType()`** — Removes a Pillar by runtime Type (no generic parameter needed)
- 37 new tests (83 total)

---

## [0.0.1] - 2025-07-12

### Added

#### Atlas — Routing & Navigation
- **Atlas** — Declarative router with Navigator 2.0, deep linking, and zero-boilerplate API
- **Passage** — Route definitions with static, dynamic (`:param`), and wildcard (`*`) patterns
- **Sanctum** — Shell routes for persistent layouts (tab bars, nav rails, drawers)
- **Sentinel** — Route guards with sync/async, `only()`, and `except()` modes
- **Shift** — Page transitions: `fade()`, `slide()`, `slideUp()`, `scale()`, `none()`, `custom()`
- **Waypoint** — Route state with Runes (path params), query params, and extra data
- **Drift** — Global redirect function applied before Sentinels
- **Runes** — Extracted path parameters (`:id` → `wp.runes['id']`)
- **RouteTrie** — O(k) trie-based route matcher with static > dynamic > wildcard priority
- **AtlasContext** — `context.atlas.to()` / `.back()` / `.replace()` BuildContext extension
- **Named routes** — `Atlas.toNamed('name', runes: {...})` navigation
- **Stack navigation** — `Atlas.to()`, `.back()`, `.backTo()`, `.replace()`, `.reset()`
- **404 handling** — Default and custom error pages via `onError`
- 46 tests covering trie matching, waypoint, sentinel, and full widget integration

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
