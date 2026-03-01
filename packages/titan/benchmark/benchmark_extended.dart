// ignore_for_file: avoid_print
import 'package:titan/titan.dart';

// =============================================================================
// Titan Extended Benchmarks
// =============================================================================
//
// Run with: dart run benchmark/benchmark_extended.dart
//
// Covers features NOT in the core benchmark suite:
//   9.  Epoch (undo/redo) — history overhead, undo/redo throughput
//  10.  TitanEffect — side-effect tracking & re-execution
//  11.  TitanObserver — global observation overhead
//  12.  Scroll / ScrollGroup — form validation at scale
//  13.  Vigil — error capture & handler dispatch
//  14.  Chronicle — logging throughput & level filtering
//  15.  Titan DI — registration, lookup, lazy resolution
//  16.  GC Stress — mass creation + disposal cycles
// =============================================================================

void main() async {
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  TITAN EXTENDED BENCHMARKS');
  print('═══════════════════════════════════════════════════════');
  print('');

  await _benchEpoch();
  await _benchEffect();
  await _benchObserver();
  await _benchScrollValidation();
  await _benchVigil();
  await _benchChronicle();
  await _benchTitanDI();
  await _benchGCStress();

  print('');
  print('═══════════════════════════════════════════════════════');
  print('  ALL EXTENDED BENCHMARKS COMPLETE');
  print('═══════════════════════════════════════════════════════');
}

// ---------------------------------------------------------------------------
// 9. Epoch (Undo / Redo)
// ---------------------------------------------------------------------------

Future<void> _benchEpoch() async {
  print('┌─ 9. Epoch Undo/Redo Performance ─────────────────────');

  // a) History recording overhead vs plain TitanState
  {
    const mutations = 100000;

    final plain = TitanState(0);
    final swPlain = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      plain.value = i;
    }
    swPlain.stop();

    final epoch = Epoch(0, maxHistory: mutations);
    final swEpoch = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      epoch.value = i;
    }
    swEpoch.stop();

    final overhead = (swEpoch.elapsedMicroseconds / swPlain.elapsedMicroseconds)
        .toStringAsFixed(2);
    print(
      '│  History overhead ($mutations mutations): '
      '${_ms(swPlain)} plain, ${_ms(swEpoch)} epoch (${overhead}x)',
    );

    plain.dispose();
    epoch.dispose();
  }

  // b) Undo throughput
  {
    for (final depth in [100, 1000, 10000]) {
      final epoch = Epoch(0, maxHistory: depth);
      for (var i = 1; i <= depth; i++) {
        epoch.value = i;
      }

      final sw = Stopwatch()..start();
      while (epoch.canUndo) {
        epoch.undo();
      }
      sw.stop();

      final perUndo = (sw.elapsedMicroseconds / depth).toStringAsFixed(2);
      print(
        '│  Undo ${_pad(depth)} steps: '
        '${_ms(sw)}  ($perUndo µs/undo)',
      );

      epoch.dispose();
    }
  }

  // c) Redo throughput
  {
    const depth = 10000;
    final epoch = Epoch(0, maxHistory: depth);
    for (var i = 1; i <= depth; i++) {
      epoch.value = i;
    }
    while (epoch.canUndo) {
      epoch.undo();
    }

    final sw = Stopwatch()..start();
    while (epoch.canRedo) {
      epoch.redo();
    }
    sw.stop();

    final perRedo = (sw.elapsedMicroseconds / depth).toStringAsFixed(2);
    print(
      '│  Redo ${_pad(depth)} steps: '
      '${_ms(sw)}  ($perRedo µs/redo)',
    );

    epoch.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 10. TitanEffect throughput
// ---------------------------------------------------------------------------

Future<void> _benchEffect() async {
  print('┌─ 10. TitanEffect Throughput ──────────────────────────');

  // a) Effect re-execution: state change → effect re-run
  {
    for (final depCount in [1, 10, 100]) {
      final states = List.generate(depCount, (i) => TitanState(i));
      final effect = TitanEffect(() {
        for (final s in states) {
          s.value; // track all
        }
      });

      const mutations = 10000;
      final sw = Stopwatch()..start();
      for (var i = 0; i < mutations; i++) {
        states[i % depCount].value = i + 1000;
      }
      sw.stop();

      final perExec = (sw.elapsedMicroseconds / mutations).toStringAsFixed(2);
      print(
        '│  ${_pad(depCount)} deps × $mutations mutations: '
        '${_ms(sw)}  ($perExec µs/re-exec)',
      );

      effect.dispose();
      for (final s in states) {
        s.dispose();
      }
    }
  }

  // b) Effect with cleanup function overhead
  {
    final state = TitanState(0);
    var cleanupCount = 0;

    final effectNoCleanup = TitanEffect(() {
      state.value;
    });

    final effectWithCleanup = TitanEffect(() {
      state.value;
      return () => cleanupCount++;
    });

    // Benchmark without cleanup
    const mutations = 50000;
    final swNo = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state.value = i;
    }
    swNo.stop();

    effectNoCleanup.dispose();
    effectWithCleanup.dispose();

    // Re-create for clean measurement with cleanup only
    final state2 = TitanState(0);
    cleanupCount = 0;

    final effectCleanup = TitanEffect(() {
      state2.value;
      return () => cleanupCount++;
    });

    final swYes = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state2.value = i;
    }
    swYes.stop();

    print(
      '│  Cleanup overhead ($mutations): '
      '${_ms(swNo)} without, ${_ms(swYes)} with '
      '($cleanupCount cleanups)',
    );

    effectCleanup.dispose();
    state.dispose();
    state2.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 11. TitanObserver overhead
// ---------------------------------------------------------------------------

Future<void> _benchObserver() async {
  print('┌─ 11. TitanObserver Overhead ──────────────────────────');

  const mutations = 100000;
  final state = TitanState(0, name: 'bench');

  // a) No observer
  {
    TitanObserver.instance = null;
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state.value = i;
    }
    sw.stop();
    print('│  No observer ($mutations): ${_ms(sw)}');
  }

  // b) Logging observer (with no-op logger)
  {
    TitanObserver.instance = TitanLoggingObserver(logger: (_) {});
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state.value = i + mutations;
    }
    sw.stop();
    print('│  LoggingObserver (no-op): ${_ms(sw)}');
  }

  // c) History observer
  {
    final histObserver = TitanHistoryObserver(maxHistory: 1000);
    TitanObserver.instance = histObserver;
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      state.value = i + mutations * 2;
    }
    sw.stop();
    print(
      '│  HistoryObserver (cap 1000): ${_ms(sw)} '
      '(${histObserver.length} records)',
    );
    histObserver.clear();
  }

  TitanObserver.instance = null;
  state.dispose();

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 12. Scroll / ScrollGroup validation
// ---------------------------------------------------------------------------

Future<void> _benchScrollValidation() async {
  print('┌─ 12. Scroll / ScrollGroup Validation ────────────────');

  // a) Single field validation throughput
  {
    final field = Scroll<String>(
      '',
      validator: (v) => v.isEmpty ? 'Required' : null,
    );

    const validations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < validations; i++) {
      field.value = i.isEven ? '' : 'value$i';
      field.validate();
    }
    sw.stop();

    final perVal = (sw.elapsedMicroseconds / validations).toStringAsFixed(2);
    print(
      '│  Single field ($validations): '
      '${_ms(sw)}  ($perVal µs/validate)',
    );
    field.dispose();
  }

  // b) Regex validator (heavier computation)
  {
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');
    final field = Scroll<String>(
      '',
      validator: (v) => emailRegex.hasMatch(v) ? null : 'Invalid email',
    );

    const validations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < validations; i++) {
      field.value = 'user$i@example.com';
      field.validate();
    }
    sw.stop();

    final perVal = (sw.elapsedMicroseconds / validations).toStringAsFixed(2);
    print(
      '│  Regex validator ($validations): '
      '${_ms(sw)}  ($perVal µs/validate)',
    );
    field.dispose();
  }

  // c) ScrollGroup.validateAll at scale
  {
    for (final fieldCount in [10, 100, 1000]) {
      final fields = List.generate(
        fieldCount,
        (i) =>
            Scroll<String>('', validator: (v) => v.isEmpty ? 'Required' : null),
      );
      final group = ScrollGroup(fields);

      // Set half the fields to valid values
      for (var i = 0; i < fieldCount; i += 2) {
        fields[i].value = 'valid';
      }

      const rounds = 1000;
      final sw = Stopwatch()..start();
      for (var i = 0; i < rounds; i++) {
        group.validateAll();
      }
      sw.stop();

      final perValidateAll = (sw.elapsedMicroseconds / rounds).toStringAsFixed(
        1,
      );
      print(
        '│  ScrollGroup ${_pad(fieldCount)} fields × $rounds: '
        '${_ms(sw)}  ($perValidateAll µs/validateAll)',
      );

      for (final f in fields) {
        f.dispose();
      }
    }
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 13. Vigil error capture
// ---------------------------------------------------------------------------

Future<void> _benchVigil() async {
  print('┌─ 13. Vigil Error Capture ─────────────────────────────');

  Vigil.reset();

  // a) capture() throughput with 0, 1, 10 handlers
  for (final handlerCount in [0, 1, 10]) {
    Vigil.reset();
    final handlers = <_NoOpHandler>[];
    for (var i = 0; i < handlerCount; i++) {
      final h = _NoOpHandler();
      Vigil.addHandler(h);
      handlers.add(h);
    }

    const captures = 100000;
    Vigil.maxHistorySize = 0; // disable history for pure dispatch benchmark

    final sw = Stopwatch()..start();
    for (var i = 0; i < captures; i++) {
      Vigil.capture('Error $i', severity: ErrorSeverity.error);
    }
    sw.stop();

    final throughput = (captures / sw.elapsedMicroseconds * 1e6)
        .toStringAsFixed(0);
    final totalHandled = handlers.fold<int>(0, (sum, h) => sum + h.count);
    print(
      '│  ${_pad(handlerCount)} handlers × $captures: '
      '${_ms(sw)}  ($throughput captures/sec, $totalHandled dispatched)',
    );
  }

  // b) History recording + trimming overhead
  {
    Vigil.reset();
    Vigil.maxHistorySize = 1000;

    const captures = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < captures; i++) {
      Vigil.capture('Error $i');
    }
    sw.stop();

    final perCapture = (sw.elapsedMicroseconds / captures).toStringAsFixed(2);
    print(
      '│  History (cap 1000, $captures): '
      '${_ms(sw)}  ($perCapture µs/capture, '
      '${Vigil.history.length} stored)',
    );
  }

  // c) guard() overhead vs raw try/catch
  {
    const runs = 100000;

    // Raw try/catch
    final swRaw = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      try {
        _noThrow(i);
      } catch (_) {
        // swallow
      }
    }
    swRaw.stop();

    // Vigil.guard (no error path — measures overhead of wrapping)
    Vigil.reset();
    Vigil.maxHistorySize = 0;
    final swGuard = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      Vigil.guard(() => _noThrow(i));
    }
    swGuard.stop();

    print(
      '│  guard() overhead ($runs, no-throw): '
      '${_ms(swRaw)} raw, ${_ms(swGuard)} guard',
    );
  }

  Vigil.reset();
  print('└───────────────────────────────────────────────────────');
  print('');
}

int _noThrow(int i) => i * 2;

// ---------------------------------------------------------------------------
// 14. Chronicle logging
// ---------------------------------------------------------------------------

Future<void> _benchChronicle() async {
  print('┌─ 14. Chronicle Logging Throughput ────────────────────');

  // a) Throughput with 0, 1, 10 sinks (no-op sinks)
  for (final sinkCount in [0, 1, 10]) {
    // Remove default console sink
    Chronicle.level = LogLevel.trace;
    while (Chronicle.sinks.isNotEmpty) {
      Chronicle.removeSink(Chronicle.sinks.first);
    }

    final sinks = <_NoOpSink>[];
    for (var i = 0; i < sinkCount; i++) {
      final s = _NoOpSink();
      Chronicle.addSink(s);
      sinks.add(s);
    }

    final log = Chronicle('Bench');
    const messages = 100000;

    final sw = Stopwatch()..start();
    for (var i = 0; i < messages; i++) {
      log.info('Message $i');
    }
    sw.stop();

    final throughput = (messages / sw.elapsedMicroseconds * 1e6)
        .toStringAsFixed(0);
    final totalWritten = sinks.fold<int>(0, (sum, s) => sum + s.count);
    print(
      '│  ${_pad(sinkCount)} sinks × $messages: '
      '${_ms(sw)}  ($throughput msgs/sec, $totalWritten written)',
    );
  }

  // b) Level filtering — messages below threshold (should be near-zero cost)
  {
    while (Chronicle.sinks.isNotEmpty) {
      Chronicle.removeSink(Chronicle.sinks.first);
    }
    Chronicle.addSink(_NoOpSink());
    Chronicle.level = LogLevel.warning; // suppress trace/debug/info

    final log = Chronicle('Bench');
    const messages = 1000000;

    final sw = Stopwatch()..start();
    for (var i = 0; i < messages; i++) {
      log.debug('This should be filtered out');
    }
    sw.stop();

    final throughput = (messages / sw.elapsedMicroseconds * 1e6)
        .toStringAsFixed(0);
    print(
      '│  Level filter ($messages suppressed): '
      '${_ms(sw)}  ($throughput filtered/sec)',
    );
  }

  // c) Structured data attachment cost
  {
    while (Chronicle.sinks.isNotEmpty) {
      Chronicle.removeSink(Chronicle.sinks.first);
    }
    Chronicle.addSink(_NoOpSink());
    Chronicle.level = LogLevel.trace;

    final log = Chronicle('Bench');
    const messages = 100000;

    // Without data
    final swNoData = Stopwatch()..start();
    for (var i = 0; i < messages; i++) {
      log.info('No data');
    }
    swNoData.stop();

    // With data
    final swData = Stopwatch()..start();
    for (var i = 0; i < messages; i++) {
      log.info('With data', {'key': 'value', 'index': i});
    }
    swData.stop();

    print(
      '│  Data attachment ($messages): '
      '${_ms(swNoData)} without, ${_ms(swData)} with',
    );
  }

  // Reset
  while (Chronicle.sinks.isNotEmpty) {
    Chronicle.removeSink(Chronicle.sinks.first);
  }
  Chronicle.addSink(Chronicle.consoleSink);
  Chronicle.level = LogLevel.info;

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 15. Titan DI (registration & lookup)
// ---------------------------------------------------------------------------

Future<void> _benchTitanDI() async {
  print('┌─ 15. Titan DI Registration & Lookup ─────────────────');

  // a) put + get throughput
  {
    Titan.reset();

    const count = 10000;
    final instances = List.generate(count, (i) => _StubPillar());

    final swPut = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Titan.forge(instances[i]);
    }
    swPut.stop();

    final perPut = (swPut.elapsedMicroseconds / count).toStringAsFixed(2);
    print(
      '│  forge() $count pillars: '
      '${_ms(swPut)}  ($perPut µs/put)',
    );

    Titan.reset();
  }

  // b) has() lookup (hit + miss)
  {
    Titan.reset();
    Titan.put<_StubPillar>(_StubPillar());

    const lookups = 1000000;

    // Hit
    final swHit = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Titan.has<_StubPillar>();
    }
    swHit.stop();

    // Miss
    final swMiss = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Titan.has<_StubPillar2>();
    }
    swMiss.stop();

    final perHit = (swHit.elapsedMicroseconds / lookups * 1000).toStringAsFixed(
      1,
    );
    final perMiss = (swMiss.elapsedMicroseconds / lookups * 1000)
        .toStringAsFixed(1);
    print(
      '│  has() $lookups lookups: '
      '${_ms(swHit)} hit ($perHit ns), '
      '${_ms(swMiss)} miss ($perMiss ns)',
    );

    Titan.reset();
  }

  // c) lazy() — first-access resolution cost
  {
    Titan.reset();

    const count = 10000;
    for (var i = 0; i < count; i++) {
      // Register under unique _Tag types isn't feasible, so test resolution
      // of a single type repeatedly after reset
    }

    // Measure lazy registration cost
    final swRegister = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Titan.reset();
      Titan.lazy<_StubPillar>(() => _StubPillar());
    }
    swRegister.stop();

    // Measure first-access resolution
    Titan.reset();
    Titan.lazy<_StubPillar>(() => _StubPillar());

    final swResolve = Stopwatch()..start();
    Titan.get<_StubPillar>();
    swResolve.stop();

    print(
      '│  lazy() register ($count): ${_ms(swRegister)}  '
      'resolve: ${swResolve.elapsedMicroseconds} µs',
    );

    Titan.reset();
  }

  // d) reset() cost with many pillars
  {
    for (final count in [10, 100, 1000]) {
      final instances = <_StubPillar>[];
      for (var i = 0; i < count; i++) {
        final p = _StubPillar();
        Titan.forge(p);
        instances.add(p);
      }

      final sw = Stopwatch()..start();
      Titan.reset();
      sw.stop();

      final perDispose = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print(
        '│  reset() ${_pad(count)} pillars: '
        '${_ms(sw)}  ($perDispose µs/pillar)',
      );
    }
  }

  Titan.reset();
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 16. GC Stress — mass creation + disposal cycles
// ---------------------------------------------------------------------------

Future<void> _benchGCStress() async {
  print('┌─ 16. GC Stress (Create → Use → Dispose Cycles) ──────');

  // a) State lifecycle: create → mutate → listen → dispose
  {
    const cycles = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final state = TitanState(0);
      final cancel = state.listen((_) {});
      state.value = 1;
      state.value = 2;
      cancel();
      state.dispose();
    }
    sw.stop();

    final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
    print(
      '│  State lifecycle ($cycles): '
      '${_ms(sw)}  ($perCycle µs/cycle)',
    );
  }

  // b) Computed lifecycle: create → read → dispose
  {
    const cycles = 10000;
    final source = TitanState(0);

    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final computed = TitanComputed(() => source.value * 2);
      computed.value; // force evaluation
      computed.dispose();
    }
    sw.stop();
    source.dispose();

    final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
    print(
      '│  Computed lifecycle ($cycles): '
      '${_ms(sw)}  ($perCycle µs/cycle)',
    );
  }

  // c) Effect lifecycle: create → trigger → dispose
  {
    const cycles = 10000;
    final source = TitanState(0);

    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final effect = TitanEffect(() {
        source.value; // track
      });
      source.value = i; // trigger re-exec
      effect.dispose();
    }
    sw.stop();
    source.dispose();

    final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
    print(
      '│  Effect lifecycle ($cycles): '
      '${_ms(sw)}  ($perCycle µs/cycle)',
    );
  }

  // d) Full graph lifecycle: Pillar create → init → use → dispose
  {
    const cycles = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final p = _BenchPillar();
      p.initialize();
      p.count.value = i;
      p.doubled.value; // read computed
      p.dispose();
    }
    sw.stop();

    final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
    print(
      '│  Pillar lifecycle ($cycles): '
      '${_ms(sw)}  ($perCycle µs/cycle)',
    );
  }

  // e) Scroll lifecycle: create → validate → dispose
  {
    const cycles = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final field = Scroll<String>(
        '',
        validator: (v) => v.isEmpty ? 'Required' : null,
      );
      field.value = 'test';
      field.validate();
      field.touch();
      field.reset();
      field.dispose();
    }
    sw.stop();

    final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
    print(
      '│  Scroll lifecycle ($cycles): '
      '${_ms(sw)}  ($perCycle µs/cycle)',
    );
  }

  // f) Epoch lifecycle: create → mutate → undo → dispose
  {
    const cycles = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final epoch = Epoch(0);
      epoch.value = 1;
      epoch.value = 2;
      epoch.undo();
      epoch.dispose();
    }
    sw.stop();

    final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
    print(
      '│  Epoch lifecycle ($cycles): '
      '${_ms(sw)}  ($perCycle µs/cycle)',
    );
  }

  Titan.reset();
  Herald.reset();

  print('└───────────────────────────────────────────────────────');
  print('');
}

// =============================================================================
// Helpers
// =============================================================================

class _NoOpHandler extends ErrorHandler {
  int count = 0;

  @override
  void handle(TitanError error) {
    count++;
  }
}

class _NoOpSink extends LogSink {
  int count = 0;

  @override
  void write(LogEntry entry) {
    count++;
  }
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

class _StubPillar extends Pillar {
  late final value = core(0);
}

class _StubPillar2 extends Pillar {
  late final value = core(0);
}

String _ms(Stopwatch sw) {
  if (sw.elapsedMilliseconds < 1) {
    return '${sw.elapsedMicroseconds} µs'.padLeft(10);
  }
  return '${sw.elapsedMilliseconds} ms'.padLeft(10);
}

String _pad(int n) => n.toString().padLeft(6);
