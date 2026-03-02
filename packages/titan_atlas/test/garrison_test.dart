import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

void main() {
  group('Garrison', () {
    Waypoint waypointFor(String path) =>
        Waypoint(path: path, pattern: path, runes: const {}, query: const {});

    group('authGuard', () {
      test('allows authenticated users', () {
        final sentinel = Garrison.authGuard(
          isAuthenticated: () => true,
          loginPath: '/login',
        );

        final result = sentinel.evaluate(
          '/dashboard',
          waypointFor('/dashboard'),
        );
        expect(result, isNull);
      });

      test('redirects unauthenticated users to login', () {
        final sentinel = Garrison.authGuard(
          isAuthenticated: () => false,
          loginPath: '/login',
        );

        final result = sentinel.evaluate(
          '/dashboard',
          waypointFor('/dashboard'),
        );
        expect(result, isNotNull);
        expect(result, contains('/login'));
      });

      test('preserves redirect URL by default', () {
        final sentinel = Garrison.authGuard(
          isAuthenticated: () => false,
          loginPath: '/login',
        );

        final result = sentinel.evaluate(
          '/dashboard',
          waypointFor('/dashboard'),
        );
        expect(result, contains('redirect='));
        expect(result, contains(Uri.encodeComponent('/dashboard')));
      });

      test('disables redirect preservation', () {
        final sentinel = Garrison.authGuard(
          isAuthenticated: () => false,
          loginPath: '/login',
          preserveRedirect: false,
        );

        final result = sentinel.evaluate(
          '/dashboard',
          waypointFor('/dashboard'),
        );
        expect(result, '/login');
      });

      test('allows public paths', () {
        final sentinel = Garrison.authGuard(
          isAuthenticated: () => false,
          loginPath: '/login',
          publicPaths: {'/login', '/register', '/'},
        );

        expect(sentinel.evaluate('/login', waypointFor('/login')), isNull);
        expect(
          sentinel.evaluate('/register', waypointFor('/register')),
          isNull,
        );
        expect(sentinel.evaluate('/', waypointFor('/')), isNull);
      });

      test('allows public prefixes', () {
        final sentinel = Garrison.authGuard(
          isAuthenticated: () => false,
          loginPath: '/login',
          publicPrefixes: {'/public/', '/api/'},
        );

        expect(
          sentinel.evaluate('/public/about', waypointFor('/public/about')),
          isNull,
        );
        expect(
          sentinel.evaluate('/api/health', waypointFor('/api/health')),
          isNull,
        );
        expect(
          sentinel.evaluate('/dashboard', waypointFor('/dashboard')),
          isNotNull,
        );
      });
    });

    group('roleGuard', () {
      test('allows matching role', () {
        final sentinel = Garrison.roleGuard(
          getRole: () => 'admin',
          rules: {
            '/admin': {'admin'},
          },
        );

        final result = sentinel.evaluate('/admin', waypointFor('/admin'));
        expect(result, isNull);
      });

      test('blocks non-matching role', () {
        final sentinel = Garrison.roleGuard(
          getRole: () => 'user',
          rules: {
            '/admin': {'admin'},
          },
          fallbackPath: '/unauthorized',
        );

        final result = sentinel.evaluate('/admin', waypointFor('/admin'));
        expect(result, '/unauthorized');
      });

      test('allows paths without rules', () {
        final sentinel = Garrison.roleGuard(
          getRole: () => 'user',
          rules: {
            '/admin': {'admin'},
          },
        );

        final result = sentinel.evaluate(
          '/dashboard',
          waypointFor('/dashboard'),
        );
        expect(result, isNull);
      });

      test('matches sub-paths', () {
        final sentinel = Garrison.roleGuard(
          getRole: () => 'user',
          rules: {
            '/admin': {'admin'},
          },
          fallbackPath: '/403',
        );

        final result = sentinel.evaluate(
          '/admin/settings',
          waypointFor('/admin/settings'),
        );
        expect(result, '/403');
      });

      test('multiple allowed roles', () {
        final sentinel = Garrison.roleGuard(
          getRole: () => 'manager',
          rules: {
            '/billing': {'admin', 'manager'},
          },
        );

        final result = sentinel.evaluate('/billing', waypointFor('/billing'));
        expect(result, isNull);
      });
    });

    group('rolesGuard', () {
      test('allows when user has matching role', () {
        final sentinel = Garrison.rolesGuard(
          getRoles: () => {'editor', 'viewer'},
          rules: {
            '/content': {'editor', 'admin'},
          },
        );

        final result = sentinel.evaluate('/content', waypointFor('/content'));
        expect(result, isNull);
      });

      test('blocks when no matching role', () {
        final sentinel = Garrison.rolesGuard(
          getRoles: () => {'viewer'},
          rules: {
            '/content': {'editor', 'admin'},
          },
          fallbackPath: '/403',
        );

        final result = sentinel.evaluate('/content', waypointFor('/content'));
        expect(result, '/403');
      });
    });

    group('onboardingGuard', () {
      test('allows onboarded users', () {
        final sentinel = Garrison.onboardingGuard(
          isOnboarded: () => true,
          onboardingPath: '/onboarding',
        );

        final result = sentinel.evaluate(
          '/dashboard',
          waypointFor('/dashboard'),
        );
        expect(result, isNull);
      });

      test('redirects non-onboarded users', () {
        final sentinel = Garrison.onboardingGuard(
          isOnboarded: () => false,
          onboardingPath: '/onboarding',
        );

        final result = sentinel.evaluate(
          '/dashboard',
          waypointFor('/dashboard'),
        );
        expect(result, '/onboarding');
      });

      test('allows the onboarding path itself', () {
        final sentinel = Garrison.onboardingGuard(
          isOnboarded: () => false,
          onboardingPath: '/onboarding',
        );

        final result = sentinel.evaluate(
          '/onboarding',
          waypointFor('/onboarding'),
        );
        expect(result, isNull);
      });

      test('allows exempt paths', () {
        final sentinel = Garrison.onboardingGuard(
          isOnboarded: () => false,
          onboardingPath: '/onboarding',
          exemptPaths: {'/logout', '/help'},
        );

        expect(sentinel.evaluate('/logout', waypointFor('/logout')), isNull);
        expect(sentinel.evaluate('/help', waypointFor('/help')), isNull);
      });
    });

    group('composite', () {
      test('evaluates guards in order', () {
        final loginStatus = <String, bool>{'loggedIn': true, 'verified': false};

        final sentinel = Garrison.composite([
          (path, _) => loginStatus['loggedIn']! ? null : '/login',
          (path, _) => loginStatus['verified']! ? null : '/verify',
        ]);

        // Logged in but not verified
        final result = sentinel.evaluate(
          '/dashboard',
          waypointFor('/dashboard'),
        );
        expect(result, '/verify');
      });

      test('returns null when all pass', () {
        final sentinel = Garrison.composite([
          (path, _) => null,
          (path, _) => null,
        ]);

        final result = sentinel.evaluate('/any', waypointFor('/any'));
        expect(result, isNull);
      });

      test('first failure wins', () {
        final sentinel = Garrison.composite([
          (path, _) => '/first',
          (path, _) => '/second',
        ]);

        final result = sentinel.evaluate('/any', waypointFor('/any'));
        expect(result, '/first');
      });
    });

    group('compositeAsync', () {
      test('evaluates async guards in order', () async {
        final sentinel = Garrison.compositeAsync([
          (path, _) async => null,
          (path, _) async => '/redirect',
        ]);

        final result = await sentinel.evaluateAsync(
          '/any',
          waypointFor('/any'),
        );
        expect(result, '/redirect');
      });
    });

    group('guestOnly', () {
      test('allows guests on guest pages', () {
        final sentinel = Garrison.guestOnly(
          isAuthenticated: () => false,
          guestPaths: {'/login', '/register'},
          redirectPath: '/dashboard',
        );

        expect(sentinel.evaluate('/login', waypointFor('/login')), isNull);
        expect(
          sentinel.evaluate('/register', waypointFor('/register')),
          isNull,
        );
      });

      test('redirects authenticated users from guest pages', () {
        final sentinel = Garrison.guestOnly(
          isAuthenticated: () => true,
          guestPaths: {'/login', '/register'},
          redirectPath: '/dashboard',
        );

        expect(
          sentinel.evaluate('/login', waypointFor('/login')),
          '/dashboard',
        );
        expect(
          sentinel.evaluate('/register', waypointFor('/register')),
          '/dashboard',
        );
      });

      test('allows authenticated users on non-guest pages', () {
        final sentinel = Garrison.guestOnly(
          isAuthenticated: () => true,
          guestPaths: {'/login'},
          redirectPath: '/dashboard',
        );

        expect(sentinel.evaluate('/about', waypointFor('/about')), isNull);
      });
    });
  });
}
