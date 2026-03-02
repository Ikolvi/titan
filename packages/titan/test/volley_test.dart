import 'package:test/test.dart';
import 'package:titan/titan.dart';

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
  });
}
