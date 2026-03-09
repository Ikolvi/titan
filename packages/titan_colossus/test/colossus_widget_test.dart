import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // Helper to clean up Colossus and global state within the test body.
  // Must be called BEFORE the test returns to avoid pending timer errors.
  Future<void> cleanup(WidgetTester tester) async {
    // Unregister plugins before shutdown
    for (final p in List.of(Lens.plugins)) {
      Lens.unregisterPlugin(p);
    }
    Colossus.shutdown();
    Titan.reset();
    Herald.reset();
    Vigil.reset();
    Chronicle.reset();
    // Rebuild with plain widget to dispose timer-holding state
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  // ---------------------------------------------------------
  // ColossusLensTab — Perf tab widget tests
  // ---------------------------------------------------------

  group('ColossusLensTab — Perf Recording Bar', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    testWidgets('shows Record Perf button in Perf tab', (tester) async {
      Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      // Open Lens
      Lens.show();
      await tester.pump();

      // Navigate to Perf tab
      await tester.tap(find.text('Perf'));
      await tester.pump();

      // Should see "Record Perf" button
      expect(find.text('Record Perf'), findsOneWidget);

      await cleanup(tester);
    });

    testWidgets('Record Perf toggles to Stop & Report', (tester) async {
      Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();

      await tester.tap(find.text('Perf'));
      await tester.pump();

      // Tap Record Perf
      await tester.tap(find.text('Record Perf'));
      await tester.pump();

      // Should now show Stop & Report and Recording indicator
      expect(find.text('Stop & Report'), findsOneWidget);
      expect(find.text('Recording...'), findsOneWidget);

      await cleanup(tester);
    });

    testWidgets('Stop & Report returns to Record Perf', (tester) async {
      Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();

      await tester.tap(find.text('Perf'));
      await tester.pump();

      // Start recording
      await tester.tap(find.text('Record Perf'));
      await tester.pump();

      // Stop recording
      await tester.tap(find.text('Stop & Report'));
      await tester.pump();

      // Should return to Record Perf and show status
      expect(find.text('Record Perf'), findsOneWidget);
      expect(find.textContaining('Recorded'), findsOneWidget);

      await cleanup(tester);
    });
  });

  // ---------------------------------------------------------
  // ShadeLensTab — Shade tab widget tests
  // ---------------------------------------------------------

  group('ShadeLensTab — Recording & Controls', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    testWidgets('shows Record button in Shade tab', (tester) async {
      Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();

      // Navigate to Shade tab
      await tester.tap(find.text('Shade'));
      await tester.pump();

      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Ready to record'), findsOneWidget);

      await cleanup(tester);
    });

    testWidgets('Record button hides Lens overlay', (tester) async {
      Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();
      expect(Lens.isVisible, true);

      // Navigate to Shade tab
      await tester.tap(find.text('Shade'));
      await tester.pump();

      // Tap Record
      await tester.tap(find.text('Record'));
      await tester.pump();

      // Lens should be hidden
      expect(Lens.isVisible, false);

      await cleanup(tester);
    });

    testWidgets('shows speed control with default 1.0x', (tester) async {
      Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();

      await tester.tap(find.text('Shade'));
      await tester.pump();

      expect(find.text('Speed:'), findsOneWidget);
      expect(find.text('0.5x'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);
      expect(find.text('5.0x'), findsOneWidget);

      await cleanup(tester);
    });

    testWidgets('shows intelligent wait toggle', (tester) async {
      Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();

      await tester.tap(find.text('Shade'));
      await tester.pump();

      expect(find.text('Wait for API / dialog'), findsOneWidget);
      expect(find.byIcon(Icons.psychology), findsOneWidget);

      await cleanup(tester);
    });
  });

  // ---------------------------------------------------------
  // ShadeLensTab — Route mismatch warning
  // ---------------------------------------------------------

  group('ShadeLensTab — Route mismatch warning', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    testWidgets('renders Shade tab with route info', (tester) async {
      final colossus = Colossus.init(enableLensTab: true);
      colossus.shade.getCurrentRoute = () => '/settings';

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      // Record a session (route will be captured as '/settings')
      colossus.shade.startRecording(
        name: 'test',
        screenSize: const Size(375, 812),
      );
      colossus.shade.stopRecording();

      Lens.show();
      await tester.pump();

      await tester.tap(find.text('Shade'));
      await tester.pump();

      // The tab renders without error
      expect(find.text('Shade'), findsOneWidget);

      await cleanup(tester);
    });
  });

  // ---------------------------------------------------------
  // ShadeLensTab — Session survives Lens hide/show cycle
  // ---------------------------------------------------------

  group('ShadeLensTab — Session persistence across Lens cycles', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    testWidgets('recorded session shows up after Lens hide/show cycle', (
      tester,
    ) async {
      final colossus = Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();

      // Navigate to Shade tab
      await tester.tap(find.text('Shade'));
      await tester.pump();

      // Tap Record — hides Lens, starts recording
      await tester.tap(find.text('Record'));
      await tester.pump();
      expect(Lens.isVisible, false);
      expect(colossus.shade.isRecording, true);

      // Programmatically stop recording (simulates reopening Lens
      // and tapping Stop). The FAB is hidden during recording —
      // only the ShadeListener status pill is shown.
      Lens.onStopRecording?.call();
      await tester.pump();

      expect(colossus.shade.isRecording, false);
      // The session should be stored on Colossus
      expect(colossus.lastRecordedSession, isNotNull);

      // Lens should auto-show after stop (via post-frame callback)
      await tester.pump();
      expect(Lens.isVisible, true);

      await tester.tap(find.text('Shade'));
      await tester.pump();

      // The "Last Session" card should now appear
      expect(find.text('Last Session'), findsOneWidget);

      await cleanup(tester);
    });

    testWidgets('stopRecording via Stop button stores session on Colossus', (
      tester,
    ) async {
      final colossus = Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();

      await tester.tap(find.text('Shade'));
      await tester.pump();

      // Start recording (hides Lens)
      await tester.tap(find.text('Record'));
      await tester.pump();
      expect(colossus.shade.isRecording, true);

      // Re-open Lens while recording
      Lens.show();
      await tester.pump();

      await tester.tap(find.text('Shade'));
      await tester.pump();

      // Should show Stop button since Shade is still recording
      expect(find.text('Stop'), findsOneWidget);

      // Tap Stop
      await tester.tap(find.text('Stop'));
      await tester.pump();

      // Session should be on Colossus
      expect(colossus.lastRecordedSession, isNotNull);
      expect(colossus.lastRecordedSession!.name, contains('shade_'));

      // Last Session card should appear
      expect(find.text('Last Session'), findsOneWidget);

      await cleanup(tester);
    });
  });

  // ---------------------------------------------------------
  // ColossusLensTab — sub-tabs
  // ---------------------------------------------------------

  group('ColossusLensTab — sub-tabs', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    testWidgets('Perf tab shows all sub-tabs', (tester) async {
      Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();

      await tester.tap(find.text('Perf'));
      await tester.pump();

      expect(find.text('Pulse'), findsWidgets);
      expect(find.text('Stride'), findsWidgets);
      expect(find.text('Vessel'), findsWidgets);
      expect(find.text('Echo'), findsWidgets);
      expect(find.text('Export'), findsWidgets);

      await cleanup(tester);
    });

    testWidgets('Pulse sub-tab shows FPS metrics', (tester) async {
      Colossus.init(enableLensTab: true);

      await tester.pumpWidget(
        const MaterialApp(home: Lens(child: Text('app'))),
      );

      Lens.show();
      await tester.pump();

      await tester.tap(find.text('Perf'));
      await tester.pump();

      // Pulse is the default sub-tab
      expect(find.text('FPS'), findsOneWidget);
      expect(find.text('Jank rate'), findsOneWidget);
      expect(find.text('Total frames'), findsOneWidget);

      await cleanup(tester);
    });
  });
}
