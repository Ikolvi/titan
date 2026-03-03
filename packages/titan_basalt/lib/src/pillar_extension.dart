/// Extension methods on [Pillar] for Basalt infrastructure features.
///
/// Import `package:titan_basalt/titan_basalt.dart` to make these factory
/// methods available on any [Pillar] subclass via `late final` initializers:
///
/// ```dart
/// import 'package:titan_basalt/titan_basalt.dart';
///
/// class ApiPillar extends Pillar {
///   late final cache = trove<String, Data>(defaultTtl: Duration(minutes: 5));
///   late final limiter = moat(maxTokens: 60);
///   late final breaker = portcullis(failureThreshold: 5);
///   late final retryQueue = anvil<String>(maxRetries: 3);
///   late final uploads = pyre<String>(concurrency: 2);
/// }
/// ```
library;

import 'package:meta/meta.dart';
import 'package:titan/titan.dart';

import 'anvil.dart';
import 'arbiter.dart';
import 'banner.dart';
import 'bulwark.dart';
import 'census.dart';
import 'clarion.dart';
import 'codex.dart';
import 'embargo.dart';
import 'lattice.dart';
import 'lode.dart';
import 'moat.dart';
import 'portcullis.dart';
import 'pyre.dart';
import 'quarry.dart';
import 'saga.dart';
import 'sieve.dart';
import 'sluice.dart';
import 'tapestry.dart';
import 'tithe.dart';
import 'trove.dart';
import 'volley.dart';
import 'warden.dart';

/// Basalt infrastructure extensions on [Pillar].
///
/// These methods create lifecycle-managed infrastructure components
/// that auto-dispose when the Pillar is disposed.
extension PillarBasaltExtension on Pillar {
  // ---------------------------------------------------------------------------
  // Moat — rate limiter
  // ---------------------------------------------------------------------------

  /// Creates a [Moat] (rate limiter) managed by this Pillar.
  ///
  /// A Moat uses a token-bucket algorithm to control operation throughput.
  /// Tokens replenish at a steady rate, and requests that exceed the
  /// bucket capacity are rejected. All quota state is reactive.
  ///
  /// ```dart
  /// late final apiLimiter = moat(
  ///   maxTokens: 60,
  ///   refillRate: Duration(seconds: 1),
  ///   name: 'api',
  /// );
  ///
  /// Future<void> fetchData() async {
  ///   if (apiLimiter.tryConsume()) {
  ///     await api.getData();
  ///   }
  /// }
  /// ```
  @protected
  Moat moat({
    int maxTokens = 10,
    Duration refillRate = const Duration(seconds: 1),
    int? initialTokens,
    void Function()? onReject,
    String? name,
  }) {
    final m = Moat(
      maxTokens: maxTokens,
      refillRate: refillRate,
      initialTokens: initialTokens,
      onReject: onReject,
      name: name,
    );
    registerNodes(m.managedNodes);
    return m;
  }

  // ---------------------------------------------------------------------------
  // Trove — TTL/LRU in-memory cache
  // ---------------------------------------------------------------------------

  /// Creates a [Trove] (in-memory cache) managed by this Pillar.
  ///
  /// A Trove provides a reactive key-value cache with TTL-based expiry,
  /// optional LRU eviction, and live cache statistics (size, hits, misses).
  ///
  /// ```dart
  /// late final productCache = trove<String, Product>(
  ///   defaultTtl: Duration(minutes: 10),
  ///   maxEntries: 200,
  ///   name: 'products',
  /// );
  ///
  /// Future<Product> getProduct(String id) async {
  ///   return productCache.getOrPut(id, () => api.fetchProduct(id));
  /// }
  /// ```
  @protected
  Trove<K, V> trove<K, V>({
    Duration? defaultTtl,
    int? maxEntries,
    void Function(K key, V value, TroveEvictionReason reason)? onEvict,
    Duration cleanupInterval = const Duration(seconds: 60),
    String? name,
  }) {
    final t = Trove<K, V>(
      defaultTtl: defaultTtl,
      maxEntries: maxEntries,
      onEvict: onEvict,
      cleanupInterval: cleanupInterval,
      name: name,
    );
    registerNodes(t.managedNodes);
    return t;
  }

  // ---------------------------------------------------------------------------
  // Pyre — priority task queue
  // ---------------------------------------------------------------------------

  /// Creates a [Pyre] (priority task queue) managed by this Pillar.
  ///
  /// A Pyre processes async tasks in priority order with concurrency
  /// control, backpressure, and reactive queue metrics.
  ///
  /// ```dart
  /// late final uploads = pyre<String>(
  ///   concurrency: 2,
  ///   maxQueueSize: 50,
  ///   name: 'uploads',
  /// );
  /// ```
  @protected
  Pyre<T> pyre<T>({
    int concurrency = 3,
    int? maxQueueSize,
    int maxRetries = 0,
    Duration retryDelay = const Duration(milliseconds: 500),
    bool autoStart = true,
    void Function(String taskId, T result)? onTaskComplete,
    void Function(String taskId, Object error)? onTaskFailed,
    void Function()? onDrained,
    String? name,
  }) {
    final p = Pyre<T>(
      concurrency: concurrency,
      maxQueueSize: maxQueueSize,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
      autoStart: autoStart,
      onTaskComplete: onTaskComplete,
      onTaskFailed: onTaskFailed,
      onDrained: onDrained,
      name: name,
    );
    registerNodes(p.managedNodes);
    return p;
  }

  // ---------------------------------------------------------------------------
  // Portcullis — reactive circuit breaker
  // ---------------------------------------------------------------------------

  /// Creates a [Portcullis] (reactive circuit breaker) managed by this Pillar.
  ///
  /// Monitors failure rates and automatically trips when failures exceed
  /// [failureThreshold], fast-failing requests until recovery.
  ///
  /// ```dart
  /// late final apiBreaker = portcullis(
  ///   failureThreshold: 5,
  ///   resetTimeout: Duration(seconds: 30),
  ///   name: 'api',
  /// );
  ///
  /// Future<Data> fetchData() async {
  ///   return apiBreaker.protect(() => api.getData());
  /// }
  /// ```
  @protected
  Portcullis portcullis({
    int failureThreshold = 5,
    Duration resetTimeout = const Duration(seconds: 30),
    int halfOpenMaxProbes = 1,
    bool Function(Object error, StackTrace stack)? shouldTrip,
    int maxTripHistory = 20,
    String? name,
  }) {
    final p = Portcullis(
      failureThreshold: failureThreshold,
      resetTimeout: resetTimeout,
      halfOpenMaxProbes: halfOpenMaxProbes,
      shouldTrip: shouldTrip,
      maxTripHistory: maxTripHistory,
      name: name,
    );
    registerNodes([...p.managedNodes, ...p.managedStateNodes]);
    return p;
  }

  // ---------------------------------------------------------------------------
  // Anvil — dead letter & retry queue
  // ---------------------------------------------------------------------------

  /// Creates an [Anvil] (dead letter & retry queue) managed by this Pillar.
  ///
  /// Queues failed operations and retries them with configurable backoff.
  /// Entries that exhaust retries move to a dead-letter state for manual
  /// inspection and replay.
  ///
  /// ```dart
  /// late final retryQueue = anvil<String>(
  ///   maxRetries: 5,
  ///   backoff: AnvilBackoff.exponential(),
  ///   name: 'order-retry',
  /// );
  ///
  /// Future<void> submitOrder(Order order) async {
  ///   try {
  ///     await api.submit(order);
  ///   } catch (e) {
  ///     retryQueue.enqueue(
  ///       () => api.submit(order).then((_) => 'ok'),
  ///       id: 'order-${order.id}',
  ///     );
  ///   }
  /// }
  /// ```
  @protected
  Anvil<T> anvil<T>({
    int maxRetries = 3,
    AnvilBackoff? backoff,
    int maxDeadLetters = 100,
    bool autoStart = true,
    String? name,
  }) {
    final a = Anvil<T>(
      maxRetries: maxRetries,
      backoff: backoff,
      maxDeadLetters: maxDeadLetters,
      autoStart: autoStart,
      name: name,
    );
    registerNodes([...a.managedNodes, ...a.managedStateNodes]);
    return a;
  }

  // ---------------------------------------------------------------------------
  // Codex — paginated data
  // ---------------------------------------------------------------------------

  /// Creates a [Codex] (paginated data manager) managed by this Pillar.
  ///
  /// A Codex handles paginated data loading with reactive state for items,
  /// loading status, errors, and page tracking.
  ///
  /// ```dart
  /// late final quests = codex<Quest>(
  ///   (request) async {
  ///     final result = await api.getQuests(
  ///       page: request.page,
  ///       limit: request.pageSize,
  ///     );
  ///     return CodexPage(items: result.items, hasMore: result.hasMore);
  ///   },
  ///   pageSize: 20,
  /// );
  /// ```
  @protected
  Codex<T> codex<T>(
    Future<CodexPage<T>> Function(CodexRequest request) fetcher, {
    int pageSize = 20,
    String? name,
  }) {
    final c = Codex<T>(fetcher: fetcher, pageSize: pageSize, name: name);
    registerNodes(c.managedNodes);
    return c;
  }

  // ---------------------------------------------------------------------------
  // Quarry — data fetching with caching
  // ---------------------------------------------------------------------------

  /// Creates a [Quarry] (data fetching query) managed by this Pillar.
  ///
  /// A Quarry manages a single async data resource with reactive state,
  /// stale-while-revalidate caching, automatic deduplication, and retry.
  ///
  /// ```dart
  /// late final userQuery = quarry<User>(
  ///   fetcher: () => api.getUser(),
  ///   staleTime: Duration(minutes: 5),
  /// );
  /// ```
  @protected
  Quarry<T> quarry<T>({
    required Future<T> Function() fetcher,
    Duration? staleTime,
    QuarryRetry retry = const QuarryRetry(maxAttempts: 0),
    void Function(T data)? onSuccess,
    void Function(Object error)? onError,
    String? name,
  }) {
    final q = Quarry<T>(
      fetcher: fetcher,
      staleTime: staleTime,
      retry: retry,
      onSuccess: onSuccess,
      onError: onError,
      name: name,
    );
    registerNodes(q.managedNodes);
    return q;
  }

  // ---------------------------------------------------------------------------
  // Bulwark — circuit breaker
  // ---------------------------------------------------------------------------

  /// Creates a [Bulwark] (circuit breaker) managed by this Pillar.
  ///
  /// A Bulwark shields your app from cascading failures by tracking
  /// error rates and opening the circuit when a threshold is breached.
  ///
  /// ```dart
  /// late final apiBreaker = bulwark<String>(
  ///   failureThreshold: 3,
  ///   resetTimeout: Duration(seconds: 30),
  /// );
  /// ```
  @protected
  Bulwark<T> bulwark<T>({
    int failureThreshold = 3,
    Duration resetTimeout = const Duration(seconds: 30),
    void Function(Object error)? onOpen,
    void Function()? onClose,
    void Function()? onHalfOpen,
    String? name,
  }) {
    final b = Bulwark<T>(
      failureThreshold: failureThreshold,
      resetTimeout: resetTimeout,
      onOpen: onOpen,
      onClose: onClose,
      onHalfOpen: onHalfOpen,
      name: name,
    );
    registerNodes(b.managedNodes);
    return b;
  }

  // ---------------------------------------------------------------------------
  // Saga — multi-step workflow orchestration
  // ---------------------------------------------------------------------------

  /// Creates a [Saga] (multi-step workflow) managed by this Pillar.
  ///
  /// A Saga coordinates a sequence of async steps with automatic
  /// compensation (rollback) on failure.
  ///
  /// ```dart
  /// late final checkout = saga<Order>(
  ///   steps: [
  ///     SagaStep(name: 'validate', execute: (_) async => validate()),
  ///     SagaStep(
  ///       name: 'charge',
  ///       execute: (_) async => chargeCard(),
  ///       compensate: (_) async => refundCard(),
  ///     ),
  ///   ],
  /// );
  /// ```
  @protected
  Saga<T> saga<T>({
    required List<SagaStep<T>> steps,
    void Function(T? result)? onComplete,
    void Function(Object error, String failedStep)? onError,
    void Function(String stepName, int index, int total)? onStepComplete,
    String? name,
  }) {
    final s = Saga<T>(
      steps: steps,
      onComplete: onComplete,
      onError: onError,
      onStepComplete: onStepComplete,
      name: name,
    );
    registerNodes(s.managedNodes);
    return s;
  }

  // ---------------------------------------------------------------------------
  // Volley — batch async operations
  // ---------------------------------------------------------------------------

  /// Creates a [Volley] (batch async executor) managed by this Pillar.
  ///
  /// A Volley runs multiple async tasks in parallel with a configurable
  /// concurrency limit and reactive progress tracking.
  ///
  /// ```dart
  /// late final upload = volley<String>(concurrency: 3);
  /// ```
  @protected
  Volley<T> volley<T>({int concurrency = 5, String? name}) {
    final v = Volley<T>(concurrency: concurrency, name: name);
    registerNodes(v.managedNodes);
    return v;
  }

  // ---------------------------------------------------------------------------
  // Banner — reactive feature flags
  // ---------------------------------------------------------------------------

  /// Creates a [Banner] (reactive feature flag registry) managed by this Pillar.
  ///
  /// A Banner manages feature flags with reactive state, percentage-based
  /// rollout, context-aware targeting rules, developer overrides, and
  /// expiration. Each flag's state is a reactive [Core<bool>] that
  /// triggers UI rebuilds when updated.
  ///
  /// ```dart
  /// late final flags = banner(
  ///   flags: [
  ///     BannerFlag(name: 'dark-mode', defaultValue: false),
  ///     BannerFlag(
  ///       name: 'new-checkout',
  ///       rollout: 0.5,
  ///       description: 'New checkout flow',
  ///     ),
  ///     BannerFlag(
  ///       name: 'premium',
  ///       rules: [
  ///         BannerRule(
  ///           name: 'is-premium',
  ///           evaluate: (ctx) => ctx['tier'] == 'premium',
  ///         ),
  ///       ],
  ///     ),
  ///   ],
  /// );
  ///
  /// // Reactive — UI rebuilds when flag changes
  /// late final showNewCheckout = derived(
  ///   () => flags['new-checkout'].value,
  /// );
  /// ```
  @protected
  Banner banner({required List<BannerFlag> flags, String? name}) {
    final b = Banner(flags: flags, name: name);
    registerNodes(b.managedNodes);
    return b;
  }

  // ---------------------------------------------------------------------------
  // Sieve — reactive search, filter & sort
  // ---------------------------------------------------------------------------

  /// Creates a [Sieve] (reactive search/filter/sort) managed by this Pillar.
  ///
  /// A Sieve manages a dataset with text search, predicate-based filters,
  /// and sorting — all reactive. Results auto-update when source data,
  /// search query, or filters change.
  ///
  /// ```dart
  /// late final search = sieve<Quest>(
  ///   items: allQuests,
  ///   textFields: [(q) => q.title, (q) => q.description],
  /// );
  ///
  /// void filterByDifficulty(int min) {
  ///   search.where('difficulty', (q) => q.difficulty >= min);
  /// }
  ///
  /// void onSearch(String text) {
  ///   search.query.value = text;
  /// }
  /// ```
  @protected
  Sieve<T> sieve<T>({
    List<T> items = const [],
    List<String Function(T)> textFields = const [],
    String? name,
  }) {
    final s = Sieve<T>(items: items, textFields: textFields, name: name);
    registerNodes(s.managedNodes);
    return s;
  }

  /// Creates a Pillar-managed [Lattice] — reactive DAG task executor.
  ///
  /// All reactive nodes are registered for automatic disposal.
  ///
  /// ```dart
  /// class AppPillar extends Pillar {
  ///   late final startup = lattice(name: 'startup');
  ///
  ///   @override
  ///   void onInit() {
  ///     startup
  ///       ..node('config', (_) => loadConfig())
  ///       ..node('auth', (r) => login(r['config']),
  ///           dependsOn: ['config'])
  ///       ..node('data', (r) => fetchData(r['auth']),
  ///           dependsOn: ['auth']);
  ///     startup.execute();
  ///   }
  /// }
  /// ```
  @protected
  Lattice lattice({String? name}) {
    final l = Lattice(name: name);
    registerNodes(l.managedNodes);
    return l;
  }

  // ---------------------------------------------------------------------------
  // Embargo — async mutex/semaphore
  // ---------------------------------------------------------------------------

  /// Creates an [Embargo] (async mutex/semaphore) managed by this Pillar.
  ///
  /// All reactive nodes are registered for automatic disposal.
  ///
  /// ```dart
  /// class CheckoutPillar extends Pillar {
  ///   // Mutex — prevent double-submit.
  ///   late final submitLock = embargo(name: 'submit');
  ///
  ///   // Semaphore — max 3 concurrent API calls.
  ///   late final apiPool = embargo(permits: 3, name: 'api');
  ///
  ///   Future<void> submit() async {
  ///     await submitLock.guard(() async {
  ///       await api.placeOrder();
  ///     });
  ///   }
  /// }
  /// ```
  @protected
  Embargo embargo({int permits = 1, Duration? timeout, String? name}) {
    final e = Embargo(permits: permits, timeout: timeout, name: name);
    registerNodes(e.managedNodes);
    return e;
  }

  // ---------------------------------------------------------------------------
  // Census — sliding-window data aggregation
  // ---------------------------------------------------------------------------

  /// Creates a [Census] (sliding-window aggregation) managed by this Pillar.
  ///
  /// All reactive nodes are registered for automatic disposal. The
  /// source subscription (if any) is cleaned up on dispose.
  ///
  /// ```dart
  /// class DashboardPillar extends Pillar {
  ///   late final orderValue = core(0.0);
  ///
  ///   late final orderStats = census<double>(
  ///     source: orderValue,
  ///     window: Duration(minutes: 5),
  ///     name: 'orders',
  ///   );
  ///
  ///   // orderStats.count.value   → entries in window
  ///   // orderStats.average.value → running mean
  ///   // orderStats.percentile(95) → 95th percentile
  /// }
  /// ```
  @protected
  Census<T> census<T extends num>({
    required Duration window,
    Core<T>? source,
    int maxEntries = 10000,
    String? name,
  }) {
    final c = Census<T>(
      window: window,
      source: source,
      maxEntries: maxEntries,
      name: name,
    );
    registerNodes(c.managedNodes);
    return c;
  }

  // ---------------------------------------------------------------------------
  // Warden — service health monitor
  // ---------------------------------------------------------------------------

  /// Creates a [Warden] (service health monitor) managed by this Pillar.
  ///
  /// All reactive nodes are registered for automatic disposal. Timers
  /// are cancelled when the Pillar is disposed.
  ///
  /// ```dart
  /// class ApiPillar extends Pillar {
  ///   late final health = warden(
  ///     interval: Duration(seconds: 30),
  ///     services: [
  ///       WardenService(
  ///         name: 'auth',
  ///         check: () => api.ping('/auth/health'),
  ///       ),
  ///     ],
  ///   );
  ///
  ///   @override
  ///   void onInit() {
  ///     health.start();
  ///   }
  /// }
  /// ```
  @protected
  Warden warden({
    required Duration interval,
    required List<WardenService> services,
    String? name,
  }) {
    final w = Warden(interval: interval, services: services, name: name);
    registerNodes(w.managedNodes);
    return w;
  }

  // ---------------------------------------------------------------------------
  // Arbiter — conflict resolution
  // ---------------------------------------------------------------------------

  /// Creates a lifecycle-managed [Arbiter] for reactive conflict resolution.
  ///
  /// Submit values from multiple sources and resolve conflicts using
  /// pluggable strategies (lastWriteWins, firstWriteWins, merge, manual).
  ///
  /// ```dart
  /// class SyncPillar extends Pillar {
  ///   late final sync = arbiter<UserProfile>(
  ///     strategy: ArbiterStrategy.lastWriteWins,
  ///   );
  ///
  ///   void receiveRemote(UserProfile remote) {
  ///     sync.submit('server', remote);
  ///   }
  /// }
  /// ```
  @protected
  Arbiter<T> arbiter<T>({
    required ArbiterStrategy strategy,
    T Function(List<ArbiterConflict<T>> candidates)? merge,
    bool autoResolve = false,
    String? name,
  }) {
    final a = Arbiter<T>(
      strategy: strategy,
      merge: merge,
      autoResolve: autoResolve,
      name: name,
    );
    registerNodes(a.managedNodes);
    return a;
  }

  // ---------------------------------------------------------------------------
  // Lode — resource pool
  // ---------------------------------------------------------------------------

  /// Creates a lifecycle-managed [Lode] for reactive resource pooling.
  ///
  /// Manages a bounded pool of reusable resources with create/destroy
  /// lifecycle, optional health validation, and reactive metrics.
  ///
  /// ```dart
  /// class DbPillar extends Pillar {
  ///   late final pool = lode<DbConnection>(
  ///     create: () async => DbConnection.open('postgres://...'),
  ///     destroy: (conn) async => conn.close(),
  ///     maxSize: 10,
  ///   );
  ///
  ///   Future<List<Row>> query(String sql) async {
  ///     return pool.withResource((conn) => conn.query(sql));
  ///   }
  /// }
  /// ```
  @protected
  Lode<T> lode<T>({
    required Future<T> Function() create,
    Future<void> Function(T resource)? destroy,
    Future<bool> Function(T resource)? validate,
    int maxSize = 10,
    String? name,
  }) {
    final l = Lode<T>(
      create: create,
      destroy: destroy,
      validate: validate,
      maxSize: maxSize,
      name: name,
    );
    registerNodes(l.managedNodes);
    return l;
  }

  // ---------------------------------------------------------------------------
  // Tithe — quota & budget manager
  // ---------------------------------------------------------------------------

  /// Creates a lifecycle-managed [Tithe] for reactive quota tracking.
  ///
  /// Tracks cumulative resource consumption against a budget with
  /// reactive signals, per-key breakdown, threshold alerts, and
  /// optional auto-reset.
  ///
  /// ```dart
  /// class ApiPillar extends Pillar {
  ///   late final apiQuota = tithe(
  ///     budget: 1000,
  ///     resetInterval: Duration(hours: 1),
  ///   );
  ///
  ///   Future<void> callApi() async {
  ///     if (!apiQuota.tryConsume(1)) throw QuotaExceeded();
  ///     // ...
  ///   }
  /// }
  /// ```
  @protected
  Tithe tithe({required int budget, Duration? resetInterval, String? name}) {
    final t = Tithe(budget: budget, resetInterval: resetInterval, name: name);
    registerNodes(t.managedNodes);
    return t;
  }

  /// Creates a [Sluice] data pipeline managed by this Pillar.
  ///
  /// Items are processed through ordered [stages], each of which can
  /// transform, filter, retry, and timeout. The pipeline exposes
  /// reactive state (fed, completed, failed, inFlight, status) and
  /// per-stage metrics.
  ///
  /// ```dart
  /// class OrderPillar extends Pillar {
  ///   late final pipeline = sluice<Order>(
  ///     stages: [
  ///       SluiceStage(name: 'validate', process: (o) => validate(o)),
  ///       SluiceStage(name: 'charge', process: (o) async => charge(o)),
  ///     ],
  ///   );
  /// }
  /// ```
  @protected
  Sluice<T> sluice<T>({
    required List<SluiceStage<T>> stages,
    int bufferSize = 256,
    SluiceOverflow overflow = SluiceOverflow.backpressure,
    void Function(T item)? onComplete,
    void Function(T item, Object error, String stageName)? onError,
    String? name,
  }) {
    final s = Sluice<T>(
      stages: stages,
      bufferSize: bufferSize,
      overflow: overflow,
      onComplete: onComplete,
      onError: onError,
      name: name,
    );
    registerNodes(s.managedNodes);
    return s;
  }

  /// Creates a [Clarion] job scheduler managed by this Pillar.
  ///
  /// Schedule recurring or one-shot async jobs with reactive
  /// observability. All timers auto-cancel on Pillar disposal.
  ///
  /// ```dart
  /// class SyncPillar extends Pillar {
  ///   late final scheduler = clarion(name: 'sync');
  /// }
  /// ```
  @protected
  Clarion clarion({String? name}) {
    final c = Clarion(name: name);
    registerNodes(c.managedNodes);
    return c;
  }

  // ---------------------------------------------------------------------------
  // Tapestry — event store
  // ---------------------------------------------------------------------------

  /// Creates a [Tapestry] event store managed by this Pillar.
  ///
  /// An append-only event store with reactive CQRS projections.
  /// All reactive nodes auto-dispose on Pillar disposal.
  ///
  /// ```dart
  /// class OrderPillar extends Pillar {
  ///   late final events = tapestry<OrderEvent>(name: 'orders');
  /// }
  /// ```
  @protected
  Tapestry<E> tapestry<E>({String? name, int? maxEvents}) {
    final t = Tapestry<E>(name: name, maxEvents: maxEvents);
    registerNodes(t.managedNodes);
    return t;
  }
}
