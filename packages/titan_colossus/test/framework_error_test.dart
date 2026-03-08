import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  group('FrameworkError', () {
    test('toMap serializes all fields', () {
      final error = FrameworkError(
        category: FrameworkErrorCategory.overflow,
        message: 'A RenderFlex overflowed by 42 pixels',
        timestamp: DateTime(2025, 1, 15, 10, 30, 0),
        library: 'rendering library',
        stackTrace: '#0 RenderFlex.performLayout',
      );

      final map = error.toMap();
      expect(map['category'], 'overflow');
      expect(map['message'], 'A RenderFlex overflowed by 42 pixels');
      expect(map['timestamp'], '2025-01-15T10:30:00.000');
      expect(map['library'], 'rendering library');
      expect(map['stackTrace'], '#0 RenderFlex.performLayout');
    });

    test('toMap omits null optional fields', () {
      final error = FrameworkError(
        category: FrameworkErrorCategory.build,
        message: 'Null check operator used on a null value',
        timestamp: DateTime(2025, 1, 15),
      );

      final map = error.toMap();
      expect(map['category'], 'build');
      expect(map['message'], contains('Null check'));
      expect(map.containsKey('library'), false);
      expect(map.containsKey('stackTrace'), false);
    });
  });

  group('FrameworkError.classify', () {
    test('detects overflow from message', () {
      expect(
        FrameworkError.classify(
          message: 'A RenderFlex overflowed by 42.0 pixels on the right.',
          library: 'rendering library',
        ),
        FrameworkErrorCategory.overflow,
      );
    });

    test('detects overflow keyword', () {
      expect(
        FrameworkError.classify(message: 'RenderBox overflow detected'),
        FrameworkErrorCategory.overflow,
      );
    });

    test('detects build from widgets library', () {
      expect(
        FrameworkError.classify(
          message: 'Null check operator used on a null value',
          library: 'widgets library',
        ),
        FrameworkErrorCategory.build,
      );
    });

    test('detects build from context', () {
      expect(
        FrameworkError.classify(
          message: 'Some error',
          context: 'during build for MyWidget',
        ),
        FrameworkErrorCategory.build,
      );
    });

    test('detects layout from context', () {
      expect(
        FrameworkError.classify(
          message: 'Some layout error',
          context: 'during performLayout()',
        ),
        FrameworkErrorCategory.layout,
      );
    });

    test('detects paint from context', () {
      expect(
        FrameworkError.classify(
          message: 'Some paint error',
          context: 'during paint()',
        ),
        FrameworkErrorCategory.paint,
      );
    });

    test('detects gesture from library', () {
      expect(
        FrameworkError.classify(
          message: 'Some gesture error',
          library: 'gesture library',
        ),
        FrameworkErrorCategory.gesture,
      );
    });

    test('detects gesture from context', () {
      expect(
        FrameworkError.classify(
          message: 'Something went wrong',
          context: 'during a gesture callback',
        ),
        FrameworkErrorCategory.gesture,
      );
    });

    test('defaults to other for unknown errors', () {
      expect(
        FrameworkError.classify(
          message: 'Something unexpected happened',
          library: 'services library',
        ),
        FrameworkErrorCategory.other,
      );
    });
  });

  group('FrameworkErrorCategory', () {
    test('has all expected values', () {
      expect(FrameworkErrorCategory.values, hasLength(6));
      expect(
        FrameworkErrorCategory.values,
        contains(FrameworkErrorCategory.overflow),
      );
      expect(
        FrameworkErrorCategory.values,
        contains(FrameworkErrorCategory.build),
      );
      expect(
        FrameworkErrorCategory.values,
        contains(FrameworkErrorCategory.layout),
      );
      expect(
        FrameworkErrorCategory.values,
        contains(FrameworkErrorCategory.paint),
      );
      expect(
        FrameworkErrorCategory.values,
        contains(FrameworkErrorCategory.gesture),
      );
      expect(
        FrameworkErrorCategory.values,
        contains(FrameworkErrorCategory.other),
      );
    });
  });
}
