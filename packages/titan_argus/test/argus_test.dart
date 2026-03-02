import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_argus/titan_argus.dart';

// ---------------------------------------------------------------------------
// Test subclass of Argus
// ---------------------------------------------------------------------------

class _TestArgus extends Argus {
  late final username = core<String?>(null, name: 'username');
  late final role = core<String?>('user', name: 'role');

  @override
  List<ReactiveNode> get authCores => [isLoggedIn, role];

  @override
  void signIn([Map<String, dynamic>? credentials]) {
    strike(() {
      username.value = credentials?['name'] as String?;
      isLoggedIn.value = true;
    });
  }

  @override
  void signOut() {
    strike(() {
      isLoggedIn.value = false;
      username.value = null;
    });
  }
}

// ---------------------------------------------------------------------------
// Minimal Argus subclass (default signOut only)
// ---------------------------------------------------------------------------

class _MinimalArgus extends Argus {
  @override
  void signIn([Map<String, dynamic>? credentials]) {
    isLoggedIn.value = true;
  }
}

void main() {
  setUp(() {
    Titan.reset();
  });

  group('Argus', () {
    test('isLoggedIn defaults to false', () {
      final auth = _TestArgus();
      expect(auth.isLoggedIn.value, isFalse);
    });

    test('signIn sets isLoggedIn to true', () {
      final auth = _TestArgus();
      auth.signIn({'name': 'Kael'});
      expect(auth.isLoggedIn.value, isTrue);
      expect(auth.username.value, 'Kael');
    });

    test('signOut sets isLoggedIn to false', () {
      final auth = _TestArgus();
      auth.signIn({'name': 'Kael'});
      auth.signOut();
      expect(auth.isLoggedIn.value, isFalse);
      expect(auth.username.value, isNull);
    });

    test('default signOut sets isLoggedIn to false', () {
      final auth = _MinimalArgus();
      auth.signIn();
      expect(auth.isLoggedIn.value, isTrue);
      auth.signOut();
      expect(auth.isLoggedIn.value, isFalse);
    });

    test('authCores returns isLoggedIn by default', () {
      final auth = _MinimalArgus();
      expect(auth.authCores, [auth.isLoggedIn]);
    });

    test('authCores can be overridden', () {
      final auth = _TestArgus();
      expect(auth.authCores, [auth.isLoggedIn, auth.role]);
    });

    test('signIn without credentials works', () {
      final auth = _TestArgus();
      auth.signIn();
      expect(auth.isLoggedIn.value, isTrue);
      expect(auth.username.value, isNull);
    });

    test('extends Pillar — has reactive capabilities', () {
      final auth = _TestArgus();
      var changes = 0;
      auth.isLoggedIn.addListener(() => changes++);

      auth.signIn({'name': 'Kael'});
      expect(changes, 1);

      auth.signOut();
      expect(changes, 2);
    });
  });

  group('Argus.guard', () {
    test('returns GarrisonAuth with sentinels and refresh', () {
      final auth = _TestArgus();
      Titan.put(auth);

      final garrisonAuth = auth.guard(
        loginPath: '/login',
        homePath: '/',
        guestPaths: {'/login'},
      );

      expect(garrisonAuth.sentinels, hasLength(2));
      expect(garrisonAuth.refresh, isA<CoreRefresh>());
    });

    test('returns one sentinel when no guestPaths', () {
      final auth = _TestArgus();
      Titan.put(auth);

      final garrisonAuth = auth.guard(loginPath: '/login', homePath: '/');

      expect(garrisonAuth.sentinels, hasLength(1));
    });

    test('uses authCores for CoreRefresh', () {
      final auth = _TestArgus();
      Titan.put(auth);

      final garrisonAuth = auth.guard(loginPath: '/login', homePath: '/');

      // CoreRefresh uses authCores which includes isLoggedIn and role
      var notified = 0;
      (garrisonAuth.refresh as ChangeNotifier).addListener(() => notified++);

      auth.role.value = 'admin';
      expect(notified, 1); // role is in authCores → triggers refresh
    });

    testWidgets('auto-redirects on sign-in via Argus', (tester) async {
      final auth = _TestArgus();
      Titan.put(auth);

      final garrisonAuth = auth.guard(
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
      await tester.pumpAndSettle();

      // Unauthenticated → login
      expect(find.text('Login'), findsOneWidget);

      // Sign in via Argus → auto-redirect to home
      auth.signIn({'name': 'Kael'});
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('auto-redirects on sign-out via Argus', (tester) async {
      final auth = _TestArgus();
      Titan.put(auth);
      auth.signIn({'name': 'Kael'});

      final garrisonAuth = auth.guard(
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
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);

      // Sign out → auto-redirect to login
      auth.signOut();
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('respects publicPaths', (tester) async {
      final auth = _TestArgus();
      Titan.put(auth);

      final garrisonAuth = auth.guard(
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
      await tester.pumpAndSettle();

      // Navigate to /about — should be allowed (public)
      Atlas.to('/about');
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
    });
  });

  group('Argus — DI integration', () {
    test('works with Titan.put / Titan.get', () {
      final auth = _TestArgus();
      Titan.put(auth);

      final retrieved = Titan.get<_TestArgus>();
      expect(retrieved, same(auth));

      retrieved.signIn({'name': 'Kael'});
      expect(auth.isLoggedIn.value, isTrue);
    });

    test('can be registered as base type', () {
      final auth = _TestArgus();
      Titan.put<Argus>(auth);

      final retrieved = Titan.get<Argus>();
      expect(retrieved, same(auth));
      expect(retrieved.isLoggedIn.value, isFalse);
    });
  });
}
