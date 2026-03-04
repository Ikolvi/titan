/// Tithe — Reactive quota & budget manager.
///
/// Tracks cumulative resource consumption against configurable budgets
/// (API calls, storage bytes, tokens, operations) with reactive signals,
/// threshold alerts, auto-reset periods, and per-resource breakdowns.
///
/// ## Why "Tithe"?
///
/// A tithe is a measured portion — a precise accounting of what has been
/// given and what remains. Titan's Tithe tracks your application's
/// resource tithes: how much has been consumed, how much is left, and
/// when the budget is spent.
///
/// ## Complementary to Moat
///
/// [Moat] controls **flow rate** (requests/second). Tithe tracks
/// **cumulative total** (requests this billing period). Together they
/// provide complete resource governance.
///
/// ## Usage
///
/// ```dart
/// class ApiPillar extends Pillar {
///   late final apiQuota = tithe(
///     budget: 1000,           // 1000 API calls
///     resetInterval: Duration(hours: 1),  // Resets hourly
///     name: 'api',
///   );
///
///   Future<void> callApi() async {
///     if (apiQuota.exceeded.value) {
///       throw QuotaExceededException('API quota exhausted');
///     }
///     apiQuota.consume(1);
///     // ... make API call
///   }
/// }
/// ```
///
/// ## Reactive State
///
/// | Property    | Type              | Description                        |
/// |-------------|-------------------|------------------------------------|
/// | `consumed`  | `Core<int>`       | Total consumed in current period    |
/// | `remaining` | `Derived<int>`    | Budget - consumed                   |
/// | `exceeded`  | `Derived<bool>`   | Whether budget is exhausted         |
/// | `ratio`     | `Derived<double>` | Consumed / budget (0.0–1.0+)        |
/// | `breakdown` | `Core<Map<...>>`  | Per-resource consumption breakdown  |
///
/// ## Key Methods
///
/// | Method                   | Description                              |
/// |--------------------------|------------------------------------------|
/// | `consume(amount, {key})` | Deduct from budget, optionally per key   |
/// | `tryConsume(amount)`     | Returns false if would exceed budget     |
/// | `reset()`                | Manually reset to zero                   |
/// | `onThreshold(pct, fn)`   | Register alert at percentage threshold   |
/// | `dispose()`              | Cancel timers and dispose nodes          |
library;

import 'dart:async';

import 'package:titan/titan.dart';

/// A registered threshold callback.
class _ThresholdEntry {
  _ThresholdEntry(this.percent, this.callback);

  final double percent;
  final void Function() callback;
  bool fired = false;
}

/// Reactive quota & budget manager.
///
/// Tracks cumulative consumption against a fixed budget with reactive
/// signals, per-key breakdowns, threshold alerts, and optional
/// auto-reset on a timer.
///
/// ```dart
/// final quota = Tithe(budget: 100, name: 'ops');
///
/// quota.consume(10);
/// quota.consume(5, key: 'uploads');
///
/// print(quota.consumed.value);  // 15
/// print(quota.remaining.value); // 85
/// print(quota.ratio.value);     // 0.15
/// print(quota.exceeded.value);  // false
///
/// print(quota.breakdown.value); // {uploads: 5}
/// ```
class Tithe {
  /// Creates a quota manager.
  ///
  /// [budget] is the maximum allowed consumption per period.
  /// [resetInterval] if provided, automatically resets the budget
  /// on that interval. [name] is an optional prefix for reactive nodes.
  Tithe({required int budget, Duration? resetInterval, String? name})
    : _budget = budget {
    if (budget <= 0) {
      throw ArgumentError.value(budget, 'budget', 'must be positive');
    }
    final prefix = name ?? 'tithe';

    _consumed = TitanState<int>(0, name: '${prefix}_consumed');
    _breakdown = TitanState<Map<String, int>>({}, name: '${prefix}_breakdown');

    _remaining = TitanComputed<int>(
      () => _budget - _consumed.value,
      name: '${prefix}_remaining',
    );
    _exceeded = TitanComputed<bool>(
      () => _consumed.value >= _budget,
      name: '${prefix}_exceeded',
    );
    _ratio = TitanComputed<double>(
      () => _budget > 0 ? _consumed.value / _budget : 0.0,
      name: '${prefix}_ratio',
    );

    _nodes = [_consumed, _breakdown, _remaining, _exceeded, _ratio];

    if (resetInterval != null) {
      _resetTimer = Timer.periodic(resetInterval, (_) => reset());
    }
  }

  final int _budget;

  // Reactive state
  late final TitanState<int> _consumed;
  late final TitanState<Map<String, int>> _breakdown;
  late final TitanComputed<int> _remaining;
  late final TitanComputed<bool> _exceeded;
  late final TitanComputed<double> _ratio;

  late final List<ReactiveNode> _nodes;
  Timer? _resetTimer;
  bool _disposed = false;

  final List<_ThresholdEntry> _thresholds = [];

  // ─── Public reactive state ───────────────────────────────────

  /// Total consumed in the current period.
  Core<int> get consumed => _consumed;

  /// Remaining budget (budget - consumed). Can be negative.
  Derived<int> get remaining => _remaining;

  /// Whether the budget has been fully consumed.
  Derived<bool> get exceeded => _exceeded;

  /// Consumption ratio (0.0 = nothing used, 1.0 = fully used).
  /// Can exceed 1.0 if over-budget.
  Derived<double> get ratio => _ratio;

  /// Per-key consumption breakdown. Only includes keys passed
  /// via [consume]'s `key` parameter.
  Core<Map<String, int>> get breakdown => _breakdown;

  /// The configured budget.
  int get budget => _budget;

  /// Reactive nodes for Pillar lifecycle management.
  List<ReactiveNode> get managedNodes => _nodes;

  // ─── Public API ──────────────────────────────────────────────

  /// Consume [amount] from the budget.
  ///
  /// If [key] is provided, the amount is also tracked in [breakdown].
  /// Consumption is always recorded even if it exceeds the budget.
  /// Use [tryConsume] to check before consuming.
  void consume(int amount, {String? key}) {
    _assertNotDisposed();
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be positive');
    }

    _consumed.value += amount;

    if (key != null) {
      final map = Map<String, int>.from(_breakdown.value);
      map[key] = (map[key] ?? 0) + amount;
      _breakdown.value = map;
    }

    _checkThresholds();
  }

  /// Try to consume [amount]. Returns `true` if the budget allows it,
  /// `false` if it would exceed the budget (nothing is consumed).
  bool tryConsume(int amount, {String? key}) {
    _assertNotDisposed();
    if (_consumed.value + amount > _budget) return false;
    consume(amount, key: key);
    return true;
  }

  /// Reset consumption to zero and clear breakdown.
  ///
  /// Threshold alerts are re-armed so they can fire again.
  void reset() {
    _consumed.value = 0;
    _breakdown.value = {};
    for (final t in _thresholds) {
      t.fired = false;
    }
  }

  /// Register a threshold alert.
  ///
  /// [percent] is a value between 0.0 and 1.0 (e.g. 0.8 = 80%).
  /// [callback] is called once when consumption reaches or exceeds
  /// that percentage of the budget. Thresholds re-arm on [reset].
  void onThreshold(double percent, void Function() callback) {
    _assertNotDisposed();
    if (percent <= 0.0 || percent > 1.0) {
      throw ArgumentError.value(percent, 'percent', 'must be in (0.0, 1.0]');
    }
    _thresholds.add(_ThresholdEntry(percent, callback));
  }

  /// Dispose the quota manager, cancelling any auto-reset timer.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resetTimer?.cancel();
    _resetTimer = null;
    for (final node in _nodes) {
      node.dispose();
    }
  }

  // ─── Internal ────────────────────────────────────────────────

  void _checkThresholds() {
    final currentRatio = _consumed.value / _budget;
    for (final t in _thresholds) {
      if (!t.fired && currentRatio >= t.percent) {
        t.fired = true;
        t.callback();
      }
    }
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('Cannot use a disposed Tithe');
    }
  }
}
