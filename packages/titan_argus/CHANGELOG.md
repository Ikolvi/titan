# Changelog

## [1.0.2] - 2026-03-03

### Added
- Example file for pub.dev documentation score

### Changed
- Updated `titan` dependency to `^1.0.1`
- Updated `titan_atlas` dependency to `^1.0.1`

## [1.0.1] - 2026-03-02

- No API changes. Version bump to align with workspace release.

## 1.0.0

- Initial release
- `Argus` abstract base class with `isLoggedIn` Core, `signIn`/`signOut` lifecycle, `authCores` getter, `guard()` convenience
- `Garrison` auth guard factories: `authGuard`, `guestOnly`, `roleGuard`, `rolesGuard`, `onboardingGuard`, `composite`, `compositeAsync`, `refreshAuth`
- `CoreRefresh` reactive bridge from `ReactiveNode` signals to Flutter `Listenable`
- `GarrisonAuth` record type for typed guard results
- Moved from `titan_atlas` for clean architectural separation
