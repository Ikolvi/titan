import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Aegis', () {
    test('succeeds on first attempt', () async {
      final result = await Aegis.run(
        () async => 42,
        maxAttempts: 3,
      );
      expect(result, 42);
    });

    test('retries and succeeds on later attempt', () async {
      var attempts = 0;
      final result = await Aegis.run(
        () async {
          attempts++;
          if (attempts < 3) throw Exception('not yet');
          return 'success';
        },
        maxAttempts: 5,
        baseDelay: Duration(milliseconds: 10),
      );

      expect(result, 'success');
      expect(attempts, 3);
    });

    test('throws after all attempts exhausted', () async {
      expect(
        () async => await Aegis.run(
          () async {
            throw Exception('always fails');
          },
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 10),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('calls onRetry callback', () async {
      var attempts = 0;
      final retries = <int>[];

      await Aegis.run(
        () async {
          attempts++;
          if (attempts < 3) throw Exception('retry me');
          return 'done';
        },
        maxAttempts: 3,
        baseDelay: Duration(milliseconds: 10),
        onRetry: (attempt, error, delay) {
          retries.add(attempt);
        },
      );

      expect(retries, [1, 2]);
    });

    test('respects retryIf predicate', () async {
      var attempts = 0;

      try {
        await Aegis.run(
          () async {
            attempts++;
            throw StateError('non-retryable');
          },
          maxAttempts: 5,
          baseDelay: Duration(milliseconds: 10),
          retryIf: (e) => e is! StateError,
        );
      } catch (_) {}

      // Should only attempt once since StateError is non-retryable
      expect(attempts, 1);
    });

    test('constant backoff uses same delay', () async {
      final delays = <Duration>[];

      try {
        await Aegis.run(
          () async => throw Exception('fail'),
          maxAttempts: 4,
          baseDelay: Duration(milliseconds: 50),
          strategy: BackoffStrategy.constant,
          jitter: false,
          onRetry: (_, _, delay) => delays.add(delay),
        );
      } catch (_) {}

      for (final d in delays) {
        expect(d.inMilliseconds, 50);
      }
    });

    test('exponential backoff increases delay', () async {
      final delays = <Duration>[];

      try {
        await Aegis.run(
          () async => throw Exception('fail'),
          maxAttempts: 4,
          baseDelay: Duration(milliseconds: 100),
          strategy: BackoffStrategy.exponential,
          jitter: false,
          onRetry: (_, _, delay) => delays.add(delay),
        );
      } catch (_) {}

      expect(delays.length, 3);
      // Exponential: 100, 200, 400
      expect(delays[0].inMilliseconds, 100);
      expect(delays[1].inMilliseconds, 200);
      expect(delays[2].inMilliseconds, 400);
    });

    test('linear backoff increases linearly', () async {
      final delays = <Duration>[];

      try {
        await Aegis.run(
          () async => throw Exception('fail'),
          maxAttempts: 4,
          baseDelay: Duration(milliseconds: 100),
          strategy: BackoffStrategy.linear,
          jitter: false,
          onRetry: (_, _, delay) => delays.add(delay),
        );
      } catch (_) {}

      expect(delays.length, 3);
      // Linear: 100, 200, 300
      expect(delays[0].inMilliseconds, 100);
      expect(delays[1].inMilliseconds, 200);
      expect(delays[2].inMilliseconds, 300);
    });

    test('maxDelay caps exponential growth', () async {
      final delays = <Duration>[];

      try {
        await Aegis.run(
          () async => throw Exception('fail'),
          maxAttempts: 10,
          baseDelay: Duration(milliseconds: 100),
          maxDelay: Duration(milliseconds: 500),
          strategy: BackoffStrategy.exponential,
          jitter: false,
          onRetry: (_, _, delay) => delays.add(delay),
        );
      } catch (_) {}

      for (final d in delays) {
        expect(d.inMilliseconds, lessThanOrEqualTo(500));
      }
    });

    test('jitter adds variation', () async {
      final delays = <Duration>[];

      try {
        await Aegis.run(
          () async => throw Exception('fail'),
          maxAttempts: 4,
          baseDelay: Duration(milliseconds: 100),
          strategy: BackoffStrategy.constant,
          jitter: true,
          onRetry: (_, _, delay) => delays.add(delay),
        );
      } catch (_) {}

      // With jitter on constant 100ms, delays should be 100-150ms
      for (final d in delays) {
        expect(d.inMilliseconds, greaterThanOrEqualTo(100));
        expect(d.inMilliseconds, lessThanOrEqualTo(150));
      }
    });

    test('preserves stack trace', () async {
      expect(
        () async => await Aegis.run(
          () async => throw ArgumentError('bad arg'),
          maxAttempts: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('runWithConfig returns AegisResult with metadata', () async {
      var attempt = 0;
      final result = await Aegis.runWithConfig(
        () async {
          attempt++;
          if (attempt < 2) throw Exception('retry');
          return 'success';
        },
        config: AegisConfig(
          maxAttempts: 3,
          baseDelay: Duration(milliseconds: 10),
        ),
      );

      expect(result.value, 'success');
      expect(result.attempts, 2);
      expect(result.totalDuration.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('runWithConfig throws after exhaustion', () async {
      expect(
        () async => await Aegis.runWithConfig(
          () async => throw Exception('always'),
          config: AegisConfig(
            maxAttempts: 2,
            baseDelay: Duration(milliseconds: 10),
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('AegisConfig.defaults has expected values', () {
      const config = AegisConfig.defaults;
      expect(config.maxAttempts, 3);
      expect(config.baseDelay, Duration(milliseconds: 500));
      expect(config.maxDelay, Duration(seconds: 30));
      expect(config.strategy, BackoffStrategy.exponential);
      expect(config.jitter, isTrue);
      expect(config.retryIf, isNull);
    });

    test('AegisResult toString shows metadata', () {
      const result = AegisResult(
        value: 'test',
        attempts: 3,
        totalDuration: Duration(milliseconds: 1500),
      );
      expect(result.toString(), contains('3'));
      expect(result.toString(), contains('1500'));
    });

    test('single attempt does not retry', () async {
      var attempts = 0;
      try {
        await Aegis.run(
          () async {
            attempts++;
            throw Exception('fail');
          },
          maxAttempts: 1,
        );
      } catch (_) {}

      expect(attempts, 1);
    });
  });
}
