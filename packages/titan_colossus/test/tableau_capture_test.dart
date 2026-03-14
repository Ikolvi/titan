import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  group('TableauCapture — currentValue extraction', () {
    testWidgets('captures TextField text via controller', (tester) async {
      final controller = TextEditingController(text: 'Arcturus');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Hero Name'),
            ),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final textFieldGlyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'TextField',
      );

      expect(textFieldGlyph.currentValue, 'Arcturus');
      expect(textFieldGlyph.label, 'Hero Name');

      controller.dispose();
    });

    testWidgets('captures empty TextField text', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final textFieldGlyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'TextField',
      );

      // Empty string is a valid current value
      expect(textFieldGlyph.currentValue, '');

      controller.dispose();
    });

    testWidgets('captures TextFormField text via controller', (tester) async {
      final controller = TextEditingController(text: 'kael@titan.io');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final formFieldGlyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'TextFormField',
      );

      expect(formFieldGlyph.currentValue, 'kael@titan.io');

      controller.dispose();
    });

    testWidgets('TextField without controller has null currentValue', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextField(decoration: InputDecoration(labelText: 'Notes')),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final textFieldGlyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'TextField',
      );

      // No controller provided → null
      expect(textFieldGlyph.currentValue, isNull);
    });

    testWidgets('captures updated text after controller change', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'initial');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ),
        ),
      );

      // Verify initial value
      var tableau = await TableauCapture.capture(index: 0);
      var glyph = tableau.glyphs.firstWhere((g) => g.widgetType == 'TextField');
      expect(glyph.currentValue, 'initial');

      // Update the controller text
      controller.text = 'updated';
      await tester.pump();

      // Verify updated value
      tableau = await TableauCapture.capture(index: 1);
      glyph = tableau.glyphs.firstWhere((g) => g.widgetType == 'TextField');
      expect(glyph.currentValue, 'updated');

      controller.dispose();
    });

    testWidgets('Checkbox currentValue still works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Checkbox(value: true, onChanged: (_) {})),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final glyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'Checkbox',
      );

      expect(glyph.currentValue, 'true');
    });

    testWidgets('Switch currentValue still works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Switch(value: false, onChanged: (_) {})),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final glyph = tableau.glyphs.firstWhere((g) => g.widgetType == 'Switch');

      expect(glyph.currentValue, 'off');
    });

    testWidgets('currentValue appears in glyph JSON as cv', (tester) async {
      final controller = TextEditingController(text: 'Kael');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Hero'),
            ),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final glyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'TextField',
      );

      final json = glyph.toMap();
      expect(json['cv'], 'Kael');

      controller.dispose();
    });
  });

  group('TableauCapture — ErrorWidget capture', () {
    testWidgets('captures ErrorWidget as content glyph', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorWidget('Build failure: null value')),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final errorGlyphs = tableau.glyphs
          .where((g) => g.widgetType == 'ErrorWidget')
          .toList();

      expect(errorGlyphs, hasLength(1));
      expect(errorGlyphs.first.label, contains('Build failure'));
      expect(errorGlyphs.first.isInteractive, false);
    });

    testWidgets('captures ErrorWidget.withDetails message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorWidget.withDetails(message: 'Widget build failed'),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final errorGlyphs = tableau.glyphs
          .where((g) => g.widgetType == 'ErrorWidget')
          .toList();

      expect(errorGlyphs, hasLength(1));
      expect(errorGlyphs.first.label, 'Widget build failed');
    });
  });

  group('TableauCapture — GestureDetector visibility', () {
    testWidgets('captures GestureDetector with text child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(onTap: () {}, child: const Text('Tap me')),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final glyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'GestureDetector',
      );

      expect(glyph.label, 'Tap me');
      expect(glyph.isInteractive, true);
      expect(glyph.isEnabled, true);
    });

    testWidgets('captures GestureDetector without text child via key', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              key: const ValueKey('avatar-tap'),
              onTap: () {},
              child: Container(width: 48, height: 48, color: Colors.blue),
            ),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final glyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'GestureDetector',
      );

      expect(glyph.label, 'avatar-tap');
      expect(glyph.isInteractive, true);
    });

    testWidgets(
      'captures label-less GestureDetector with positional fallback',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GestureDetector(
                onTap: () {},
                child: Container(width: 100, height: 100, color: Colors.red),
              ),
            ),
          ),
        );

        final tableau = await TableauCapture.capture(index: 0);
        final glyph = tableau.glyphs.firstWhere(
          (g) => g.widgetType == 'GestureDetector',
        );

        expect(glyph.label, isNotNull);
        expect(glyph.label, startsWith('tap@'));
        expect(glyph.isInteractive, true);
      },
    );

    testWidgets('GestureDetector with no callbacks is disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(child: const Text('No handler')),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final glyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'GestureDetector',
      );

      expect(glyph.isEnabled, false);
    });

    testWidgets('InkWell with no onTap is disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InkWell(child: const Text('No handler'))),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final glyph = tableau.glyphs.firstWhere((g) => g.widgetType == 'InkWell');

      expect(glyph.isEnabled, false);
    });

    testWidgets('GestureDetector onLongPress sets longPress interaction type', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onLongPress: () {},
              child: const Text('Hold me'),
            ),
          ),
        ),
      );

      final tableau = await TableauCapture.capture(index: 0);
      final glyph = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'GestureDetector',
      );

      expect(glyph.interactionType, 'longPress');
      expect(glyph.isEnabled, true);
    });
  });
}
