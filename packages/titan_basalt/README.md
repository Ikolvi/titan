# Basalt — Titan's Infrastructure & Resilience Toolkit

[![pub package](https://img.shields.io/pub/v/titan_basalt.svg)](https://pub.dev/packages/titan_basalt)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Basalt** provides reactive infrastructure and resilience patterns that
integrate seamlessly with Titan's [Pillar](https://pub.dev/packages/titan)
lifecycle. All components auto-dispose when their owning Pillar is disposed.

## Features

| Feature | Class | Purpose |
|---------|-------|---------|
| Reactive Cache | **Trove** | TTL/LRU in-memory cache with reactive hit-rate statistics |
| Rate Limiter | **Moat** | Token-bucket rate limiting with per-key quotas (`MoatPool`) |
| Circuit Breaker | **Portcullis** | Automatic failure detection, half-open probing, and recovery |
| Retry Queue | **Anvil** | Dead letter & retry queue with exponential/linear/constant backoff |
| Task Queue | **Pyre** | Priority-ordered async task processing with concurrency control |
| Pagination | **Codex** | Reactive paginated data loading (offset & cursor-based) |
| Data Fetching | **Quarry** | SWR data queries with dedup, retry, and optimistic updates |
| Circuit Breaker (legacy) | **Bulwark** | Lightweight circuit breaker with reactive state |
| Workflow | **Saga** | Multi-step orchestration with automatic compensation/rollback |
| Batch Async | **Volley** | Parallel task execution with concurrency limit and progress |
| Action Chain | **Tether** | Composable middleware-style request/response pipeline |
| Audit Trail | **Annals** | Capped, queryable append-only audit log |
| Feature Flags | **Banner** | Reactive feature flags with rollout, rules, overrides, expiry |
| Search/Filter | **Sieve** | Reactive search, filter & sort engine for collections |
| DAG Executor | **Lattice** | Reactive DAG task executor with dependency resolution & parallelism |
| Async Mutex | **Embargo** | Reactive async mutex/semaphore with concurrency control |
| Data Aggregation | **Census** | Sliding-window statistical aggregation with reactive outputs |
| Service Health | **Warden** | Reactive service health monitoring with per-service status, latency, and failure tracking |
| Conflict Resolution | **Arbiter** | Multi-source conflict detection and resolution with pluggable strategies |
| Resource Pool | **Lode** | Reactive resource pool with lease management, warmup, drain, and utilization tracking |
| Quota & Budget | **Tithe** | Reactive quota tracking with per-key breakdown, threshold alerts, and auto-reset |
| Data Pipeline | **Sluice** | Reactive multi-stage data pipeline with per-stage metrics, retry, timeout, and overflow strategies |
| Job Scheduler | **Clarion** | Reactive job scheduler with recurring/one-shot jobs, concurrency policies, and per-job observability |
| Event Store | **Tapestry** | Append-only event store with reactive CQRS projections, temporal queries, replay, and compaction |

## Installation

```yaml
dependencies:
  titan: ^1.0.1
  titan_basalt: ^1.0.0
```

## Quick Start

```dart
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

class ApiPillar extends Pillar {
  // Cache API responses for 5 minutes
  late final cache = trove<String, Map<String, dynamic>>(
    defaultTtl: Duration(minutes: 5),
    maxEntries: 200,
    name: 'api-cache',
  );

  // Rate-limit API calls to 60/minute
  late final limiter = moat(
    maxTokens: 60,
    refillRate: Duration(seconds: 1),
    name: 'api-rate',
  );

  // Circuit breaker for external service
  late final breaker = portcullis(
    failureThreshold: 5,
    resetTimeout: Duration(seconds: 30),
    name: 'service',
  );

  // Retry failed operations with exponential backoff
  late final retryQueue = anvil<String>(
    maxRetries: 3,
    backoff: AnvilBackoff.exponential(),
    name: 'orders',
  );

  // Process uploads in priority order
  late final uploads = pyre<String>(
    concurrency: 2,
    maxQueueSize: 50,
    name: 'uploads',
  );
}
```

## Trove — Reactive Cache

```dart
late final cache = trove<String, Product>(
  defaultTtl: Duration(minutes: 10),
  maxEntries: 500,
  onEvict: (key, value, reason) => print('Evicted $key: $reason'),
);

// Cache operations
cache.put('product-1', product);
final hit = cache.get('product-1');        // cache hit
final miss = cache.get('nonexistent');     // null on miss
final fetched = await cache.getOrPut(      // fetch on miss
  'product-2', () => api.fetchProduct('2'),
);

// Reactive stats
print('Size: ${cache.size}');
print('Hit rate: ${cache.hitRate.toStringAsFixed(1)}%');
```

## Moat — Rate Limiter

```dart
late final limiter = moat(maxTokens: 100, refillRate: Duration(seconds: 1));

if (limiter.tryConsume()) {
  await api.call();
} else {
  print('Rate limited! ${limiter.availableTokens} tokens remaining');
}

// Per-key quotas
final pool = MoatPool(maxTokens: 10, refillRate: Duration(seconds: 5));
pool.tryConsume('user-123');
pool.tryConsume('user-456');
```

## Portcullis — Circuit Breaker

```dart
late final breaker = portcullis(
  failureThreshold: 5,
  resetTimeout: Duration(seconds: 30),
);

try {
  final result = await breaker.protect(() => api.fetchData());
} on PortcullisOpenException {
  print('Circuit open — service unavailable');
}

// Reactive state
print('State: ${breaker.state}');           // closed/open/halfOpen
print('Failures: ${breaker.failureCount}');
```

## Anvil — Retry Queue

```dart
late final retryQueue = anvil<String>(
  maxRetries: 5,
  backoff: AnvilBackoff.exponential(
    initial: Duration(seconds: 1),
    multiplier: 2.0,
    jitter: true,
  ),
);

retryQueue.enqueue(
  () async {
    await api.submitOrder(order);
    return 'success';
  },
  id: 'order-${order.id}',
);

// Monitor state
print('Pending: ${retryQueue.pendingCount}');
print('Dead letters: ${retryQueue.deadLetterCount}');
retryQueue.retryDeadLetters(); // Replay failed entries
```

## Pyre — Priority Task Queue

```dart
late final taskQueue = pyre<String>(concurrency: 3);

// Enqueue tasks with priority
taskQueue.enqueue(
  () async => processHighPriority(),
  priority: PyrePriority.high,
);
taskQueue.enqueue(
  () async => processLowPriority(),
  priority: PyrePriority.low,
);

// Reactive metrics
print('Queued: ${taskQueue.pending}');
print('Active: ${taskQueue.active}');
print('Completed: ${taskQueue.completed}');
```

## Architecture

Basalt features integrate with Pillar via **extension methods**. When you
import `titan_basalt`, factory methods like `trove()`, `moat()`,
`portcullis()`, `anvil()`, `pyre()`, `banner()`, `sieve()`, `lattice()`, `embargo()`, `census()`, `warden()`, `arbiter()`, `lode()`, `tithe()`, `sluice()`, `clarion()`, and `tapestry()` become available on any Pillar
subclass. These methods use `Pillar.registerNodes()` to ensure all
reactive nodes are auto-disposed with the Pillar lifecycle.

```
titan (core)  ──  Reactive engine, Pillar, DI, events
     ↑
titan_basalt  ──  Infrastructure & resilience extensions
```

## Related Packages

| Package | Purpose |
|---------|---------|
| [titan](https://pub.dev/packages/titan) | Core reactive engine |
| [titan_bastion](https://pub.dev/packages/titan_bastion) | Flutter widgets (Vestige, Beacon, Spark) |
| [titan_atlas](https://pub.dev/packages/titan_atlas) | Routing & navigation |
| [titan_argus](https://pub.dev/packages/titan_argus) | Authentication & authorization |
| [titan_colossus](https://pub.dev/packages/titan_colossus) | Performance monitoring |
