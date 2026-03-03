/// Basalt — Titan's Infrastructure & Resilience Toolkit
///
/// Provides reactive infrastructure components that integrate with Titan's
/// [Pillar] lifecycle via extension methods:
///
/// | Feature | Class | Purpose |
/// |---------|-------|---------|
/// | Cache | **Trove** | TTL/LRU in-memory cache with reactive stats |
/// | Rate Limiter | **Moat** | Token-bucket rate limiting with per-key quotas |
/// | Circuit Breaker | **Portcullis** | Automatic failure detection & recovery |
/// | Retry Queue | **Anvil** | Dead letter & retry with configurable backoff |
/// | Task Queue | **Pyre** | Priority-ordered async task processing |
///
/// ## Quick Start
///
/// ```dart
/// import 'package:titan/titan.dart';
/// import 'package:titan_basalt/titan_basalt.dart';
///
/// class ApiPillar extends Pillar {
///   late final cache = trove<String, Data>(
///     defaultTtl: Duration(minutes: 5),
///   );
///   late final limiter = moat(maxTokens: 60);
///   late final breaker = portcullis(failureThreshold: 5);
///   late final retryQueue = anvil<String>(maxRetries: 3);
///   late final taskQueue = pyre<String>(concurrency: 2);
/// }
/// ```
///
/// All components auto-dispose when the owning Pillar is disposed.
library;

// Infrastructure features
export 'src/annals.dart';
export 'src/anvil.dart';
export 'src/banner.dart';
export 'src/bulwark.dart';
export 'src/codex.dart';
export 'src/moat.dart';
export 'src/portcullis.dart';
export 'src/pyre.dart';
export 'src/quarry.dart';
export 'src/saga.dart';
export 'src/sieve.dart';
export 'src/tether.dart';
export 'src/trove.dart';
export 'src/volley.dart';

// Pillar integration
export 'src/pillar_extension.dart';
