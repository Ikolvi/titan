import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

import 'package:titan_example/pillars/questboard_pillar.dart';
import 'package:titan_example/screens/hero_profile_screen.dart';

// ---------------------------------------------------------------------------
// Hero Profile — Rename Dialog Tests
//
// Verifies the Spark-based _RenameDialog widget:
//   1. Dialog opens with current hero name pre-filled
//   2. Typing a new name and tapping Rename updates the Pillar
//   3. Cancel closes dialog without changes
//   4. useTextController factory is invoked when set (Colossus integration)
//   5. Controller is auto-disposed when dialog closes
// ---------------------------------------------------------------------------

void main() {
  tearDown(() {
    Herald.reset();
    Vigil.reset();
    Titan.reset();
    Spark.textControllerFactory = null;
  });

  Widget buildApp() {
    return MaterialApp(
      home: Beacon(
        pillars: [QuestboardPillar.new],
        child: const HeroProfileScreen(),
      ),
    );
  }

  Future<void> openRenameDialog(WidgetTester tester) async {
    // Tap the edit (rename) icon button
    final editButton = find.byIcon(Icons.edit);
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
  }

  group('Rename dialog', () {
    testWidgets('opens with current hero name pre-filled', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Default hero name is 'Kael'
      await openRenameDialog(tester);

      // Dialog should be open
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Rename Hero'), findsOneWidget);

      // TextField should contain initial hero name
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Kael');
    });

    testWidgets('renames hero when Rename is tapped', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await openRenameDialog(tester);

      // Clear and type a new name
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Atlas');
      await tester.pumpAndSettle();

      // Tap the Rename button
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Dialog should close
      expect(find.byType(AlertDialog), findsNothing);

      // Hero name should be updated
      final board = BeaconScope.of<QuestboardPillar>(
        tester.element(find.byType(HeroProfileScreen)),
      );
      expect(board.heroName.value, 'Atlas');
    });

    testWidgets('cancels without changing hero name', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await openRenameDialog(tester);

      // Type a new name
      await tester.enterText(find.byType(TextField), 'NotKael');
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should close
      expect(find.byType(AlertDialog), findsNothing);

      // Hero name should remain unchanged
      final board = BeaconScope.of<QuestboardPillar>(
        tester.element(find.byType(HeroProfileScreen)),
      );
      expect(board.heroName.value, 'Kael');
    });

    testWidgets('supports Epoch undo after rename', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // First rename
      await openRenameDialog(tester);
      await tester.enterText(find.byType(TextField), 'Atlas');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      final board = BeaconScope.of<QuestboardPillar>(
        tester.element(find.byType(HeroProfileScreen)),
      );
      expect(board.heroName.value, 'Atlas');
      expect(board.heroName.canUndo, true);

      // Undo should restore Kael
      board.undoName();
      await tester.pumpAndSettle();
      expect(board.heroName.value, 'Kael');
    });
  });

  group('textControllerFactory integration', () {
    testWidgets('uses factory when Spark.textControllerFactory is set', (
      tester,
    ) async {
      int factoryCallCount = 0;
      String? factoryText;

      Spark.textControllerFactory = ({String? text, String? fieldId}) {
        factoryCallCount++;
        factoryText = text;
        return TextEditingController(text: text);
      };

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await openRenameDialog(tester);

      // Factory should have been called once with the hero name
      expect(factoryCallCount, 1);
      expect(factoryText, 'Kael');

      // Dialog should still work normally
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Kael');
    });

    testWidgets('factory-created controller works for rename', (tester) async {
      final controllers = <TextEditingController>[];

      Spark.textControllerFactory = ({String? text, String? fieldId}) {
        final ctrl = TextEditingController(text: text);
        controllers.add(ctrl);
        return ctrl;
      };

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await openRenameDialog(tester);
      expect(controllers.length, 1);

      // Type and rename
      await tester.enterText(find.byType(TextField), 'Zephyr');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Pillar should be updated
      final board = BeaconScope.of<QuestboardPillar>(
        tester.element(find.byType(HeroProfileScreen)),
      );
      expect(board.heroName.value, 'Zephyr');
    });

    testWidgets('falls back to plain TextEditingController without factory', (
      tester,
    ) async {
      // Ensure no factory
      Spark.textControllerFactory = null;

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await openRenameDialog(tester);

      // Should still work
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller, isA<TextEditingController>());
      expect(textField.controller?.text, 'Kael');
    });
  });

  group('controller lifecycle', () {
    testWidgets('controller is disposed when dialog closes', (tester) async {
      final controllers = <TextEditingController>[];

      Spark.textControllerFactory = ({String? text, String? fieldId}) {
        final ctrl = TextEditingController(text: text);
        controllers.add(ctrl);
        return ctrl;
      };

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      // Open dialog — creates controller
      await openRenameDialog(tester);
      expect(controllers.length, 1);
      final captured = controllers.first;

      // Close dialog via Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Re-open dialog — should create a new controller (old one disposed)
      await openRenameDialog(tester);
      expect(controllers.length, 2);

      // The second controller should be a different instance
      expect(identical(controllers[0], controllers[1]), isFalse);

      // Verify the first controller was disposed by checking listeners throw
      expect(() => captured.addListener(() {}), throwsFlutterError);
    });
  });
}
