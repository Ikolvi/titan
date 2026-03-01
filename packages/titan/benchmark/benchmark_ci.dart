// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:titan/titan.dart';

// =============================================================================
// Titan CI Benchmark Runner
// =============================================================================
//
// Run with: dart run benchmark/benchmark_ci.dart
//
// Outputs JSON benchmark results to stdout for CI consumption.
// The CI workflow captures this output and posts it to the job summary.
// =============================================================================

final _results = <Map<String, dynamic>>[];

void main() {
  _benchReactiveCreation();
  _benchStateNotification();
  _benchBatchSpeedup();
  _benchComputedChain();
  _benchWideFanOut();
  _benchHeraldThroughput();
  _benchPillarLifecycle();
  _benchDiamondDependency();
  _benchEpochOverhead();
  _benchVigilCapture();

  // Output JSON
  print(
    jsonEncode({
      'benchmarks': _results,
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );
}

void _record(String name, String unit, double value) {
  _results.add({'name': name, 'value': value, 'unit': unit});
}

// ---------------------------------------------------------------------------
// 1. Reactive Node Creation (100K states)
// ---------------------------------------------------------------------------
void _benchReactiveCreation() {
  const count = 100000;
  final sw = Stopwatch()..start();
  final nodes = <TitanState<int>>[];
  for (var i = 0; i < count; i++) {
    nodes.add(TitanState(i));
  }
  sw.stop();
  final perNode = sw.elapsedMicroseconds / count;
  _record('Node Creation (100K)', 'µs/node', perNode);
  for (final n in nodes) {
    n.dispose();
  }
}

// ---------------------------------------------------------------------------
// 2. State Notification (1 listener × 10K mutations)
// ---------------------------------------------------------------------------
void _benchStateNotification() {
  final state = TitanState(0);
  var callCount = 0;
  state.listen((_) => callCount++);

  const mutations = 10000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < mutations; i++) {
    state.value = i;
  }
  sw.stop();

  final throughput = mutations / sw.elapsedMicroseconds * 1e6;
  _record('Notification Throughput', 'mutations/sec', throughput);
  state.dispose();
}

// ---------------------------------------------------------------------------
// 3. Batch vs Unbatched Speedup
// ---------------------------------------------------------------------------
void _benchBatchSpeedup() {
  const stateCount = 100;
  const mutations = 10000;
  final states = List.generate(stateCount, (i) => TitanState(i));
  final sum = TitanComputed(() {
    var total = 0;
    for (final s in states) {
      total += s.value;
    }
    return total;
  });
  sum.value;

  // Unbatched
  final eff1 = TitanEffect(() {
    sum.value;
  });
  final swU = Stopwatch()..start();
  for (var i = 0; i < mutations; i++) {
    states[i % stateCount].value = i + 1000;
  }
  swU.stop();
  eff1.dispose();

  // Batched
  final eff2 = TitanEffect(() {
    sum.value;
  });
  final swB = Stopwatch()..start();
  for (var batch = 0; batch < mutations ~/ stateCount; batch++) {
    titanBatch(() {
      for (var i = 0; i < stateCount; i++) {
        states[i].value = batch * stateCount + i + 2000;
      }
    });
  }
  swB.stop();

  final speedup = swU.elapsedMicroseconds / swB.elapsedMicroseconds;
  _record('Batch Speedup', 'x', speedup);

  eff2.dispose();
  sum.dispose();
  for (final s in states) {
    s.dispose();
  }
}

// ---------------------------------------------------------------------------
// 4. Deep Computed Chain (depth=1000)
// ---------------------------------------------------------------------------
void _benchComputedChain() {
  const depth = 1000;
  final source = TitanState(0);
  final chain = <TitanComputed<int>>[TitanComputed(() => source.value + 1)];
  for (var i = 1; i < depth; i++) {
    final prev = chain[i - 1];
    chain.add(TitanComputed(() => prev.value + 1));
  }
  chain.last.value;

  const mutations = 1000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < mutations; i++) {
    source.value = i;
    chain.last.value;
  }
  sw.stop();

  final perMutation = sw.elapsedMicroseconds / mutations;
  _record('Deep Chain (1000)', 'µs/propagation', perMutation);

  for (final c in chain.reversed) {
    c.dispose();
  }
  source.dispose();
}

// ---------------------------------------------------------------------------
// 5. Wide Fan-Out (1 source → 10K dependents)
// ---------------------------------------------------------------------------
void _benchWideFanOut() {
  const width = 10000;
  final source = TitanState(0);
  final deps = List.generate(
    width,
    (i) => TitanComputed(() => source.value + i),
  );
  for (final d in deps) {
    d.value;
  }

  const mutations = 1000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < mutations; i++) {
    source.value = i;
    for (final d in deps) {
      d.value;
    }
  }
  sw.stop();

  final perMutation = sw.elapsedMicroseconds / mutations;
  _record('Fan-Out (10K)', 'µs/propagation', perMutation);

  for (final d in deps) {
    d.dispose();
  }
  source.dispose();
}

// ---------------------------------------------------------------------------
// 6. Herald Throughput (10 listeners × 100K events)
// ---------------------------------------------------------------------------
void _benchHeraldThroughput() {
  Herald.reset();
  var received = 0;
  final subs = <dynamic>[];
  for (var i = 0; i < 10; i++) {
    subs.add(Herald.on<_BenchEvent>((_) => received++));
  }

  const events = 100000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < events; i++) {
    Herald.emit(_BenchEvent(i));
  }
  sw.stop();

  final throughput = events / sw.elapsedMicroseconds * 1e6;
  _record('Herald Throughput (10 listeners)', 'events/sec', throughput);

  for (final s in subs) {
    (s as dynamic).cancel();
  }
  Herald.reset();
}

// ---------------------------------------------------------------------------
// 7. Pillar Lifecycle (10K pillars create → init → dispose)
// ---------------------------------------------------------------------------
void _benchPillarLifecycle() {
  const count = 10000;
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

  final perPillar = sw.elapsedMicroseconds / count;
  _record('Pillar Lifecycle (10K)', 'µs/pillar', perPillar);
  Titan.reset();
  Herald.reset();
}

// ---------------------------------------------------------------------------
// 8. Diamond Dependency (1K diamonds × 100 mutations)
// ---------------------------------------------------------------------------
void _benchDiamondDependency() {
  const diamondCount = 1000;
  final sources = <TitanState<int>>[];
  final diamonds = <TitanComputed<int>>[];

  for (var i = 0; i < diamondCount; i++) {
    final a = TitanState(i);
    final b = TitanComputed(() => a.value * 2);
    final c = TitanComputed(() => a.value * 3);
    final d = TitanComputed(() => b.value + c.value);
    d.value;
    sources.add(a);
    diamonds.add(d);
  }

  const mutations = 100;
  final sw = Stopwatch()..start();
  for (var m = 0; m < mutations; m++) {
    for (var i = 0; i < diamondCount; i++) {
      sources[i].value = m * diamondCount + i;
      diamonds[i].value;
    }
  }
  sw.stop();

  final perOp = sw.elapsedMicroseconds / (diamondCount * mutations);
  _record('Diamond Pattern (1K)', 'µs/diamond', perOp);

  for (final d in diamonds) {
    d.dispose();
  }
  for (final s in sources) {
    s.dispose();
  }
}

// ---------------------------------------------------------------------------
// 9. Epoch Overhead vs Plain State
// ---------------------------------------------------------------------------
void _benchEpochOverhead() {
  const mutations = 100000;

  final plain = TitanState(0);
  final swPlain = Stopwatch()..start();
  for (var i = 0; i < mutations; i++) {
    plain.value = i;
  }
  swPlain.stop();

  final epoch = Epoch(0, maxHistory: 50);
  final swEpoch = Stopwatch()..start();
  for (var i = 0; i < mutations; i++) {
    epoch.value = i;
  }
  swEpoch.stop();

  final overhead = swEpoch.elapsedMicroseconds / swPlain.elapsedMicroseconds;
  _record('Epoch Overhead', 'x vs plain state', overhead);

  plain.dispose();
  epoch.dispose();
}

// ---------------------------------------------------------------------------
// 10. Vigil Error Capture
// ---------------------------------------------------------------------------
void _benchVigilCapture() {
  Vigil.reset();
  Vigil.maxHistorySize = 100;

  const captures = 100000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < captures; i++) {
    Vigil.capture(
      StateError('bench'),
      context: ErrorContext(source: StateError, action: 'bench'),
    );
  }
  sw.stop();

  final throughput = captures / sw.elapsedMicroseconds * 1e6;
  _record('Vigil Capture', 'captures/sec', throughput);
  Vigil.reset();
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

  @override
  void onInit() {
    watch(() {
      count.value;
      doubled.value;
    });
  }
}
