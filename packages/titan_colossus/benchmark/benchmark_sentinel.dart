// ignore_for_file: avoid_print
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

// =============================================================================
// Sentinel Performance Benchmarks
// =============================================================================
//
// Run with: cd packages/titan_colossus && flutter test benchmark/benchmark_sentinel.dart
//
// Measures the overhead of Sentinel HTTP interception to ensure it adds
// negligible latency to real HTTP traffic. The Sentinel wraps HttpClient
// at the dart:io level — these benchmarks verify that wrapping cost is
// sub-microsecond per operation.
//
// Benchmarks:
//   1.  SentinelRecord creation throughput
//   2.  SentinelRecord toMetricJson() serialization
//   3.  SentinelRecord toDetailJson() serialization (with bodies)
//   4.  SentinelConfig URL filtering (exclude patterns)
//   5.  SentinelConfig URL filtering (include patterns)
//   6.  Sentinel install/uninstall cycle
//   7.  Record callback dispatch throughput
//   8.  Request body buffering (small payloads)
//   9.  Request body buffering (large payloads, capped)
//  10.  DevToolsBridge.timelinePageLoad() throughput
//  11.  DevToolsBridge.postTremorAlert() throughput
//  12.  DevToolsBridge.log() throughput
// =============================================================================

void main() {
  test('Sentinel Performance Benchmarks', () {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('  SENTINEL PERFORMANCE BENCHMARKS');
    print('═══════════════════════════════════════════════════════');
    print('');

    _benchRecordCreation();
    _benchRecordToMetricJson();
    _benchRecordToDetailJson();
    _benchUrlFilterExclude();
    _benchUrlFilterInclude();
    _benchInstallUninstall();
    _benchCallbackDispatch();
    _benchBodyBufferSmall();
    _benchBodyBufferLarge();
    _benchTimelinePageLoad();
    _benchPostTremorAlert();
    _benchDevToolsLog();

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  ALL SENTINEL BENCHMARKS COMPLETE');
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

SentinelRecord _makeRecord({List<int>? requestBody, List<int>? responseBody}) {
  return SentinelRecord(
    id: 'sentinel-42',
    method: 'GET',
    url: Uri.parse('https://api.questboard.io/quests/42'),
    timestamp: DateTime(2025, 1, 15, 12, 0, 0),
    duration: const Duration(milliseconds: 142),
    requestHeaders: const {
      'accept': ['application/json'],
      'authorization': ['Bearer eyJ...'],
      'user-agent': ['Envoy/1.0'],
    },
    requestBody: requestBody,
    requestSize: requestBody?.length ?? 0,
    requestContentType: 'application/json',
    statusCode: 200,
    responseHeaders: const {
      'content-type': ['application/json; charset=utf-8'],
      'x-request-id': ['req-abc-123'],
    },
    responseBody: responseBody,
    responseSize: responseBody?.length ?? 1024,
    responseContentType: 'application/json',
    success: true,
  );
}

// ---------------------------------------------------------------------------
// 1. SentinelRecord creation throughput
// ---------------------------------------------------------------------------

void _benchRecordCreation() {
  print('┌─ 1. SentinelRecord Creation Throughput ───────────────');

  for (final count in [100000, 1000000]) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      SentinelRecord(
        id: 'sentinel-$i',
        method: 'GET',
        url: Uri.parse('https://api.questboard.io/quests/$i'),
        timestamp: DateTime.now(),
        duration: Duration(milliseconds: 100 + (i % 200)),
        statusCode: 200,
        success: true,
      );
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print(
      '│  ${count.toString().padLeft(7)} records:  ${_ms(sw)}  ($perOp µs/record)',
    );
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 2. SentinelRecord toMetricJson() serialization
// ---------------------------------------------------------------------------

void _benchRecordToMetricJson() {
  print('┌─ 2. SentinelRecord toMetricJson() ────────────────────');

  final record = _makeRecord();
  const count = 100000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    record.toMetricJson();
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
  print('│  $count calls:  ${_ms(sw)}  ($perOp µs/op)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 3. SentinelRecord toDetailJson() with bodies
// ---------------------------------------------------------------------------

void _benchRecordToDetailJson() {
  print('┌─ 3. SentinelRecord toDetailJson() (with bodies) ─────');

  final requestBody = utf8.encode('{"title":"Shadow Wyrm Quest","reward":500}');
  final responseBody = utf8.encode(
    '{"id":42,"title":"Shadow Wyrm Quest","status":"active","heroes":[],'
    '"reward":500,"created":"2025-01-15T12:00:00Z"}',
  );
  final record = _makeRecord(
    requestBody: requestBody,
    responseBody: responseBody,
  );
  const count = 100000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    record.toDetailJson();
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
  print('│  $count calls:  ${_ms(sw)}  ($perOp µs/op)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 4. URL filtering — exclude patterns
// ---------------------------------------------------------------------------

void _benchUrlFilterExclude() {
  print('┌─ 4. URL Filter — Exclude Patterns ────────────────────');

  final excludeRegexes = [
    RegExp(r'localhost:864\d'),
    RegExp(r'/health$'),
    RegExp(r'/ping$'),
    RegExp(r'analytics\.questboard\.io'),
  ];

  final urls = [
    Uri.parse('https://api.questboard.io/quests'),
    Uri.parse('https://api.questboard.io/heroes/7'),
    Uri.parse('http://localhost:8642/health'),
    Uri.parse('https://analytics.questboard.io/event'),
    Uri.parse('https://api.questboard.io/quests/42/comments'),
  ];

  const iterations = 1000000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final url = urls[i % urls.length];
    final urlStr = url.toString();
    var captured = true;
    for (final regex in excludeRegexes) {
      if (regex.hasMatch(urlStr)) {
        captured = false;
        break;
      }
    }
    // Prevent optimization
    if (captured && i < 0) print('');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
  print('│  $iterations URLs × 4 patterns:  ${_ms(sw)}  ($perOp µs/url)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 5. URL filtering — include patterns
// ---------------------------------------------------------------------------

void _benchUrlFilterInclude() {
  print('┌─ 5. URL Filter — Include Patterns ────────────────────');

  final includeRegexes = [
    RegExp(r'api\.questboard\.io'),
    RegExp(r'auth\.questboard\.io'),
  ];
  final excludeRegexes = [RegExp(r'/health$')];

  final urls = [
    Uri.parse('https://api.questboard.io/quests'),
    Uri.parse('https://auth.questboard.io/token'),
    Uri.parse('https://cdn.questboard.io/images/hero.png'),
    Uri.parse('https://api.questboard.io/health'),
    Uri.parse('https://api.questboard.io/quests/42'),
  ];

  const iterations = 1000000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final url = urls[i % urls.length];
    final urlStr = url.toString();

    // Check excludes first
    var excluded = false;
    for (final regex in excludeRegexes) {
      if (regex.hasMatch(urlStr)) {
        excluded = true;
        break;
      }
    }
    if (excluded) continue;

    // Check includes
    var included = false;
    for (final regex in includeRegexes) {
      if (regex.hasMatch(urlStr)) {
        included = true;
        break;
      }
    }
    if (included && i < 0) print('');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
  print('│  $iterations URLs × 3 patterns:  ${_ms(sw)}  ($perOp µs/url)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 6. Sentinel install/uninstall cycle
// ---------------------------------------------------------------------------

void _benchInstallUninstall() {
  print('┌─ 6. Sentinel Install/Uninstall Cycle ─────────────────');

  const count = 10000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    Sentinel.install(onRecord: (_) {}, chainPreviousOverrides: false);
    Sentinel.uninstall();
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
  print('│  $count cycles:  ${_ms(sw)}  ($perOp µs/cycle)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 7. Record callback dispatch throughput
// ---------------------------------------------------------------------------

void _benchCallbackDispatch() {
  print('┌─ 7. Record Callback Dispatch ─────────────────────────');

  final records = <SentinelRecord>[];
  var maxRecords = 500;

  final record = _makeRecord();
  const iterations = 100000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    records.add(record);
    while (records.length > maxRecords) {
      records.removeAt(0);
    }
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
  print(
    '│  $iterations dispatches (cap=$maxRecords):  ${_ms(sw)}  ($perOp µs/dispatch)',
  );

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 8. Request body buffering — small payloads
// ---------------------------------------------------------------------------

void _benchBodyBufferSmall() {
  print('┌─ 8. Body Buffering — Small Payloads ──────────────────');

  final payload = utf8.encode('{"title":"Quest","reward":100}');
  const maxCapture = 64 * 1024;
  const iterations = 100000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final buffer = <int>[];
    if (buffer.length < maxCapture) {
      final remaining = maxCapture - buffer.length;
      buffer.addAll(
        payload.length <= remaining ? payload : payload.sublist(0, remaining),
      );
    }
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
  print(
    '│  $iterations × ${payload.length}B payloads:  ${_ms(sw)}  ($perOp µs/buffer)',
  );

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 9. Request body buffering — large payloads (capped)
// ---------------------------------------------------------------------------

void _benchBodyBufferLarge() {
  print('┌─ 9. Body Buffering — Large Payloads (64KB cap) ──────');

  // 128KB payload, but only 64KB will be buffered
  final payload = List<int>.filled(128 * 1024, 0x41);
  const maxCapture = 64 * 1024;
  const iterations = 1000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final buffer = <int>[];
    // Simulate chunked writes (4KB chunks)
    for (var offset = 0; offset < payload.length; offset += 4096) {
      final end = (offset + 4096).clamp(0, payload.length);
      final chunk = payload.sublist(offset, end);
      if (buffer.length < maxCapture) {
        final remaining = maxCapture - buffer.length;
        buffer.addAll(
          chunk.length <= remaining ? chunk : chunk.sublist(0, remaining),
        );
      }
    }
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
  print(
    '│  $iterations × 128KB payloads (capped to 64KB):  ${_ms(sw)}  ($perOp µs/buffer)',
  );

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 10. DevToolsBridge.timelinePageLoad() throughput
// ---------------------------------------------------------------------------

void _benchTimelinePageLoad() {
  print('┌─ 10. DevToolsBridge.timelinePageLoad() ───────────────');

  const count = 100000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    DevToolsBridge.timelinePageLoad(
      '/quests/$i',
      Duration(milliseconds: 100 + (i % 300)),
    );
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
  print('│  $count calls:  ${_ms(sw)}  ($perOp µs/call)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 11. DevToolsBridge.postTremorAlert() throughput
// ---------------------------------------------------------------------------

void _benchPostTremorAlert() {
  print('┌─ 11. DevToolsBridge.postTremorAlert() ────────────────');

  const count = 100000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    DevToolsBridge.postTremorAlert(
      'fps_low',
      'frame',
      'warning',
      'FPS dropped to 42',
    );
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
  print('│  $count calls:  ${_ms(sw)}  ($perOp µs/call)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 12. DevToolsBridge.log() throughput
// ---------------------------------------------------------------------------

void _benchDevToolsLog() {
  print('┌─ 12. DevToolsBridge.log() ────────────────────────────');

  const count = 100000;

  final sw = Stopwatch()..start();
  for (var i = 0; i < count; i++) {
    DevToolsBridge.log('Sentinel captured 502 from /api/heroes/$i');
  }
  sw.stop();

  final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
  print('│  $count calls:  ${_ms(sw)}  ($perOp µs/call)');

  print('└───────────────────────────────────────────────────────');
  print('');
}
