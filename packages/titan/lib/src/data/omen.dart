/// Omen — Reactive async Derived with automatic dependency tracking.
///
/// An Omen evaluates an asynchronous computation whenever its reactive
/// dependencies change. It bridges the gap between synchronous [Derived]
/// values and async operations like API calls, database queries, or file
/// reads by automatically re-executing when any [Core] read inside its
/// computation function changes.
///
/// ## Why "Omen"?
///
/// An omen is a sign of things to come. Titan's Omen watches the present
/// state of your Cores and computes a future result — when the omens
/// change, the prophecy is rewritten.
///
/// ## Usage
///
/// ```dart
/// class SearchPillar extends Pillar {
///   late final query = core('');
///   late final sortBy = core('relevance');
///
///   // Auto-refetches when query or sortBy change
///   late final results = omen<List<Product>>(
///     () async => api.search(query.value, sort: sortBy.value),
///     debounce: Duration(milliseconds: 300),
///   );
/// }
/// ```
///
/// ## Features
///
/// - **Auto-tracking** — reads Core values inside the compute function to
///   detect dependencies automatically (same mechanism as [Derived])
/// - **Debounce** — coalesces rapid dependency changes before re-evaluating
/// - **AsyncValue lifecycle** — exposes `loading`, `data`, `refreshing`,
///   `error` states via the standard [AsyncValue] sealed class
/// - **Cancellation** — cancels in-flight computations when dependencies
///   change or when manually cancelled
/// - **Stale-while-revalidate** — shows previous data while refreshing
/// - **Pillar integration** — `omen()` factory method with auto-disposal
///
/// ## Reactive Stats
///
/// ```dart
/// // In a Vestige builder:
/// final snapshot = pillar.results.value;
/// snapshot.when(
///   onData: (products) => ProductList(products),
///   onLoading: () => Spinner(),
///   onError: (e, s) => ErrorWidget(e),
/// );
/// ```
library;

import 'dart:async';

import '../async/async_value.dart';
import '../core/reactive.dart';
import '../core/state.dart';

/// Reactive async computed value with automatic dependency tracking.
///
/// An Omen re-evaluates its async [compute] function whenever the
/// reactive dependencies read during the previous evaluation change.
///
/// ## Example
///
/// ```dart
/// class DashboardPillar extends Pillar {
///   late final userId = core('user-42');
///   late final includeArchived = core(false);
///
///   late final stats = omen<DashboardStats>(
///     () async => api.fetchStats(
///       userId.value,
///       archived: includeArchived.value,
///     ),
///     debounce: Duration(milliseconds: 500),
///   );
/// }
/// ```
class Omen<T> extends ReactiveNode {
  /// The async computation function that reads reactive Cores.
  final Future<T> Function() _compute;

  /// Debounce duration for coalescing rapid dependency changes.
  final Duration? _debounce;

  /// Whether to keep the previous data visible while refreshing.
  final bool _keepPreviousData;

  /// The reactive AsyncValue state.
  final TitanState<AsyncValue<T>> _state;

  /// Stored name for lazy initialization.
  final String? _name;

  /// Reactive execution count (lazy — avoids allocation if never read).
  TitanState<int>? __executionCount;

  /// Reactive execution count.
  TitanState<int> get _executionCount => __executionCount ??= TitanState<int>(
    0,
    name: _name != null ? '${_name}_executions' : null,
  );

  /// Currently tracked dependencies.
  Set<ReactiveNode> _dependencies = {};

  /// Monotonic version counter for execution cancellation.
  int _executionVersion = 0;

  /// Debounce timer.
  Timer? _debounceTimer;

  /// Whether the omen has ever been evaluated.
  bool _hasEverExecuted = false;

  /// Creates a reactive async computed value.
  ///
  /// - [compute] — Async function that reads Core values. Titan will
  ///   automatically detect which Cores are read and re-execute when
  ///   they change.
  /// - [debounce] — Optional debounce duration. If set, rapid dependency
  ///   changes are coalesced so the computation runs at most once per
  ///   debounce interval.
  /// - [keepPreviousData] — If `true` (default), previous data is shown
  ///   via [AsyncRefreshing] while a re-computation is in flight.
  /// - [name] — Debug name for internal Cores.
  /// - [eager] — If `true` (default), executes immediately on creation.
  ///
  /// ```dart
  /// final results = Omen<List<Product>>(
  ///   () async => api.search(query.value),
  ///   debounce: Duration(milliseconds: 300),
  /// );
  /// ```
  Omen(
    Future<T> Function() compute, {
    Duration? debounce,
    bool keepPreviousData = true,
    String? name,
    bool eager = true,
  }) : _compute = compute,
       _debounce = debounce,
       _keepPreviousData = keepPreviousData,
       _name = name,
       _state = TitanState<AsyncValue<T>>(
         const AsyncLoading(),
         name: name != null ? '${name}_state' : null,
       ) {
    if (eager) {
      _executeInitial();
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// The current [AsyncValue] state (reactive).
  ///
  /// Read `.value` to get the current state:
  /// ```dart
  /// final snapshot = omen.value;
  /// if (snapshot case AsyncData(:final data)) {
  ///   print(data);
  /// }
  /// ```
  AsyncValue<T> get value {
    // Track this omen as a dependency when read inside a scope
    _state.track();
    return _state.value;
  }

  /// The underlying reactive state node.
  TitanState<AsyncValue<T>> get state => _state;

  /// Reactive execution count (lazy — allocated on first access).
  TitanState<int> get executionCount => _executionCount;

  /// The current data, if available.
  T? get data => _state.value.dataOrNull;

  /// Whether the current state is loading.
  bool get isLoading => _state.value.isLoading;

  /// Whether the current state has data.
  bool get hasData => _state.value.hasData;

  /// Whether the current state has an error.
  bool get hasError => _state.value.isError;

  /// Whether the omen is currently refreshing (has data + loading).
  bool get isRefreshing => _state.value.isRefreshing;

  /// All managed reactive nodes (for Pillar disposal).
  List<TitanState<dynamic>> get managedNodes => [_state, ?__executionCount];

  /// Manually trigger a re-execution, regardless of dependency changes.
  ///
  /// ```dart
  /// omen.refresh(); // re-fetches even if no dependency changed
  /// ```
  void refresh() {
    _debounceTimer?.cancel();
    _execute();
  }

  /// Cancel the in-flight computation.
  ///
  /// The state remains at its current value. Call [refresh] to restart.
  void cancel() {
    _debounceTimer?.cancel();
    _executionVersion++;
  }

  /// Reset to initial loading state and re-execute.
  void reset() {
    cancel();
    _state.value = const AsyncLoading();
    __executionCount?.value = 0;
    _hasEverExecuted = false;
    _execute();
  }

  @override
  void dispose() {
    cancel();
    _clearDependencies();
    _state.dispose();
    __executionCount?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dependency tracking + async execution
  // ---------------------------------------------------------------------------

  /// Fast-path for the initial eager execution.
  ///
  /// Skips redundant work that only matters on re-execution:
  /// - No previous execution to cancel
  /// - State is already [AsyncLoading] from the constructor
  /// - Dependencies set is already empty — no swap/diff needed
  void _executeInitial() {
    final previous = ReactiveScope.pushTracker(this);

    late final Future<T> future;
    try {
      future = _compute();
    } catch (e, s) {
      ReactiveScope.popTracker(previous);
      _state.value = AsyncError<T>(e, s);
      _hasEverExecuted = true;
      _executionCount.value++;
      return;
    }
    ReactiveScope.popTracker(previous);

    // Async resolution — capture version to detect stale callbacks
    final version = _executionVersion;

    future.then(
      (result) {
        if (version != _executionVersion || isDisposed) return;
        _state.value = AsyncData<T>(result);
        _executionCount.value++;
      },
      onError: (Object e, StackTrace s) {
        if (version != _executionVersion || isDisposed) return;
        _state.value = AsyncError<T>(e, s);
        _executionCount.value++;
      },
    );

    _hasEverExecuted = true;
  }

  /// Execute the async computation with dependency tracking.
  void _execute() {
    if (isDisposed) return;

    // Cancel any previous in-flight computation
    _executionVersion++;

    // Phase 1: Prepare state (OUTSIDE tracker scope to avoid self-dependency)
    // Reading _state via peek() avoids the track() overhead.
    final existingData = _state.peek().dataOrNull;
    if (_keepPreviousData && existingData != null) {
      _state.value = AsyncRefreshing<T>(existingData);
    }

    // Phase 2: Synchronous dependency tracking
    // Push Omen as the tracker so that Core reads inside _compute()
    // register as dependencies. Only _compute() runs inside this scope.
    final oldDeps = _dependencies;
    final newDeps = <ReactiveNode>{};
    _dependencies = newDeps;

    final previous = ReactiveScope.pushTracker(this);

    late final Future<T> future;
    try {
      future = _compute();
    } catch (e, s) {
      ReactiveScope.popTracker(previous);
      _state.value = AsyncError<T>(e, s);
      _diffDependencies(oldDeps, newDeps);
      _hasEverExecuted = true;
      _executionCount.value++;
      return;
    }
    ReactiveScope.popTracker(previous);

    // Phase 3: Async resolution — capture version to detect stale callbacks
    final version = _executionVersion;

    future.then(
      (result) {
        if (version != _executionVersion || isDisposed) return;
        _state.value = AsyncData<T>(result);
        _executionCount.value++;
      },
      onError: (Object e, StackTrace s) {
        if (version != _executionVersion || isDisposed) return;
        _state.value = AsyncError<T>(e, s);
        _executionCount.value++;
      },
    );

    // Diff dependencies
    _diffDependencies(oldDeps, newDeps);
    _hasEverExecuted = true;
  }

  /// Diff old vs new dependencies: unsubscribe from stale, keep new.
  void _diffDependencies(Set<ReactiveNode> oldDeps, Set<ReactiveNode> newDeps) {
    if (_hasEverExecuted) {
      for (final dep in oldDeps) {
        if (!newDeps.contains(dep)) {
          dep.removeDependent(this);
        }
      }
    }
  }

  /// Clear all tracked dependencies.
  void _clearDependencies() {
    for (final dep in _dependencies) {
      dep.removeDependent(this);
    }
    _dependencies.clear();
  }

  /// Called when a tracked dependency changes.
  @override
  void onDependencyChanged(ReactiveNode dependency) {
    if (isDisposed) return;

    if (_debounce != null) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounce, _execute);
    } else {
      _execute();
    }
  }

  @override
  void onTracked(ReactiveNode source) {
    _dependencies.add(source);
  }

  @override
  String toString() {
    final stateStr = switch (_state.value) {
      AsyncData<T>(:final data) => 'data: $data',
      AsyncLoading<T>() => 'loading',
      AsyncRefreshing<T>(:final data) => 'refreshing (prev: $data)',
      AsyncError<T>(:final error) => 'error: $error',
    };
    final execCount = __executionCount?.peek() ?? 0;
    return 'Omen<$T>($stateStr, executions: $execCount)';
  }
}
