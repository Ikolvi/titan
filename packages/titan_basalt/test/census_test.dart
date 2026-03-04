import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

// ── Test helpers ─────────────────────────────────────────────────────────────

class _DashboardPillar extends Pillar {
  late final orderValue = core(0.0);

  late final orderStats = census<double>(
    source: orderValue,
    window: const Duration(seconds: 5),
    name: 'orders',
  );

  @override
  void initialize() {
    // Touch orderStats to trigger lazy init.
    orderStats;
  }
}

void main() {
  group('Census', () {
    // ── Construction ───────────────────────────────────────────────────

    test('creates with default values', () {
      final c = Census<int>(window: const Duration(seconds: 10));
      expect(c.count.value, 0);
      expect(c.sum.value, 0);
      expect(c.average.value, 0);
      expect(c.min.value, double.infinity);
      expect(c.max.value, double.negativeInfinity);
      expect(c.last.value, 0);
      expect(c.entries, isEmpty);
    });

    test('accepts custom name', () {
      final c = Census<double>(
        window: const Duration(seconds: 5),
        name: 'latency',
      );
      expect(c.name, 'latency');
    });

    test('accepts custom maxEntries', () {
      final c = Census<int>(
        window: const Duration(seconds: 10),
        maxEntries: 100,
      );
      expect(c.maxEntries, 100);
    });

    test('asserts on maxEntries <= 0', () {
      expect(
        () => Census<int>(window: const Duration(seconds: 1), maxEntries: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    // ── Recording ──────────────────────────────────────────────────────

    test('record adds entries and updates aggregates', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      c.record(10);
      c.record(20);
      c.record(30);

      expect(c.count.value, 3);
      expect(c.sum.value, 60);
      expect(c.average.value, 20);
      expect(c.min.value, 10);
      expect(c.max.value, 30);
      expect(c.last.value, 30);
    });

    test('record with single entry', () {
      final c = Census<double>(window: const Duration(seconds: 60));
      c.record(42.5);

      expect(c.count.value, 1);
      expect(c.sum.value, 42.5);
      expect(c.average.value, 42.5);
      expect(c.min.value, 42.5);
      expect(c.max.value, 42.5);
      expect(c.last.value, 42.5);
    });

    test('record with negative values', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      c.record(-5);
      c.record(10);
      c.record(-15);

      expect(c.count.value, 3);
      expect(c.sum.value, -10);
      expect(c.min.value, -15);
      expect(c.max.value, 10);
    });

    test('record with zero values', () {
      final c = Census<double>(window: const Duration(seconds: 60));
      c.record(0);
      c.record(0);
      c.record(0);

      expect(c.count.value, 3);
      expect(c.sum.value, 0);
      expect(c.average.value, 0);
      expect(c.min.value, 0);
      expect(c.max.value, 0);
    });

    // ── Window eviction ────────────────────────────────────────────────

    test('evicts entries outside the window', () async {
      final c = Census<int>(window: const Duration(milliseconds: 50));

      c.record(100);
      c.record(200);
      expect(c.count.value, 2);

      // Wait for entries to expire.
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Record new value — triggers eviction of old ones.
      c.record(50);
      expect(c.count.value, 1);
      expect(c.sum.value, 50);
      expect(c.min.value, 50);
      expect(c.max.value, 50);
    });

    test('evict() removes stale entries without recording', () async {
      final c = Census<int>(window: const Duration(milliseconds: 50));

      c.record(10);
      c.record(20);
      expect(c.count.value, 2);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      c.evict();
      expect(c.count.value, 0);
      expect(c.sum.value, 0);
      expect(c.min.value, double.infinity);
      expect(c.max.value, double.negativeInfinity);
    });

    test('evict() is no-op when nothing is stale', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      c.record(10);
      c.record(20);

      c.evict();
      expect(c.count.value, 2); // Nothing changed.
    });

    // ── Max entries cap ────────────────────────────────────────────────

    test('respects maxEntries cap', () {
      final c = Census<int>(window: const Duration(seconds: 60), maxEntries: 3);

      c.record(1);
      c.record(2);
      c.record(3);
      c.record(4); // Evicts 1.

      expect(c.count.value, 3);
      expect(c.entries.map((e) => e.value), [2, 3, 4]);
      expect(c.sum.value, 9);
      expect(c.min.value, 2);
      expect(c.max.value, 4);
    });

    // ── Percentile ─────────────────────────────────────────────────────

    test('percentile returns 0 for empty census', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      expect(c.percentile(50), 0);
      expect(c.percentile(95), 0);
    });

    test('percentile returns the value for single entry', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      c.record(42);
      expect(c.percentile(0), 42);
      expect(c.percentile(50), 42);
      expect(c.percentile(100), 42);
    });

    test('percentile(50) computes median', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      for (var i = 1; i <= 100; i++) {
        c.record(i);
      }
      expect(c.percentile(50), closeTo(50.5, 0.01));
    });

    test('percentile(0) returns min, percentile(100) returns max', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      c.record(5);
      c.record(10);
      c.record(15);
      c.record(20);
      c.record(25);

      expect(c.percentile(0), 5);
      expect(c.percentile(100), 25);
    });

    test('percentile(95) with larger dataset', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      // Record 1..1000.
      for (var i = 1; i <= 1000; i++) {
        c.record(i);
      }
      final p95 = c.percentile(95);
      // 95th percentile of 1..1000 should be around 950.
      expect(p95, closeTo(950.05, 1.0));
    });

    test('percentile asserts on invalid range', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      c.record(10);

      expect(() => c.percentile(-1), throwsA(isA<ArgumentError>()));
      expect(() => c.percentile(101), throwsA(isA<ArgumentError>()));
    });

    // ── Reset ──────────────────────────────────────────────────────────

    test('reset clears all entries and aggregates', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      c.record(10);
      c.record(20);
      c.record(30);

      c.reset();

      expect(c.count.value, 0);
      expect(c.sum.value, 0);
      expect(c.average.value, 0);
      expect(c.min.value, double.infinity);
      expect(c.max.value, double.negativeInfinity);
      expect(c.last.value, 0);
      expect(c.entries, isEmpty);
    });

    test('can record after reset', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      c.record(10);
      c.reset();
      c.record(50);

      expect(c.count.value, 1);
      expect(c.sum.value, 50);
      expect(c.average.value, 50);
    });

    // ── Reactive source ────────────────────────────────────────────────

    test('auto-records from reactive source', () {
      final source = TitanState<int>(0, name: 'source');
      final c = Census<int>(
        window: const Duration(seconds: 60),
        source: source,
      );

      source.value = 10;
      source.value = 20;
      source.value = 30;

      expect(c.count.value, 3);
      expect(c.sum.value, 60);
      expect(c.average.value, 20);

      c.dispose();
    });

    test('stops recording after dispose', () {
      final source = TitanState<int>(0, name: 'source');
      final c = Census<int>(
        window: const Duration(seconds: 60),
        source: source,
      );

      source.value = 10;
      expect(c.count.value, 1);

      c.dispose();

      source.value = 20;
      expect(c.count.value, 1); // No new entry.
    });

    // ── Entries snapshot ────────────────────────────────────────────────

    test('entries returns unmodifiable snapshot', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      c.record(10);
      c.record(20);

      final snapshot = c.entries;
      expect(snapshot, hasLength(2));
      expect(snapshot[0].value, 10);
      expect(snapshot[1].value, 20);
      expect(snapshot[0].timestamp, isA<DateTime>());

      // Attempting to modify the snapshot should throw.
      expect(
        () => snapshot.add(CensusEntry(30, DateTime.now())),
        throwsUnsupportedError,
      );
    });

    // ── CensusEntry ────────────────────────────────────────────────────

    test('CensusEntry stores value and timestamp', () {
      final now = DateTime.now();
      final entry = CensusEntry<int>(42, now);
      expect(entry.value, 42);
      expect(entry.timestamp, now);
    });

    // ── managedNodes ───────────────────────────────────────────────────

    test('managedNodes returns reactive state nodes', () {
      final c = Census<int>(window: const Duration(seconds: 10));
      final nodes = c.managedNodes.toList();
      expect(nodes, hasLength(5)); // count, sum, min, max, last
    });

    // ── Pillar integration ─────────────────────────────────────────────

    test('works as Pillar extension', () {
      final pillar = _DashboardPillar();
      pillar.initialize();

      pillar.orderValue.value = 99.99;
      pillar.orderValue.value = 49.99;
      pillar.orderValue.value = 149.99;

      expect(pillar.orderStats.count.value, 3);
      expect(pillar.orderStats.sum.value, closeTo(299.97, 0.01));
      expect(pillar.orderStats.average.value, closeTo(99.99, 0.01));
      expect(pillar.orderStats.min.value, closeTo(49.99, 0.01));
      expect(pillar.orderStats.max.value, closeTo(149.99, 0.01));

      pillar.dispose();
    });

    // ── Stress tests ───────────────────────────────────────────────────

    test('handles high volume (10,000 entries)', () {
      final c = Census<int>(window: const Duration(seconds: 60));
      for (var i = 0; i < 10000; i++) {
        c.record(i);
      }

      expect(c.count.value, 10000);
      expect(c.sum.value, 49995000); // Sum of 0..9999.
      expect(c.min.value, 0);
      expect(c.max.value, 9999);
      expect(c.average.value, closeTo(4999.5, 0.01));
    });

    test('handles maxEntries overflow gracefully', () {
      final c = Census<int>(
        window: const Duration(seconds: 60),
        maxEntries: 100,
      );

      for (var i = 0; i < 500; i++) {
        c.record(i);
      }

      // Only the last 100 entries should remain.
      expect(c.count.value, 100);
      // Entries 400..499.
      expect(c.min.value, 400);
      expect(c.max.value, 499);
    });

    // ── Double values ──────────────────────────────────────────────────

    test('works with double values', () {
      final c = Census<double>(window: const Duration(seconds: 60));
      c.record(1.5);
      c.record(2.5);
      c.record(3.5);

      expect(c.count.value, 3);
      expect(c.sum.value, closeTo(7.5, 0.001));
      expect(c.average.value, closeTo(2.5, 0.001));
      expect(c.min.value, closeTo(1.5, 0.001));
      expect(c.max.value, closeTo(3.5, 0.001));
    });
  });
}
