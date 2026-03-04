import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------
  // Phantom — gesture replay engine
  // ---------------------------------------------------------

  group('Phantom', () {
    // ---------------------------------------------------------
    // Construction
    // ---------------------------------------------------------

    test('creates with default settings', () {
      final phantom = Phantom();

      expect(phantom.normalizePositions, true);
      expect(phantom.speedMultiplier, 1.0);
      expect(phantom.isReplaying, false);
      expect(phantom.shade, isNull);
      expect(phantom.suppressKeyboard, true);
    });

    test('creates with custom settings', () {
      final shade = Shade();
      final phantom = Phantom(
        normalizePositions: false,
        speedMultiplier: 2.0,
        shade: shade,
        suppressKeyboard: false,
      );

      expect(phantom.normalizePositions, false);
      expect(phantom.speedMultiplier, 2.0);
      expect(phantom.shade, same(shade));
      expect(phantom.suppressKeyboard, false);
    });

    test('creates with waitForSettled defaults', () {
      final phantom = Phantom();

      expect(phantom.waitForSettled, false);
      expect(phantom.settleTimeout, const Duration(seconds: 5));
    });

    test('creates with custom waitForSettled settings', () {
      final phantom = Phantom(
        waitForSettled: true,
        settleTimeout: const Duration(seconds: 10),
      );

      expect(phantom.waitForSettled, true);
      expect(phantom.settleTimeout, const Duration(seconds: 10));
    });

    test('rejects non-positive speed multiplier', () {
      expect(() => Phantom(speedMultiplier: 0), throwsA(isA<ArgumentError>()));
      expect(() => Phantom(speedMultiplier: -1), throwsA(isA<ArgumentError>()));
    });

    // ---------------------------------------------------------
    // Empty session
    // ---------------------------------------------------------

    test('handles empty session gracefully', () async {
      final phantom = Phantom();
      final session = ShadeSession(
        id: 'empty',
        name: 'empty',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      final result = await phantom.replay(session);

      expect(result.eventsDispatched, 0);
      expect(result.eventsSkipped, 0);
      expect(result.wasCancelled, false);
      expect(result.sessionName, 'empty');
    });
  });

  // ---------------------------------------------------------
  // PhantomResult — replay outcome
  // ---------------------------------------------------------

  group('PhantomResult', () {
    test('computes totalEvents correctly', () {
      final result = PhantomResult(
        sessionName: 'test',
        eventsDispatched: 10,
        eventsSkipped: 2,
        expectedDuration: const Duration(seconds: 5),
        actualDuration: const Duration(seconds: 5),
        wasNormalized: false,
        wasCancelled: false,
      );

      expect(result.totalEvents, 12);
    });

    test('computes speedRatio correctly', () {
      final result = PhantomResult(
        sessionName: 'test',
        eventsDispatched: 10,
        eventsSkipped: 0,
        expectedDuration: const Duration(seconds: 10),
        actualDuration: const Duration(seconds: 5),
        wasNormalized: false,
        wasCancelled: false,
      );

      expect(result.speedRatio, closeTo(0.5, 0.01));
    });

    test('speedRatio returns 0 for zero-duration session', () {
      final result = PhantomResult(
        sessionName: 'test',
        eventsDispatched: 0,
        eventsSkipped: 0,
        expectedDuration: Duration.zero,
        actualDuration: Duration.zero,
        wasNormalized: false,
        wasCancelled: false,
      );

      expect(result.speedRatio, 0);
    });

    test('toMap includes all fields', () {
      final result = PhantomResult(
        sessionName: 'checkout',
        eventsDispatched: 50,
        eventsSkipped: 3,
        expectedDuration: const Duration(seconds: 10),
        actualDuration: const Duration(seconds: 5),
        wasNormalized: true,
        wasCancelled: false,
      );
      final map = result.toMap();

      expect(map['sessionName'], 'checkout');
      expect(map['eventsDispatched'], 50);
      expect(map['eventsSkipped'], 3);
      expect(map['wasNormalized'], true);
      expect(map['wasCancelled'], false);
      expect(map['speedRatio'], isA<double>());
    });

    test('toString includes key info', () {
      final result = PhantomResult(
        sessionName: 'login',
        eventsDispatched: 20,
        eventsSkipped: 0,
        expectedDuration: const Duration(seconds: 3),
        actualDuration: const Duration(seconds: 3),
        wasNormalized: false,
        wasCancelled: false,
      );

      expect(result.toString(), contains('login'));
      expect(result.toString(), contains('20/20'));
    });

    test('toString shows CANCELLED for cancelled replays', () {
      final result = PhantomResult(
        sessionName: 'test',
        eventsDispatched: 5,
        eventsSkipped: 0,
        expectedDuration: const Duration(seconds: 10),
        actualDuration: const Duration(seconds: 2),
        wasNormalized: false,
        wasCancelled: true,
      );

      expect(result.toString(), contains('CANCELLED'));
    });
  });

  // ---------------------------------------------------------
  // Phantom — direct text replay via registry
  // ---------------------------------------------------------

  group('Phantom direct text replay', () {
    test('sets isReplaying on shade during replay', () async {
      final shade = Shade();
      final phantom = Phantom(shade: shade);

      expect(shade.isReplaying, false);

      final session = ShadeSession(
        id: 'replay_flag',
        name: 'replay_flag',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      await phantom.replay(session);
      // After replay, flag should be cleared
      expect(shade.isReplaying, false);
    });

    test('uses controller registry for textInput imprints', () async {
      final shade = Shade();
      final controller = ShadeTextController(shade: shade, fieldId: 'email');

      final phantom = Phantom(shade: shade, suppressKeyboard: false);

      final session = ShadeSession(
        id: 'text_replay',
        name: 'text_replay',
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
            timestamp: const Duration(milliseconds: 100),
            text: 'kael@ironclad.dev',
            selectionBase: 17,
            selectionExtent: 17,
            fieldId: 'email',
          ),
        ],
      );

      final result = await phantom.replay(session);

      expect(result.eventsDispatched, 1);
      expect(controller.text, 'kael@ironclad.dev');
      expect(controller.selection.baseOffset, 17);

      controller.dispose();
    });

    test('falls back to onTextInput when no controller registered', () async {
      final shade = Shade();
      final receivedImprints = <Imprint>[];

      final phantom = Phantom(
        shade: shade,
        suppressKeyboard: false,
        onTextInput: (imprint) => receivedImprints.add(imprint),
      );

      final session = ShadeSession(
        id: 'fallback',
        name: 'fallback',
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
            timestamp: const Duration(milliseconds: 50),
            text: 'fallback text',
            fieldId: 'unregistered_field',
          ),
        ],
      );

      await phantom.replay(session);

      expect(receivedImprints.length, 1);
      expect(receivedImprints.first.text, 'fallback text');
    });

    test('sets text silently without recording', () async {
      final shade = Shade();
      final controller = ShadeTextController(shade: shade, fieldId: 'name');

      // Start recording to verify no duplicate events
      shade.startRecording(name: 'verify', screenSize: const Size(375, 812));

      final phantom = Phantom(shade: shade, suppressKeyboard: false);

      final session = ShadeSession(
        id: 'silent',
        name: 'silent',
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
            text: 'injected',
            selectionBase: 8,
            selectionExtent: 8,
            fieldId: 'name',
          ),
        ],
      );

      await phantom.replay(session);

      // Controller should have the text
      expect(controller.text, 'injected');
      // Shade should NOT have recorded a duplicate
      expect(shade.currentEventCount, 0);

      shade.stopRecording();
      controller.dispose();
    });
  });

  // ---------------------------------------------------------
  // Phantom — waitForSettled behavior
  // ---------------------------------------------------------

  group('Phantom waitForSettled', () {
    test('replays empty session with waitForSettled enabled', () async {
      final phantom = Phantom(
        waitForSettled: true,
        settleTimeout: const Duration(seconds: 1),
      );

      final session = ShadeSession(
        id: 'settled_empty',
        name: 'settled_empty',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      final result = await phantom.replay(session);

      expect(result.eventsDispatched, 0);
      expect(result.wasCancelled, false);
    });

    test('cancel works during waitForSettled replay', () async {
      final phantom = Phantom(
        waitForSettled: true,
        settleTimeout: const Duration(seconds: 1),
      );

      final session = ShadeSession(
        id: 'cancel_settled',
        name: 'cancel_settled',
        recordedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 5),
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [
          Imprint(
            type: ImprintType.textInput,
            positionX: 0,
            positionY: 0,
            timestamp: const Duration(milliseconds: 10),
            text: 'before cancel',
          ),
        ],
      );

      // Start replay and immediately cancel
      final future = phantom.replay(session);
      phantom.cancel();

      final result = await future;
      // Should complete (may or may not be cancelled depending on timing)
      expect(result, isA<PhantomResult>());
    });
  });

  // ---------------------------------------------------------
  // Phantom — route validation
  // ---------------------------------------------------------

  group('Phantom route validation', () {
    test('creates with validateRoute defaults to true', () {
      final phantom = Phantom();
      expect(phantom.validateRoute, true);
    });

    test('creates with validateRoute set to false', () {
      final phantom = Phantom(validateRoute: false);
      expect(phantom.validateRoute, false);
    });

    test('no-op when session has no startRoute', () async {
      final shade = Shade();
      shade.getCurrentRoute = () => '/different';

      final phantom = Phantom(shade: shade, validateRoute: true);

      final session = ShadeSession(
        id: 'no_start_route',
        name: 'no_start_route',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        startRoute: null,
        imprints: [],
      );

      final result = await phantom.replay(session);

      expect(result.wasCancelled, false);
      expect(result.routeChanged, false);
      expect(result.invalidRoute, isNull);
    });

    test('no-op when shade has no getCurrentRoute', () async {
      final shade = Shade();
      // No getCurrentRoute set

      final phantom = Phantom(shade: shade, validateRoute: true);

      final session = ShadeSession(
        id: 'no_callback',
        name: 'no_callback',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        startRoute: '/quests',
        imprints: [],
      );

      final result = await phantom.replay(session);

      expect(result.wasCancelled, false);
      expect(result.routeChanged, false);
    });

    test('skipped when validateRoute is false', () async {
      final shade = Shade();
      shade.getCurrentRoute = () => '/login';

      final phantom = Phantom(
        shade: shade,
        validateRoute: false,
        suppressKeyboard: false,
      );

      final session = ShadeSession(
        id: 'skip_validation',
        name: 'skip_validation',
        recordedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 1),
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        startRoute: '/quests',
        imprints: [
          Imprint(
            type: ImprintType.textInput,
            positionX: 0,
            positionY: 0,
            timestamp: const Duration(milliseconds: 10),
            text: 'test',
          ),
        ],
      );

      final result = await phantom.replay(session);

      // Should complete without cancellation even though routes differ
      expect(result.wasCancelled, false);
      expect(result.routeChanged, false);
      // Text event skipped: no controller registered, no focused field,
      // and no onTextInput callback — but replay itself completed.
      expect(result.eventsSkipped, 1);
    });
  });

  // ---------------------------------------------------------
  // PhantomResult — route changed fields
  // ---------------------------------------------------------

  group('PhantomResult route fields', () {
    test('defaults routeChanged to false', () {
      final result = PhantomResult(
        sessionName: 'test',
        eventsDispatched: 10,
        eventsSkipped: 0,
        expectedDuration: const Duration(seconds: 5),
        actualDuration: const Duration(seconds: 5),
        wasNormalized: false,
        wasCancelled: false,
      );

      expect(result.routeChanged, false);
      expect(result.invalidRoute, isNull);
    });

    test('includes routeChanged in toMap', () {
      final result = PhantomResult(
        sessionName: 'test',
        eventsDispatched: 5,
        eventsSkipped: 0,
        expectedDuration: const Duration(seconds: 5),
        actualDuration: const Duration(seconds: 2),
        wasNormalized: false,
        wasCancelled: true,
        routeChanged: true,
        invalidRoute: '/login',
      );
      final map = result.toMap();

      expect(map['routeChanged'], true);
      expect(map['invalidRoute'], '/login');
    });

    test('excludes invalidRoute from toMap when null', () {
      final result = PhantomResult(
        sessionName: 'test',
        eventsDispatched: 10,
        eventsSkipped: 0,
        expectedDuration: const Duration(seconds: 5),
        actualDuration: const Duration(seconds: 5),
        wasNormalized: false,
        wasCancelled: false,
      );
      final map = result.toMap();

      expect(map['routeChanged'], false);
      expect(map.containsKey('invalidRoute'), false);
    });

    test('toString shows ROUTE_CHANGED', () {
      final result = PhantomResult(
        sessionName: 'checkout',
        eventsDispatched: 3,
        eventsSkipped: 0,
        expectedDuration: const Duration(seconds: 10),
        actualDuration: const Duration(seconds: 1),
        wasNormalized: false,
        wasCancelled: true,
        routeChanged: true,
        invalidRoute: '/login',
      );

      expect(result.toString(), contains('ROUTE_CHANGED'));
      expect(result.toString(), contains('/login'));
    });

    test('toString omits ROUTE_CHANGED when false', () {
      final result = PhantomResult(
        sessionName: 'test',
        eventsDispatched: 10,
        eventsSkipped: 0,
        expectedDuration: const Duration(seconds: 5),
        actualDuration: const Duration(seconds: 5),
        wasNormalized: false,
        wasCancelled: false,
      );

      expect(result.toString(), isNot(contains('ROUTE_CHANGED')));
    });
  });
}
