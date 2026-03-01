import 'dart:async';

import '../core/state.dart';

// ---------------------------------------------------------------------------
// Quarry — Titan's Data Fetching Layer
// ---------------------------------------------------------------------------

/// Configuration for retry behavior.
class QuarryRetry {
  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Delay between retries. Doubles on each attempt (exponential backoff).
  final Duration baseDelay;

  /// Creates retry configuration.
  const QuarryRetry({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
  });
}

/// **Quarry** — Reactive data fetching with caching and stale-while-revalidate.
///
/// A Quarry manages a single async data resource — fetching, caching,
/// invalidating, and refetching it with reactive state. Inspired by
/// TanStack Query / React Query patterns.
///
/// ## Why "Quarry"?
///
/// A quarry is where raw resources are extracted. Quarry extracts your data
/// from remote sources and refines it into reactive state.
///
/// ## Features
///
/// - **Stale-while-revalidate**: show cached data while fetching fresh data
/// - **Automatic deduplication**: won't refetch if already loading
/// - **Retry with backoff**: automatic retry on failure
/// - **Manual invalidation**: mark data stale and trigger refetch
/// - **Optimistic updates**: update data locally before server confirms
/// - **Reactive state**: `data`, `isLoading`, `error`, `isFetching` are all
///   reactive Cores that trigger UI rebuilds automatically
///
/// ## Usage with Pillar
///
/// ```dart
/// class UserPillar extends Pillar {
///   late final userQuery = quarry<User>(
///     fetcher: () => api.getUser(),
///     staleTime: Duration(minutes: 5),
///   );
///
///   @override
///   void onInit() => userQuery.fetch();
/// }
/// ```
///
/// ## Stale-While-Revalidate
///
/// ```dart
/// late final profile = quarry<Profile>(
///   fetcher: () => api.getProfile(),
///   staleTime: Duration(minutes: 10),
/// );
///
/// // First call — fetches and caches.
/// await profile.fetch();
///
/// // Later — if data is stale, returns cached data immediately
/// // while fetching fresh data in the background.
/// await profile.fetch(); // Uses stale-while-revalidate
/// ```
///
/// ## Optimistic Updates
///
/// ```dart
/// void toggleFavorite(String questId) {
///   final current = questQuery.data.value!;
///   // Optimistic update
///   questQuery.setData(current.copyWith(isFavorite: !current.isFavorite));
///   // Then sync with server
///   api.toggleFavorite(questId).catchError((_) => questQuery.refetch());
/// }
/// ```
class Quarry<T> {
  final Future<T> Function() _fetcher;

  /// How long data remains fresh before becoming stale.
  ///
  /// If `null`, data is always considered stale.
  final Duration? staleTime;

  /// Retry configuration for failed fetches.
  final QuarryRetry retry;

  /// The fetched data, or `null` if not yet fetched.
  final TitanState<T?> data;

  /// Whether the initial fetch is in progress (no data yet).
  final TitanState<bool> isLoading;

  /// Whether a background refetch is in progress (data already exists).
  final TitanState<bool> isFetching;

  /// The most recent error, or `null` if the last fetch succeeded.
  final TitanState<Object?> error;

  /// When the data was last successfully fetched.
  DateTime? _lastFetchTime;

  /// Whether a fetch is currently in progress (deduplication).
  Completer<void>? _activeFetch;

  /// Creates a Quarry with a fetcher function and optional configuration.
  Quarry({
    required Future<T> Function() fetcher,
    this.staleTime,
    this.retry = const QuarryRetry(maxAttempts: 0),
    String? name,
  }) : _fetcher = fetcher,
       data = TitanState<T?>(null, name: name != null ? '${name}_data' : null),
       isLoading = TitanState<bool>(
         false,
         name: name != null ? '${name}_loading' : null,
       ),
       isFetching = TitanState<bool>(
         false,
         name: name != null ? '${name}_fetching' : null,
       ),
       error = TitanState<Object?>(
         null,
         name: name != null ? '${name}_error' : null,
       );

  /// Whether the data exists.
  bool get hasData => data.value != null;

  /// Whether there is an error.
  bool get hasError => error.value != null;

  /// Whether the cached data is stale.
  ///
  /// Data is stale if:
  /// - It has never been fetched.
  /// - [staleTime] is `null` (always stale).
  /// - The time since the last fetch exceeds [staleTime].
  bool get isStale {
    if (_lastFetchTime == null) return true;
    if (staleTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > staleTime!;
  }

  /// Fetch the data.
  ///
  /// **Stale-while-revalidate behavior:**
  /// - If no data exists, sets `isLoading = true` and fetches.
  /// - If data exists but is stale, keeps data visible and sets
  ///   `isFetching = true` while refetching in the background.
  /// - If data exists and is fresh, does nothing.
  ///
  /// **Deduplication:** If a fetch is already in progress, returns
  /// the same future without starting a second request.
  Future<void> fetch() async {
    // Fresh data — no need to refetch.
    if (hasData && !isStale) return;

    // Deduplicate concurrent fetches.
    if (_activeFetch != null) {
      return _activeFetch!.future;
    }

    final completer = Completer<void>();
    _activeFetch = completer;

    try {
      if (hasData) {
        // Stale-while-revalidate: keep data visible, show background indicator.
        isFetching.value = true;
      } else {
        // Initial load: show loading state.
        isLoading.value = true;
      }

      final result = await _fetchWithRetry();
      data.value = result;
      error.value = null;
      _lastFetchTime = DateTime.now();
    } catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
      isFetching.value = false;
      _activeFetch = null;
      completer.complete();
    }
  }

  /// Force a refetch, ignoring staleness.
  ///
  /// If data exists, uses stale-while-revalidate (keeps data visible).
  /// If no data exists, acts like [fetch].
  Future<void> refetch() async {
    _lastFetchTime = null; // Mark as stale.
    await fetch();
  }

  /// Mark the data as stale without immediately refetching.
  ///
  /// The next call to [fetch] will trigger a refetch.
  void invalidate() {
    _lastFetchTime = null;
  }

  /// Set data manually (optimistic update).
  ///
  /// This updates the data immediately without fetching from the server.
  /// Useful for optimistic UI updates.
  ///
  /// ```dart
  /// // Optimistic update
  /// query.setData(newValue);
  ///
  /// // Sync with server, refetch on failure
  /// api.update(newValue).catchError((_) => query.refetch());
  /// ```
  void setData(T value) {
    data.value = value;
    error.value = null;
    _lastFetchTime = DateTime.now();
  }

  /// Reset to initial state — clear all data, errors, and timing.
  void reset() {
    data.value = null;
    error.value = null;
    isLoading.value = false;
    isFetching.value = false;
    _lastFetchTime = null;
    _activeFetch = null;
  }

  Future<T> _fetchWithRetry() async {
    var attempts = 0;
    final maxAttempts = retry.maxAttempts;

    while (true) {
      try {
        return await _fetcher();
      } catch (e) {
        attempts++;
        if (maxAttempts <= 0 || attempts >= maxAttempts) rethrow;

        // Exponential backoff.
        final delay = retry.baseDelay * (1 << (attempts - 1));
        await Future<void>.delayed(delay);
      }
    }
  }

  /// All managed reactive nodes (for disposal by Pillar).
  List<TitanState<dynamic>> get managedNodes => [
    data,
    isLoading,
    isFetching,
    error,
  ];

  /// Dispose all managed state.
  void dispose() {
    for (final node in managedNodes) {
      node.dispose();
    }
  }
}
