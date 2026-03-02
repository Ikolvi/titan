import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

class _TestPillar extends Pillar {
  late final count = core(0);
  late final label = core('hello');
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

  group('VestigeWhen', () {
    testWidgets('renders first matching case', (tester) async {
      final pillar = _TestPillar();
      Titan.put(pillar);

      await tester.pumpWidget(
        MaterialApp(
          home: VestigeWhen<_TestPillar>(
            cases: [
              WhenCase(
                condition: (p) => p.count.value < 0,
                builder: (_, p) => Text('negative'),
              ),
              WhenCase(
                condition: (p) => p.count.value == 0,
                builder: (_, p) => Text('zero'),
              ),
              WhenCase(
                condition: (p) => p.count.value > 0,
                builder: (_, p) => Text('positive'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('zero'), findsOneWidget);
    });

    testWidgets('renders orElse when no case matches', (tester) async {
      final pillar = _TestPillar();
      pillar.count.value = 5;
      Titan.put(pillar);

      await tester.pumpWidget(
        MaterialApp(
          home: VestigeWhen<_TestPillar>(
            cases: [
              WhenCase(
                condition: (p) => p.count.value < 0,
                builder: (_, p) => Text('negative'),
              ),
              WhenCase(
                condition: (p) => p.count.value > 100,
                builder: (_, p) => Text('over hundred'),
              ),
            ],
            orElse: (_, p) => Text('default: ${p.count.value}'),
          ),
        ),
      );

      expect(find.text('default: 5'), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when no match and no orElse', (
      tester,
    ) async {
      final pillar = _TestPillar();
      pillar.count.value = 50;
      Titan.put(pillar);

      await tester.pumpWidget(
        MaterialApp(
          home: VestigeWhen<_TestPillar>(
            cases: [
              WhenCase(
                condition: (p) => p.count.value < 0,
                builder: (_, p) => Text('negative'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('negative'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('rebuilds when condition deps change', (tester) async {
      final pillar = _TestPillar();
      Titan.put(pillar);

      await tester.pumpWidget(
        MaterialApp(
          home: VestigeWhen<_TestPillar>(
            cases: [
              WhenCase(
                condition: (p) => p.count.value < 0,
                builder: (_, p) => Text('negative'),
              ),
              WhenCase(
                condition: (p) => p.count.value == 0,
                builder: (_, p) => Text('zero'),
              ),
              WhenCase(
                condition: (p) => p.count.value > 0,
                builder: (_, p) => Text('positive'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('zero'), findsOneWidget);

      pillar.count.value = 5;
      await tester.pump();
      expect(find.text('positive'), findsOneWidget);

      pillar.count.value = -3;
      await tester.pump();
      expect(find.text('negative'), findsOneWidget);
    });

    testWidgets('works with Beacon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [_TestPillar.new],
            child: VestigeWhen<_TestPillar>(
              cases: [
                WhenCase(
                  condition: (p) => p.count.value == 0,
                  builder: (_, p) => Text('zero'),
                ),
              ],
              orElse: (_, p) => Text('other'),
            ),
          ),
        ),
      );

      expect(find.text('zero'), findsOneWidget);
    });

    testWidgets('first matching case wins over later matches', (tester) async {
      final pillar = _TestPillar();
      pillar.count.value = 5;
      Titan.put(pillar);

      await tester.pumpWidget(
        MaterialApp(
          home: VestigeWhen<_TestPillar>(
            cases: [
              WhenCase(
                condition: (p) => p.count.value > 0,
                builder: (_, p) => Text('first match'),
              ),
              WhenCase(
                condition: (p) => p.count.value > 0,
                builder: (_, p) => Text('second match'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('first match'), findsOneWidget);
      expect(find.text('second match'), findsNothing);
    });

    testWidgets('reads multiple Cores from conditions', (tester) async {
      final pillar = _TestPillar();
      Titan.put(pillar);

      await tester.pumpWidget(
        MaterialApp(
          home: VestigeWhen<_TestPillar>(
            cases: [
              WhenCase(
                condition: (p) =>
                    p.count.value > 10 && p.label.value == 'special',
                builder: (_, p) => Text('special high'),
              ),
            ],
            orElse: (_, p) => Text('normal'),
          ),
        ),
      );

      expect(find.text('normal'), findsOneWidget);

      pillar.count.value = 20;
      pillar.label.value = 'special';
      await tester.pump();
      expect(find.text('special high'), findsOneWidget);
    });
  });
}
