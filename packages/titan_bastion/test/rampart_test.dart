import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:titan_bastion/titan_bastion.dart';

void main() {
  group('Rampart', () {
    group('layoutFor', () {
      test('returns compact for narrow widths', () {
        expect(Rampart.layoutFor(0), RampartLayout.compact);
        expect(Rampart.layoutFor(320), RampartLayout.compact);
        expect(Rampart.layoutFor(599), RampartLayout.compact);
      });

      test('returns medium for tablet widths', () {
        expect(Rampart.layoutFor(600), RampartLayout.medium);
        expect(Rampart.layoutFor(700), RampartLayout.medium);
        expect(Rampart.layoutFor(839), RampartLayout.medium);
      });

      test('returns expanded for desktop widths', () {
        expect(Rampart.layoutFor(840), RampartLayout.expanded);
        expect(Rampart.layoutFor(1200), RampartLayout.expanded);
        expect(Rampart.layoutFor(1920), RampartLayout.expanded);
      });

      test('respects custom breakpoints', () {
        const bp = RampartBreakpoints(compact: 0, medium: 768, expanded: 1280);
        expect(Rampart.layoutFor(600, bp), RampartLayout.compact);
        expect(Rampart.layoutFor(768, bp), RampartLayout.medium);
        expect(Rampart.layoutFor(1280, bp), RampartLayout.expanded);
      });
    });

    group('RampartBreakpoints', () {
      test('material3 has correct default values', () {
        const bp = RampartBreakpoints.material3;
        expect(bp.compact, 0);
        expect(bp.medium, 600);
        expect(bp.expanded, 840);
      });
    });

    group('RampartValue', () {
      test('resolve returns correct value for each tier', () {
        const value = RampartValue<double>(
          compact: 8,
          medium: 16,
          expanded: 24,
        );

        expect(value.resolve(RampartLayout.compact), 8);
        expect(value.resolve(RampartLayout.medium), 16);
        expect(value.resolve(RampartLayout.expanded), 24);
      });

      test('resolve falls back to compact when medium is null', () {
        const value = RampartValue<double>(compact: 8);
        expect(value.resolve(RampartLayout.medium), 8);
      });

      test(
        'resolve falls back to medium then compact when expanded is null',
        () {
          const value = RampartValue<double>(compact: 8, medium: 16);
          expect(value.resolve(RampartLayout.expanded), 16);

          const value2 = RampartValue<double>(compact: 8);
          expect(value2.resolve(RampartLayout.expanded), 8);
        },
      );

      test('all constructor sets same value for all tiers', () {
        const value = RampartValue<int>.all(42);
        expect(value.resolve(RampartLayout.compact), 42);
        expect(value.resolve(RampartLayout.medium), 42);
        expect(value.resolve(RampartLayout.expanded), 42);
      });
    });

    group('Rampart widget', () {
      testWidgets('shows compact layout for phone width', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTeardownToTearDown(tester);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(360, 640)),
            child: Rampart(
              compact: (_) =>
                  const Text('compact', textDirection: TextDirection.ltr),
              medium: (_) =>
                  const Text('medium', textDirection: TextDirection.ltr),
              expanded: (_) =>
                  const Text('expanded', textDirection: TextDirection.ltr),
            ),
          ),
        );

        expect(find.text('compact'), findsOneWidget);
        expect(find.text('medium'), findsNothing);
        expect(find.text('expanded'), findsNothing);
      });

      testWidgets('shows medium layout for tablet width', (tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTeardownToTearDown(tester);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(768, 1024)),
            child: Rampart(
              compact: (_) =>
                  const Text('compact', textDirection: TextDirection.ltr),
              medium: (_) =>
                  const Text('medium', textDirection: TextDirection.ltr),
              expanded: (_) =>
                  const Text('expanded', textDirection: TextDirection.ltr),
            ),
          ),
        );

        expect(find.text('compact'), findsNothing);
        expect(find.text('medium'), findsOneWidget);
        expect(find.text('expanded'), findsNothing);
      });

      testWidgets('shows expanded layout for desktop width', (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTeardownToTearDown(tester);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Rampart(
              compact: (_) =>
                  const Text('compact', textDirection: TextDirection.ltr),
              medium: (_) =>
                  const Text('medium', textDirection: TextDirection.ltr),
              expanded: (_) =>
                  const Text('expanded', textDirection: TextDirection.ltr),
            ),
          ),
        );

        expect(find.text('compact'), findsNothing);
        expect(find.text('medium'), findsNothing);
        expect(find.text('expanded'), findsOneWidget);
      });

      testWidgets('falls back to compact when medium is null', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(768, 1024)),
            child: Rampart(
              compact: (_) =>
                  const Text('compact', textDirection: TextDirection.ltr),
              expanded: (_) =>
                  const Text('expanded', textDirection: TextDirection.ltr),
            ),
          ),
        );

        expect(find.text('compact'), findsOneWidget);
      });

      testWidgets('falls back to medium when expanded is null', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Rampart(
              compact: (_) =>
                  const Text('compact', textDirection: TextDirection.ltr),
              medium: (_) =>
                  const Text('medium', textDirection: TextDirection.ltr),
            ),
          ),
        );

        expect(find.text('medium'), findsOneWidget);
      });
    });

    group('RampartVisibility', () {
      testWidgets('shows child when layout matches', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: RampartVisibility(
                visibleOn: const {RampartLayout.expanded},
                child: const Text('side panel'),
              ),
            ),
          ),
        );

        expect(find.text('side panel'), findsOneWidget);
      });

      testWidgets('hides child when layout does not match', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(360, 640)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: RampartVisibility(
                visibleOn: const {RampartLayout.expanded},
                child: const Text('side panel'),
              ),
            ),
          ),
        );

        expect(find.text('side panel'), findsNothing);
      });

      testWidgets('shows replacement when hidden', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(360, 640)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: RampartVisibility(
                visibleOn: const {RampartLayout.expanded},
                replacement: const Text('hidden'),
                child: const Text('side panel'),
              ),
            ),
          ),
        );

        expect(find.text('side panel'), findsNothing);
        expect(find.text('hidden'), findsOneWidget);
      });

      testWidgets('multiple layout tiers', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(768, 1024)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: RampartVisibility(
                visibleOn: const {RampartLayout.medium, RampartLayout.expanded},
                child: const Text('nav rail'),
              ),
            ),
          ),
        );

        expect(find.text('nav rail'), findsOneWidget);
      });
    });
  });
}

void addTeardownToTearDown(WidgetTester tester) {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
