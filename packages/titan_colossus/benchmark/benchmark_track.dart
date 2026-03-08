// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan/titan.dart';
import 'package:titan_colossus/titan_colossus.dart';

// =============================================================================
// Colossus Benchmark Tracker
// =============================================================================
//
// Run with:
//   cd packages/titan_colossus && flutter test benchmark/benchmark_track.dart
//
// Unified benchmark runner that:
//   1. Runs all 26 Colossus benchmarks (monitor + recording + export + overhead)
//   2. Saves results to benchmark/results/
//   3. Compares against previous run and flags regressions
//
// =============================================================================

final _results = <String, _BenchResult>{};
var _isWarmup = false;

void main() {
  test('Colossus Benchmark Tracker', () {
    const samples = 3;
    const threshold = 10.0;
    const noiseFloor = 0.100;

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  COLOSSUS BENCHMARK TRACKER');
    print('═══════════════════════════════════════════════════════');
    print('');

    // JIT Warmup: run all benchmarks once without recording
    print('── Warmup ─────────────────────────────────────────────');
    final warmupSw = Stopwatch()..start();
    _isWarmup = true;
    _runMonitorBenchmarks();
    _runRecordingBenchmarks();
    _runExportBenchmarks();
    _runOverheadBenchmarks();
    _runBlueprintBenchmarks();
    _runScryBenchmarks();
    _isWarmup = false;
    _results.clear();
    warmupSw.stop();
    print('   ✓ Warmup complete (${warmupSw.elapsedMilliseconds}ms)');
    print('');

    // Multi-sample collection
    final allSamples = <String, List<_BenchResult>>{};

    print('── Benchmarks ─────────────────────────────────────────');
    for (var sample = 0; sample < samples; sample++) {
      _results.clear();
      _runMonitorBenchmarks();
      _runRecordingBenchmarks();
      _runExportBenchmarks();
      _runOverheadBenchmarks();
      _runBlueprintBenchmarks();
      _runScryBenchmarks();
      for (final entry in _results.entries) {
        allSamples.putIfAbsent(entry.key, () => []).add(entry.value);
      }
      print('   ✓ Sample ${sample + 1}/$samples collected');
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

    print('   ✓ Medians computed from $samples samples');
    print('');

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
    final latestFile = File('benchmark/results/latest.json');
    if (latestFile.existsSync()) {
      previous =
          jsonDecode(latestFile.readAsStringSync()) as Map<String, dynamic>;
    }

    // Print comparison report
    _printReport(previous, threshold, noiseFloor);

    // Save results
    final resultsDir = Directory('benchmark/results');
    final historyDir = Directory('benchmark/results/history');
    if (!resultsDir.existsSync()) resultsDir.createSync(recursive: true);
    if (!historyDir.existsSync()) historyDir.createSync(recursive: true);

    final jsonOutput = const JsonEncoder.withIndent('  ').convert(payload);

    File('benchmark/results/latest.json').writeAsStringSync(jsonOutput);

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    File(
      'benchmark/results/history/${version}_$ts.json',
    ).writeAsStringSync(jsonOutput);

    print('');
    print('📁 Results saved:');
    print('   benchmark/results/latest.json');
    print('   benchmark/results/history/${version}_$ts.json');

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  TRACKING COMPLETE');
    print('═══════════════════════════════════════════════════════');
  });
}

// =============================================================================
// Monitor Benchmarks (1–8)
// =============================================================================

void _runMonitorBenchmarks() {
  // 1. Pulse.recordFrame()
  {
    final pulse = Pulse(maxHistory: 300);
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );
    }
    sw.stop();
    _record(
      'Pulse recordFrame (100K)',
      sw.elapsedMicroseconds / count,
      'µs/frame',
      'monitor',
    );
  }

  // 2. Pulse steady-state (full history, rolling average)
  {
    final pulse = Pulse(maxHistory: 300);
    for (var i = 0; i < 300; i++) {
      pulse.recordFrame(
        buildDuration: Duration(microseconds: 3000 + (i % 5) * 1000),
        rasterDuration: Duration(microseconds: 2000 + (i % 3) * 500),
        totalDuration: Duration(microseconds: 5000 + (i % 5) * 1500),
      );
    }
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );
    }
    sw.stop();
    _record(
      'Pulse Steady-State (100K)',
      sw.elapsedMicroseconds / count,
      'µs/frame',
      'monitor',
    );
  }

  // 3. FrameMark creation + isJank
  {
    const count = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final frame = FrameMark(
        buildDuration: Duration(microseconds: 4000 + (i % 20) * 1000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: Duration(microseconds: 7000 + (i % 20) * 1500),
      );
      frame.isJank;
    }
    sw.stop();
    _record(
      'FrameMark Create+Jank (1M)',
      sw.elapsedMicroseconds / count,
      'µs/mark',
      'monitor',
    );
  }

  // 4. Stride.record()
  {
    final stride = Stride(maxHistory: 100);
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      stride.record(
        '/page/$i',
        Duration(milliseconds: 50 + (i % 200)),
        pattern: '/page/:id',
      );
    }
    sw.stop();
    _record(
      'Stride record (100K)',
      sw.elapsedMicroseconds / count,
      'µs/record',
      'monitor',
    );
  }

  // 5. Stride.avgPageLoad
  {
    final stride = Stride(maxHistory: 100);
    for (var i = 0; i < 100; i++) {
      stride.record('/page/$i', Duration(milliseconds: 50 + (i % 200)));
    }
    const reads = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < reads; i++) {
      stride.avgPageLoad;
    }
    sw.stop();
    _record(
      'Stride avgPageLoad (100K)',
      sw.elapsedMicroseconds / reads,
      'µs/read',
      'monitor',
    );
  }

  // 6. Tremor.evaluate() batch
  {
    final tremors = [
      Tremor.fps(threshold: 50),
      Tremor.jankRate(threshold: 5),
      Tremor.pageLoad(threshold: const Duration(seconds: 1)),
      Tremor.memory(maxPillars: 50),
      Tremor.rebuilds(threshold: 100, widget: 'HeroCard'),
      Tremor.leaks(),
    ];
    final context = TremorContext(
      fps: 58.0,
      jankRate: 3.2,
      pillarCount: 12,
      leakSuspects: const [],
      lastPageLoad: PageLoadMark(
        path: '/home',
        duration: const Duration(milliseconds: 200),
      ),
      rebuildsPerWidget: {'HeroCard': 45, 'QuestList': 22},
    );
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      for (final tremor in tremors) {
        tremor.evaluate(context);
        tremor.reset();
      }
    }
    sw.stop();
    _record(
      'Tremor Evaluate (6x1M)',
      sw.elapsedMicroseconds / (iterations * tremors.length),
      'µs/eval',
      'monitor',
    );
  }

  // 7. recordRebuild (Echo hot path)
  {
    final rebuildsPerWidget = <String, int>{};
    final labels = List.generate(50, (i) => 'Widget_$i');
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final label = labels[i % labels.length];
      rebuildsPerWidget[label] = (rebuildsPerWidget[label] ?? 0) + 1;
    }
    sw.stop();
    _record(
      'recordRebuild (1M, 50 widgets)',
      iterations / sw.elapsedMicroseconds * 1e6,
      'rebuilds/sec',
      'monitor',
    );
  }

  // 8. Vessel snapshot
  {
    Titan.reset();
    final p = _BenchPillar();
    Titan.put<_BenchPillar>(p);

    final vessel = Vessel(checkInterval: const Duration(hours: 1));
    const snapshots = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < snapshots; i++) {
      vessel.snapshot();
    }
    sw.stop();
    _record(
      'Vessel Snapshot (1 pillar)',
      sw.elapsedMicroseconds / snapshots,
      'µs/snapshot',
      'monitor',
    );
    vessel.dispose();
    Titan.reset();
  }
}

// =============================================================================
// Recording Benchmarks (9–15)
// =============================================================================

void _runRecordingBenchmarks() {
  // 9. Imprint creation
  {
    const count = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Imprint(
        type: ImprintType.pointerDown,
        positionX: 100.0 + i,
        positionY: 200.0,
        timestamp: Duration(milliseconds: i),
        pointer: 1,
        buttons: 1,
        pressure: 1.0,
      );
    }
    sw.stop();
    _record(
      'Imprint Creation (1M)',
      sw.elapsedMicroseconds / count,
      'µs/imprint',
      'recording',
    );
  }

  // 10. Imprint toMap
  {
    const count = 100000;
    const imprint = Imprint(
      type: ImprintType.pointerDown,
      positionX: 100.0,
      positionY: 200.0,
      timestamp: Duration(milliseconds: 500),
      pointer: 1,
      buttons: 1,
      pressure: 1.0,
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      imprint.toMap();
    }
    sw.stop();
    _record(
      'Imprint toMap (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 11. Imprint fromMap
  {
    const count = 100000;
    final map = const Imprint(
      type: ImprintType.pointerDown,
      positionX: 100.0,
      positionY: 200.0,
      timestamp: Duration(milliseconds: 500),
      pointer: 1,
      buttons: 1,
      pressure: 1.0,
    ).toMap();
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Imprint.fromMap(map);
    }
    sw.stop();
    _record(
      'Imprint fromMap (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 12. ShadeSession toJson (500 events)
  {
    final session = _makeSession(500);
    const count = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      session.toJson();
    }
    sw.stop();
    _record(
      'Session toJson (500 events)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 13. ShadeSession fromJson (500 events)
  {
    final jsonStr = _makeSession(500).toJson();
    const count = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      ShadeSession.fromJson(jsonStr);
    }
    sw.stop();
    _record(
      'Session fromJson (500 events)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 14. ShadeSession toJson (2000 events)
  {
    final session = _makeSession(2000);
    const count = 50;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      session.toJson();
    }
    sw.stop();
    _record(
      'Session toJson (2K events)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 15. ShadeSession fromJson (2000 events)
  {
    final jsonStr = _makeSession(2000).toJson();
    const count = 50;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      ShadeSession.fromJson(jsonStr);
    }
    sw.stop();
    _record(
      'Session fromJson (2K events)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }
}

// =============================================================================
// Export Benchmarks (16–21)
// =============================================================================

void _runExportBenchmarks() {
  final decree = _makeDecree();

  // 16. Decree toMap
  {
    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      decree.toMap();
    }
    sw.stop();
    _record(
      'Decree toMap (10K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'export',
    );
  }

  // 17. Decree summary
  {
    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      decree.summary;
    }
    sw.stop();
    _record(
      'Decree summary (10K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'export',
    );
  }

  // 18. Decree topRebuilders
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      decree.topRebuilders();
    }
    sw.stop();
    _record(
      'Decree topRebuilders (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'export',
    );
  }

  // 19. Inscribe markdown
  {
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Inscribe.markdown(decree);
    }
    sw.stop();
    _record(
      'Inscribe Markdown (1K)',
      sw.elapsedMicroseconds / count,
      'µs/export',
      'export',
    );
  }

  // 20. Inscribe json
  {
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Inscribe.json(decree);
    }
    sw.stop();
    _record(
      'Inscribe JSON (1K)',
      sw.elapsedMicroseconds / count,
      'µs/export',
      'export',
    );
  }

  // 21. Inscribe html
  {
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Inscribe.html(decree);
    }
    sw.stop();
    _record(
      'Inscribe HTML (1K)',
      sw.elapsedMicroseconds / count,
      'µs/export',
      'export',
    );
  }
}

// =============================================================================
// Overhead & Stress Benchmarks (22–26)
// =============================================================================

void _runOverheadBenchmarks() {
  // 22. FrameMark serialization
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      FrameMark(
        buildDuration: Duration(microseconds: 4000 + i),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: Duration(microseconds: 7000 + i),
      ).toMap();
    }
    sw.stop();
    _record(
      'FrameMark Create+Serialize (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'overhead',
    );
  }

  // 23. MemoryMark serialization
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      MemoryMark(
        pillarCount: 15,
        totalInstances: 42,
        leakSuspects: const ['SomePillar'],
      ).toMap();
    }
    sw.stop();
    _record(
      'MemoryMark Create+Serialize (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'overhead',
    );
  }

  // 24. Pulse history trim (small maxHistory = more frequent trims)
  {
    final pulse = Pulse(maxHistory: 50);
    for (var i = 0; i < 50; i++) {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );
    }
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );
    }
    sw.stop();
    _record(
      'Pulse Trim (maxHistory=50, 100K)',
      sw.elapsedMicroseconds / count,
      'µs/frame',
      'overhead',
    );
  }

  // 25. Tremor factory creation
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Tremor.fps(threshold: 50);
      Tremor.jankRate(threshold: 5);
      Tremor.pageLoad(threshold: const Duration(seconds: 1));
      Tremor.memory(maxPillars: 50);
      Tremor.rebuilds(threshold: 100, widget: 'W$i');
      Tremor.leaks();
    }
    sw.stop();
    _record(
      'Tremor Factory (600K)',
      sw.elapsedMicroseconds / (count * 6),
      'µs/factory',
      'overhead',
    );
  }

  // 26. Imprint round-trip (create -> toMap -> fromMap)
  {
    const count = 50000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100.0 + i,
        positionY: 200.0,
        timestamp: Duration(milliseconds: i),
        pointer: 1,
        buttons: 1,
      );
      Imprint.fromMap(imprint.toMap());
    }
    sw.stop();
    _record(
      'Imprint Round-Trip (50K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'overhead',
    );
  }
}

// =============================================================================
// Blueprint Benchmarks (27–34)
// =============================================================================

void _runBlueprintBenchmarks() {
  // 27. Scout.analyzeSession()
  {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);

    const sessions = 200;
    const routeCount = 20;
    final routes = [for (var i = 0; i < routeCount; i++) '/screen_$i'];

    final sw = Stopwatch()..start();
    for (var i = 0; i < sessions; i++) {
      scout.analyzeSession(_blueprintSession(id: 's_$i', routes: routes));
    }
    sw.stop();
    Scout.reset();

    _record(
      'Scout Analyze (200×20)',
      sw.elapsedMicroseconds / sessions,
      'µs/session',
      'blueprint',
    );
  }

  // 28. Terrain toJson (25 outposts)
  {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    for (var i = 0; i < 10; i++) {
      scout.analyzeSession(
        _blueprintSession(
          id: 'tj_$i',
          routes: [for (var j = 0; j < 25; j++) '/screen_$j'],
        ),
      );
    }
    Scout.reset();

    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      terrain.toJson();
    }
    sw.stop();

    _record(
      'Terrain toJson (25 outposts)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'blueprint',
    );
  }

  // 29. Terrain fromJson
  {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    for (var i = 0; i < 10; i++) {
      scout.analyzeSession(
        _blueprintSession(
          id: 'tf_$i',
          routes: [for (var j = 0; j < 25; j++) '/screen_$j'],
        ),
      );
    }
    Scout.reset();

    final json = terrain.toJson();
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Terrain.fromJson(json);
    }
    sw.stop();

    _record(
      'Terrain fromJson (25 outposts)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'blueprint',
    );
  }

  // 30. Terrain graph queries (cached vs uncached)
  {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    for (var i = 0; i < 10; i++) {
      scout.analyzeSession(
        _blueprintSession(
          id: 'gq_$i',
          routes: [for (var j = 0; j < 30; j++) '/screen_$j'],
        ),
      );
    }
    Scout.reset();

    const count = 10000;

    // unreliableMarches (now cached)
    terrain.invalidateCache();
    final sw1 = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      terrain.unreliableMarches;
    }
    sw1.stop();

    _record(
      'Terrain unreliableMarches (10K)',
      sw1.elapsedMicroseconds / count,
      'µs/op',
      'blueprint',
    );

    // deadEnds (now cached)
    terrain.invalidateCache();
    final sw2 = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      terrain.deadEnds;
    }
    sw2.stop();

    _record(
      'Terrain deadEnds (10K)',
      sw2.elapsedMicroseconds / count,
      'µs/op',
      'blueprint',
    );
  }

  // 31. Gauntlet.generateFor()
  {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    for (var i = 0; i < 5; i++) {
      scout.analyzeSession(
        _blueprintSession(
          id: 'g_$i',
          routes: [for (var j = 0; j < 10; j++) '/screen_$j'],
        ),
      );
    }
    Scout.reset();

    final outpost = terrain.outposts.values.first;
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Gauntlet.generateFor(outpost);
    }
    sw.stop();

    _record(
      'Gauntlet generateFor (1K)',
      sw.elapsedMicroseconds / count,
      'µs/outpost',
      'blueprint',
    );
  }

  // 32. BlueprintExport toJson
  {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    for (var i = 0; i < 10; i++) {
      scout.analyzeSession(
        _blueprintSession(
          id: 'bj_$i',
          routes: [for (var j = 0; j < 20; j++) '/screen_$j'],
        ),
      );
    }

    final export = BlueprintExport.fromScout(scout: scout);
    Scout.reset();

    const count = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      export.toJson();
    }
    sw.stop();

    _record(
      'BlueprintExport toJson (100)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'blueprint',
    );
  }

  // 33. BlueprintExport toCompactJsonString
  {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    for (var i = 0; i < 10; i++) {
      scout.analyzeSession(
        _blueprintSession(
          id: 'bc_$i',
          routes: [for (var j = 0; j < 20; j++) '/screen_$j'],
        ),
      );
    }

    final export = BlueprintExport.fromScout(scout: scout);
    Scout.reset();

    const count = 100;

    // Pretty-printed
    final sw1 = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      export.toJsonString();
    }
    sw1.stop();

    _record(
      'BlueprintExport toJsonString (100)',
      sw1.elapsedMicroseconds / count,
      'µs/op',
      'blueprint',
    );

    // Compact
    final sw2 = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      export.toCompactJsonString();
    }
    sw2.stop();

    _record(
      'BlueprintExport toCompactJson (100)',
      sw2.elapsedMicroseconds / count,
      'µs/op',
      'blueprint',
    );
  }

  // 34. Full pipeline: sessions → Scout → Gauntlet → Export
  {
    const routeCount = 50;
    const sessionCount = 50;
    final routes = [for (var i = 0; i < routeCount; i++) '/screen_$i'];

    final sw = Stopwatch()..start();
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    for (var i = 0; i < sessionCount; i++) {
      scout.analyzeSession(_blueprintSession(id: 'pipe_$i', routes: routes));
    }
    final export = BlueprintExport.fromScout(scout: scout);
    export.toCompactJsonString();
    Scout.reset();
    sw.stop();

    _record(
      'Full Pipeline (50×50)',
      sw.elapsedMilliseconds.toDouble(),
      'ms',
      'blueprint',
    );
  }
}

// =============================================================================
// Scry Benchmarks (35–42)
// =============================================================================

/// Build a raw glyph map for Scry benchmarks.
Map<String, dynamic> _scryGlyph({
  required String label,
  String widgetType = 'Text',
  double x = 0,
  double y = 0,
  bool interactive = false,
  String? interactionType,
  String? fieldId,
  String? currentValue,
  int depth = 5,
  List<String>? ancestors,
}) {
  return {
    'l': label,
    'wt': widgetType,
    'x': x,
    'y': y,
    'w': 100.0,
    'h': 48.0,
    'ia': interactive,
    if (interactionType != null) 'it': interactionType,
    if (fieldId != null) 'fid': fieldId,
    if (currentValue != null) 'cv': currentValue,
    'd': depth,
    if (ancestors != null) 'anc': ancestors,
    'en': true,
  };
}

/// Small screen: 10 mixed glyphs.
List<Map<String, dynamic>> _scrySmallScreen() {
  return [
    _scryGlyph(label: 'Home', y: 50, depth: 3),
    _scryGlyph(
      label: 'Submit',
      widgetType: 'ElevatedButton',
      y: 200,
      interactive: true,
      interactionType: 'tap',
    ),
    _scryGlyph(label: 'Welcome back', y: 100),
    _scryGlyph(
      label: 'Cancel',
      widgetType: 'TextButton',
      y: 200,
      x: 150,
      interactive: true,
      interactionType: 'tap',
    ),
    _scryGlyph(label: 'Status: Active', y: 150),
    _scryGlyph(
      label: 'Settings',
      widgetType: 'NavigationDestination',
      y: 750,
      interactive: true,
      interactionType: 'tap',
      ancestors: ['NavigationBar'],
    ),
    _scryGlyph(
      label: 'Profile',
      widgetType: 'NavigationDestination',
      y: 750,
      x: 100,
      interactive: true,
      interactionType: 'tap',
      ancestors: ['NavigationBar'],
    ),
    _scryGlyph(label: 'Version 2.1.0', y: 700),
    _scryGlyph(
      label: 'Help',
      widgetType: 'IconButton',
      y: 50,
      x: 350,
      interactive: true,
      interactionType: 'tap',
    ),
    _scryGlyph(label: 'Last synced: 5m ago', y: 160),
  ];
}

/// Medium screen: 50 mixed glyphs.
List<Map<String, dynamic>> _scryMediumScreen() {
  final glyphs = <Map<String, dynamic>>[];
  glyphs.add(
    _scryGlyph(label: 'Dashboard', y: 50, depth: 3, ancestors: ['AppBar']),
  );
  for (var i = 0; i < 5; i++) {
    glyphs.add(
      _scryGlyph(
        label: 'Tab ${i + 1}',
        widgetType: 'NavigationDestination',
        y: 750,
        x: i * 80.0,
        interactive: true,
        interactionType: 'tap',
        ancestors: ['NavigationBar'],
      ),
    );
  }
  for (var i = 0; i < 10; i++) {
    glyphs.add(_scryGlyph(label: 'Field $i: Value $i', y: 100.0 + i * 30));
  }
  for (var i = 0; i < 8; i++) {
    glyphs.add(
      _scryGlyph(
        label: 'Action $i',
        widgetType: 'ElevatedButton',
        y: 400.0 + i * 40,
        interactive: true,
        interactionType: 'tap',
      ),
    );
  }
  for (var i = 0; i < 22; i++) {
    glyphs.add(_scryGlyph(label: 'Content line $i text', y: 100.0 + i * 25));
  }
  glyphs.add(
    _scryGlyph(
      label: 'Delete',
      widgetType: 'TextButton',
      y: 600,
      interactive: true,
      interactionType: 'tap',
    ),
  );
  glyphs.add(
    _scryGlyph(
      label: 'Reset',
      widgetType: 'TextButton',
      y: 630,
      interactive: true,
      interactionType: 'tap',
    ),
  );
  glyphs.add(
    _scryGlyph(
      label: 'Sign Out',
      widgetType: 'TextButton',
      y: 660,
      interactive: true,
      interactionType: 'tap',
    ),
  );
  return glyphs;
}

/// Large screen: N mixed glyphs.
List<Map<String, dynamic>> _scryLargeScreen(int count) {
  return [
    for (var i = 0; i < count; i++)
      _scryGlyph(
        label: i % 7 == 0
            ? 'Field $i: Data $i'
            : i % 5 == 0
            ? 'Button $i'
            : 'Item $i text',
        widgetType: i % 5 == 0 ? 'ElevatedButton' : 'Text',
        y: (i * 30.0) % 800,
        x: (i * 50.0) % 400,
        interactive: i % 5 == 0,
        interactionType: i % 5 == 0 ? 'tap' : null,
        depth: (i % 20) + 1,
      ),
  ];
}

void _runScryBenchmarks() {
  const scry = Scry();

  // 35. observe() — small screen (10 glyphs)
  {
    final screen = _scrySmallScreen();
    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      scry.observe(screen, route: '/home');
    }
    sw.stop();
    _record(
      'Scry Small (10 glyphs)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'scry',
    );
  }

  // 36. observe() — medium screen (50 glyphs)
  {
    final screen = _scryMediumScreen();
    const count = 5000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      scry.observe(screen, route: '/dashboard');
    }
    sw.stop();
    _record(
      'Scry Medium (50 glyphs)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'scry',
    );
  }

  // 37. observe() — large screen (200 glyphs)
  {
    final screen = _scryLargeScreen(200);
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      scry.observe(screen, route: '/complex');
    }
    sw.stop();
    _record(
      'Scry Large (200 glyphs)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'scry',
    );
  }

  // 38. observe() — stress test (500 glyphs)
  {
    final screen = _scryLargeScreen(500);
    const count = 200;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      scry.observe(screen, route: '/stress');
    }
    sw.stop();
    _record(
      'Scry Stress (500 glyphs)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'scry',
    );
  }

  // 39. observe() — form screen (20 fields)
  {
    final screen = <Map<String, dynamic>>[
      _scryGlyph(label: 'Form', y: 50, ancestors: ['AppBar']),
      for (var i = 0; i < 20; i++)
        _scryGlyph(
          label: 'Field $i',
          widgetType: 'TextField',
          y: 100.0 + i * 60,
          interactive: true,
          interactionType: 'tap',
          fieldId: 'field_$i',
          currentValue: i % 3 == 0 ? 'value $i' : '',
        ),
      _scryGlyph(
        label: 'Submit',
        widgetType: 'ElevatedButton',
        y: 1300,
        interactive: true,
        interactionType: 'tap',
      ),
    ];
    const count = 5000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      scry.observe(screen, route: '/register');
    }
    sw.stop();
    _record(
      'Scry Form (20 fields)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'scry',
    );
  }

  // 40. observe() — data-rich screen (30 KV pairs)
  {
    final screen = <Map<String, dynamic>>[
      _scryGlyph(label: 'Details', y: 50, ancestors: ['AppBar']),
      for (var i = 0; i < 15; i++)
        _scryGlyph(label: 'Metric $i: ${1000 + i * 42}', y: 100.0 + i * 30),
      for (var i = 0; i < 15; i++) ...[
        _scryGlyph(label: 'Stat $i', y: 560.0 + i * 30, x: 20),
        _scryGlyph(label: '${2000 + i}', y: 560.0 + i * 30, x: 300),
      ],
    ];
    const count = 5000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      scry.observe(screen, route: '/details');
    }
    sw.stop();
    _record(
      'Scry DataRich (30 KV)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'scry',
    );
  }

  // 41. formatGaze() throughput
  {
    final gaze = scry.observe(_scryMediumScreen(), route: '/dashboard');
    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      scry.formatGaze(gaze);
    }
    sw.stop();
    _record(
      'Scry formatGaze (50 glyphs)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'scry',
    );
  }

  // 42. Full observe+format pipeline
  {
    final screens = [_scrySmallScreen(), _scryMediumScreen()];
    const count = 5000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final screen = screens[i % screens.length];
      final gaze = scry.observe(screen, route: '/bench');
      scry.formatGaze(gaze);
    }
    sw.stop();
    _record(
      'Scry Full Pipeline (5K)',
      sw.elapsedMicroseconds / count,
      'µs/cycle',
      'scry',
    );
  }
}

/// Helper: create a Blueprint benchmark session.
ShadeSession _blueprintSession({
  required String id,
  required List<String> routes,
}) {
  return ShadeSession(
    id: id,
    name: 'bench-$id',
    recordedAt: DateTime(2025),
    duration: Duration(seconds: routes.length * 3),
    screenWidth: 400,
    screenHeight: 800,
    devicePixelRatio: 2.0,
    imprints: [
      for (var i = 0; i < routes.length; i++)
        Imprint(
          type: ImprintType.pointerDown,
          positionX: 100.0 + i,
          positionY: 200.0 + i,
          timestamp: Duration(milliseconds: i * 100),
          tableauIndex: i,
        ),
    ],
    tableaux: [
      for (var i = 0; i < routes.length; i++)
        Tableau(
          index: i,
          route: routes[i],
          timestamp: Duration(seconds: i + 1),
          screenWidth: 400,
          screenHeight: 800,
          glyphs: [
            Glyph(
              widgetType: 'ElevatedButton',
              label: 'Button $i',
              left: 0,
              top: 0,
              width: 100,
              height: 48,
              isInteractive: true,
              interactionType: 'tap',
              key: 'key_$i',
              isEnabled: true,
              depth: i,
            ),
          ],
        ),
    ],
  );
}

// =============================================================================
// Helpers
// =============================================================================

ShadeSession _makeSession(int eventCount) {
  return ShadeSession(
    id: 'bench-session',
    name: 'Benchmark Session',
    recordedAt: DateTime.now(),
    duration: Duration(milliseconds: eventCount * 16),
    screenWidth: 390,
    screenHeight: 844,
    devicePixelRatio: 3.0,
    imprints: List.generate(
      eventCount,
      (i) => Imprint(
        type: i % 3 == 0
            ? ImprintType.pointerDown
            : i % 3 == 1
            ? ImprintType.pointerMove
            : ImprintType.pointerUp,
        positionX: 100.0 + i * 0.5,
        positionY: 200.0 + i * 0.3,
        timestamp: Duration(milliseconds: i * 16),
        pointer: 1,
        buttons: i % 3 == 2 ? 0 : 1,
        pressure: 1.0,
      ),
    ),
    startRoute: '/home',
  );
}

Decree _makeDecree() {
  return Decree(
    sessionStart: DateTime.now(),
    totalFrames: 10000,
    jankFrames: 150,
    avgFps: 58.5,
    avgBuildTime: const Duration(microseconds: 4200),
    avgRasterTime: const Duration(microseconds: 3100),
    pageLoads: List.generate(
      20,
      (i) => PageLoadMark(
        path: '/page/$i',
        duration: Duration(milliseconds: 100 + i * 10),
      ),
    ),
    pillarCount: 15,
    totalInstances: 42,
    leakSuspects: [
      LeakSuspect(typeName: 'OldPillar', firstSeen: DateTime.now()),
    ],
    rebuildsPerWidget: {for (var i = 0; i < 30; i++) 'Widget_$i': 10 + i * 3},
  );
}

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

void _printReport(
  Map<String, dynamic>? previous,
  double threshold,
  double noiseFloor,
) {
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  RESULTS');
  print('═══════════════════════════════════════════════════════');

  final prevBenchmarks = previous?['benchmarks'] as Map<String, dynamic>?;

  // Group by suite
  final suites = <String, List<String>>{};
  for (final entry in _results.entries) {
    suites.putIfAbsent(entry.value.suite, () => []).add(entry.key);
  }

  for (final suite in suites.entries) {
    print('');
    print('── ${suite.key.toUpperCase()} ──');

    for (final name in suite.value) {
      final result = _results[name]!;
      final valueStr = result.value >= 1000
          ? result.value.toStringAsFixed(0)
          : result.value.toStringAsFixed(3);

      String flag = '';
      if (prevBenchmarks != null && prevBenchmarks.containsKey(name)) {
        final prevValue =
            (prevBenchmarks[name] as Map<String, dynamic>)['value'] as num;
        final prevUnit =
            (prevBenchmarks[name] as Map<String, dynamic>)['unit'] as String;

        // For throughput metrics (higher is better), invert the comparison
        final isHigherBetter = prevUnit.contains('/sec') || prevUnit == 'x';

        final pctChange = ((result.value - prevValue) / prevValue * 100);

        final isRegression = isHigherBetter
            ? pctChange < -threshold
            : pctChange > threshold;
        final isImprovement = isHigherBetter
            ? pctChange > threshold
            : pctChange < -threshold;

        // Skip noise-floor items
        final absValue = isHigherBetter
            ? 1.0 / result.value * 1e6
            : result.value;
        if (absValue < noiseFloor && isRegression) {
          flag = ' (noise)';
        } else if (isRegression) {
          flag = pctChange.abs() > 20
              ? ' 🔴 ${pctChange.toStringAsFixed(1)}%'
              : ' 🟡 ${pctChange.toStringAsFixed(1)}%';
        } else if (isImprovement) {
          flag = pctChange.abs() > 20
              ? ' 💚 ${pctChange.toStringAsFixed(1)}%'
              : ' 🟢 ${pctChange.toStringAsFixed(1)}%';
        }
      } else if (prevBenchmarks != null) {
        flag = ' 🆕';
      }

      print('  ${name.padRight(38)} $valueStr ${result.unit}$flag');
    }
  }

  // Check for removed metrics
  if (prevBenchmarks != null) {
    for (final name in prevBenchmarks.keys) {
      if (!_results.containsKey(name)) {
        print('  ${name.padRight(38)} ❌ removed');
      }
    }
  }
}

class _BenchResult {
  final double value;
  final String unit;
  final String suite;
  _BenchResult({required this.value, required this.unit, required this.suite});
}

class _BenchPillar extends Pillar {
  late final count = core(0);
}
