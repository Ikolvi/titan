import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

class _TestPillar extends Pillar {
  late final value = core('original');
}

class _MockTestPillar extends Pillar {
  late final value = core('mocked');
}

class _AnotherPillar extends Pillar {
  late final count = core(42);
}

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

  group('PillarScope', () {
    testWidgets('provides Pillar instances to child subtree', (tester) async {
      final pillar = _TestPillar()..initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: PillarScope(
            overrides: [pillar],
            child: Vestige<_TestPillar>(builder: (_, p) => Text(p.value.value)),
          ),
        ),
      );

      expect(find.text('original'), findsOneWidget);

      pillar.dispose();
    });

    testWidgets('overrides ancestor Beacon Pillar', (tester) async {
      final mock = _MockTestPillar()..initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [_TestPillar.new],
            child: PillarScope(
              overrides: [mock],
              child: Vestige<_MockTestPillar>(
                builder: (_, p) => Text(p.value.value),
              ),
            ),
          ),
        ),
      );

      // PillarScope's _MockTestPillar is resolved
      expect(find.text('mocked'), findsOneWidget);

      mock.dispose();
    });

    testWidgets('provides multiple Pillars', (tester) async {
      final pillar1 = _TestPillar()..initialize();
      final pillar2 = _AnotherPillar()..initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: PillarScope(
            overrides: [pillar1, pillar2],
            child: Column(
              children: [
                Vestige<_TestPillar>(builder: (_, p) => Text(p.value.value)),
                Vestige<_AnotherPillar>(
                  builder: (_, p) => Text('${p.count.value}'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('original'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      pillar1.dispose();
      pillar2.dispose();
    });

    testWidgets('does not dispose Pillars when removed', (tester) async {
      final pillar = _TestPillar()..initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: PillarScope(
            overrides: [pillar],
            child: Vestige<_TestPillar>(builder: (_, p) => Text(p.value.value)),
          ),
        ),
      );

      expect(find.text('original'), findsOneWidget);

      // Remove the PillarScope — Pillar should NOT be disposed
      await tester.pumpWidget(MaterialApp(home: SizedBox.shrink()));

      // Pillar is still alive (unlike Beacon which disposes)
      expect(pillar.isDisposed, isFalse);

      pillar.dispose();
    });

    testWidgets('updates reactively when Core changes', (tester) async {
      final pillar = _TestPillar()..initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: PillarScope(
            overrides: [pillar],
            child: Vestige<_TestPillar>(builder: (_, p) => Text(p.value.value)),
          ),
        ),
      );

      expect(find.text('original'), findsOneWidget);

      pillar.value.value = 'updated';
      await tester.pump();

      expect(find.text('updated'), findsOneWidget);

      pillar.dispose();
    });
  });
}
