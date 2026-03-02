/// Snapshot — Capture and restore Pillar state.
///
/// A Snapshot captures all named [Core] values from a Pillar into an
/// immutable map, then restores them on demand. Useful for testing,
/// undo workflows, debugging, and state persistence.
///
/// ## Why "Snapshot"?
///
/// A snapshot freezes a moment in time. Titan's Snapshot preserves
/// the exact reactive state of a Pillar for later restoration.
///
/// ## Usage
///
/// ```dart
/// class CounterPillar extends Pillar {
///   late final count = core(0, name: 'count');
///   late final label = core('hello', name: 'label');
/// }
///
/// final pillar = CounterPillar();
/// pillar.count.value = 10;
///
/// // Capture
/// final snap = Snapshot.capture(pillar);
/// print(snap.values); // {'count': 10, 'label': 'hello'}
///
/// // Mutate
/// pillar.count.value = 99;
///
/// // Restore
/// Snapshot.restore(pillar, snap);
/// print(pillar.count.value); // 10
/// ```
library;

import '../core/reactive.dart';
import '../core/state.dart';

/// An immutable snapshot of a Pillar's named Core values.
///
/// Created via [Snapshot.capture] and applied via [Snapshot.restore].
class PillarSnapshot {
  /// The captured values, keyed by Core name.
  final Map<String, dynamic> values;

  /// The timestamp when this snapshot was taken.
  final DateTime timestamp;

  /// Optional label for debugging.
  final String? label;

  /// Creates a snapshot with the given values.
  const PillarSnapshot._({
    required this.values,
    required this.timestamp,
    this.label,
  });

  /// Creates a snapshot directly from a map (for testing).
  ///
  /// ```dart
  /// final snap = PillarSnapshot.fromMap({'count': 10});
  /// ```
  PillarSnapshot.fromMap(Map<String, dynamic> values, {this.label})
    : values = Map.unmodifiable(values),
      timestamp = DateTime.now();

  /// Whether this snapshot contains a value for the given Core name.
  bool has(String name) => values.containsKey(name);

  /// Get a typed value from the snapshot.
  ///
  /// Returns `null` if the name is not present.
  T? get<T>(String name) => values[name] as T?;

  /// The number of captured cores.
  int get length => values.length;

  @override
  String toString() =>
      'PillarSnapshot(${label != null ? '"$label", ' : ''}${values.length} cores, $timestamp)';
}

/// Snapshot utilities for capturing and restoring Pillar state.
///
/// Works with any object that exposes managed [ReactiveNode]s — typically
/// called via [Pillar] extension methods.
///
/// ```dart
/// final snap = Snapshot.capture(pillar);
/// // ... make changes ...
/// Snapshot.restore(pillar, snap);
/// ```
class Snapshot {
  Snapshot._();

  /// Capture all named [TitanState] Cores from the managed nodes.
  ///
  /// Only Cores with a non-null [name] are included. Computed values
  /// and effects are excluded since they derive from state.
  ///
  /// [nodes] — the list of reactive nodes (usually from Pillar._managedNodes).
  /// [label] — optional debug label.
  static PillarSnapshot captureFromNodes(
    List<ReactiveNode> nodes, {
    String? label,
  }) {
    final values = <String, dynamic>{};

    for (final node in nodes) {
      if (node is TitanState && node.name != null) {
        values[node.name!] = node.peek();
      }
    }

    return PillarSnapshot._(
      values: Map.unmodifiable(values),
      timestamp: DateTime.now(),
      label: label,
    );
  }

  /// Restore named [TitanState] Cores from a snapshot.
  ///
  /// Uses [silent] to write values without triggering notifications,
  /// unless [notify] is `true`.
  ///
  /// [nodes] — the list of reactive nodes to restore into.
  /// [snapshot] — the snapshot to restore from.
  /// [notify] — if `true`, uses reactive setter instead of [silent].
  static void restoreToNodes(
    List<ReactiveNode> nodes,
    PillarSnapshot snapshot, {
    bool notify = false,
  }) {
    for (final node in nodes) {
      if (node is TitanState && node.name != null) {
        final name = node.name!;
        if (snapshot.values.containsKey(name)) {
          if (notify) {
            node.value = snapshot.values[name];
          } else {
            node.silent(snapshot.values[name]);
          }
        }
      }
    }
  }

  /// Compare two snapshots and return a map of changed values.
  ///
  /// Returns a map of Core name → `(before, after)` for values that differ.
  static Map<String, (dynamic, dynamic)> diff(
    PillarSnapshot a,
    PillarSnapshot b,
  ) {
    final changes = <String, (dynamic, dynamic)>{};
    final allKeys = {...a.values.keys, ...b.values.keys};

    for (final key in allKeys) {
      final va = a.values[key];
      final vb = b.values[key];
      if (va != vb) {
        changes[key] = (va, vb);
      }
    }

    return changes;
  }
}
