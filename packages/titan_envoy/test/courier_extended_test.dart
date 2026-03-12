import 'dart:async';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

/// Extensive tests for RetryCourier, AuthCourier, DedupCourier, and
/// CookieCourier — covering edge cases, advanced configurations,
/// and integration scenarios.
void main() {
  Missive testGet(String path) {
    return Missive(
      method: Method.get,
      uri: Uri.parse('https://api.test.com$path'),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RetryCourier — Advanced
  // ═══════════════════════════════════════════════════════════════════

  group('RetryCourier — Advanced', () {
    test('maxDelay caps exponential growth', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 5,
        retryDelay: Duration(milliseconds: 10),
        backoffMultiplier: 10.0,
        maxDelay: Duration(milliseconds: 50),
        addJitter: false,
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.connectionError(missive: m);
        },
      );

      final sw = Stopwatch()..start();
      try {
        await chain.proceed(testGet('/test'));
      } on EnvoyError {
        // Expected
      }
      sw.stop();

      // 6 total attempts (initial + 5 retries)
      expect(attempts, 6);

      // Total delay should be bounded by maxDelay * retries
      // Without cap: 10 + 100 + 1000 + 10000 + 100000 ms
      // With maxDelay=50ms: 10 + 50 + 50 + 50 + 50 = ~210ms
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('retryOnTimeout=true retries timeout errors', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 2,
        retryDelay: Duration(milliseconds: 1),
        addJitter: false,
        retryOnTimeout: true,
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.timeout(missive: m);
        },
      );

      try {
        await chain.proceed(testGet('/test'));
      } on EnvoyError {
        // Expected
      }

      expect(attempts, 3); // initial + 2 retries
    });

    test('retryOnTimeout=false does not retry timeout errors', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 3,
        retryDelay: Duration(milliseconds: 1),
        retryOnTimeout: false,
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.timeout(missive: m);
        },
      );

      try {
        await chain.proceed(testGet('/test'));
      } on EnvoyError {
        // Expected
      }

      expect(attempts, 1); // No retries
    });

    test('retryOnConnectionError=false stops retries', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 3,
        retryDelay: Duration(milliseconds: 1),
        retryOnConnectionError: false,
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.connectionError(missive: m);
        },
      );

      try {
        await chain.proceed(testGet('/test'));
      } on EnvoyError {
        // Expected
      }

      expect(attempts, 1);
    });

    test('does not retry cancelled requests', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 3,
        retryDelay: Duration(milliseconds: 1),
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.cancelled(missive: m);
        },
      );

      try {
        await chain.proceed(testGet('/test'));
      } on EnvoyError {
        // Expected
      }

      expect(attempts, 1);
    });

    test('does not retry parseError', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 3,
        retryDelay: Duration(milliseconds: 1),
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.parseError(missive: m);
        },
      );

      try {
        await chain.proceed(testGet('/test'));
      } on EnvoyError {
        // Expected
      }

      expect(attempts, 1);
    });

    test('custom shouldRetry predicate overrides defaults', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 3,
        retryDelay: Duration(milliseconds: 1),
        shouldRetry: (error, attempt) {
          return error.type == EnvoyErrorType.parseError; // override!
        },
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.parseError(missive: m);
        },
      );

      try {
        await chain.proceed(testGet('/test'));
      } on EnvoyError {
        // Expected
      }

      expect(attempts, 4); // Now retries parseError
    });

    test('retries on specific status codes from response', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 2,
        retryDelay: Duration(milliseconds: 1),
        addJitter: false,
        retryOn: {503},
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          return Dispatch(
            statusCode: 503,
            data: 'Service Unavailable',
            headers: {},
            missive: m,
          );
        },
      );

      final dispatch = await chain.proceed(testGet('/test'));

      // Should retry 2 times + initial = 3 total
      expect(attempts, 3);
      expect(dispatch.statusCode, 503);
    });

    test('stops retrying on success', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 5,
        retryDelay: Duration(milliseconds: 1),
        addJitter: false,
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          if (attempts < 3) {
            throw EnvoyError.connectionError(missive: m);
          }
          return Dispatch(
            statusCode: 200,
            data: {'ok': true},
            headers: {},
            missive: m,
          );
        },
      );

      final dispatch = await chain.proceed(testGet('/test'));
      expect(attempts, 3);
      expect(dispatch.statusCode, 200);
    });

    test('429 is in default retry set', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 1,
        retryDelay: Duration(milliseconds: 1),
        addJitter: false,
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          return Dispatch(
            statusCode: 429,
            data: 'Rate limited',
            headers: {},
            missive: m,
          );
        },
      );

      await chain.proceed(testGet('/test'));
      expect(attempts, 2); // initial + 1 retry
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // AuthCourier — Advanced
  // ═══════════════════════════════════════════════════════════════════

  group('AuthCourier — Advanced', () {
    test('maxRefreshAttempts limits refresh cycles', () async {
      var refreshCount = 0;
      final courier = AuthCourier(
        tokenProvider: () => 'expired-token',
        maxRefreshAttempts: 2,
        onUnauthorized: () {
          refreshCount++;
          return 'still-expired-token';
        },
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 401,
            data: 'Unauthorized',
            headers: {},
            missive: m,
          );
        },
      );

      final dispatch = await chain.proceed(testGet('/test'));
      expect(dispatch.statusCode, 401);
      expect(refreshCount, 2);
    });

    test('onUnauthorized returning null stops retry', () async {
      var refreshCount = 0;
      final courier = AuthCourier(
        tokenProvider: () => 'expired-token',
        maxRefreshAttempts: 5,
        onUnauthorized: () {
          refreshCount++;
          return null; // Can't refresh
        },
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 401,
            data: 'Unauthorized',
            headers: {},
            missive: m,
          );
        },
      );

      final dispatch = await chain.proceed(testGet('/test'));
      expect(dispatch.statusCode, 401);
      expect(refreshCount, 1); // Only one attempt
    });

    test('null token provider skips auth header', () async {
      final courier = AuthCourier(tokenProvider: () => null);

      String? sentAuth;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentAuth = m.headers['Authorization'];
          return Dispatch(
            statusCode: 200,
            data: {'ok': true},
            headers: {},
            missive: m,
          );
        },
      );

      await chain.proceed(testGet('/test'));
      expect(sentAuth, isNull);
    });

    test('empty token skips auth header', () async {
      final courier = AuthCourier(tokenProvider: () => '');

      String? sentAuth;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentAuth = m.headers['Authorization'];
          return Dispatch(
            statusCode: 200,
            data: {'ok': true},
            headers: {},
            missive: m,
          );
        },
      );

      await chain.proceed(testGet('/test'));
      expect(sentAuth, isNull);
    });

    test('custom header name and prefix', () async {
      final courier = AuthCourier(
        tokenProvider: () => 'my-api-key',
        headerName: 'X-API-Key',
        tokenPrefix: '', // No prefix
      );

      String? sentHeader;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentHeader = m.headers['X-API-Key'];
          return Dispatch(
            statusCode: 200,
            data: {'ok': true},
            headers: {},
            missive: m,
          );
        },
      );

      await chain.proceed(testGet('/test'));
      expect(sentHeader, 'my-api-key');
    });

    test('async token provider', () async {
      final courier = AuthCourier(
        tokenProvider: () async {
          await Future<void>.delayed(Duration(milliseconds: 10));
          return 'async-token';
        },
      );

      String? sentAuth;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentAuth = m.headers['Authorization'];
          return Dispatch(statusCode: 200, data: {}, headers: {}, missive: m);
        },
      );

      await chain.proceed(testGet('/test'));
      expect(sentAuth, 'Bearer async-token');
    });

    test('successful refresh retries and succeeds', () async {
      var attempt = 0;
      final courier = AuthCourier(
        tokenProvider: () => 'old-token',
        onUnauthorized: () => 'new-token',
      );

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempt++;
          final token = m.headers['Authorization'];
          if (token == 'Bearer old-token') {
            return Dispatch(
              statusCode: 401,
              data: 'Unauthorized',
              headers: {},
              missive: m,
            );
          }
          return Dispatch(
            statusCode: 200,
            data: {'token': token},
            headers: {},
            missive: m,
          );
        },
      );

      final dispatch = await chain.proceed(testGet('/test'));
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['token'], 'Bearer new-token');
      expect(attempt, 2);
    });

    test('401 as EnvoyError.badResponse triggers refresh', () async {
      var refreshed = false;
      final courier = AuthCourier(
        tokenProvider: () => 'token',
        onUnauthorized: () {
          refreshed = true;
          return 'fresh-token';
        },
      );

      var attempt = 0;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempt++;
          if (attempt == 1) {
            throw EnvoyError.badResponse(
              missive: m,
              dispatch: Dispatch(statusCode: 401, headers: {}, missive: m),
            );
          }
          return Dispatch(
            statusCode: 200,
            data: {'refreshed': true},
            headers: {},
            missive: m,
          );
        },
      );

      final dispatch = await chain.proceed(testGet('/test'));
      expect(refreshed, isTrue);
      expect(dispatch.statusCode, 200);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // DedupCourier — Advanced
  // ═══════════════════════════════════════════════════════════════════

  group('DedupCourier — Advanced', () {
    test('TTL > 0 keeps dedup entry after completion', () async {
      final courier = DedupCourier(ttl: Duration(milliseconds: 200));
      var callCount = 0;

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          callCount++;
          return Dispatch(
            statusCode: 200,
            data: {'call': callCount},
            headers: {},
            missive: m,
          );
        },
      );

      // First call
      final first = await chain.proceed(testGet('/data'));
      expect(first.data, {'call': 1});

      // Second call immediately — should be deduped via TTL
      final chain2 = CourierChain(
        couriers: [courier],
        execute: (m) async {
          callCount++;
          return Dispatch(
            statusCode: 200,
            data: {'call': callCount},
            headers: {},
            missive: m,
          );
        },
      );
      final second = await chain2.proceed(testGet('/data'));
      expect(second.data, {'call': 1}); // Same as first

      // Wait for TTL to expire
      await Future<void>.delayed(Duration(milliseconds: 300));

      // Third call should make a new request
      final chain3 = CourierChain(
        couriers: [courier],
        execute: (m) async {
          callCount++;
          return Dispatch(
            statusCode: 200,
            data: {'call': callCount},
            headers: {},
            missive: m,
          );
        },
      );
      final third = await chain3.proceed(testGet('/data'));
      expect(third.data, {'call': 2});
    });

    test('error propagates to all waiters', () async {
      final courier = DedupCourier();
      final completer = Completer<Dispatch>();

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) => completer.future,
      );

      // Start two concurrent requests
      final future1 = chain.proceed(testGet('/shared'));
      final future2 = chain.proceed(testGet('/shared'));

      // Complete with error
      completer.completeError(
        EnvoyError.connectionError(missive: testGet('/shared')),
      );

      expect(() => future1, throwsA(isA<EnvoyError>()));
      expect(() => future2, throwsA(isA<EnvoyError>()));
    });

    test('different methods are not deduped', () async {
      final courier = DedupCourier();
      var callCount = 0;

      Future<Dispatch> execute(Missive m) async {
        callCount++;
        return Dispatch(
          statusCode: 200,
          data: {'call': callCount},
          headers: {},
          missive: m,
        );
      }

      final getChain = CourierChain(couriers: [courier], execute: execute);
      final postChain = CourierChain(couriers: [courier], execute: execute);

      await getChain.proceed(testGet('/data'));
      await postChain.proceed(
        Missive(
          method: Method.post,
          uri: Uri.parse('https://api.test.com/data'),
        ),
      );

      expect(callCount, 2); // Different methods = different keys
    });

    test('inFlightCount tracks concurrent requests', () async {
      final courier = DedupCourier();
      final completer = Completer<Dispatch>();

      expect(courier.inFlightCount, 0);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) => completer.future,
      );

      final future = chain.proceed(testGet('/tracked'));
      expect(courier.inFlightCount, 1);

      completer.complete(
        Dispatch(
          statusCode: 200,
          data: {},
          headers: {},
          missive: testGet('/tracked'),
        ),
      );

      await future;
      expect(courier.inFlightCount, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // CookieCourier — Advanced
  // ═══════════════════════════════════════════════════════════════════

  group('CookieCourier — Advanced', () {
    test('parses RFC 1123 Expires date', () async {
      final courier = CookieCourier();

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {},
            headers: {
              'set-cookie':
                  'session=abc; Expires=Thu, 01 Dec 2099 16:00:00 GMT; Path=/',
            },
            missive: m,
          );
        },
      );

      await chain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.test.com/login'),
        ),
      );

      expect(courier.cookieCount, 1);
    });

    test('multiple cookies from single response', () async {
      final courier = CookieCourier();

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {},
            headers: {
              'set-cookie':
                  'session=abc; Path=/, lang=en; Path=/, theme=dark; Path=/',
            },
            missive: m,
          );
        },
      );

      await chain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.test.com/settings'),
        ),
      );

      expect(courier.cookieCount, 3);
    });

    test('HttpOnly flag is parsed', () async {
      final courier = CookieCourier();

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {},
            headers: {'set-cookie': 'token=xyz; HttpOnly; Path=/'},
            missive: m,
          );
        },
      );

      await chain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.test.com/auth'),
        ),
      );

      expect(courier.cookieCount, 1);
    });

    test('cookie not sent to different domain', () async {
      final courier = CookieCourier();

      // Set cookie for api.test.com
      final setChain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {},
            headers: {'set-cookie': 'session=abc; Domain=api.test.com; Path=/'},
            missive: m,
          );
        },
      );

      await setChain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.test.com/login'),
        ),
      );

      // Request to different domain
      String? sentCookies;
      final otherChain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentCookies = m.headers['cookie'];
          return Dispatch(statusCode: 200, data: {}, headers: {}, missive: m);
        },
      );

      await otherChain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://other.example.com/page'),
        ),
      );

      expect(sentCookies, isNull);
    });

    test('cookie sent to matching path', () async {
      final courier = CookieCourier();

      final setChain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {},
            headers: {'set-cookie': 'api=key123; Path=/api'},
            missive: m,
          );
        },
      );

      await setChain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://test.com/api/login'),
        ),
      );

      // Request to /api/users (matches /api path)
      String? sentCookies;
      final matchChain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentCookies = m.headers['cookie'];
          return Dispatch(statusCode: 200, data: {}, headers: {}, missive: m);
        },
      );

      await matchChain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://test.com/api/users'),
        ),
      );

      expect(sentCookies, contains('api=key123'));
    });

    test('cookie not sent to non-matching path', () async {
      final courier = CookieCourier();

      final setChain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {},
            headers: {'set-cookie': 'admin=secret; Path=/admin'},
            missive: m,
          );
        },
      );

      await setChain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://test.com/admin/login'),
        ),
      );

      // Request to /public — should NOT get the cookie
      String? sentCookies;
      final noMatchChain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentCookies = m.headers['cookie'];
          return Dispatch(statusCode: 200, data: {}, headers: {}, missive: m);
        },
      );

      await noMatchChain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://test.com/public/page'),
        ),
      );

      expect(sentCookies, isNull);
    });

    test('secure cookie not sent over http', () async {
      final courier = CookieCourier();

      final setChain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {},
            headers: {'set-cookie': 'secure=val; Secure; Path=/'},
            missive: m,
          );
        },
      );

      await setChain.proceed(
        Missive(method: Method.get, uri: Uri.parse('https://test.com/login')),
      );

      // Request over http
      String? sentCookies;
      final httpChain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentCookies = m.headers['cookie'];
          return Dispatch(statusCode: 200, data: {}, headers: {}, missive: m);
        },
      );

      await httpChain.proceed(
        Missive(method: Method.get, uri: Uri.parse('http://test.com/page')),
      );

      expect(sentCookies, isNull);
    });

    test('persistCookies=false clears expiry', () async {
      final courier = CookieCourier(persistCookies: false);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {},
            headers: {
              'set-cookie':
                  'session=abc; Expires=Thu, 01 Dec 2099 16:00:00 GMT; Path=/',
            },
            missive: m,
          );
        },
      );

      await chain.proceed(
        Missive(method: Method.get, uri: Uri.parse('https://test.com/login')),
      );

      // Cookie is stored but without expiry (session cookie behavior)
      expect(courier.cookieCount, 1);
    });

    test('clear removes all cookies', () async {
      final courier = CookieCourier();

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {},
            headers: {'set-cookie': 'a=1; Path=/, b=2; Path=/'},
            missive: m,
          );
        },
      );

      await chain.proceed(
        Missive(method: Method.get, uri: Uri.parse('https://test.com/')),
      );

      expect(courier.cookieCount, 2);
      courier.clear();
      expect(courier.cookieCount, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // MetricsCourier — Extended
  // ═══════════════════════════════════════════════════════════════════

  group('MetricsCourier — Extended', () {
    test('captures cached response detection', () async {
      EnvoyMetric? capturedMetric;
      final courier = MetricsCourier(onMetric: (m) => capturedMetric = m);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {'cached': true},
            rawBody: '{}',
            headers: {'x-envoy-cache': 'hit'},
            missive: m,
          );
        },
      );

      await chain.proceed(testGet('/cached'));

      expect(capturedMetric, isNotNull);
      expect(capturedMetric!.cached, isTrue);
      expect(capturedMetric!.success, isTrue);
    });

    test('captures error metrics', () async {
      EnvoyMetric? capturedMetric;
      final courier = MetricsCourier(onMetric: (m) => capturedMetric = m);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          throw EnvoyError.connectionError(missive: m);
        },
      );

      try {
        await chain.proceed(testGet('/fail'));
      } on EnvoyError {
        // Expected
      }

      expect(capturedMetric, isNotNull);
      expect(capturedMetric!.success, isFalse);
      expect(capturedMetric!.error, isNotNull);
    });

    test('measures duration accurately', () async {
      EnvoyMetric? capturedMetric;
      final courier = MetricsCourier(onMetric: (m) => capturedMetric = m);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          await Future<void>.delayed(Duration(milliseconds: 50));
          return Dispatch(statusCode: 200, data: {}, headers: {}, missive: m);
        },
      );

      await chain.proceed(testGet('/timed'));

      expect(capturedMetric!.duration.inMilliseconds, greaterThan(40));
    });

    test('captures response size from rawBody', () async {
      EnvoyMetric? capturedMetric;
      final courier = MetricsCourier(onMetric: (m) => capturedMetric = m);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {'large': true},
            rawBody: 'x' * 1000,
            headers: {},
            missive: m,
          );
        },
      );

      await chain.proceed(testGet('/large'));

      expect(capturedMetric!.responseSize, 1000);
    });

    test('EnvoyMetric.toJson includes all fields', () {
      final metric = EnvoyMetric(
        method: 'POST',
        url: 'https://api.test.com/users',
        statusCode: 201,
        duration: Duration(milliseconds: 150),
        success: true,
        responseSize: 256,
        requestSize: 64,
        cached: false,
        timestamp: DateTime.utc(2025, 6, 15),
      );

      final json = metric.toJson();
      expect(json['method'], 'POST');
      expect(json['url'], 'https://api.test.com/users');
      expect(json['statusCode'], 201);
      expect(json['durationMs'], 150);
      expect(json['success'], true);
      expect(json['responseSize'], 256);
      expect(json['requestSize'], 64);
      expect(json['cached'], false);
      expect(json['timestamp'], isA<String>());
    });

    test('EnvoyMetric.toString formats correctly', () {
      final success = EnvoyMetric(
        method: 'GET',
        url: 'https://api.test.com/users',
        statusCode: 200,
        duration: Duration(milliseconds: 50),
        success: true,
        timestamp: DateTime.now(),
      );
      expect(success.toString(), contains('✓'));
      expect(success.toString(), contains('GET'));
      expect(success.toString(), contains('200'));

      final failure = EnvoyMetric(
        method: 'POST',
        url: 'https://api.test.com/error',
        duration: Duration(milliseconds: 100),
        success: false,
        error: 'Connection failed',
        timestamp: DateTime.now(),
      );
      expect(failure.toString(), contains('✗'));
      expect(failure.toString(), contains('POST'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Gate — Extended
  // ═══════════════════════════════════════════════════════════════════

  group('Gate — Extended', () {
    test('maxQueue=0 allows unlimited queue', () async {
      final gate = Gate(maxConcurrent: 1, maxQueue: 0);
      final completers = List.generate(10, (_) => Completer<Dispatch>());
      var index = 0;

      final chain = CourierChain(
        couriers: [gate],
        execute: (m) {
          final c = completers[index++];
          return c.future;
        },
      );

      // Start 10 requests — 1 active, 9 queued
      final futures = List.generate(10, (_) => chain.proceed(testGet('/test')));

      expect(gate.activeCount, 1);
      expect(gate.queueLength, 9);

      // Complete all
      for (var i = 0; i < 10; i++) {
        completers[i].complete(
          Dispatch(
            statusCode: 200,
            data: {},
            headers: {},
            missive: testGet('/test'),
          ),
        );
        await Future<void>.delayed(Duration(milliseconds: 1));
      }

      await Future.wait(futures);
    });

    test('slot released on error', () async {
      final gate = Gate(maxConcurrent: 1);
      var attempt = 0;

      final chain = CourierChain(
        couriers: [gate],
        execute: (m) async {
          attempt++;
          if (attempt == 1) throw EnvoyError.connectionError(missive: m);
          return Dispatch(statusCode: 200, data: {}, headers: {}, missive: m);
        },
      );

      // First request fails
      try {
        await chain.proceed(testGet('/fail'));
      } on EnvoyError {
        // Expected
      }

      // Second request should succeed (slot was released)
      final chain2 = CourierChain(
        couriers: [gate],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            data: {'ok': true},
            headers: {},
            missive: m,
          );
        },
      );

      final dispatch = await chain2.proceed(testGet('/success'));
      expect(dispatch.data, {'ok': true});
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // LogCourier — Extended
  // ═══════════════════════════════════════════════════════════════════

  group('LogCourier — Extended', () {
    test('logs request method and URL', () async {
      final logs = <String>[];
      final courier = LogCourier(log: logs.add);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async =>
            Dispatch(statusCode: 200, data: {}, headers: {}, missive: m),
      );

      await chain.proceed(testGet('/users'));

      expect(logs.any((l) => l.contains('GET')), isTrue);
      expect(logs.any((l) => l.contains('/users')), isTrue);
    });

    test('logs headers when enabled', () async {
      final logs = <String>[];
      final courier = LogCourier(log: logs.add, logHeaders: true);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async => Dispatch(
          statusCode: 200,
          data: {},
          headers: {'x-response': 'value'},
          missive: m,
        ),
      );

      await chain.proceed(
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.test.com/users'),
          headers: {'x-custom': 'test'},
        ),
      );

      expect(logs.any((l) => l.contains('x-custom')), isTrue);
      expect(logs.any((l) => l.contains('x-response')), isTrue);
    });

    test('logs body when enabled', () async {
      final logs = <String>[];
      final courier = LogCourier(log: logs.add, logBody: true);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async => Dispatch(
          statusCode: 200,
          data: {},
          rawBody: '{"result":"success"}',
          headers: {},
          missive: m,
        ),
      );

      await chain.proceed(
        Missive(
          method: Method.post,
          uri: Uri.parse('https://api.test.com/users'),
          data: {'name': 'Kael'},
        ),
      );

      expect(logs.any((l) => l.contains('Body:')), isTrue);
    });

    test('logs errors when enabled', () async {
      final logs = <String>[];
      final courier = LogCourier(log: logs.add, logErrors: true);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          throw EnvoyError.connectionError(missive: m);
        },
      );

      try {
        await chain.proceed(testGet('/fail'));
      } on EnvoyError {
        // Expected
      }

      expect(logs.any((l) => l.contains('✗')), isTrue);
    });

    test('truncates long response body', () async {
      final logs = <String>[];
      final courier = LogCourier(log: logs.add, logBody: true);

      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async => Dispatch(
          statusCode: 200,
          data: {},
          rawBody: 'x' * 1000,
          headers: {},
          missive: m,
        ),
      );

      await chain.proceed(testGet('/large'));

      final bodyLog = logs.firstWhere(
        (l) => l.contains('Body:'),
        orElse: () => '',
      );
      expect(bodyLog, contains('...'));
      expect(bodyLog.length, lessThan(1000));
    });
  });
}
