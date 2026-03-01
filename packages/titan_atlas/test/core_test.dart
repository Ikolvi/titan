import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/src/core/waypoint.dart';
import 'package:titan_atlas/src/core/sentinel.dart';

void main() {
  group('Waypoint', () {
    test('stores path and pattern', () {
      const wp = Waypoint(path: '/user/42', pattern: '/user/:id');
      expect(wp.path, '/user/42');
      expect(wp.pattern, '/user/:id');
    });

    test('stores runes (parameters)', () {
      const wp = Waypoint(
        path: '/user/42',
        pattern: '/user/:id',
        runes: {'id': '42'},
      );
      expect(wp.runes['id'], '42');
    });

    test('stores query parameters', () {
      const wp = Waypoint(
        path: '/search',
        pattern: '/search',
        query: {'q': 'dart', 'page': '2'},
      );
      expect(wp.query['q'], 'dart');
      expect(wp.query['page'], '2');
    });

    test('stores extra data', () {
      final wp = Waypoint(
        path: '/detail',
        pattern: '/detail',
        extra: {'key': 'value'},
      );
      expect(wp.extra, {'key': 'value'});
    });

    test('generates URI with query', () {
      const wp = Waypoint(
        path: '/search',
        pattern: '/search',
        query: {'q': 'dart'},
      );
      expect(wp.uri.toString(), '/search?q=dart');
    });

    test('equality by path and pattern', () {
      const a = Waypoint(path: '/home', pattern: '/home');
      const b = Waypoint(path: '/home', pattern: '/home');
      const c = Waypoint(path: '/about', pattern: '/about');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates modified copy', () {
      const original = Waypoint(path: '/home', pattern: '/home');
      final copy = original.copyWith(path: '/about', pattern: '/about');
      expect(copy.path, '/about');
      expect(original.path, '/home');
    });
  });

  group('Sentinel', () {
    test('evaluates sync guard', () {
      final sentinel = Sentinel((path, _) {
        if (path.startsWith('/admin')) return '/login';
        return null;
      });

      const wp = Waypoint(path: '/admin', pattern: '/admin');
      expect(sentinel.evaluate('/admin', wp), '/login');
      expect(sentinel.evaluate('/home', wp), isNull);
    });

    test('Sentinel.only guards specific paths', () {
      final sentinel = Sentinel.only(
        paths: {'/settings', '/billing'},
        guard: (path, _) => '/login',
      );

      const wp = Waypoint(path: '/settings', pattern: '/settings');
      expect(sentinel.evaluate('/settings', wp), '/login');
      expect(sentinel.evaluate('/home', wp), isNull);
    });

    test('Sentinel.except excludes paths', () {
      final sentinel = Sentinel.except(
        paths: {'/login', '/register'},
        guard: (path, _) => '/login',
      );

      const wp = Waypoint(path: '/home', pattern: '/home');
      expect(sentinel.evaluate('/home', wp), '/login');
      expect(sentinel.evaluate('/login', wp), isNull);
    });

    test('async sentinel evaluates', () async {
      final sentinel = Sentinel.async((path, _) async {
        return path == '/restricted' ? '/403' : null;
      });

      const wp = Waypoint(path: '/restricted', pattern: '/restricted');
      expect(
        await sentinel.evaluateAsync('/restricted', wp),
        '/403',
      );
      expect(
        await sentinel.evaluateAsync('/home', wp),
        isNull,
      );
    });
  });
}
