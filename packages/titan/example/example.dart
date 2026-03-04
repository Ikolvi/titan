// ignore_for_file: avoid_print

/// Titan — Reactive state management with Pillars, Cores, and Derived values.
///
/// This example demonstrates the core reactive system:
/// - [Pillar] — The state management unit
/// - [Core] — Mutable reactive state
/// - [Derived] — Computed values that auto-track dependencies
/// - [strike] — Intent-based state mutations
/// - [watch] — Reactive side effects (Watchers)
library;

import 'package:titan/titan.dart';

// ---------------------------------------------------------------------------
// Define a Pillar — Titan's reactive module
// ---------------------------------------------------------------------------

class CounterPillar extends Pillar {
  /// Private mutable state — only this Pillar can mutate
  late final _count = core(0);

  /// Public read-only view — consumers can read & track, but cannot mutate
  ReadCore<int> get count => _count;

  /// Computed value — auto-tracks `count`
  late final doubled = derived(() => _count.value * 2);

  /// Named mutations via Strike
  void increment() => strike(() => _count.value++);
  void decrement() => strike(() => _count.value--);

  /// Explicit setter for direct value changes
  void setCount(int value) => strike(() => _count.value = value);

  @override
  void onInit() {
    // Watcher — runs automatically when dependencies change
    watch(() {
      print('Count changed to: ${_count.value} (doubled: ${doubled.value})');
    });
  }
}

// ---------------------------------------------------------------------------
// Usage — Pure Dart (no Flutter needed)
// ---------------------------------------------------------------------------

void main() {
  // Register globally
  final counter = CounterPillar();
  Titan.put(counter);

  // Read reactive state
  print('Initial: ${counter.count.value}'); // 0
  print('Doubled: ${counter.doubled.value}'); // 0

  // Mutate via Strike
  counter.increment();
  // Watcher fires: "Count changed to: 1 (doubled: 2)"

  print('After increment: ${counter.count.value}'); // 1
  print('Doubled: ${counter.doubled.value}'); // 2

  // Explicit setter — all mutations flow through Pillar methods
  counter.setCount(5);
  // Watcher fires: "Count changed to: 5 (doubled: 10)"

  // Batch multiple changes (single notification)
  titanBatch(() {
    counter.setCount(10);
    counter.setCount(20);
  });
  // Watcher fires once: "Count changed to: 20 (doubled: 40)"

  // Clean up
  counter.dispose();
  Titan.reset();
}
