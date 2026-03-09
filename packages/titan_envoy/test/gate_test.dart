import 'dart:async';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

/// A fake executor with configurable delay.
Future<Dispatch> _delayedExecutor(
  Missive missive, {
  Duration delay = const Duration(milliseconds: 50),
}) async {
  await Future<void>.delayed(delay);
  return Dispatch(
    statusCode: 200,
    data: {'result': 'ok'},
    rawBody: '{"result":"ok"}',
    headers: const {},
    missive: missive,
    duration: delay,
  );
}

Missive _missive([String path = '/test']) =>
    Missive(method: Method.get, uri: Uri.parse('https://api.example.com$path'));

void main() {
  group('Gate', () {
    group('construction', () {
      test('creates with default values', () {
        final gate = Gate();
        expect(gate.maxConcurrent, 6);
        expect(gate.maxQueue, 100);
        expect(gate.queueTimeout, isNull);
        expect(gate.activeCount, 0);
        expect(gate.queueLength, 0);
      });

      test('creates with custom values', () {
        final gate = Gate(
          maxConcurrent: 2,
          maxQueue: 10,
          queueTimeout: Duration(seconds: 5),
        );
        expect(gate.maxConcurrent, 2);
        expect(gate.maxQueue, 10);
        expect(gate.queueTimeout, Duration(seconds: 5));
      });

      test('asserts maxConcurrent > 0', () {
        expect(() => Gate(maxConcurrent: 0), throwsA(isA<AssertionError>()));
        expect(() => Gate(maxConcurrent: -1), throwsA(isA<AssertionError>()));
      });
    });

    group('concurrency limiting', () {
      test('allows up to maxConcurrent simultaneous requests', () async {
        final gate = Gate(maxConcurrent: 3);
        var maxActive = 0;
        var currentActive = 0;

        Future<Dispatch> trackingExecutor(Missive missive) async {
          currentActive++;
          if (currentActive > maxActive) maxActive = currentActive;
          await Future<void>.delayed(Duration(milliseconds: 30));
          currentActive--;
          return Dispatch(
            statusCode: 200,
            data: null,
            rawBody: '',
            headers: const {},
            missive: missive,
            duration: Duration.zero,
          );
        }

        final chain = CourierChain(couriers: [gate], execute: trackingExecutor);
        final futures = List.generate(
          6,
          (i) => chain.proceed(_missive('/r$i')),
        );

        await Future.wait(futures);
        expect(maxActive, lessThanOrEqualTo(3));
      });

      test('single request passes through immediately', () async {
        final gate = Gate(maxConcurrent: 2);
        final chain = CourierChain(
          couriers: [gate],
          execute: (m) => _delayedExecutor(m, delay: Duration.zero),
        );

        final dispatch = await chain.proceed(_missive());
        expect(dispatch.statusCode, 200);
        expect(gate.activeCount, 0);
        expect(gate.queueLength, 0);
      });

      test('queued requests complete after active ones finish', () async {
        final gate = Gate(maxConcurrent: 1);
        final completionOrder = <int>[];
        var callCount = 0;

        Future<Dispatch> sequentialExecutor(Missive missive) async {
          final index = callCount++;
          await Future<void>.delayed(Duration(milliseconds: 20));
          completionOrder.add(index);
          return Dispatch(
            statusCode: 200,
            data: null,
            rawBody: '',
            headers: const {},
            missive: missive,
            duration: Duration.zero,
          );
        }

        final chain = CourierChain(
          couriers: [gate],
          execute: sequentialExecutor,
        );

        await Future.wait([
          chain.proceed(_missive('/a')),
          chain.proceed(_missive('/b')),
          chain.proceed(_missive('/c')),
        ]);

        expect(completionOrder, [0, 1, 2]);
      });

      test('activeCount tracks in-flight requests', () async {
        final gate = Gate(maxConcurrent: 2);
        final started = Completer<void>();
        final release = Completer<void>();

        Future<Dispatch> blockingExecutor(Missive missive) async {
          started.complete();
          await release.future;
          return Dispatch(
            statusCode: 200,
            data: null,
            rawBody: '',
            headers: const {},
            missive: missive,
            duration: Duration.zero,
          );
        }

        final chain = CourierChain(couriers: [gate], execute: blockingExecutor);

        expect(gate.activeCount, 0);

        final future = chain.proceed(_missive());
        await started.future;
        expect(gate.activeCount, 1);

        release.complete();
        await future;
        expect(gate.activeCount, 0);
      });
    });

    group('queue management', () {
      test('rejects when queue is full', () async {
        final gate = Gate(maxConcurrent: 1, maxQueue: 1);
        final release = Completer<void>();

        Future<Dispatch> blockingExecutor(Missive missive) async {
          await release.future;
          return Dispatch(
            statusCode: 200,
            data: null,
            rawBody: '',
            headers: const {},
            missive: missive,
            duration: Duration.zero,
          );
        }

        final chain = CourierChain(couriers: [gate], execute: blockingExecutor);

        // First request takes the active slot
        unawaited(chain.proceed(_missive('/active')));
        await Future<void>.delayed(Duration(milliseconds: 10));

        // Second fills the queue
        unawaited(chain.proceed(_missive('/queued')));
        await Future<void>.delayed(Duration(milliseconds: 10));

        // Third should be rejected
        expect(
          () => chain.proceed(_missive('/rejected')),
          throwsA(isA<EnvoyError>()),
        );

        release.complete();
      });

      test('queueLength tracks waiting requests', () async {
        final gate = Gate(maxConcurrent: 1, maxQueue: 10);
        final release = Completer<void>();

        Future<Dispatch> blockingExecutor(Missive missive) async {
          await release.future;
          return Dispatch(
            statusCode: 200,
            data: null,
            rawBody: '',
            headers: const {},
            missive: missive,
            duration: Duration.zero,
          );
        }

        final chain = CourierChain(couriers: [gate], execute: blockingExecutor);

        // Active slot
        unawaited(chain.proceed(_missive('/a')));
        await Future<void>.delayed(Duration(milliseconds: 10));
        expect(gate.queueLength, 0);
        expect(gate.activeCount, 1);

        // Queue 2 more
        unawaited(chain.proceed(_missive('/b')));
        unawaited(chain.proceed(_missive('/c')));
        await Future<void>.delayed(Duration(milliseconds: 10));
        expect(gate.queueLength, 2);

        release.complete();
        await Future<void>.delayed(Duration(milliseconds: 50));
        expect(gate.queueLength, 0);
        expect(gate.activeCount, 0);
      });

      test('unlimited queue when maxQueue is 0', () async {
        final gate = Gate(maxConcurrent: 1, maxQueue: 0);
        final release = Completer<void>();

        Future<Dispatch> blockingExecutor(Missive missive) async {
          await release.future;
          return Dispatch(
            statusCode: 200,
            data: null,
            rawBody: '',
            headers: const {},
            missive: missive,
            duration: Duration.zero,
          );
        }

        final chain = CourierChain(couriers: [gate], execute: blockingExecutor);

        // Fill active slot
        unawaited(chain.proceed(_missive('/a')));
        await Future<void>.delayed(Duration(milliseconds: 10));

        // Queue many — should not throw
        for (var i = 0; i < 50; i++) {
          unawaited(chain.proceed(_missive('/q$i')));
        }
        await Future<void>.delayed(Duration(milliseconds: 10));
        expect(gate.queueLength, 50);

        release.complete();
        await Future<void>.delayed(Duration(milliseconds: 100));
        expect(gate.queueLength, 0);
      });
    });

    group('timeout', () {
      test('throws timeout when queue wait exceeds queueTimeout', () async {
        final gate = Gate(
          maxConcurrent: 1,
          queueTimeout: Duration(milliseconds: 50),
        );
        final release = Completer<void>();

        Future<Dispatch> blockingExecutor(Missive missive) async {
          await release.future;
          return Dispatch(
            statusCode: 200,
            data: null,
            rawBody: '',
            headers: const {},
            missive: missive,
            duration: Duration.zero,
          );
        }

        final chain = CourierChain(couriers: [gate], execute: blockingExecutor);

        // Fill active slot with long-running request
        unawaited(chain.proceed(_missive('/slow')));
        await Future<void>.delayed(Duration(milliseconds: 10));

        // This should timeout waiting in queue
        await expectLater(
          chain.proceed(_missive('/timeout')),
          throwsA(
            isA<EnvoyError>().having(
              (e) => e.type,
              'type',
              EnvoyErrorType.timeout,
            ),
          ),
        );

        release.complete();
      });
    });

    group('error handling', () {
      test('releases slot on executor error', () async {
        final gate = Gate(maxConcurrent: 1);

        Future<Dispatch> failingExecutor(Missive missive) async {
          throw EnvoyError(
            type: EnvoyErrorType.unknown,
            missive: missive,
            message: 'test error',
          );
        }

        final chain = CourierChain(couriers: [gate], execute: failingExecutor);

        expect(() => chain.proceed(_missive()), throwsA(isA<EnvoyError>()));
        await Future<void>.delayed(Duration(milliseconds: 10));
        expect(gate.activeCount, 0);
      });

      test('slot transfers to queued request on completion', () async {
        final gate = Gate(maxConcurrent: 1);
        final completers = <Completer<void>>[];

        Future<Dispatch> controlledExecutor(Missive missive) async {
          final c = Completer<void>();
          completers.add(c);
          await c.future;
          return Dispatch(
            statusCode: 200,
            data: null,
            rawBody: '',
            headers: const {},
            missive: missive,
            duration: Duration.zero,
          );
        }

        final chain = CourierChain(
          couriers: [gate],
          execute: controlledExecutor,
        );

        // Start first
        final f1 = chain.proceed(_missive('/1'));
        await Future<void>.delayed(Duration(milliseconds: 10));
        expect(gate.activeCount, 1);

        // Queue second
        final f2 = chain.proceed(_missive('/2'));
        await Future<void>.delayed(Duration(milliseconds: 10));
        expect(gate.queueLength, 1);

        // Complete first — second should start
        completers[0].complete();
        await Future<void>.delayed(Duration(milliseconds: 10));
        await f1;
        expect(gate.activeCount, 1);
        expect(gate.queueLength, 0);

        // Complete second
        completers[1].complete();
        await f2;
        expect(gate.activeCount, 0);
      });
    });

    group('integration with CourierChain', () {
      test('works with other couriers', () async {
        final gate = Gate(maxConcurrent: 2);
        final log = <String>[];

        final recorder = _LogCourier(log);
        final chain = CourierChain(
          couriers: [gate, recorder],
          execute: (m) => _delayedExecutor(m, delay: Duration.zero),
        );

        await chain.proceed(_missive());
        expect(log, ['intercept']);
      });
    });
  });
}

class _LogCourier extends Courier {
  _LogCourier(this.log);
  final List<String> log;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    log.add('intercept');
    return chain.proceed(missive);
  }
}
