import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

// ---------------------------------------------------------------------------
// Test Pillars
// ---------------------------------------------------------------------------

class AuthPillar extends Pillar {
  late final user = core<String?>('guest');
  bool disposed = false;

  @override
  void onDispose() {
    disposed = true;
  }
}

class CheckoutPillar extends Pillar {
  late final total = core(0.0);
  bool disposed = false;

  @override
  void onDispose() {
    disposed = true;
  }
}

class DashboardPillar extends Pillar {
  late final tab = core(0);
  bool disposed = false;

  @override
  void onDispose() {
    disposed = true;
  }
}

class SettingsPillar extends Pillar {
  late final darkMode = core(false);
  bool disposed = false;

  @override
  void onDispose() {
    disposed = true;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _app(Atlas atlas) => MaterialApp.router(routerConfig: atlas.config);

void main() {
  setUp(() => Titan.reset());
  tearDown(() => Titan.reset());

  group('Atlas global pillars', () {
    testWidgets('registers global Pillars via Titan.put on construction',
        (tester) async {
      final atlas = Atlas(
        pillars: [AuthPillar.new],
        passages: [
          Passage('/', (_) => const Text('Home')),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      // AuthPillar should be accessible via Titan DI
      expect(Titan.has<AuthPillar>(), isTrue);
      final auth = Titan.get<AuthPillar>();
      expect(auth.user.value, 'guest');
    });

    testWidgets('multiple global Pillars all accessible', (tester) async {
      final atlas = Atlas(
        pillars: [AuthPillar.new, DashboardPillar.new],
        passages: [
          Passage('/', (_) => const Text('Home')),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      expect(Titan.has<AuthPillar>(), isTrue);
      expect(Titan.has<DashboardPillar>(), isTrue);
    });

    testWidgets('global Pillars accessible in Passage builders',
        (tester) async {
      final atlas = Atlas(
        pillars: [AuthPillar.new],
        passages: [
          Passage('/', (_) {
            final auth = Titan.get<AuthPillar>();
            return Text('User: ${auth.user.value}');
          }),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      expect(find.text('User: guest'), findsOneWidget);
    });

    testWidgets('global Pillars accessible in Sentinel guards',
        (tester) async {
      final atlas = Atlas(
        pillars: [AuthPillar.new],
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/login', (_) => const Text('Login')),
          Passage('/admin', (_) => const Text('Admin')),
        ],
        sentinels: [
          Sentinel.only(
            paths: {'/admin'},
            guard: (path, _) {
              final auth = Titan.get<AuthPillar>();
              return auth.user.value == 'guest' ? '/login' : null;
            },
          ),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      // Navigate to admin — should redirect to login since user is guest
      Atlas.to('/admin');
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });
  });

  group('Route-scoped Pillars (Passage)', () {
    testWidgets('creates Pillars when route is pushed', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/checkout', (_) {
            final checkout = Titan.get<CheckoutPillar>();
            return Text('Total: ${checkout.total.value}');
          }, pillars: [CheckoutPillar.new]),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      // CheckoutPillar should NOT exist yet
      expect(Titan.has<CheckoutPillar>(), isFalse);

      // Navigate to checkout
      Atlas.to('/checkout');
      await tester.pumpAndSettle();

      // Now it should exist
      expect(Titan.has<CheckoutPillar>(), isTrue);
      expect(find.text('Total: 0.0'), findsOneWidget);
    });

    testWidgets('disposes Pillars when route is popped', (tester) async {
      late CheckoutPillar checkoutRef;

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/checkout', (_) {
            checkoutRef = Titan.get<CheckoutPillar>();
            return const Text('Checkout');
          }, pillars: [CheckoutPillar.new]),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      // Navigate to checkout
      Atlas.to('/checkout');
      await tester.pumpAndSettle();
      expect(Titan.has<CheckoutPillar>(), isTrue);
      expect(checkoutRef.disposed, isFalse);

      // Go back
      Atlas.back();
      await tester.pumpAndSettle();

      // Pillar should be disposed and removed
      expect(Titan.has<CheckoutPillar>(), isFalse);
      expect(checkoutRef.disposed, isTrue);
    });

    testWidgets('disposes Pillars on replace', (tester) async {
      late CheckoutPillar checkoutRef;

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/checkout', (_) {
            checkoutRef = Titan.get<CheckoutPillar>();
            return const Text('Checkout');
          }, pillars: [CheckoutPillar.new]),
          Passage('/done', (_) => const Text('Done')),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      Atlas.to('/checkout');
      await tester.pumpAndSettle();
      expect(Titan.has<CheckoutPillar>(), isTrue);

      // Replace with /done
      Atlas.replace('/done');
      await tester.pumpAndSettle();

      expect(Titan.has<CheckoutPillar>(), isFalse);
      expect(checkoutRef.disposed, isTrue);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('disposes all route Pillars on reset', (tester) async {
      late CheckoutPillar checkoutRef;

      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/checkout', (_) {
            checkoutRef = Titan.get<CheckoutPillar>();
            return const Text('Checkout');
          }, pillars: [CheckoutPillar.new]),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      Atlas.to('/checkout');
      await tester.pumpAndSettle();

      // Reset to home
      Atlas.reset('/');
      await tester.pumpAndSettle();

      expect(Titan.has<CheckoutPillar>(), isFalse);
      expect(checkoutRef.disposed, isTrue);
    });

    testWidgets('multiple route-scoped Pillars on same Passage',
        (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/checkout', (_) => const Text('Checkout'),
              pillars: [CheckoutPillar.new, SettingsPillar.new]),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      Atlas.to('/checkout');
      await tester.pumpAndSettle();

      expect(Titan.has<CheckoutPillar>(), isTrue);
      expect(Titan.has<SettingsPillar>(), isTrue);

      Atlas.back();
      await tester.pumpAndSettle();

      expect(Titan.has<CheckoutPillar>(), isFalse);
      expect(Titan.has<SettingsPillar>(), isFalse);
    });
  });

  group('Shell-scoped Pillars (Sanctum)', () {
    testWidgets('creates Pillar when entering Sanctum passage',
        (tester) async {
      final atlas = Atlas(
        passages: [
          Sanctum(
            pillars: [DashboardPillar.new],
            shell: (child) => Column(children: [
              const Text('Shell'),
              Expanded(child: child),
            ]),
            passages: [
              Passage('/', (_) {
                final dash = Titan.get<DashboardPillar>();
                return Text('Tab: ${dash.tab.value}');
              }),
            ],
          ),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      expect(Titan.has<DashboardPillar>(), isTrue);
      expect(find.text('Tab: 0'), findsOneWidget);
    });

    testWidgets(
        'Sanctum Pillars combined with Passage Pillars', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Sanctum(
            pillars: [DashboardPillar.new],
            shell: (child) => child,
            passages: [
              Passage('/settings', (_) => const Text('Settings'),
                  pillars: [SettingsPillar.new]),
            ],
          ),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      Atlas.to('/settings');
      await tester.pumpAndSettle();

      // Both Sanctum + Passage Pillars should be registered
      expect(Titan.has<DashboardPillar>(), isTrue);
      expect(Titan.has<SettingsPillar>(), isTrue);

      Atlas.back();
      await tester.pumpAndSettle();

      // Both should be cleaned up when leaving the stack
      expect(Titan.has<DashboardPillar>(), isFalse);
      expect(Titan.has<SettingsPillar>(), isFalse);
    });
  });

  group('Combined: global + route-scoped', () {
    testWidgets('global survives route pops, route-scoped does not',
        (tester) async {
      late CheckoutPillar checkoutRef;

      final atlas = Atlas(
        pillars: [AuthPillar.new],
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/checkout', (_) {
            checkoutRef = Titan.get<CheckoutPillar>();
            return const Text('Checkout');
          }, pillars: [CheckoutPillar.new]),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      expect(Titan.has<AuthPillar>(), isTrue);

      Atlas.to('/checkout');
      await tester.pumpAndSettle();
      expect(Titan.has<CheckoutPillar>(), isTrue);

      Atlas.back();
      await tester.pumpAndSettle();

      // AuthPillar (global) persists, CheckoutPillar (route) is gone
      expect(Titan.has<AuthPillar>(), isTrue);
      expect(Titan.has<CheckoutPillar>(), isFalse);
      expect(checkoutRef.disposed, isTrue);
    });

    testWidgets('global Pillars usable in route-scoped Pillar builders',
        (tester) async {
      final atlas = Atlas(
        pillars: [AuthPillar.new],
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/checkout', (_) {
            final auth = Titan.get<AuthPillar>();
            final checkout = Titan.get<CheckoutPillar>();
            return Text('${auth.user.value} - ${checkout.total.value}');
          }, pillars: [CheckoutPillar.new]),
        ],
      );

      await tester.pumpWidget(_app(atlas));
      await tester.pumpAndSettle();

      Atlas.to('/checkout');
      await tester.pumpAndSettle();

      expect(find.text('guest - 0.0'), findsOneWidget);
    });
  });

  group('Titan.removeByType', () {
    test('removes instance by runtime type', () {
      final auth = AuthPillar();
      Titan.put(auth);
      expect(Titan.has<AuthPillar>(), isTrue);

      Titan.removeByType(AuthPillar);
      expect(Titan.has<AuthPillar>(), isFalse);
      expect(auth.disposed, isTrue);
    });

    test('removes and disposes Pillar', () {
      final pillar = CheckoutPillar();
      Titan.put(pillar);

      Titan.removeByType(CheckoutPillar);
      expect(pillar.disposed, isTrue);
    });

    test('no-op for unregistered type', () {
      final result = Titan.removeByType(AuthPillar);
      expect(result, isNull);
    });
  });
}
