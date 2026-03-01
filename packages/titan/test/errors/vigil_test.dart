import 'package:test/test.dart';
import 'package:titan/titan.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _RecordingHandler extends ErrorHandler {
  final List<TitanError> errors = [];

  @override
  void handle(TitanError error) {
    errors.add(error);
  }
}

class _ThrowingHandler extends ErrorHandler {
  @override
  void handle(TitanError error) {
    throw StateError('Handler exploded!');
  }
}

// ---------------------------------------------------------------------------
// Test Pillars
// ---------------------------------------------------------------------------

class FailingPillar extends Pillar {
  late final value = core(0);

  Future<void> failAsync() => strikeAsync(() async {
        throw StateError('async boom');
      });

  void manualCapture() {
    try {
      throw FormatException('bad data');
    } catch (e, s) {
      captureError(
        e,
        stackTrace: s,
        action: 'manualCapture',
        metadata: {'key': 'value'},
      );
    }
  }

  void captureWithSeverity(ErrorSeverity severity) {
    captureError(
      'test error',
      severity: severity,
      action: 'testAction',
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    Vigil.reset();
    Titan.reset();
    Herald.reset();
  });

  group('Vigil — Core', () {
    test('capture stores error in history', () {
      Vigil.capture(StateError('boom'));

      expect(Vigil.history, hasLength(1));
      expect(Vigil.history.first.error, isA<StateError>());
    });

    test('capture with full context', () {
      Vigil.capture(
        'test error',
        stackTrace: StackTrace.current,
        severity: ErrorSeverity.fatal,
        context: ErrorContext(
          source: FailingPillar,
          action: 'loadData',
          metadata: {'userId': '123'},
        ),
      );

      final err = Vigil.lastError!;
      expect(err.error, 'test error');
      expect(err.severity, ErrorSeverity.fatal);
      expect(err.stackTrace, isNotNull);
      expect(err.context?.source, FailingPillar);
      expect(err.context?.action, 'loadData');
      expect(err.context?.metadata, {'userId': '123'});
      expect(err.timestamp, isA<DateTime>());
    });

    test('lastError returns most recent', () {
      Vigil.capture('first');
      Vigil.capture('second');
      Vigil.capture('third');

      expect(Vigil.lastError?.error, 'third');
    });

    test('lastError is null when no errors', () {
      expect(Vigil.lastError, isNull);
    });

    test('multiple captures build history', () {
      for (var i = 0; i < 5; i++) {
        Vigil.capture('error $i');
      }
      expect(Vigil.history, hasLength(5));
    });

    test('clearHistory removes all entries', () {
      Vigil.capture('error');
      expect(Vigil.history, isNotEmpty);

      Vigil.clearHistory();
      expect(Vigil.history, isEmpty);
    });
  });

  group('Vigil — History Limit', () {
    test('respects maxHistorySize', () {
      Vigil.maxHistorySize = 3;

      for (var i = 0; i < 10; i++) {
        Vigil.capture('error $i');
      }

      expect(Vigil.history, hasLength(3));
      expect(Vigil.history.first.error, 'error 7');
      expect(Vigil.history.last.error, 'error 9');
    });

    test('maxHistorySize = 0 disables history', () {
      Vigil.maxHistorySize = 0;
      Vigil.capture('dropped');
      expect(Vigil.history, isEmpty);
    });

    test('reducing maxHistorySize trims existing', () {
      for (var i = 0; i < 10; i++) {
        Vigil.capture('error $i');
      }
      expect(Vigil.history, hasLength(10));

      Vigil.maxHistorySize = 3;
      expect(Vigil.history, hasLength(3));
    });
  });

  group('Vigil — Handlers', () {
    test('handler receives captured errors', () {
      final handler = _RecordingHandler();
      Vigil.addHandler(handler);

      Vigil.capture('test');

      expect(handler.errors, hasLength(1));
      expect(handler.errors.first.error, 'test');
    });

    test('multiple handlers all receive errors', () {
      final h1 = _RecordingHandler();
      final h2 = _RecordingHandler();
      Vigil.addHandler(h1);
      Vigil.addHandler(h2);

      Vigil.capture('shared');

      expect(h1.errors, hasLength(1));
      expect(h2.errors, hasLength(1));
    });

    test('removeHandler stops delivery', () {
      final handler = _RecordingHandler();
      Vigil.addHandler(handler);

      Vigil.capture('before');
      Vigil.removeHandler(handler);
      Vigil.capture('after');

      expect(handler.errors, hasLength(1));
      expect(handler.errors.first.error, 'before');
    });

    test('throwing handler does not break other handlers', () {
      final good = _RecordingHandler();
      Vigil.addHandler(_ThrowingHandler());
      Vigil.addHandler(good);

      Vigil.capture('resilient');

      expect(good.errors, hasLength(1));
    });

    test('handlers list is read-only', () {
      Vigil.addHandler(_RecordingHandler());
      expect(Vigil.handlers, hasLength(1));
      expect(
        () => (Vigil.handlers as List).add(_RecordingHandler()),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('Vigil — FilteredErrorHandler', () {
    test('only forwards matching errors', () {
      final inner = _RecordingHandler();
      Vigil.addHandler(FilteredErrorHandler(
        filter: (e) => e.severity == ErrorSeverity.fatal,
        handler: inner,
      ));

      Vigil.capture('info', severity: ErrorSeverity.info);
      Vigil.capture('warning', severity: ErrorSeverity.warning);
      Vigil.capture('fatal', severity: ErrorSeverity.fatal);

      expect(inner.errors, hasLength(1));
      expect(inner.errors.first.error, 'fatal');
    });
  });

  group('Vigil — Stream', () {
    test('errors stream delivers captured errors', () {
      final received = <TitanError>[];
      final sub = Vigil.errors.listen(received.add);

      Vigil.capture('streamed');

      expect(received, hasLength(1));
      expect(received.first.error, 'streamed');
      sub.cancel();
    });

    test('stream is broadcast', () {
      expect(Vigil.errors.isBroadcast, isTrue);
    });
  });

  group('Vigil — Query', () {
    test('bySeverity filters correctly', () {
      Vigil.capture('d', severity: ErrorSeverity.debug);
      Vigil.capture('i', severity: ErrorSeverity.info);
      Vigil.capture('w', severity: ErrorSeverity.warning);
      Vigil.capture('e1', severity: ErrorSeverity.error);
      Vigil.capture('e2', severity: ErrorSeverity.error);
      Vigil.capture('f', severity: ErrorSeverity.fatal);

      expect(Vigil.bySeverity(ErrorSeverity.error), hasLength(2));
      expect(Vigil.bySeverity(ErrorSeverity.fatal), hasLength(1));
      expect(Vigil.bySeverity(ErrorSeverity.debug), hasLength(1));
    });

    test('bySource filters correctly', () {
      Vigil.capture('a',
          context: ErrorContext(source: FailingPillar));
      Vigil.capture('b',
          context: ErrorContext(source: FailingPillar));
      Vigil.capture('c', context: ErrorContext(source: String));

      expect(Vigil.bySource(FailingPillar), hasLength(2));
      expect(Vigil.bySource(String), hasLength(1));
      expect(Vigil.bySource(int), isEmpty);
    });
  });

  group('Vigil — Guard', () {
    test('guard returns value on success', () {
      final result = Vigil.guard(() => 42);
      expect(result, 42);
      expect(Vigil.history, isEmpty);
    });

    test('guard returns null and captures on failure', () {
      final result = Vigil.guard<int>(() => throw StateError('oops'));
      expect(result, isNull);
      expect(Vigil.history, hasLength(1));
      expect(Vigil.lastError?.error, isA<StateError>());
    });

    test('guardAsync returns value on success', () async {
      final result = await Vigil.guardAsync(() async => 'ok');
      expect(result, 'ok');
      expect(Vigil.history, isEmpty);
    });

    test('guardAsync returns null and captures on failure', () async {
      final result = await Vigil.guardAsync<String>(
        () async => throw FormatException('bad'),
      );
      expect(result, isNull);
      expect(Vigil.history, hasLength(1));
    });

    test('captureAndRethrow captures then rethrows', () async {
      expect(
        () => Vigil.captureAndRethrow<int>(
          () async => throw StateError('fail'),
        ),
        throwsA(isA<StateError>()),
      );

      // Wait for async to complete
      await Future<void>.delayed(Duration.zero);
      expect(Vigil.history, hasLength(1));
    });

    test('guard with custom context', () {
      Vigil.guard(
        () => throw 'ouch',
        severity: ErrorSeverity.warning,
        context: ErrorContext(action: 'parse'),
      );

      final err = Vigil.lastError!;
      expect(err.severity, ErrorSeverity.warning);
      expect(err.context?.action, 'parse');
    });
  });

  group('Vigil — Reset', () {
    test('reset clears handlers, history, and maxHistorySize', () {
      Vigil.addHandler(_RecordingHandler());
      Vigil.capture('error');
      Vigil.maxHistorySize = 5;

      Vigil.reset();

      expect(Vigil.handlers, isEmpty);
      expect(Vigil.history, isEmpty);
      expect(Vigil.maxHistorySize, 100);
    });
  });

  group('Pillar — Vigil integration', () {
    test('strikeAsync auto-captures errors', () async {
      final pillar = FailingPillar()..initialize();

      try {
        await pillar.failAsync();
      } catch (_) {
        // expected
      }

      expect(Vigil.history, hasLength(1));
      final err = Vigil.lastError!;
      expect(err.error, isA<StateError>());
      expect(err.context?.source, FailingPillar);
      expect(err.context?.action, 'strikeAsync');
      expect(err.stackTrace, isNotNull);
    });

    test('strikeAsync rethrows after capture', () async {
      final pillar = FailingPillar()..initialize();

      expect(
        () => pillar.failAsync(),
        throwsA(isA<StateError>()),
      );
    });

    test('captureError tags with Pillar runtimeType', () {
      final pillar = FailingPillar()..initialize();
      pillar.manualCapture();

      expect(Vigil.history, hasLength(1));
      final err = Vigil.lastError!;
      expect(err.error, isA<FormatException>());
      expect(err.context?.source, FailingPillar);
      expect(err.context?.action, 'manualCapture');
      expect(err.context?.metadata, {'key': 'value'});
    });

    test('captureError with severity', () {
      final pillar = FailingPillar()..initialize();

      pillar.captureWithSeverity(ErrorSeverity.fatal);
      expect(Vigil.lastError?.severity, ErrorSeverity.fatal);

      pillar.captureWithSeverity(ErrorSeverity.warning);
      expect(Vigil.lastError?.severity, ErrorSeverity.warning);
    });

    test('Vigil integrates with Titan DI', () async {
      Titan.put(FailingPillar());
      final handler = _RecordingHandler();
      Vigil.addHandler(handler);

      try {
        await Titan.get<FailingPillar>().failAsync();
      } catch (_) {}

      expect(handler.errors, hasLength(1));
      expect(handler.errors.first.context?.source, FailingPillar);
    });
  });

  group('TitanError', () {
    test('toString includes severity and error', () {
      final err = TitanError(
        error: 'something broke',
        severity: ErrorSeverity.fatal,
      );
      expect(err.toString(), contains('FATAL'));
      expect(err.toString(), contains('something broke'));
    });

    test('toString includes source and action', () {
      final err = TitanError(
        error: 'oops',
        context: ErrorContext(
          source: FailingPillar,
          action: 'loadData',
        ),
      );
      expect(err.toString(), contains('FailingPillar'));
      expect(err.toString(), contains('loadData'));
    });
  });

  group('ErrorContext', () {
    test('toString includes all fields', () {
      final ctx = ErrorContext(
        source: FailingPillar,
        action: 'test',
        metadata: {'a': 1},
      );
      expect(ctx.toString(), contains('FailingPillar'));
      expect(ctx.toString(), contains('test'));
      expect(ctx.toString(), contains('a'));
    });
  });

  group('ConsoleErrorHandler', () {
    test('respects minSeverity', () {
      // ConsoleErrorHandler prints to stdout — just verify it doesn't throw
      final handler = ConsoleErrorHandler(
        minSeverity: ErrorSeverity.fatal,
        includeStackTrace: false,
      );

      // Should not print (below minSeverity)
      handler.handle(TitanError(
          error: 'info', severity: ErrorSeverity.info));

      // Should print (meets minSeverity)
      handler.handle(TitanError(
          error: 'fatal', severity: ErrorSeverity.fatal));
    });
  });

  group('Vigil — Ring Buffer', () {
    test('ring buffer wraps correctly at capacity', () {
      Vigil.maxHistorySize = 3;

      for (var i = 0; i < 10; i++) {
        Vigil.capture('error $i');
      }

      expect(Vigil.history, hasLength(3));
      // Should have the 3 most recent in order
      expect(Vigil.history[0].error, 'error 7');
      expect(Vigil.history[1].error, 'error 8');
      expect(Vigil.history[2].error, 'error 9');
    });

    test('lastError correct after buffer wraps multiple times', () {
      Vigil.maxHistorySize = 2;

      Vigil.capture('a');
      expect(Vigil.lastError?.error, 'a');

      Vigil.capture('b');
      expect(Vigil.lastError?.error, 'b');

      Vigil.capture('c'); // wraps
      expect(Vigil.lastError?.error, 'c');

      Vigil.capture('d'); // wraps again
      expect(Vigil.lastError?.error, 'd');

      // History should be [c, d]
      expect(Vigil.history[0].error, 'c');
      expect(Vigil.history[1].error, 'd');
    });

    test('increasing maxHistorySize preserves existing entries', () {
      Vigil.maxHistorySize = 3;

      Vigil.capture('a');
      Vigil.capture('b');
      Vigil.capture('c');

      expect(Vigil.history, hasLength(3));

      Vigil.maxHistorySize = 10;
      expect(Vigil.history, hasLength(3));
      expect(Vigil.history[0].error, 'a');
      expect(Vigil.history[1].error, 'b');
      expect(Vigil.history[2].error, 'c');

      // Can now add more
      Vigil.capture('d');
      expect(Vigil.history, hasLength(4));
    });

    test('clearHistory resets ring buffer after wrap', () {
      Vigil.maxHistorySize = 2;

      Vigil.capture('a');
      Vigil.capture('b');
      Vigil.capture('c'); // wraps

      Vigil.clearHistory();
      expect(Vigil.history, isEmpty);
      expect(Vigil.lastError, isNull);

      // Can record again after clear
      Vigil.capture('d');
      expect(Vigil.history, hasLength(1));
      expect(Vigil.lastError?.error, 'd');
    });

    test('setting same maxHistorySize is no-op', () {
      Vigil.maxHistorySize = 100; // default
      Vigil.capture('a');
      Vigil.capture('b');

      Vigil.maxHistorySize = 100; // same
      expect(Vigil.history, hasLength(2));
    });

    test('bySeverity works after ring buffer wraps', () {
      Vigil.maxHistorySize = 3;

      Vigil.capture('w1', severity: ErrorSeverity.warning);
      Vigil.capture('e1', severity: ErrorSeverity.error);
      Vigil.capture('w2', severity: ErrorSeverity.warning);
      Vigil.capture('e2', severity: ErrorSeverity.error); // wraps, evicts w1
      Vigil.capture('f1', severity: ErrorSeverity.fatal); // wraps, evicts e1

      // History: [w2, e2, f1]
      expect(Vigil.bySeverity(ErrorSeverity.warning), hasLength(1));
      expect(Vigil.bySeverity(ErrorSeverity.error), hasLength(1));
      expect(Vigil.bySeverity(ErrorSeverity.fatal), hasLength(1));
    });
  });
}
