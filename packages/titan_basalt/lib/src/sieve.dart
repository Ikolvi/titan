import 'package:titan/titan.dart';

// =============================================================================
// Sieve — Reactive Search, Filter & Sort Engine
// =============================================================================

/// A reactive search, filter, and sort engine for collections.
///
/// **Sieve** manages a dataset with text search, predicate-based filters,
/// and sorting — all reactive. Any change to the source items, search query,
/// or filter set automatically recomputes the [results].
///
/// ## Quick start
///
/// ```dart
/// class QuestPillar extends Pillar {
///   late final search = sieve<Quest>(
///     items: allQuests,
///     textFields: [(q) => q.title, (q) => q.description],
///   );
///
///   void filterByDifficulty(int min) {
///     search.where('difficulty', (q) => q.difficulty >= min);
///   }
///
///   void onSearch(String text) {
///     search.query.value = text;
///   }
/// }
/// ```
///
/// ## Text search
///
/// Text search matches the query (case-insensitive substring) against any
/// field returned by [textFields]. All text fields must be non-null strings:
///
/// ```dart
/// search.query.value = 'dragon';
/// // results now contain only items where title or description
/// // contains 'dragon' (case-insensitive)
/// ```
///
/// ## Predicate filters
///
/// Filters are named predicates that stack with AND logic:
///
/// ```dart
/// search.where('active', (q) => q.status == 'active');
/// search.where('hard', (q) => q.difficulty >= 4);
/// // results: items matching search AND active AND hard
/// ```
///
/// ## Sorting
///
/// ```dart
/// search.sortBy((a, b) => a.title.compareTo(b.title));
/// ```
///
/// ## Reactive results
///
/// All outputs are reactive [Derived] values that trigger UI rebuilds:
///
/// ```dart
/// // In a Vestige:
/// Text('${pillar.search.resultCount.value} results');
/// ListView(children: pillar.search.results.value.map(...));
/// ```
class Sieve<T> {
  /// Creates a reactive search/filter/sort engine.
  ///
  /// - [items]: initial dataset (can be updated via [items] core)
  /// - [textFields]: functions that extract searchable text from items
  /// - [name]: optional debug name
  Sieve({
    List<T> items = const [],
    List<String Function(T)> textFields = const [],
    this.name,
  }) : _textFields = textFields {
    _items = TitanState<List<T>>(items);
    _query = TitanState<String>('');
    _filterVersion = TitanState<int>(0);

    _results = TitanComputed<List<T>>(() => _compute());
    _resultCount = TitanComputed<int>(() => _results.value.length);
    _totalCount = TitanComputed<int>(() => _items.value.length);
    _isFiltered = TitanComputed<bool>(() {
      // Read filter version to track changes
      _filterVersion.value;
      return _query.value.isNotEmpty || _predicates.isNotEmpty;
    });
  }

  /// Optional debug name.
  final String? name;

  final List<String Function(T)> _textFields;
  final Map<String, bool Function(T)> _predicates = {};
  Comparator<T>? _comparator;

  late final TitanState<List<T>> _items;
  late final TitanState<String> _query;
  late final TitanState<int> _filterVersion;
  late final TitanComputed<List<T>> _results;
  late final TitanComputed<int> _resultCount;
  late final TitanComputed<int> _totalCount;
  late final TitanComputed<bool> _isFiltered;

  // ---------------------------------------------------------------------------
  // Source data
  // ---------------------------------------------------------------------------

  /// The source dataset as a reactive [Core].
  ///
  /// Set `items.value = newList` to update the dataset. This triggers
  /// recomputation of [results].
  Core<List<T>> get items => _items;

  /// Replaces the source dataset. Convenience for `items.value = newItems`.
  void setItems(List<T> newItems) {
    _items.value = newItems;
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// The search query as a reactive [Core].
  ///
  /// Set `query.value = 'text'` to filter items by text. Text search
  /// matches case-insensitively against all [textFields].
  Core<String> get query => _query;

  /// Clears the search query.
  void clearQuery() {
    _query.value = '';
  }

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  /// Adds or replaces a named filter predicate.
  ///
  /// All filters are AND-combined: items must pass every predicate to
  /// appear in [results].
  ///
  /// ```dart
  /// sieve.where('active', (q) => q.status == 'active');
  /// sieve.where('hard', (q) => q.difficulty >= 4);
  /// ```
  void where(String key, bool Function(T item) predicate) {
    _predicates[key] = predicate;
    _filterVersion.value++;
  }

  /// Removes a named filter.
  void removeWhere(String key) {
    if (_predicates.remove(key) != null) {
      _filterVersion.value++;
    }
  }

  /// Removes all filters.
  void clearFilters() {
    if (_predicates.isNotEmpty) {
      _predicates.clear();
      _filterVersion.value++;
    }
  }

  /// Removes all filters and clears the search query.
  void reset() {
    _predicates.clear();
    _filterVersion.value++;
    _query.value = '';
    _comparator = null;
  }

  /// Returns the names of all active filters.
  List<String> get filterKeys => _predicates.keys.toList(growable: false);

  /// Whether a filter with [key] is active.
  bool hasFilter(String key) => _predicates.containsKey(key);

  /// The number of active filters.
  int get filterCount => _predicates.length;

  // ---------------------------------------------------------------------------
  // Sort
  // ---------------------------------------------------------------------------

  /// Sets the sort comparator for results.
  ///
  /// Pass `null` to remove sorting (items appear in source order).
  ///
  /// ```dart
  /// sieve.sortBy((a, b) => a.title.compareTo(b.title));
  /// ```
  void sortBy(Comparator<T>? comparator) {
    _comparator = comparator;
    _filterVersion.value++; // Trigger recomputation
  }

  // ---------------------------------------------------------------------------
  // Results (reactive)
  // ---------------------------------------------------------------------------

  /// Filtered, searched, and sorted results. Reactive — triggers rebuilds.
  Derived<List<T>> get results => _results;

  /// Count of items in [results]. Reactive.
  Derived<int> get resultCount => _resultCount;

  /// Total count of source items before filtering. Reactive.
  Derived<int> get totalCount => _totalCount;

  /// Whether any filter or search query is active. Reactive.
  Derived<bool> get isFiltered => _isFiltered;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Reactive nodes managed by this Sieve for Pillar lifecycle integration.
  Iterable<ReactiveNode> get managedNodes => [
    _items,
    _query,
    _filterVersion,
    _results,
    _resultCount,
    _totalCount,
    _isFiltered,
  ];

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  List<T> _compute() {
    final source = _items.value;
    final searchText = _query.value;
    // Read version to track filter changes in the dependency graph.
    _filterVersion.value;

    final hasSearch = searchText.isNotEmpty && _textFields.isNotEmpty;
    final hasFilters = _predicates.isNotEmpty;
    final hasSort = _comparator != null;

    // Fast path: no filtering or sorting needed.
    if (!hasSearch && !hasFilters && !hasSort) {
      return List<T>.of(source);
    }

    final lower = hasSearch ? searchText.toLowerCase() : '';

    var result = source.where((item) {
      // Text search (case-insensitive substring match)
      if (hasSearch) {
        final matches = _textFields.any(
          (field) => field(item).toLowerCase().contains(lower),
        );
        if (!matches) return false;
      }

      // Predicate filters (AND logic)
      if (hasFilters) {
        for (final predicate in _predicates.values) {
          if (!predicate(item)) return false;
        }
      }

      return true;
    }).toList();

    // Sort
    if (hasSort) {
      result.sort(_comparator);
    }

    return result;
  }

  @override
  String toString() {
    final label = name != null ? ' "$name"' : '';
    return 'Sieve$label(${_items.value.length} items, '
        '${_results.value.length} results, '
        '${_predicates.length} filters)';
  }
}
