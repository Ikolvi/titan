import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

void main() {
  group('AtlasAnalyticsObserver', () {
    test('onNavigate calls onScreen and onEvent', () {
      final screens = <Map<String, String>>[];
      final events = <Map<String, dynamic>>[];

      final observer = AtlasAnalyticsObserver(
        onScreen: (name, params) => screens.add({'name': name, ...params}),
        onEvent: (event, params) => events.add({'event': event, ...params}),
      );

      const from = Waypoint(path: '/home', pattern: '/home');
      const to = Waypoint(
        path: '/profile/42',
        pattern: '/profile/:id',
        name: 'Profile',
      );

      observer.onNavigate(from, to);

      expect(screens.length, 1);
      expect(screens.first['name'], 'Profile');
      expect(screens.first['path'], '/profile/42');
      expect(screens.first['from'], '/home');

      expect(events.length, 1);
      expect(events.first['event'], 'navigate');
      expect(events.first['to'], '/profile/42');
    });

    test('falls back to path when no name', () {
      final screens = <String>[];

      final observer = AtlasAnalyticsObserver(
        onScreen: (name, _) => screens.add(name),
      );

      const from = Waypoint(path: '/home', pattern: '/home');
      const to = Waypoint(path: '/settings', pattern: '/settings');

      observer.onNavigate(from, to);

      expect(screens.first, '/settings');
    });

    test('screenNameResolver overrides default naming', () {
      final screens = <String>[];

      final observer = AtlasAnalyticsObserver(
        screenNameResolver: (path, name, metadata) =>
            metadata?['title'] as String? ?? name ?? path,
        onScreen: (name, _) => screens.add(name),
      );

      const from = Waypoint(path: '/home', pattern: '/home');
      const to = Waypoint(
        path: '/admin',
        pattern: '/admin',
        metadata: {'title': 'Admin Panel'},
      );

      observer.onNavigate(from, to);
      expect(screens.first, 'Admin Panel');
    });

    test('onReplace triggers screen and event', () {
      final events = <String>[];

      final observer = AtlasAnalyticsObserver(
        onEvent: (event, _) => events.add(event),
      );

      const from = Waypoint(path: '/a', pattern: '/a');
      const to = Waypoint(path: '/b', pattern: '/b');

      observer.onReplace(from, to);
      expect(events, ['replace']);
    });

    test('onPop triggers screen and event', () {
      final events = <String>[];

      final observer = AtlasAnalyticsObserver(
        onEvent: (event, _) => events.add(event),
      );

      const from = Waypoint(path: '/detail', pattern: '/detail');
      const to = Waypoint(path: '/list', pattern: '/list');

      observer.onPop(from, to);
      expect(events, ['pop']);
    });

    test('onReset triggers screen and event', () {
      final screens = <String>[];
      final events = <String>[];

      final observer = AtlasAnalyticsObserver(
        onScreen: (name, _) => screens.add(name),
        onEvent: (event, _) => events.add(event),
      );

      const to = Waypoint(path: '/home', pattern: '/home', name: 'Home');

      observer.onReset(to);
      expect(screens, ['Home']);
      expect(events, ['reset']);
    });

    test('onGuardRedirect emits event', () {
      final events = <Map<String, dynamic>>[];

      final observer = AtlasAnalyticsObserver(
        onEvent: (event, params) => events.add({'event': event, ...params}),
      );

      observer.onGuardRedirect('/admin', '/login');
      expect(events.first['event'], 'guard_redirect');
      expect(events.first['from'], '/admin');
      expect(events.first['to'], '/login');
    });

    test('onDriftRedirect emits event', () {
      final events = <Map<String, dynamic>>[];

      final observer = AtlasAnalyticsObserver(
        onEvent: (event, params) => events.add({'event': event, ...params}),
      );

      observer.onDriftRedirect('/old', '/new');
      expect(events.first['event'], 'drift_redirect');
    });

    test('onNotFound emits event', () {
      final events = <Map<String, dynamic>>[];

      final observer = AtlasAnalyticsObserver(
        onEvent: (event, params) => events.add({'event': event, ...params}),
      );

      observer.onNotFound('/unknown');
      expect(events.first['event'], 'not_found');
      expect(events.first['path'], '/unknown');
    });

    test('null callbacks are safe', () {
      const observer = AtlasAnalyticsObserver();
      const from = Waypoint(path: '/a', pattern: '/a');
      const to = Waypoint(path: '/b', pattern: '/b');

      // Should not throw
      observer.onNavigate(from, to);
      observer.onReplace(from, to);
      observer.onPop(from, to);
      observer.onReset(to);
      observer.onGuardRedirect('/a', '/b');
      observer.onDriftRedirect('/a', '/b');
      observer.onNotFound('/x');
    });
  });
}
