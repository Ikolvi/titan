// ignore_for_file: avoid_print
import 'dart:async';

import 'package:titan/titan.dart';

// =============================================================================
// Titan Performance Benchmarks
// =============================================================================
//
// Run with: dart run benchmark/benchmark.dart
//
// Measures:
//   1. Reactive graph creation & notification at scale (1K–100K nodes)
//   2. Batch vs unbatched mutation throughput
//   3. Deep computed chains (1–1000 deep)
//   4. Wide fan-out (single state → many dependents)
//   5. Herald event throughput
//   6. Pillar lifecycle (create → init → dispose)
// =============================================================================

void main() async {
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  TITAN PERFORMANCE BENCHMARKS');
  print('═══════════════════════════════════════════════════════');
  print('');

  await _benchReactiveCreation();
  await _benchStateNotification();
  await _benchBatchVsUnbatched();
  await _benchComputedChainDepth();
  await _benchWideFanOut();
  await _benchHeraldThroughput();
  await _benchPillarLifecycle();
  await _benchDiamondDependency();

  print('');
  print('═══════════════════════════════════════════════════════');
  print('  ALL BENCHMARKS COMPLETE');
  print('═══════════════════════════════════════════════════════');
}

// ---------------------------------------------------------------------------
// 1. Reactive node creation at scale
// ---------------------------------------------------------------------------

Future<void> _benchReactiveCreation() async {
  print('┌─ 1. Reactive Node Creation ──────────────────────────');

  for (final count in [1000, 10000, 100000]) {
    final sw = Stopwatch()..start();
    final nodes = <TitanState<int>>[];
    for (var i = 0; i < count; i++) {
      nodes.add(TitanState(i));
    }
    sw.stop();
    final perNode = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
    print('│  ${_pad(count)} states:  ${_ms(sw)}  ($perNode µs/node)');

    // Cleanup
    for (final n in nodes) {
      n.dispose();
    }
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 2. State notification throughput
// ---------------------------------------------------------------------------

Future<void> _benchStateNotification() async {
  print('┌─ 2. State Notification Throughput ────────────────────');

  for (final listenerCount in [1, 10, 100, 1000]) {
    final state = TitanState(0);
    var callCount = 0;

    for (var i = 0; i < listenerCount; i++) {
      state.listen((_) => callCount++);
    }

    const mutations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state.value = i;
    }
    sw.stop();

    final throughput = (mutations / sw.elapsedMicroseconds * 1e6)
        .toStringAsFixed(0);
    print(
      '│  ${_pad(listenerCount)} listeners × $mutations mutations: '
      '${_ms(sw)}  ($throughput mutations/sec)',
    );
    state.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 3. Batch vs unbatched
// ---------------------------------------------------------------------------

Future<void> _benchBatchVsUnbatched() async {
  print('┌─ 3. Batch vs Unbatched Mutations ─────────────────────');

  const stateCount = 100;
  const mutations = 10000;

  // Create states and a computed that depends on all of them
  final states = List.generate(stateCount, (i) => TitanState(i));
  final sum = TitanComputed(() {
    var total = 0;
    for (final s in states) {
      total += s.value;
    }
    return total;
  });

  // Force initial computation
  sum.value;

  // Unbatched
  var recomputeCount = 0;
  final effect = TitanEffect(() {
    sum.value;
    recomputeCount++;
  });
  recomputeCount = 0; // Reset after initial run

  final swUnbatched = Stopwatch()..start();
  for (var i = 0; i < mutations; i++) {
    states[i % stateCount].value = i + 1000;
  }
  swUnbatched.stop();
  final unbatchedRecomputes = recomputeCount;

  effect.dispose();

  // Batched
  recomputeCount = 0;
  final effect2 = TitanEffect(() {
    sum.value;
    recomputeCount++;
  });
  recomputeCount = 0;

  final swBatched = Stopwatch()..start();
  for (var batch = 0; batch < mutations ~/ stateCount; batch++) {
    titanBatch(() {
      for (var i = 0; i < stateCount; i++) {
        states[i].value = batch * stateCount + i + 2000;
      }
    });
  }
  swBatched.stop();
  final batchedRecomputes = recomputeCount;

  final speedup =
      swUnbatched.elapsedMicroseconds / swBatched.elapsedMicroseconds;

  print('│  Unbatched: ${_ms(swUnbatched)}  ($unbatchedRecomputes recomputes)');
  print('│  Batched:   ${_ms(swBatched)}  ($batchedRecomputes recomputes)');
  print('│  Speedup:   ${speedup.toStringAsFixed(1)}x');

  effect2.dispose();
  sum.dispose();
  for (final s in states) {
    s.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 4. Deep computed chains
// ---------------------------------------------------------------------------

Future<void> _benchComputedChainDepth() async {
  print('┌─ 4. Deep Computed Chain Propagation ──────────────────');

  for (final depth in [10, 100, 500, 1000]) {
    final source = TitanState(0);
    final chain = <TitanComputed<int>>[TitanComputed(() => source.value + 1)];

    for (var i = 1; i < depth; i++) {
      final prev = chain[i - 1];
      chain.add(TitanComputed(() => prev.value + 1));
    }

    // Force initial computation
    chain.last.value;

    const mutations = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      source.value = i;
      chain.last.value; // Force full chain recomputation
    }
    sw.stop();

    final perMutation = (sw.elapsedMicroseconds / mutations).toStringAsFixed(1);
    print(
      '│  Depth ${_pad(depth)}: ${_ms(sw)}  '
      '($perMutation µs/propagation)',
    );

    // Verify correctness
    source.value = 42;
    assert(chain.last.value == 42 + depth);

    // Cleanup
    for (final c in chain.reversed) {
      c.dispose();
    }
    source.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 5. Wide fan-out (1 source → N dependents)
// ---------------------------------------------------------------------------

Future<void> _benchWideFanOut() async {
  print('┌─ 5. Wide Fan-Out (1 Source → N Dependents) ───────────');

  for (final width in [10, 100, 1000, 10000]) {
    final source = TitanState(0);
    final dependents = List.generate(
      width,
      (i) => TitanComputed(() => source.value + i),
    );

    // Force initial computation
    for (final d in dependents) {
      d.value;
    }

    const mutations = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      source.value = i;
      // Read all dependents to trigger recomputation
      for (final d in dependents) {
        d.value;
      }
    }
    sw.stop();

    final perMutation = (sw.elapsedMicroseconds / mutations).toStringAsFixed(1);
    print(
      '│  Width ${_pad(width)}: ${_ms(sw)}  '
      '($perMutation µs/propagation)',
    );

    // Cleanup
    for (final d in dependents) {
      d.dispose();
    }
    source.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 6. Herald event throughput
// ---------------------------------------------------------------------------

Future<void> _benchHeraldThroughput() async {
  print('┌─ 6. Herald Event Throughput ──────────────────────────');

  for (final listenerCount in [0, 1, 10, 100]) {
    Herald.reset();

    var received = 0;
    final subs = <StreamSubscription<_BenchEvent>>[];
    for (var i = 0; i < listenerCount; i++) {
      subs.add(Herald.on<_BenchEvent>((_) => received++));
    }

    const events = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < events; i++) {
      Herald.emit(_BenchEvent(i));
    }
    sw.stop();

    final throughput = (events / sw.elapsedMicroseconds * 1e6).toStringAsFixed(
      0,
    );
    print(
      '│  ${_pad(listenerCount)} listeners × $events events: '
      '${_ms(sw)}  ($throughput events/sec)',
    );

    for (final s in subs) {
      s.cancel();
    }
  }

  Herald.reset();
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 7. Pillar lifecycle
// ---------------------------------------------------------------------------

Future<void> _benchPillarLifecycle() async {
  print('┌─ 7. Pillar Lifecycle (Create → Init → Dispose) ──────');

  for (final count in [100, 1000, 10000]) {
    final sw = Stopwatch()..start();
    final pillars = <_BenchPillar>[];
    for (var i = 0; i < count; i++) {
      final p = _BenchPillar();
      p.initialize();
      pillars.add(p);
    }
    for (final p in pillars) {
      p.dispose();
    }
    sw.stop();

    final perPillar = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
    print('│  ${_pad(count)} pillars:  ${_ms(sw)}  ($perPillar µs/pillar)');
  }

  Titan.reset();
  Herald.reset();
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 8. Diamond dependency (A → B, A → C, B+C → D)
// ---------------------------------------------------------------------------

Future<void> _benchDiamondDependency() async {
  print('┌─ 8. Diamond Dependency Pattern ───────────────────────');

  const diamondCount = 1000;
  final sources = <TitanState<int>>[];
  final diamonds = <TitanComputed<int>>[];

  // Build [diamondCount] independent diamond patterns
  for (var i = 0; i < diamondCount; i++) {
    final a = TitanState(i);
    final b = TitanComputed(() => a.value * 2);
    final c = TitanComputed(() => a.value * 3);
    final d = TitanComputed(
      () => b.value + c.value,
    ); // Should compute once per a change
    d.value; // Force initial computation
    sources.add(a);
    diamonds.add(d);
  }

  const mutations = 100;
  final sw = Stopwatch()..start();
  for (var m = 0; m < mutations; m++) {
    for (var i = 0; i < diamondCount; i++) {
      sources[i].value = m * diamondCount + i;
      diamonds[i].value; // Read to trigger
    }
  }
  sw.stop();

  final totalOps = diamondCount * mutations;
  final perOp = (sw.elapsedMicroseconds / totalOps).toStringAsFixed(2);
  print(
    '│  $diamondCount diamonds × $mutations mutations: '
    '${_ms(sw)}  ($perOp µs/diamond)',
  );

  // Verify correctness: a=42 → b=84, c=126, d=210
  sources[0].value = 42;
  assert(diamonds[0].value == 42 * 2 + 42 * 3);

  // Cleanup
  for (final d in diamonds) {
    d.dispose();
  }
  for (final s in sources) {
    s.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// =============================================================================
// Helpers
// =============================================================================

class _BenchEvent {
  final int id;
  _BenchEvent(this.id);
}

class _BenchPillar extends Pillar {
  late final count = core(0);
  late final doubled = derived(() => count.value * 2);
  late final name = core('bench');

  @override
  void onInit() {
    watch(() {
      // Read both to register dependencies
      count.value;
      doubled.value;
    });
  }
}

String _ms(Stopwatch sw) {
  if (sw.elapsedMilliseconds < 1) {
    return '${sw.elapsedMicroseconds} µs'.padLeft(10);
  }
  return '${sw.elapsedMilliseconds} ms'.padLeft(10);
}

String _pad(int n) => n.toString().padLeft(6);
