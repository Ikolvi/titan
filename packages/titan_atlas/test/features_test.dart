import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

void main() {
  group('Waypoint — type-safe Rune accessors', () {
    test('intRune parses integer', () {
      const wp = Waypoint(
        path: '/user/42',
        pattern: '/user/:id',
        runes: {'id': '42'},
      );
      expect(wp.intRune('id'), 42);
    });

    test('intRune returns null for non-integer', () {
      const wp = Waypoint(
        path: '/user/abc',
        pattern: '/user/:id',
        runes: {'id': 'abc'},
      );
      expect(wp.intRune('id'), isNull);
    });

    test('intRune returns null for missing key', () {
      const wp = Waypoint(path: '/user/42', pattern: '/user/:id');
      expect(wp.intRune('missing'), isNull);
    });

    test('doubleRune parses double', () {
      const wp = Waypoint(
        path: '/price/19.99',
        pattern: '/price/:value',
        runes: {'value': '19.99'},
      );
      expect(wp.doubleRune('value'), 19.99);
    });

    test('boolRune parses boolean', () {
      const wp = Waypoint(
        path: '/flag/true',
        pattern: '/flag/:val',
        runes: {'val': 'true'},
      );
      expect(wp.boolRune('val'), true);

      const wp2 = Waypoint(
        path: '/flag/1',
        pattern: '/flag/:val',
        runes: {'val': '1'},
      );
      expect(wp2.boolRune('val'), true);

      const wp3 = Waypoint(
        path: '/flag/false',
        pattern: '/flag/:val',
        runes: {'val': 'false'},
      );
      expect(wp3.boolRune('val'), false);
    });

    test('intQuery parses query int', () {
      const wp = Waypoint(
        path: '/search',
        pattern: '/search',
        query: {'page': '5'},
      );
      expect(wp.intQuery('page'), 5);
      expect(wp.intQuery('missing'), isNull);
    });

    test('doubleQuery parses query double', () {
      const wp = Waypoint(
        path: '/items',
        pattern: '/items',
        query: {'min': '10.5'},
      );
      expect(wp.doubleQuery('min'), 10.5);
    });

    test('boolQuery parses query bool', () {
      const wp = Waypoint(
        path: '/list',
        pattern: '/list',
        query: {'active': 'true'},
      );
      expect(wp.boolQuery('active'), true);
    });
  });

  group('Waypoint — metadata and name', () {
    test('stores metadata', () {
      const wp = Waypoint(
        path: '/admin',
        pattern: '/admin',
        metadata: {'title': 'Admin Panel', 'role': 'admin'},
      );
      expect(wp.metadata?['title'], 'Admin Panel');
      expect(wp.metadata?['role'], 'admin');
    });

    test('stores name', () {
      const wp = Waypoint(path: '/home', pattern: '/home', name: 'home');
      expect(wp.name, 'home');
    });

    test('copyWith preserves metadata and name', () {
      const wp = Waypoint(
        path: '/a',
        pattern: '/a',
        metadata: {'key': 'val'},
        name: 'test',
      );
      final copy = wp.copyWith(path: '/b', pattern: '/b');
      expect(copy.metadata?['key'], 'val');
      expect(copy.name, 'test');
    });
  });

  group('Atlas — per-route redirect', () {
    testWidgets('Passage redirect triggers', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/old', (_) => const Text('Old'), redirect: (wp) => '/new'),
          Passage('/new', (_) => const Text('New')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/old');
      await tester.pumpAndSettle();

      expect(find.text('New'), findsOneWidget);
      expect(find.text('Old'), findsNothing);
    });

    testWidgets('Passage redirect returns null allows passage', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage(
            '/page',
            (_) => const Text('Page'),
            redirect: (wp) => null, // Allow
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/page');
      await tester.pumpAndSettle();

      expect(find.text('Page'), findsOneWidget);
    });
  });

  group('Atlas — route metadata on Waypoint', () {
    testWidgets('metadata accessible in builder', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage(
            '/admin',
            (wp) => Text('Title: ${wp.metadata?['title']}'),
            metadata: {'title': 'Admin Panel'},
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/admin');
      await tester.pumpAndSettle();

      expect(find.text('Title: Admin Panel'), findsOneWidget);
    });

    testWidgets('name accessible on current waypoint', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home'), name: 'home'),
          Passage('/about', (_) => const Text('About'), name: 'about'),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(Atlas.current.name, 'home');

      Atlas.to('/about');
      await tester.pumpAndSettle();

      expect(Atlas.current.name, 'about');
    });
  });

  group('Atlas — AtlasObserver', () {
    testWidgets('observer receives onNavigate', (tester) async {
      final events = <String>[];

      final observer = _TestObserver(
        onNavigateFn: (from, to) => events.add('nav:${from.path}->${to.path}'),
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/about', (_) => const Text('About')),
        ],
        observers: [observer],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/about');
      await tester.pumpAndSettle();

      expect(events, ['nav:/->/about']);
    });

    testWidgets('observer receives onReplace', (tester) async {
      final events = <String>[];

      final observer = _TestObserver(
        onReplaceFn: (from, to) =>
            events.add('replace:${from.path}->${to.path}'),
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
          Passage('/b', (_) => const Text('B')),
        ],
        observers: [observer],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/a');
      await tester.pumpAndSettle();

      Atlas.replace('/b');
      await tester.pumpAndSettle();

      expect(events, ['replace:/a->/b']);
    });

    testWidgets('observer receives onPop', (tester) async {
      final events = <String>[];

      final observer = _TestObserver(
        onPopFn: (from, to) => events.add('pop:${from.path}->${to.path}'),
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
        ],
        observers: [observer],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/a');
      await tester.pumpAndSettle();

      Atlas.back();
      await tester.pumpAndSettle();

      expect(events, ['pop:/a->/']);
    });

    testWidgets('observer receives onReset', (tester) async {
      final events = <String>[];

      final observer = _TestObserver(
        onResetFn: (to) => events.add('reset:${to.path}'),
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
        ],
        observers: [observer],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/a');
      await tester.pumpAndSettle();

      Atlas.reset('/');
      await tester.pumpAndSettle();

      expect(events, ['reset:/']);
    });

    testWidgets('observer receives onGuardRedirect', (tester) async {
      final events = <String>[];

      final observer = _TestObserver(
        onGuardRedirectFn: (from, to) => events.add('guard:$from->$to'),
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
          Passage('/admin', (_) => const Text('Admin')),
        ],
        sentinels: [
          Sentinel((path, _) {
            if (path == '/admin') return '/login';
            return null;
          }),
        ],
        observers: [observer],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/admin');
      await tester.pumpAndSettle();

      expect(events, ['guard:/admin->/login']);
    });

    testWidgets('observer receives onNotFound', (tester) async {
      final events = <String>[];

      final observer = _TestObserver(
        onNotFoundFn: (path) => events.add('404:$path'),
      );

      final atlas = Atlas(
        passages: [Passage('/', (_) => const Text('Home'))],
        observers: [observer],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/nonexistent');
      await tester.pumpAndSettle();

      expect(events, ['404:/nonexistent']);
    });
  });
}

/// Test observer with configurable callbacks
class _TestObserver extends AtlasObserver {
  final void Function(Waypoint from, Waypoint to)? onNavigateFn;
  final void Function(Waypoint from, Waypoint to)? onReplaceFn;
  final void Function(Waypoint from, Waypoint to)? onPopFn;
  final void Function(Waypoint to)? onResetFn;
  final void Function(String from, String to)? onGuardRedirectFn;
  final void Function(String from, String to)? onDriftRedirectFn;
  final void Function(String path)? onNotFoundFn;

  _TestObserver({
    this.onNavigateFn,
    this.onReplaceFn,
    this.onPopFn,
    this.onResetFn,
    this.onGuardRedirectFn,
    // ignore: unused_element_parameter
    this.onDriftRedirectFn,
    this.onNotFoundFn,
  });

  @override
  void onNavigate(Waypoint from, Waypoint to) => onNavigateFn?.call(from, to);

  @override
  void onReplace(Waypoint from, Waypoint to) => onReplaceFn?.call(from, to);

  @override
  void onPop(Waypoint from, Waypoint to) => onPopFn?.call(from, to);

  @override
  void onReset(Waypoint to) => onResetFn?.call(to);

  @override
  void onGuardRedirect(String originalPath, String redirectPath) =>
      onGuardRedirectFn?.call(originalPath, redirectPath);

  @override
  void onDriftRedirect(String originalPath, String redirectPath) =>
      onDriftRedirectFn?.call(originalPath, redirectPath);

  @override
  void onNotFound(String path) => onNotFoundFn?.call(path);
}
