# Changelog

## [1.2.0] - 2026-03-05

### Fixed
- **Shade session persistence** — Recorded sessions now survive Lens hide/show cycles. Session is stored on `Colossus` instance instead of disposed Pillar.

### Added
- **Auto-show Lens after FAB stop** — Lens overlay automatically opens when stopping a recording via the floating action button.
- **Draggable FAB** — Lens floating button can be dragged to any position. Position persists across hide/show. Added `Lens.resetFabPosition()` to restore defaults.

### Changed
- **Plugin tabs first** — Plugin tabs (Shade) now appear before built-in tabs (Pillars, Herald, Vigil, Chronicle) in the Lens panel.

## [1.1.0] - 2026-03-04

### Added
- **ColossusPlugin** — One-line `TitanPlugin` adapter for full Colossus integration. Add or remove performance monitoring with a single line in `Beacon(plugins: [...])`
  - Manages `Colossus.init()`, `Lens` overlay, `ShadeListener`, export/route callbacks, auto-replay, and `Colossus.shutdown()` automatically

## [1.0.4] - 2026-03-04

### Changed
- **Assert → Runtime Errors**: `Phantom` speedMultiplier validation and `Colossus.instance` guard changed from debug-only `assert` to runtime errors (`ArgumentError` / `StateError`)

## [1.0.3] - 2026-03-04

### Changed
- Updated `titan` dependency to `^1.1.0`

## [1.0.2] - 2026-03-03

### Added
- Example file for pub.dev documentation score

### Changed
- Updated `titan` dependency to `^1.0.1`
- Updated `titan_bastion` dependency to `^1.0.1`
- Updated `titan_atlas` dependency to `^1.0.1`

## [1.0.1] - 2026-03-02

- **Lens** — `Lens`, `LensPlugin`, and `LensLogSink` moved here from `titan_bastion`. Import from `package:titan_colossus/titan_colossus.dart`.

## 1.0.0

- Initial release
- **Colossus** — Enterprise performance monitoring Pillar
- **Pulse** — Frame metrics (FPS, jank detection, build/raster timing)
- **Stride** — Page load timing with Atlas integration
- **Vessel** — Memory monitoring and leak detection
- **Echo** — Widget rebuild tracking
- **Tremor** — Configurable performance alerts via Herald
- **Decree** — Performance report generation
- **Lens integration** — Plugin tab for the Lens debug overlay
- **ColossusAtlasObserver** — Automatic route timing via Atlas
