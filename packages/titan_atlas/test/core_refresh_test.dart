import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

// ---------------------------------------------------------------------------
// Test Pillar for auth simulation
// ---------------------------------------------------------------------------

class _AuthPillar extends Pillar {
  late final isLoggedIn = core(false);
  late final role = core<String?>(null);
}

void main() {
  setUp(() {
    Titan.reset();
  });

  // ---------------------------------------------------------
  // CoreRefresh — reactive bridge
  // ---------------------------------------------------------

  group('CoreRefresh', () {
    test('notifies listeners when a Core value changes', () {
      final auth = _AuthPillar();
      final refresh = CoreRefresh([auth.isLoggedIn]);

      var notified = 0;
      refresh.addListener(() => notified++);

      auth.isLoggedIn.value = true;
      expect(notified, 1);

      auth.isLoggedIn.value = false;
      expect(notified, 2);

      refresh.dispose();
    });

    test('notifies on any of multiple Core changes', () {
      final auth = _AuthPillar();
      final refresh = CoreRefresh([auth.isLoggedIn, auth.role]);

      var notified = 0;
      refresh.addListener(() => notified++);

      auth.isLoggedIn.value = true;
      expect(notified, 1);

      auth.role.value = 'admin';
      expect(notified, 2);

      refresh.dispose();
    });

    test('does not notify after dispose', () {
      final auth = _AuthPillar();
      final refresh = CoreRefresh([auth.isLoggedIn]);

      var notified = 0;
      refresh.addListener(() => notified++);

      refresh.dispose();

      auth.isLoggedIn.value = true;
      expect(notified, 0);
    });

    test('handles empty cores list', () {
      final refresh = CoreRefresh([]);
      // Should not throw
      refresh.dispose();
    });
  });

  // ---------------------------------------------------------
  // Atlas — refreshListenable integration
  // ---------------------------------------------------------

  group('Atlas — refreshListenable', () {
    testWidgets('redirects unauthenticated user to login on refresh', (
      tester,
    ) async {
      final auth = _AuthPillar();
      auth.isLoggedIn.value = true;

      final refresh = CoreRefresh([auth.isLoggedIn]);

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: [
          Sentinel.except(
            paths: {'/login'},
            guard: (path, _) => auth.isLoggedIn.peek() ? null : '/login',
          ),
        ],
        refreshListenable: refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      // Initially on Home (authenticated)
      expect(find.text('Home'), findsOneWidget);

      // Sign out → triggers refresh → Sentinel redirects to /login
      auth.isLoggedIn.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);

      refresh.dispose();
    });

    testWidgets('redirects authenticated user away from login on refresh', (
      tester,
    ) async {
      final auth = _AuthPillar();
      auth.isLoggedIn.value = false;

      final refresh = CoreRefresh([auth.isLoggedIn]);

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: [
          // Redirect unauthenticated to /login
          Sentinel.except(
            paths: {'/login'},
            guard: (path, _) => auth.isLoggedIn.peek() ? null : '/login',
          ),
          // Redirect authenticated away from /login
          Sentinel.only(
            paths: {'/login'},
            guard: (path, _) => auth.isLoggedIn.peek() ? '/' : null,
          ),
        ],
        refreshListenable: refresh,
        initialPath: '/login',
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      // Initially on Login (not authenticated)
      expect(find.text('Login'), findsOneWidget);

      // Sign in → triggers refresh → Sentinel redirects to /
      auth.isLoggedIn.value = true;
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

      refresh.dispose();
    });

    testWidgets('does not navigate when Sentinel allows current path', (
      tester,
    ) async {
      final auth = _AuthPillar();
      auth.isLoggedIn.value = true;

      final refresh = CoreRefresh([auth.isLoggedIn, auth.role]);

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: [
          Sentinel.except(
            paths: {'/login'},
            guard: (path, _) => auth.isLoggedIn.peek() ? null : '/login',
          ),
        ],
        refreshListenable: refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

      // Changing role (not isLoggedIn) should NOT redirect
      auth.role.value = 'admin';
      await tester.pumpAndSettle();

      // Still on Home
      expect(find.text('Home'), findsOneWidget);

      refresh.dispose();
    });

    testWidgets('works with Drift redirect', (tester) async {
      final auth = _AuthPillar();
      auth.isLoggedIn.value = true;

      final refresh = CoreRefresh([auth.isLoggedIn]);

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        drift: (path, _) => auth.isLoggedIn.peek() ? null : '/login',
        refreshListenable: refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

      // Sign out → drift redirects to /login
      auth.isLoggedIn.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);

      refresh.dispose();
    });

    testWidgets('works with Garrison.authGuard', (tester) async {
      final auth = _AuthPillar();
      auth.isLoggedIn.value = true;

      final refresh = CoreRefresh([auth.isLoggedIn]);

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
          Passage('/register', (_) => const Text('Register')),
        ],
        sentinels: [
          Garrison.authGuard(
            isAuthenticated: () => auth.isLoggedIn.peek(),
            loginPath: '/login',
            publicPaths: {'/login', '/register'},
          ),
        ],
        refreshListenable: refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

      // Sign out → Garrison guard redirects to /login
      auth.isLoggedIn.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);

      refresh.dispose();
    });

    testWidgets('works with ChangeNotifier (Flutter Listenable)', (
      tester,
    ) async {
      final notifier = ValueNotifier<bool>(true);

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: [
          Sentinel.except(
            paths: {'/login'},
            guard: (path, _) => notifier.value ? null : '/login',
          ),
        ],
        refreshListenable: notifier,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

      notifier.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);

      notifier.dispose();
    });

    testWidgets('Atlas without refreshListenable still works', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/about', (_) => const Text('About')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

      Atlas.to('/about');
      await tester.pumpAndSettle();
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('cleans up old refresh listener when new Atlas is created', (
      tester,
    ) async {
      final auth = _AuthPillar();
      auth.isLoggedIn.value = true;

      final refresh1 = CoreRefresh([auth.isLoggedIn]);

      // First Atlas
      Atlas(
        passages: [
          Passage('/', (_) => const Text('Home1')),
          Passage('/login', (_) => const Text('Login1')),
        ],
        sentinels: [
          Sentinel.except(
            paths: {'/login'},
            guard: (path, _) => auth.isLoggedIn.peek() ? null : '/login',
          ),
        ],
        refreshListenable: refresh1,
      );

      final refresh2 = CoreRefresh([auth.isLoggedIn]);

      // Second Atlas — should clean up first Atlas's listener
      final atlas2 = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home2')),
          Passage('/login', (_) => const Text('Login2')),
        ],
        sentinels: [
          Sentinel.except(
            paths: {'/login'},
            guard: (path, _) => auth.isLoggedIn.peek() ? null : '/login',
          ),
        ],
        refreshListenable: refresh2,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas2.config));
      await tester.pumpAndSettle();

      expect(find.text('Home2'), findsOneWidget);

      // Sign out → should use second Atlas's sentinel
      auth.isLoggedIn.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Login2'), findsOneWidget);

      refresh1.dispose();
      refresh2.dispose();
    });

    testWidgets('handles rapid state changes without errors', (tester) async {
      final auth = _AuthPillar();
      auth.isLoggedIn.value = true;

      final refresh = CoreRefresh([auth.isLoggedIn]);

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: [
          Sentinel.except(
            paths: {'/login'},
            guard: (path, _) => auth.isLoggedIn.peek() ? null : '/login',
          ),
          Sentinel.only(
            paths: {'/login'},
            guard: (path, _) => auth.isLoggedIn.peek() ? '/' : null,
          ),
        ],
        refreshListenable: refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      // Rapid toggles
      auth.isLoggedIn.value = false;
      auth.isLoggedIn.value = true;
      auth.isLoggedIn.value = false;
      await tester.pumpAndSettle();

      // Should end up on Login (last state was false)
      expect(find.text('Login'), findsOneWidget);

      refresh.dispose();
    });
  });

  // ---------------------------------------------------------
  // Garrison.refreshAuth — convenience factory
  // ---------------------------------------------------------

  group('Garrison.refreshAuth', () {
    test('returns sentinels and refresh listenable', () {
      final auth = _AuthPillar();
      Titan.put(auth);

      final result = Garrison.refreshAuth(
        isAuthenticated: () => auth.isLoggedIn.value,
        cores: [auth.isLoggedIn],
        loginPath: '/login',
        homePath: '/',
        guestPaths: {'/login'},
      );

      expect(result.sentinels, hasLength(2)); // authGuard + guestOnly
      expect(result.refresh, isA<CoreRefresh>());
    });

    test('returns one sentinel when no guestPaths', () {
      final auth = _AuthPillar();
      Titan.put(auth);

      final result = Garrison.refreshAuth(
        isAuthenticated: () => auth.isLoggedIn.value,
        cores: [auth.isLoggedIn],
        loginPath: '/login',
        homePath: '/',
      );

      // No guestPaths → only authGuard sentinel
      expect(result.sentinels, hasLength(1));
    });

    testWidgets('redirects unauthenticated to login', (tester) async {
      final auth = _AuthPillar();
      Titan.put(auth);
      auth.isLoggedIn.value = false;

      final garrisonAuth = Garrison.refreshAuth(
        isAuthenticated: () => auth.isLoggedIn.value,
        cores: [auth.isLoggedIn],
        loginPath: '/login',
        homePath: '/',
        guestPaths: {'/login'},
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: garrisonAuth.sentinels,
        refreshListenable: garrisonAuth.refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));

      // Unauthenticated → redirected to login
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('auto-redirects on sign-in', (tester) async {
      final auth = _AuthPillar();
      Titan.put(auth);
      auth.isLoggedIn.value = false;

      final garrisonAuth = Garrison.refreshAuth(
        isAuthenticated: () => auth.isLoggedIn.value,
        cores: [auth.isLoggedIn],
        loginPath: '/login',
        homePath: '/',
        guestPaths: {'/login'},
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: garrisonAuth.sentinels,
        refreshListenable: garrisonAuth.refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));

      expect(find.text('Login'), findsOneWidget);

      // Sign in → CoreRefresh notifies → guestOnly redirects to /
      auth.isLoggedIn.value = true;
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('auto-redirects on sign-out', (tester) async {
      final auth = _AuthPillar();
      Titan.put(auth);
      auth.isLoggedIn.value = true;

      final garrisonAuth = Garrison.refreshAuth(
        isAuthenticated: () => auth.isLoggedIn.value,
        cores: [auth.isLoggedIn],
        loginPath: '/login',
        homePath: '/',
        guestPaths: {'/login'},
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: garrisonAuth.sentinels,
        refreshListenable: garrisonAuth.refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));

      expect(find.text('Home'), findsOneWidget);

      // Sign out → CoreRefresh notifies → authGuard redirects to /login
      auth.isLoggedIn.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('respects publicPaths', (tester) async {
      final auth = _AuthPillar();
      Titan.put(auth);
      auth.isLoggedIn.value = false;

      final garrisonAuth = Garrison.refreshAuth(
        isAuthenticated: () => auth.isLoggedIn.value,
        cores: [auth.isLoggedIn],
        loginPath: '/login',
        homePath: '/',
        publicPaths: {'/about'},
        guestPaths: {'/login'},
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
          Passage('/about', (_) => const Text('About')),
        ],
        sentinels: garrisonAuth.sentinels,
        refreshListenable: garrisonAuth.refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));

      // Navigate to /about — should be allowed (public)
      Atlas.to('/about');
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('works with multiple cores', (tester) async {
      final auth = _AuthPillar();
      Titan.put(auth);
      auth.isLoggedIn.value = true;
      auth.role.value = 'user';

      final garrisonAuth = Garrison.refreshAuth(
        isAuthenticated: () => auth.isLoggedIn.value,
        cores: [auth.isLoggedIn, auth.role],
        loginPath: '/login',
        homePath: '/',
        guestPaths: {'/login'},
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: garrisonAuth.sentinels,
        refreshListenable: garrisonAuth.refresh,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));

      expect(find.text('Home'), findsOneWidget);

      // Changing role triggers refresh but stays on Home (still authenticated)
      auth.role.value = 'admin';
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);

      // Sign out triggers redirect to login
      auth.isLoggedIn.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------
  // Post-login redirect — preserveRedirect + guestOnly
  // ---------------------------------------------------------

  group('Post-login redirect', () {
    test('guestOnly uses redirect query param when authenticated', () {
      final sentinel = Garrison.guestOnly(
        isAuthenticated: () => true,
        guestPaths: {'/login'},
        redirectPath: '/',
      );

      // Waypoint with redirect query param
      final waypoint = Waypoint(
        path: '/login',
        pattern: '/login',
        query: {'redirect': '%2Fquest%2F42'},
      );

      final result = sentinel.evaluate('/login', waypoint);
      expect(result, '/quest/42');
    });

    test('guestOnly falls back to redirectPath without redirect param', () {
      final sentinel = Garrison.guestOnly(
        isAuthenticated: () => true,
        guestPaths: {'/login'},
        redirectPath: '/',
      );

      final waypoint = Waypoint(path: '/login', pattern: '/login');

      final result = sentinel.evaluate('/login', waypoint);
      expect(result, '/');
    });

    test('guestOnly ignores redirect param when useRedirectQuery is false', () {
      final sentinel = Garrison.guestOnly(
        isAuthenticated: () => true,
        guestPaths: {'/login'},
        redirectPath: '/',
        useRedirectQuery: false,
      );

      final waypoint = Waypoint(
        path: '/login',
        pattern: '/login',
        query: {'redirect': '%2Fquest%2F42'},
      );

      final result = sentinel.evaluate('/login', waypoint);
      expect(result, '/');
    });

    test('guestOnly returns null when not authenticated', () {
      final sentinel = Garrison.guestOnly(
        isAuthenticated: () => false,
        guestPaths: {'/login'},
        redirectPath: '/',
      );

      final waypoint = Waypoint(
        path: '/login',
        pattern: '/login',
        query: {'redirect': '%2Fquest%2F42'},
      );

      final result = sentinel.evaluate('/login', waypoint);
      expect(result, isNull);
    });

    testWidgets(
      'authGuard preserveRedirect → guestOnly redirects to original page',
      (tester) async {
        final auth = _AuthPillar();
        Titan.put(auth);
        auth.isLoggedIn.value = false;

        final garrisonAuth = Garrison.refreshAuth(
          isAuthenticated: () => auth.isLoggedIn.value,
          cores: [auth.isLoggedIn],
          loginPath: '/login',
          homePath: '/',
          guestPaths: {'/login'},
          preserveRedirect: true,
        );

        final atlas = Atlas(
          passages: [
            Passage('/', (_) => const Text('Home')),
            Passage('/login', (wp) => Text('Login:${wp.query['redirect']}')),
            Passage('/quest/:id', (wp) => Text('Quest:${wp.runes['id']}')),
          ],
          sentinels: garrisonAuth.sentinels,
          refreshListenable: garrisonAuth.refresh,
          // Simulate arriving at login with a redirect param already set
          // (as if authGuard had redirected from /quest/42)
          initialPath: '/login?redirect=%2Fquest%2F42',
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
        await tester.pumpAndSettle();

        // Unauthenticated → on login page with redirect param
        expect(find.textContaining('Login'), findsOneWidget);

        // Sign in → CoreRefresh re-evaluates → guestOnly reads redirect param
        auth.isLoggedIn.value = true;
        await tester.pumpAndSettle();

        // Should be redirected to the original quest page
        expect(find.text('Quest:42'), findsOneWidget);
      },
    );

    testWidgets('sign-in without redirect param goes to homePath', (
      tester,
    ) async {
      final auth = _AuthPillar();
      Titan.put(auth);
      auth.isLoggedIn.value = false;

      final garrisonAuth = Garrison.refreshAuth(
        isAuthenticated: () => auth.isLoggedIn.value,
        cores: [auth.isLoggedIn],
        loginPath: '/login',
        homePath: '/',
        guestPaths: {'/login'},
      );

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
        ],
        sentinels: garrisonAuth.sentinels,
        refreshListenable: garrisonAuth.refresh,
        initialPath: '/login',
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);

      // Sign in without redirect query param → goes to homePath (/)
      auth.isLoggedIn.value = true;
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });
  });
}
