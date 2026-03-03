# Changelog

## 1.7.0

### Added

- **Arbiter** — Reactive conflict resolution with pluggable strategies (lastWriteWins, firstWriteWins, merge, manual). Submit values from multiple sources, detect conflicts reactively, auto-resolve or manually accept, with full resolution history and reactive state tracking.

## 1.6.0

### Added

- **Warden** — Reactive service health monitor with continuous polling, per-service reactive state (status, latency, failures, lastChecked), aggregate health for critical services, configurable down thresholds, per-service interval overrides, and manual `checkService()`/`checkAll()` methods.

## 1.5.0

### Added

- **Census** — Reactive sliding-window data aggregation with count, sum, average, min, max, percentile. Auto-records from reactive sources or accepts manual `record()` calls. Incremental O(1) updates on the hot path, configurable `maxEntries` buffer cap.

## 1.4.0

### Added

- **Embargo** — Reactive async mutex/semaphore with configurable permits, FIFO queuing, timeout support, automatic release on error, and reactive status/queue tracking. Mutex mode (permits=1) for double-submit prevention, semaphore mode (permits=N) for connection pooling.

## 1.3.0

### Added

- **Lattice** — Reactive DAG (directed acyclic graph) task executor with dependency resolution, automatic parallelism via Kahn's algorithm, fail-fast error handling, reactive progress/status tracking, and upstream result passing.

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
