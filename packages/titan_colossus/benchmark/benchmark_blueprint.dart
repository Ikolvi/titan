// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

// =============================================================================
// Blueprint Performance Benchmarks — Scout, Terrain, Gauntlet, Export
// =============================================================================
//
// Run with: cd packages/titan_colossus && flutter test benchmark/benchmark_blueprint.dart
//
// Measures the performance of the AI Blueprint Generation pipeline:
//   1.  Scout.analyzeSession() throughput
//   2.  Terrain serialization (toJson / fromJson)
//   3.  Terrain export (toAiMap / toMermaid)
//   4.  Terrain graph queries (deadEnds, reachableFrom, shortestPath)
//   5.  Terrain at scale (50, 200, 500 outposts)
//   6.  Gauntlet.generateFor() throughput
//   7.  Stratagem serialization (toJson / fromJson)
//   8.  BlueprintExport.fromScout() construction
//   9.  BlueprintExport.toJson / toJsonString / toAiPrompt
//   10. Tableau creation + serialization
//   11. Tableau.diff() throughput
//   12. Full pipeline: sessions → Scout → Gauntlet → Export
// =============================================================================

void main() {
  test('Blueprint Performance Benchmarks', () {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('  BLUEPRINT PERFORMANCE BENCHMARKS');
    print('═══════════════════════════════════════════════════════');
    print('');

    _benchScoutAnalyze();
    _benchTerrainSerialization();
    _benchTerrainExport();
    _benchTerrainQueries();
    _benchTerrainAtScale();
    _benchGauntletGenerate();
    _benchStratagemSerialization();
    _benchBlueprintExportConstruction();
    _benchBlueprintExportSerialization();
    _benchTableauCreation();
    _benchTableauDiff();
    _benchFullPipeline();

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  ALL BLUEPRINT BENCHMARKS COMPLETE');
    print('═══════════════════════════════════════════════════════');
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _ms(Stopwatch sw) {
  final ms = sw.elapsedMilliseconds;
  final us = sw.elapsedMicroseconds;
  if (ms > 0) return '${ms}ms';
  return '$usµs';
}

String _pad(int n) => n.toString().padLeft(7);

/// Create a realistic Glyph for benchmarking.
Glyph _glyph(int i, {bool interactive = true}) => Glyph(
  widgetType: interactive ? 'ElevatedButton' : 'Text',
  label: 'Element $i',
  left: (i % 3) * 120.0,
  top: (i ~/ 3) * 60.0,
  width: 100,
  height: 48,
  isInteractive: interactive,
  interactionType: interactive ? 'tap' : null,
  key: 'key_$i',
  isEnabled: true,
  depth: i,
);

/// Create a Tableau with the given route and glyph count.
Tableau _tableau(int index, String route, {int glyphCount = 5}) => Tableau(
  index: index,
  route: route,
  timestamp: Duration(seconds: index + 1),
  screenWidth: 400,
  screenHeight: 800,
  glyphs: [
    for (var i = 0; i < glyphCount; i++) _glyph(i, interactive: i % 3 == 0),
  ],
);

/// Create a session with N tableaux spanning N different routes.
ShadeSession _session({
  required String id,
  required List<String> routes,
  int glyphsPerTableau = 5,
  int imprintCount = 0,
}) {
  return ShadeSession(
    id: id,
    name: 'bench-session-$id',
    recordedAt: DateTime(2025),
    duration: Duration(seconds: routes.length * 3),
    screenWidth: 400,
    screenHeight: 800,
    devicePixelRatio: 2.0,
    imprints: [
      for (var i = 0; i < imprintCount; i++)
        Imprint(
          type: ImprintType.pointerDown,
          positionX: 100.0 + i,
          positionY: 200.0 + i,
          timestamp: Duration(milliseconds: i * 100),
          tableauIndex: i % routes.length,
        ),
    ],
    tableaux: [
      for (var i = 0; i < routes.length; i++)
        _tableau(i, routes[i], glyphCount: glyphsPerTableau),
    ],
  );
}

/// Generate N unique routes forming a connected chain.
List<String> _chainRoutes(int count) => [
  for (var i = 0; i < count; i++) '/screen_$i',
];

// ---------------------------------------------------------------------------
// 1. Scout.analyzeSession() throughput
// ---------------------------------------------------------------------------

void _benchScoutAnalyze() {
  print('┌─ 1. Scout.analyzeSession() Throughput ───────────────');

  for (final routeCount in [5, 20, 50]) {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    final routes = _chainRoutes(routeCount);

    const sessions = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < sessions; i++) {
      scout.analyzeSession(
        _session(id: 's_$i', routes: routes, glyphsPerTableau: 8),
      );
    }
    sw.stop();

    final perSession = (sw.elapsedMicroseconds / sessions).toStringAsFixed(1);
    print(
      '│  $sessions sessions × $routeCount routes:  ${_ms(sw)}  '
      '($perSession µs/session, ${terrain.screenCount} outposts)',
    );
  }

  Scout.reset();
  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 2. Terrain serialization (toJson / fromJson)
// ---------------------------------------------------------------------------

void _benchTerrainSerialization() {
  print('┌─ 2. Terrain Serialization (toJson/fromJson) ────────');

  // Build a medium terrain
  Scout.reset();
  final terrain = Terrain();
  final scout = Scout.withTerrain(terrain);
  for (var i = 0; i < 20; i++) {
    scout.analyzeSession(
      _session(id: 'ser_$i', routes: _chainRoutes(25), glyphsPerTableau: 6),
    );
  }
  Scout.reset();

  // Benchmark toJson
  const count = 1000;
  final sw1 = Stopwatch()..start();
  late Map<String, dynamic> json;
  for (var i = 0; i < count; i++) {
    json = terrain.toJson();
  }
  sw1.stop();
  final perTo = (sw1.elapsedMicroseconds / count).toStringAsFixed(1);
  print(
    '│  toJson()   ($count, ${terrain.screenCount} outposts):  '
    '${_ms(sw1)}  ($perTo µs/op)',
  );

  // Benchmark fromJson
  final sw2 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    Terrain.fromJson(json);
  }
  sw2.stop();
  final perFrom = (sw2.elapsedMicroseconds / count).toStringAsFixed(1);
  print(
    '│  fromJson() ($count, ${terrain.screenCount} outposts):  '
    '${_ms(sw2)}  ($perFrom µs/op)',
  );

  // JSON string size
  final jsonStr = const JsonEncoder().convert(json);
  print('│  JSON size: ${(jsonStr.length / 1024).toStringAsFixed(1)} KB');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 3. Terrain export (toAiMap / toMermaid)
// ---------------------------------------------------------------------------

void _benchTerrainExport() {
  print('┌─ 3. Terrain Export (toAiMap/toMermaid) ──────────────');

  Scout.reset();
  final terrain = Terrain();
  final scout = Scout.withTerrain(terrain);
  for (var i = 0; i < 10; i++) {
    scout.analyzeSession(
      _session(id: 'exp_$i', routes: _chainRoutes(30), glyphsPerTableau: 4),
    );
  }
  Scout.reset();

  const count = 1000;

  // toAiMap
  final sw1 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    terrain.toAiMap();
  }
  sw1.stop();
  final perAi = (sw1.elapsedMicroseconds / count).toStringAsFixed(1);
  print(
    '│  toAiMap()  ($count, ${terrain.screenCount} screens):  '
    '${_ms(sw1)}  ($perAi µs/op)',
  );

  // toMermaid
  final sw2 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    terrain.toMermaid();
  }
  sw2.stop();
  final perMmd = (sw2.elapsedMicroseconds / count).toStringAsFixed(1);
  print(
    '│  toMermaid()($count, ${terrain.screenCount} screens):  '
    '${_ms(sw2)}  ($perMmd µs/op)',
  );

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 4. Terrain graph queries
// ---------------------------------------------------------------------------

void _benchTerrainQueries() {
  print('┌─ 4. Terrain Graph Queries ───────────────────────────');

  Scout.reset();
  final terrain = Terrain();
  final scout = Scout.withTerrain(terrain);
  // Build a 50-screen graph with transitions
  for (var i = 0; i < 20; i++) {
    scout.analyzeSession(
      _session(id: 'q_$i', routes: _chainRoutes(50), glyphsPerTableau: 4),
    );
  }
  Scout.reset();

  const count = 10000;

  // deadEnds
  final sw1 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    terrain.deadEnds;
  }
  sw1.stop();
  final perDe = (sw1.elapsedMicroseconds / count).toStringAsFixed(1);
  print(
    '│  deadEnds       ($count):  ${_ms(sw1)}  ($perDe µs/op, '
    '${terrain.deadEnds.length} found)',
  );

  // unreliableMarches
  final sw2 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    terrain.unreliableMarches;
  }
  sw2.stop();
  final perUm = (sw2.elapsedMicroseconds / count).toStringAsFixed(1);
  print(
    '│  unreliable     ($count):  ${_ms(sw2)}  ($perUm µs/op, '
    '${terrain.unreliableMarches.length} found)',
  );

  // reachableFrom
  final firstRoute = terrain.outposts.keys.first;
  final sw3 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    terrain.reachableFrom(firstRoute);
  }
  sw3.stop();
  final perRf = (sw3.elapsedMicroseconds / count).toStringAsFixed(1);
  print('│  reachableFrom  ($count):  ${_ms(sw3)}  ($perRf µs/op)');

  // shortestPath
  final lastRoute = terrain.outposts.keys.last;
  final sw4 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    terrain.shortestPath(firstRoute, lastRoute);
  }
  sw4.stop();
  final perSp = (sw4.elapsedMicroseconds / count).toStringAsFixed(1);
  print('│  shortestPath   ($count):  ${_ms(sw4)}  ($perSp µs/op)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 5. Terrain at scale (50, 200, 500 outposts)
// ---------------------------------------------------------------------------

void _benchTerrainAtScale() {
  print('┌─ 5. Terrain at Scale ────────────────────────────────');

  for (final screenCount in [50, 200, 500]) {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);

    // Build large terrain by feeding sessions with many routes
    // Use batches of 50 routes per session to build up
    final batchSize = screenCount < 50 ? screenCount : 50;
    final batches = (screenCount / batchSize).ceil();

    final buildSw = Stopwatch()..start();
    for (var batch = 0; batch < batches; batch++) {
      final startIdx = batch * batchSize;
      final endIdx = (startIdx + batchSize).clamp(0, screenCount);
      // Use unique single-segment routes to avoid parameterizer collapsing
      final routes = [for (var i = startIdx; i < endIdx; i++) '/s${i}page'];
      // Feed multiple sessions so transitions form
      for (var s = 0; s < 5; s++) {
        scout.analyzeSession(
          _session(
            id: 'scale_${batch}_$s',
            routes: routes,
            glyphsPerTableau: 4,
          ),
        );
      }
    }
    buildSw.stop();

    // Benchmark key operations at this scale
    final toJsonSw = Stopwatch()..start();
    final json = terrain.toJson();
    toJsonSw.stop();

    final fromJsonSw = Stopwatch()..start();
    Terrain.fromJson(json);
    fromJsonSw.stop();

    final aiMapSw = Stopwatch()..start();
    terrain.toAiMap();
    aiMapSw.stop();

    final deadEndSw = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      terrain.deadEnds;
    }
    deadEndSw.stop();

    print(
      '│  ${_pad(terrain.screenCount)} screens, '
      '${terrain.transitionCount} transitions:',
    );
    print(
      '│    Build:    ${_ms(buildSw)}  '
      'toJson: ${_ms(toJsonSw)}  '
      'fromJson: ${_ms(fromJsonSw)}',
    );
    print(
      '│    aiMap:    ${_ms(aiMapSw)}  '
      'deadEnds×100: ${_ms(deadEndSw)}',
    );

    Scout.reset();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 6. Gauntlet.generateFor() throughput
// ---------------------------------------------------------------------------

void _benchGauntletGenerate() {
  print('┌─ 6. Gauntlet.generateFor() Throughput ──────────────');

  Scout.reset();
  final terrain = Terrain();
  final scout = Scout.withTerrain(terrain);
  for (var i = 0; i < 10; i++) {
    scout.analyzeSession(
      _session(id: 'g_$i', routes: _chainRoutes(15), glyphsPerTableau: 8),
    );
  }
  Scout.reset();

  final outposts = terrain.outposts.values.toList();

  for (final intensity in GauntletIntensity.values) {
    var totalStratagems = 0;
    final sw = Stopwatch()..start();
    for (final outpost in outposts) {
      final stratagems = Gauntlet.generateFor(outpost, intensity: intensity);
      totalStratagems += stratagems.length;
    }
    sw.stop();

    final perOutpost = (sw.elapsedMicroseconds / outposts.length)
        .toStringAsFixed(1);
    print(
      '│  ${intensity.name.padRight(9)} (${outposts.length} outposts):  '
      '${_ms(sw)}  ($perOutpost µs/outpost, $totalStratagems stratagems)',
    );
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 7. Stratagem serialization (toJson / fromJson)
// ---------------------------------------------------------------------------

void _benchStratagemSerialization() {
  print('┌─ 7. Stratagem Serialization ─────────────────────────');

  Scout.reset();
  final terrain = Terrain();
  final scout = Scout.withTerrain(terrain);
  for (var i = 0; i < 5; i++) {
    scout.analyzeSession(
      _session(id: 'ss_$i', routes: _chainRoutes(10), glyphsPerTableau: 6),
    );
  }
  Scout.reset();

  // Collect stratagems
  final stratagems = <Stratagem>[];
  for (final outpost in terrain.outposts.values) {
    stratagems.addAll(Gauntlet.generateFor(outpost));
  }

  if (stratagems.isEmpty) {
    print('│  (no stratagems generated — skipped)');
    print('└───────────────────────────────────────────────────────');
    print('');
    return;
  }

  const iterations = 1000;

  // toJson
  final sw1 = Stopwatch()..start();
  late List<Map<String, dynamic>> jsons;
  for (var i = 0; i < iterations; i++) {
    jsons = stratagems.map((s) => s.toJson()).toList();
  }
  sw1.stop();

  final perTo = (sw1.elapsedMicroseconds / (iterations * stratagems.length))
      .toStringAsFixed(2);
  print(
    '│  toJson()   ($iterations × ${stratagems.length}):  '
    '${_ms(sw1)}  ($perTo µs/stratagem)',
  );

  // fromJson
  final sw2 = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    for (final json in jsons) {
      Stratagem.fromJson(json);
    }
  }
  sw2.stop();

  final perFrom = (sw2.elapsedMicroseconds / (iterations * jsons.length))
      .toStringAsFixed(2);
  print(
    '│  fromJson() ($iterations × ${jsons.length}):  '
    '${_ms(sw2)}  ($perFrom µs/stratagem)',
  );

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 8. BlueprintExport.fromScout() construction
// ---------------------------------------------------------------------------

void _benchBlueprintExportConstruction() {
  print('┌─ 8. BlueprintExport.fromScout() Construction ───────');

  for (final routeCount in [10, 30, 50]) {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    for (var i = 0; i < 10; i++) {
      scout.analyzeSession(
        _session(
          id: 'bec_$i',
          routes: _chainRoutes(routeCount),
          glyphsPerTableau: 6,
        ),
      );
    }

    const iterations = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      BlueprintExport.fromScout(scout: scout);
    }
    sw.stop();

    final perExport = (sw.elapsedMicroseconds / iterations).toStringAsFixed(1);
    print(
      '│  $routeCount routes ($iterations):  ${_ms(sw)}  '
      '($perExport µs/export, ${terrain.screenCount} screens)',
    );

    Scout.reset();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 9. BlueprintExport serialization
// ---------------------------------------------------------------------------

void _benchBlueprintExportSerialization() {
  print('┌─ 9. BlueprintExport Serialization ───────────────────');

  Scout.reset();
  final terrain = Terrain();
  final scout = Scout.withTerrain(terrain);
  for (var i = 0; i < 10; i++) {
    scout.analyzeSession(
      _session(id: 'bes_$i', routes: _chainRoutes(20), glyphsPerTableau: 6),
    );
  }
  final export = BlueprintExport.fromScout(scout: scout);
  Scout.reset();

  const iterations = 500;

  // toJson
  final sw1 = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    export.toJson();
  }
  sw1.stop();
  final perJson = (sw1.elapsedMicroseconds / iterations).toStringAsFixed(1);
  print('│  toJson()       ($iterations):  ${_ms(sw1)}  ($perJson µs/op)');

  // toJsonString
  final sw2 = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    export.toJsonString();
  }
  sw2.stop();
  final perStr = (sw2.elapsedMicroseconds / iterations).toStringAsFixed(1);
  final size = (export.toJsonString().length / 1024).toStringAsFixed(1);
  print(
    '│  toJsonString() ($iterations):  ${_ms(sw2)}  '
    '($perStr µs/op, $size KB)',
  );

  // toAiPrompt
  final sw3 = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    export.toAiPrompt();
  }
  sw3.stop();
  final perPrompt = (sw3.elapsedMicroseconds / iterations).toStringAsFixed(1);
  final promptSize = (export.toAiPrompt().length / 1024).toStringAsFixed(1);
  print(
    '│  toAiPrompt()   ($iterations):  ${_ms(sw3)}  '
    '($perPrompt µs/op, $promptSize KB)',
  );

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 10. Tableau creation + serialization
// ---------------------------------------------------------------------------

void _benchTableauCreation() {
  print('┌─ 10. Tableau Creation + Serialization ──────────────');

  // Creation at scale
  for (final glyphCount in [5, 20, 50]) {
    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      _tableau(i, '/bench', glyphCount: glyphCount);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
    print(
      '│  Create ($count, $glyphCount glyphs):  ${_ms(sw)}  '
      '($perOp µs/tableau)',
    );
  }

  // Serialization round-trip
  final tab = _tableau(0, '/bench', glyphCount: 20);
  const serCount = 10000;

  final sw1 = Stopwatch()..start();
  late Map<String, dynamic> map;
  for (var i = 0; i < serCount; i++) {
    map = tab.toMap();
  }
  sw1.stop();
  final perTo = (sw1.elapsedMicroseconds / serCount).toStringAsFixed(2);
  print('│  toMap()  ($serCount, 20 glyphs):  ${_ms(sw1)}  ($perTo µs/op)');

  final sw2 = Stopwatch()..start();
  for (var i = 0; i < serCount; i++) {
    Tableau.fromMap(map);
  }
  sw2.stop();
  final perFrom = (sw2.elapsedMicroseconds / serCount).toStringAsFixed(2);
  print('│  fromMap()($serCount, 20 glyphs):  ${_ms(sw2)}  ($perFrom µs/op)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 11. Tableau.diff() throughput
// ---------------------------------------------------------------------------

void _benchTableauDiff() {
  print('┌─ 11. Tableau.diff() Throughput ──────────────────────');

  // Same tableau (no changes) — baseline
  final tabA = _tableau(0, '/bench', glyphCount: 20);

  const count = 10000;
  final sw1 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    tabA.diff(tabA);
  }
  sw1.stop();
  final perSame = (sw1.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  Same tableau ($count):  ${_ms(sw1)}  ($perSame µs/op)');

  // Different tableaux (route change + glyph changes)
  final tabB = _tableau(1, '/other', glyphCount: 20);

  final sw2 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    tabA.diff(tabB);
  }
  sw2.stop();
  final perDiff = (sw2.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  Different ($count):     ${_ms(sw2)}  ($perDiff µs/op)');

  // Large tableaux (50 glyphs)
  final tabC = _tableau(0, '/bench', glyphCount: 50);
  final tabD = _tableau(1, '/other', glyphCount: 50);

  final sw3 = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    tabC.diff(tabD);
  }
  sw3.stop();
  final perLarge = (sw3.elapsedMicroseconds / count).toStringAsFixed(2);
  print('│  Large 50 glyphs ($count): ${_ms(sw3)}  ($perLarge µs/op)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 12. Full pipeline: sessions → Scout → Gauntlet → Export
// ---------------------------------------------------------------------------

void _benchFullPipeline() {
  print('┌─ 12. Full Pipeline (Session → Scout → Export) ──────');

  for (final scenario in [
    (name: 'Small', sessions: 5, routes: 8, glyphs: 4),
    (name: 'Medium', sessions: 20, routes: 25, glyphs: 6),
    (name: 'Large', sessions: 50, routes: 50, glyphs: 8),
  ]) {
    Scout.reset();
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);
    final routes = _chainRoutes(scenario.routes);

    final totalSw = Stopwatch()..start();

    // Phase 1: Feed sessions
    final feedSw = Stopwatch()..start();
    for (var i = 0; i < scenario.sessions; i++) {
      scout.analyzeSession(
        _session(
          id: 'pipe_$i',
          routes: routes,
          glyphsPerTableau: scenario.glyphs,
        ),
      );
    }
    feedSw.stop();

    // Phase 2: Generate stratagems
    final gauntletSw = Stopwatch()..start();
    var stratagemCount = 0;
    for (final outpost in terrain.outposts.values) {
      stratagemCount += Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.standard,
      ).length;
    }
    gauntletSw.stop();

    // Phase 3: Export
    final exportSw = Stopwatch()..start();
    final export = BlueprintExport.fromScout(scout: scout);
    export.toJsonString();
    export.toAiPrompt();
    exportSw.stop();

    totalSw.stop();

    print(
      '│  ${scenario.name.padRight(7)} '
      '(${scenario.sessions}s × ${scenario.routes}r):',
    );
    print(
      '│    Feed: ${_ms(feedSw)}  '
      'Gauntlet: ${_ms(gauntletSw)} ($stratagemCount plans)  '
      'Export: ${_ms(exportSw)}',
    );
    print(
      '│    Total: ${_ms(totalSw)}  '
      '(${terrain.screenCount} screens, '
      '${terrain.transitionCount} transitions)',
    );

    Scout.reset();
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}
