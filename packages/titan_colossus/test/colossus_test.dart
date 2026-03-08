import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------
  // Colossus — performance monitor
  // ---------------------------------------------------------

  group('Colossus', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    // ---------------------------------------------------------
    // Singleton lifecycle
    // ---------------------------------------------------------

    test('init creates singleton instance', () {
      final colossus = Colossus.init(enableLensTab: false);

      expect(Colossus.isActive, true);
      expect(Colossus.instance, same(colossus));
    });

    test('init returns existing instance on duplicate call', () {
      final first = Colossus.init(enableLensTab: false);
      final second = Colossus.init(enableLensTab: false);

      expect(first, same(second));
    });

    test('shutdown clears singleton', () {
      Colossus.init(enableLensTab: false);
      expect(Colossus.isActive, true);

      Colossus.shutdown();
      expect(Colossus.isActive, false);
    });

    // ---------------------------------------------------------
    // Decree — performance report
    // ---------------------------------------------------------

    test('decree returns a report snapshot', () {
      final colossus = Colossus.init(enableLensTab: false);
      final decree = colossus.decree();

      expect(decree.totalFrames, 0);
      expect(decree.jankFrames, 0);
      expect(decree.pillarCount, isA<int>());
    });

    // ---------------------------------------------------------
    // Reset
    // ---------------------------------------------------------

    test('reset clears all metrics', () {
      final colossus = Colossus.init(enableLensTab: false);
      colossus.recordRebuild('MyWidget');
      expect(colossus.rebuildsPerWidget['MyWidget'], 1);

      colossus.reset();
      expect(colossus.rebuildsPerWidget, isEmpty);
    });

    // ---------------------------------------------------------
    // Inscribe export shortcuts
    // ---------------------------------------------------------

    test('inscribeMarkdown returns non-empty string', () {
      final colossus = Colossus.init(enableLensTab: false);
      final md = colossus.inscribeMarkdown();

      expect(md, isNotEmpty);
      expect(md, contains('Performance'));
    });

    test('inscribeJson returns valid JSON-like string', () {
      final colossus = Colossus.init(enableLensTab: false);
      final json = colossus.inscribeJson();

      expect(json, isNotEmpty);
      expect(json, startsWith('{'));
    });

    test('inscribeHtml returns HTML string', () {
      final colossus = Colossus.init(enableLensTab: false);
      final html = colossus.inscribeHtml();

      expect(html, isNotEmpty);
      expect(html, contains('<html'));
    });

    // ---------------------------------------------------------
    // Shade access
    // ---------------------------------------------------------

    test('shade instance is accessible', () {
      final colossus = Colossus.init(enableLensTab: false);

      expect(colossus.shade, isA<Shade>());
      expect(colossus.shade.isRecording, false);
    });

    // ---------------------------------------------------------
    // replaySession — route safety
    // ---------------------------------------------------------

    test('replaySession detects route mismatch without throwing', () async {
      final colossus = Colossus.init(enableLensTab: false);
      colossus.shade.getCurrentRoute = () => '/settings';

      final session = ShadeSession(
        id: 'route_test',
        name: 'route_test',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        startRoute: '/home',
        imprints: [],
      );

      // Should complete without throwing (logs warning but continues)
      final result = await colossus.replaySession(session);
      expect(result.eventsDispatched, 0);
      expect(result.wasCancelled, false);
    });

    test('replaySession throws on route mismatch when required', () async {
      final colossus = Colossus.init(enableLensTab: false);
      colossus.shade.getCurrentRoute = () => '/settings';

      final session = ShadeSession(
        id: 'require_route',
        name: 'require_route',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        startRoute: '/home',
        imprints: [],
      );

      expect(
        () => colossus.replaySession(session, requireMatchingRoute: true),
        throwsStateError,
      );
    });

    test('replaySession succeeds when route matches', () async {
      final colossus = Colossus.init(enableLensTab: false);
      colossus.shade.getCurrentRoute = () => '/home';

      final session = ShadeSession(
        id: 'match',
        name: 'match',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        startRoute: '/home',
        imprints: [],
      );

      final result = await colossus.replaySession(session);
      expect(result.eventsDispatched, 0);
    });

    test('replaySession skips route check when no startRoute', () async {
      final colossus = Colossus.init(enableLensTab: false);
      colossus.shade.getCurrentRoute = () => '/anywhere';

      final session = ShadeSession(
        id: 'no_route',
        name: 'no_route',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      final result = await colossus.replaySession(session);
      expect(result.eventsDispatched, 0);
    });

    // ---------------------------------------------------------
    // replaySession — waitForSettled passthrough
    // ---------------------------------------------------------

    test('replaySession accepts waitForSettled parameter', () async {
      final colossus = Colossus.init(enableLensTab: false);

      final session = ShadeSession(
        id: 'settled',
        name: 'settled',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      // Should not throw — parameter is accepted
      final result = await colossus.replaySession(
        session,
        waitForSettled: true,
        settleTimeout: const Duration(seconds: 2),
      );
      expect(result.eventsDispatched, 0);
    });

    // ---------------------------------------------------------
    // replaySession — resetBeforeReplay
    // ---------------------------------------------------------

    test(
      'replaySession resets metrics when resetBeforeReplay is true',
      () async {
        final colossus = Colossus.init(enableLensTab: false);
        colossus.recordRebuild('Widget1');
        expect(colossus.rebuildsPerWidget['Widget1'], 1);

        final session = ShadeSession(
          id: 'reset',
          name: 'reset',
          recordedAt: DateTime(2025, 1, 1),
          duration: Duration.zero,
          screenWidth: 375,
          screenHeight: 812,
          devicePixelRatio: 2.0,
          imprints: [],
        );

        await colossus.replaySession(session, resetBeforeReplay: true);
        expect(colossus.rebuildsPerWidget, isEmpty);
      },
    );

    test(
      'replaySession preserves metrics when resetBeforeReplay is false',
      () async {
        final colossus = Colossus.init(enableLensTab: false);
        colossus.recordRebuild('Widget1');

        final session = ShadeSession(
          id: 'no_reset',
          name: 'no_reset',
          recordedAt: DateTime(2025, 1, 1),
          duration: Duration.zero,
          screenWidth: 375,
          screenHeight: 812,
          devicePixelRatio: 2.0,
          imprints: [],
        );

        await colossus.replaySession(session, resetBeforeReplay: false);
        expect(colossus.rebuildsPerWidget['Widget1'], 1);
      },
    );

    // ---------------------------------------------------------
    // replaySession — onProgress callback
    // ---------------------------------------------------------

    test('replaySession forwards onProgress callback', () async {
      final colossus = Colossus.init(enableLensTab: false);
      final progressUpdates = <List<int>>[];

      final session = ShadeSession(
        id: 'progress',
        name: 'progress',
        recordedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 1),
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [
          Imprint(
            type: ImprintType.textInput,
            positionX: 0,
            positionY: 0,
            timestamp: const Duration(milliseconds: 10),
            text: 'test',
            fieldId: 'field1',
          ),
        ],
      );

      await colossus.replaySession(
        session,
        onProgress: (current, total) {
          progressUpdates.add([current, total]);
        },
      );

      expect(progressUpdates, isNotEmpty);
      expect(progressUpdates.last, [1, 1]);
    });

    // ---------------------------------------------------------
    // Rebuild tracking
    // ---------------------------------------------------------

    test('recordRebuild increments widget count', () {
      final colossus = Colossus.init(enableLensTab: false);

      colossus.recordRebuild('Counter');
      colossus.recordRebuild('Counter');
      colossus.recordRebuild('Header');

      expect(colossus.rebuildsPerWidget['Counter'], 2);
      expect(colossus.rebuildsPerWidget['Header'], 1);
    });

    test('alertHistory starts empty', () {
      final colossus = Colossus.init(enableLensTab: false);
      expect(colossus.alertHistory, isEmpty);
    });

    test('alertHistory is unmodifiable', () {
      final colossus = Colossus.init(enableLensTab: false);
      expect(
        () => colossus.alertHistory.add(
          ColossusTremor(tremor: Tremor.fps(), message: 'test'),
        ),
        throwsUnsupportedError,
      );
    });

    test('frameworkErrors starts empty', () {
      final colossus = Colossus.init(enableLensTab: false);
      expect(colossus.frameworkErrors, isEmpty);
    });

    test('frameworkErrors is unmodifiable', () {
      final colossus = Colossus.init(enableLensTab: false);
      expect(
        () => colossus.frameworkErrors.add(
          FrameworkError(
            category: FrameworkErrorCategory.overflow,
            message: 'test',
            timestamp: DateTime.now(),
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  // ---------------------------------------------------------
  // Colossus — vault and auto-replay
  // ---------------------------------------------------------

  group('Colossus — auto-replay', () {
    late Directory tempDir;

    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
      tempDir = Directory.systemTemp.createTempSync('colossus_test_');
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('vault is null when shadeStoragePath not provided', () {
      final colossus = Colossus.init(enableLensTab: false);
      expect(colossus.vault, isNull);
    });

    test('vault is set when shadeStoragePath provided', () {
      final colossus = Colossus.init(
        enableLensTab: false,
        shadeStoragePath: tempDir.path,
      );
      expect(colossus.vault, isNotNull);
    });

    test('saveSession saves to vault and returns path', () async {
      final colossus = Colossus.init(
        enableLensTab: false,
        shadeStoragePath: tempDir.path,
      );

      final session = ShadeSession(
        id: 'save_test',
        name: 'save_test',
        recordedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 2),
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [
          Imprint(
            type: ImprintType.pointerDown,
            positionX: 100,
            positionY: 200,
            timestamp: const Duration(milliseconds: 100),
          ),
        ],
      );

      final path = await colossus.saveSession(session);
      expect(path, isNotNull);
      expect(path, isNotEmpty);
    });

    test('saveSession returns null when vault not configured', () async {
      final colossus = Colossus.init(enableLensTab: false);

      final session = ShadeSession(
        id: 'no_vault',
        name: 'no_vault',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      final path = await colossus.saveSession(session);
      expect(path, isNull);
    });

    test('loadSession retrieves saved session', () async {
      final colossus = Colossus.init(
        enableLensTab: false,
        shadeStoragePath: tempDir.path,
      );

      final session = ShadeSession(
        id: 'load_test',
        name: 'load_test',
        recordedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 1),
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      await colossus.saveSession(session);
      final loaded = await colossus.loadSession('load_test');

      expect(loaded, isNotNull);
      expect(loaded!.name, 'load_test');
    });

    test('checkAutoReplay returns null when vault not configured', () async {
      final colossus = Colossus.init(enableLensTab: false);

      final result = await colossus.checkAutoReplay();
      expect(result, isNull);
    });

    test('checkAutoReplay returns null when not enabled', () async {
      final colossus = Colossus.init(
        enableLensTab: false,
        shadeStoragePath: tempDir.path,
      );

      final result = await colossus.checkAutoReplay();
      expect(result, isNull);
    });

    test('checkAutoReplay blocks on route mismatch', () async {
      final colossus = Colossus.init(
        enableLensTab: false,
        shadeStoragePath: tempDir.path,
      );

      // Save a session with start route
      final session = ShadeSession(
        id: 'route_block',
        name: 'route_block',
        recordedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 1),
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        startRoute: '/home',
        imprints: [
          Imprint(
            type: ImprintType.pointerDown,
            positionX: 100,
            positionY: 200,
            timestamp: const Duration(milliseconds: 50),
          ),
        ],
      );

      await colossus.saveSession(session);
      await colossus.setAutoReplay(enabled: true, sessionId: 'route_block');

      // Set a different current route
      colossus.shade.getCurrentRoute = () => '/settings';

      // checkAutoReplay should detect the mismatch and return null
      final result = await colossus.checkAutoReplay();
      expect(result, isNull);
    });

    test('setAutoReplay persists config to vault', () async {
      final colossus = Colossus.init(
        enableLensTab: false,
        shadeStoragePath: tempDir.path,
      );

      await colossus.setAutoReplay(
        enabled: true,
        sessionId: 'my_session',
        speed: 2.0,
      );

      final config = await colossus.vault!.getAutoReplayConfig();
      expect(config, isNotNull);
      expect(config!.enabled, true);
      expect(config.sessionId, 'my_session');
      expect(config.speed, 2.0);
    });

    test('setAutoReplay does nothing when vault not configured', () async {
      final colossus = Colossus.init(enableLensTab: false);

      // Should not throw
      await colossus.setAutoReplay(enabled: true, sessionId: 'test');
    });
  });

  // ---------------------------------------------------------
  // VesselConfig
  // ---------------------------------------------------------

  group('VesselConfig', () {
    test('creates with defaults', () {
      const config = VesselConfig();

      expect(config.checkInterval, const Duration(seconds: 10));
      expect(config.leakThreshold, const Duration(minutes: 5));
      expect(config.exemptTypes, isEmpty);
    });

    test('creates with custom values', () {
      const config = VesselConfig(
        checkInterval: Duration(seconds: 5),
        leakThreshold: Duration(minutes: 2),
        exemptTypes: {'AuthPillar'},
      );

      expect(config.checkInterval, const Duration(seconds: 5));
      expect(config.leakThreshold, const Duration(minutes: 2));
      expect(config.exemptTypes, contains('AuthPillar'));
    });
  });
}
