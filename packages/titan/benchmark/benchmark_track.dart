// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:titan/titan.dart';

// =============================================================================
// Titan Benchmark Tracker
// =============================================================================
//
// Run with: dart run benchmark/benchmark_track.dart
//
// Unified benchmark runner that:
//   1. Runs all benchmarks (core + extended + enterprise)
//   2. Saves results to benchmark/results/
//   3. Compares against previous run and flags regressions
//
// Options:
//   --save         Save results (default: true)
//   --no-save      Run without saving
//   --baseline     Save as the named baseline for future comparison
//   --compare      Compare against a specific saved file
//   --history      Show all saved benchmark runs
//   --threshold    Regression threshold percentage (default: 10)
//   --samples      Number of samples per benchmark for median (default: 3)
//
// =============================================================================

final _results = <String, _BenchResult>{};
var _isWarmup = false;
var _samples = 3;

void main(List<String> args) async {
  final save = !args.contains('--no-save');
  final showHistory = args.contains('--history');
  final baselineName = _getArg(args, '--baseline');
  final compareFile = _getArg(args, '--compare');
  final threshold = double.tryParse(_getArg(args, '--threshold') ?? '') ?? 10.0;
  _samples = int.tryParse(_getArg(args, '--samples') ?? '') ?? 3;

  final resultsDir = Directory('benchmark/results');
  final historyDir = Directory('benchmark/results/history');

  if (showHistory) {
    _showHistory(historyDir);
    return;
  }

  print('');
  print('═══════════════════════════════════════════════════════');
  print('  TITAN BENCHMARK TRACKER');
  print('═══════════════════════════════════════════════════════');
  print('');

  // JIT Warmup: run all benchmarks once without recording to
  // ensure Dart's JIT compiler has optimized all hot paths.
  // This dramatically reduces variance between runs.
  print('── Warmup ─────────────────────────────────────────────');
  final warmupSw = Stopwatch()..start();
  _isWarmup = true;
  await _runCoreBenchmarks();
  await _runExtendedBenchmarks();
  await _runEnterpriseBenchmarks();
  _isWarmup = false;
  _results.clear();
  warmupSw.stop();
  print('   ✓ Warmup complete (${warmupSw.elapsedMilliseconds}ms)');
  print('');

  // Multi-sample: run all benchmarks N times, collect values, take medians.
  // This reduces noise from OS scheduling, GC, and other transient effects.
  final allSamples = <String, List<_BenchResult>>{};

  print('── Benchmarks ─────────────────────────────────────────');
  for (var sample = 0; sample < _samples; sample++) {
    _results.clear();
    await _runCoreBenchmarks();
    await _runExtendedBenchmarks();
    await _runEnterpriseBenchmarks();
    for (final entry in _results.entries) {
      allSamples.putIfAbsent(entry.key, () => []).add(entry.value);
    }
    print('   ✓ Sample ${sample + 1}/$_samples collected');
  }

  // Take medians
  _results.clear();
  for (final entry in allSamples.entries) {
    final values = entry.value.map((r) => r.value).toList()..sort();
    final mid = values.length ~/ 2;
    final median = values.length.isOdd
        ? values[mid]
        : (values[mid - 1] + values[mid]) / 2;
    _results[entry.key] = _BenchResult(
      value: median,
      unit: entry.value.first.unit,
      suite: entry.value.first.suite,
    );
  }

  if (_samples > 1) {
    print('   ✓ Medians computed from $_samples samples');
    print('');
  }

  // Load version from pubspec
  final version = _readVersion();

  // Build result payload
  final payload = {
    'version': version,
    'timestamp': DateTime.now().toIso8601String(),
    'platform': Platform.operatingSystem,
    'dartVersion': Platform.version.split(' ').first,
    'benchmarks': _results.map(
      (k, v) =>
          MapEntry(k, {'value': v.value, 'unit': v.unit, 'suite': v.suite}),
    ),
  };

  // Load previous results for comparison
  Map<String, dynamic>? previous;
  if (compareFile != null) {
    final file = File(compareFile);
    if (file.existsSync()) {
      previous = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } else {
      print('⚠ Compare file not found: $compareFile');
    }
  } else {
    final latestFile = File('benchmark/results/latest.json');
    if (latestFile.existsSync()) {
      previous =
          jsonDecode(latestFile.readAsStringSync()) as Map<String, dynamic>;
    }
  }

  // Print comparison report
  _printReport(previous, threshold);

  // Save results
  if (save) {
    if (!resultsDir.existsSync()) resultsDir.createSync(recursive: true);
    if (!historyDir.existsSync()) historyDir.createSync(recursive: true);

    final jsonOutput = const JsonEncoder.withIndent('  ').convert(payload);

    // Save as latest
    File('benchmark/results/latest.json').writeAsStringSync(jsonOutput);

    // Save to history
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final historyName = baselineName ?? '${version}_$ts';
    File(
      'benchmark/results/history/$historyName.json',
    ).writeAsStringSync(jsonOutput);

    print('');
    print('📁 Results saved:');
    print('   benchmark/results/latest.json');
    print('   benchmark/results/history/$historyName.json');
  }

  print('');
  print('═══════════════════════════════════════════════════════');
  print('  TRACKING COMPLETE');
  print('═══════════════════════════════════════════════════════');
}

// =============================================================================
// Core Benchmarks (1-8)
// =============================================================================

Future<void> _runCoreBenchmarks() async {
  // 1. Node creation
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    final nodes = <TitanState<int>>[];
    for (var i = 0; i < count; i++) {
      nodes.add(TitanState(i));
    }
    sw.stop();
    _record(
      'Node Creation (100K)',
      sw.elapsedMicroseconds / count,
      'µs/node',
      'core',
    );
    for (final n in nodes) {
      n.dispose();
    }
  }

  // 2. Notification throughput
  {
    final state = TitanState(0);
    state.listen((_) {});
    const mutations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state.value = i;
    }
    sw.stop();
    _record(
      'Notification (1 listener)',
      mutations / sw.elapsedMicroseconds * 1e6,
      'mutations/sec',
      'core',
    );
    state.dispose();
  }

  // 3. Batch speedup
  {
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

    final eff1 = TitanEffect(() => sum.value);
    final swU = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      states[i % stateCount].value = i + 1000;
    }
    swU.stop();
    eff1.dispose();

    final eff2 = TitanEffect(() => sum.value);
    final swB = Stopwatch()..start();
    for (var batch = 0; batch < mutations ~/ stateCount; batch++) {
      titanBatch(() {
        for (var i = 0; i < stateCount; i++) {
          states[i].value = batch * stateCount + i + 2000;
        }
      });
    }
    swB.stop();

    _record(
      'Batch Speedup',
      swU.elapsedMicroseconds / swB.elapsedMicroseconds,
      'x',
      'core',
    );
    eff2.dispose();
    sum.dispose();
    for (final s in states) {
      s.dispose();
    }
  }

  // 4. Deep chain
  {
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
    _record(
      'Deep Chain (1000)',
      sw.elapsedMicroseconds / mutations,
      'µs/propagation',
      'core',
    );
    for (final c in chain.reversed) {
      c.dispose();
    }
    source.dispose();
  }

  // 5. Fan-out
  {
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
    _record(
      'Fan-Out (10K)',
      sw.elapsedMicroseconds / mutations,
      'µs/propagation',
      'core',
    );
    for (final d in deps) {
      d.dispose();
    }
    source.dispose();
  }

  // 6. Herald throughput
  {
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
    _record(
      'Herald (10 listeners)',
      events / sw.elapsedMicroseconds * 1e6,
      'events/sec',
      'core',
    );
    for (final s in subs) {
      (s as dynamic).cancel();
    }
    Herald.reset();
  }

  // 7. Pillar lifecycle
  {
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
    _record(
      'Pillar Lifecycle (10K)',
      sw.elapsedMicroseconds / count,
      'µs/pillar',
      'core',
    );
    Titan.reset();
    Herald.reset();
  }

  // 8. Diamond dependency
  {
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
    _record(
      'Diamond (1K)',
      sw.elapsedMicroseconds / (diamondCount * mutations),
      'µs/diamond',
      'core',
    );
    for (final d in diamonds) {
      d.dispose();
    }
    for (final s in sources) {
      s.dispose();
    }
  }
}

// =============================================================================
// Extended Benchmarks (9-16)
// =============================================================================

Future<void> _runExtendedBenchmarks() async {
  // 9. Epoch overhead
  {
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
    _record(
      'Epoch Overhead',
      swEpoch.elapsedMicroseconds / swPlain.elapsedMicroseconds,
      'x vs plain',
      'extended',
    );
    plain.dispose();
    epoch.dispose();
  }

  // 10. Effect re-execution
  {
    final state = TitanState(0);
    final effect = TitanEffect(() => state.value);
    const mutations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state.value = i;
    }
    sw.stop();
    _record(
      'Effect Re-exec (1 dep)',
      sw.elapsedMicroseconds / mutations,
      'µs/re-exec',
      'extended',
    );
    effect.dispose();
    state.dispose();
  }

  // 11. Observer overhead
  {
    const mutations = 100000;
    final state = TitanState(0, name: 'bench');
    TitanObserver.instance = null;
    final swNo = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state.value = i;
    }
    swNo.stop();

    TitanObserver.instance = TitanLoggingObserver(logger: (_) {});
    final swYes = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state.value = i + mutations;
    }
    swYes.stop();

    _record(
      'Observer Overhead',
      swYes.elapsedMicroseconds / swNo.elapsedMicroseconds,
      'x vs none',
      'extended',
    );
    TitanObserver.instance = null;
    state.dispose();
  }

  // 12. Scroll validation
  {
    final field = Scroll<String>(
      '',
      validator: (v) => v.isEmpty ? 'Required' : null,
    );
    const validations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < validations; i++) {
      field.value = i.isEven ? '' : 'v$i';
      field.validate();
    }
    sw.stop();
    _record(
      'Scroll Validate',
      sw.elapsedMicroseconds / validations,
      'µs/validate',
      'extended',
    );
    field.dispose();
  }

  // 13. Vigil capture
  {
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
    _record(
      'Vigil Capture',
      captures / sw.elapsedMicroseconds * 1e6,
      'captures/sec',
      'extended',
    );
    Vigil.reset();
  }

  // 14. Chronicle logging
  {
    while (Chronicle.sinks.isNotEmpty) {
      Chronicle.removeSink(Chronicle.sinks.first);
    }
    Chronicle.addSink(_NoOpSink());
    Chronicle.level = LogLevel.trace;
    final log = Chronicle('Bench');
    const messages = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < messages; i++) {
      log.info('msg $i');
    }
    sw.stop();
    _record(
      'Chronicle Log',
      messages / sw.elapsedMicroseconds * 1e6,
      'msgs/sec',
      'extended',
    );
    while (Chronicle.sinks.isNotEmpty) {
      Chronicle.removeSink(Chronicle.sinks.first);
    }
    Chronicle.addSink(Chronicle.consoleSink);
    Chronicle.level = LogLevel.info;
  }

  // 15. DI lookup
  {
    Titan.reset();
    Titan.put<_BenchPillar>(_BenchPillar());
    const lookups = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Titan.has<_BenchPillar>();
    }
    sw.stop();
    _record(
      'DI Lookup (hit)',
      sw.elapsedMicroseconds / lookups * 1000,
      'ns/lookup',
      'extended',
    );
    Titan.reset();
  }

  // 16. GC Stress (state lifecycle)
  {
    const cycles = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final s = TitanState(0);
      final c = s.listen((_) {});
      s.value = 1;
      c();
      s.dispose();
    }
    sw.stop();
    _record(
      'GC Stress (state)',
      sw.elapsedMicroseconds / cycles,
      'µs/cycle',
      'extended',
    );
  }
}

// =============================================================================
// Enterprise Benchmarks (17-27)
// =============================================================================

Future<void> _runEnterpriseBenchmarks() async {
  // 17. Loom transition
  {
    final loom = Loom<_LoomState, _LoomAction>(
      initial: _LoomState.available,
      transitions: {
        (_LoomState.available, _LoomAction.claim): _LoomState.claiming,
        (_LoomState.claiming, _LoomAction.start): _LoomState.active,
        (_LoomState.active, _LoomAction.complete): _LoomState.completed,
      },
      maxHistory: 0,
    );
    const cycles = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      loom.send(_LoomAction.claim);
      loom.send(_LoomAction.start);
      loom.send(_LoomAction.complete);
      loom.reset(_LoomState.available);
    }
    sw.stop();
    _record(
      'Loom Transition',
      sw.elapsedMicroseconds / (cycles * 3),
      'µs/transition',
      'enterprise',
    );
    loom.state.dispose();
  }

  // 18. Bulwark success call
  {
    final bulwark = Bulwark<int>(failureThreshold: 5);
    const calls = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      await bulwark.call(() async => i);
    }
    sw.stop();
    _record(
      'Bulwark Success',
      sw.elapsedMicroseconds / calls,
      'µs/call',
      'enterprise',
    );
    bulwark.dispose();
  }

  // 19. Saga workflow
  {
    final steps = List.generate(
      10,
      (i) => SagaStep<int>(
        name: 'step$i',
        execute: (prev) async => (prev ?? 0) + 1,
      ),
    );
    const runs = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      final saga = Saga<int>(steps: steps);
      await saga.run();
      saga.dispose();
    }
    sw.stop();
    _record(
      'Saga (10 steps)',
      sw.elapsedMicroseconds / runs,
      'µs/run',
      'enterprise',
    );
  }

  // 20. Volley batch
  {
    final tasks = List.generate(
      100,
      (i) => VolleyTask<int>(name: 't$i', execute: () async => i),
    );
    final volley = Volley<int>(concurrency: 10);
    final sw = Stopwatch()..start();
    await volley.execute(tasks);
    sw.stop();
    _record(
      'Volley (100 tasks, conc=10)',
      sw.elapsedMicroseconds / 100,
      'µs/task',
      'enterprise',
    );
    volley.dispose();
  }

  // 21. Annals record (capped)
  {
    Annals.reset();
    Annals.enable(maxEntries: 1000);
    const records = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < records; i++) {
      Annals.record(AnnalEntry(coreName: 'c', oldValue: i, newValue: i + 1));
    }
    sw.stop();
    _record(
      'Annals Record (cap=1K)',
      records / sw.elapsedMicroseconds * 1e6,
      'records/sec',
      'enterprise',
    );
    Annals.reset();
  }

  // 22. Tether call
  {
    Tether.reset();
    Tether.register<int, int>('mul', (r) async => r * 2);
    const calls = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      await Tether.call<int, int>('mul', i);
    }
    sw.stop();
    _record(
      'Tether Call',
      sw.elapsedMicroseconds / calls,
      'µs/call',
      'enterprise',
    );
    Tether.reset();
  }

  // 23. Aegis success
  {
    const calls = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      await Aegis.run(() async => i, maxAttempts: 3, baseDelay: Duration.zero);
    }
    sw.stop();
    _record(
      'Aegis Success',
      sw.elapsedMicroseconds / calls,
      'µs/call',
      'enterprise',
    );
  }

  // 24. Sigil lookup
  {
    Sigil.reset();
    for (var i = 0; i < 100; i++) {
      Sigil.register('f_$i', i.isEven);
    }
    const lookups = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Sigil.isEnabled('f_0');
    }
    sw.stop();
    _record(
      'Sigil Lookup',
      lookups / sw.elapsedMicroseconds * 1e6,
      'lookups/sec',
      'enterprise',
    );
    Sigil.reset();
  }

  // 25. Core.toggle
  {
    final flag = TitanState(false);
    const ops = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      flag.toggle();
    }
    sw.stop();
    _record('Core.toggle', sw.elapsedMicroseconds / ops, 'µs/op', 'enterprise');
    flag.dispose();
  }

  // 26. Snapshot capture
  {
    final nodes = List.generate(100, (i) => TitanState(i, name: 'n$i'));
    const captures = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < captures; i++) {
      Snapshot.captureFromNodes(nodes);
    }
    sw.stop();
    _record(
      'Snapshot Capture (100)',
      sw.elapsedMicroseconds / captures,
      'µs/capture',
      'enterprise',
    );
    for (final n in nodes) {
      n.dispose();
    }
  }

  // 27. Crucible track
  {
    final crucible = Crucible(() => _BenchPillar());
    crucible.track(crucible.pillar.count);
    const mutations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      crucible.pillar.count.value = i;
    }
    sw.stop();
    _record(
      'Crucible Track',
      sw.elapsedMicroseconds / mutations,
      'µs/mutation',
      'enterprise',
    );
    crucible.dispose();
    Titan.reset();
    Herald.reset();
  }
}

// =============================================================================
// Report Generation
// =============================================================================

void _printReport(Map<String, dynamic>? previous, double threshold) {
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  RESULTS');
  print('═══════════════════════════════════════════════════════');
  print('');

  final hasPrevious = previous != null;
  Map<String, dynamic>? prevBenchmarks;
  if (hasPrevious) {
    prevBenchmarks = previous['benchmarks'] as Map<String, dynamic>?;
    print(
      '  Comparing against: ${previous['version']} '
      '(${previous['timestamp']})',
    );
    print('');
  }

  // Group by suite
  final suites = <String, List<String>>{};
  for (final entry in _results.entries) {
    suites.putIfAbsent(entry.value.suite, () => []).add(entry.key);
  }

  var regressionCount = 0;
  var improvementCount = 0;

  for (final suite in ['core', 'extended', 'enterprise']) {
    final names = suites[suite];
    if (names == null) continue;

    final suiteName = suite[0].toUpperCase() + suite.substring(1);
    print('  ┌─ $suiteName ${'─' * (49 - suiteName.length)}');

    for (final name in names) {
      final result = _results[name]!;
      final valueStr = _formatValue(result.value, result.unit);

      if (hasPrevious &&
          prevBenchmarks != null &&
          prevBenchmarks.containsKey(name)) {
        final prevData = prevBenchmarks[name] as Map<String, dynamic>;
        final prevValue = (prevData['value'] as num).toDouble();
        final change = _calculateChange(result.value, prevValue, result.unit);
        final changeStr = _formatChange(change);
        final flag = _regressionFlag(change, threshold);

        if (change > threshold) regressionCount++;
        if (change < -threshold) improvementCount++;

        print('  │  $name: $valueStr  $changeStr $flag');
      } else {
        print('  │  $name: $valueStr');
      }
    }

    print('  └${'─' * 53}');
    print('');
  }

  // Summary
  if (hasPrevious) {
    print(
      '  Summary: $regressionCount regressions, '
      '$improvementCount improvements '
      '(threshold: ±${threshold.toStringAsFixed(0)}%)',
    );
    if (regressionCount > 0) {
      print('  ⚠ REGRESSIONS DETECTED — investigate before committing');
    } else {
      print('  ✓ No significant regressions');
    }
  } else {
    print('  ℹ No previous results to compare against (first run)');
  }
}

// =============================================================================
// Comparison Helpers
// =============================================================================

/// Calculate the % change between current and previous.
/// For "higher is better" metrics (throughput), positive change means regression.
/// For "lower is better" metrics (latency), positive change means regression.
double _calculateChange(double current, double previous, String unit) {
  if (previous == 0) return 0;

  // Higher-is-better units: positive % = improvement, flip sign for regression
  final higherIsBetter =
      unit.contains('/sec') ||
      unit.contains('lookups/sec') ||
      unit.contains('records/sec') ||
      unit == 'x';

  final pctChange = ((current - previous) / previous) * 100;

  // For higher-is-better: a decrease is a regression (return positive %)
  // For lower-is-better: an increase is a regression (return positive %)
  return higherIsBetter ? -pctChange : pctChange;
}

String _formatChange(double change) {
  final sign = change > 0 ? '+' : '';
  return '($sign${change.toStringAsFixed(1)}%)'.padLeft(10);
}

String _regressionFlag(double change, double threshold) {
  if (change > threshold * 2) return '🔴';
  if (change > threshold) return '🟡';
  if (change < -threshold) return '🟢';
  return '  ';
}

String _formatValue(double value, String unit) {
  String formatted;
  if (value >= 1e6) {
    formatted = '${(value / 1e6).toStringAsFixed(1)}M';
  } else if (value >= 1e3) {
    formatted = '${(value / 1e3).toStringAsFixed(1)}K';
  } else if (value >= 1) {
    formatted = value.toStringAsFixed(2);
  } else {
    formatted = value.toStringAsFixed(3);
  }
  return '$formatted $unit'.padRight(28);
}

// =============================================================================
// History
// =============================================================================

void _showHistory(Directory historyDir) {
  if (!historyDir.existsSync()) {
    print('No benchmark history found.');
    return;
  }

  final files =
      historyDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    print('No benchmark history found.');
    return;
  }

  print('');
  print('═══════════════════════════════════════════════════════');
  print('  BENCHMARK HISTORY');
  print('═══════════════════════════════════════════════════════');
  print('');

  for (final file in files) {
    try {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final name = file.uri.pathSegments.last.replaceAll('.json', '');
      final version = data['version'] ?? '?';
      final ts = data['timestamp'] ?? '?';
      final benchmarks = data['benchmarks'] as Map<String, dynamic>?;
      final count = benchmarks?.length ?? 0;
      print('  $name  v$version  $ts  ($count metrics)');
    } catch (_) {
      print('  ${file.path}  (invalid)');
    }
  }
  print('');
}

// =============================================================================
// Utilities
// =============================================================================

void _record(String name, double value, String unit, String suite) {
  if (_isWarmup) return;
  _results[name] = _BenchResult(value: value, unit: unit, suite: suite);
}

String _readVersion() {
  try {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'version:\s*(.+)').firstMatch(pubspec);
    return match?.group(1)?.trim() ?? 'unknown';
  } catch (_) {
    return 'unknown';
  }
}

String? _getArg(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index >= 0 && index + 1 < args.length) {
    return args[index + 1];
  }
  return null;
}

class _BenchResult {
  final double value;
  final String unit;
  final String suite;
  _BenchResult({required this.value, required this.unit, required this.suite});
}

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

class _NoOpSink extends LogSink {
  @override
  void write(LogEntry entry) {}
}

enum _LoomState { available, claiming, active, completed }

enum _LoomAction { claim, start, complete }
