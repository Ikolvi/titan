import 'package:titan_basalt/titan_basalt.dart';
import 'package:titan_colossus/titan_colossus.dart';
import 'package:titan_envoy/titan_envoy.dart';

import '../models/tale.dart';

// ---------------------------------------------------------------------------
// TavernPillar — HTTP-powered tale board using Envoy
// ---------------------------------------------------------------------------
//
// Demonstrates every major Envoy feature:
//   EnvoyPillar         — Dedicated HTTP client with auto-disposal
//   configureCouriers   — Full courier pipeline setup
//   LogCourier          — Request/response logging
//   RetryCourier        — Automatic retry on failure
//   CacheCourier        — HTTP-level response caching
//   DedupCourier        — Deduplication of concurrent GET requests
//   MetricsCourier      — Per-request performance metrics
//   Gate                — Concurrency throttle (max 4 parallel requests)
//   MemoryCache         — In-memory LRU cache (50 entries)
//   CachePolicy         — staleWhileRevalidate for tale detail
//   Recall              — Cancel token for search debouncing
//   Codex + Envoy       — Paginated list backed by HTTP
//   Quarry + Envoy      — SWR data fetching for detail + comments
//   envoyQuarry         — One-line SWR extension for guild members
//   POST / DELETE       — Write operations through Envoy
//   EnvoyMetric         — Real-time request metric tracking
//   EnvoyError          — Typed error handling
//
// API: DummyJSON (https://dummyjson.com)
//   GET    /posts           — paginated tales
//   GET    /posts/:id       — tale detail
//   GET    /comments/post/:id — tale comments
//   GET    /users           — guild members (authors)
//   POST   /posts/add       — create a new tale
//   DELETE /posts/:id       — delete a tale
// ---------------------------------------------------------------------------

/// Tavern Pillar — manages a bulletin board of hero tales fetched via HTTP.
///
/// Extends [EnvoyPillar] for a dedicated [Envoy] client with automatic
/// lifecycle management. The client is auto-disposed when the Pillar
/// is removed from the widget tree.
///
/// ```dart
/// // Access from any widget:
/// final pillar = context.pillar<TavernPillar>();
/// pillar.loadTaleDetail(42);
/// ```
class TavernPillar extends EnvoyPillar {
  TavernPillar()
    : super(
        baseUrl: 'https://dummyjson.com',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      );

  // -------------------------------------------------------------------------
  // Courier Configuration
  // -------------------------------------------------------------------------

  /// Sets up the full courier (interceptor) pipeline.
  ///
  /// Order matters — couriers execute in FIFO order on request,
  /// and reverse order on response.
  @override
  void configureCouriers(Envoy envoy) {
    _cache = MemoryCache(maxEntries: 50);

    envoy
      ..addCourier(LogCourier()) // 1. Log all requests/responses
      ..addCourier(DedupCourier()) // 2. Dedup concurrent GET requests
      ..addCourier(RetryCourier(maxRetries: 2)) // 3. Retry on failure
      ..addCourier(
        CacheCourier(
          cache: _cache!,
          defaultPolicy: const CachePolicy.staleWhileRevalidate(
            ttl: Duration(minutes: 5),
          ),
        ),
      ) // 4. Cache responses
      ..addCourier(Gate(maxConcurrent: 4)) // 5. Throttle concurrency
      ..addCourier(MetricsCourier(onMetric: _onMetric)); // 6. Track metrics
  }

  MemoryCache? _cache;

  // -------------------------------------------------------------------------
  // State — Paginated Tales (Codex + Envoy)
  // -------------------------------------------------------------------------

  /// Paginated tale list — fetches from `/posts?limit=N&skip=N`.
  ///
  /// Uses [Codex] with an Envoy-powered fetcher for HTTP pagination.
  /// DummyJSON uses `limit` and `skip` query parameters.
  late final tales = codex<Tale>(
    (request) async {
      final skip = request.page * request.pageSize;
      final dispatch = await envoy.get(
        '/posts',
        queryParameters: {
          'limit': request.pageSize.toString(),
          'skip': skip.toString(),
        },
      );
      final data = dispatch.data as Map<String, dynamic>;
      final items = (data['posts'] as List)
          .map((e) => Tale.fromJson(e as Map<String, dynamic>))
          .toList();
      // Enrich with cached author names
      for (final tale in items) {
        tale.authorName = _authorCache[tale.userId];
      }
      final total = data['total'] as int;
      final hasMore = skip + items.length < total;
      return CodexPage(items: items, hasMore: hasMore);
    },
    pageSize: 10,
    name: 'tales',
  );

  // -------------------------------------------------------------------------
  // State — Search (Recall cancel token)
  // -------------------------------------------------------------------------

  /// Search query text — drives client-side filtering.
  late final searchQuery = core('', name: 'searchQuery');

  /// Filtered results based on [searchQuery].
  late final searchResults = derived<List<Tale>>(() {
    final query = searchQuery.value.toLowerCase();
    if (query.isEmpty) return [];
    return tales.items.value
        .where(
          (t) =>
              t.title.toLowerCase().contains(query) ||
              t.body.toLowerCase().contains(query),
        )
        .toList();
  }, name: 'searchResults');

  /// Whether a search is currently active.
  late final isSearchActive = derived(
    () => searchQuery.value.isNotEmpty,
    name: 'isSearchActive',
  );

  /// Active [Recall] token — cancelled when a new search starts.
  Recall? _activeRecall;

  // -------------------------------------------------------------------------
  // State — Tale Detail (Quarry + Envoy)
  // -------------------------------------------------------------------------

  /// The currently viewed tale ID.
  late final taleId = core(0, name: 'taleId');

  /// Tale detail — fetched from `/posts/:id` with SWR caching.
  ///
  /// Uses a [Quarry] with manual Envoy calls for dynamic path support.
  /// This pattern is recommended when the endpoint path depends on state.
  late final taleDetail = quarry<Tale>(
    fetcher: () async {
      final dispatch = await envoy.get('/posts/${taleId.value}');
      final tale = Tale.fromJson(dispatch.data as Map<String, dynamic>);
      tale.authorName = _authorCache[tale.userId];
      return tale;
    },
    staleTime: const Duration(seconds: 30),
    retry: const QuarryRetry(maxAttempts: 3),
    name: 'taleDetail',
  );

  /// Comments on the current tale — fetched from `/comments/post/:id`.
  late final comments = quarry<List<TaleComment>>(
    fetcher: () async {
      final dispatch = await envoy.get('/comments/post/${taleId.value}');
      final data = dispatch.data as Map<String, dynamic>;
      return (data['comments'] as List)
          .map((e) => TaleComment.fromJson(e as Map<String, dynamic>))
          .toList();
    },
    staleTime: const Duration(minutes: 2),
    name: 'comments',
  );

  // -------------------------------------------------------------------------
  // State — Guild Members (envoyQuarry extension)
  // -------------------------------------------------------------------------

  /// Guild member directory — fetched via the [envoyQuarry] extension.
  ///
  /// This demonstrates the one-line convenience API for SWR data fetching.
  /// The `/users` endpoint returns all 10 users at once — perfect for
  /// a Quarry with a long stale time.
  late final members = envoyQuarry<List<GuildMember>>(
    envoy: envoy,
    path: '/users',
    fromJson: (data) {
      final map = data as Map<String, dynamic>;
      return (map['users'] as List)
          .map((e) => GuildMember.fromJson(e as Map<String, dynamic>))
          .toList();
    },
    staleTime: const Duration(minutes: 10),
    name: 'guildMembers',
  );

  /// Author name cache — populated from guild members.
  final Map<int, String> _authorCache = {};

  // -------------------------------------------------------------------------
  // State — Metrics Dashboard
  // -------------------------------------------------------------------------

  /// All recorded HTTP request metrics.
  late final metrics = core<List<EnvoyMetric>>([], name: 'metrics');

  /// Total number of HTTP requests made.
  late final totalRequests = derived(
    () => metrics.value.length,
    name: 'totalRequests',
  );

  /// Average request latency across all tracked requests.
  late final avgLatency = derived(() {
    final list = metrics.value;
    if (list.isEmpty) return Duration.zero;
    final totalMs = list.fold<int>(
      0,
      (sum, m) => sum + m.duration.inMilliseconds,
    );
    return Duration(milliseconds: totalMs ~/ list.length);
  }, name: 'avgLatency');

  /// Number of cached responses (status code 304 or cached flag).
  late final cacheHits = derived(
    () => metrics.value.where((m) => m.cached).length,
    name: 'cacheHits',
  );

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    _loadMembersAndTales();
  }

  Future<void> _loadMembersAndTales() async {
    try {
      // Load guild members first to populate author cache
      await members.fetch();
      final memberList = members.data.value;
      if (memberList != null) {
        for (final m in memberList) {
          _authorCache[m.id] = m.name;
        }
      }
      // Then load the first page of tales
      await tales.loadFirst();
      // Enrich loaded tales with author names
      _enrichTalesWithAuthors();
      log.info('Tavern initialized — ${tales.items.value.length} tales loaded');
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'initTavern');
    }
  }

  void _enrichTalesWithAuthors() {
    final enriched = tales.items.value.map((t) {
      t.authorName = _authorCache[t.userId];
      return t;
    }).toList();
    strike(() {
      tales.items.value = enriched;
    });
  }

  // -------------------------------------------------------------------------
  // Actions — Tale List
  // -------------------------------------------------------------------------

  /// Load the next page of tales.
  Future<void> loadMore() async {
    await tales.loadNext();
    _enrichTalesWithAuthors();
  }

  /// Refresh the tales list from the beginning.
  Future<void> refreshTales() async {
    await tales.refresh();
    _enrichTalesWithAuthors();
  }

  // -------------------------------------------------------------------------
  // Actions — Search with Recall
  // -------------------------------------------------------------------------

  /// Update the search query — cancels the previous [Recall] token.
  ///
  /// Demonstrates the Recall cancel-token pattern for debounced search.
  void updateSearch(String query) {
    // Cancel any pending operation from the previous search
    _activeRecall?.cancel('superseded by new search');
    _activeRecall = Recall();

    searchQuery.value = query;
  }

  /// Clear the search and return to the full list.
  void clearSearch() {
    _activeRecall?.cancel('search cleared');
    _activeRecall = null;
    searchQuery.value = '';
  }

  // -------------------------------------------------------------------------
  // Actions — Tale Detail
  // -------------------------------------------------------------------------

  /// Load a tale's detail and comments by ID.
  ///
  /// Issues parallel requests for both the tale and its comments,
  /// demonstrating concurrent Envoy requests through the Gate throttle.
  Future<void> loadTaleDetail(int id) async {
    taleId.value = id;
    taleDetail.invalidate();
    comments.invalidate();
    await Future.wait([taleDetail.fetch(), comments.fetch()]);
    log.info('Loaded tale #$id with comments');
  }

  /// Refresh the current tale detail and comments.
  Future<void> refreshDetail() async {
    await Future.wait([taleDetail.refetch(), comments.refetch()]);
  }

  // -------------------------------------------------------------------------
  // Actions — Create & Delete (POST / DELETE)
  // -------------------------------------------------------------------------

  /// Create a new tale — demonstrates POST with Envoy.
  ///
  /// DummyJSON returns the created resource with an assigned ID
  /// (simulated — the mock API doesn't persist).
  Future<Tale?> createTale({
    required String title,
    required String body,
  }) async {
    try {
      final dispatch = await envoy.post(
        '/posts/add',
        data: {'title': title, 'body': body, 'userId': 1},
      );
      final tale = Tale.fromJson(dispatch.data as Map<String, dynamic>);
      tale.authorName = _authorCache[1] ?? 'Anonymous';
      log.info('Created tale: "${tale.title}"');

      // Prepend to the local list (DummyJSON doesn't persist)
      strike(() {
        tales.items.value = [tale, ...tales.items.value];
      });

      return tale;
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'createTale');
      return null;
    }
  }

  /// Delete a tale — demonstrates DELETE with Envoy.
  Future<bool> deleteTale(int id) async {
    try {
      await envoy.delete('/posts/$id');
      log.info('Deleted tale #$id');

      // Remove from local list
      strike(() {
        tales.items.value = tales.items.value.where((t) => t.id != id).toList();
      });

      return true;
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'deleteTale');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Actions — Cache Management
  // -------------------------------------------------------------------------

  /// Clear the in-memory HTTP response cache.
  void clearCache() {
    _cache?.clear();
    log.info('HTTP cache cleared');
  }

  /// Returns the current cache size.
  int get cacheSize => _cache?.size ?? 0;

  // -------------------------------------------------------------------------
  // Metric Tracking
  // -------------------------------------------------------------------------

  void _onMetric(EnvoyMetric metric) {
    metrics.value = [...metrics.value, metric];

    // Forward to Colossus for unified API tracking dashboard
    if (Colossus.isActive) {
      Colossus.instance.trackApiMetric(metric.toJson());
    }

    log.debug(
      'HTTP ${metric.method} ${metric.url} → ${metric.statusCode} '
      'in ${metric.duration.inMilliseconds}ms'
      '${metric.cached ? ' (cached)' : ''}',
    );
  }
}
