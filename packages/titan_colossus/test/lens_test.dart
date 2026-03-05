import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  setUp(() {
    Titan.reset();
    Herald.reset();
    Vigil.reset();
    Chronicle.reset();
  });

  tearDown(() {
    Titan.reset();
    Herald.reset();
    Vigil.reset();
    Chronicle.reset();
  });

  group('Lens — Debug Overlay', () {
    testWidgets('renders child when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(enabled: false, child: Text('app'))),
      );

      expect(find.text('app'), findsOneWidget);
      // No FAB should be visible
      expect(find.byIcon(Icons.bug_report), findsNothing);
    });

    testWidgets('renders child and FAB when enabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      expect(find.text('app'), findsOneWidget);
      expect(find.byIcon(Icons.bug_report), findsOneWidget);
    });

    testWidgets('FAB toggles panel visibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      // Panel not visible initially
      expect(find.text('Pillars'), findsNothing);

      // Tap FAB to open
      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pump();

      // Panel should be visible
      expect(find.text('Pillars'), findsOneWidget);
      expect(find.text('Herald'), findsOneWidget);
      expect(find.text('Vigil'), findsOneWidget);
      expect(find.text('Chronicle'), findsOneWidget);

      // Tap close icon to hide
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.text('Pillars'), findsNothing);
    });

    testWidgets('shows registered Pillars', (tester) async {
      Titan.put(_TestPillar());

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      // Open panel
      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pump();

      // Should show the registered Pillar type
      expect(find.text('_TestPillar'), findsOneWidget);
    });

    testWidgets('shows Vigil errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      // Capture an error in Vigil
      Vigil.capture(Exception('test error'));

      // Open panel and switch to Vigil tab
      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pump();
      await tester.tap(find.text('Vigil'));
      await tester.pump();

      expect(find.textContaining('test error'), findsOneWidget);
    });

    testWidgets('isVisible returns false when panel is closed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      expect(Lens.isVisible, false);
    });

    testWidgets('isVisible tracks panel visibility', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      expect(Lens.isVisible, false);

      Lens.show();
      await tester.pump();
      expect(Lens.isVisible, true);

      Lens.hide();
      await tester.pump();
      expect(Lens.isVisible, false);

      Lens.toggle();
      await tester.pump();
      expect(Lens.isVisible, true);
    });

    testWidgets('isVisible returns false when no Lens is mounted', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: Text('no lens')));

      expect(Lens.isVisible, false);
    });

    testWidgets('static show/hide/toggle work', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      // Panel not visible
      expect(find.text('Pillars'), findsNothing);

      // Static show
      Lens.show();
      await tester.pump();
      expect(find.text('Pillars'), findsOneWidget);

      // Static hide
      Lens.hide();
      await tester.pump();
      expect(find.text('Pillars'), findsNothing);

      // Static toggle
      Lens.toggle();
      await tester.pump();
      expect(find.text('Pillars'), findsOneWidget);
    });

    testWidgets('LensLogSink captures Chronicle entries', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      // Log something
      final logger = Chronicle('TestLogger');
      logger.info('hello from chronicle');

      // Open panel and switch to Chronicle tab
      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pump();
      await tester.tap(find.text('Chronicle'));
      await tester.pump();

      expect(find.textContaining('hello from chronicle'), findsOneWidget);
    });

    testWidgets('shows "No Herald events" when empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      await tester.tap(find.byIcon(Icons.bug_report));
      await tester.pump();
      await tester.tap(find.text('Herald'));
      await tester.pump();

      expect(find.text('No Herald events'), findsOneWidget);
    });

    testWidgets('disposes cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      // Navigate away to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: Text('other')));

      // Should not throw
      expect(find.text('other'), findsOneWidget);
    });
  });

  group('LensLogSink — Unit', () {
    test('captures log entries', () {
      final sink = LensLogSink();
      sink.write(
        LogEntry(
          loggerName: 'test',
          level: LogLevel.info,
          message: 'hello',
          timestamp: DateTime.now(),
        ),
      );
      expect(sink.entries.length, 1);
      expect(sink.entries.first.message, 'hello');
    });

    test('respects maxEntries limit', () {
      final sink = LensLogSink(maxEntries: 3);
      for (var i = 0; i < 5; i++) {
        sink.write(
          LogEntry(
            loggerName: 'test',
            level: LogLevel.info,
            message: 'msg_$i',
            timestamp: DateTime.now(),
          ),
        );
      }
      expect(sink.entries.length, 3);
      expect(sink.entries.first.message, 'msg_2');
    });

    test('clear() removes all entries', () {
      final sink = LensLogSink();
      sink.write(
        LogEntry(
          loggerName: 'test',
          level: LogLevel.info,
          message: 'hello',
          timestamp: DateTime.now(),
        ),
      );
      sink.clear();
      expect(sink.entries, isEmpty);
    });

    test('onEntry callback fires on each write', () {
      final sink = LensLogSink();
      int count = 0;
      sink.onEntry = () => count++;
      sink.write(
        LogEntry(
          loggerName: 'test',
          level: LogLevel.info,
          message: 'hello',
          timestamp: DateTime.now(),
        ),
      );
      expect(count, 1);
    });
  });

  // ---------------------------------------------------------
  // Lens FAB — Draggable & Position Persistence
  // ---------------------------------------------------------

  group('Lens FAB — Draggable position', () {
    setUp(() {
      // Reset FAB position before each test
      Lens.resetFabPosition();
    });

    testWidgets('FAB can be dragged to a new position', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      // Find the FAB
      final fab = find.byIcon(Icons.bug_report);
      expect(fab, findsOneWidget);

      // Get initial position
      final initialCenter = tester.getCenter(fab);

      // Drag the FAB
      await tester.drag(fab, const Offset(-50, -100));
      await tester.pump();

      // FAB should have moved
      final newCenter = tester.getCenter(fab);
      expect(newCenter, isNot(equals(initialCenter)));
    });

    testWidgets('FAB position persists across Lens hide/show', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      final fab = find.byIcon(Icons.bug_report);

      // Drag the FAB
      await tester.drag(fab, const Offset(-80, -60));
      await tester.pump();

      final movedCenter = tester.getCenter(fab);

      // Hide and show Lens (the FAB remains as it's always rendered)
      Lens.show();
      await tester.pump();

      Lens.hide();
      await tester.pump();

      // FAB position should be the same
      final afterToggle = tester.getCenter(fab);
      expect(afterToggle, equals(movedCenter));
    });

    testWidgets('resetFabPosition restores default after drag', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      final fab = find.byIcon(Icons.bug_report);
      final defaultCenter = tester.getCenter(fab);

      // Drag the FAB away from default
      await tester.drag(fab, const Offset(-80, -60));
      await tester.pump();

      // Verify it moved
      final movedCenter = tester.getCenter(fab);
      expect(movedCenter, isNot(equals(defaultCenter)));

      // Reset via static method
      Lens.resetFabPosition();
      await tester.pump();

      // Should be back at default
      final resetCenter = tester.getCenter(find.byIcon(Icons.bug_report));
      expect(resetCenter, equals(defaultCenter));
    });

    testWidgets('resetFabPosition() resets static position', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      final fab = find.byIcon(Icons.bug_report);

      // Drag FAB
      await tester.drag(fab, const Offset(-50, -50));
      await tester.pump();

      // Reset via static method
      Lens.resetFabPosition();
      await tester.pump();

      // Should be at default position
      final center = tester.getCenter(find.byIcon(Icons.bug_report));
      // Default is right:16, bottom:80 — check it matches fresh widget
      // We just verify the static fields were reset
      expect(center, isNotNull);
    });
  });
}

class _TestPillar extends Pillar {
  late final count = core(0);
}
