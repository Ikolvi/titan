import 'package:test/test.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Volley', () {
    test('executes tasks and returns results', () async {
      final volley = Volley<int>();

      final tasks = [
        VolleyTask<int>(name: 'add2', execute: () async => 2),
        VolleyTask<int>(name: 'add3', execute: () async => 3),
        VolleyTask<int>(name: 'add5', execute: () async => 5),
      ];

      final results = await volley.execute(tasks);

      expect(results.length, 3);
      expect(results[0].isSuccess, isTrue);
      expect(results[1].isSuccess, isTrue);
      expect(results[2].isSuccess, isTrue);
      expect((results[0] as VolleySuccess<int>).value, 2);
      expect((results[1] as VolleySuccess<int>).value, 3);
      expect((results[2] as VolleySuccess<int>).value, 5);

      volley.dispose();
    });

    test('handles task failures gracefully', () async {
      final volley = Volley<int>();

      final tasks = [
        VolleyTask<int>(name: 'ok', execute: () async => 1),
        VolleyTask<int>(
          name: 'fail',
          execute: () async => throw Exception('boom'),
        ),
        VolleyTask<int>(name: 'ok2', execute: () async => 3),
      ];

      final results = await volley.execute(tasks);

      expect(results.length, 3);
      expect(results[0].isSuccess, isTrue);
      expect(results[1].isFailure, isTrue);
      expect(results[2].isSuccess, isTrue);

      expect(results[1].errorOrNull, isA<Exception>());
      expect(results[0].valueOrNull, 1);
      expect(results[2].valueOrNull, 3);

      volley.dispose();
    });

    test('respects concurrency limit', () async {
      var concurrent = 0;
      var maxConcurrent = 0;

      final volley = Volley<int>(concurrency: 2);

      final tasks = List.generate(
        6,
        (i) => VolleyTask<int>(
          name: 'task$i',
          execute: () async {
            concurrent++;
            if (concurrent > maxConcurrent) maxConcurrent = concurrent;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            concurrent--;
            return i;
          },
        ),
      );

      await volley.execute(tasks);

      expect(maxConcurrent, lessThanOrEqualTo(2));

      volley.dispose();
    });

    test('tracks progress reactively', () async {
      final volley = Volley<int>(concurrency: 1);

      final tasks = [
        VolleyTask<int>(
          name: 'a',
          execute: () async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return 1;
          },
        ),
        VolleyTask<int>(
          name: 'b',
          execute: () async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return 2;
          },
        ),
      ];

      await volley.execute(tasks);

      expect(volley.progress, 1.0);
      expect(volley.status, VolleyStatus.done);
      expect(volley.completedCount, 2);
      expect(volley.totalCount, 2);

      volley.dispose();
    });

    test('can cancel running tasks', () async {
      final volley = Volley<int>(concurrency: 1);

      final tasks = List.generate(
        10,
        (i) => VolleyTask<int>(
          name: 'task$i',
          execute: () async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return i;
          },
        ),
      );

      final future = volley.execute(tasks);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      volley.cancel();

      final results = await future;

      final failures = results.where((r) => r.isFailure).toList();
      expect(failures, isNotEmpty);
      expect(volley.status, VolleyStatus.cancelled);

      volley.dispose();
    });

    test('reset clears state', () async {
      final volley = Volley<int>();

      final tasks = [VolleyTask<int>(name: 'a', execute: () async => 1)];

      await volley.execute(tasks);
      expect(volley.status, VolleyStatus.done);

      volley.reset();
      expect(volley.status, VolleyStatus.idle);
      expect(volley.progress, 0.0);
      expect(volley.completedCount, 0);
      expect(volley.successCount, 0);
      expect(volley.failedCount, 0);
      expect(volley.totalCount, 0);

      volley.dispose();
    });

    test('VolleyResult sealed class properties', () {
      final success = VolleySuccess<int>(taskName: 'test', value: 42);
      expect(success.isSuccess, isTrue);
      expect(success.isFailure, isFalse);
      expect(success.valueOrNull, 42);
      expect(success.errorOrNull, isNull);

      final failure = VolleyFailure<int>(
        taskName: 'test',
        error: Exception('err'),
        stackTrace: StackTrace.current,
      );
      expect(failure.isSuccess, isFalse);
      expect(failure.isFailure, isTrue);
      expect(failure.valueOrNull, isNull);
      expect(failure.errorOrNull, isA<Exception>());
    });

    test('empty task list returns empty results', () async {
      final volley = Volley<int>();

      final results = await volley.execute([]);
      expect(results, isEmpty);
      expect(volley.status, VolleyStatus.done);

      volley.dispose();
    });

    test('concurrency with single worker', () async {
      final volley = Volley<String>(concurrency: 1);

      final order = <int>[];
      final tasks = List.generate(
        3,
        (i) => VolleyTask<String>(
          name: 'task$i',
          execute: () async {
            order.add(i);
            return 'result$i';
          },
        ),
      );

      final results = await volley.execute(tasks);

      expect(results.length, 3);
      expect(order, [0, 1, 2]);

      volley.dispose();
    });

    test('managedNodes returns reactive cores', () {
      final volley = Volley<int>();

      final nodes = volley.managedNodes;
      expect(nodes, isNotEmpty);
      expect(nodes.length, 4);

      volley.dispose();
    });

    // ---- New tests below ----

    test('separates successCount and failedCount', () async {
      final volley = Volley<int>();

      final tasks = [
        VolleyTask<int>(name: 'ok', execute: () async => 1),
        VolleyTask<int>(
          name: 'fail',
          execute: () async => throw Exception('err'),
        ),
        VolleyTask<int>(name: 'ok2', execute: () async => 3),
      ];

      await volley.execute(tasks);

      expect(volley.successCount, 2);
      expect(volley.failedCount, 1);
      expect(volley.completedCount, 3);

      volley.dispose();
    });

    test('retries failed tasks', () async {
      var attempts = 0;

      final volley = Volley<int>(
        maxRetries: 2,
        retryDelay: const Duration(milliseconds: 10),
      );

      final tasks = [
        VolleyTask<int>(
          name: 'flaky',
          execute: () async {
            attempts++;
            if (attempts < 3) throw Exception('not yet');
            return 42;
          },
        ),
      ];

      final results = await volley.execute(tasks);

      expect(results[0].isSuccess, isTrue);
      expect(results[0].valueOrNull, 42);
      expect(attempts, 3);
      expect(volley.successCount, 1);

      volley.dispose();
    });

    test('retries exhaust and fail', () async {
      var attempts = 0;

      final volley = Volley<int>(
        maxRetries: 1,
        retryDelay: const Duration(milliseconds: 10),
      );

      final tasks = [
        VolleyTask<int>(
          name: 'alwaysFails',
          execute: () async {
            attempts++;
            throw Exception('boom');
          },
        ),
      ];

      final results = await volley.execute(tasks);

      expect(results[0].isFailure, isTrue);
      expect(attempts, 2); // 1 original + 1 retry
      expect(volley.failedCount, 1);

      volley.dispose();
    });

    test('per-task timeout', () async {
      final volley = Volley<int>();

      final tasks = [
        VolleyTask<int>(
          name: 'slow',
          timeout: const Duration(milliseconds: 10),
          execute: () async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return 1;
          },
        ),
      ];

      final results = await volley.execute(tasks);

      expect(results[0].isFailure, isTrue);
      expect(volley.failedCount, 1);

      volley.dispose();
    });

    test('global taskTimeout', () async {
      final volley = Volley<int>(taskTimeout: const Duration(milliseconds: 10));

      final tasks = [
        VolleyTask<int>(
          name: 'slow',
          execute: () async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return 1;
          },
        ),
      ];

      final results = await volley.execute(tasks);

      expect(results[0].isFailure, isTrue);

      volley.dispose();
    });

    test('per-task timeout overrides global', () async {
      final volley = Volley<int>(taskTimeout: const Duration(milliseconds: 10));

      final tasks = [
        VolleyTask<int>(
          name: 'withOverride',
          timeout: const Duration(seconds: 5),
          execute: () async => 42,
        ),
      ];

      final results = await volley.execute(tasks);

      expect(results[0].isSuccess, isTrue);

      volley.dispose();
    });

    test('onTaskComplete callback fires', () async {
      final completed = <String>[];

      final volley = Volley<int>(
        onTaskComplete: (name, result) => completed.add('$name:$result'),
      );

      final tasks = [
        VolleyTask<int>(name: 'a', execute: () async => 1),
        VolleyTask<int>(name: 'b', execute: () async => 2),
      ];

      await volley.execute(tasks);

      expect(completed, containsAll(['a:1', 'b:2']));

      volley.dispose();
    });

    test('onTaskFailed callback fires', () async {
      final failures = <String>[];

      final volley = Volley<int>(
        onTaskFailed: (name, error) => failures.add(name),
      );

      final tasks = [
        VolleyTask<int>(
          name: 'fail1',
          execute: () async => throw Exception('err'),
        ),
      ];

      await volley.execute(tasks);

      expect(failures, ['fail1']);

      volley.dispose();
    });

    test('throws when executed while running', () async {
      final volley = Volley<int>(concurrency: 1);

      final tasks = [
        VolleyTask<int>(
          name: 'slow',
          execute: () async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return 1;
          },
        ),
      ];

      final future = volley.execute(tasks);

      expect(() => volley.execute(tasks), throwsA(isA<StateError>()));

      await future;
      volley.dispose();
    });

    test('throws when using disposed Volley', () {
      final volley = Volley<int>();
      volley.dispose();

      expect(volley.isDisposed, isTrue);
      expect(() => volley.execute([]), throwsA(isA<StateError>()));
      expect(() => volley.reset(), throwsA(isA<StateError>()));
    });

    test('dispose is idempotent', () {
      final volley = Volley<int>();
      volley.dispose();
      volley.dispose(); // no throw
      expect(volley.isDisposed, isTrue);
    });

    test('toString reflects state', () async {
      final volley = Volley<int>();
      expect(volley.toString(), contains('idle'));

      await volley.execute([
        VolleyTask<int>(name: 'a', execute: () async => 1),
      ]);
      expect(volley.toString(), contains('success: 1'));

      volley.dispose();
    });

    test('VolleyResult toString formats correctly', () {
      final success = VolleySuccess<int>(taskName: 'test', value: 42);
      expect(success.toString(), contains('test'));
      expect(success.toString(), contains('42'));

      final failure = VolleyFailure<int>(
        taskName: 'bad',
        error: Exception('err'),
        stackTrace: StackTrace.current,
      );
      expect(failure.toString(), contains('bad'));
    });

    test('VolleyTask timeout property', () {
      final task = VolleyTask<int>(
        name: 'test',
        execute: () async => 1,
        timeout: const Duration(seconds: 5),
      );
      expect(task.timeout, const Duration(seconds: 5));
      expect(task.name, 'test');
    });

    test('retry with timeout combination', () async {
      var attempts = 0;

      final volley = Volley<int>(
        maxRetries: 2,
        retryDelay: const Duration(milliseconds: 10),
      );

      final tasks = [
        VolleyTask<int>(
          name: 'retryTimeout',
          timeout: const Duration(milliseconds: 5),
          execute: () async {
            attempts++;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return 1;
          },
        ),
      ];

      final results = await volley.execute(tasks);

      expect(results[0].isFailure, isTrue);
      expect(attempts, 3); // original + 2 retries, all timeout

      volley.dispose();
    });

    test('mixed success and failure with retries', () async {
      var failAttempts = 0;

      final volley = Volley<String>(
        concurrency: 2,
        maxRetries: 1,
        retryDelay: const Duration(milliseconds: 10),
      );

      final tasks = [
        VolleyTask<String>(name: 'ok', execute: () async => 'pass'),
        VolleyTask<String>(
          name: 'flaky',
          execute: () async {
            failAttempts++;
            if (failAttempts == 1) throw Exception('first try');
            return 'recovered';
          },
        ),
      ];

      final results = await volley.execute(tasks);

      expect(results[0].isSuccess, isTrue);
      expect(results[1].isSuccess, isTrue);
      expect(results[1].valueOrNull, 'recovered');

      volley.dispose();
    });

    test('can run execute multiple times after completion', () async {
      final volley = Volley<int>();

      final r1 = await volley.execute([
        VolleyTask<int>(name: 'a', execute: () async => 1),
      ]);
      expect(r1[0].valueOrNull, 1);

      final r2 = await volley.execute([
        VolleyTask<int>(name: 'b', execute: () async => 2),
      ]);
      expect(r2[0].valueOrNull, 2);

      volley.dispose();
    });
  });
}
