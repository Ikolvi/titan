// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:titan_envoy/titan_envoy.dart';

// =============================================================================
// Titan Envoy Benchmarks
// =============================================================================
//
// Run with: dart run benchmark/benchmark_envoy.dart
//
// Covers:
//  1. Missive — Request construction throughput
//  2. Dispatch — Response wrapper construction
//  3. CourierChain — Interceptor pipeline throughput
//  4. MemoryCache — Put/get/eviction performance
//  5. Gate — Throttle token acquire overhead
//  6. Parcel — Multipart form data construction
//  7. Recall — Cancel token check throughput
//  7. CachePolicy — Strategy evaluation
//  8. Body Encoding — JSON, binary, string
//  9. Response Decoding — JSON parse throughput
// 10. DedupCourier — Key hashing & dedup savings
// 11. CookieCourier — Cookie lookup scaling (0–1000)
// 12. MetricsCourier — Instrumentation overhead
// 13. HTTP Round-Trip — Loopback GET/POST/concurrent
// 14. Dispatch — Property access throughput
// =============================================================================

void main() async {
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  TITAN ENVOY BENCHMARKS');
  print('═══════════════════════════════════════════════════════');
  print('');

  _benchMissive();
  _benchDispatch();
  await _benchCourierChain();
  _benchMemoryCache();
  _benchParcel();
  _benchRecall();
  _benchCachePolicy();
  await _benchBodyEncoding();
  await _benchResponseDecoding();
  await _benchDedupCourier();
  await _benchCookieLookup();
  await _benchMetricsCourierOverhead();
  await _benchHttpRoundTrip();
  await _benchDispatchPropertyAccess();

  print('');
  print('═══════════════════════════════════════════════════════');
  print('  ALL ENVOY BENCHMARKS COMPLETE');
  print('═══════════════════════════════════════════════════════');
}

// ---------------------------------------------------------------------------
// 1. Missive — Request construction
// ---------------------------------------------------------------------------

void _benchMissive() {
  print('┌─ 1. Missive (Request Construction) ──────────────────');

  // a) Basic GET construction
  {
    for (final count in [1000, 10000, 100000]) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.example.com/users/$i'),
        );
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print(
        '│  GET construction (${_pad(count)}): ${_ms(sw)}'
        '  ($perOp µs/op)',
      );
    }
  }

  // b) Full POST with headers + query params
  {
    const iterations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      Missive(
        method: Method.post,
        uri: Uri.parse('https://api.example.com/users'),
        headers: {
          'Authorization': 'Bearer token-$i',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Request-Id': 'req-$i',
        },
        queryParameters: {'page': '$i', 'limit': '20'},
        data: {'name': 'User $i', 'email': 'user$i@test.com'},
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  POST + headers + params ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 2. Dispatch — Response construction
// ---------------------------------------------------------------------------

void _benchDispatch() {
  print('┌─ 2. Dispatch (Response Construction) ────────────────');

  final missive = Missive(
    method: Method.get,
    uri: Uri.parse('https://api.example.com/users'),
  );

  // a) Basic response construction
  {
    for (final count in [1000, 10000, 100000]) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Dispatch(
          statusCode: 200,
          headers: {
            'content-type': 'application/json',
            'x-request-id': 'req-$i',
          },
          missive: missive,
          data: {'id': i, 'name': 'User $i'},
          rawBody: '{"id": $i, "name": "User $i"}',
          duration: const Duration(milliseconds: 150),
        );
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print(
        '│  Dispatch construction (${_pad(count)}): ${_ms(sw)}'
        '  ($perOp µs/op)',
      );
    }
  }

  // b) Status check throughput
  {
    const iterations = 100000;
    final dispatches = <Dispatch>[
      Dispatch(statusCode: 200, headers: const {}, missive: missive),
      Dispatch(statusCode: 301, headers: const {}, missive: missive),
      Dispatch(statusCode: 404, headers: const {}, missive: missive),
      Dispatch(statusCode: 500, headers: const {}, missive: missive),
    ];
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final d = dispatches[i % 4];
      d.isSuccess;
      d.isRedirect;
      d.isClientError;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Status checks ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 3. CourierChain — Interceptor pipeline
// ---------------------------------------------------------------------------

Future<void> _benchCourierChain() async {
  print('┌─ 3. CourierChain (Interceptor Pipeline) ─────────────');

  final missive = Missive(
    method: Method.get,
    uri: Uri.parse('https://api.example.com/data'),
  );

  final mockResponse = Dispatch(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    missive: missive,
    data: {'result': 'ok'},
  );

  // No-op passthrough courier for measuring chain overhead
  final passthrough = _PassthroughCourier();

  for (final chainLength in [0, 1, 3, 5, 7]) {
    final couriers = List.generate(chainLength, (_) => passthrough);
    const iterations = 10000;

    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final chain = CourierChain(
        couriers: couriers,
        execute: (_) async => mockResponse,
      );
      await chain.proceed(missive);
    }
    sw.stop();

    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Chain($chainLength couriers) × $iterations: ${_ms(sw)}'
      '  ($perOp µs/req)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 4. MemoryCache — Put / Get / Eviction
// ---------------------------------------------------------------------------

void _benchMemoryCache() {
  print('┌─ 4. MemoryCache (Put / Get / Eviction) ─────────────');

  // a) Put throughput
  {
    for (final count in [100, 1000, 10000]) {
      final cache = MemoryCache(maxEntries: count + 100);
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        cache.put(
          'key-$i',
          CacheEntry(
            statusCode: 200,
            headers: const {},
            storedAt: DateTime.now(),
            data: 'value-$i',
          ),
        );
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print('│  Put (${_pad(count)}): ${_ms(sw)}  ($perOp µs/op)');
    }
  }

  // b) Get throughput (cache hits)
  {
    const size = 10000;
    final cache = MemoryCache(maxEntries: size + 100);
    for (var i = 0; i < size; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: DateTime.now(),
          data: 'value-$i',
        ),
      );
    }

    const lookups = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      cache.get('key-${i % size}');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print(
      '│  Get hits ($lookups from $size): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  // c) Get throughput (cache misses)
  {
    final cache = MemoryCache(maxEntries: 100);
    for (var i = 0; i < 100; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: DateTime.now(),
          data: 'value-$i',
        ),
      );
    }

    const lookups = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      cache.get('miss-$i');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print('│  Get misses ($lookups): ${_ms(sw)}  ($perOp µs/op)');
  }

  // d) LRU eviction (put beyond maxEntries)
  {
    const maxEntries = 1000;
    final cache = MemoryCache(maxEntries: maxEntries);

    // Fill cache
    for (var i = 0; i < maxEntries; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: DateTime.now(),
          data: 'value-$i',
        ),
      );
    }

    // Overflow by 1000, causing 1000 evictions
    const overflow = 1000;
    final sw = Stopwatch()..start();
    for (var i = maxEntries; i < maxEntries + overflow; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: DateTime.now(),
          data: 'value-$i',
        ),
      );
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / overflow).toStringAsFixed(2);
    print(
      '│  LRU eviction ($overflow overflows): ${_ms(sw)}'
      '  ($perOp µs/evict)',
    );
  }

  // e) TTL eviction
  {
    const count = 1000;
    final cache = MemoryCache(maxEntries: count + 100);
    final expired = DateTime.now().subtract(const Duration(hours: 1));
    for (var i = 0; i < count; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: expired,
          data: 'value-$i',
          ttl: const Duration(seconds: 1), // Already expired
        ),
      );
    }

    final sw = Stopwatch()..start();
    final evicted = cache.evictExpired();
    sw.stop();
    print('│  TTL eviction ($evicted expired): ${_ms(sw)}');
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 5. Parcel — Multipart form data
// ---------------------------------------------------------------------------

void _benchParcel() {
  print('┌─ 5. Parcel (Multipart Form Data) ────────────────────');

  // a) Field-only construction
  {
    for (final fields in [10, 50, 100]) {
      const iterations = 1000;
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        final parcel = Parcel();
        for (var f = 0; f < fields; f++) {
          parcel.addField('field_$f', 'value_$f');
        }
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
      print(
        '│  $fields fields × $iterations: ${_ms(sw)}'
        '  ($perOp µs/parcel)',
      );
    }
  }

  // b) fromMap construction
  {
    final fieldMap = {for (var i = 0; i < 50; i++) 'field_$i': 'value_$i'};
    const iterations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      Parcel.fromMap(fieldMap);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  fromMap(50 fields) × $iterations: ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  // c) toUrlEncoded
  {
    final parcel = Parcel();
    for (var i = 0; i < 50; i++) {
      parcel.addField('field_$i', 'value with spaces $i');
    }
    const iterations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      parcel.toUrlEncoded();
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  toUrlEncoded(50 fields) × $iterations: ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 6. Recall — Cancel token
// ---------------------------------------------------------------------------

void _benchRecall() {
  print('┌─ 6. Recall (Cancel Token) ───────────────────────────');

  // a) isCancelled check throughput (not cancelled)
  {
    final recall = Recall();
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      recall.isCancelled;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  isCancelled check ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  // b) Creation + cancellation throughput
  {
    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final recall = Recall();
      recall.cancel('reason $i');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Create + cancel ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 7. CachePolicy — Strategy evaluation
// ---------------------------------------------------------------------------

void _benchCachePolicy() {
  print('┌─ 7. CachePolicy (Strategy Evaluation) ──────────────');

  // a) Policy construction
  {
    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      switch (i % 4) {
        case 0:
          const CachePolicy.networkFirst();
        case 1:
          const CachePolicy.cacheFirst();
        case 2:
          const CachePolicy.networkOnly();
        case 3:
          CachePolicy.cacheFirst(ttl: Duration(minutes: i % 60));
      }
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Policy construction ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  // b) Strategy name access (enum)
  {
    const iterations = 1000000;
    const policies = [
      CachePolicy.networkFirst(),
      CachePolicy.cacheFirst(),
      CachePolicy.networkOnly(),
    ];
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      policies[i % 3].strategy.name;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Strategy name ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 8. Body Encoding — JSON, binary, string
// ---------------------------------------------------------------------------

Future<void> _benchBodyEncoding() async {
  print('┌─ 8. Body Encoding ────────────────────────────────────');

  // JSON map encoding
  {
    const iterations = 100000;
    final data = {'name': 'Kael', 'level': 42, 'guild': 'Ironforge'};
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      jsonEncode(data);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  JSON map encode:   ${_ms(sw)}  ($perOp µs/op)');
  }

  // JSON list encoding (50 items)
  {
    const iterations = 10000;
    final data = List.generate(50, (i) => {'id': i, 'value': 'item_$i'});
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      jsonEncode(data);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  JSON list encode:  ${_ms(sw)}  ($perOp µs/op)');
  }

  // Uint8List passthrough
  {
    const iterations = 1000000;
    final data = Uint8List(1024);
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      data.length;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
    print('│  Binary type check: ${_ms(sw)}  ($perOp µs/op)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 9. Response Decoding — JSON parse throughput
// ---------------------------------------------------------------------------

Future<void> _benchResponseDecoding() async {
  print('┌─ 9. Response Decoding ────────────────────────────────');

  // Small JSON decode
  {
    const iterations = 100000;
    const body = '{"id":1,"name":"Kael","level":42}';
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      jsonDecode(body);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  Small JSON decode: ${_ms(sw)}  ($perOp µs/op)');
  }

  // Large JSON decode (100 items)
  {
    const iterations = 10000;
    final items = List.generate(100, (i) => '{"id":$i,"name":"item_$i"}');
    final body = '[${items.join(",")}]';
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      jsonDecode(body);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  Large JSON decode: ${_ms(sw)}  ($perOp µs/op)');
  }

  // Nested JSON decode
  {
    const iterations = 10000;
    const body =
        '{"user":{"profile":{"settings":{"theme":"dark",'
        '"locale":"en","notifications":{"email":true,"push":false}}}}}';
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      jsonDecode(body);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  Nested JSON decode: ${_ms(sw)}  ($perOp µs/op)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 10. DedupCourier — Key hashing & dedup savings
// ---------------------------------------------------------------------------

Future<void> _benchDedupCourier() async {
  print('┌─ 10. DedupCourier ────────────────────────────────────');

  // Unique requests (no dedup)
  {
    const iterations = 10000;
    final dedup = DedupCourier();

    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final chain = CourierChain(
        couriers: [dedup],
        execute: (m) async => Dispatch(
          statusCode: 200,
          headers: const {},
          missive: m,
          data: {'i': i},
        ),
      );
      await chain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.example.com/unique/$i'),
        ),
      );
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  Unique keys:       ${_ms(sw)}  ($perOp µs/op)');
  }

  // Concurrent identical requests (dedup kicks in)
  {
    const batches = 1000;
    const concurrency = 10;
    final dedup = DedupCourier();
    var callCount = 0;

    final sw = Stopwatch()..start();
    for (var i = 0; i < batches; i++) {
      final futures = <Future<Dispatch>>[];
      for (var j = 0; j < concurrency; j++) {
        final chain = CourierChain(
          couriers: [dedup],
          execute: (m) async {
            callCount++;
            return Dispatch(
              statusCode: 200,
              headers: const {},
              missive: m,
              data: {'ok': true},
            );
          },
        );
        futures.add(
          chain.proceed(
            Missive(
              method: Method.get,
              uri: Uri.parse('https://api.example.com/shared/$i'),
            ),
          ),
        );
      }
      await Future.wait(futures);
    }
    sw.stop();

    final prBatch = (sw.elapsedMicroseconds / batches).toStringAsFixed(2);
    final ratio = (batches * concurrency) / callCount;
    print(
      '│  ${concurrency}x dedup batches: ${_ms(sw)}'
      '  ($prBatch µs/batch, ${ratio.toStringAsFixed(1)}x dedup)',
    );
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 11. CookieCourier — Cookie lookup scaling
// ---------------------------------------------------------------------------

Future<void> _benchCookieLookup() async {
  print('┌─ 11. CookieCourier Lookup ────────────────────────────');

  for (final cookieCount in [0, 10, 100, 1000]) {
    final cookie = CookieCourier();

    // Pre-populate cookies
    if (cookieCount > 0) {
      final setChain = CourierChain(
        couriers: [cookie],
        execute: (m) async {
          final cookieHeaders = List.generate(
            cookieCount,
            (i) => 'cookie_$i=value_$i; Path=/',
          ).join(', ');
          return Dispatch(
            statusCode: 200,
            data: <String, dynamic>{},
            headers: {'set-cookie': cookieHeaders},
            missive: m,
          );
        },
      );
      await setChain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.example.com/setup'),
        ),
      );
    }

    const iterations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final chain = CourierChain(
        couriers: [cookie],
        execute: (m) async =>
            Dispatch(statusCode: 200, headers: const {}, missive: m),
      );
      await chain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.example.com/bench'),
        ),
      );
    }
    sw.stop();

    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  ${_pad(cookieCount)} cookies: ${_ms(sw)}  ($perOp µs/op)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 12. MetricsCourier — Instrumentation overhead
// ---------------------------------------------------------------------------

Future<void> _benchMetricsCourierOverhead() async {
  print('┌─ 12. MetricsCourier Overhead ─────────────────────────');

  final missive = Missive(
    method: Method.get,
    uri: Uri.parse('https://api.example.com/bench'),
  );

  final mockResponse = Dispatch(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    missive: missive,
    data: {'ok': true},
    rawBody: '{"ok":true}',
  );

  // Without metrics (baseline)
  {
    const iterations = 50000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final chain = CourierChain(
        couriers: [],
        execute: (_) async => mockResponse,
      );
      await chain.proceed(missive);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  Without metrics:   ${_ms(sw)}  ($perOp µs/op)');
  }

  // With MetricsCourier
  {
    const iterations = 50000;
    final metrics = MetricsCourier(onMetric: (_) {});
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final chain = CourierChain(
        couriers: [metrics],
        execute: (_) async => mockResponse,
      );
      await chain.proceed(missive);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  With MetricsCourier: ${_ms(sw)}  ($perOp µs/op)');
  }

  // With MetricsCourier + toJson
  {
    const iterations = 50000;
    final metrics = MetricsCourier(onMetric: (m) => m.toJson());
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final chain = CourierChain(
        couriers: [metrics],
        execute: (_) async => mockResponse,
      );
      await chain.proceed(missive);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  Metrics + toJson:  ${_ms(sw)}  ($perOp µs/op)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 13. HTTP Round-Trip — Loopback
// ---------------------------------------------------------------------------

Future<void> _benchHttpRoundTrip() async {
  print('┌─ 13. HTTP Round-Trip (Loopback) ──────────────────────');

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) {
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write('{"id":1,"name":"Kael"}')
      ..close();
  });

  final envoy = Envoy(baseUrl: 'http://localhost:${server.port}');

  // Warm up
  for (var i = 0; i < 10; i++) {
    await envoy.get('/users/1');
  }

  // GET benchmark
  {
    const iterations = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await envoy.get('/users/1');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  GET round-trip:    ${_ms(sw)}  ($perOp µs/op)');
  }

  // POST benchmark
  {
    const iterations = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await envoy.post('/users', data: {'name': 'Kael', 'level': i});
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  POST round-trip:   ${_ms(sw)}  ($perOp µs/op)');
  }

  // Concurrent GET benchmark
  {
    const concurrent = 50;
    const batches = 20;
    final sw = Stopwatch()..start();
    for (var b = 0; b < batches; b++) {
      await Future.wait(
        List.generate(concurrent, (i) => envoy.get('/users/$i')),
      );
    }
    sw.stop();
    final total = concurrent * batches;
    final perOp = (sw.elapsedMicroseconds / total).toStringAsFixed(2);
    print('│  $concurrent-concurrent GET: ${_ms(sw)}  ($perOp µs/op)');
  }

  envoy.close();
  await server.close(force: true);

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 14. Dispatch — Property access throughput
// ---------------------------------------------------------------------------

Future<void> _benchDispatchPropertyAccess() async {
  print('┌─ 14. Dispatch Property Access ────────────────────────');

  final missive = Missive(
    method: Method.get,
    uri: Uri.parse('https://api.example.com/users'),
  );
  final dispatch = Dispatch(
    statusCode: 200,
    data: {
      'id': 1,
      'name': 'Kael',
      'items': [1, 2, 3],
    },
    rawBody: '{"id":1,"name":"Kael","items":[1,2,3]}',
    headers: {'content-type': 'application/json', 'content-length': '37'},
    missive: missive,
    duration: const Duration(milliseconds: 50),
  );

  // isSuccess
  {
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      dispatch.isSuccess;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
    print('│  isSuccess:         ${_ms(sw)}  ($perOp µs/op)');
  }

  // jsonMap
  {
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      dispatch.jsonMap;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
    print('│  jsonMap:           ${_ms(sw)}  ($perOp µs/op)');
  }

  // contentType
  {
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      dispatch.contentType;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
    print('│  contentType:       ${_ms(sw)}  ($perOp µs/op)');
  }

  // contentLength
  {
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      dispatch.contentLength;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
    print('│  contentLength:     ${_ms(sw)}  ($perOp µs/op)');
  }

  // parsedJson (re-parse each time)
  {
    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      dispatch.parsedJson;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print('│  parsedJson:        ${_ms(sw)}  ($perOp µs/op)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _PassthroughCourier extends Courier {
  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) {
    return chain.proceed(missive);
  }
}

/// Format stopwatch to ms string.
String _ms(Stopwatch sw) {
  if (sw.elapsedMilliseconds > 0) {
    return '${sw.elapsedMilliseconds} ms';
  }
  return '${sw.elapsedMicroseconds} µs';
}

/// Right-pad a number for alignment.
String _pad(int n) => n.toString().padLeft(6);
