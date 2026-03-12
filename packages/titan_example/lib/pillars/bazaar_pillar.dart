import 'package:titan_basalt/titan_basalt.dart';
import 'package:titan_colossus/titan_colossus.dart';
import 'package:titan_envoy/titan_envoy.dart';

import '../models/bazaar.dart';

// ---------------------------------------------------------------------------
// BazaarPillar — E-Commerce marketplace powered by Envoy
// ---------------------------------------------------------------------------
//
// Demonstrates every major Envoy feature with a REAL working API:
//   EnvoyPillar         — Dedicated HTTP client with auto-disposal
//   configureCouriers   — Full courier pipeline setup
//   LogCourier          — Request/response logging
//   RetryCourier        — Automatic retry on failure
//   CacheCourier        — HTTP-level response caching
//   DedupCourier        — Deduplication of concurrent GET requests
//   MetricsCourier      — Per-request performance metrics
//   Gate                — Concurrency throttle (max 6 parallel requests)
//   MemoryCache         — In-memory LRU cache (100 entries)
//   CachePolicy         — staleWhileRevalidate for product detail
//   Recall              — Cancel token for search debouncing
//   Codex + Envoy       — Paginated product list backed by HTTP
//   Quarry + Envoy      — SWR data fetching for product detail
//   envoyQuarry         — One-line SWR extension for categories
//   POST / PUT / DELETE — Write operations through Envoy
//   EnvoyMetric         — Real-time request metric tracking
//   EnvoyError          — Typed error handling
//   Derived             — Computed cart totals, filtered results
//   Core                — Local cart state, sorting, category filter
//
// API: DummyJSON (https://dummyjson.com) — REAL working e-commerce API
//   GET    /products               — paginated products
//   GET    /products/:id           — product detail with reviews
//   GET    /products/search?q=     — full-text product search
//   GET    /products/categories    — all categories
//   GET    /products/category/:s   — products by category
//   POST   /products/add           — create a new product
//   PUT    /products/:id           — update a product
//   DELETE /products/:id           — delete a product
//   GET    /carts/:id              — cart details
//   POST   /carts/add              — create a cart
//   PUT    /carts/:id              — update a cart
// ---------------------------------------------------------------------------

/// Sort options for the product listing.
enum WaresSortOrder {
  /// Default order (as returned by API).
  none,

  /// Price: low to high.
  priceLowToHigh,

  /// Price: high to low.
  priceHighToLow,

  /// Rating: highest first.
  ratingDesc,

  /// Name: A to Z.
  nameAsc,
}

/// Bazaar Pillar — manages the hero marketplace with real API calls.
///
/// Extends [EnvoyPillar] for a dedicated [Envoy] client with automatic
/// lifecycle management. Uses DummyJSON as a real working e-commerce API.
///
/// ```dart
/// // Access from any widget:
/// final pillar = context.pillar<BazaarPillar>();
/// pillar.searchProducts('phone');
/// pillar.addToCoffer(productId: 1, quantity: 2);
/// ```
class BazaarPillar extends EnvoyPillar {
  BazaarPillar()
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
    _cache = MemoryCache(maxEntries: 100);

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
      ..addCourier(Gate(maxConcurrent: 6)) // 5. Throttle concurrency
      ..addCourier(MetricsCourier(onMetric: _onMetric)); // 6. Track metrics
  }

  MemoryCache? _cache;

  // -------------------------------------------------------------------------
  // State — Paginated Products (Codex + Envoy)
  // -------------------------------------------------------------------------

  /// Paginated product list — fetches from `/products?limit=N&skip=N`.
  ///
  /// Uses [Codex] with an Envoy-powered fetcher for HTTP pagination.
  /// DummyJSON uses `limit` and `skip` query parameters.
  late final products = codex<Wares>(
    (request) async {
      final skip = request.page * request.pageSize;
      final category = selectedCategory.value;
      final String path;
      final Map<String, String> queryParams;

      if (category != null) {
        // Filter by category — DummyJSON category endpoint
        path = '/products/category/${category.slug}';
        queryParams = {
          'limit': request.pageSize.toString(),
          'skip': skip.toString(),
        };
      } else {
        // All products with optional sorting
        path = '/products';
        queryParams = {
          'limit': request.pageSize.toString(),
          'skip': skip.toString(),
          ..._sortQueryParams(),
        };
      }

      final dispatch = await envoy.get(path, queryParameters: queryParams);
      final data = dispatch.data as Map<String, dynamic>;
      final items = (data['products'] as List)
          .map((e) => Wares.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = data['total'] as int;
      final hasMore = skip + items.length < total;
      return CodexPage(items: items, hasMore: hasMore);
    },
    pageSize: 12,
    name: 'bazaarProducts',
  );

  Map<String, String> _sortQueryParams() {
    switch (sortOrder.value) {
      case WaresSortOrder.priceLowToHigh:
        return {'sortBy': 'price', 'order': 'asc'};
      case WaresSortOrder.priceHighToLow:
        return {'sortBy': 'price', 'order': 'desc'};
      case WaresSortOrder.ratingDesc:
        return {'sortBy': 'rating', 'order': 'desc'};
      case WaresSortOrder.nameAsc:
        return {'sortBy': 'title', 'order': 'asc'};
      case WaresSortOrder.none:
        return {};
    }
  }

  // -------------------------------------------------------------------------
  // State — Sort & Filter
  // -------------------------------------------------------------------------

  /// Current sort order for the product listing.
  late final sortOrder = core(WaresSortOrder.none, name: 'sortOrder');

  /// Currently selected category filter — `null` means all.
  late final selectedCategory = core<WaresCategory?>(
    null,
    name: 'selectedCategory',
  );

  // -------------------------------------------------------------------------
  // State — Search (Recall cancel token + server search)
  // -------------------------------------------------------------------------

  /// Search query text — drives server-side search.
  late final searchQuery = core('', name: 'bazaarSearchQuery');

  /// Search results from the DummyJSON `/products/search` endpoint.
  late final searchResults = core<List<Wares>>([], name: 'bazaarSearchResults');

  /// Whether a search request is in-flight.
  late final isSearchLoading = core(false, name: 'bazaarSearchLoading');

  /// Whether a search is currently active.
  late final isSearchActive = derived(
    () => searchQuery.value.isNotEmpty,
    name: 'bazaarSearchActive',
  );

  /// Active [Recall] token — cancelled when a new search starts.
  Recall? _activeSearchRecall;

  // -------------------------------------------------------------------------
  // State — Product Detail (Quarry + Envoy)
  // -------------------------------------------------------------------------

  /// The currently viewed product ID.
  late final waresId = core(0, name: 'waresId');

  /// Product detail — fetched from `/products/:id` with SWR caching.
  ///
  /// Uses [Quarry] with manual Envoy calls. The DummyJSON product
  /// response includes full details, images, and reviews.
  late final waresDetail = quarry<Wares>(
    fetcher: () async {
      final dispatch = await envoy.get('/products/${waresId.value}');
      return Wares.fromJson(dispatch.data as Map<String, dynamic>);
    },
    staleTime: const Duration(seconds: 30),
    retry: const QuarryRetry(maxAttempts: 3),
    name: 'waresDetail',
  );

  // -------------------------------------------------------------------------
  // State — Categories (envoyQuarry extension)
  // -------------------------------------------------------------------------

  /// All product categories — fetched via [envoyQuarry] extension.
  ///
  /// The `/products/categories` endpoint returns all categories at once.
  late final categories = envoyQuarry<List<WaresCategory>>(
    envoy: envoy,
    path: '/products/categories',
    fromJson: (data) => (data as List)
        .map((e) => WaresCategory.fromJson(e as Map<String, dynamic>))
        .toList(),
    staleTime: const Duration(minutes: 30),
    name: 'bazaarCategories',
  );

  // -------------------------------------------------------------------------
  // State — Local Cart (Coffer)
  // -------------------------------------------------------------------------

  /// Local cart items — tracks products added by the user.
  late final cofferItems = core<List<CofferItem>>([], name: 'cofferItems');

  /// Server-side cart (from DummyJSON API — fetched for demo purposes).
  late final serverCoffer = quarry<Coffer>(
    fetcher: () async {
      final dispatch = await envoy.get('/carts/1');
      return Coffer.fromJson(dispatch.data as Map<String, dynamic>);
    },
    staleTime: const Duration(minutes: 5),
    name: 'serverCoffer',
  );

  /// Total number of items in the local cart.
  late final cofferItemCount = derived(
    () => cofferItems.value.fold<int>(0, (sum, item) => sum + item.quantity),
    name: 'cofferItemCount',
  );

  /// Total price of items in the local cart.
  late final cofferTotal = derived(() {
    return cofferItems.value.fold<double>(0, (sum, item) => sum + item.total);
  }, name: 'cofferTotal');

  /// Discounted total of items in the local cart.
  late final cofferDiscountedTotal = derived(() {
    return cofferItems.value.fold<double>(
      0,
      (sum, item) => sum + item.discountedTotal,
    );
  }, name: 'cofferDiscountedTotal');

  /// Total savings from discounts.
  late final cofferSavings = derived(() {
    return cofferTotal.value - cofferDiscountedTotal.value;
  }, name: 'cofferSavings');

  // -------------------------------------------------------------------------
  // State — Metrics Dashboard
  // -------------------------------------------------------------------------

  /// All recorded HTTP request metrics.
  late final metrics = core<List<EnvoyMetric>>([], name: 'bazaarMetrics');

  /// Total number of HTTP requests made.
  late final totalRequests = derived(
    () => metrics.value.length,
    name: 'bazaarTotalRequests',
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
  }, name: 'bazaarAvgLatency');

  /// Number of cached responses.
  late final cacheHits = derived(
    () => metrics.value.where((m) => m.cached).length,
    name: 'bazaarCacheHits',
  );

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    _initializeBazaar();
  }

  Future<void> _initializeBazaar() async {
    try {
      // Load categories and first page of products in parallel
      await Future.wait([categories.fetch(), products.loadFirst()]);
      // Also fetch the demo server cart
      await serverCoffer.fetch();
      log.info(
        'Bazaar initialized — '
        '${products.items.value.length} wares loaded, '
        '${categories.data.value?.length ?? 0} categories',
      );
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'initBazaar');
    }
  }

  // -------------------------------------------------------------------------
  // Actions — Product List
  // -------------------------------------------------------------------------

  /// Load the next page of products.
  Future<void> loadMore() async {
    await products.loadNext();
  }

  /// Refresh the product list from the beginning.
  Future<void> refreshProducts() async {
    await products.refresh();
  }

  /// Change the sort order and reload products.
  Future<void> changeSortOrder(WaresSortOrder order) async {
    sortOrder.value = order;
    await products.refresh();
  }

  /// Filter products by category (or clear filter with `null`).
  Future<void> filterByCategory(WaresCategory? category) async {
    selectedCategory.value = category;
    await products.refresh();
  }

  // -------------------------------------------------------------------------
  // Actions — Search with Recall (server-side)
  // -------------------------------------------------------------------------

  /// Search products via the DummyJSON search endpoint.
  ///
  /// Demonstrates the Recall cancel-token pattern. Previous in-flight
  /// requests are automatically cancelled when a new search starts.
  Future<void> searchProducts(String query) async {
    // Cancel any pending search
    _activeSearchRecall?.cancel('superseded by new search');

    if (query.isEmpty) {
      searchQuery.value = '';
      searchResults.value = [];
      isSearchLoading.value = false;
      return;
    }

    searchQuery.value = query;
    _activeSearchRecall = Recall();
    isSearchLoading.value = true;

    try {
      final dispatch = await envoy.get(
        '/products/search',
        queryParameters: {'q': query, 'limit': '20'},
        recall: _activeSearchRecall,
      );
      final data = dispatch.data as Map<String, dynamic>;
      final items = (data['products'] as List)
          .map((e) => Wares.fromJson(e as Map<String, dynamic>))
          .toList();
      searchResults.value = items;
      log.info('Search "$query" returned ${items.length} results');
    } on EnvoyError catch (e) {
      if (e.type != EnvoyErrorType.cancelled) {
        captureError(e, action: 'searchProducts');
      }
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'searchProducts');
    } finally {
      isSearchLoading.value = false;
    }
  }

  /// Clear the search and return to the full product list.
  void clearSearch() {
    _activeSearchRecall?.cancel('search cleared');
    _activeSearchRecall = null;
    searchQuery.value = '';
    searchResults.value = [];
    isSearchLoading.value = false;
  }

  // -------------------------------------------------------------------------
  // Actions — Product Detail
  // -------------------------------------------------------------------------

  /// Load a product's detail by ID.
  Future<void> loadWaresDetail(int id) async {
    waresId.value = id;
    waresDetail.invalidate();
    await waresDetail.fetch();
    log.info('Loaded wares #$id: "${waresDetail.data.value?.title}"');
  }

  /// Refresh the current product detail.
  Future<void> refreshDetail() async {
    await waresDetail.refetch();
  }

  // -------------------------------------------------------------------------
  // Actions — Local Cart (Coffer) Management
  // -------------------------------------------------------------------------

  /// Add a product to the local coffer.
  ///
  /// If the item already exists, increases its quantity.
  void addToCoffer({required Wares wares, int quantity = 1}) {
    final existing = cofferItems.value;
    final index = existing.indexWhere((item) => item.id == wares.id);

    if (index >= 0) {
      // Update quantity of existing item
      final old = existing[index];
      final newQty = old.quantity + quantity;
      final updated = CofferItem(
        id: old.id,
        title: old.title,
        price: old.price,
        quantity: newQty,
        total: old.price * newQty,
        discountPercentage: old.discountPercentage,
        discountedTotal:
            old.price * newQty * (1 - old.discountPercentage / 100),
        thumbnail: old.thumbnail,
      );
      final items = List<CofferItem>.from(existing);
      items[index] = updated;
      cofferItems.value = items;
    } else {
      // Add new item
      final item = CofferItem(
        id: wares.id,
        title: wares.title,
        price: wares.price,
        quantity: quantity,
        total: wares.price * quantity,
        discountPercentage: wares.discountPercentage,
        discountedTotal: wares.discountedPrice * quantity,
        thumbnail: wares.thumbnail,
      );
      cofferItems.value = [...existing, item];
    }

    log.info('Added ${wares.title} (×$quantity) to coffer');
  }

  /// Remove an item from the local coffer.
  void removeFromCoffer(int productId) {
    cofferItems.value = cofferItems.value
        .where((item) => item.id != productId)
        .toList();
    log.info('Removed item #$productId from coffer');
  }

  /// Update the quantity of an item in the coffer.
  void updateCofferQuantity({required int productId, required int quantity}) {
    if (quantity <= 0) {
      removeFromCoffer(productId);
      return;
    }

    final items = List<CofferItem>.from(cofferItems.value);
    final index = items.indexWhere((item) => item.id == productId);
    if (index < 0) return;

    final old = items[index];
    items[index] = CofferItem(
      id: old.id,
      title: old.title,
      price: old.price,
      quantity: quantity,
      total: old.price * quantity,
      discountPercentage: old.discountPercentage,
      discountedTotal:
          old.price * quantity * (1 - old.discountPercentage / 100),
      thumbnail: old.thumbnail,
    );
    cofferItems.value = items;
  }

  /// Clear all items from the local coffer.
  void clearCoffer() {
    cofferItems.value = [];
    log.info('Coffer cleared');
  }

  // -------------------------------------------------------------------------
  // Actions — Server Cart Operations (POST / PUT)
  // -------------------------------------------------------------------------

  /// Submit the local coffer to the DummyJSON API as a new cart.
  ///
  /// Demonstrates POST with Envoy. DummyJSON returns the created cart
  /// with server-computed totals and discounts.
  Future<Coffer?> submitCoffer() async {
    if (cofferItems.value.isEmpty) return null;

    try {
      final dispatch = await envoy.post(
        '/carts/add',
        data: {
          'userId': 1,
          'products': cofferItems.value
              .map((item) => {'id': item.id, 'quantity': item.quantity})
              .toList(),
        },
      );
      final coffer = Coffer.fromJson(dispatch.data as Map<String, dynamic>);
      log.info(
        'Coffer submitted — ${coffer.totalProducts} products, '
        'total: \$${coffer.total.toStringAsFixed(2)}',
      );
      return coffer;
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'submitCoffer');
      return null;
    }
  }

  /// Update a server cart — demonstrates PUT with Envoy.
  Future<Coffer?> updateServerCart(int cartId) async {
    try {
      final dispatch = await envoy.put(
        '/carts/$cartId',
        data: {
          'merge': true,
          'products': cofferItems.value
              .map((item) => {'id': item.id, 'quantity': item.quantity})
              .toList(),
        },
      );
      final coffer = Coffer.fromJson(dispatch.data as Map<String, dynamic>);
      log.info('Server cart #$cartId updated');
      return coffer;
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'updateServerCart');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Actions — Product CRUD (POST / PUT / DELETE)
  // -------------------------------------------------------------------------

  /// Create a new product — demonstrates POST with Envoy.
  ///
  /// DummyJSON returns the created product with a new ID (simulated).
  Future<Wares?> createProduct({
    required String title,
    required String description,
    required double price,
    required String category,
  }) async {
    try {
      final dispatch = await envoy.post(
        '/products/add',
        data: {
          'title': title,
          'description': description,
          'price': price,
          'category': category,
        },
      );
      final wares = Wares.fromJson(dispatch.data as Map<String, dynamic>);
      log.info('Created product: "${wares.title}" (id: ${wares.id})');

      // Prepend to local list (DummyJSON doesn't persist)
      strike(() {
        products.items.value = [wares, ...products.items.value];
      });

      return wares;
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'createProduct');
      return null;
    }
  }

  /// Update a product — demonstrates PUT with Envoy.
  Future<Wares?> updateProduct({
    required int id,
    required String title,
    required double price,
  }) async {
    try {
      final dispatch = await envoy.put(
        '/products/$id',
        data: {'title': title, 'price': price},
      );
      final wares = Wares.fromJson(dispatch.data as Map<String, dynamic>);
      log.info('Updated product #$id: "${wares.title}"');
      return wares;
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'updateProduct');
      return null;
    }
  }

  /// Delete a product — demonstrates DELETE with Envoy.
  Future<bool> deleteProduct(int id) async {
    try {
      await envoy.delete('/products/$id');
      log.info('Deleted product #$id');

      // Remove from local list
      strike(() {
        products.items.value = products.items.value
            .where((w) => w.id != id)
            .toList();
      });

      return true;
    } catch (e, s) {
      captureError(e, stackTrace: s, action: 'deleteProduct');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Actions — Cache Management
  // -------------------------------------------------------------------------

  /// Clear the in-memory HTTP response cache.
  void clearCache() {
    _cache?.clear();
    log.info('Bazaar HTTP cache cleared');
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
