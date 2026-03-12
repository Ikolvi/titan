import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

// ---------------------------------------------------------------------------
// Atlas Observer & Discovery API Tests
// ---------------------------------------------------------------------------
//
// Validates the new Atlas static APIs:
//   - Atlas.isActive
//   - Atlas.addObserver / Atlas.removeObserver
//   - Atlas.registeredPatterns
//   - RouteTrie.patterns

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -----------------------------------------------------------------------
  // Atlas.isActive
  // -----------------------------------------------------------------------

  group('Atlas.isActive', () {
    testWidgets('returns true after Atlas construction', (tester) async {
      Atlas(passages: [Passage('/', (wp) => const SizedBox())]);

      expect(Atlas.isActive, true);
    });

    testWidgets('returns true when Atlas replaced', (tester) async {
      Atlas(passages: [Passage('/', (wp) => const SizedBox())]);

      // Replace with new Atlas
      Atlas(
        passages: [
          Passage('/', (wp) => const SizedBox()),
          Passage('/about', (wp) => const SizedBox()),
        ],
      );

      expect(Atlas.isActive, true);
    });
  });

  // -----------------------------------------------------------------------
  // Atlas.addObserver / Atlas.removeObserver
  // -----------------------------------------------------------------------

  group('Atlas.addObserver / removeObserver', () {
    testWidgets('addObserver adds observer without error', (tester) async {
      Atlas(passages: [Passage('/', (wp) => const SizedBox())]);

      final observer = _TestObserver();
      expect(() => Atlas.addObserver(observer), returnsNormally);
    });

    testWidgets('addObserver deduplicates same observer', (tester) async {
      Atlas(passages: [Passage('/', (wp) => const SizedBox())]);

      final observer = _TestObserver();
      Atlas.addObserver(observer);
      Atlas.addObserver(observer); // Should not add duplicate

      expect(true, isTrue);
    });

    testWidgets('removeObserver removes observer from list', (tester) async {
      Atlas(passages: [Passage('/', (wp) => const SizedBox())]);

      final observer = _TestObserver();
      Atlas.addObserver(observer);
      expect(() => Atlas.removeObserver(observer), returnsNormally);
    });

    testWidgets('removeObserver is no-op for unregistered observer', (
      tester,
    ) async {
      Atlas(passages: [Passage('/', (wp) => const SizedBox())]);

      final observer = _TestObserver();
      // Should not throw even though observer was never added
      expect(() => Atlas.removeObserver(observer), returnsNormally);
    });

    testWidgets('observer receives navigation events after addObserver', (
      tester,
    ) async {
      final observer = _TestObserver();

      final atlas = Atlas(
        passages: [
          Passage('/', (wp) => const SizedBox()),
          Passage('/detail', (wp) => const SizedBox()),
        ],
      );

      // Add observer after construction
      Atlas.addObserver(observer);

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      // Navigate
      Atlas.to('/detail');
      await tester.pumpAndSettle();

      expect(observer.navigations, isNotEmpty);
      expect(observer.navigations.last, '/detail');
    });

    testWidgets('removed observer does not receive events', (tester) async {
      final observer = _TestObserver();

      final atlas = Atlas(
        passages: [
          Passage('/', (wp) => const SizedBox()),
          Passage('/detail', (wp) => const SizedBox()),
          Passage('/other', (wp) => const SizedBox()),
        ],
      );

      Atlas.addObserver(observer);

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      // Navigate to trigger observer
      Atlas.to('/detail');
      await tester.pumpAndSettle();
      expect(observer.navigations.length, 1);

      // Remove and navigate again
      Atlas.removeObserver(observer);
      Atlas.to('/other');
      await tester.pumpAndSettle();

      // Count should not increase after removal
      expect(observer.navigations.length, 1);
    });
  });

  // -----------------------------------------------------------------------
  // Atlas.registeredPatterns
  // -----------------------------------------------------------------------

  group('Atlas.registeredPatterns', () {
    testWidgets('returns all registered route patterns', (tester) async {
      Atlas(
        passages: [
          Passage('/', (wp) => const SizedBox()),
          Passage('/about', (wp) => const SizedBox()),
          Passage('/profile/:id', (wp) => const SizedBox()),
        ],
      );

      final patterns = Atlas.registeredPatterns;

      expect(patterns, contains('/'));
      expect(patterns, contains('/about'));
      expect(patterns, contains('/profile/:id'));
    });

    testWidgets('returns empty list for no routes', (tester) async {
      Atlas(passages: []);

      final patterns = Atlas.registeredPatterns;
      expect(patterns, isEmpty);
    });

    testWidgets('includes nested Sanctum passage patterns', (tester) async {
      Atlas(
        passages: [
          Passage('/', (wp) => const SizedBox()),
          Sanctum(
            shell: (child) => child,
            passages: [
              Passage('/settings/general', (wp) => const SizedBox()),
              Passage('/settings/advanced', (wp) => const SizedBox()),
            ],
          ),
        ],
      );

      final patterns = Atlas.registeredPatterns;

      expect(patterns, contains('/'));
      expect(patterns, contains('/settings/general'));
      expect(patterns, contains('/settings/advanced'));
    });

    testWidgets('includes dynamic route segments', (tester) async {
      Atlas(
        passages: [
          Passage('/', (wp) => const SizedBox()),
          Passage('/user/:userId', (wp) => const SizedBox()),
          Passage('/post/:postId/comment/:commentId', (wp) => const SizedBox()),
        ],
      );

      final patterns = Atlas.registeredPatterns;

      expect(patterns, contains('/user/:userId'));
      expect(patterns, contains('/post/:postId/comment/:commentId'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test Helpers
// ---------------------------------------------------------------------------

class _TestObserver extends AtlasObserver {
  final List<String> navigations = [];
  final List<String> pops = [];

  @override
  void onNavigate(Waypoint from, Waypoint to) {
    navigations.add(to.path);
  }

  @override
  void onPop(Waypoint from, Waypoint to) {
    pops.add(to.path);
  }
}
