import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Colossus — Enterprise MCP capabilities
  // ---------------------------------------------------------

  group('Colossus reloadPage', () {
    late Colossus colossus;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      colossus.dispose();
    });

    test('reloadPage without route returns error when no Atlas', () async {
      // No Atlas configured, no getCurrentRoute — reports error
      final result = await colossus.reloadPage();

      expect(result['success'], isFalse);
      expect(result['method'], 'route');
      expect(result['error'], contains('Unable to determine current route'));
    });
  });

  group('Colossus getRouteHistory', () {
    late Colossus colossus;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      colossus.dispose();
    });

    test('returns empty history when no events', () {
      final history = colossus.getRouteHistory();

      expect(history['count'], 0);
      expect(history['routes'], isEmpty);
    });

    test('returns atlas events only', () {
      colossus.trackEvent({
        'source': 'atlas',
        'type': 'navigate',
        'route': '/home',
      });
      colossus.trackEvent({
        'source': 'basalt',
        'type': 'circuit_trip',
        'name': 'api-breaker',
      });
      colossus.trackEvent({
        'source': 'atlas',
        'type': 'navigate',
        'route': '/settings',
      });

      final history = colossus.getRouteHistory();

      expect(history['count'], 2);
      expect((history['routes'] as List).length, 2);
    });

    test('preserves chronological order', () {
      colossus.trackEvent({
        'source': 'atlas',
        'type': 'navigate',
        'route': '/first',
      });
      colossus.trackEvent({
        'source': 'atlas',
        'type': 'navigate',
        'route': '/second',
      });
      colossus.trackEvent({
        'source': 'atlas',
        'type': 'pop',
        'route': '/first',
      });

      final history = colossus.getRouteHistory();
      final routes = history['routes'] as List;

      expect(routes[0]['route'], '/first');
      expect(routes[1]['route'], '/second');
      expect(routes[2]['type'], 'pop');
    });
  });

  group('Colossus events access', () {
    late Colossus colossus;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      colossus.dispose();
    });

    test('events starts empty', () {
      expect(colossus.events, isEmpty);
    });

    test('trackEvent adds event with timestamp', () {
      colossus.trackEvent({
        'source': 'test',
        'type': 'custom',
        'data': 'value',
      });

      expect(colossus.events, hasLength(1));
      expect(colossus.events[0]['source'], 'test');
      expect(colossus.events[0]['timestamp'], isNotNull);
    });

    test('trackEvent preserves existing timestamp', () {
      colossus.trackEvent({
        'source': 'test',
        'type': 'custom',
        'timestamp': '2025-01-01T00:00:00Z',
      });

      expect(colossus.events[0]['timestamp'], '2025-01-01T00:00:00Z');
    });

    test('events caps at 1000', () {
      for (var i = 0; i < 1010; i++) {
        colossus.trackEvent({'source': 'test', 'type': 'event_$i'});
      }

      expect(colossus.events.length, 1000);
      // Oldest events should be evicted
      expect(colossus.events[0]['type'], 'event_10');
    });

    test('events list is unmodifiable', () {
      colossus.trackEvent({'source': 'test', 'type': 'custom'});

      expect(
        () => colossus.events.add({'source': 'hacker'}),
        throwsUnsupportedError,
      );
    });
  });
}
