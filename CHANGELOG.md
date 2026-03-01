# Changelog

All notable changes to the Titan packages will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- `TitanMiddleware` — Abstract middleware for intercepting state changes
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
