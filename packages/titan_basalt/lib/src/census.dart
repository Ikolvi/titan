/// Census — Reactive sliding-window data aggregation.
///
/// Collects values over a configurable time window and produces
/// real-time statistical aggregates (count, sum, average, min, max,
/// percentile). Unlike [Derived], which computes from **current** values,
/// Census computes from **historical** values within a time window.
///
/// ## Why "Census"?
///
/// A census is a systematic collection and aggregation of data about a
/// population. Titan's Census continuously aggregates reactive data
/// streams into statistical summaries — the population's vital signs.
///
/// ## Usage
///
/// ```dart
/// class DashboardPillar extends Pillar {
///   late final orderValue = core(0.0);
///   late final responseTime = core(0.0);
///
///   late final orderStats = census<double>(
///     source: orderValue,
///     window: Duration(minutes: 5),
///     name: 'orders',
///   );
///
///   // orderStats.count.value   → number of entries in window
///   // orderStats.sum.value     → sum of values in window
///   // orderStats.average.value → mean of values in window
///   // orderStats.min.value     → minimum value in window
///   // orderStats.max.value     → maximum value in window
///   // orderStats.percentile(95) → 95th percentile
/// }
/// ```
///
/// ## Manual Recording
///
/// If you don't have a reactive source, record values manually:
///
/// ```dart
/// late final latencyStats = census<double>(
///   window: Duration(minutes: 1),
///   name: 'latency',
/// );
///
/// void onRequestComplete(double ms) {
///   latencyStats.record(ms);
/// }
/// ```
///
/// ## Reactive State
///
/// | Property  | Type           | Description                        |
/// |-----------|----------------|------------------------------------|
/// | `count`   | `ReadCore<int>`    | Number of entries in the window    |
/// | `sum`     | `ReadCore<double>` | Sum of values in the window        |
/// | `average` | `Derived<double>`  | Mean of values (sum ÷ count)       |
/// | `min`     | `ReadCore<double>` | Minimum value in the window        |
/// | `max`     | `ReadCore<double>` | Maximum value in the window        |
/// | `last`    | `ReadCore<double>` | Most recently recorded value       |
///
/// ## Pillar Integration
///
/// Use the `census()` extension method on Pillar for lifecycle-managed
/// instances:
///
/// ```dart
/// late final stats = census<double>(
///   source: responseTime,
///   window: Duration(minutes: 5),
/// );
/// ```
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:titan/titan.dart';

/// A timestamped value entry in a [Census] window.
class CensusEntry<T extends num> {
  /// Creates a [CensusEntry].
  const CensusEntry(this.value, this.timestamp);

  /// The recorded value.
  final T value;

  /// When this value was recorded.
  final DateTime timestamp;
}

/// Reactive sliding-window data aggregation.
///
/// Collects numeric values over a configurable time [window] and
/// maintains running statistical aggregates that update reactively.
///
/// Values can be recorded manually via [record], or automatically
/// when a reactive [source] is provided.
///
/// See the library documentation for full usage examples.
class Census<T extends num> {
  /// Creates a [Census] with the given [window] duration.
  ///
  /// - [window] defines how far back values are retained. Entries older
  ///   than this duration are evicted on the next [record] or [evict] call.
  /// - [source] optionally subscribes to a reactive [Core] and
  ///   auto-records its value on every change.
  /// - [maxEntries] caps the buffer size to prevent unbounded growth.
  ///   When exceeded, the oldest entry is removed regardless of window.
  /// - [name] is used for debug output and [managedNodes] naming.
  Census({
    required this.window,
    Core<T>? source,
    this.maxEntries = 10000,
    this.name,
  }) {
    if (maxEntries <= 0) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'must be > 0');
    }
    final n = name ?? 'census';
    _count = TitanState<int>(0, name: '${n}_count');
    _sum = TitanState<double>(0, name: '${n}_sum');
    _min = TitanState<double>(double.infinity, name: '${n}_min');
    _max = TitanState<double>(double.negativeInfinity, name: '${n}_max');
    _last = TitanState<double>(0, name: '${n}_last');
    _average = TitanComputed<double>(
      () => _count.value > 0 ? _sum.value / _count.value : 0,
      name: '${n}_avg',
    );

    if (source != null) {
      _sourceSubscription = source.listen((_) {
        record(source.value);
      });
    }
  }

  /// The sliding time window. Entries older than this are evicted.
  final Duration window;

  /// Maximum number of entries retained. Prevents unbounded growth.
  final int maxEntries;

  /// Debug name.
  final String? name;

  // ── Internal state ─────────────────────────────────────────────────────

  final Queue<CensusEntry<T>> _entries = Queue<CensusEntry<T>>();
  late final TitanState<int> _count;
  late final TitanState<double> _sum;
  late final TitanState<double> _min;
  late final TitanState<double> _max;
  late final TitanState<double> _last;
  late final TitanComputed<double> _average;
  void Function()? _sourceSubscription;

  // ── Reactive properties ────────────────────────────────────────────────

  /// Number of entries currently in the window (reactive).
  ReadCore<int> get count => _count;

  /// Sum of all values in the window (reactive).
  ReadCore<double> get sum => _sum;

  /// Arithmetic mean of values in the window (reactive).
  /// Returns `0` when the window is empty.
  Derived<double> get average => _average;

  /// Minimum value in the window (reactive).
  /// Returns `double.infinity` when the window is empty.
  ReadCore<double> get min => _min;

  /// Maximum value in the window (reactive).
  /// Returns `double.negativeInfinity` when the window is empty.
  ReadCore<double> get max => _max;

  /// Most recently recorded value (reactive).
  ReadCore<double> get last => _last;

  /// All entries currently in the window (snapshot, not reactive).
  List<CensusEntry<T>> get entries => List.unmodifiable(_entries);

  // ── Primary API ────────────────────────────────────────────────────────

  /// Record a [value] into the census window.
  ///
  /// Evicts entries that have fallen outside the window, then appends
  /// the new value and recomputes all aggregates.
  ///
  /// ```dart
  /// stats.record(42.5);
  /// print(stats.count.value); // 1
  /// print(stats.sum.value);   // 42.5
  /// ```
  void record(T value) {
    final evicted = _evictStale();

    // Enforce maxEntries.
    var overflowEvicted = false;
    while (_entries.length >= maxEntries) {
      _entries.removeFirst();
      overflowEvicted = true;
    }

    final v = value.toDouble();
    _entries.addLast(CensusEntry<T>(value, DateTime.now()));
    _last.value = v;

    if (evicted || overflowEvicted) {
      // Full recompute needed — eviction may have removed min/max entries.
      _recompute();
    } else {
      // Fast incremental update — O(1).
      _count.value = _entries.length;
      _sum.value += v;
      _min.value = math.min(_min.value, v);
      _max.value = math.max(_max.value, v);
    }
  }

  /// Manually evict stale entries without recording a new value.
  ///
  /// Useful for timer-driven cleanup. Recomputes aggregates after
  /// eviction.
  void evict() {
    if (_evictStale()) {
      _recompute();
    }
  }

  /// Compute the [p]-th percentile of values in the window.
  ///
  /// [p] must be between 0 and 100 (inclusive).
  /// Returns `0` when the window is empty.
  ///
  /// Uses linear interpolation between closest ranks.
  ///
  /// ```dart
  /// final p95 = stats.percentile(95);
  /// final p50 = stats.percentile(50); // median
  /// ```
  double percentile(int p) {
    if (p < 0 || p > 100) {
      throw ArgumentError.value(p, 'p', 'must be between 0 and 100');
    }
    if (_entries.isEmpty) return 0;

    final sorted = _entries.map((e) => e.value.toDouble()).toList()..sort();
    if (sorted.length == 1) return sorted.first;

    final rank = (p / 100) * (sorted.length - 1);
    final lower = rank.floor();
    final upper = rank.ceil();

    if (lower == upper) return sorted[lower];

    final fraction = rank - lower;
    return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
  }

  /// Remove all entries and reset aggregates.
  void reset() {
    _entries.clear();
    _count.value = 0;
    _sum.value = 0;
    _min.value = double.infinity;
    _max.value = double.negativeInfinity;
    _last.value = 0;
  }

  /// Dispose the census, cancelling any source subscription.
  void dispose() {
    _sourceSubscription?.call();
    _sourceSubscription = null;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Reactive nodes managed by this Census for Pillar integration.
  Iterable<ReactiveNode> get managedNodes => [_count, _sum, _min, _max, _last];

  // ── Internal ───────────────────────────────────────────────────────────

  /// Returns `true` if any entries were evicted.
  bool _evictStale() {
    final cutoff = DateTime.now().subtract(window);
    var evicted = false;
    while (_entries.isNotEmpty && _entries.first.timestamp.isBefore(cutoff)) {
      _entries.removeFirst();
      evicted = true;
    }
    return evicted;
  }

  void _recompute() {
    if (_entries.isEmpty) {
      _count.value = 0;
      _sum.value = 0;
      _min.value = double.infinity;
      _max.value = double.negativeInfinity;
      return;
    }

    var s = 0.0;
    var lo = double.infinity;
    var hi = double.negativeInfinity;

    for (final e in _entries) {
      final v = e.value.toDouble();
      s += v;
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }

    _count.value = _entries.length;
    _sum.value = s;
    _min.value = lo;
    _max.value = hi;
  }
}
