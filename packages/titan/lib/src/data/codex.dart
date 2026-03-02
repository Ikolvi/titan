import '../core/batch.dart';
import '../core/state.dart';

// ---------------------------------------------------------------------------
// Codex — Titan's Pagination Layer
// ---------------------------------------------------------------------------

/// A page of data returned by a paginated fetch.
///
/// ```dart
/// return CodexPage(
///   items: results,
///   hasMore: results.length == pageSize,
///   nextCursor: lastItem?.id,
/// );
/// ```
class CodexPage<T> {
  /// The items in this page.
  final List<T> items;

  /// Whether more pages are available.
  final bool hasMore;

  /// The cursor for fetching the next page (cursor-based pagination).
  final String? nextCursor;

  /// Creates a page of paginated data.
  const CodexPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });
}

/// A request for a page of data.
///
/// Contains all information needed to fetch the next page,
/// whether using offset or cursor-based pagination.
class CodexRequest {
  /// The zero-based page number (offset pagination).
  final int page;

  /// The maximum number of items per page.
  final int pageSize;

  /// The cursor from the previous page (cursor pagination).
  final String? cursor;

  /// Creates a pagination request.
  const CodexRequest({required this.page, required this.pageSize, this.cursor});
}

/// **Codex** — Paginated data management with reactive state.
///
/// A Codex manages paginated data fetching — loading pages incrementally,
/// tracking loading/error/empty states, and providing `loadNext()` /
/// `refresh()` methods.
///
/// ## Why "Codex"?
///
/// A codex is an ancient book of pages. Codex manages your data page by page.
///
/// ## Usage with Pillar
///
/// ```dart
/// class QuestListPillar extends Pillar {
///   late final questCodex = codex<Quest>(
///     fetcher: (request) async {
///       final result = await api.getQuests(
///         page: request.page,
///         limit: request.pageSize,
///       );
///       return CodexPage(
///         items: result.items,
///         hasMore: result.hasMore,
///       );
///     },
///     pageSize: 20,
///   );
///
///   @override
///   void onInit() => questCodex.loadFirst();
/// }
/// ```
///
/// ## Cursor-Based Pagination
///
/// ```dart
/// late final feed = codex<Post>(
///   fetcher: (request) async {
///     final result = await api.getFeed(cursor: request.cursor, limit: request.pageSize);
///     return CodexPage(
///       items: result.posts,
///       hasMore: result.hasMore,
///       nextCursor: result.nextCursor,
///     );
///   },
///   pageSize: 10,
/// );
/// ```
class Codex<T> {
  final Future<CodexPage<T>> Function(CodexRequest request) _fetcher;
  final int pageSize;

  /// All accumulated items across all loaded pages.
  final TitanState<List<T>> items;

  /// Whether a page is currently being fetched.
  final TitanState<bool> isLoading;

  /// Whether more pages are available.
  final TitanState<bool> hasMore;

  /// The current page number (0-indexed).
  final TitanState<int> currentPage;

  /// The most recent error, or `null` if the last fetch succeeded.
  final TitanState<Object?> error;

  /// The cursor for the next page (cursor-based pagination).
  String? _nextCursor;

  /// Creates a Codex with a fetcher function and page size.
  Codex({
    required Future<CodexPage<T>> Function(CodexRequest request) fetcher,
    this.pageSize = 20,
    String? name,
  }) : _fetcher = fetcher,
       items = TitanState<List<T>>(
         [],
         name: name != null ? '${name}_items' : null,
       ),
       isLoading = TitanState<bool>(
         false,
         name: name != null ? '${name}_loading' : null,
       ),
       hasMore = TitanState<bool>(
         true,
         name: name != null ? '${name}_hasMore' : null,
       ),
       currentPage = TitanState<int>(
         0,
         name: name != null ? '${name}_page' : null,
       ),
       error = TitanState<Object?>(
         null,
         name: name != null ? '${name}_error' : null,
       );

  /// Whether the codex is empty and not loading.
  bool get isEmpty => items.value.isEmpty && !isLoading.value;

  /// Whether any items have been loaded.
  bool get isNotEmpty => items.value.isNotEmpty;

  /// The total number of items loaded so far.
  int get itemCount => items.value.length;

  /// Load the first page, clearing any existing data.
  ///
  /// This is typically called during `onInit()`.
  Future<void> loadFirst() async {
    items.value = [];
    currentPage.value = 0;
    hasMore.value = true;
    _nextCursor = null;
    error.value = null;
    await _loadPage(0);
  }

  /// Load the next page, appending to existing items.
  ///
  /// Does nothing if [isLoading] is `true` or [hasMore] is `false`.
  Future<void> loadNext() async {
    if (isLoading.value || !hasMore.value) return;
    await _loadPage(currentPage.value + 1);
  }

  /// Refresh from scratch — reload from page 0.
  ///
  /// Clears all existing data and starts fresh.
  Future<void> refresh() async {
    await loadFirst();
  }

  /// Refresh from page 0 without clearing existing items.
  ///
  /// Keeps current items visible while reloading. On success, replaces
  /// items atomically. On error, existing items remain untouched.
  /// Ideal for pull-to-refresh UX.
  ///
  /// ```dart
  /// // In a RefreshIndicator callback:
  /// onRefresh: () => codex.softRefresh(),
  /// ```
  Future<void> softRefresh() async {
    if (isLoading.value) return;
    isLoading.value = true;
    error.value = null;
    try {
      final request = CodexRequest(page: 0, pageSize: pageSize);
      final result = await _fetcher(request);
      titanBatch(() {
        items.value = result.items;
        currentPage.value = 0;
        hasMore.value = result.hasMore;
        _nextCursor = result.nextCursor;
        isLoading.value = false;
      });
    } catch (e) {
      titanBatch(() {
        error.value = e;
        isLoading.value = false;
      });
    }
  }

  /// Returns a filtered view of the current items.
  ///
  /// Does NOT modify the stored items — returns a new list with
  /// only the items matching [test]. Useful for client-side search
  /// and filtering without re-fetching.
  ///
  /// ```dart
  /// final completed = codex.where((q) => q.isCompleted);
  /// ```
  List<T> where(bool Function(T item) test) {
    return items.value.where(test).toList();
  }

  /// Replace all items (e.g., after sorting or bulk update).
  ///
  /// ```dart
  /// final sorted = [...codex.items.value]..sort((a, b) => a.name.compareTo(b.name));
  /// codex.replaceItems(sorted);
  /// ```
  void replaceItems(List<T> newItems) {
    items.value = newItems;
  }

  /// Insert an item at the given [index] (optimistic mutation).
  ///
  /// If [index] is omitted, prepends to the beginning.
  ///
  /// ```dart
  /// // Optimistic insert at top
  /// codex.insertItem(newQuest);
  ///
  /// // Insert at specific position
  /// codex.insertItem(quest, index: 3);
  /// ```
  void insertItem(T item, {int? index}) {
    final list = [...items.value];
    list.insert(index ?? 0, item);
    items.value = list;
  }

  /// Remove the first item matching [test] (optimistic mutation).
  ///
  /// Returns `true` if an item was removed, `false` otherwise.
  ///
  /// ```dart
  /// codex.removeItemWhere((q) => q.id == questId);
  /// ```
  bool removeItemWhere(bool Function(T item) test) {
    final list = [...items.value];
    final index = list.indexWhere(test);
    if (index == -1) return false;
    list.removeAt(index);
    items.value = list;
    return true;
  }

  /// Remove the item at [index] (optimistic mutation).
  ///
  /// Returns the removed item.
  ///
  /// ```dart
  /// final removed = codex.removeItemAt(2);
  /// ```
  T removeItemAt(int index) {
    final list = [...items.value];
    final removed = list.removeAt(index);
    items.value = list;
    return removed;
  }

  /// Update the first item matching [test] with [update] (optimistic mutation).
  ///
  /// Returns `true` if an item was updated, `false` otherwise.
  ///
  /// ```dart
  /// codex.updateItemWhere(
  ///   (q) => q.id == questId,
  ///   (q) => q.copyWith(completed: true),
  /// );
  /// ```
  bool updateItemWhere(bool Function(T item) test, T Function(T item) update) {
    final list = [...items.value];
    final index = list.indexWhere(test);
    if (index == -1) return false;
    list[index] = update(list[index]);
    items.value = list;
    return true;
  }

  /// Update the item at [index] with [update] (optimistic mutation).
  ///
  /// ```dart
  /// codex.updateItemAt(0, (q) => q.copyWith(pinned: true));
  /// ```
  void updateItemAt(int index, T Function(T item) update) {
    final list = [...items.value];
    list[index] = update(list[index]);
    items.value = list;
  }

  Future<void> _loadPage(int page) async {
    isLoading.value = true;
    error.value = null;

    try {
      final request = CodexRequest(
        page: page,
        pageSize: pageSize,
        cursor: _nextCursor,
      );

      final result = await _fetcher(request);

      titanBatch(() {
        if (page == 0) {
          items.value = result.items;
        } else {
          items.value = [...items.value, ...result.items];
        }

        currentPage.value = page;
        hasMore.value = result.hasMore;
        _nextCursor = result.nextCursor;
        isLoading.value = false;
      });
    } catch (e) {
      titanBatch(() {
        error.value = e;
        isLoading.value = false;
      });
    }
  }

  /// All managed reactive nodes (for disposal by Pillar).
  List<TitanState<dynamic>> get managedNodes => [
    items,
    isLoading,
    hasMore,
    currentPage,
    error,
  ];

  /// Dispose all managed state.
  void dispose() {
    for (final node in managedNodes) {
      node.dispose();
    }
  }
}
