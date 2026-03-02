// ignore_for_file: avoid_print, invalid_use_of_protected_member
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

// =============================================================================
// Spark Hook Performance Benchmarks
// =============================================================================
//
// Run with: cd packages/titan_bastion && flutter test benchmark/spark_benchmark.dart
//
// Measures:
//   1. Spark widget creation & disposal lifecycle
//   2. useCore state-change rebuild throughput
//   3. useDerived rebuild overhead (scaling with derived count)
//   4. Hook allocation scaling (1–50 hooks per widget)
//   5. useReducer dispatch throughput
//   6. useMemo recomputation avoidance
//   7. Spark vs StatefulWidget rebuild comparison
//   8. useCallback stability (reference identity)
// =============================================================================

void main() {
  testWidgets('Spark Hook Performance Benchmarks', (tester) async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('  SPARK HOOK PERFORMANCE BENCHMARKS');
    print('═══════════════════════════════════════════════════════');
    print('');

    await _benchSparkLifecycle(tester);
    await _benchUseCoreRebuild(tester);
    await _benchUseDerivedRebuild(tester);
    await _benchHookScaling(tester);
    await _benchUseReducerDispatch(tester);
    await _benchUseMemoAvoidance(tester);
    await _benchSparkVsStateful(tester);
    await _benchUseCallbackStability(tester);

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  ALL SPARK BENCHMARKS COMPLETE');
    print('═══════════════════════════════════════════════════════');
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _ms(Stopwatch sw) =>
    '${(sw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms';

String _pad(Object v) => '$v'.padLeft(6);

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

// ---------------------------------------------------------------------------
// 1. Spark widget creation & disposal lifecycle
// ---------------------------------------------------------------------------

Future<void> _benchSparkLifecycle(WidgetTester tester) async {
  print('┌─ 1. Spark Widget Lifecycle ──────────────────────────');

  const cycles = 500;
  final sw = Stopwatch()..start();

  for (var i = 0; i < cycles; i++) {
    await tester.pumpWidget(_app(_SimpleSpark(key: ValueKey(i))));
    await tester.pumpWidget(_app(const SizedBox.shrink()));
  }
  sw.stop();

  final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
  print('│  $cycles create+dispose cycles: ${_ms(sw)}  ($perCycle µs/cycle)');
  print('└───────────────────────────────────────────────────────');
  print('');
}

class _SimpleSpark extends Spark {
  const _SimpleSpark({super.key});

  @override
  Widget ignite(BuildContext context) {
    final count = useCore(0);
    useDerived(() => count.value * 2);
    useEffect(() => null, const []);
    useMemo(() => 'Hero #${count.value}', [count.value]);
    return Text('${count.value}');
  }
}

// ---------------------------------------------------------------------------
// 2. useCore state-change rebuild throughput
// ---------------------------------------------------------------------------

Future<void> _benchUseCoreRebuild(WidgetTester tester) async {
  print('┌─ 2. useCore Rebuild Throughput ──────────────────────');

  for (final mutations in [100, 500]) {
    await tester.pumpWidget(_app(const _CoreRebuildSpark()));
    await tester.pump();

    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      final sparkState = tester.firstState<SparkState>(
        find.byType(_CoreRebuildSpark),
      );
      sparkState.setState(() {});
      await tester.pump();
    }
    sw.stop();

    final perRebuild = (sw.elapsedMicroseconds / mutations).toStringAsFixed(2);
    print(
      '│  ${_pad(mutations)} state-change rebuilds: '
      '${_ms(sw)}  ($perRebuild µs/rebuild)',
    );

    await tester.pumpWidget(_app(const SizedBox.shrink()));
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

class _CoreRebuildSpark extends Spark {
  const _CoreRebuildSpark();

  @override
  Widget ignite(BuildContext context) {
    final count = useCore(0);
    final doubled = useDerived(() => count.value * 2);
    return Text('${count.value} = ${doubled.value}');
  }
}

// ---------------------------------------------------------------------------
// 3. useDerived rebuild overhead (scaling)
// ---------------------------------------------------------------------------

Future<void> _benchUseDerivedRebuild(WidgetTester tester) async {
  print('┌─ 3. useDerived Rebuild Overhead ─────────────────────');

  for (final derivedCount in [1, 5, 10]) {
    await tester.pumpWidget(
      _app(
        _DerivedScaleSpark(
          key: ValueKey('derived-$derivedCount'),
          derivedCount: derivedCount,
        ),
      ),
    );
    await tester.pump();

    const rebuilds = 200;
    final sw = Stopwatch()..start();
    for (var i = 0; i < rebuilds; i++) {
      final sparkState = tester.firstState<SparkState>(
        find.byType(_DerivedScaleSpark),
      );
      sparkState.setState(() {});
      await tester.pump();
    }
    sw.stop();

    final perRebuild = (sw.elapsedMicroseconds / rebuilds).toStringAsFixed(2);
    print(
      '│  ${_pad(derivedCount)} derived values × $rebuilds rebuilds: '
      '${_ms(sw)}  ($perRebuild µs/rebuild)',
    );

    await tester.pumpWidget(_app(const SizedBox.shrink()));
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

class _DerivedScaleSpark extends Spark {
  final int derivedCount;
  const _DerivedScaleSpark({super.key, required this.derivedCount});

  @override
  Widget ignite(BuildContext context) {
    final root = useCore(0);
    var sum = 0;
    for (var i = 0; i < derivedCount; i++) {
      final d = useDerived(() => root.value + i);
      sum += d.value;
    }
    return Text('Sum: $sum');
  }
}

// ---------------------------------------------------------------------------
// 4. Hook allocation scaling
// ---------------------------------------------------------------------------

Future<void> _benchHookScaling(WidgetTester tester) async {
  print('┌─ 4. Hook Allocation Scaling ─────────────────────────');

  for (final hookCount in [1, 10, 25, 50]) {
    // ValueKey forces new SparkState for each hookCount
    await tester.pumpWidget(
      _app(
        _HookScaleBench(
          key: ValueKey('hooks-$hookCount'),
          hookCount: hookCount,
        ),
      ),
    );
    await tester.pump();

    const rebuilds = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < rebuilds; i++) {
      final sparkState = tester.firstState<SparkState>(
        find.byType(_HookScaleBench),
      );
      sparkState.setState(() {});
      await tester.pump();
    }
    sw.stop();

    final perRebuild = (sw.elapsedMicroseconds / rebuilds).toStringAsFixed(2);
    print(
      '│  ${_pad(hookCount)} hooks × $rebuilds rebuilds: '
      '${_ms(sw)}  ($perRebuild µs/rebuild)',
    );

    await tester.pumpWidget(_app(const SizedBox.shrink()));
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

class _HookScaleBench extends Spark {
  final int hookCount;
  const _HookScaleBench({super.key, required this.hookCount});

  @override
  Widget ignite(BuildContext context) {
    for (var i = 0; i < hookCount; i++) {
      useCore(i);
    }
    return const Text('hooks');
  }
}

// ---------------------------------------------------------------------------
// 5. useReducer dispatch throughput
// ---------------------------------------------------------------------------

Future<void> _benchUseReducerDispatch(WidgetTester tester) async {
  print('┌─ 5. useReducer Dispatch Throughput ───────────────────');

  await tester.pumpWidget(_app(const _ReducerBench()));
  await tester.pump();

  for (final dispatches in [100, 500]) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < dispatches; i++) {
      final sparkState = tester.firstState<SparkState>(
        find.byType(_ReducerBench),
      );
      sparkState.setState(() {});
      await tester.pump();
    }
    sw.stop();

    final perDispatch = (sw.elapsedMicroseconds / dispatches).toStringAsFixed(
      2,
    );
    print(
      '│  ${_pad(dispatches)} rebuilds with reducer: '
      '${_ms(sw)}  ($perDispatch µs/dispatch)',
    );
  }

  await tester.pumpWidget(_app(const SizedBox.shrink()));
  print('└───────────────────────────────────────────────────────');
  print('');
}

class _ReducerBench extends Spark {
  const _ReducerBench();

  @override
  Widget ignite(BuildContext context) {
    final store = useReducer<int, String>(
      (state, action) => switch (action) {
        'inc' => state + 1,
        'dec' => state - 1,
        'reset' => 0,
        _ => state,
      },
      initialState: 0,
    );
    return Text('${store.state}');
  }
}

// ---------------------------------------------------------------------------
// 6. useMemo recomputation avoidance
// ---------------------------------------------------------------------------

Future<void> _benchUseMemoAvoidance(WidgetTester tester) async {
  print('┌─ 6. useMemo Recomputation Avoidance ─────────────────');

  await tester.pumpWidget(_app(const _MemoBench()));
  await tester.pump();

  const rebuilds = 500;
  final sw = Stopwatch()..start();
  for (var i = 0; i < rebuilds; i++) {
    final sparkState = tester.firstState<SparkState>(find.byType(_MemoBench));
    sparkState.setState(() {});
    await tester.pump();
  }
  sw.stop();

  final perRebuild = (sw.elapsedMicroseconds / rebuilds).toStringAsFixed(2);
  print(
    '│  $rebuilds rebuilds (memo hit): '
    '${_ms(sw)}  ($perRebuild µs/rebuild)',
  );

  await tester.pumpWidget(_app(const SizedBox.shrink()));
  print('└───────────────────────────────────────────────────────');
  print('');
}

class _MemoBench extends Spark {
  const _MemoBench();

  @override
  Widget ignite(BuildContext context) {
    final count = useCore(42);
    // Keys match every time → memo is never recomputed
    final expensive = useMemo(() {
      var total = 0;
      for (var i = 0; i < 100; i++) {
        total += count.value;
      }
      return total;
    }, [count.value]);
    return Text('$expensive');
  }
}

// ---------------------------------------------------------------------------
// 7. Spark vs StatefulWidget rebuild comparison
// ---------------------------------------------------------------------------

Future<void> _benchSparkVsStateful(WidgetTester tester) async {
  print('┌─ 7. Spark vs StatefulWidget Rebuild ─────────────────');

  const rebuilds = 500;

  // Spark rebuild
  await tester.pumpWidget(_app(const _SparkCounter()));
  await tester.pump();
  final swSpark = Stopwatch()..start();
  for (var i = 0; i < rebuilds; i++) {
    final sparkState = tester.firstState<SparkState>(
      find.byType(_SparkCounter),
    );
    sparkState.setState(() {});
    await tester.pump();
  }
  swSpark.stop();

  await tester.pumpWidget(_app(const SizedBox.shrink()));

  // StatefulWidget rebuild
  await tester.pumpWidget(_app(const _StatefulCounter()));
  await tester.pump();
  final swStateful = Stopwatch()..start();
  for (var i = 0; i < rebuilds; i++) {
    final statefulState = tester.state<_StatefulCounterState>(
      find.byType(_StatefulCounter),
    );
    statefulState.rebuild();
    await tester.pump();
  }
  swStateful.stop();

  final sparkPer = (swSpark.elapsedMicroseconds / rebuilds).toStringAsFixed(2);
  final statePer = (swStateful.elapsedMicroseconds / rebuilds).toStringAsFixed(
    2,
  );
  final ratio = swStateful.elapsedMicroseconds > 0
      ? (swSpark.elapsedMicroseconds / swStateful.elapsedMicroseconds)
            .toStringAsFixed(2)
      : 'N/A';

  print(
    '│  Spark:          $rebuilds rebuilds in ${_ms(swSpark)}  '
    '($sparkPer µs/rebuild)',
  );
  print(
    '│  StatefulWidget:  $rebuilds rebuilds in ${_ms(swStateful)}  '
    '($statePer µs/rebuild)',
  );
  print('│  Ratio (Spark/Stateful): $ratio×');

  await tester.pumpWidget(_app(const SizedBox.shrink()));
  print('└───────────────────────────────────────────────────────');
  print('');
}

class _SparkCounter extends Spark {
  const _SparkCounter();

  @override
  Widget ignite(BuildContext context) {
    final count = useCore(0);
    final doubled = useDerived(() => count.value * 2);
    final label = useMemo(() => 'Count: ${count.value}', [count.value]);
    useEffect(() => null, const []);
    return Text('$label = ${doubled.value}');
  }
}

class _StatefulCounter extends StatefulWidget {
  const _StatefulCounter();

  @override
  State<_StatefulCounter> createState() => _StatefulCounterState();
}

class _StatefulCounterState extends State<_StatefulCounter> {
  int _count = 0;

  void rebuild() => setState(() => _count++);

  @override
  Widget build(BuildContext context) {
    final doubled = _count * 2;
    final label = 'Count: $_count';
    return Text('$label = $doubled');
  }
}

// ---------------------------------------------------------------------------
// 8. useCallback stability
// ---------------------------------------------------------------------------

Future<void> _benchUseCallbackStability(WidgetTester tester) async {
  print('┌─ 8. useCallback Stability ───────────────────────────');

  await tester.pumpWidget(_app(const _CallbackBench()));
  await tester.pump();

  const rebuilds = 500;
  final sw = Stopwatch()..start();
  for (var i = 0; i < rebuilds; i++) {
    final sparkState = tester.firstState<SparkState>(
      find.byType(_CallbackBench),
    );
    sparkState.setState(() {});
    await tester.pump();
  }
  sw.stop();

  final perRebuild = (sw.elapsedMicroseconds / rebuilds).toStringAsFixed(2);
  print(
    '│  $rebuilds rebuilds (10 stable callbacks): '
    '${_ms(sw)}  ($perRebuild µs/rebuild)',
  );

  await tester.pumpWidget(_app(const SizedBox.shrink()));
  print('└───────────────────────────────────────────────────────');
  print('');
}

class _CallbackBench extends Spark {
  const _CallbackBench();

  @override
  Widget ignite(BuildContext context) {
    final count = useCore(0);

    // 10 stable callbacks with const keys
    for (var i = 0; i < 10; i++) {
      useCallback(() => count.value++, const []);
    }

    return Text('${count.value}');
  }
}
