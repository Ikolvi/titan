import 'package:test/test.dart';
import 'package:titan/titan.dart';

/// A test sink that collects log entries for assertions.
class TestLogSink extends LogSink {
  final List<LogEntry> entries = [];

  @override
  void write(LogEntry entry) => entries.add(entry);

  void clear() => entries.clear();
}

class _TestPillar extends Pillar {
  late final count = core(0);

  void logSomething() {
    log.info('Count is ${count.value}');
  }

  void logError() {
    log.error('Something failed', Exception('oops'), StackTrace.current);
  }
}

void main() {
  group('Chronicle', () {
    late TestLogSink sink;

    setUp(() {
      Chronicle.reset();
      sink = TestLogSink();
      Chronicle.addSink(sink);
    });

    tearDown(() => Chronicle.reset());

    // -----------------------------------------------------------------------
    // Basic logging
    // -----------------------------------------------------------------------

    test('logs at all levels', () {
      final log = Chronicle('Test');
      Chronicle.level = LogLevel.trace;

      log.trace('trace msg');
      log.debug('debug msg');
      log.info('info msg');
      log.warning('warning msg');
      log.error('error msg');
      log.fatal('fatal msg');

      expect(sink.entries.length, 6);
      expect(sink.entries[0].level, LogLevel.trace);
      expect(sink.entries[1].level, LogLevel.debug);
      expect(sink.entries[2].level, LogLevel.info);
      expect(sink.entries[3].level, LogLevel.warning);
      expect(sink.entries[4].level, LogLevel.error);
      expect(sink.entries[5].level, LogLevel.fatal);
    });

    test('logger name is preserved', () {
      final log = Chronicle('AuthService');
      log.info('hello');

      expect(sink.entries.single.loggerName, 'AuthService');
    });

    test('message is preserved', () {
      final log = Chronicle('Test');
      log.info('important message');

      expect(sink.entries.single.message, 'important message');
    });

    test('data is attached', () {
      final log = Chronicle('Test');
      log.info('event', {'key': 'value', 'count': 42});

      expect(sink.entries.single.data, {'key': 'value', 'count': 42});
    });

    test('error and stack trace are attached', () {
      final log = Chronicle('Test');
      final error = Exception('failure');
      final stack = StackTrace.current;

      log.error('failed', error, stack);

      expect(sink.entries.single.error, error);
      expect(sink.entries.single.stackTrace, stack);
    });

    test('timestamp is set automatically', () {
      final before = DateTime.now();
      final log = Chronicle('Test');
      log.info('now');
      final after = DateTime.now();

      final ts = sink.entries.single.timestamp;
      expect(ts.isAfter(before) || ts.isAtSameMomentAs(before), isTrue);
      expect(ts.isBefore(after) || ts.isAtSameMomentAs(after), isTrue);
    });

    // -----------------------------------------------------------------------
    // Level filtering
    // -----------------------------------------------------------------------

    test('suppresses messages below global level', () {
      Chronicle.level = LogLevel.warning;
      final log = Chronicle('Test');

      log.trace('nope');
      log.debug('nope');
      log.info('nope');
      log.warning('yes');
      log.error('yes');
      log.fatal('yes');

      expect(sink.entries.length, 3);
      expect(sink.entries.map((e) => e.level).toList(), [
        LogLevel.warning,
        LogLevel.error,
        LogLevel.fatal,
      ]);
    });

    test('LogLevel.off suppresses everything', () {
      Chronicle.level = LogLevel.off;
      final log = Chronicle('Test');

      log.trace('nope');
      log.debug('nope');
      log.info('nope');
      log.warning('nope');
      log.error('nope');
      log.fatal('nope');

      expect(sink.entries, isEmpty);
    });

    test('LogLevel.trace shows everything', () {
      Chronicle.level = LogLevel.trace;
      final log = Chronicle('Test');

      log.trace('1');
      log.debug('2');
      log.info('3');
      log.warning('4');
      log.error('5');
      log.fatal('6');

      expect(sink.entries.length, 6);
    });

    // -----------------------------------------------------------------------
    // Sinks
    // -----------------------------------------------------------------------

    test('routes to multiple sinks', () {
      final sink2 = TestLogSink();
      Chronicle.addSink(sink2);
      final log = Chronicle('Test');

      log.info('multi');

      expect(sink.entries.length, 1);
      expect(sink2.entries.length, 1);
    });

    test('removeSink stops routing to that sink', () {
      final log = Chronicle('Test');
      log.info('before');
      expect(sink.entries.length, 1);

      Chronicle.removeSink(sink);
      log.info('after');
      expect(sink.entries.length, 1); // no new entry
    });

    test('sink errors do not cascade', () {
      Chronicle.addSink(_FailingSink());
      final log = Chronicle('Test');

      // Should not throw
      log.info('safe');

      // Our test sink still received it
      expect(sink.entries.length, 1);
    });

    test('reset clears sinks and restores defaults', () {
      Chronicle.level = LogLevel.fatal;
      Chronicle.addSink(TestLogSink());
      Chronicle.addSink(TestLogSink());

      Chronicle.reset();

      expect(Chronicle.level, LogLevel.debug);
      // After reset, sinks list is re-initialized lazily with consoleSink
      expect(Chronicle.sinks, contains(Chronicle.consoleSink));
    });

    // -----------------------------------------------------------------------
    // call() method
    // -----------------------------------------------------------------------

    test('call() logs at given level', () {
      final log = Chronicle('Test');
      log.call(LogLevel.warning, 'custom',
          data: {'x': 1}, error: 'err', stackTrace: StackTrace.empty);

      final entry = sink.entries.single;
      expect(entry.level, LogLevel.warning);
      expect(entry.message, 'custom');
      expect(entry.data, {'x': 1});
      expect(entry.error, 'err');
      expect(entry.stackTrace, StackTrace.empty);
    });

    // -----------------------------------------------------------------------
    // LogEntry.toString()
    // -----------------------------------------------------------------------

    test('LogEntry toString includes level, name, message', () {
      final entry = LogEntry(
        loggerName: 'Auth',
        level: LogLevel.info,
        message: 'logged in',
      );
      expect(entry.toString(), contains('[INFO]'));
      expect(entry.toString(), contains('Auth'));
      expect(entry.toString(), contains('logged in'));
    });

    test('LogEntry toString includes data and error', () {
      final entry = LogEntry(
        loggerName: 'X',
        level: LogLevel.error,
        message: 'fail',
        data: {'k': 'v'},
        error: Exception('bad'),
      );
      final str = entry.toString();
      expect(str, contains('{k: v}'));
      expect(str, contains('Error:'));
    });

    // -----------------------------------------------------------------------
    // ConsoleLogSink
    // -----------------------------------------------------------------------

    test('ConsoleLogSink respects minLevel', () {
      final consoleSink = ConsoleLogSink(minLevel: LogLevel.error);

      // We can't easily capture print output, but we can verify the
      // minLevel filtering by subclassing
      final trackingSink = _TrackingConsoleSink(minLevel: LogLevel.error);

      final log = Chronicle('Test');
      Chronicle.addSink(trackingSink);

      log.debug('should skip');
      log.info('should skip');
      log.error('should show');

      expect(trackingSink.writtenEntries, 1);
      expect(consoleSink.minLevel, LogLevel.error);
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------

    test('Pillar.log is auto-named after runtimeType', () {
      final pillar = _TestPillar();
      pillar.initialize();
      pillar.logSomething();

      expect(sink.entries.single.loggerName, '_TestPillar');
      expect(sink.entries.single.message, 'Count is 0');

      pillar.dispose();
    });

    test('Pillar.log.error captures error details', () {
      final pillar = _TestPillar();
      pillar.initialize();
      pillar.logError();

      final entry = sink.entries.single;
      expect(entry.level, LogLevel.error);
      expect(entry.error, isA<Exception>());
      expect(entry.stackTrace, isNotNull);

      pillar.dispose();
    });

    // -----------------------------------------------------------------------
    // Default sink behavior
    // -----------------------------------------------------------------------

    test('default console sink is added on first log', () {
      Chronicle.reset();
      // Don't manually add any sink

      final log = Chronicle('Test');
      // Logging triggers _ensureInitialized which adds consoleSink
      log.info('auto');

      expect(Chronicle.sinks, contains(Chronicle.consoleSink));
    });

    // -----------------------------------------------------------------------
    // Multiple loggers
    // -----------------------------------------------------------------------

    test('multiple loggers share global config', () {
      Chronicle.level = LogLevel.error;
      final a = Chronicle('A');
      final b = Chronicle('B');

      a.info('skipped');
      b.info('skipped');
      a.error('shown');
      b.fatal('shown');

      expect(sink.entries.length, 2);
      expect(sink.entries[0].loggerName, 'A');
      expect(sink.entries[1].loggerName, 'B');
    });
  });
}

class _FailingSink extends LogSink {
  @override
  void write(LogEntry entry) => throw Exception('sink failure');
}

class _TrackingConsoleSink extends ConsoleLogSink {
  int writtenEntries = 0;

  _TrackingConsoleSink({super.minLevel});

  @override
  void write(LogEntry entry) {
    if (entry.level.index >= minLevel.index) {
      writtenEntries++;
    }
  }
}
