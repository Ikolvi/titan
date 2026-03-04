# Changelog

## 1.12.4

### Fixed
- **BannerFlag**: Removed `assert` for rollout range validation in const constructor. Rollout is now validated exclusively via `ArgumentError` in `Banner()` constructor and `Banner.register()`, ensuring the check fires in release builds too.

## 1.12.3

### Changed

- **Assert → Runtime Errors**: All debug-only `assert` statements converted to runtime errors that fire in release builds:
  - `Embargo`: `ArgumentError` for non-positive permits
  - `Trove`: `ArgumentError` for non-positive maxEntries
  - `Volley`: `ArgumentError` for non-positive concurrency/maxRetries
  - `Census`: `ArgumentError` for non-positive maxEntries and invalid percentile range
  - `Moat`: `ArgumentError` for non-positive maxTokens and invalid consume amounts
  - `Pyre`: `ArgumentError` for non-positive concurrency/maxQueueSize/maxRetries
  - `Arbiter`: `ArgumentError` for null merge callback on custom strategy, `StateError` for use-after-dispose
  - `Tithe`: `ArgumentError` for non-positive budget/amount and invalid percentages, `StateError` for use-after-dispose
  - `Lode`: `ArgumentError` for non-positive maxSize, `StateError` for use-after-dispose and released lease access
  - `Warden`: `ArgumentError` for empty services list
  - `Clarion`: `StateError` for duplicate job registration
  - `Tapestry`: `StateError` for duplicate weave registration
  - `Sluice`: `ArgumentError` for empty stages and non-positive stage concurrency
  - `Banner`: `ArgumentError` for rollout values outside 0.0–1.0 (validated at `Banner` registration time)

## 1.12.2

### Fixed

- **Dependency**: Updated minimum `titan` constraint to `^1.1.0` (requires `Pillar.registerNodes()` API).
- **Example**: Added `example/example.dart` for pub.dev documentation score.

## 1.12.1

### Improved

- **Pyre** — O(1) enqueue/dequeue via per-priority `Queue` buckets (was O(n) sorted list insert + removeAt(0)).
- **Volley** — Added `maxRetries`, `retryDelay`, `taskTimeout`, per-task `VolleyTask.timeout`, `onTaskComplete`/`onTaskFailed` callbacks, separate `successCount`/`failedCount` tracking, `isDisposed` guard.
- **Tether** — Rewritten as instance-based with reactive state (`registeredCount`, `callCount`, `lastCallTime`, `errorCount`), `managedNodes`, `dispose()`. Added `Tether.global` singleton with static convenience API. Added `tether()` Pillar factory.
- **Annals** — Fixed `StreamController` leak (lazy creation + `dispose()`). Optimized `query()` with limit to avoid materializing full list. Changed backing store from `Queue` to `List`.
- **Saga** — Compensation errors now tracked in `compensationErrors` list instead of silently swallowed. Added `onCompensationError` callback.
- **Moat** — `consume()` now uses Completer-based wakeup instead of polling loop, eliminating unnecessary CPU cycles.
- **Trove** — `_purgeExpired()` optimized to single-pass (avoids redundant map re-lookup).

### Deprecated

- **Bulwark** — Deprecated in favor of `Portcullis` (superset). Will be removed in v2.0.

## 1.12.0

### Added

- **Tapestry** — Reactive event store with CQRS projections. Append-only event log with `TapestryStrand` envelopes (sequence, timestamp, correlationId, metadata), reactive `TapestryWeave` projections with fold functions and optional `where` filters, temporal event querying, `TapestryFrame` snapshots, replay, compaction, and `maxEvents` limit. Aggregate reactive state (eventCount, lastSequence, status, lastEventTime, weaveCount). Per-weave state (state, version, lastUpdated).

## 1.11.0

### Added

- **Clarion** — Reactive job scheduler. Manages recurring and one-shot async jobs with configurable intervals, concurrency policies (`skipIfRunning`, `allowOverlap`), per-job reactive observability (`isRunning`, `runCount`, `errorCount`, `lastRun`, `nextRun`), aggregate reactive state (`status`, `activeCount`, `totalRuns`, `totalErrors`, `successRate`, `isIdle`, `jobCount`), pause/resume per-job or globally, manual `trigger()`, and `ClarionRun` execution records.

## 1.10.0

### Added

- **Sluice** — Reactive multi-stage data pipeline. Processes items through configurable stages with per-stage metrics (processed, filtered, errors, queued), retry with configurable attempts, per-stage timeout, overflow strategies (backpressure, dropOldest, dropNewest), pause/resume control, and aggregate reactive state (fed, completed, failed, inFlight, status, errorRate).

## 1.9.0

### Added

- **Tithe** — Reactive quota & budget manager. Tracks cumulative resource consumption against configurable budgets with reactive signals (consumed, remaining, exceeded, ratio), per-key breakdown, threshold alerts at configurable percentages, auto-reset with periodic timer, and tryConsume for safe budget checks.

## 1.8.0

### Added

- **Lode** — Reactive resource pool for managing bounded pools of reusable expensive resources (database connections, HTTP clients, worker isolates). Acquire/release with LodeLease, withResource convenience, health validation on checkout, warmup/drain lifecycle, timeout on exhausted pool, and reactive metrics (available, inUse, size, waiters, utilization).

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
