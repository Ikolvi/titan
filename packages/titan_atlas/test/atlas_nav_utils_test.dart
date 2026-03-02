import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

void main() {
  setUp(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  tearDown(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  group('Atlas — navigation utilities', () {
    testWidgets('depth returns stack size', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/about', (_) => const Text('About')),
          Passage('/contact', (_) => const Text('Contact')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(Atlas.depth, 1);

      Atlas.to('/about');
      await tester.pumpAndSettle();
      expect(Atlas.depth, 2);

      Atlas.to('/contact');
      await tester.pumpAndSettle();
      expect(Atlas.depth, 3);
    });

    testWidgets('stack returns waypoint list', (tester) async {
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

      final stack = Atlas.stack;
      expect(stack, hasLength(2));
      expect(stack[0].path, '/');
      expect(stack[1].path, '/about');
    });

    testWidgets('isAt checks current path', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/about', (_) => const Text('About')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(Atlas.isAt('/'), isTrue);
      expect(Atlas.isAt('/about'), isFalse);

      Atlas.to('/about');
      await tester.pumpAndSettle();

      expect(Atlas.isAt('/about'), isTrue);
      expect(Atlas.isAt('/'), isFalse);
    });

    testWidgets('hasInStack checks if path exists in stack', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/about', (_) => const Text('About')),
          Passage('/contact', (_) => const Text('Contact')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      Atlas.to('/about');
      await tester.pumpAndSettle();

      expect(Atlas.hasInStack('/'), isTrue);
      expect(Atlas.hasInStack('/about'), isTrue);
      expect(Atlas.hasInStack('/contact'), isFalse);
    });

    testWidgets('hasRoute checks registered routes', (tester) async {
      final atlas = Atlas(
        passages: [
          Passage('/', (_) => const Text('Home')),
          Passage('/about', (_) => const Text('About')),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      expect(Atlas.hasRoute('/'), isTrue);
      expect(Atlas.hasRoute('/about'), isTrue);
      expect(Atlas.hasRoute('/nonexistent'), isFalse);
    });

    testWidgets('depth decreases on back', (tester) async {
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
      expect(Atlas.depth, 2);

      Atlas.back();
      await tester.pumpAndSettle();
      expect(Atlas.depth, 1);
    });

    testWidgets('stack is unmodifiable', (tester) async {
      final atlas = Atlas(passages: [Passage('/', (_) => const Text('Home'))]);

      await tester.pumpWidget(MaterialApp.router(routerConfig: atlas.config));
      await tester.pumpAndSettle();

      final stack = Atlas.stack;
      expect(
        () => stack.add(const Waypoint(path: '/x', pattern: '/x')),
        throwsUnsupportedError,
      );
    });
  });
}
