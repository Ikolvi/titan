import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  group('ColossusLogger', () {
    test('DefaultLogger implements ColossusLogger', () {
      final logger = DefaultLogger('Test');
      expect(logger, isA<ColossusLogger>());
      expect(logger.name, 'Test');
    });

    test('DefaultLogger logs without throwing', () {
      final logger = DefaultLogger('Test');
      // Should not throw
      logger.info('info message');
      logger.info('info with data', {'key': 'value'});
      logger.warning('warning message');
      logger.warning('warning with data', {'count': 42});
      logger.error('error message');
      logger.error('error with details', Exception('test'), StackTrace.current);
    });

    test('DefaultLogger routes to sink when provided', () {
      final entries = <ColossusLogEntry>[];
      final sink = _TestLogSink(entries);
      final logger = DefaultLogger('Sink', sink: sink);

      logger.info('hello', {'k': 'v'});
      logger.warning('warn');
      logger.error('err');

      expect(entries, hasLength(3));
      expect(entries[0].level, 'info');
      expect(entries[0].loggerName, 'Sink');
      expect(entries[0].message, 'hello');
      expect(entries[0].data, {'k': 'v'});
      expect(entries[0].timestamp, isA<DateTime>());
      expect(entries[1].level, 'warning');
      expect(entries[2].level, 'error');
    });
  });

  group('ColossusLogEntry', () {
    test('stores all fields', () {
      final ts = DateTime(2024, 1, 1);
      final entry = ColossusLogEntry(
        loggerName: 'Test',
        level: 'info',
        message: 'hello',
        timestamp: ts,
        data: {'key': 'value'},
      );

      expect(entry.loggerName, 'Test');
      expect(entry.level, 'info');
      expect(entry.message, 'hello');
      expect(entry.timestamp, ts);
      expect(entry.data, {'key': 'value'});
    });
  });

  group('ColossusEventBus', () {
    test('DefaultEventBus implements ColossusEventBus', () {
      final bus = DefaultEventBus();
      expect(bus, isA<ColossusEventBus>());
      bus.dispose();
    });

    test('emits and receives events', () async {
      final bus = DefaultEventBus();
      final received = <Object>[];
      final sub = bus.allEvents.listen(received.add);

      bus.emit('event1');
      bus.emit(42);
      bus.emit({'type': 'test'});

      await Future<void>.delayed(Duration.zero);

      expect(received, [
        'event1',
        42,
        {'type': 'test'},
      ]);
      await sub.cancel();
      bus.dispose();
    });

    test('does not throw when emitting after dispose', () {
      final bus = DefaultEventBus();
      bus.dispose();
      // Should not throw
      bus.emit('after dispose');
    });

    test('does not throw when disposing twice', () {
      final bus = DefaultEventBus();
      bus.dispose();
      bus.dispose();
    });
  });

  group('ColossusErrorReporter', () {
    test('DefaultErrorReporter implements ColossusErrorReporter', () {
      final reporter = DefaultErrorReporter();
      expect(reporter, isA<ColossusErrorReporter>());
    });

    test('captures errors with severity', () async {
      final reporter = DefaultErrorReporter();
      final errors = <Object>[];
      final sub = reporter.errors.listen(errors.add);

      reporter.capture('test error');
      reporter.capture('warning', severity: ColossusErrorSeverity.warning);
      reporter.capture('info', severity: ColossusErrorSeverity.info);

      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(3));
      expect(reporter.history, hasLength(3));

      final first = reporter.history.first as ColossusErrorEntry;
      expect(first.message, 'test error');
      expect(first.severity, ColossusErrorSeverity.error);
      expect(first.timestamp, isA<DateTime>());

      await sub.cancel();
    });

    test('clearHistory clears accumulated errors', () {
      final reporter = DefaultErrorReporter();
      reporter.capture('error1');
      reporter.capture('error2');
      expect(reporter.history, hasLength(2));

      reporter.clearHistory();
      expect(reporter.history, isEmpty);
    });

    test('history is capped at max entries', () {
      final reporter = DefaultErrorReporter();
      for (var i = 0; i < 250; i++) {
        reporter.capture('error $i');
      }
      // DefaultErrorReporter._maxHistory is 200
      expect(reporter.history.length, 200);
    });
  });

  group('ColossusErrorEntry', () {
    test('toString includes severity and message', () {
      final entry = ColossusErrorEntry(
        message: 'test',
        severity: ColossusErrorSeverity.warning,
        timestamp: DateTime(2024, 1, 1),
      );
      expect(entry.toString(), contains('warning'));
      expect(entry.toString(), contains('test'));
    });
  });

  group('ColossusServiceLocator', () {
    test('DefaultServiceLocator implements ColossusServiceLocator', () {
      final locator = DefaultServiceLocator();
      expect(locator, isA<ColossusServiceLocator>());
    });

    test('register and resolve', () {
      final locator = DefaultServiceLocator();
      locator.register<String>('hello');
      expect(locator.resolve<String>(), 'hello');
    });

    test('resolve throws when not registered', () {
      final locator = DefaultServiceLocator();
      expect(() => locator.resolve<String>(), throwsStateError);
    });

    test('tryResolve returns null when not registered', () {
      final locator = DefaultServiceLocator();
      expect(locator.tryResolve<String>(), isNull);
    });

    test('has returns correct state', () {
      final locator = DefaultServiceLocator();
      expect(locator.has<String>(), isFalse);
      locator.register<String>('hello');
      expect(locator.has<String>(), isTrue);
    });

    test('unregister removes instance', () {
      final locator = DefaultServiceLocator();
      locator.register<String>('hello');
      locator.unregister<String>();
      expect(locator.has<String>(), isFalse);
    });

    test('instances returns all registered', () {
      final locator = DefaultServiceLocator();
      locator.register<String>('hello');
      locator.register<int>(42);
      expect(locator.instances, hasLength(2));
      expect(locator.instances[String], 'hello');
      expect(locator.instances[int], 42);
    });

    test('registeredTypes returns type set', () {
      final locator = DefaultServiceLocator();
      locator.register<String>('hello');
      locator.register<int>(42);
      expect(locator.registeredTypes, containsAll([String, int]));
    });

    test('instances map is unmodifiable', () {
      final locator = DefaultServiceLocator();
      locator.register<String>('hello');
      expect(() => locator.instances[String] = 'world', throwsA(anything));
    });
  });

  group('ColossusReactiveValue', () {
    test('DefaultReactiveValue implements ColossusReactiveValue', () {
      final rv = DefaultReactiveValue<int>(0);
      expect(rv, isA<ColossusReactiveValue<int>>());
      rv.dispose();
    });

    test('value get and set', () {
      final rv = DefaultReactiveValue<int>(0);
      expect(rv.value, 0);
      rv.value = 42;
      expect(rv.value, 42);
      rv.dispose();
    });

    test('peek returns current value', () {
      final rv = DefaultReactiveValue<String>('hello');
      expect(rv.peek(), 'hello');
      rv.value = 'world';
      expect(rv.peek(), 'world');
      rv.dispose();
    });

    test('notifies listeners on change', () {
      final rv = DefaultReactiveValue<int>(0);
      var notified = false;
      rv.addListener(() => notified = true);
      rv.value = 1;
      expect(notified, isTrue);
      rv.dispose();
    });

    test('does not notify when value is same', () {
      final rv = DefaultReactiveValue<int>(42);
      var notifyCount = 0;
      rv.addListener(() => notifyCount++);
      rv.value = 42; // Same value
      expect(notifyCount, 0);
      rv.dispose();
    });

    test('removeListener stops notifications', () {
      final rv = DefaultReactiveValue<int>(0);
      var notified = false;
      void listener() => notified = true;
      rv.addListener(listener);
      rv.removeListener(listener);
      rv.value = 1;
      expect(notified, isFalse);
      rv.dispose();
    });
  });

  group('ColossusBindings', () {
    setUp(() => ColossusBindings.reset());
    tearDown(() => ColossusBindings.reset());

    test('throws when not installed', () {
      expect(() => ColossusBindings.instance, throwsStateError);
    });

    test('isInstalled returns false initially', () {
      expect(ColossusBindings.isInstalled, isFalse);
    });

    test('install and access instance', () {
      ColossusBindings.installDefaults();
      expect(ColossusBindings.isInstalled, isTrue);
      expect(ColossusBindings.instance, isA<ColossusBindings>());
    });

    test('installDefaults creates working bindings', () {
      ColossusBindings.installDefaults();
      final b = ColossusBindings.instance;

      // Logger
      final logger = b.createLogger('Test');
      expect(logger, isA<DefaultLogger>());

      // Event bus
      expect(b.eventBus, isA<DefaultEventBus>());

      // Error reporter
      expect(b.errorReporter, isA<DefaultErrorReporter>());

      // Service locator
      expect(b.serviceLocator, isA<DefaultServiceLocator>());

      // Reactive value
      final rv = b.createReactiveValue(42);
      expect(rv, isA<DefaultReactiveValue<int>>());
      expect(rv.value, 42);
      rv.dispose();

      b.eventBus.dispose();
    });

    test('reset clears installed bindings', () {
      ColossusBindings.installDefaults();
      expect(ColossusBindings.isInstalled, isTrue);
      ColossusBindings.reset();
      expect(ColossusBindings.isInstalled, isFalse);
    });

    test('custom bindings can be installed', () {
      final bus = DefaultEventBus();
      final reporter = DefaultErrorReporter();
      final locator = DefaultServiceLocator();

      ColossusBindings.install(
        ColossusBindings(
          createLogger: DefaultLogger.new,
          eventBus: bus,
          errorReporter: reporter,
          serviceLocator: locator,
          createReactiveValue: <T>(T initial) =>
              DefaultReactiveValue<T>(initial),
        ),
      );

      expect(ColossusBindings.instance.eventBus, same(bus));
      expect(ColossusBindings.instance.errorReporter, same(reporter));
      expect(ColossusBindings.instance.serviceLocator, same(locator));

      bus.dispose();
    });
  });

  group('TitanBindings', () {
    setUp(() => ColossusBindings.reset());
    tearDown(() => ColossusBindings.reset());

    test('creates all bindings', () {
      final bindings = TitanBindings();
      ColossusBindings.install(bindings);

      final b = ColossusBindings.instance;
      expect(b, isA<TitanBindings>());

      // Logger creates Chronicle-backed loggers
      final logger = b.createLogger('Test');
      expect(logger, isA<ColossusLogger>());

      // Event bus uses Herald
      expect(b.eventBus, isA<ColossusEventBus>());

      // Error reporter uses Vigil
      expect(b.errorReporter, isA<ColossusErrorReporter>());

      // Service locator uses Titan DI
      expect(b.serviceLocator, isA<ColossusServiceLocator>());

      // Reactive value uses Core<T>
      final rv = b.createReactiveValue(42);
      expect(rv, isA<ColossusReactiveValue<int>>());
      expect(rv.value, 42);
      rv.dispose();
    });

    test('logger logs via Chronicle', () {
      final bindings = TitanBindings();
      ColossusBindings.install(bindings);

      final logger = ColossusBindings.instance.createLogger('TestLog');
      // Should not throw
      logger.info('info test');
      logger.warning('warning test');
      logger.error('error test');
    });

    test('event bus emits via Herald', () async {
      final bindings = TitanBindings();
      ColossusBindings.install(bindings);

      final events = <Object>[];
      final sub = ColossusBindings.instance.eventBus.allEvents.listen(
        events.add,
      );

      ColossusBindings.instance.eventBus.emit('test event');
      await Future<void>.delayed(Duration.zero);

      expect(events, ['test event']);
      await sub.cancel();
    });

    test('service locator delegates to Titan DI', () {
      final bindings = TitanBindings();
      ColossusBindings.install(bindings);

      final locator = ColossusBindings.instance.serviceLocator;
      locator.register<_TestService>(_TestService('hello'));
      expect(locator.has<_TestService>(), isTrue);
      expect(locator.resolve<_TestService>().name, 'hello');

      locator.unregister<_TestService>();
      expect(locator.has<_TestService>(), isFalse);
    });

    test('error reporter delegates to Vigil', () {
      final bindings = TitanBindings();
      ColossusBindings.install(bindings);

      final reporter = ColossusBindings.instance.errorReporter;
      // Should not throw
      reporter.capture('test error', severity: ColossusErrorSeverity.warning);
    });
  });

  group('ColossusErrorSeverity', () {
    test('has all expected values', () {
      expect(ColossusErrorSeverity.values, hasLength(4));
      expect(
        ColossusErrorSeverity.values,
        containsAll([
          ColossusErrorSeverity.info,
          ColossusErrorSeverity.warning,
          ColossusErrorSeverity.error,
          ColossusErrorSeverity.fatal,
        ]),
      );
    });
  });
}

class _TestLogSink implements ColossusLogSink {
  final List<ColossusLogEntry> entries;
  _TestLogSink(this.entries);

  @override
  void write(ColossusLogEntry entry) => entries.add(entry);
}

class _TestService {
  final String name;
  _TestService(this.name);
}
