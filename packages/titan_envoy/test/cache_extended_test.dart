import 'dart:async';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

/// Extensive tests for CacheCourier — staleWhileRevalidate, networkOnly,
/// TTL, cache key collisions, non-GET caching, and edge cases.
void main() {
  late MemoryCache cache;
  late CacheCourier courier;

  /// Creates a fake executor that returns a response with a body.
  Future<Dispatch> Function(Missive) executor({
    int statusCode = 200,
    Object? data,
    Map<String, String>? headers,
  }) {
    return (Missive m) async => Dispatch(
      statusCode: statusCode,
      data: data ?? {'source': 'network'},
      rawBody: '{"source":"network"}',
      headers: headers ?? {},
      missive: m,
    );
  }

  /// Creates a failing executor.
  Future<Dispatch> Function(Missive) failingExecutor() {
    return (Missive m) async => throw EnvoyError.connectionError(missive: m);
  }

  Missive testGet(String path, {Map<String, Object?>? extra}) {
    return Missive(
      method: Method.get,
      uri: Uri.parse('https://api.test.com$path'),
      extra: extra ?? const {},
    );
  }

  Missive testPost(String path) {
    return Missive(
      method: Method.post,
      uri: Uri.parse('https://api.test.com$path'),
      data: {'test': true},
    );
  }

  setUp(() {
    cache = MemoryCache(maxEntries: 100);
    courier = CacheCourier(
      cache: cache,
      defaultPolicy: CachePolicy.cacheFirst(ttl: Duration(minutes: 5)),
    );
  });

  // ═══════════════════════════════════════════════════════════════════
  // staleWhileRevalidate
  // ═══════════════════════════════════════════════════════════════════

  group('staleWhileRevalidate strategy', () {
    test('serves stale cache immediately and revalidates', () async {
      // Pre-populate cache with an entry that is still valid per its own TTL
      // (MemoryCache auto-evicts expired entries on read). The SWR strategy
      // returns whatever is in cache and revalidates in the background.
      cache.put(
        'GET:https://api.test.com/data',
        CacheEntry(
          statusCode: 200,
          data: {'source': 'cached'},
          rawBody: '{"source":"cached"}',
          headers: {},
          storedAt: DateTime.now().subtract(Duration(minutes: 1)),
          ttl: Duration(hours: 1),
        ),
      );

      var networkCalled = false;
      final swrCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.staleWhileRevalidate(
          ttl: Duration(minutes: 5),
        ),
      );

      final chain = CourierChain(
        couriers: [swrCourier],
        execute: (m) async {
          networkCalled = true;
          return Dispatch(
            statusCode: 200,
            data: {'source': 'fresh'},
            rawBody: '{"source":"fresh"}',
            headers: {},
            missive: m,
          );
        },
      );

      final dispatch = await chain.proceed(testGet('/data'));

      // Should return cached data immediately
      expect(dispatch.data, {'source': 'cached'});
      expect(dispatch.headers['x-envoy-cache'], 'hit');

      // Wait for background revalidation
      await Future<void>.delayed(Duration(milliseconds: 100));
      expect(networkCalled, isTrue);

      // New data should be in cache
      final updated = cache.get('GET:https://api.test.com/data');
      expect(updated?.data, {'source': 'fresh'});
    });

    test('fetches from network when cache is empty', () async {
      final swrCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.staleWhileRevalidate(
          ttl: Duration(minutes: 5),
        ),
      );

      final chain = CourierChain(
        couriers: [swrCourier],
        execute: executor(data: {'source': 'network'}),
      );

      final dispatch = await chain.proceed(testGet('/no-cache'));
      expect(dispatch.data, {'source': 'network'});
      expect(dispatch.headers.containsKey('x-envoy-cache'), isFalse);
    });

    test(
      'background revalidation failure does not affect returned data',
      () async {
        cache.put(
          'GET:https://api.test.com/flaky',
          CacheEntry(
            statusCode: 200,
            data: {'source': 'stale'},
            rawBody: '{"source":"stale"}',
            headers: {},
            storedAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
        );

        final swrCourier = CacheCourier(
          cache: cache,
          defaultPolicy: CachePolicy.staleWhileRevalidate(),
        );

        final chain = CourierChain(
          couriers: [swrCourier],
          execute: failingExecutor(),
        );

        // Should still return stale data even though revalidation fails
        final dispatch = await chain.proceed(testGet('/flaky'));
        expect(dispatch.data, {'source': 'stale'});
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════
  // networkOnly
  // ═══════════════════════════════════════════════════════════════════

  group('networkOnly strategy', () {
    test('always fetches from network', () async {
      final noCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.networkOnly(),
      );

      final chain = CourierChain(
        couriers: [noCourier],
        execute: executor(data: {'live': true}),
      );

      final dispatch = await chain.proceed(testGet('/live'));
      expect(dispatch.data, {'live': true});
    });

    test('caches the result for future fallback', () async {
      final noCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.networkOnly(),
      );

      final chain = CourierChain(
        couriers: [noCourier],
        execute: executor(data: {'saved': true}),
      );

      await chain.proceed(testGet('/save-me'));

      // Verify data was cached
      final entry = cache.get('GET:https://api.test.com/save-me');
      expect(entry, isNotNull);
      expect(entry?.data, {'saved': true});
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // cacheOnly
  // ═══════════════════════════════════════════════════════════════════

  group('cacheOnly strategy', () {
    test('throws when cache is empty', () async {
      final coCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.cacheOnly(),
      );

      final chain = CourierChain(couriers: [coCourier], execute: executor());

      expect(
        () => chain.proceed(testGet('/missing')),
        throwsA(isA<StateError>()),
      );
    });

    test('returns cached data without network', () async {
      cache.put(
        'GET:https://api.test.com/offline',
        CacheEntry(
          statusCode: 200,
          data: {'offline': true},
          rawBody: '{"offline":true}',
          headers: {},
          storedAt: DateTime.now(),
        ),
      );

      var networkCalled = false;
      final coCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.cacheOnly(),
      );

      final chain = CourierChain(
        couriers: [coCourier],
        execute: (m) async {
          networkCalled = true;
          return Dispatch(statusCode: 200, data: {}, headers: {}, missive: m);
        },
      );

      final dispatch = await chain.proceed(testGet('/offline'));
      expect(dispatch.data, {'offline': true});
      expect(networkCalled, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // TTL & Expiration
  // ═══════════════════════════════════════════════════════════════════

  group('TTL and expiration', () {
    test('expired entry triggers fresh fetch for cacheFirst', () async {
      cache.put(
        'GET:https://api.test.com/stale',
        CacheEntry(
          statusCode: 200,
          data: {'state': 'old'},
          rawBody: '{"state":"old"}',
          headers: {},
          // Stored 10 minutes ago
          storedAt: DateTime.now().subtract(Duration(minutes: 10)),
          ttl: Duration(minutes: 5),
        ),
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: executor(data: {'state': 'fresh'}),
      );

      final dispatch = await chain.proceed(testGet('/stale'));
      // Should fetch fresh because entry is expired
      expect(dispatch.data, {'state': 'fresh'});
    });

    test('null TTL means entry never expires', () async {
      final neverExpireCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.cacheFirst(),
      );

      cache.put(
        'GET:https://api.test.com/eternal',
        CacheEntry(
          statusCode: 200,
          data: {'source': 'ancient'},
          rawBody: '{"source":"ancient"}',
          headers: {},
          storedAt: DateTime.now().subtract(Duration(days: 365)),
          // no TTL
        ),
      );

      final chain = CourierChain(
        couriers: [neverExpireCourier],
        execute: executor(data: {'source': 'new'}),
      );

      final dispatch = await chain.proceed(testGet('/eternal'));
      // Should use cached because no TTL = never expires
      expect(dispatch.data, {'source': 'ancient'});
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Non-GET methods
  // ═══════════════════════════════════════════════════════════════════

  group('Non-GET methods', () {
    test('POST requests skip cache by default', () async {
      var networkCalled = false;

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          networkCalled = true;
          return Dispatch(
            statusCode: 201,
            data: {'created': true},
            headers: {},
            missive: m,
          );
        },
      );

      final dispatch = await chain.proceed(testPost('/users'));
      expect(networkCalled, isTrue);
      expect(dispatch.statusCode, 201);
    });

    test('custom cacheableMethods enables POST caching', () async {
      final postCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.cacheFirst(ttl: Duration(minutes: 5)),
        cacheableMethods: {Method.get, Method.post},
      );

      final chain = CourierChain(
        couriers: [postCourier],
        execute: executor(statusCode: 201, data: {'cached-post': true}),
      );

      // First call — network
      await chain.proceed(testPost('/users'));

      // Second call — should serve from cache
      final second = CourierChain(
        couriers: [postCourier],
        execute: (m) async => throw StateError('Should not be called'),
      );

      final dispatch = await second.proceed(testPost('/users'));
      expect(dispatch.data, {'cached-post': true});
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Per-request policy override
  // ═══════════════════════════════════════════════════════════════════

  group('Per-request policy override', () {
    test('policyKey overrides default strategy', () async {
      // Default is cacheFirst, override to networkOnly
      final chain = CourierChain(
        couriers: [courier],
        execute: executor(data: {'from': 'network'}),
      );

      final dispatch = await chain.proceed(
        testGet(
          '/override',
          extra: {CacheCourier.policyKey: CachePolicy.networkOnly()},
        ),
      );

      expect(dispatch.data, {'from': 'network'});
    });

    test('skipKey bypasses cache entirely', () async {
      // Pre-populate cache
      cache.put(
        'GET:https://api.test.com/skipped',
        CacheEntry(
          statusCode: 200,
          data: {'source': 'cached'},
          rawBody: '{}',
          headers: {},
          storedAt: DateTime.now(),
        ),
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: executor(data: {'source': 'fresh'}),
      );

      final dispatch = await chain.proceed(
        testGet('/skipped', extra: {CacheCourier.skipKey: true}),
      );

      expect(dispatch.data, {'source': 'fresh'});
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Cache key
  // ═══════════════════════════════════════════════════════════════════

  group('Cache key', () {
    test('different query params produce different keys', () async {
      var callCount = 0;

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          callCount++;
          return Dispatch(
            statusCode: 200,
            data: {'call': callCount},
            rawBody: '{}',
            headers: {},
            missive: m,
          );
        },
      );

      await chain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.test.com/data'),
          queryParameters: {'page': '1'},
        ),
      );

      final chain2 = CourierChain(
        couriers: [courier],
        execute: (m) async {
          callCount++;
          return Dispatch(
            statusCode: 200,
            data: {'call': callCount},
            rawBody: '{}',
            headers: {},
            missive: m,
          );
        },
      );

      await chain2.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.test.com/data'),
          queryParameters: {'page': '2'},
        ),
      );

      // Both should have hit network (different keys)
      expect(callCount, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // networkFirst fallback
  // ═══════════════════════════════════════════════════════════════════

  group('networkFirst fallback', () {
    test('falls back to cache on network error', () async {
      cache.put(
        'GET:https://api.test.com/fallback',
        CacheEntry(
          statusCode: 200,
          data: {'fallback': true},
          rawBody: '{}',
          headers: {},
          storedAt: DateTime.now(),
        ),
      );

      final nfCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.networkFirst(ttl: Duration(minutes: 5)),
      );

      final chain = CourierChain(
        couriers: [nfCourier],
        execute: failingExecutor(),
      );

      final dispatch = await chain.proceed(testGet('/fallback'));
      expect(dispatch.data, {'fallback': true});
    });

    test('rethrows when no cache and network error', () async {
      final nfCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.networkFirst(),
      );

      final chain = CourierChain(
        couriers: [nfCourier],
        execute: failingExecutor(),
      );

      expect(
        () => chain.proceed(testGet('/no-cache-no-network')),
        throwsA(isA<EnvoyError>()),
      );
    });

    test('stores successful network response', () async {
      final nfCourier = CacheCourier(
        cache: cache,
        defaultPolicy: CachePolicy.networkFirst(ttl: Duration(minutes: 5)),
      );

      final chain = CourierChain(
        couriers: [nfCourier],
        execute: executor(data: {'stored': true}),
      );

      await chain.proceed(testGet('/store-me'));

      final entry = cache.get('GET:https://api.test.com/store-me');
      expect(entry, isNotNull);
      expect(entry?.data, {'stored': true});
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Error response not cached
  // ═══════════════════════════════════════════════════════════════════

  group('Error responses', () {
    test('does not cache 4xx responses', () async {
      final chain = CourierChain(
        couriers: [courier],
        execute: executor(statusCode: 404, data: {'error': 'not found'}),
      );

      await chain.proceed(testGet('/not-found'));

      final entry = cache.get('GET:https://api.test.com/not-found');
      expect(entry, isNull);
    });

    test('does not cache 5xx responses', () async {
      final chain = CourierChain(
        couriers: [courier],
        execute: executor(statusCode: 500, data: {'error': 'server error'}),
      );

      await chain.proceed(testGet('/server-error'));

      final entry = cache.get('GET:https://api.test.com/server-error');
      expect(entry, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // CachePolicy toString
  // ═══════════════════════════════════════════════════════════════════

  group('CachePolicy', () {
    test('toString includes strategy and TTL', () {
      final policy = CachePolicy.cacheFirst(ttl: Duration(minutes: 5));
      expect(policy.toString(), contains('cacheFirst'));
      expect(policy.toString(), contains('0:05:00'));
    });

    test('toString with null TTL', () {
      final policy = CachePolicy.networkFirst();
      expect(policy.toString(), contains('networkFirst'));
      expect(policy.toString(), contains('null'));
    });

    test('all strategies are constructable', () {
      expect(CachePolicy.cacheFirst().strategy, CacheStrategy.cacheFirst);
      expect(CachePolicy.networkFirst().strategy, CacheStrategy.networkFirst);
      expect(CachePolicy.cacheOnly().strategy, CacheStrategy.cacheOnly);
      expect(CachePolicy.networkOnly().strategy, CacheStrategy.networkOnly);
      expect(
        CachePolicy.staleWhileRevalidate().strategy,
        CacheStrategy.staleWhileRevalidate,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // MemoryCache edge cases
  // ═══════════════════════════════════════════════════════════════════

  group('MemoryCache edge cases', () {
    test('evicts oldest entry when at capacity', () async {
      final smallCache = MemoryCache(maxEntries: 3);

      for (var i = 0; i < 5; i++) {
        smallCache.put(
          'key$i',
          CacheEntry(
            statusCode: 200,
            data: i,
            headers: {},
            storedAt: DateTime.now(),
          ),
        );
      }

      // First two should be evicted
      expect(smallCache.get('key0'), isNull);
      expect(smallCache.get('key1'), isNull);
      // Last three should exist
      expect(smallCache.get('key2'), isNotNull);
      expect(smallCache.get('key3'), isNotNull);
      expect(smallCache.get('key4'), isNotNull);
      expect(smallCache.size, 3);
    });

    test('overwriting existing key does not evict', () async {
      final smallCache = MemoryCache(maxEntries: 2);

      smallCache.put(
        'key',
        CacheEntry(
          statusCode: 200,
          data: 'first',
          headers: {},
          storedAt: DateTime.now(),
        ),
      );

      smallCache.put(
        'key',
        CacheEntry(
          statusCode: 200,
          data: 'second',
          headers: {},
          storedAt: DateTime.now(),
        ),
      );

      expect(smallCache.size, 1);
      final entry = smallCache.get('key');
      expect(entry?.data, 'second');
    });

    test('evictExpired removes only expired entries', () async {
      cache.put(
        'fresh',
        CacheEntry(
          statusCode: 200,
          data: 'fresh',
          headers: {},
          storedAt: DateTime.now(),
          ttl: Duration(hours: 1),
        ),
      );

      cache.put(
        'expired',
        CacheEntry(
          statusCode: 200,
          data: 'expired',
          headers: {},
          storedAt: DateTime.now().subtract(Duration(hours: 2)),
          ttl: Duration(hours: 1),
        ),
      );

      final evicted = cache.evictExpired();
      expect(evicted, 1);
      expect(cache.get('fresh'), isNotNull);
      expect(cache.get('expired'), isNull);
    });

    test('keys returns all stored keys', () {
      cache.put(
        'a',
        CacheEntry(statusCode: 200, headers: {}, storedAt: DateTime.now()),
      );
      cache.put(
        'b',
        CacheEntry(statusCode: 200, headers: {}, storedAt: DateTime.now()),
      );

      expect(cache.keys.toSet(), {'a', 'b'});
    });

    test('CacheEntry.isExpired with no TTL returns false', () {
      final entry = CacheEntry(
        statusCode: 200,
        headers: {},
        storedAt: DateTime.now().subtract(Duration(days: 365)),
      );
      expect(entry.isExpired, isFalse);
    });

    test('CacheEntry.toJson and fromJson round-trip', () {
      final entry = CacheEntry(
        statusCode: 200,
        rawBody: '{"test":true}',
        headers: {'content-type': 'application/json'},
        storedAt: DateTime.utc(2025, 1, 1),
        ttl: Duration(minutes: 30),
      );

      final json = entry.toJson();
      final restored = CacheEntry.fromJson(json);

      expect(restored.statusCode, 200);
      expect(restored.rawBody, '{"test":true}');
      expect(restored.headers['content-type'], 'application/json');
      expect(restored.storedAt, DateTime.utc(2025, 1, 1));
      expect(restored.ttl, Duration(minutes: 30));
    });

    test('CacheEntry.fromJson without TTL', () {
      final json = {
        'statusCode': 200,
        'rawBody': null,
        'headers': <String, String>{},
        'storedAt': '2025-01-01T00:00:00.000Z',
      };

      final entry = CacheEntry.fromJson(json);
      expect(entry.ttl, isNull);
      expect(entry.isExpired, isFalse);
    });
  });
}
