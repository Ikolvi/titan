import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_argus/titan_argus.dart';

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

      expect(find.text('Home'), findsOneWidget);

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
        initialPath: '/login',
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);

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

      auth.role.value = 'admin';
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

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

      auth.isLoggedIn.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);

      refresh.dispose();
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

      auth.isLoggedIn.value = false;
      auth.isLoggedIn.value = true;
      auth.isLoggedIn.value = false;
      await tester.pumpAndSettle();

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

      expect(result.sentinels, hasLength(2));
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

      expect(result.sentinels, hasLength(1));
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

      final waypoint = Waypoint(
        path: '/login',
        pattern: '/login',
        query: {'redirect': '/quest/42'},
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
        query: {'redirect': '/quest/42'},
      );

      final result = sentinel.evaluate('/login', waypoint);
      expect(result, '/');
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
          initialPath: '/login?redirect=%2Fquest%2F42',
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
        await tester.pumpAndSettle();

        expect(find.textContaining('Login'), findsOneWidget);

        auth.isLoggedIn.value = true;
        await tester.pumpAndSettle();

        expect(find.text('Quest:42'), findsOneWidget);
      },
    );
  });
}
