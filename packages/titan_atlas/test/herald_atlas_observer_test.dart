import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

void main() {
  group('HeraldAtlasObserver', () {
    late HeraldAtlasObserver observer;

    setUp(() {
      Herald.reset();
      observer = HeraldAtlasObserver();
    });

    tearDown(() => Herald.reset());

    Waypoint makeWaypoint(String path) => Waypoint(
          path: path,
          pattern: path,
          runes: const {},
          query: const {},
        );

    test('onNavigate emits AtlasRouteChanged with push type', () {
      final events = <AtlasRouteChanged>[];
      Herald.on<AtlasRouteChanged>((e) => events.add(e));

      observer.onNavigate(makeWaypoint('/'), makeWaypoint('/about'));

      expect(events.length, 1);
      expect(events.first.from?.path, '/');
      expect(events.first.to.path, '/about');
      expect(events.first.type, AtlasNavigationType.push);
    });

    test('onReplace emits AtlasRouteChanged with replace type', () {
      final events = <AtlasRouteChanged>[];
      Herald.on<AtlasRouteChanged>((e) => events.add(e));

      observer.onReplace(makeWaypoint('/old'), makeWaypoint('/new'));

      expect(events.length, 1);
      expect(events.first.type, AtlasNavigationType.replace);
    });

    test('onPop emits AtlasRouteChanged with pop type', () {
      final events = <AtlasRouteChanged>[];
      Herald.on<AtlasRouteChanged>((e) => events.add(e));

      observer.onPop(makeWaypoint('/detail'), makeWaypoint('/list'));

      expect(events.length, 1);
      expect(events.first.type, AtlasNavigationType.pop);
      expect(events.first.from?.path, '/detail');
      expect(events.first.to.path, '/list');
    });

    test('onReset emits AtlasRouteChanged with reset type', () {
      final events = <AtlasRouteChanged>[];
      Herald.on<AtlasRouteChanged>((e) => events.add(e));

      observer.onReset(makeWaypoint('/'));

      expect(events.length, 1);
      expect(events.first.from, isNull);
      expect(events.first.to.path, '/');
      expect(events.first.type, AtlasNavigationType.reset);
    });

    test('onGuardRedirect emits AtlasGuardRedirect', () {
      final events = <AtlasGuardRedirect>[];
      Herald.on<AtlasGuardRedirect>((e) => events.add(e));

      observer.onGuardRedirect('/admin', '/login');

      expect(events.length, 1);
      expect(events.first.originalPath, '/admin');
      expect(events.first.redirectPath, '/login');
    });

    test('onDriftRedirect emits AtlasDriftRedirect', () {
      final events = <AtlasDriftRedirect>[];
      Herald.on<AtlasDriftRedirect>((e) => events.add(e));

      observer.onDriftRedirect('/old-page', '/new-page');

      expect(events.length, 1);
      expect(events.first.originalPath, '/old-page');
      expect(events.first.redirectPath, '/new-page');
    });

    test('onNotFound emits AtlasRouteNotFound', () {
      final events = <AtlasRouteNotFound>[];
      Herald.on<AtlasRouteNotFound>((e) => events.add(e));

      observer.onNotFound('/nonexistent');

      expect(events.length, 1);
      expect(events.first.path, '/nonexistent');
    });

    test('toString on events is readable', () {
      expect(
        AtlasRouteChanged(
          from: makeWaypoint('/a'),
          to: makeWaypoint('/b'),
          type: AtlasNavigationType.push,
        ).toString(),
        contains('AtlasRouteChanged'),
      );
      expect(
        const AtlasGuardRedirect(
          originalPath: '/x',
          redirectPath: '/y',
        ).toString(),
        contains('AtlasGuardRedirect'),
      );
      expect(
        const AtlasDriftRedirect(
          originalPath: '/x',
          redirectPath: '/y',
        ).toString(),
        contains('AtlasDriftRedirect'),
      );
      expect(
        const AtlasRouteNotFound(path: '/z').toString(),
        contains('AtlasRouteNotFound'),
      );
    });

    test('Pillar can listen for Atlas events via Herald', () {
      final routes = <String>[];
      Herald.on<AtlasRouteChanged>((e) => routes.add(e.to.path));

      observer.onNavigate(makeWaypoint('/'), makeWaypoint('/home'));
      observer.onNavigate(makeWaypoint('/home'), makeWaypoint('/profile'));

      expect(routes, ['/home', '/profile']);
    });
  });
}
