# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-03-04

### Added
- **TitanPlugin** — Abstract plugin interface for Beacon lifecycle hooks (`onAttach`, `buildOverlay`, `onDetach`)
- **Beacon `plugins` parameter** — Pass `List<TitanPlugin>?` to Beacon for modular integrations
  - Plugins attach after Pillars are created, overlays wrap inside the inherited scope, detach runs in reverse order

## [1.0.3] - 2026-03-04

### Changed
- Updated `titan` dependency to `^1.1.0`

## [1.0.2] - 2026-03-03

### Changed
- Updated `titan` dependency to `^1.0.1`

## [1.0.1] - 2026-03-03

### Changed
- **Lens** — Moved `Lens`, `LensPlugin`, and `LensLogSink` to `titan_colossus`. Import from `package:titan_colossus/titan_colossus.dart` instead of `package:titan_bastion/titan_bastion.dart`.

## [1.0.0] - 2026-03-02

### 🎉 Stable Release

Titan Bastion reaches 1.0.0 — all Flutter widgets (Vestige, Beacon, Confluence, Lens, Spark) are now
considered stable. No breaking changes are planned for the 1.x series.

### Added
- **Spark** — Hooks-style reactive widget eliminating StatefulWidget boilerplate
  - `Spark` base class with `ignite()` builder method
  - **Auto-tracking**: Any `Core` or `Derived` `.value` read during `ignite()` is automatically tracked
  - Reactive hooks: `useCore<T>`, `useDerived<T>` — auto-tracking with rebuild
  - Lifecycle hooks: `useEffect`, `useMemo`, `useRef`
  - Controller hooks: `useTextController`, `useAnimationController`, `useFocusNode`, `useScrollController`, `useTabController`, `usePageController`
  - Stream hook: `useStream<T>` — reactive stream consumption returning `AsyncValue<T>`
  - Titan integration: `usePillar<P>` for Beacon/Titan lookup
  - 45 tests

### Changed
- Updated `titan` dependency to `^1.0.0`
- 145 tests passing

## [0.3.0] - 2026-03-02

### Added
- **Spark** — Hooks-style reactive widget eliminating StatefulWidget boilerplate
  - `Spark` base class with `ignite()` builder method
  - **Auto-tracking**: Any `Core` or `Derived` `.value` read during `ignite()` is automatically tracked via `TitanEffect` — changes trigger rebuilds (same engine as Vestige)
  - Reactive hooks: `useCore<T>`, `useDerived<T>` — auto-tracking with rebuild
  - Lifecycle hooks: `useEffect`, `useMemo`, `useRef`
  - Controller hooks: `useTextController`, `useAnimationController`, `useFocusNode`, `useScrollController`, `useTabController`, `usePageController`
  - Titan integration: `usePillar<P>` for Beacon/Titan lookup
  - 45 tests (including 6 auto-tracking tests)
  - Story chapter XXI: "The Spark Ignites"

## [0.2.0] - 2026-03-02

### Changed
- Updated `titan` dependency to `^0.2.0` (Conduit support)

## [0.1.1] - 2026-03-02

### Added
- Screenshots and banner image for pub.dev
- Banner in README header

## [0.1.0] - 2026-03-02

### Fixed
- **setState during build** — all reactive widgets (Vestige, VestigeRaw, Obs, Confluence2/3/4)
  now defer `setState` via `addPostFrameCallback` when Flutter is in the build/layout phase
  (fixes crash when Codex.loadNext triggers inside an itemBuilder)

### Added
- Pub.dev publish preparation — example file, topics, CHANGELOG cleanup
- `dart format` applied across all source files

## [0.0.2] - 2025-07-12

### Added
- **Confluence** — Multi-Pillar consumer widgets
  - `Confluence2<A,B>`, `Confluence3<A,B,C>`, `Confluence4<A,B,C,D>`
  - Typed builders, Beacon/Titan resolution, auto-tracking via TitanEffect
- **Lens** — In-app debug overlay
  - `Lens` — Floating debug panel with 4 tabs (Pillars, Herald, Vigil, Chronicle)
  - `LensLogSink` — Buffered Chronicle log capture for overlay display
  - Static control: `Lens.show()`, `Lens.hide()`, `Lens.toggle()`
  - Zero-overhead in production via `enabled` flag

## [0.0.1] - 2025-07-11

### Added
- **Vestige** — Primary reactive widget consumer for Pillar state
  - Auto-tracks `Core`s and `Derived`s, rebuilds only on change
  - Resolves Pillars from `Beacon` (widget tree) or `Titan` (global)
- **VestigeRaw** — Standalone reactive builder for raw Cores (no Pillar needed)
- **Beacon** — Widget-tree DI provider for Pillar instances
  - `BeaconScope.findPillar<P>()` for ancestor lookup
- **Obs** — Ultra-simple auto-tracking reactive widget builder
- **TitanStateMixin** — Mixin for `StatefulWidget` lifecycle integration
- **Context extension** — `context.pillar<P>()` for Beacon/Titan lookup
