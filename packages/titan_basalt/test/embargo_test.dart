import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Embargo', () {
    group('construction', () {
      test('creates with default permits (mutex)', () {
        final e = Embargo(name: 'test');
        expect(e.permits, 1);
        expect(e.name, 'test');
        expect(e.timeout, isNull);
        expect(e.activeCount.value, 0);
        expect(e.queueLength.value, 0);
        expect(e.totalAcquires.value, 0);
        expect(e.isLocked.value, false);
        expect(e.isAvailable.value, true);
        expect(e.canAcquire, true);
        expect(e.status.value, EmbargoStatus.available);
      });

      test('creates with custom permits (semaphore)', () {
        final e = Embargo(permits: 3, name: 'pool');
        expect(e.permits, 3);
        expect(e.canAcquire, true);
      });

      test('rejects permits <= 0', () {
        expect(() => Embargo(permits: 0), throwsA(isA<ArgumentError>()));
        expect(() => Embargo(permits: -1), throwsA(isA<ArgumentError>()));
      });
    });

    group('guard (mutex)', () {
      test('executes action and returns result', () async {
        final e = Embargo(name: 'test');
        final result = await e.guard(() async => 42);
        expect(result, 42);
        expect(e.totalAcquires.value, 1);
        expect(e.activeCount.value, 0);
      });

      test('serializes concurrent calls', () async {
        final e = Embargo(name: 'test');
        final order = <int>[];

        final f1 = e.guard(() async {
          order.add(1);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          order.add(2);
          return 'a';
        });

        final f2 = e.guard(() async {
          order.add(3);
          return 'b';
        });

        await Future.wait([f1, f2]);

        // f1 starts first, f2 waits, then f2 runs after f1 completes
        expect(order, [1, 2, 3]);
      });

      test('releases permit on error', () async {
        final e = Embargo(name: 'test');

        try {
          await e.guard(() async => throw Exception('boom'));
        } catch (_) {}

        expect(e.activeCount.value, 0);
        expect(e.isLocked.value, false);
        expect(e.totalAcquires.value, 1);
      });

      test('tracks reactive state during execution', () async {
        final e = Embargo(name: 'test');
        final stateDuringExec = <bool>[];

        await e.guard(() async {
          stateDuringExec.add(e.isLocked.value);
          stateDuringExec.add(e.isAvailable.value);
        });

        expect(stateDuringExec, [true, false]);
        expect(e.isLocked.value, false);
        expect(e.isAvailable.value, true);
      });
    });

    group('guard (semaphore)', () {
      test('allows N concurrent executions', () async {
        final e = Embargo(permits: 3, name: 'pool');
        var concurrent = 0;
        var maxConcurrent = 0;

        Future<void> task() async {
          concurrent++;
          if (concurrent > maxConcurrent) maxConcurrent = concurrent;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          concurrent--;
        }

        await Future.wait([
          e.guard(task),
          e.guard(task),
          e.guard(task),
          e.guard(task),
          e.guard(task),
        ]);

        expect(maxConcurrent, 3);
        expect(e.totalAcquires.value, 5);
        expect(e.activeCount.value, 0);
      });

      test('queues beyond permit limit', () async {
        final e = Embargo(permits: 2, name: 'pool');
        final completers = <Completer<void>>[
          Completer(),
          Completer(),
          Completer(),
        ];
        final started = <int>[];

        // Start 3 tasks, but only 2 can run at once
        final f1 = e.guard(() async {
          started.add(1);
          await completers[0].future;
        });
        final f2 = e.guard(() async {
          started.add(2);
          await completers[1].future;
        });
        final f3 = e.guard(() async {
          started.add(3);
          await completers[2].future;
        });

        // Give time for tasks to start
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(started, [1, 2]); // Only 2 started
        expect(e.queueLength.value, 1); // 1 waiting
        expect(e.status.value, EmbargoStatus.contended);

        // Complete first task, third should start
        completers[0].complete();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(started, [1, 2, 3]);
        expect(e.queueLength.value, 0);

        // Complete remaining
        completers[1].complete();
        completers[2].complete();
        await Future.wait([f1, f2, f3]);

        expect(e.activeCount.value, 0);
      });
    });

    group('acquire / release', () {
      test('manual acquire and release', () async {
        final e = Embargo(name: 'test');

        final lease = await e.acquire();
        expect(lease.isReleased, false);
        expect(e.isLocked.value, true);
        expect(e.activeCount.value, 1);

        lease.release();
        expect(lease.isReleased, true);
        expect(e.isLocked.value, false);
        expect(e.activeCount.value, 0);
      });

      test('double release throws', () async {
        final e = Embargo(name: 'test');
        final lease = await e.acquire();
        lease.release();
        expect(() => lease.release(), throwsStateError);
      });

      test('holdDuration tracks time', () async {
        final e = Embargo(name: 'test');
        final lease = await e.acquire();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(lease.holdDuration.inMilliseconds, greaterThan(15));
        lease.release();
      });
    });

    group('timeout', () {
      test('throws EmbargoTimeoutException on timeout', () async {
        final e = Embargo(name: 'test');

        // Acquire the only permit
        final lease = await e.acquire();

        // Try to acquire with timeout — should throw
        await expectLater(
          e.guard(
            () async => 'never',
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<EmbargoTimeoutException>()),
        );

        lease.release();
      });

      test('uses instance timeout as default', () async {
        final e = Embargo(
          name: 'test',
          timeout: const Duration(milliseconds: 50),
        );

        final lease = await e.acquire();

        await expectLater(
          e.guard(() async => 'never'),
          throwsA(isA<EmbargoTimeoutException>()),
        );

        lease.release();
      });

      test('per-call timeout overrides instance timeout', () async {
        final e = Embargo(name: 'test', timeout: const Duration(seconds: 10));

        final lease = await e.acquire();

        await expectLater(
          e.guard(
            () async => 'never',
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<EmbargoTimeoutException>()),
        );

        lease.release();
      });

      test('exception contains context', () async {
        final e = Embargo(name: 'myLock');
        final lease = await e.acquire();

        try {
          await e.guard(
            () async => 'never',
            timeout: const Duration(milliseconds: 50),
          );
          fail('Should have thrown');
        } on EmbargoTimeoutException catch (ex) {
          expect(ex.embargoName, 'myLock');
          expect(ex.timeout, const Duration(milliseconds: 50));
          expect(ex.toString(), contains('myLock'));
          expect(ex.toString(), contains('50ms'));
        }

        lease.release();
      });
    });

    group('status', () {
      test('available when no permits held', () {
        final e = Embargo(permits: 2, name: 'test');
        expect(e.status.value, EmbargoStatus.available);
      });

      test('busy when all permits held but no queue', () async {
        final e = Embargo(permits: 1, name: 'test');
        final completer = Completer<void>();

        final f = e.guard(() async {
          await completer.future;
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(e.status.value, EmbargoStatus.busy);

        completer.complete();
        await f;
      });

      test('contended when all permits held and queue non-empty', () async {
        final e = Embargo(permits: 1, name: 'test');
        final completer = Completer<void>();

        final f1 = e.guard(() async {
          await completer.future;
        });

        // This will queue
        final f2 = e.guard(() async => 'queued');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(e.status.value, EmbargoStatus.contended);
        expect(e.queueLength.value, 1);

        completer.complete();
        await Future.wait([f1, f2]);
        expect(e.status.value, EmbargoStatus.available);
      });
    });

    group('reset', () {
      test('resets all state', () async {
        final e = Embargo(permits: 2, name: 'test');

        // Acquire some permits
        final l1 = await e.acquire();
        final l2 = await e.acquire();
        expect(e.activeCount.value, 2);
        expect(e.totalAcquires.value, 2);

        e.reset();

        expect(e.activeCount.value, 0);
        expect(e.totalAcquires.value, 0);
        expect(e.queueLength.value, 0);
        expect(e.status.value, EmbargoStatus.available);

        // Leases are now detached — releasing them won't affect state
        // (activeCount is already 0, _release checks <= 0)
        l1.release();
        l2.release();
      });

      test('cancels waiting tasks on reset', () async {
        final e = Embargo(name: 'test');

        // Acquire the only permit
        final lease = await e.acquire();

        // Start a waiter
        final waiterFuture = e.guard(() async => 'waited');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(e.queueLength.value, 1);

        // Reset cancels the waiter
        e.reset();

        expect(waiterFuture, throwsA(isA<StateError>()));

        lease.release();
      });
    });

    group('canAcquire', () {
      test('true when permits available', () {
        final e = Embargo(permits: 2, name: 'test');
        expect(e.canAcquire, true);
      });

      test('false when all permits held', () async {
        final e = Embargo(permits: 1, name: 'test');
        final lease = await e.acquire();
        expect(e.canAcquire, false);
        lease.release();
        expect(e.canAcquire, true);
      });
    });

    group('managedNodes', () {
      test('returns reactive nodes for Pillar integration', () {
        final e = Embargo(name: 'test');
        expect(e.managedNodes, isNotEmpty);
        expect(e.managedNodes.length, 3);
      });
    });

    group('FIFO ordering', () {
      test('waiters are served in order', () async {
        final e = Embargo(name: 'test');
        final order = <int>[];

        final blocker = Completer<void>();
        final f0 = e.guard(() async {
          await blocker.future;
        });

        // Queue tasks in order
        final f1 = e.guard(() async {
          order.add(1);
        });
        final f2 = e.guard(() async {
          order.add(2);
        });
        final f3 = e.guard(() async {
          order.add(3);
        });

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(e.queueLength.value, 3);

        blocker.complete();
        await Future.wait([f0, f1, f2, f3]);

        expect(order, [1, 2, 3]);
      });
    });

    group('EmbargoTimeoutException', () {
      test('toString includes details', () {
        final ex = EmbargoTimeoutException(
          embargoName: 'submit',
          timeout: const Duration(milliseconds: 100),
          queueLength: 5,
        );
        expect(ex.toString(), contains('submit'));
        expect(ex.toString(), contains('100ms'));
        expect(ex.toString(), contains('5 waiting'));
      });
    });

    group('stress', () {
      test('handles 100 concurrent tasks through mutex', () async {
        final e = Embargo(name: 'stress');
        var counter = 0;
        var maxConcurrent = 0;
        var current = 0;

        final futures = List.generate(100, (i) {
          return e.guard(() async {
            current++;
            if (current > maxConcurrent) maxConcurrent = current;
            counter++;
            await Future<void>.delayed(Duration.zero);
            current--;
          });
        });

        await Future.wait(futures);

        expect(counter, 100);
        expect(maxConcurrent, 1); // Mutex — never > 1
        expect(e.totalAcquires.value, 100);
        expect(e.activeCount.value, 0);
      });

      test('handles 50 concurrent tasks through semaphore(5)', () async {
        final e = Embargo(permits: 5, name: 'stress');
        var maxConcurrent = 0;
        var current = 0;

        final futures = List.generate(50, (i) {
          return e.guard(() async {
            current++;
            if (current > maxConcurrent) maxConcurrent = current;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            current--;
          });
        });

        await Future.wait(futures);

        expect(maxConcurrent, 5);
        expect(e.totalAcquires.value, 50);
        expect(e.activeCount.value, 0);
      });
    });

    group('Pillar integration', () {
      test('embargo() factory creates managed embargo', () {
        final pillar = _TestPillar();
        pillar.initialize();

        expect(pillar.lock.permits, 1);
        expect(pillar.lock.name, 'submit');
        expect(pillar.lock.activeCount.value, 0);
      });

      test('embargo with permits creates semaphore', () {
        final pillar = _TestPillar();
        pillar.initialize();

        expect(pillar.pool.permits, 3);
        expect(pillar.pool.name, 'api');
      });

      test('guard works through Pillar', () async {
        final pillar = _TestPillar();
        pillar.initialize();

        final result = await pillar.lock.guard(() async => 'done');
        expect(result, 'done');
        expect(pillar.lock.totalAcquires.value, 1);
      });
    });
  });
}

class _TestPillar extends Pillar {
  late final lock = embargo(name: 'submit');
  late final pool = embargo(permits: 3, name: 'api');

  @override
  void initialize() {
    lock; // trigger lazy init
    pool;
  }
}
