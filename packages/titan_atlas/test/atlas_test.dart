import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

void main() {
  // Reset static Atlas instance between tests.
  tearDown(() {
    // Atlas uses a static _instance, so we need a fresh one per test.
    // Creating a new Atlas in each test replaces the previous instance.
  });

  group('Atlas — basic navigation', () {
    testWidgets('renders initial route', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/about', (_) => const Text('About')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('About'), findsNothing);
    });

    testWidgets('navigates with Atlas.to()', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/about', (_) => const Text('About')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/about');
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('navigates back with Atlas.back()', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/about', (_) => const Text('About')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/about');
      await tester.pumpAndSettle();
      expect(find.text('About'), findsOneWidget);

      Atlas.back();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('Atlas.replace replaces current route', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
          Passage('/b', (_) => const Text('B')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/a');
      await tester.pumpAndSettle();

      Atlas.replace('/b');
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);

      // Back should go to Home, not A (since A was replaced)
      Atlas.back();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('Atlas.reset clears stack', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
          Passage('/b', (_) => const Text('B')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/a');
      await tester.pumpAndSettle();
      Atlas.to('/b');
      await tester.pumpAndSettle();

      Atlas.reset('/');
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(Atlas.canBack, isFalse);
    });

    testWidgets('Atlas.canBack is correct', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(Atlas.canBack, isFalse);

      Atlas.to('/a');
      await tester.pumpAndSettle();
      expect(Atlas.canBack, isTrue);

      Atlas.back();
      await tester.pumpAndSettle();
      expect(Atlas.canBack, isFalse);
    });

    testWidgets('Atlas.go() reuses existing stack entry', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
          Passage('/b', (_) => const Text('B')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);

      // Push onto stack
      Atlas.to('/a');
      await tester.pumpAndSettle();
      Atlas.to('/b');
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(Atlas.current.path, '/b');

      // go() back to '/' — should pop to existing entry, not duplicate
      Atlas.go('/');
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(Atlas.current.path, '/');
      expect(Atlas.canBack, isFalse); // stack is just [/]
    });

    testWidgets('Atlas.go() navigates fresh when path not in stack', (
      tester,
    ) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
          Passage('/b', (_) => const Text('B')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      // go() to a path NOT in the stack — replaces stack entirely
      Atlas.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
      expect(Atlas.current.path, '/b');
      expect(Atlas.canBack, isFalse);
    });

    testWidgets('Atlas.go() is no-op when already at path', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/a');
      await tester.pumpAndSettle();

      // go() to current path — no change
      Atlas.go('/a');
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(Atlas.current.path, '/a');
      expect(Atlas.canBack, isTrue); // stack still [/, /a]
    });

    testWidgets('Atlas.current returns current waypoint', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/user/:id', (wp) => Text('User ${wp.runes['id']}')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(Atlas.current.path, '/');

      Atlas.to('/user/42');
      await tester.pumpAndSettle();

      expect(Atlas.current.path, '/user/42');
      expect(Atlas.current.runes['id'], '42');
    });
  });

  group('Atlas — Runes (path parameters)', () {
    testWidgets('passes Runes to builder', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/profile/:id', (wp) => Text('Profile: ${wp.runes['id']}')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/profile/titan');
      await tester.pumpAndSettle();

      expect(find.text('Profile: titan'), findsOneWidget);
    });

    testWidgets('passes multiple Runes', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage(
            '/org/:org/repo/:repo',
            (wp) => Text('${wp.runes['org']}/${wp.runes['repo']}'),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/org/ikolvi/repo/titan');
      await tester.pumpAndSettle();

      expect(find.text('ikolvi/titan'), findsOneWidget);
    });
  });

  group('Atlas — query parameters', () {
    testWidgets('passes query parameters', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/search', (wp) => Text('q=${wp.query['q']}')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/search?q=dart');
      await tester.pumpAndSettle();

      expect(find.text('q=dart'), findsOneWidget);
    });
  });

  group('Atlas — extra data', () {
    testWidgets('passes extra data through navigation', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/detail', (wp) => Text('Extra: ${wp.extra}')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/detail', extra: 'payload');
      await tester.pumpAndSettle();

      expect(find.text('Extra: payload'), findsOneWidget);
    });
  });

  group('Atlas — named routes', () {
    testWidgets('navigates by name with toNamed()', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage(
            '/user/:id',
            (wp) => Text('User ${wp.runes['id']}'),
            name: 'user',
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.toNamed('user', runes: {'id': '99'});
      await tester.pumpAndSettle();

      expect(find.text('User 99'), findsOneWidget);
    });

    testWidgets('throws for unknown named route', (tester) async {
      Atlas(passages: [Passage('/', (_) => const Text('Home'))]);

      expect(() => Atlas.toNamed('nonexistent'), throwsA(isA<StateError>()));
    });
  });

  group('Atlas — Sentinel (route guards)', () {
    testWidgets('redirects when Sentinel blocks', (tester) async {
      var loggedIn = false;

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
          Passage('/dashboard', (_) => const Text('Dashboard')),
        ],
        sentinels: [
          Sentinel((path, _) {
            if (path == '/dashboard' && !loggedIn) return '/login';
            return null;
          }),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/dashboard');
      await tester.pumpAndSettle();

      // Should redirect to /login
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);

      // Now log in and try again
      loggedIn = true;
      Atlas.to('/dashboard');
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('Sentinel.only guards specific paths', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
          Passage('/admin', (_) => const Text('Admin')),
          Passage('/public', (_) => const Text('Public')),
        ],
        sentinels: [
          Sentinel.only(paths: {'/admin'}, guard: (path, _) => '/login'),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      // Public should NOT be guarded
      Atlas.to('/public');
      await tester.pumpAndSettle();
      expect(find.text('Public'), findsOneWidget);

      // Admin should redirect to login
      Atlas.to('/admin');
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });
  });

  group('Atlas — Drift (redirect)', () {
    testWidgets('global drift redirects', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/new-home', (_) => const Text('New Home')),
        ],
        drift: (path, _) {
          if (path == '/old-home') return '/new-home';
          return null;
        },
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/old-home');
      await tester.pumpAndSettle();

      expect(find.text('New Home'), findsOneWidget);
    });
  });

  group('Atlas — 404 / error handling', () {
    testWidgets('shows default 404 for unknown route', (tester) async {
      final atlas = Atlas(passages: [Passage('/', (_) => const Text('Home'))]);

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/nonexistent');
      await tester.pumpAndSettle();

      expect(find.text('404'), findsOneWidget);
    });

    testWidgets('uses custom error page', (tester) async {
      final atlas = Atlas(
        passages: [Passage('/', (_) => const Text('Home'))],
        onError: (path) => Text('Custom 404: $path'),
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/missing');
      await tester.pumpAndSettle();

      expect(find.text('Custom 404: /missing'), findsOneWidget);
    });
  });

  group('Atlas — Sanctum (shell routes)', () {
    testWidgets('wraps routes in shell', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Sanctum(
            shell: (child) => Column(
              children: [
                const Text('Shell'),
                Expanded(child: child),
              ],
            ),
            passages: [
              Passage('/tab1', (_) => const Text('Tab 1')),
              Passage('/tab2', (_) => const Text('Tab 2')),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/tab1');
      await tester.pumpAndSettle();

      expect(find.text('Shell'), findsOneWidget);
      expect(find.text('Tab 1'), findsOneWidget);
    });
  });

  group('Atlas — Shift (transitions)', () {
    testWidgets('uses Shift.none for instant transition', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage(
            '/instant',
            (_) => const Text('Instant'),
            shift: Shift.none(),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/instant');
      await tester.pump(); // Single pump — instant transition

      expect(find.text('Instant'), findsOneWidget);
    });
  });

  group('Atlas — backTo', () {
    testWidgets('pops until matching route', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
          Passage('/b', (_) => const Text('B')),
          Passage('/c', (_) => const Text('C')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/a');
      await tester.pumpAndSettle();
      Atlas.to('/b');
      await tester.pumpAndSettle();
      Atlas.to('/c');
      await tester.pumpAndSettle();

      Atlas.backTo('/a');
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget);
    });
  });

  group('Atlas — context extension', () {
    testWidgets('context.atlas.to navigates', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage(
            '/',
            (_) => Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => context.atlas.to('/target'),
                child: const Text('Go'),
              ),
            ),
          ),
          Passage('/target', (_) => const Text('Target')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.text('Target'), findsOneWidget);
    });

    testWidgets('context.atlas.back goes back', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage(
            '/second',
            (_) => Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => context.atlas.back(),
                child: const Text('Back'),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/second');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('Atlas — initialPath', () {
    testWidgets('starts at custom initial path', (tester) async {
      final atlas = Atlas(
        initialPath: '/welcome',
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/welcome', (_) => const Text('Welcome')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    });
  });

  group('Atlas — push with result', () {
    testWidgets('push returns result when back is called with value', (
      tester,
    ) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/dialog', (_) => const Text('Dialog')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      // Push and capture the future
      final future = Atlas.push<bool>('/dialog');
      await tester.pumpAndSettle();

      expect(find.text('Dialog'), findsOneWidget);

      // Pop with result
      Atlas.back(true);
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, true);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('push returns null when back is called without value', (
      tester,
    ) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/confirm', (_) => const Text('Confirm')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      final future = Atlas.push<String>('/confirm');
      await tester.pumpAndSettle();

      Atlas.back();
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNull);
    });

    testWidgets('push returns typed result', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/picker', (_) => const Text('Picker')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      final future = Atlas.push<Map<String, dynamic>>('/picker');
      await tester.pumpAndSettle();

      Atlas.back({'id': 42, 'name': 'Titan'});
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, {'id': 42, 'name': 'Titan'});
    });

    testWidgets('push completes with null when go() is called', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
          Passage('/b', (_) => const Text('B')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      final future = Atlas.push<bool>('/a');
      await tester.pumpAndSettle();

      // go() replaces the stack, should complete with null
      Atlas.go('/b');
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNull);
    });

    testWidgets('push completes with null when reset() is called', (
      tester,
    ) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/modal', (_) => const Text('Modal')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      final future = Atlas.push<int>('/modal');
      await tester.pumpAndSettle();

      Atlas.reset('/');
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNull);
    });

    testWidgets('push completes with null when replace() is called', (
      tester,
    ) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/a', (_) => const Text('A')),
          Passage('/b', (_) => const Text('B')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      final future = Atlas.push<bool>('/a');
      await tester.pumpAndSettle();

      Atlas.replace('/b');
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, isNull);
    });
  });
}
