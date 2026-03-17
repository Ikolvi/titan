import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/integration/devtools_bridge.dart';

void main() {
  group('DevToolsBridge install/uninstall', () {
    tearDown(() {
      DevToolsBridge.uninstall();
    });

    test('isInstalled is false by default', () {
      expect(DevToolsBridge.isInstalled, false);
    });

    test('uninstall sets isInstalled to false', () {
      // DevToolsBridge.install needs a Colossus instance, which requires
      // full initialization. We test the static state management instead.
      DevToolsBridge.uninstall();
      expect(DevToolsBridge.isInstalled, false);
    });

    test('double uninstall is safe', () {
      DevToolsBridge.uninstall();
      DevToolsBridge.uninstall(); // Should not throw
      expect(DevToolsBridge.isInstalled, false);
    });
  });

  group('DevToolsBridge static methods', () {
    // These methods use dart:developer APIs which are no-ops in test mode.
    // We verify they don't throw.

    test('timelinePageLoad does not throw', () {
      expect(
        () => DevToolsBridge.timelinePageLoad(
          '/quest/1',
          const Duration(milliseconds: 150),
        ),
        returnsNormally,
      );
    });

    test('timelineTremor does not throw', () {
      expect(
        () => DevToolsBridge.timelineTremor(
          'fps_low',
          'FPS dropped below 30',
          'warning',
        ),
        returnsNormally,
      );
    });

    test('timelineApiCall does not throw', () {
      expect(
        () => DevToolsBridge.timelineApiCall('GET', '/api/heroes', 200, 150),
        returnsNormally,
      );
    });

    test('timelineApiCall handles null statusCode', () {
      expect(
        () => DevToolsBridge.timelineApiCall('GET', '/api/heroes', null, 0),
        returnsNormally,
      );
    });

    test('postTremorAlert does not throw', () {
      expect(
        () => DevToolsBridge.postTremorAlert(
          'fps_low',
          'frame',
          'warning',
          'FPS below 30',
        ),
        returnsNormally,
      );
    });

    test('postApiMetric does not throw', () {
      expect(
        () => DevToolsBridge.postApiMetric({
          'method': 'GET',
          'url': '/api/heroes',
          'statusCode': 200,
          'durationMs': 150,
        }),
        returnsNormally,
      );
    });

    test('postRouteChange does not throw', () {
      expect(
        () => DevToolsBridge.postRouteChange('/home', '/quest/1', 'navigate'),
        returnsNormally,
      );
    });

    test('postRouteChange handles null from', () {
      expect(
        () => DevToolsBridge.postRouteChange(null, '/home', 'navigate'),
        returnsNormally,
      );
    });

    test('postFrameworkError does not throw', () {
      expect(
        () => DevToolsBridge.postFrameworkError(
          'overflow',
          'RenderFlex overflowed by 42 pixels',
        ),
        returnsNormally,
      );
    });

    test('log does not throw', () {
      expect(() => DevToolsBridge.log('Test message'), returnsNormally);
    });

    test('log with custom level and error does not throw', () {
      expect(
        () => DevToolsBridge.log(
          'Error occurred',
          level: 1000,
          error: Exception('test'),
        ),
        returnsNormally,
      );
    });

    test('all timeline methods work when bridge not installed', () {
      DevToolsBridge.uninstall();

      // All static methods should work regardless of install state
      // because they use dart:developer directly
      expect(() {
        DevToolsBridge.timelinePageLoad('/test', Duration.zero);
        DevToolsBridge.timelineTremor('test', 'msg', 'info');
        DevToolsBridge.timelineApiCall('GET', '/test', 200, 0);
        DevToolsBridge.postTremorAlert('test', 'frame', 'info', 'msg');
        DevToolsBridge.postApiMetric({'test': true});
        DevToolsBridge.postRouteChange(null, '/test', 'navigate');
        DevToolsBridge.postFrameworkError('test', 'msg');
        DevToolsBridge.log('test');
      }, returnsNormally);
    });
  });
}
