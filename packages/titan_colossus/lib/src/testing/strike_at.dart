import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// StrikeAt — Semantic-free tap helper for widget tests
// ---------------------------------------------------------------------------

/// Extension on [WidgetTester] for tapping widgets **without semantics**.
///
/// Uses the same approach as Titan's [StratagemRunner]: finds the widget
/// via the Element tree, reads its [RenderBox] position, and dispatches
/// synthetic [PointerDownEvent] + [PointerUpEvent] through
/// [GestureBinding.handlePointerEvent].
///
/// ## Usage
///
/// ```dart
/// // Tap by Finder (any finder — no semantics needed)
/// await tester.strikeAt(find.byType(GestureDetector));
///
/// // Tap by Key
/// await tester.strikeAtKey('avatar-tap');
///
/// // Long press by Finder
/// await tester.strikeAndHold(find.byType(GestureDetector));
///
/// // Tap at raw coordinates
/// await tester.strikeAtOffset(const Offset(120, 340));
/// ```
extension StrikeAt on WidgetTester {
  static int _pointerCounter = 9000;

  /// Tap the first widget matched by [finder] via synthetic pointer events.
  ///
  /// Bypasses the semantics tree entirely — resolves position from
  /// the widget's [RenderBox].
  Future<void> strikeAt(Finder finder) async {
    final center = _centerOf(finder);
    await _dispatchTap(center);
    await pump();
  }

  /// Tap the widget with the given [ValueKey] via synthetic pointer events.
  Future<void> strikeAtKey(String key) async {
    await strikeAt(find.byKey(ValueKey(key)));
  }

  /// Tap at a raw screen [position] via synthetic pointer events.
  Future<void> strikeAtOffset(Offset position) async {
    await _dispatchTap(position);
    await pump();
  }

  /// Long press the first widget matched by [finder] (~550ms hold).
  Future<void> strikeAndHold(Finder finder) async {
    final center = _centerOf(finder);
    await _dispatchLongPress(center);
    await pump();
  }

  /// Long press at a raw screen [position] (~550ms hold).
  Future<void> strikeAndHoldAt(Offset position) async {
    await _dispatchLongPress(position);
    await pump();
  }

  /// Double-tap the first widget matched by [finder].
  Future<void> strikeDouble(Finder finder) async {
    final center = _centerOf(finder);
    await _dispatchDoubleTap(center);
    await pumpAndSettle();
  }

  /// Double-tap at a raw screen [position].
  Future<void> strikeDoubleAt(Offset position) async {
    await _dispatchDoubleTap(position);
    await pumpAndSettle();
  }

  /// Swipe from the first widget matched by [finder] in [direction].
  ///
  /// [direction] is one of `'left'`, `'right'`, `'up'`, `'down'`.
  /// [distance] controls how far the swipe travels (default: 300).
  Future<void> strikeSwipe(
    Finder finder, {
    String direction = 'left',
    double distance = 300,
  }) async {
    final center = _centerOf(finder);
    await _dispatchSwipe(center, direction, distance);
    await pump();
  }

  /// Swipe from a raw screen [position] in [direction].
  Future<void> strikeSwipeAt(
    Offset position, {
    String direction = 'left',
    double distance = 300,
  }) async {
    await _dispatchSwipe(position, direction, distance);
    await pump();
  }

  /// Drag from the center of [finder] by [offset].
  Future<void> strikeDrag(Finder finder, Offset offset) async {
    final center = _centerOf(finder);
    await _dispatchDrag(center, center + offset);
    await pump();
  }

  /// Drag from [from] to [to] via synthetic pointer events.
  Future<void> strikeDragAt(Offset from, Offset to) async {
    await _dispatchDrag(from, to);
    await pump();
  }

  /// Scroll at the first widget matched by [finder].
  ///
  /// [delta] controls scroll direction and distance. Positive `dy` scrolls
  /// content up (reveals below), negative `dy` scrolls content down.
  Future<void> strikeScroll(Finder finder, Offset delta) async {
    final center = _centerOf(finder);
    _dispatchScroll(center, delta);
    await pump();
  }

  /// Scroll at a raw screen [position].
  Future<void> strikeScrollAt(Offset position, Offset delta) async {
    _dispatchScroll(position, delta);
    await pump();
  }

  /// Enter text into the first [EditableText] matched by [finder].
  ///
  /// Delegates to [WidgetTester.enterText] which goes through Flutter's
  /// `TestTextInput` channel — more reliable than manual controller
  /// manipulation in widget tests.
  ///
  /// ```dart
  /// await tester.strikeText(find.byType(TextField), 'hello');
  /// ```
  Future<void> strikeText(Finder finder, String text) async {
    await tap(finder);
    await pump();
    await enterText(finder, text);
    await pump();
  }

  /// Enter text into the widget with the given [ValueKey].
  Future<void> strikeTextByKey(String key, String text) async {
    await strikeText(find.byKey(ValueKey(key)), text);
  }

  /// Clear text from the first [EditableText] matched by [finder].
  Future<void> strikeClearText(Finder finder) async {
    await strikeText(finder, '');
  }

  // -----------------------------------------------------------------------
  // Internals
  // -----------------------------------------------------------------------

  Offset _centerOf(Finder finder) {
    final element = finder.evaluate().first;
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox) {
      throw StateError(
        'StrikeAt: ${element.widget.runtimeType} has no RenderBox. '
        'Cannot resolve tap position.',
      );
    }
    if (!renderObject.hasSize) {
      throw StateError(
        'StrikeAt: ${element.widget.runtimeType} has no size. '
        'Ensure the widget is laid out before tapping.',
      );
    }
    return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
  }

  Future<void> _dispatchTap(Offset position) async {
    final pointer = _pointerCounter++;
    final binding = GestureBinding.instance;

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        device: pointer,
        buttons: kPrimaryButton,
      ),
    );

    await pump(const Duration(milliseconds: 16));

    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        device: pointer,
      ),
    );
  }

  Future<void> _dispatchLongPress(Offset position) async {
    final pointer = _pointerCounter++;
    final binding = GestureBinding.instance;

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        device: pointer,
        buttons: kPrimaryButton,
      ),
    );

    await pump(const Duration(milliseconds: 550));

    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        device: pointer,
      ),
    );
  }

  Future<void> _dispatchDoubleTap(Offset position) async {
    await _dispatchTap(position);
    await pump(const Duration(milliseconds: 50));
    await _dispatchTap(position);
  }

  Future<void> _dispatchSwipe(
    Offset start,
    String direction,
    double distance,
  ) async {
    final pointer = _pointerCounter++;
    final binding = GestureBinding.instance;
    var elapsed = Duration.zero;

    final end = switch (direction) {
      'left' => Offset(start.dx - distance, start.dy),
      'right' => Offset(start.dx + distance, start.dy),
      'up' => Offset(start.dx, start.dy - distance),
      'down' => Offset(start.dx, start.dy + distance),
      _ => Offset(start.dx - distance, start.dy),
    };

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: start,
        timeStamp: elapsed,
        kind: PointerDeviceKind.touch,
        device: pointer,
        buttons: kPrimaryButton,
      ),
    );

    const steps = 10;
    const stepDuration = Duration(milliseconds: 8);
    for (var i = 1; i <= steps; i++) {
      elapsed += stepDuration;
      final t = i / steps;
      final pos = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: pos,
          timeStamp: elapsed,
          delta: Offset(
            (end.dx - start.dx) / steps,
            (end.dy - start.dy) / steps,
          ),
          kind: PointerDeviceKind.touch,
          device: pointer,
          buttons: kPrimaryButton,
        ),
      );
      await pump(stepDuration);
    }

    elapsed += const Duration(milliseconds: 2);
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: end,
        timeStamp: elapsed,
        kind: PointerDeviceKind.touch,
        device: pointer,
      ),
    );
  }

  Future<void> _dispatchDrag(Offset from, Offset to) async {
    final pointer = _pointerCounter++;
    final binding = GestureBinding.instance;
    var elapsed = Duration.zero;

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: from,
        timeStamp: elapsed,
        kind: PointerDeviceKind.touch,
        device: pointer,
        buttons: kPrimaryButton,
      ),
    );

    const steps = 10;
    const stepDuration = Duration(milliseconds: 8);
    for (var i = 1; i <= steps; i++) {
      elapsed += stepDuration;
      final t = i / steps;
      final pos = Offset(
        from.dx + (to.dx - from.dx) * t,
        from.dy + (to.dy - from.dy) * t,
      );
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: pos,
          timeStamp: elapsed,
          delta: Offset((to.dx - from.dx) / steps, (to.dy - from.dy) / steps),
          kind: PointerDeviceKind.touch,
          device: pointer,
          buttons: kPrimaryButton,
        ),
      );
      await pump(stepDuration);
    }

    elapsed += const Duration(milliseconds: 2);
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: to,
        timeStamp: elapsed,
        kind: PointerDeviceKind.touch,
        device: pointer,
      ),
    );
  }

  void _dispatchScroll(Offset position, Offset delta) {
    GestureBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        position: position,
        scrollDelta: delta,
        kind: PointerDeviceKind.mouse,
        device: _pointerCounter++,
      ),
    );
  }
}
