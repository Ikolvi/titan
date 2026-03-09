import 'dart:async';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

/// Creates a test missive for the given [uri].
Missive _missive(String url) =>
    Missive(method: Method.get, uri: Uri.parse(url));

/// A fake executor that returns a Dispatch with configurable headers.
Future<Dispatch> _fakeExecutor(
  Missive missive, {
  Map<String, String> headers = const {},
}) async {
  return Dispatch(
    statusCode: 200,
    data: null,
    rawBody: '',
    headers: headers,
    missive: missive,
    duration: Duration.zero,
  );
}

void main() {
  group('CookieCourier', () {
    group('construction', () {
      test('creates with defaults', () {
        final courier = CookieCourier();
        expect(courier.persistCookies, isTrue);
        expect(courier.cookieCount, 0);
      });

      test('creates with persistCookies false', () {
        final courier = CookieCourier(persistCookies: false);
        expect(courier.persistCookies, isFalse);
      });
    });

    group('cookie storage', () {
      test('stores cookie from set-cookie header', () async {
        final courier = CookieCourier();
        final chain = CourierChain(
          couriers: [courier],
          execute: (m) => _fakeExecutor(
            m,
            headers: {'set-cookie': 'session=abc123; Path=/'},
          ),
        );

        await chain.proceed(_missive('https://api.example.com/login'));
        expect(courier.cookieCount, 1);
      });

      test('stores multiple cookies', () async {
        final courier = CookieCourier();
        final chain = CourierChain(
          couriers: [courier],
          execute: (m) => _fakeExecutor(
            m,
            headers: {'set-cookie': 'session=abc; Path=/, theme=dark; Path=/'},
          ),
        );

        await chain.proceed(_missive('https://api.example.com/login'));
        expect(courier.cookieCount, 2);
      });

      test('attaches cookies to subsequent requests', () async {
        final courier = CookieCourier();
        Missive? capturedMissive;

        final chain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );

        // First: set the cookie via a simulated response
        final setChain = CourierChain(
          couriers: [courier],
          execute: (m) => _fakeExecutor(
            m,
            headers: {'set-cookie': 'session=xyz789; Path=/'},
          ),
        );
        await setChain.proceed(_missive('https://api.example.com/auth'));

        // Second: verify cookie is sent
        await chain.proceed(_missive('https://api.example.com/profile'));
        expect(capturedMissive!.headers['cookie'], contains('session=xyz789'));
      });

      test('respects domain matching', () async {
        final courier = CookieCourier();
        Missive? capturedMissive;

        // Set cookie for api.example.com
        final setChain = CourierChain(
          couriers: [courier],
          execute: (m) => _fakeExecutor(
            m,
            headers: {
              'set-cookie': 'token=abc; Domain=api.example.com; Path=/',
            },
          ),
        );
        await setChain.proceed(_missive('https://api.example.com/login'));

        // Should NOT attach to different domain
        final otherChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );
        await otherChain.proceed(_missive('https://other.com/page'));
        expect(capturedMissive!.headers['cookie'], isNull);
      });

      test('respects path matching', () async {
        final courier = CookieCourier();
        Missive? capturedMissive;

        // Set cookie for /api path
        final setChain = CourierChain(
          couriers: [courier],
          execute: (m) =>
              _fakeExecutor(m, headers: {'set-cookie': 'token=abc; Path=/api'}),
        );
        await setChain.proceed(_missive('https://example.com/api/login'));

        // Should attach to /api/profile
        final apiChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );
        await apiChain.proceed(_missive('https://example.com/api/profile'));
        expect(capturedMissive!.headers['cookie'], contains('token=abc'));

        // Should NOT attach to /other
        capturedMissive = null;
        final otherChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );
        await otherChain.proceed(_missive('https://example.com/other'));
        expect(capturedMissive!.headers['cookie'], anyOf(isNull, isEmpty));
      });

      test('respects secure flag', () async {
        final courier = CookieCourier();
        Missive? capturedMissive;

        // Set secure cookie
        final setChain = CourierChain(
          couriers: [courier],
          execute: (m) => _fakeExecutor(
            m,
            headers: {'set-cookie': 'token=secret; Secure; Path=/'},
          ),
        );
        await setChain.proceed(_missive('https://example.com/login'));

        // Should NOT attach to http:// (non-secure)
        final httpChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );
        await httpChain.proceed(_missive('http://example.com/page'));
        expect(capturedMissive!.headers['cookie'], anyOf(isNull, isEmpty));

        // Should attach to https://
        capturedMissive = null;
        final httpsChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );
        await httpsChain.proceed(_missive('https://example.com/page'));
        expect(capturedMissive!.headers['cookie'], contains('token=secret'));
      });

      test('overwrites cookie with same name', () async {
        final courier = CookieCourier();

        final setChain1 = CourierChain(
          couriers: [courier],
          execute: (m) =>
              _fakeExecutor(m, headers: {'set-cookie': 'theme=light; Path=/'}),
        );
        await setChain1.proceed(_missive('https://example.com/'));
        expect(courier.cookieCount, 1);

        final setChain2 = CourierChain(
          couriers: [courier],
          execute: (m) =>
              _fakeExecutor(m, headers: {'set-cookie': 'theme=dark; Path=/'}),
        );
        await setChain2.proceed(_missive('https://example.com/'));
        expect(courier.cookieCount, 1);

        // Verify latest value
        Missive? capturedMissive;
        final readChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );
        await readChain.proceed(_missive('https://example.com/'));
        expect(capturedMissive!.headers['cookie'], contains('theme=dark'));
        expect(
          capturedMissive!.headers['cookie'],
          isNot(contains('theme=light')),
        );
      });
    });

    group('expiry', () {
      test('evicts expired cookies', () async {
        final courier = CookieCourier();

        // Set a cookie with max-age=0 (already expired)
        final setChain = CourierChain(
          couriers: [courier],
          execute: (m) => _fakeExecutor(
            m,
            headers: {'set-cookie': 'expired=yes; Max-Age=0; Path=/'},
          ),
        );
        await setChain.proceed(_missive('https://example.com/'));

        // Cookie should be stored but with past expiry
        // On next request, it should be evicted
        Missive? capturedMissive;
        final readChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );
        await readChain.proceed(_missive('https://example.com/'));
        expect(
          capturedMissive!.headers['cookie'],
          anyOf(isNull, isEmpty, isNot(contains('expired=yes'))),
        );
      });
    });

    group('clear', () {
      test('removes all stored cookies', () async {
        final courier = CookieCourier();

        final setChain = CourierChain(
          couriers: [courier],
          execute: (m) =>
              _fakeExecutor(m, headers: {'set-cookie': 'session=abc; Path=/'}),
        );
        await setChain.proceed(_missive('https://example.com/'));
        expect(courier.cookieCount, 1);

        courier.clear();
        expect(courier.cookieCount, 0);
      });
    });

    group('preserves existing cookies header', () {
      test('appends to existing cookie header on request', () async {
        final courier = CookieCourier();

        // Store a cookie
        final setChain = CourierChain(
          couriers: [courier],
          execute: (m) =>
              _fakeExecutor(m, headers: {'set-cookie': 'session=abc; Path=/'}),
        );
        await setChain.proceed(_missive('https://example.com/'));

        // Send request with existing cookie header
        Missive? capturedMissive;
        final readChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );

        final missive = Missive(
          method: Method.get,
          uri: Uri.parse('https://example.com/api'),
          headers: {'cookie': 'custom=value'},
        );
        await readChain.proceed(missive);
        expect(capturedMissive!.headers['cookie'], contains('custom=value'));
        expect(capturedMissive!.headers['cookie'], contains('session=abc'));
      });
    });

    group('subdomain matching', () {
      test('parent domain cookie sent to subdomains', () async {
        final courier = CookieCourier();

        // Set cookie for 'example.com'
        final setChain = CourierChain(
          couriers: [courier],
          execute: (m) => _fakeExecutor(
            m,
            headers: {'set-cookie': 'global=yes; Domain=example.com; Path=/'},
          ),
        );
        await setChain.proceed(_missive('https://example.com/'));

        // Should be sent to sub.example.com
        Missive? capturedMissive;
        final readChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );
        await readChain.proceed(_missive('https://api.example.com/data'));
        expect(capturedMissive!.headers['cookie'], contains('global=yes'));
      });
    });

    group('domain with leading dot', () {
      test('strips leading dot from Domain attribute', () async {
        final courier = CookieCourier();

        final setChain = CourierChain(
          couriers: [courier],
          execute: (m) => _fakeExecutor(
            m,
            headers: {'set-cookie': 'dotted=ok; Domain=.example.com; Path=/'},
          ),
        );
        await setChain.proceed(_missive('https://example.com/'));

        // Should match example.com
        Missive? capturedMissive;
        final readChain = CourierChain(
          couriers: [courier],
          execute: (m) {
            capturedMissive = m;
            return _fakeExecutor(m);
          },
        );
        await readChain.proceed(_missive('https://example.com/'));
        expect(capturedMissive!.headers['cookie'], contains('dotted=ok'));
      });
    });
  });
}
