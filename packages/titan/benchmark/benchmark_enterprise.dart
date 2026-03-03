// ignore_for_file: avoid_print
import 'dart:async';

import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

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
//  31. Trove — Reactive TTL/LRU cache
//  32. Moat — Token-bucket rate limiter
//  33. Omen — Reactive async derived
//  34. Pyre — Priority task queue
//  35. Mandate — Reactive policy engine
//  36. Ledger — State transactions
//  37. Portcullis — Reactive circuit breaker
//  38. Anvil — Dead letter & retry queue
//  39. Banner — Reactive feature flags
//  40. Sieve — Reactive search/filter/sort
//  41. Lattice — Reactive DAG task executor
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
  await _benchRefreshPipeline();
  await _benchTrove();
  await _benchMoat();
  await _benchOmen();
  await _benchPyre();
  await _benchMandate();
  await _benchLedger();
  await _benchPortcullis();
  await _benchAnvil();
  await _benchBanner();
  await _benchSieve();
  await _benchLattice();
  await _benchEmbargo();
  await _benchCensus();
  await _benchWarden();
  await _benchArbiter();
  await _benchLode();
  _benchTithe();
  await _benchSluice();
  await _benchClarion();
  _benchTapestry();

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

// ---------------------------------------------------------------------------
// 31. Refresh Pipeline — simulates CoreRefresh hot path
// ---------------------------------------------------------------------------
// Benchmarks the pure-Dart components that power Atlas's refreshListenable:
//   A) Reactive listener → callback chain (Core change → notification)
//   B) Guard pipeline evaluation (Sentinel-like closures)
//   C) URI parsing overhead (path + query extraction)
//   D) Full simulated refresh cycle

Future<void> _benchRefreshPipeline() async {
  print('┌─ 31. Refresh Pipeline ────────────────────────────────');

  // A) Reactive listener → callback chain
  // Simulates: Core.value = x → listener fires → callback invoked
  {
    final state = TitanState(false);
    var callbackCount = 0;
    void onNotify() => callbackCount++;
    state.addListener(onNotify);

    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      state.value = i.isEven; // toggle to ensure notification
    }
    sw.stop();

    final perOp = sw.elapsedMicroseconds / iterations;
    print(
      '│  Listener chain (${_pad(iterations)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/notify)',
    );

    state.removeListener(onNotify);
    state.dispose();
  }

  // B) Guard pipeline evaluation
  // Simulates: authGuard + guestOnly Sentinel evaluation (closure calls)
  {
    var isAuthenticated = false;
    final publicPaths = {'/login', '/register', '/about'};
    final guestPaths = {'/login', '/register'};

    // Simulated authGuard closure
    String? authGuard(String path) {
      if (publicPaths.contains(path)) return null;
      if (isAuthenticated) return null;
      return '/login?redirect=${Uri.encodeComponent(path)}';
    }

    // Simulated guestOnly closure
    String? guestOnly(String path, Map<String, String> query) {
      if (!guestPaths.contains(path)) return null;
      if (!isAuthenticated) return null;
      final redirect = query['redirect'];
      if (redirect != null && redirect.isNotEmpty) return redirect;
      return '/';
    }

    const iterations = 100000;
    final paths = ['/dashboard', '/login', '/quest/42', '/about', '/profile'];

    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      isAuthenticated = i.isEven;
      final path = paths[i % paths.length];
      final result = authGuard(path);
      if (result == null) {
        guestOnly(path, const {});
      }
    }
    sw.stop();

    final perOp = sw.elapsedMicroseconds / iterations;
    print(
      '│  Guard pipeline (${_pad(iterations)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/eval)',
    );
  }

  // C) URI parsing overhead
  // Simulates: _resolve parses path with query params
  {
    const iterations = 50000;
    final uris = [
      '/login?redirect=%2Fquest%2F42',
      '/dashboard',
      '/quest/42?tab=details&page=1',
      '/login',
      '/quest/42/comments?sort=newest',
    ];

    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final raw = uris[i % uris.length];
      final uri = Uri.parse(raw);
      // Force evaluation of path and queryParameters
      uri.path;
      uri.queryParameters;
    }
    sw.stop();

    final perOp = sw.elapsedMicroseconds / iterations;
    print(
      '│  URI parsing   (${_pad(iterations)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/parse)',
    );
  }

  // D) Full simulated refresh cycle
  // Core change → listener → guard pipeline → URI parse → comparison
  {
    final state = TitanState(false);
    var isAuthenticated = false;
    final publicPaths = <String>{'/login', '/register'};
    final guestPaths = <String>{'/login', '/register'};
    var isRefreshing = false;

    void simulateRefresh() {
      if (isRefreshing) return;
      isRefreshing = true;
      isAuthenticated = state.peek();

      // Simulate _onRefresh: parse current URI
      final currentUri = Uri.parse('/login?redirect=%2Fquest%2F42');
      final currentPath = currentUri.path;
      final query = currentUri.queryParameters;

      // authGuard evaluation
      String? result;
      if (!publicPaths.contains(currentPath) && !isAuthenticated) {
        result = '/login';
      }

      // guestOnly evaluation
      if (result == null &&
          guestPaths.contains(currentPath) &&
          isAuthenticated) {
        final redirect = query['redirect'];
        result = (redirect != null && redirect.isNotEmpty) ? redirect : '/';
      }

      // Path comparison
      final resolvedPath = result ?? currentPath;
      if (resolvedPath != currentPath) {
        // Would navigate (no-op in benchmark)
      }
      isRefreshing = false;
    }

    state.addListener(simulateRefresh);

    const iterations = 50000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      state.value = i.isEven;
    }
    sw.stop();

    final perOp = sw.elapsedMicroseconds / iterations;
    print(
      '│  Full cycle    (${_pad(iterations)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/refresh)',
    );

    state.removeListener(simulateRefresh);
    state.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 31. Trove — Reactive TTL/LRU In-Memory Cache
// ---------------------------------------------------------------------------

Future<void> _benchTrove() async {
  print('┌─ 31. Trove (TTL/LRU Cache) ────────────────────────');

  // a) Put throughput
  {
    for (final count in [1000, 10000, 100000]) {
      final cache = Trove<int, int>(name: 'bench-put');
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        cache.put(i, i);
      }
      sw.stop();
      final perOp = sw.elapsedMicroseconds / count;
      print(
        '│  Put           (${_pad(count)}):  ${_ms(sw)}'
        '  (${perOp.toStringAsFixed(3)} µs/op)',
      );
      cache.dispose();
    }
  }

  // b) Get throughput (hits)
  {
    const count = 100000;
    final cache = Trove<int, int>(name: 'bench-get');
    for (var i = 0; i < count; i++) {
      cache.put(i, i);
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      cache.get(i);
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Get (hits)    (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    print('│  Hit rate: ${cache.hitRate.toStringAsFixed(1)}%');
    cache.dispose();
  }

  // c) Get throughput (misses)
  {
    const count = 100000;
    final cache = Trove<int, int>(name: 'bench-miss');
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      cache.get(i);
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Get (misses)  (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    cache.dispose();
  }

  // d) LRU eviction overhead
  {
    const maxEntries = 1000;
    const insertions = 10000;
    final cache = Trove<int, int>(maxEntries: maxEntries, name: 'bench-lru');
    final sw = Stopwatch()..start();
    for (var i = 0; i < insertions; i++) {
      cache.put(i, i);
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / insertions;
    print(
      '│  LRU eviction  (${_pad(insertions)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op, cap=$maxEntries)',
    );
    print('│  Evictions: ${cache.evictions.value}');
    cache.dispose();
  }

  // e) putIfAbsent pattern (sync)
  {
    const count = 100000;
    final cache = Trove<int, int>(name: 'bench-putIfAbsent');
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      cache.putIfAbsent(i % 1000, () => i);
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  putIfAbsent   (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    cache.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 32. Moat — Rate Limiter
// ---------------------------------------------------------------------------

Future<void> _benchMoat() async {
  print('┌─ 32. Moat (Rate Limiter) ──────────────────────────');

  // a) tryConsume throughput (with tokens available)
  {
    const count = 100000;
    final limiter = Moat(
      maxTokens: count,
      refillRate: const Duration(seconds: 60),
      name: 'bench-consume',
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      limiter.tryConsume();
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  tryConsume    (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    limiter.dispose();
  }

  // b) tryConsume throughput (rejected — empty bucket)
  {
    const count = 100000;
    final limiter = Moat(
      maxTokens: 1,
      refillRate: const Duration(seconds: 60),
      initialTokens: 0,
      name: 'bench-reject',
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      limiter.tryConsume();
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  tryConsume rej(${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    limiter.dispose();
  }

  // c) MoatPool per-key creation + consume
  {
    const keys = 1000;
    final pool = MoatPool(
      maxTokens: 10,
      refillRate: const Duration(seconds: 60),
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < keys; i++) {
      pool.tryConsume('key_$i');
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / keys;
    print(
      '│  Pool create   (${_pad(keys)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/key)',
    );
    pool.dispose();
  }

  // d) MoatPool existing key lookup
  {
    const count = 100000;
    final pool = MoatPool(
      maxTokens: count,
      refillRate: const Duration(seconds: 60),
    );
    // Pre-create 100 keys
    for (var i = 0; i < 100; i++) {
      pool.tryConsume('key_$i');
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      pool.tryConsume('key_${i % 100}');
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Pool lookup   (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    pool.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 33. Omen — Reactive Async Derived
// ---------------------------------------------------------------------------

Future<void> _benchOmen() async {
  print('┌─ 33. Omen (Reactive Async Derived) ─────────────────');

  // a) Omen creation + eager execution overhead
  {
    const count = 10000;
    final sw = Stopwatch()..start();
    final omens = <Omen<int>>[];
    for (var i = 0; i < count; i++) {
      omens.add(Omen<int>(() async => i, name: 'bench-$i'));
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Create eager  (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    for (final o in omens) {
      o.dispose();
    }
  }

  // b) Omen creation with lazy (no eager execution)
  {
    const count = 10000;
    final sw = Stopwatch()..start();
    final omens = <Omen<int>>[];
    for (var i = 0; i < count; i++) {
      omens.add(Omen<int>(() async => i, eager: false, name: 'lazy-$i'));
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Create lazy   (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    for (final o in omens) {
      o.dispose();
    }
  }

  // c) Full resolution cycle: create → await → read data
  {
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final o = Omen<int>(() async => i);
      await Future<void>.delayed(Duration.zero);
      o.value; // trigger read
      o.dispose();
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Full cycle    (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
  }

  // d) Refresh throughput
  {
    const count = 5000;
    var counter = 0;
    final o = Omen<int>(() async => counter++);
    await Future<void>.delayed(Duration.zero); // first resolution
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      o.refresh();
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Refresh       (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    o.dispose();
  }

  // e) Cancel throughput
  {
    const count = 10000;
    final o = Omen<int>(() async => 1);
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      o.refresh();
      o.cancel();
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Refresh+cancel(${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    o.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 34. Pyre — Priority Task Queue
// ---------------------------------------------------------------------------

Future<void> _benchPyre() async {
  print('┌─ 34. Pyre (Priority Task Queue) ─────────────────────');

  // a) Enqueue throughput (autoStart: false)
  {
    const count = 10000;
    final q = Pyre<int>(concurrency: 5, autoStart: false, name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      q.enqueue(() async => i);
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Enqueue       (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    q.dispose();
  }

  // b) Priority-sorted enqueue
  {
    const count = 10000;
    final q = Pyre<int>(concurrency: 5, autoStart: false, name: 'prio-bench');
    final priorities = [
      PyrePriority.low,
      PyrePriority.normal,
      PyrePriority.high,
      PyrePriority.critical,
    ];
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      q.enqueue(() async => i, priority: priorities[i % 4]);
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Sorted enq   (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    q.dispose();
  }

  // c) Full execution cycle
  {
    const count = 1000;
    final q = Pyre<int>(concurrency: 10, name: 'exec-bench');
    final sw = Stopwatch()..start();
    final futures = <Future<int>>[];
    for (var i = 0; i < count; i++) {
      futures.add(q.enqueue(() async => i));
    }
    await Future.wait(futures);
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Execute      (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    q.dispose();
  }

  // d) Cancel throughput
  {
    const count = 10000;
    final q = Pyre<int>(concurrency: 1, autoStart: false, name: 'cancel-bench');
    for (var i = 0; i < count; i++) {
      q.enqueue(() async => i, id: 'task_$i');
    }
    final sw = Stopwatch()..start();
    q.cancelAll();
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  CancelAll    (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    q.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 35. Mandate — Reactive Policy Engine
// ---------------------------------------------------------------------------

Future<void> _benchMandate() async {
  print('┌─ 35. Mandate (Reactive Policy Engine) ───────────────');

  // a) Creation with N writs
  {
    const count = 10000;
    final role = TitanState<String>('user');
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final m = Mandate(
        writs: [
          Writ(name: 'auth', evaluate: () => role.value != ''),
          Writ(name: 'role', evaluate: () => role.value == 'admin'),
          Writ(name: 'flag', evaluate: () => true),
        ],
        name: 'bench_$i',
      );
      m.dispose();
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Create(3w)   (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
  }

  // b) Verdict evaluation (cached)
  {
    const count = 100000;
    final flag = TitanState<bool>(true);
    final m = Mandate(
      writs: [
        Writ(name: 'a', evaluate: () => flag.value),
        Writ(name: 'b', evaluate: () => true),
        Writ(name: 'c', evaluate: () => true),
      ],
    );
    // Prime
    m.verdict.value;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      m.verdict.value;
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Verdict(cch) (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    m.dispose();
  }

  // c) Reactive re-evaluation (toggle Core, read verdict)
  {
    const count = 10000;
    final flag = TitanState<bool>(true);
    final m = Mandate(
      writs: [
        Writ(name: 'flag', evaluate: () => flag.value),
        Writ(name: 'ok', evaluate: () => true),
      ],
    );
    m.verdict.value; // prime
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      flag.value = i.isEven;
      m.verdict.value;
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  Re-evaluate  (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    m.dispose();
  }

  // d) can() lookup
  {
    const count = 100000;
    final m = Mandate(
      writs: [
        Writ(name: 'auth', evaluate: () => true),
        Writ(name: 'role', evaluate: () => true),
        Writ(name: 'plan', evaluate: () => true),
      ],
    );
    m.can('auth').value; // prime
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      m.can('role').value;
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  can() lookup (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    m.dispose();
  }

  // e) addWrit throughput
  {
    const count = 10000;
    final m = Mandate();
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      m.addWrit(Writ(name: 'w_$i', evaluate: () => true));
    }
    sw.stop();
    final perOp = sw.elapsedMicroseconds / count;
    print(
      '│  addWrit      (${_pad(count)}):  ${_ms(sw)}'
      '  (${perOp.toStringAsFixed(3)} µs/op)',
    );
    m.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// =============================================================================
// 36. Ledger — State Transactions
// =============================================================================

Future<void> _benchLedger() async {
  print('┌─ 36. Ledger (State Transactions) ───────────────────');

  // --- Create ---
  {
    const n = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      Ledger(name: 'bench');
    }
    sw.stop();
    print(
      '│  Create        (${'$n'.padLeft(6)}): '
      '${_ms(sw)}  (${(sw.elapsedMicroseconds / n).toStringAsFixed(3)} µs/op)',
    );
  }

  // --- Begin/commit (no captures) ---
  {
    const n = 100000;
    final l = Ledger();
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      final tx = l.begin();
      tx.commit();
    }
    sw.stop();
    print(
      '│  Begin/Commit  (${'$n'.padLeft(6)}): '
      '${_ms(sw)}  (${(sw.elapsedMicroseconds / n).toStringAsFixed(3)} µs/op)',
    );
    l.dispose();
  }

  // --- Capture + commit (3 Cores) ---
  {
    const n = 10000;
    final l = Ledger();
    final a = TitanState(0);
    final b = TitanState(0);
    final c = TitanState(0);
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      final tx = l.begin();
      tx.capture(a);
      tx.capture(b);
      tx.capture(c);
      a.value = i;
      b.value = i;
      c.value = i;
      tx.commit();
    }
    sw.stop();
    print(
      '│  Capture+Cmit  (${'$n'.padLeft(6)}): '
      '${_ms(sw)}  (${(sw.elapsedMicroseconds / n).toStringAsFixed(3)} µs/op)',
    );
    l.dispose();
  }

  // --- Rollback (3 Cores) ---
  {
    const n = 10000;
    final l = Ledger();
    final a = TitanState(0);
    final b = TitanState(0);
    final c = TitanState(0);
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      final tx = l.begin();
      tx.capture(a);
      tx.capture(b);
      tx.capture(c);
      a.value = i + 100;
      b.value = i + 200;
      c.value = i + 300;
      tx.rollback();
    }
    sw.stop();
    print(
      '│  Rollback(3c)  (${'$n'.padLeft(6)}): '
      '${_ms(sw)}  (${(sw.elapsedMicroseconds / n).toStringAsFixed(3)} µs/op)',
    );
    l.dispose();
  }

  // --- transactSync ---
  {
    const n = 10000;
    final l = Ledger();
    final a = TitanState(0);
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      l.transactSync((tx) {
        tx.capture(a);
        a.value = i;
      });
    }
    sw.stop();
    print(
      '│  transactSync  (${'$n'.padLeft(6)}): '
      '${_ms(sw)}  (${(sw.elapsedMicroseconds / n).toStringAsFixed(3)} µs/op)',
    );
    l.dispose();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// =============================================================================
// Helpers (tail)
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

// ---------------------------------------------------------------------------
// 37. Portcullis — Reactive Circuit Breaker
// ---------------------------------------------------------------------------

Future<void> _benchPortcullis() async {
  const iter = 10000;

  // 37a. Create
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      final p = Portcullis(
        failureThreshold: 5,
        resetTimeout: const Duration(seconds: 30),
        name: 'bench',
      );
      p.dispose();
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '37. Portcullis  | Create                  '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // 37b. protect (success path)
  {
    final p = Portcullis(failureThreshold: 100);
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      await p.protect(() async => i);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '37. Portcullis  | Protect(success)         '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    p.dispose();
  }

  // 37c. protectSync (success path)
  {
    final p = Portcullis(failureThreshold: 100);
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      p.protectSync(() => i);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '37. Portcullis  | ProtectSync(success)     '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    p.dispose();
  }

  // 37d. Trip + reject (fast-fail)
  {
    final p = Portcullis(failureThreshold: 1);
    // Trip it once
    try {
      await p.protect(() async => throw Exception('trip'));
    } catch (_) {}

    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      try {
        await p.protect(() async => i);
      } on PortcullisOpenException catch (_) {}
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '37. Portcullis  | Reject(open)             '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    p.dispose();
  }

  // 37e. Failure path (not tripping)
  {
    final p = Portcullis(failureThreshold: iter + 1);
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      try {
        await p.protect(() async => throw Exception('fail'));
      } catch (_) {}
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '37. Portcullis  | Protect(failure)         '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    p.dispose();
  }

  print('');
}

// ---------------------------------------------------------------------------
// 38. Anvil — Dead Letter & Retry Queue
// ---------------------------------------------------------------------------

Future<void> _benchAnvil() async {
  const iter = 10000;

  // 38a. Create
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      final a = Anvil<String>(name: 'bench');
      a.dispose();
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '38. Anvil       | Create                  '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // 38b. Enqueue (autoStart: false — no async overhead)
  {
    final a = Anvil<String>(autoStart: false, name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      a.enqueue(() async => 'ok', id: 'job-$i');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '38. Anvil       | Enqueue(no-start)        '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    a.dispose();
  }

  // 38c. Enqueue + success (async processing)
  {
    final a = Anvil<String>(name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      a.enqueue(() async => 'ok', id: 'async-$i');
    }
    // Wait for all to complete
    while (a.succeededCount < iter) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '38. Anvil       | Enqueue+Success          '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    a.dispose();
  }

  // 38d. FindById lookup
  {
    final a = Anvil<String>(autoStart: false, name: 'bench');
    for (var i = 0; i < 1000; i++) {
      a.enqueue(() async => 'ok', id: 'lookup-$i');
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      a.findById('lookup-${i % 1000}');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '38. Anvil       | FindById(1k pool)        '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    a.dispose();
  }

  // 38e. Backoff delay computation
  {
    final backoff = AnvilBackoff.exponential(
      initial: const Duration(seconds: 1),
      multiplier: 2.0,
      jitter: true,
      maxDelay: const Duration(minutes: 5),
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      backoff.delayFor(i % 20);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '38. Anvil       | BackoffCompute           '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  print('');
}

// ---------------------------------------------------------------------------
// 39. Banner — Reactive Feature Flags
// ---------------------------------------------------------------------------

Future<void> _benchBanner() async {
  const iter = 100000;

  print('┌─ 39. Banner (Feature Flags) ─────────────────────────');

  // 39a. Flag lookup (isEnabled) — no rules, default value
  {
    final b = Banner(
      flags: [
        for (var i = 0; i < 100; i++)
          BannerFlag(name: 'flag-$i', defaultValue: i.isEven),
      ],
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      b.isEnabled('flag-${i % 100}');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '39. Banner      | DefaultLookup(100 flags) '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // 39b. Flag lookup with rules evaluation
  {
    final b = Banner(
      flags: [
        for (var i = 0; i < 100; i++)
          BannerFlag(
            name: 'rule-$i',
            rules: [
              BannerRule(
                name: 'tier-check',
                evaluate: (ctx) => ctx['tier'] == 'premium',
              ),
              BannerRule(
                name: 'region-check',
                evaluate: (ctx) => ctx['region'] == 'us',
              ),
            ],
          ),
      ],
    );
    final ctx = {'tier': 'free', 'region': 'eu'};
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      b.isEnabled('rule-${i % 100}', context: ctx);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '39. Banner      | RulesEval(2 rules)       '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // 39c. Rollout percentage evaluation (with userId hashing)
  {
    final b = Banner(
      flags: [const BannerFlag(name: 'rollout-test', rollout: 0.5)],
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      b.isEnabled('rollout-test', userId: 'user-${i % 1000}');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '39. Banner      | RolloutHash(50%)         '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // 39d. Override lookup (fastest path)
  {
    final b = Banner(
      flags: [for (var i = 0; i < 100; i++) BannerFlag(name: 'ovr-$i')],
    );
    for (var i = 0; i < 100; i++) {
      b.setOverride('ovr-$i', true);
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < iter; i++) {
      b.isEnabled('ovr-${i % 100}');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / iter;
    print(
      '39. Banner      | OverrideLookup(100)      '
      '| ${_pad(iter)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // 39e. Bulk flag creation at scale
  {
    for (final count in [100, 1000, 5000]) {
      final sw = Stopwatch()..start();
      final b = Banner(
        flags: [for (var i = 0; i < count; i++) BannerFlag(name: 'bulk-$i')],
      );
      sw.stop();
      final usPerFlag = sw.elapsedMicroseconds / count;
      print(
        '39. Banner      | Create($count flags)     '
        '${count < 1000 ? ' ' : ''}| ${_pad(count)} × '
        '${usPerFlag.toStringAsFixed(3)} µs/flag = ${_ms(sw)}',
      );
      // Prevent GC
      b.isEnabled('bulk-0');
    }
  }

  // 39f. Snapshot generation
  {
    final b = Banner(
      flags: [
        for (var i = 0; i < 1000; i++)
          BannerFlag(name: 'snap-$i', defaultValue: i.isEven),
      ],
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      b.snapshot;
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 1000;
    print(
      '39. Banner      | Snapshot(1k flags)       '
      '| ${_pad(1000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  print('');
}

// ---------------------------------------------------------------------------
// 40. Sieve — Reactive Search, Filter & Sort
// ---------------------------------------------------------------------------

Future<void> _benchSieve() async {
  print('┌─ 40. Sieve (Search/Filter/Sort) ─────────────────────');

  // 40a. Filter throughput
  {
    for (final count in [1000, 10000, 100000]) {
      final items = List.generate(count, (i) => i);
      final s = Sieve<int>(items: items);
      s.where('even', (n) => n.isEven);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        s.where('even', (n) => n.isEven);
        s.results.value;
      }
      sw.stop();
      final us = sw.elapsedMicroseconds / 1000;
      print(
        '40. Sieve       | Filter($count)           '
        '| ${_pad(1000)} × ${us.toStringAsFixed(1)} µs/op = ${_ms(sw)}',
      );
    }
  }

  // 40b. Text search throughput
  {
    for (final count in [1000, 10000]) {
      final items = List.generate(
        count,
        (i) => 'item-$i description for entry $i',
      );
      final s = Sieve<String>(items: items, textFields: [(s) => s]);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        s.query.value = 'item-$i';
        s.results.value;
      }
      sw.stop();
      final us = sw.elapsedMicroseconds / 100;
      print(
        '40. Sieve       | TextSearch($count)       '
        '| ${_pad(100)} × ${us.toStringAsFixed(1)} µs/op = ${_ms(sw)}',
      );
    }
  }

  // 40c. Sort throughput
  {
    for (final count in [1000, 10000]) {
      final items = List.generate(count, (i) => count - i);
      final s = Sieve<int>(items: items);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        if (i.isEven) {
          s.sortBy((a, b) => a.compareTo(b));
        } else {
          s.sortBy((a, b) => b.compareTo(a));
        }
        s.results.value;
      }
      sw.stop();
      final us = sw.elapsedMicroseconds / 100;
      print(
        '40. Sieve       | Sort($count)             '
        '| ${_pad(100)} × ${us.toStringAsFixed(1)} µs/op = ${_ms(sw)}',
      );
    }
  }

  // 40d. Combined: search + filter + sort
  {
    const count = 10000;
    final items = List.generate(count, (i) => 'item-$i priority-${i % 5}');
    final s = Sieve<String>(items: items, textFields: [(s) => s]);
    s.where('priority', (s) => s.contains('priority-0'));
    s.sortBy((a, b) => a.compareTo(b));

    final sw = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      s.query.value = 'item-${i * 10}';
      s.results.value;
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 100;
    print(
      '40. Sieve       | Combined(10k)            '
      '| ${_pad(100)} × ${us.toStringAsFixed(1)} µs/op = ${_ms(sw)}',
    );
  }

  // 40e. Create + setup
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      Sieve<int>(items: List.generate(10, (j) => j));
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '40. Sieve       | Create(10 items)         '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  print('');
}

// ---------------------------------------------------------------------------
// 41. Lattice — Reactive DAG Task Executor
// ---------------------------------------------------------------------------

Future<void> _benchLattice() async {
  print('┌─ 41. Lattice (DAG Task Executor) ──────────────────');

  // 41a. Linear chain execution
  {
    for (final count in [10, 50, 100]) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        final l = Lattice();
        l.node('n0', (_) async => 0);
        for (var j = 1; j < count; j++) {
          l.node(
            'n$j',
            (r) async => (r['n${j - 1}'] as int) + 1,
            dependsOn: ['n${j - 1}'],
          );
        }
        await l.execute();
      }
      sw.stop();
      final us = sw.elapsedMicroseconds / 100;
      print(
        '41. Lattice     | Chain($count nodes)       '
        '| ${_pad(100)} × ${us.toStringAsFixed(1)} µs/op = ${_ms(sw)}',
      );
    }
  }

  // 41b. Wide (parallel) execution
  {
    for (final count in [10, 50, 100]) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        final l = Lattice();
        for (var j = 0; j < count; j++) {
          l.node('n$j', (_) async => j);
        }
        await l.execute();
      }
      sw.stop();
      final us = sw.elapsedMicroseconds / 100;
      print(
        '41. Lattice     | Wide($count nodes)        '
        '| ${_pad(100)} × ${us.toStringAsFixed(1)} µs/op = ${_ms(sw)}',
      );
    }
  }

  // 41c. Diamond pattern
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      final l = Lattice();
      l.node('root', (_) async => 0);
      l.node('a', (_) async => 1, dependsOn: ['root']);
      l.node('b', (_) async => 2, dependsOn: ['root']);
      l.node('join', (_) async => 3, dependsOn: ['a', 'b']);
      await l.execute();
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 1000;
    print(
      '41. Lattice     | Diamond(4 nodes)         '
      '| ${_pad(1000)} × ${us.toStringAsFixed(1)} µs/op = ${_ms(sw)}',
    );
  }

  // 41d. Create + register overhead
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      final l = Lattice();
      l.node('a', (_) async => 1);
      l.node('b', (_) async => 2, dependsOn: ['a']);
      l.node('c', (_) async => 3, dependsOn: ['a']);
      l.node('d', (_) async => 4, dependsOn: ['b', 'c']);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '41. Lattice     | Create(4 nodes)          '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // 41e. Cycle detection
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      final l = Lattice();
      for (var j = 0; j < 10; j++) {
        l.node('n$j', (_) async => j, dependsOn: [if (j > 0) 'n${j - 1}']);
      }
      l.hasCycle;
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '41. Lattice     | CycleCheck(10 nodes)     '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  print('');
}

// ═══════════════════════════════════════════════════════════════════════════════
// 42. Embargo — Async Mutex/Semaphore
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> _benchEmbargo() async {
  print('');
  print('── 42. Embargo ──────────────────────────────────────');

  // Mutex guard (uncontended)
  {
    final e = Embargo(name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      await e.guard(() async => i);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '42. Embargo     | MutexGuard(uncontended)  '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Semaphore guard (permits=5, uncontended)
  {
    final e = Embargo(permits: 5, name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      await e.guard(() async => i);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '42. Embargo     | SemaphoreGuard(5, uncon) '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Mutex contended (100 concurrent tasks)
  {
    final e = Embargo(name: 'bench');
    final sw = Stopwatch()..start();
    final futures = List.generate(100, (i) {
      return e.guard(() async => i);
    });
    await Future.wait(futures);
    sw.stop();
    final us = sw.elapsedMicroseconds / 100;
    print(
      '42. Embargo     | MutexContended(100)      '
      '| ${_pad(100)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Create
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 100000; i++) {
      Embargo(name: 'e$i');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 100000;
    print(
      '42. Embargo     | Create                   '
      '| ${_pad(100000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Acquire/Release (manual)
  {
    final e = Embargo(name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      final lease = await e.acquire();
      lease.release();
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '42. Embargo     | AcquireRelease           '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  print('');
}

// =============================================================================
// 43. Census — Sliding-Window Aggregation
// =============================================================================

Future<void> _benchCensus() async {
  print('');
  print('── 43. Census ───────────────────────────────────────');

  // Record throughput (10,000 entries)
  {
    final c = Census<int>(window: const Duration(seconds: 60), name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      c.record(i);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '43. Census      | Record(10k)              '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Record + evict (window causes constant eviction)
  {
    final c = Census<int>(
      window: const Duration(milliseconds: 1),
      name: 'bench',
    );
    // Pre-populate.
    for (var i = 0; i < 100; i++) {
      c.record(i);
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      c.record(i);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '43. Census      | Record+Evict(10k)        '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Percentile computation (1,000 entries)
  {
    final c = Census<int>(window: const Duration(seconds: 60), name: 'bench');
    for (var i = 0; i < 1000; i++) {
      c.record(i);
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      c.percentile(95);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '43. Census      | Percentile(95, n=1000)   '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Create
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 100000; i++) {
      Census<int>(window: const Duration(seconds: 60), name: 'c$i');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 100000;
    print(
      '43. Census      | Create                   '
      '| ${_pad(100000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Reactive source (10,000 updates)
  {
    final source = TitanState<int>(0, name: 'source');
    final c = Census<int>(
      window: const Duration(seconds: 60),
      source: source,
      name: 'bench',
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      source.value = i;
    }
    sw.stop();
    c.dispose();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '43. Census      | ReactiveSource(10k)      '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  print('');
}

// =============================================================================
// 44. Warden — Service Health Monitor
// =============================================================================

Future<void> _benchWarden() async {
  print('');
  print('── 44. Warden ───────────────────────────────────────');

  // Create with multiple services
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      Warden(
        interval: const Duration(seconds: 30),
        services: [
          WardenService(name: 'auth', check: () async {}),
          WardenService(name: 'db', check: () async {}),
          WardenService(name: 'cache', check: () async {}),
        ],
        name: 'w$i',
      );
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '44. Warden      | Create(3 services)       '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // CheckAll (3 healthy services)
  {
    final w = Warden(
      interval: const Duration(seconds: 60),
      services: [
        WardenService(name: 'auth', check: () async {}),
        WardenService(name: 'db', check: () async {}),
        WardenService(name: 'cache', check: () async {}),
      ],
      name: 'bench',
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      await w.checkAll();
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 1000;
    print(
      '44. Warden      | CheckAll(3 svcs, 1K)     '
      '| ${_pad(1000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Single checkService
  {
    final w = Warden(
      interval: const Duration(seconds: 60),
      services: [WardenService(name: 'api', check: () async {})],
      name: 'bench',
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      await w.checkService('api');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '44. Warden      | CheckService(10K)        '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  print('');
}

// ---------------------------------------------------------------------------
// 45. Arbiter — Conflict Resolution
// ---------------------------------------------------------------------------

Future<void> _benchArbiter() async {
  print('\n─── 45. Arbiter (Conflict Resolution) ───');

  // Submit + resolve (lastWriteWins)
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      final a = Arbiter<int>(strategy: ArbiterStrategy.lastWriteWins);
      a.submit('local', i, timestamp: DateTime(2024, 1, 1));
      a.submit('server', i + 1, timestamp: DateTime(2024, 1, 2));
      a.resolve();
      a.dispose();
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '45. Arbiter     | Submit+Resolve(LWW, 10K)  '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Submit + resolve (merge, 3 sources)
  {
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      final a = Arbiter<int>(
        strategy: ArbiterStrategy.merge,
        merge: (cs) => cs.fold(0, (sum, c) => sum + c.value),
      );
      a.submit('a', i);
      a.submit('b', i + 1);
      a.submit('c', i + 2);
      a.resolve();
      a.dispose();
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '45. Arbiter     | Submit3+Merge(10K)        '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  // Auto-resolve
  {
    final a = Arbiter<int>(
      strategy: ArbiterStrategy.lastWriteWins,
      autoResolve: true,
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      a.submit('local', i, timestamp: DateTime(2024, 1, 1));
      a.submit('server', i + 1, timestamp: DateTime(2024, 1, 2));
    }
    sw.stop();
    a.dispose();
    final us = sw.elapsedMicroseconds / 10000;
    print(
      '45. Arbiter     | AutoResolve(LWW, 10K)     '
      '| ${_pad(10000)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  print('');
}

// ---------------------------------------------------------------------------
// 46. Lode — Reactive Resource Pool
// ---------------------------------------------------------------------------

Future<void> _benchLode() async {
  print('\n─── 46. Lode (Resource Pool) ───');

  // Acquire + Release cycle
  {
    var n = 0;
    final pool = Lode<int>(create: () async => ++n, maxSize: 100);
    const ops = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      final lease = await pool.acquire();
      lease.release();
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '46. Lode        | Acquire+Release(10K)      '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    await pool.dispose();
  }

  // withResource convenience
  {
    var n = 0;
    final pool = Lode<int>(create: () async => ++n, maxSize: 100);
    const ops = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      await pool.withResource((r) async => r);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '46. Lode        | withResource(10K)         '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    await pool.dispose();
  }

  // Warmup + Drain
  {
    const ops = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      var n = 0;
      final pool = Lode<int>(create: () async => ++n, maxSize: 10);
      await pool.warmup(5);
      await pool.drain();
      await pool.dispose();
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '46. Lode        | Warmup5+Drain(1K)         '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
  }

  print('');
}

// ---------------------------------------------------------------------------
// 47. Tithe — Reactive Quota & Budget Manager
// ---------------------------------------------------------------------------

void _benchTithe() {
  print('\n─── 47. Tithe (Quota & Budget) ───');

  // Consume throughput
  {
    final t = Tithe(budget: 1000000, name: 'bench');
    const ops = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      t.consume(1);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '47. Tithe       | consume(100K)             '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    t.dispose();
  }

  // Consume with key (per-resource breakdown)
  {
    final t = Tithe(budget: 1000000, name: 'bench');
    const ops = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      t.consume(1, key: 'api');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '47. Tithe       | consume+key(100K)         '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    t.dispose();
  }

  // tryConsume throughput
  {
    final t = Tithe(budget: 1000000, name: 'bench');
    const ops = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      t.tryConsume(1);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '47. Tithe       | tryConsume(100K)           '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    t.dispose();
  }

  print('');
}

// 48. Sluice — Reactive Data Pipeline
// ────────────────────────────────────

Future<void> _benchSluice() async {
  print('\n─── 48. Sluice (Data Pipeline) ───');
  const ops = 100000;

  // Benchmark 1: Single sync stage feed+flush.
  {
    final s = Sluice<int>(
      stages: [SluiceStage(name: 'pass', process: (n) => n)],
      bufferSize: ops + 1,
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      s.feed(i);
    }
    await s.flush();
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '48. Sluice      | feed+flush 1-stage(100K)   '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    s.dispose();
  }

  // Benchmark 2: Three sync stages feed+flush.
  {
    final s = Sluice<int>(
      stages: [
        SluiceStage(name: 'a', process: (n) => n + 1),
        SluiceStage(name: 'b', process: (n) => n * 2),
        SluiceStage(name: 'c', process: (n) => n - 1),
      ],
      bufferSize: ops + 1,
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      s.feed(i);
    }
    await s.flush();
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '48. Sluice      | feed+flush 3-stage(100K)   '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    s.dispose();
  }

  // Benchmark 3: Feed with filter (50% filtered out).
  {
    final s = Sluice<int>(
      stages: [SluiceStage(name: 'even', process: (n) => n.isEven ? n : null)],
      bufferSize: ops + 1,
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      s.feed(i);
    }
    await s.flush();
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '48. Sluice      | feed+filter 50%(100K)      '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    s.dispose();
  }

  print('');
}

Future<void> _benchClarion() async {
  print('\n─── 49. Clarion (Job Scheduler) ───');

  // Benchmark 1: Schedule registration throughput.
  {
    const ops = 100000;
    final c = Clarion(name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      c.schedule('job_$i', const Duration(hours: 1), () async {});
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '49. Clarion     | schedule(100K)             '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    c.dispose();
  }

  // Benchmark 2: Trigger + await (no-op handler) throughput.
  {
    const ops = 100000;
    final c = Clarion(name: 'bench');
    c.schedule('noop', const Duration(hours: 1), () async {});
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      c.trigger('noop');
    }
    // Let all microtask completions settle.
    await Future<void>.delayed(Duration.zero);
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '49. Clarion     | trigger(100K)              '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    c.dispose();
  }

  // Benchmark 3: Schedule + unschedule churn.
  {
    const ops = 100000;
    final c = Clarion(name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      c.schedule('tmp', const Duration(hours: 1), () async {});
      c.unschedule('tmp');
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '49. Clarion     | sched+unsched(100K)        '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    c.dispose();
  }

  print('');
}

void _benchTapestry() {
  print('\n─── 50. Tapestry (Event Store) ───');

  // Benchmark 1: Append throughput (no weaves).
  {
    const ops = 100000;
    final t = Tapestry<int>(name: 'bench');
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      t.append(i);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '50. Tapestry    | append(100K, no weave)     '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    t.dispose();
  }

  // Benchmark 2: Append throughput with 1 weave.
  {
    const ops = 100000;
    final t = Tapestry<int>(name: 'bench');
    t.weave<int>(name: 'sum', initial: 0, fold: (s, e) => s + e);
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      t.append(i);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '50. Tapestry    | append(100K, 1 weave)      '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    t.dispose();
  }

  // Benchmark 3: Query throughput.
  {
    const ops = 100000;
    final t = Tapestry<int>(name: 'bench');
    for (var i = 0; i < 1000; i++) {
      t.append(i);
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < ops; i++) {
      t.query(fromSequence: 100, toSequence: 200);
    }
    sw.stop();
    final us = sw.elapsedMicroseconds / ops;
    print(
      '50. Tapestry    | query(100K, range)          '
      '| ${_pad(ops)} × ${us.toStringAsFixed(3)} µs/op = ${_ms(sw)}',
    );
    t.dispose();
  }

  print('');
}
