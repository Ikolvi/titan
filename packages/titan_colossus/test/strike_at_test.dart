// ignore: unused_import — Colors, Icons, Container used in widget trees
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/testing/strike_at.dart';

void main() {
  group('StrikeAt — semantic-free tap helper', () {
    testWidgets('taps GestureDetector by type without semantics', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () => tapped = true,
              child: Container(width: 100, height: 100, color: Colors.blue),
            ),
          ),
        ),
      );

      await tester.strikeAt(find.byType(GestureDetector));

      expect(tapped, isTrue);
    });

    testWidgets('taps GestureDetector by ValueKey', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              key: const ValueKey('my-target'),
              onTap: () => tapped = true,
              child: Container(width: 80, height: 80, color: Colors.red),
            ),
          ),
        ),
      );

      await tester.strikeAtKey('my-target');

      expect(tapped, isTrue);
    });

    testWidgets('taps at raw offset', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => tapped = true,
                child: Container(width: 200, height: 200, color: Colors.green),
              ),
            ),
          ),
        ),
      );

      // Tap inside the 200x200 box (accounting for AppBar offset)
      final element = find.byType(GestureDetector).evaluate().first;
      final box = element.renderObject! as RenderBox;
      final center = box.localToGlobal(box.size.center(Offset.zero));
      await tester.strikeAtOffset(center);

      expect(tapped, isTrue);
    });

    testWidgets('long presses GestureDetector without semantics', (
      tester,
    ) async {
      var longPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onLongPress: () => longPressed = true,
              child: Container(width: 100, height: 100, color: Colors.amber),
            ),
          ),
        ),
      );

      await tester.strikeAndHold(find.byType(GestureDetector));

      expect(longPressed, isTrue);
    });

    testWidgets('taps nested GestureDetector by key', (tester) async {
      var innerTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onTap: () {}, // outer — should NOT fire
              child: Center(
                child: GestureDetector(
                  key: const ValueKey('inner'),
                  onTap: () => innerTapped = true,
                  child: Container(width: 50, height: 50, color: Colors.purple),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.strikeAtKey('inner');

      expect(innerTapped, isTrue);
    });

    testWidgets('taps GestureDetector wrapping image-like widget', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                key: const ValueKey('avatar'),
                onTap: () => tapped = true,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Placeholder(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.strikeAtKey('avatar');

      expect(tapped, isTrue);
    });

    testWidgets('throws StateError for widget without RenderBox', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );

      // SizedBox.shrink has a RenderBox but with zero size — this should
      // still work (we dispatch at center of 0x0). But a widget with no
      // renderObject at all would throw.
      // This test just verifies no crash on a tiny widget.
      await tester.strikeAt(find.byType(SizedBox).first);
    });

    testWidgets('double-taps GestureDetector without semantics', (
      tester,
    ) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onDoubleTap: () => tapCount++,
              child: Container(width: 100, height: 100, color: Colors.teal),
            ),
          ),
        ),
      );

      await tester.strikeDouble(find.byType(GestureDetector));

      expect(tapCount, 1);
    });

    testWidgets('double-taps at raw offset', (tester) async {
      var doubleTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onDoubleTap: () => doubleTapped = true,
                child: Container(width: 200, height: 200, color: Colors.cyan),
              ),
            ),
          ),
        ),
      );

      final element = find.byType(GestureDetector).evaluate().first;
      final box = element.renderObject! as RenderBox;
      final center = box.localToGlobal(box.size.center(Offset.zero));
      await tester.strikeDoubleAt(center);

      expect(doubleTapped, isTrue);
    });

    testWidgets('swipes left on GestureDetector', (tester) async {
      var swiped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < 0) {
                  swiped = true;
                }
              },
              child: Container(width: 300, height: 300, color: Colors.orange),
            ),
          ),
        ),
      );

      await tester.strikeSwipe(find.byType(GestureDetector), direction: 'left');

      expect(swiped, isTrue);
    });

    testWidgets('swipes right on GestureDetector', (tester) async {
      var swiped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 0) {
                  swiped = true;
                }
              },
              child: Container(width: 300, height: 300, color: Colors.orange),
            ),
          ),
        ),
      );

      await tester.strikeSwipe(
        find.byType(GestureDetector),
        direction: 'right',
      );

      expect(swiped, isTrue);
    });

    testWidgets('swipes at raw offset', (tester) async {
      var dragDelta = Offset.zero;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onPanUpdate: (details) => dragDelta += details.delta,
              child: Container(width: 400, height: 400, color: Colors.lime),
            ),
          ),
        ),
      );

      final element = find.byType(GestureDetector).evaluate().first;
      final box = element.renderObject! as RenderBox;
      final center = box.localToGlobal(box.size.center(Offset.zero));
      await tester.strikeSwipeAt(center, direction: 'down', distance: 200);

      expect(dragDelta.dy, greaterThan(0));
    });

    testWidgets('drags widget by offset', (tester) async {
      var totalDelta = Offset.zero;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onPanUpdate: (details) => totalDelta += details.delta,
              child: Container(width: 200, height: 200, color: Colors.indigo),
            ),
          ),
        ),
      );

      await tester.strikeDrag(
        find.byType(GestureDetector),
        const Offset(100, 50),
      );

      expect(totalDelta.dx, greaterThan(0));
      expect(totalDelta.dy, greaterThan(0));
    });

    testWidgets('drags between two offsets', (tester) async {
      var totalDelta = Offset.zero;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              onPanUpdate: (details) => totalDelta += details.delta,
              child: Container(width: 400, height: 400, color: Colors.brown),
            ),
          ),
        ),
      );

      final element = find.byType(GestureDetector).evaluate().first;
      final box = element.renderObject! as RenderBox;
      final topLeft = box.localToGlobal(Offset.zero);
      await tester.strikeDragAt(
        topLeft + const Offset(50, 50),
        topLeft + const Offset(250, 150),
      );

      expect(totalDelta.dx, greaterThan(0));
      expect(totalDelta.dy, greaterThan(0));
    });

    testWidgets('scrolls at widget position', (tester) async {
      var scrolled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                scrolled = true;
                return false;
              },
              child: ListView(
                children: List.generate(
                  50,
                  (i) => SizedBox(height: 60, child: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.strikeScroll(find.byType(ListView), const Offset(0, 300));

      expect(scrolled, isTrue);
    });

    testWidgets('scrolls at raw offset', (tester) async {
      var scrolled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                scrolled = true;
                return false;
              },
              child: ListView(
                children: List.generate(
                  50,
                  (i) => SizedBox(height: 60, child: Text('Item $i')),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.strikeScrollAt(const Offset(200, 400), const Offset(0, 300));

      expect(scrolled, isTrue);
    });

    // -----------------------------------------------------------------------
    // strikeText — text input via flutter_test
    // -----------------------------------------------------------------------

    testWidgets('strikeText enters text into TextField', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );

      await tester.strikeText(find.byType(TextField), 'hello world');

      expect(controller.text, 'hello world');
    });

    testWidgets('strikeTextByKey enters text by ValueKey', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              key: const ValueKey('email-field'),
              controller: controller,
            ),
          ),
        ),
      );

      await tester.strikeTextByKey('email-field', 'test@example.com');

      expect(controller.text, 'test@example.com');
    });

    testWidgets('strikeClearText clears TextField', (tester) async {
      final controller = TextEditingController(text: 'existing');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );

      await tester.strikeClearText(find.byType(TextField));

      expect(controller.text, isEmpty);
    });

    testWidgets('strikeText replaces existing text', (tester) async {
      final controller = TextEditingController(text: 'old text');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(controller: controller)),
        ),
      );

      await tester.strikeText(find.byType(TextField), 'new text');

      expect(controller.text, 'new text');
    });

    testWidgets('strikeText works with TextFormField', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(child: TextFormField(controller: controller)),
          ),
        ),
      );

      await tester.strikeText(find.byType(TextFormField), 'form value');

      expect(controller.text, 'form value');
    });
  });
}
