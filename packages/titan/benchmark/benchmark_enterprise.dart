// ignore_for_file: avoid_print
import 'dart:async';

import 'package:titan/titan.dart';

// =============================================================================
// Titan Enterprise Benchmarks
// =============================================================================
//
// Run with: dart run benchmark/benchmark_enterprise.dart
//
// Covers enterprise features from phases 1–10:
//  17. Loom — FSM creation, transition throughput, history, allowedEvents
//  18. Bulwark — Circuit breaker lifecycle, call overhead, trip/reset
//  19. Saga — Multi-step workflow execution, compensation
//  20. Volley — Batch async with concurrency control
//  21. Annals — Audit trail recording, querying, export
//  22. Tether — Request-response channel registration & dispatch
//  23. Aegis — Retry with backoff (success + failure paths)
//  24. Sigil — Feature flag registration, lookup, toggle throughput
//  25. Core Extensions — toggle, increment, list ops, map ops, select
//  26. Snapshot — State capture & restore, diff
//  27. Crucible — Testing harness track + change recording
//  28. Conduit — Core-level middleware pipeline throughput
//  29. Prism — Fine-grained state projections
//  30. Nexus — Reactive collections (NexusList, NexusMap, NexusSet)
// =============================================================================

void main() async {
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  TITAN ENTERPRISE BENCHMARKS');
  print('═══════════════════════════════════════════════════════');
  print('');

  await _benchLoom();
  await _benchBulwark();
  await _benchSaga();
  await _benchVolley();
  await _benchAnnals();
  await _benchTether();
  await _benchAegis();
  await _benchSigil();
  await _benchCoreExtensions();
  await _benchSnapshot();
  await _benchCrucible();
  await _benchConduit();
  await _benchPrism();
  await _benchNexus();

  print('');
  print('═══════════════════════════════════════════════════════');
  print('  ALL ENTERPRISE BENCHMARKS COMPLETE');
  print('═══════════════════════════════════════════════════════');
}

// ---------------------------------------------------------------------------
// 17. Loom — Finite State Machine
// ---------------------------------------------------------------------------

enum _QuestState { available, claiming, active, completed, failed }

enum _QuestEvent { claim, start, complete, fail, retry, abandon }

Future<void> _benchLoom() async {
  print('┌─ 17. Loom (FSM) ─────────────────────────────────────');

  // a) Creation at scale
  {
    for (final count in [100, 1000, 10000]) {
      final sw = Stopwatch()..start();
      final looms = <Loom<_QuestState, _QuestEvent>>[];
      for (var i = 0; i < count; i++) {
        looms.add(
          Loom(
            initial: _QuestState.available,
            transitions: {
              (_QuestState.available, _QuestEvent.claim): _QuestState.claiming,
              (_QuestState.claiming, _QuestEvent.start): _QuestState.active,
              (_QuestState.active, _QuestEvent.complete): _QuestState.completed,
              (_QuestState.active, _QuestEvent.fail): _QuestState.failed,
              (_QuestState.failed, _QuestEvent.retry): _QuestState.active,
              (_QuestState.claiming, _QuestEvent.abandon):
                  _QuestState.available,
            },
          ),
        );
      }
      sw.stop();

      final perLoom = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print('│  Create ${_pad(count)} looms: ${_ms(sw)}  ($perLoom µs/loom)');

      for (final l in looms) {
        l.state.dispose();
      }
    }
  }

  // b) Transition throughput
  {
    final loom = Loom<_QuestState, _QuestEvent>(
      initial: _QuestState.available,
      transitions: {
        (_QuestState.available, _QuestEvent.claim): _QuestState.claiming,
        (_QuestState.claiming, _QuestEvent.start): _QuestState.active,
        (_QuestState.active, _QuestEvent.complete): _QuestState.completed,
        (_QuestState.active, _QuestEvent.fail): _QuestState.failed,
        (_QuestState.failed, _QuestEvent.retry): _QuestState.active,
        (_QuestState.claiming, _QuestEvent.abandon): _QuestState.available,
      },
      maxHistory: 0,
    );

    const cycles = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      loom.send(_QuestEvent.claim);
      loom.send(_QuestEvent.start);
      loom.send(_QuestEvent.complete);
      loom.reset(_QuestState.available);
    }
    sw.stop();

    final totalTransitions = cycles * 3;
    final perTransition = (sw.elapsedMicroseconds / totalTransitions)
        .toStringAsFixed(2);
    print(
      '│  ${_pad(totalTransitions)} transitions: '
      '${_ms(sw)}  ($perTransition µs/transition)',
    );

    loom.state.dispose();
  }

  // c) canSend / allowedEvents throughput
  {
    final loom = Loom<_QuestState, _QuestEvent>(
      initial: _QuestState.available,
      transitions: {
        (_QuestState.available, _QuestEvent.claim): _QuestState.claiming,
        (_QuestState.claiming, _QuestEvent.start): _QuestState.active,
        (_QuestState.active, _QuestEvent.complete): _QuestState.completed,
        (_QuestState.active, _QuestEvent.fail): _QuestState.failed,
        (_QuestState.failed, _QuestEvent.retry): _QuestState.active,
        (_QuestState.claiming, _QuestEvent.abandon): _QuestState.available,
      },
    );

    const lookups = 100000;
    final swCanSend = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      loom.canSend(_QuestEvent.claim);
    }
    swCanSend.stop();

    final swAllowed = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      loom.allowedEvents;
    }
    swAllowed.stop();

    final perCanSend = (swCanSend.elapsedMicroseconds / lookups * 1000)
        .toStringAsFixed(1);
    final perAllowed = (swAllowed.elapsedMicroseconds / lookups * 1000)
        .toStringAsFixed(1);
    print(
      '│  canSend ($lookups): ${_ms(swCanSend)} ($perCanSend ns/call)  '
      'allowedEvents: ${_ms(swAllowed)} ($perAllowed ns/call)',
    );

    loom.state.dispose();
  }

  // d) Transition with callbacks overhead
  {
    var enterCount = 0;
    var exitCount = 0;
    var transitionCount = 0;

    final loom = Loom<_QuestState, _QuestEvent>(
      initial: _QuestState.available,
      transitions: {
        (_QuestState.available, _QuestEvent.claim): _QuestState.claiming,
        (_QuestState.claiming, _QuestEvent.start): _QuestState.active,
        (_QuestState.active, _QuestEvent.complete): _QuestState.completed,
        (_QuestState.claiming, _QuestEvent.abandon): _QuestState.available,
      },
      onEnter: {
        _QuestState.claiming: () => enterCount++,
        _QuestState.active: () => enterCount++,
        _QuestState.completed: () => enterCount++,
      },
      onExit: {
        _QuestState.available: () => exitCount++,
        _QuestState.claiming: () => exitCount++,
        _QuestState.active: () => exitCount++,
      },
      onTransition: (from, event, to) => transitionCount++,
      maxHistory: 0,
    );

    const cycles = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      loom.send(_QuestEvent.claim);
      loom.send(_QuestEvent.start);
      loom.send(_QuestEvent.complete);
      loom.reset(_QuestState.available);
    }
    sw.stop();

    final totalTransitions = cycles * 3;
    final perTransition = (sw.elapsedMicroseconds / totalTransitions)
        .toStringAsFixed(2);
    print(
      '│  With callbacks ($totalTransitions): '
      '${_ms(sw)}  ($perTransition µs/transition, '
      '$enterCount enters, $exitCount exits)',
    );

    loom.state.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 18. Bulwark — Circuit Breaker
// ---------------------------------------------------------------------------

Future<void> _benchBulwark() async {
  print('┌─ 18. Bulwark (Circuit Breaker) ──────────────────────');

  // a) Successful call throughput (closed circuit)
  {
    final bulwark = Bulwark<int>(failureThreshold: 5);

    const calls = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      await bulwark.call(() async => i);
    }
    sw.stop();

    final perCall = (sw.elapsedMicroseconds / calls).toStringAsFixed(2);
    print(
      '│  Success path ($calls): '
      '${_ms(sw)}  ($perCall µs/call)',
    );

    bulwark.dispose();
  }

  // b) Trip → open → BulwarkOpenException path
  {
    final bulwark = Bulwark<int>(
      failureThreshold: 3,
      resetTimeout: const Duration(hours: 1),
    );

    // Trip it
    for (var i = 0; i < 3; i++) {
      try {
        await bulwark.call(() async => throw StateError('fail'));
      } catch (_) {}
    }
    assert(bulwark.isOpen);

    const calls = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      try {
        await bulwark.call(() async => i);
      } on BulwarkOpenException catch (_) {
        // expected
      }
    }
    sw.stop();

    final perCall = (sw.elapsedMicroseconds / calls).toStringAsFixed(2);
    print(
      '│  Open circuit fast-fail ($calls): '
      '${_ms(sw)}  ($perCall µs/rejection)',
    );

    bulwark.dispose();
  }

  // c) Lifecycle: create + call + reset + dispose
  {
    const cycles = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final b = Bulwark<int>(failureThreshold: 3);
      await b.call(() async => i);
      b.reset();
      b.dispose();
    }
    sw.stop();

    final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
    print(
      '│  Lifecycle ($cycles): '
      '${_ms(sw)}  ($perCycle µs/cycle)',
    );
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 19. Saga — Multi-Step Workflow
// ---------------------------------------------------------------------------

Future<void> _benchSaga() async {
  print('┌─ 19. Saga (Multi-Step Workflow) ─────────────────────');

  // a) Successful workflow throughput
  {
    for (final stepCount in [3, 10, 50]) {
      final steps = List.generate(
        stepCount,
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

      final perRun = (sw.elapsedMicroseconds / runs).toStringAsFixed(1);
      print(
        '│  Success ($stepCount steps × $runs): '
        '${_ms(sw)}  ($perRun µs/run)',
      );
    }
  }

  // b) Workflow with compensation (failure at midpoint)
  {
    const stepCount = 10;
    var compensationCount = 0;
    final steps = List.generate(
      stepCount,
      (i) => SagaStep<int>(
        name: 'step$i',
        execute: (prev) async {
          if (i == stepCount ~/ 2) throw StateError('fail at step $i');
          return (prev ?? 0) + 1;
        },
        compensate: (_) async => compensationCount++,
      ),
    );

    const runs = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      compensationCount = 0;
      final saga = Saga<int>(steps: steps);
      try {
        await saga.run();
      } catch (_) {}
      saga.dispose();
    }
    sw.stop();

    final perRun = (sw.elapsedMicroseconds / runs).toStringAsFixed(1);
    print(
      '│  Compensation ($stepCount steps, fail@mid × $runs): '
      '${_ms(sw)}  ($perRun µs/run)',
    );
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 20. Volley — Batch Async
// ---------------------------------------------------------------------------

Future<void> _benchVolley() async {
  print('┌─ 20. Volley (Batch Async) ───────────────────────────');

  // a) Parallel execution throughput
  {
    for (final taskCount in [10, 100, 1000]) {
      final tasks = List.generate(
        taskCount,
        (i) => VolleyTask<int>(name: 'task$i', execute: () async => i),
      );

      final volley = Volley<int>(concurrency: 10);
      final sw = Stopwatch()..start();
      final results = await volley.execute(tasks);
      sw.stop();

      final successCount = results.where((r) => r.isSuccess).length;
      final perTask = (sw.elapsedMicroseconds / taskCount).toStringAsFixed(1);
      print(
        '│  ${_pad(taskCount)} tasks (conc=10): '
        '${_ms(sw)}  ($perTask µs/task, $successCount succeeded)',
      );

      volley.dispose();
    }
  }

  // b) Lifecycle: create + execute + dispose
  {
    const cycles = 100;
    final tasks = List.generate(
      10,
      (i) => VolleyTask<int>(name: 'task$i', execute: () async => i),
    );

    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final v = Volley<int>(concurrency: 5);
      await v.execute(tasks);
      v.dispose();
    }
    sw.stop();

    final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(1);
    print(
      '│  Lifecycle ($cycles × 10 tasks): '
      '${_ms(sw)}  ($perCycle µs/cycle)',
    );
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 21. Annals — Audit Trail
// ---------------------------------------------------------------------------

Future<void> _benchAnnals() async {
  print('┌─ 21. Annals (Audit Trail) ───────────────────────────');

  // a) Record throughput
  {
    Annals.reset();
    Annals.enable(maxEntries: 100000);

    const records = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < records; i++) {
      Annals.record(
        AnnalEntry(
          coreName: 'count',
          pillarType: 'CounterPillar',
          oldValue: i,
          newValue: i + 1,
          action: 'increment',
        ),
      );
    }
    sw.stop();

    final throughput = (records / sw.elapsedMicroseconds * 1e6).toStringAsFixed(
      0,
    );
    print(
      '│  Record ($records): '
      '${_ms(sw)}  ($throughput records/sec)',
    );
  }

  // b) Query performance
  {
    const queries = 1000;

    // Query by coreName
    final swName = Stopwatch()..start();
    for (var i = 0; i < queries; i++) {
      Annals.query(coreName: 'count', limit: 10);
    }
    swName.stop();

    // Query by pillarType
    final swType = Stopwatch()..start();
    for (var i = 0; i < queries; i++) {
      Annals.query(pillarType: 'CounterPillar', limit: 10);
    }
    swType.stop();

    final perNameQuery = (swName.elapsedMicroseconds / queries).toStringAsFixed(
      1,
    );
    final perTypeQuery = (swType.elapsedMicroseconds / queries).toStringAsFixed(
      1,
    );
    print(
      '│  Query ($queries, 100K entries): '
      'byName ${_ms(swName)} ($perNameQuery µs/q), '
      'byType ${_ms(swType)} ($perTypeQuery µs/q)',
    );
  }

  // c) Export performance
  {
    const exports = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < exports; i++) {
      Annals.export();
    }
    sw.stop();

    final perExport = (sw.elapsedMicroseconds / exports).toStringAsFixed(1);
    print(
      '│  Export ($exports, 100K entries): '
      '${_ms(sw)}  ($perExport µs/export)',
    );
  }

  // d) History trimming (capped at 1000 with overflow)
  {
    Annals.reset();
    Annals.enable(maxEntries: 1000);

    const records = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < records; i++) {
      Annals.record(
        AnnalEntry(coreName: 'trimmed', oldValue: i, newValue: i + 1),
      );
    }
    sw.stop();

    final perRecord = (sw.elapsedMicroseconds / records).toStringAsFixed(2);
    print(
      '│  Capped recording ($records, cap=1000): '
      '${_ms(sw)}  ($perRecord µs/record, ${Annals.length} stored)',
    );
  }

  Annals.reset();
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 22. Tether — Request-Response Channels
// ---------------------------------------------------------------------------

Future<void> _benchTether() async {
  print('┌─ 22. Tether (Request-Response) ─────────────────────');

  // a) Registration throughput
  {
    Tether.reset();

    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Tether.register<int, int>('handler_$i', (req) async => req * 2);
    }
    sw.stop();

    final perReg = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
    print(
      '│  Register ($count): '
      '${_ms(sw)}  ($perReg µs/register)',
    );

    Tether.reset();
  }

  // b) Call throughput
  {
    Tether.reset();
    Tether.register<int, int>('multiply', (req) async => req * 2);

    const calls = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      await Tether.call<int, int>('multiply', i);
    }
    sw.stop();

    final perCall = (sw.elapsedMicroseconds / calls).toStringAsFixed(2);
    print(
      '│  call() ($calls): '
      '${_ms(sw)}  ($perCall µs/call)',
    );
  }

  // c) tryCall() with miss
  {
    const calls = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      await Tether.tryCall<int, int>('nonexistent', i);
    }
    sw.stop();

    final perCall = (sw.elapsedMicroseconds / calls).toStringAsFixed(2);
    print(
      '│  tryCall() miss ($calls): '
      '${_ms(sw)}  ($perCall µs/miss)',
    );
  }

  // d) has() lookup throughput
  {
    const lookups = 1000000;
    final swHit = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Tether.has('multiply');
    }
    swHit.stop();

    final swMiss = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Tether.has('nonexistent');
    }
    swMiss.stop();

    final perHit = (swHit.elapsedMicroseconds / lookups * 1000).toStringAsFixed(
      1,
    );
    final perMiss = (swMiss.elapsedMicroseconds / lookups * 1000)
        .toStringAsFixed(1);
    print(
      '│  has() ($lookups): '
      'hit ${_ms(swHit)} ($perHit ns), '
      'miss ${_ms(swMiss)} ($perMiss ns)',
    );
  }

  Tether.reset();
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 23. Aegis — Retry with Backoff
// ---------------------------------------------------------------------------

Future<void> _benchAegis() async {
  print('┌─ 23. Aegis (Retry with Backoff) ────────────────────');

  // a) Success on first attempt (no retry needed)
  {
    const calls = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      await Aegis.run(() async => i, maxAttempts: 3, baseDelay: Duration.zero);
    }
    sw.stop();

    final perCall = (sw.elapsedMicroseconds / calls).toStringAsFixed(2);
    print(
      '│  Success-first ($calls): '
      '${_ms(sw)}  ($perCall µs/call)',
    );
  }

  // b) Retry overhead (fail then succeed, zero delay)
  {
    const calls = 500;
    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      var attempt = 0;
      await Aegis.run(
        () async {
          attempt++;
          if (attempt < 3) throw StateError('retry');
          return i;
        },
        maxAttempts: 5,
        baseDelay: Duration.zero,
      );
    }
    sw.stop();

    final perCall = (sw.elapsedMicroseconds / calls).toStringAsFixed(2);
    print(
      '│  Retry (fail×2 + succeed, $calls): '
      '${_ms(sw)}  ($perCall µs/call)',
    );
  }

  // c) runWithConfig overhead
  {
    const calls = 1000;
    final config = AegisConfig(
      maxAttempts: 3,
      baseDelay: Duration.zero,
      jitter: false,
    );

    final sw = Stopwatch()..start();
    for (var i = 0; i < calls; i++) {
      await Aegis.runWithConfig(() async => i, config: config);
    }
    sw.stop();

    final perCall = (sw.elapsedMicroseconds / calls).toStringAsFixed(2);
    print(
      '│  runWithConfig ($calls): '
      '${_ms(sw)}  ($perCall µs/call)',
    );
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 24. Sigil — Feature Flags
// ---------------------------------------------------------------------------

Future<void> _benchSigil() async {
  print('┌─ 24. Sigil (Feature Flags) ─────────────────────────');

  // a) Registration throughput
  {
    Sigil.reset();

    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Sigil.register('flag_$i', i.isEven);
    }
    sw.stop();

    final perReg = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
    print(
      '│  Register ($count): '
      '${_ms(sw)}  ($perReg µs/register)',
    );
  }

  // b) isEnabled lookup throughput
  {
    const lookups = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Sigil.isEnabled('flag_0');
    }
    sw.stop();

    final perLookup = (sw.elapsedMicroseconds / lookups * 1000).toStringAsFixed(
      1,
    );
    print(
      '│  isEnabled ($lookups): '
      '${_ms(sw)}  ($perLookup ns/lookup)',
    );
  }

  // c) Toggle throughput
  {
    const toggles = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < toggles; i++) {
      Sigil.toggle('flag_0');
    }
    sw.stop();

    final perToggle = (sw.elapsedMicroseconds / toggles).toStringAsFixed(2);
    print(
      '│  Toggle ($toggles): '
      '${_ms(sw)}  ($perToggle µs/toggle)',
    );
  }

  // d) loadAll throughput
  {
    Sigil.reset();

    const batches = 1000;
    final flags = {for (var i = 0; i < 100; i++) 'batch_$i': i.isEven};

    final sw = Stopwatch()..start();
    for (var i = 0; i < batches; i++) {
      Sigil.loadAll(flags);
    }
    sw.stop();

    final perBatch = (sw.elapsedMicroseconds / batches).toStringAsFixed(1);
    print(
      '│  loadAll ($batches × 100 flags): '
      '${_ms(sw)}  ($perBatch µs/batch)',
    );
  }

  // e) Override / peek (non-reactive) throughput
  {
    Sigil.reset();
    Sigil.register('peekable', true);

    const peeks = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < peeks; i++) {
      Sigil.peek('peekable');
    }
    sw.stop();

    final perPeek = (sw.elapsedMicroseconds / peeks * 1000).toStringAsFixed(1);
    print(
      '│  peek() ($peeks): '
      '${_ms(sw)}  ($perPeek ns/peek)',
    );
  }

  Sigil.reset();
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 25. Core Extensions — toggle, increment, list ops, map ops, select
// ---------------------------------------------------------------------------

Future<void> _benchCoreExtensions() async {
  print('┌─ 25. Core Extensions ────────────────────────────────');

  // a) Bool toggle
  {
    final flag = TitanState(false);
    const ops = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      flag.toggle();
    }
    sw.stop();

    final perOp = (sw.elapsedMicroseconds / ops).toStringAsFixed(2);
    print('│  Bool.toggle ($ops): ${_ms(sw)}  ($perOp µs/toggle)');

    flag.dispose();
  }

  // b) Int increment
  {
    final count = TitanState(0);
    const ops = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      count.increment();
    }
    sw.stop();

    final perOp = (sw.elapsedMicroseconds / ops).toStringAsFixed(2);
    print('│  Int.increment ($ops): ${_ms(sw)}  ($perOp µs/op)');

    count.dispose();
  }

  // c) List.add
  {
    final items = TitanState<List<int>>([]);
    const ops = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      items.add(i);
    }
    sw.stop();

    final perOp = (sw.elapsedMicroseconds / ops).toStringAsFixed(2);
    print('│  List.add ($ops): ${_ms(sw)}  ($perOp µs/add)');

    items.dispose();
  }

  // d) Map.set
  {
    final map = TitanState<Map<String, int>>({});
    const ops = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      map.set('key_$i', i);
    }
    sw.stop();

    final perOp = (sw.elapsedMicroseconds / ops).toStringAsFixed(2);
    print('│  Map.set ($ops): ${_ms(sw)}  ($perOp µs/set)');

    map.dispose();
  }

  // e) Core.select overhead vs raw computed
  {
    final user = TitanState<Map<String, dynamic>>({'name': 'Kael', 'level': 1});

    // select (creates a TitanComputed internally)
    final selected = user.select((u) => u['name'] as String);

    // Raw Derived for comparison
    final rawDerived = TitanComputed(() => user.value['name'] as String);

    // Force initial computation
    selected.value;
    rawDerived.value;

    const mutations = 10000;

    final swSelect = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      user.value = {'name': 'Kael_$i', 'level': i};
      selected.value;
    }
    swSelect.stop();

    final swRaw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      user.value = {'name': 'Raw_$i', 'level': i};
      rawDerived.value;
    }
    swRaw.stop();

    print(
      '│  Core.select vs Derived ($mutations): '
      '${_ms(swSelect)} select, ${_ms(swRaw)} raw',
    );

    selected.dispose();
    rawDerived.dispose();
    user.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 26. Snapshot — State Capture & Restore
// ---------------------------------------------------------------------------

Future<void> _benchSnapshot() async {
  print('┌─ 26. Snapshot (Capture & Restore) ───────────────────');

  // a) Capture throughput
  {
    for (final nodeCount in [10, 100, 1000]) {
      final nodes = List.generate(
        nodeCount,
        (i) => TitanState(i, name: 'node_$i'),
      );

      const captures = 1000;
      final sw = Stopwatch()..start();
      for (var i = 0; i < captures; i++) {
        Snapshot.captureFromNodes(nodes);
      }
      sw.stop();

      final perCapture = (sw.elapsedMicroseconds / captures).toStringAsFixed(1);
      print(
        '│  Capture ${_pad(nodeCount)} nodes ($captures): '
        '${_ms(sw)}  ($perCapture µs/capture)',
      );

      for (final n in nodes) {
        n.dispose();
      }
    }
  }

  // b) Restore throughput
  {
    final nodes = List.generate(100, (i) => TitanState(i, name: 'node_$i'));
    final snapshot = Snapshot.captureFromNodes(nodes);

    // Change values
    for (final n in nodes) {
      n.value = 999;
    }

    const restores = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < restores; i++) {
      Snapshot.restoreToNodes(nodes, snapshot);
    }
    sw.stop();

    final perRestore = (sw.elapsedMicroseconds / restores).toStringAsFixed(1);
    print(
      '│  Restore 100 nodes ($restores): '
      '${_ms(sw)}  ($perRestore µs/restore)',
    );

    for (final n in nodes) {
      n.dispose();
    }
  }

  // c) Diff throughput
  {
    final nodesA = List.generate(100, (i) => TitanState(i, name: 'node_$i'));
    final snapA = Snapshot.captureFromNodes(nodesA);

    // Change half
    for (var i = 0; i < 50; i++) {
      nodesA[i].value = 999;
    }
    final snapB = Snapshot.captureFromNodes(nodesA);

    const diffs = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < diffs; i++) {
      Snapshot.diff(snapA, snapB);
    }
    sw.stop();

    final perDiff = (sw.elapsedMicroseconds / diffs).toStringAsFixed(2);
    print(
      '│  Diff 100 nodes ($diffs): '
      '${_ms(sw)}  ($perDiff µs/diff)',
    );

    for (final n in nodesA) {
      n.dispose();
    }
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 27. Crucible — Testing Harness
// ---------------------------------------------------------------------------

Future<void> _benchCrucible() async {
  print('┌─ 27. Crucible (Testing Harness) ─────────────────────');

  // a) Crucible creation + dispose lifecycle
  {
    const cycles = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < cycles; i++) {
      final crucible = Crucible(() => _BenchPillar());
      crucible.dispose();
    }
    sw.stop();

    final perCycle = (sw.elapsedMicroseconds / cycles).toStringAsFixed(2);
    print(
      '│  Lifecycle ($cycles): '
      '${_ms(sw)}  ($perCycle µs/cycle)',
    );

    Titan.reset();
    Herald.reset();
  }

  // b) Track + change recording throughput
  {
    final crucible = Crucible(() => _BenchPillar());
    crucible.track(crucible.pillar.count);

    const mutations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < mutations; i++) {
      crucible.pillar.count.value = i;
    }
    sw.stop();

    final changeCount = crucible.changesFor(crucible.pillar.count).length;
    final perMutation = (sw.elapsedMicroseconds / mutations).toStringAsFixed(2);
    print(
      '│  Track ($mutations mutations): '
      '${_ms(sw)}  ($perMutation µs/mutation, '
      '$changeCount changes recorded)',
    );

    crucible.dispose();
    Titan.reset();
    Herald.reset();
  }

  // c) expectCore throughput
  {
    final crucible = Crucible(() => _BenchPillar());

    const checks = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < checks; i++) {
      crucible.expectCore(crucible.pillar.count, 0);
    }
    sw.stop();

    final perCheck = (sw.elapsedMicroseconds / checks).toStringAsFixed(2);
    print(
      '│  expectCore ($checks): '
      '${_ms(sw)}  ($perCheck µs/check)',
    );

    crucible.dispose();
    Titan.reset();
    Herald.reset();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// =============================================================================
// Helpers
// =============================================================================
// 28. Conduit — Core-level middleware pipeline
// =============================================================================

Future<void> _benchConduit() async {
  print('── 28. Conduit ──────────────────────────────────────');

  // 28a. Core with single ClampConduit — 10K value sets
  {
    final sw = Stopwatch()..start();
    const n = 10000;
    final state = TitanState<int>(
      50,
      conduits: [ClampConduit(min: 0, max: 100)],
    );
    for (var i = 0; i < n; i++) {
      state.value = i % 200 - 50; // Range -50..149
    }
    sw.stop();
    print('  Clamp 10K sets:      ${_ms(sw)}  (${_pad(n)} iterations)');
  }

  // 28b. Core with 3-conduit chain — 10K sets
  {
    final sw = Stopwatch()..start();
    const n = 10000;
    final state = TitanState<String>(
      '',
      conduits: [
        TransformConduit((_, v) => v.trim()),
        TransformConduit((_, v) => v.toLowerCase()),
        ValidateConduit((_, v) => v.length > 100 ? 'too long' : null),
      ],
    );
    for (var i = 0; i < n; i++) {
      state.value = '  Hello $i  ';
    }
    sw.stop();
    print('  3-chain 10K sets:    ${_ms(sw)}  (${_pad(n)} iterations)');
  }

  // 28c. Rejected changes (FreezeConduit) — 10K rejections
  {
    final sw = Stopwatch()..start();
    const n = 10000;
    final state = TitanState<int>(
      100,
      conduits: [
        FreezeConduit((_, _) => true), // Always frozen
      ],
    );
    for (var i = 0; i < n; i++) {
      try {
        state.value = i;
      } on ConduitRejectedException {
        // Expected
      }
    }
    sw.stop();
    print('  Reject 10K sets:     ${_ms(sw)}  (${_pad(n)} iterations)');
  }

  // 28d. addConduit / removeConduit churn — 10K add+remove cycles
  {
    final sw = Stopwatch()..start();
    const n = 10000;
    final state = TitanState<int>(0);
    final conduit = ClampConduit<int>(min: 0, max: 10);
    for (var i = 0; i < n; i++) {
      state.addConduit(conduit);
      state.removeConduit(conduit);
    }
    sw.stop();
    print('  Add/remove 10K:      ${_ms(sw)}  (${_pad(n)} iterations)');
  }

  // 28e. No-conduit baseline — 10K sets for comparison
  {
    final sw = Stopwatch()..start();
    const n = 10000;
    final state = TitanState<int>(0);
    for (var i = 0; i < n; i++) {
      state.value = i;
    }
    sw.stop();
    print('  No-conduit 10K:      ${_ms(sw)}  (${_pad(n)} iterations)');
  }

  print('');
}

// =============================================================================
// 29. Prism — Fine-grained state projections
// =============================================================================

Future<void> _benchPrism() async {
  print('── 29. Prism ───────────────────────────────────────');

  // 29a. Single-source Prism — 10K reads after source changes
  {
    final source = TitanState<Map<String, int>>({'a': 0, 'b': 0});
    final prism = Prism.of(source, (m) => m['a'] ?? 0);
    prism.value; // prime

    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      source.value = {'a': i, 'b': i * 2};
      prism.value;
    }
    sw.stop();
    print('  Single Prism 10K:    ${_ms(sw)}  (${_pad(n)} iterations)');
    source.dispose();
  }

  // 29b. combine2 Prism — 10K mutations
  {
    final a = TitanState(0);
    final b = TitanState(0);
    final combined = Prism.combine2(a, b, (x, y) => x + y);
    combined.value;

    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      a.value = i;
      combined.value;
    }
    sw.stop();
    print('  Combine2 10K:        ${_ms(sw)}  (${_pad(n)} iterations)');
    a.dispose();
    b.dispose();
  }

  // 29c. Multiple Prisms on same source — 10K mutations
  {
    final source = TitanState<Map<String, int>>({'hp': 100, 'mp': 50, 'xp': 0});
    final hp = Prism.of(source, (m) => m['hp'] ?? 0);
    final mp = Prism.of(source, (m) => m['mp'] ?? 0);
    final xp = Prism.of(source, (m) => m['xp'] ?? 0);
    hp.value;
    mp.value;
    xp.value;

    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      source.value = {'hp': 100 - i % 10, 'mp': 50, 'xp': i};
      hp.value;
      mp.value;
      xp.value;
    }
    sw.stop();
    print('  3 Prisms 10K:        ${_ms(sw)}  (${_pad(n)} iterations)');
    source.dispose();
  }

  // 29d. Prism vs Derived baseline — 10K (same operation for comparison)
  {
    final source = TitanState(0);
    final derived = TitanComputed(() => source.value * 2);
    derived.value;

    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      source.value = i;
      derived.value;
    }
    sw.stop();
    print('  Derived baseline:    ${_ms(sw)}  (${_pad(n)} iterations)');
    source.dispose();
  }

  // 29e. Prism with PrismEquals.list — 10K with structural equality
  {
    final source = TitanState<List<int>>([1, 2, 3]);
    final prism = Prism.of<List<int>, List<int>>(
      source,
      (list) => list.where((x) => x.isEven).toList(),
      equals: PrismEquals.list,
    );
    prism.value;

    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      source.value = [i, i + 1, i + 2, i + 3];
      prism.value;
    }
    sw.stop();
    print('  List equality 10K:   ${_ms(sw)}  (${_pad(n)} iterations)');
    source.dispose();
  }

  print('');
}

// =============================================================================
// 30. Nexus — Reactive Collections
// =============================================================================

Future<void> _benchNexus() async {
  print('── 30. Nexus ───────────────────────────────────────');

  // 30a. NexusList add — 10K elements
  {
    final list = NexusList<int>();
    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      list.add(i);
    }
    sw.stop();
    print('  List add 10K:        ${_ms(sw)}  (${_pad(n)} iterations)');
    list.dispose();
  }

  // 30b. NexusList vs Core<List> add — 10K (copy-on-write baseline)
  {
    final core = TitanState<List<int>>([]);
    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      core.value = [...core.peek(), i];
    }
    sw.stop();
    print('  Core<List> add 10K:  ${_ms(sw)}  (${_pad(n)} copy-on-write)');
    core.dispose();
  }

  // 30c. NexusList removeAt — 10K removals
  {
    final list = NexusList<int>(initial: List.generate(10000, (i) => i));
    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      list.removeAt(0);
    }
    sw.stop();
    print('  List removeAt 10K:   ${_ms(sw)}  (${_pad(n)} iterations)');
    list.dispose();
  }

  // 30d. NexusList operator []= — 10K updates
  {
    final list = NexusList<int>(initial: List.generate(10000, (i) => i));
    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      list[i] = i * 2;
    }
    sw.stop();
    print('  List update 10K:     ${_ms(sw)}  (${_pad(n)} iterations)');
    list.dispose();
  }

  // 30e. NexusMap set — 10K entries
  {
    final map = NexusMap<int, int>();
    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      map[i] = i;
    }
    sw.stop();
    print('  Map set 10K:         ${_ms(sw)}  (${_pad(n)} iterations)');
    map.dispose();
  }

  // 30f. NexusMap remove — 10K removals
  {
    final map = NexusMap<int, int>(
      initial: {for (var i = 0; i < 10000; i++) i: i},
    );
    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      map.remove(i);
    }
    sw.stop();
    print('  Map remove 10K:      ${_ms(sw)}  (${_pad(n)} iterations)');
    map.dispose();
  }

  // 30g. NexusSet add — 10K elements
  {
    final set = NexusSet<int>();
    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      set.add(i);
    }
    sw.stop();
    print('  Set add 10K:         ${_ms(sw)}  (${_pad(n)} iterations)');
    set.dispose();
  }

  // 30h. NexusList with Derived — 10K mutations with observer
  {
    final list = NexusList<int>();
    final sum = TitanComputed(() => list.value.fold(0, (a, b) => a + b));
    sum.value; // prime

    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      list.add(i);
      sum.value;
    }
    sw.stop();
    print('  List+Derived 10K:    ${_ms(sw)}  (${_pad(n)} iterations)');
    list.dispose();
  }

  print('');
}

// =============================================================================
// Helpers
// =============================================================================

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

String _ms(Stopwatch sw) {
  if (sw.elapsedMilliseconds < 1) {
    return '${sw.elapsedMicroseconds} µs'.padLeft(10);
  }
  return '${sw.elapsedMilliseconds} ms'.padLeft(10);
}

String _pad(int n) => n.toString().padLeft(6);
