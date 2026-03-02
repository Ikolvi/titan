# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
