import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

// ---------------------------------------------------------------------------
// Test Pillars
// ---------------------------------------------------------------------------

class _CounterPillar extends Pillar {
  late final count = core(0);
  late final label = core('Counter');
  late final doubled = derived(() => count.value * 2);

  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
}

class _LifecyclePillar extends Pillar {
  bool wasInitialized = false;
  bool wasDisposed = false;

  @override
  void onInit() => wasInitialized = true;

  @override
  void onDispose() => wasDisposed = true;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  tearDown(() => Titan.reset());

  group('Vestige<P>', () {
    testWidgets('finds Pillar from Beacon and renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [_CounterPillar.new],
            child: Vestige<_CounterPillar>(
              builder: (context, counter) =>
                  Text('Count: ${counter.count.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('rebuilds when Core changes', (tester) async {
      late _CounterPillar pillar;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: Vestige<_CounterPillar>(
              builder: (context, counter) =>
                  Text('Count: ${counter.count.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      pillar.increment();
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('auto-tracks only accessed Cores', (tester) async {
      late _CounterPillar pillar;
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: Vestige<_CounterPillar>(
              builder: (context, counter) {
                buildCount++;
                return Text('Count: ${counter.count.value}');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Change label (not accessed in builder) — should NOT rebuild
      pillar.label.value = 'New Label';
      await tester.pump();
      expect(buildCount, 1);

      // Change count (accessed in builder) — SHOULD rebuild
      pillar.increment();
      await tester.pump();
      expect(buildCount, 2);
    });

    testWidgets('works with Derived values', (tester) async {
      late _CounterPillar pillar;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: Vestige<_CounterPillar>(
              builder: (context, counter) =>
                  Text('Doubled: ${counter.doubled.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Doubled: 0'), findsOneWidget);

      pillar.increment();
      await tester.pump();

      expect(find.text('Doubled: 2'), findsOneWidget);
    });

    testWidgets('finds Pillar from Titan global registry', (tester) async {
      final pillar = _CounterPillar();
      Titan.put(pillar);

      await tester.pumpWidget(
        MaterialApp(
          home: Vestige<_CounterPillar>(
            builder: (context, counter) =>
                Text('Count: ${counter.count.value}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      pillar.increment();
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('multiple Vestiges track independently', (tester) async {
      late _CounterPillar pillar;
      int countBuilds = 0;
      int labelBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: Column(
              children: [
                Vestige<_CounterPillar>(
                  builder: (context, c) {
                    countBuilds++;
                    return Text('Count: ${c.count.value}');
                  },
                ),
                Vestige<_CounterPillar>(
                  builder: (context, c) {
                    labelBuilds++;
                    return Text('Label: ${c.label.value}');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(countBuilds, 1);
      expect(labelBuilds, 1);

      // Change count — only count Vestige rebuilds
      pillar.increment();
      await tester.pump();
      expect(countBuilds, 2);
      expect(labelBuilds, 1);

      // Change label — only label Vestige rebuilds
      pillar.label.value = 'New';
      await tester.pump();
      expect(countBuilds, 2);
      expect(labelBuilds, 2);
    });
  });

  group('Beacon', () {
    testWidgets('creates and initializes Pillars', (tester) async {
      late _LifecyclePillar pillar;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _LifecyclePillar();
                return pillar;
              },
            ],
            child: const Text('Hello'),
          ),
        ),
      );

      expect(pillar.wasInitialized, true);
    });

    testWidgets('disposes Pillars when removed from tree', (tester) async {
      late _LifecyclePillar pillar;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _LifecyclePillar();
                return pillar;
              },
            ],
            child: const Text('Hello'),
          ),
        ),
      );

      expect(pillar.wasDisposed, false);

      // Remove Beacon from tree
      await tester.pumpWidget(const MaterialApp(home: Text('Goodbye')));

      expect(pillar.wasDisposed, true);
    });

    testWidgets('provides multiple Pillars', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [_CounterPillar.new, _LifecyclePillar.new],
            child: Column(
              children: [
                Vestige<_CounterPillar>(
                  builder: (context, c) => Text('Count: ${c.count.value}'),
                ),
                Builder(
                  builder: (context) {
                    final lc = context.pillar<_LifecyclePillar>();
                    return Text('Init: ${lc.wasInitialized}');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(find.text('Init: true'), findsOneWidget);
    });
  });

  group('context.pillar<P>()', () {
    testWidgets('retrieves Pillar from Beacon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [_CounterPillar.new],
            child: Builder(
              builder: (context) {
                final c = context.pillar<_CounterPillar>();
                return Text('Count: ${c.count.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('falls back to Titan global', (tester) async {
      Titan.put(_CounterPillar());

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final c = context.pillar<_CounterPillar>();
              return Text('Count: ${c.count.value}');
            },
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });
  });

  group('VestigeRaw', () {
    testWidgets('auto-tracks standalone cores', (tester) async {
      final count = Core(0);

      await tester.pumpWidget(
        MaterialApp(
          home: VestigeRaw(builder: (context) => Text('Count: ${count.value}')),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      count.value = 42;
      await tester.pump();

      expect(find.text('Count: 42'), findsOneWidget);

      count.dispose();
    });
  });

  group('VestigeSelector', () {
    testWidgets('selects sub-value from Pillar via Beacon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [_CounterPillar.new],
            child: VestigeSelector<_CounterPillar, int>(
              selector: (counter) => counter.count.value,
              builder: (context, count) => Text('Count: $count'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('rebuilds when selected value changes', (tester) async {
      late _CounterPillar pillar;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: VestigeSelector<_CounterPillar, int>(
              selector: (counter) => counter.count.value,
              builder: (context, count) => Text('Count: $count'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      pillar.increment();
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('does NOT rebuild when unselected state changes', (
      tester,
    ) async {
      late _CounterPillar pillar;
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: VestigeSelector<_CounterPillar, int>(
              selector: (counter) => counter.count.value,
              builder: (context, count) {
                buildCount++;
                return Text('Count: $count');
              },
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Change label (not selected) — should NOT rebuild
      pillar.label.value = 'New Label';
      await tester.pump();
      expect(buildCount, 1);

      // Change count (selected) — SHOULD rebuild
      pillar.increment();
      await tester.pump();
      expect(buildCount, 2);
    });

    testWidgets('works with Derived selector', (tester) async {
      late _CounterPillar pillar;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: VestigeSelector<_CounterPillar, int>(
              selector: (counter) => counter.doubled.value,
              builder: (context, doubled) => Text('Doubled: $doubled'),
            ),
          ),
        ),
      );

      expect(find.text('Doubled: 0'), findsOneWidget);

      pillar.increment();
      await tester.pump();

      expect(find.text('Doubled: 2'), findsOneWidget);
    });

    testWidgets('custom equality prevents unnecessary rebuilds', (
      tester,
    ) async {
      late _CounterPillar pillar;
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: VestigeSelector<_CounterPillar, String>(
              selector: (counter) => counter.count.value > 5 ? 'high' : 'low',
              equals: (a, b) => a == b,
              builder: (context, level) {
                buildCount++;
                return Text('Level: $level');
              },
            ),
          ),
        ),
      );

      expect(find.text('Level: low'), findsOneWidget);
      expect(buildCount, 1);

      // 0 → 1: still 'low' — no rebuild
      pillar.increment();
      await tester.pump();
      expect(buildCount, 1);

      // Set count to 6 → 'high' — rebuild
      pillar.count.value = 6;
      await tester.pump();
      expect(find.text('Level: high'), findsOneWidget);
      expect(buildCount, 2);

      // 6 → 7: still 'high' — no rebuild
      pillar.increment();
      await tester.pump();
      expect(buildCount, 2);
    });

    testWidgets('finds Pillar from Titan global registry', (tester) async {
      final pillar = _CounterPillar();
      Titan.put(pillar);

      await tester.pumpWidget(
        MaterialApp(
          home: VestigeSelector<_CounterPillar, int>(
            selector: (counter) => counter.count.value,
            builder: (context, count) => Text('Count: $count'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      pillar.increment();
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });
  });
}
