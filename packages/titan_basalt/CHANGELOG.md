# Changelog

## 1.2.0

### Added

- **Sieve** — Reactive search, filter & sort engine for collections. Text search, named predicate filters (AND logic), sorting, and reactive outputs — all Pillar-managed.

## 1.1.0

### Added

- **Banner** — Reactive feature flag registry with percentage-based rollout, context-aware targeting rules, developer overrides, expiration, and remote config integration. Each flag is a reactive `Core<bool>` that triggers UI rebuilds when updated.

## 1.0.0

### Initial Release

Infrastructure & resilience features extracted from `titan` core:

- **Trove** — Reactive TTL/LRU in-memory cache with hit-rate tracking
- **Moat** — Token-bucket rate limiter with per-key quotas (MoatPool)
- **Portcullis** — Reactive circuit breaker with half-open probing
- **Anvil** — Dead letter & retry queue with configurable backoff
- **Pyre** — Priority-ordered async task queue with concurrency control
- **Codex** — Reactive paginated data loading (offset & cursor-based)
- **Quarry** — SWR data queries with dedup, retry, and optimistic updates
- **Bulwark** — Lightweight circuit breaker with reactive state
- **Saga** — Multi-step workflow orchestration with compensation/rollback
- **Volley** — Parallel batch async execution with progress tracking
- **Tether** — Composable middleware-style action chain
- **Annals** — Capped, queryable append-only audit log

All features integrate with `Pillar` via extension methods — use
`late final cache = trove(...)` just like core factory methods.
