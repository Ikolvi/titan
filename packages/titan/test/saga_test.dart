import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  setUp(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  tearDown(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  group('Saga', () {
    test('completes all steps in order', () async {
      final order = <String>[];
      final saga = Saga<String>(
        steps: [
          SagaStep(
            name: 'step1',
            execute: (_) async {
              order.add('step1');
              return 'one';
            },
          ),
          SagaStep(
            name: 'step2',
            execute: (prev) async {
              order.add('step2');
              return '${prev}_two';
            },
          ),
          SagaStep(
            name: 'step3',
            execute: (prev) async {
              order.add('step3');
              return '${prev}_three';
            },
          ),
        ],
      );

      final result = await saga.run();
      expect(result, 'one_two_three');
      expect(order, ['step1', 'step2', 'step3']);
      expect(saga.status, SagaStatus.completed);
    });

    test('previous result is passed to next step', () async {
      final saga = Saga<int>(
        steps: [
          SagaStep(name: 'init', execute: (_) async => 10),
          SagaStep(name: 'double', execute: (prev) async => prev! * 2),
          SagaStep(name: 'add5', execute: (prev) async => prev! + 5),
        ],
      );

      final result = await saga.run();
      expect(result, 25); // 10 * 2 + 5
    });

    test('status transitions through running to completed', () async {
      final statuses = <SagaStatus>[];
      final saga = Saga<String>(
        steps: [SagaStep(name: 'step1', execute: (_) async => 'done')],
      );

      // Track status changes
      TitanEffect(() {
        statuses.add(saga.statusCore.value);
      });

      expect(saga.status, SagaStatus.idle);

      await saga.run();

      expect(statuses, contains(SagaStatus.running));
      expect(saga.status, SagaStatus.completed);
    });

    test('compensates completed steps on failure', () async {
      final compensated = <String>[];
      final saga = Saga<String>(
        steps: [
          SagaStep(
            name: 'step1',
            execute: (_) async => 'one',
            compensate: (result) async => compensated.add('undo_$result'),
          ),
          SagaStep(
            name: 'step2',
            execute: (_) async => 'two',
            compensate: (result) async => compensated.add('undo_$result'),
          ),
          SagaStep(
            name: 'step3',
            execute: (_) async => throw Exception('fail!'),
          ),
        ],
      );

      final result = await saga.run();
      expect(result, isNull);
      expect(saga.status, SagaStatus.failed);
      expect(saga.error, isA<Exception>());
      // Compensation happens in reverse order
      expect(compensated, ['undo_two', 'undo_one']);
    });

    test('compensates in reverse order', () async {
      final order = <int>[];
      final saga = Saga<int>(
        steps: [
          SagaStep(
            name: 'a',
            execute: (_) async => 1,
            compensate: (_) async => order.add(1),
          ),
          SagaStep(
            name: 'b',
            execute: (_) async => 2,
            compensate: (_) async => order.add(2),
          ),
          SagaStep(
            name: 'c',
            execute: (_) async => 3,
            compensate: (_) async => order.add(3),
          ),
          SagaStep(name: 'd', execute: (_) async => throw StateError('fail')),
        ],
      );

      await saga.run();
      expect(order, [3, 2, 1]);
    });

    test('tracks currentStep reactively', () async {
      final steps = <int>[];
      final saga = Saga<String>(
        steps: [
          SagaStep(name: 's0', execute: (_) async => 'a'),
          SagaStep(name: 's1', execute: (_) async => 'b'),
          SagaStep(name: 's2', execute: (_) async => 'c'),
        ],
      );

      TitanEffect(() {
        steps.add(saga.currentStepCore.value);
      });

      await saga.run();
      expect(steps, contains(0));
      expect(steps, contains(1));
      expect(steps, contains(2));
    });

    test('progress is reactive', () async {
      final saga = Saga<String>(
        steps: [
          SagaStep(name: 'a', execute: (_) async => ''),
          SagaStep(name: 'b', execute: (_) async => ''),
          SagaStep(name: 'c', execute: (_) async => ''),
          SagaStep(name: 'd', execute: (_) async => ''),
        ],
      );

      expect(saga.progress, 0.0);
      await saga.run();
      expect(saga.progress, 1.0);
    });

    test('throws if already running', () async {
      final saga = Saga<String>(
        steps: [
          SagaStep(
            name: 'slow',
            execute: (_) async {
              await Future<void>.delayed(Duration(milliseconds: 100));
              return 'done';
            },
          ),
        ],
      );

      // Start running
      final future = saga.run();

      // Attempting to run again should throw
      expect(() => saga.run(), throwsStateError);

      await future;
    });

    test('can be reset after completion', () async {
      final saga = Saga<String>(
        steps: [SagaStep(name: 'a', execute: (_) async => 'done')],
      );

      await saga.run();
      expect(saga.status, SagaStatus.completed);

      saga.reset();
      expect(saga.status, SagaStatus.idle);
      expect(saga.currentStep, -1);
      expect(saga.error, isNull);
      expect(saga.result, isNull);
    });

    test('can be reset after failure and re-run', () async {
      var shouldFail = true;
      final saga = Saga<String>(
        steps: [
          SagaStep(
            name: 'maybe-fail',
            execute: (_) async {
              if (shouldFail) throw Exception('fail');
              return 'success';
            },
          ),
        ],
      );

      await saga.run();
      expect(saga.status, SagaStatus.failed);

      saga.reset();
      shouldFail = false;
      final result = await saga.run();
      expect(result, 'success');
      expect(saga.status, SagaStatus.completed);
    });

    test('calls onComplete callback', () async {
      String? completedWith;
      final saga = Saga<String>(
        steps: [SagaStep(name: 'a', execute: (_) async => 'result')],
        onComplete: (result) => completedWith = result,
      );

      await saga.run();
      expect(completedWith, 'result');
    });

    test('calls onError callback', () async {
      Object? caughtError;
      String? failedStep;
      final saga = Saga<String>(
        steps: [
          SagaStep(
            name: 'failing-step',
            execute: (_) async => throw Exception('boom'),
          ),
        ],
        onError: (error, step) {
          caughtError = error;
          failedStep = step;
        },
      );

      await saga.run();
      expect(caughtError, isA<Exception>());
      expect(failedStep, 'failing-step');
    });

    test('calls onStepComplete callback', () async {
      final completed = <(String, int, int)>[];
      final saga = Saga<String>(
        steps: [
          SagaStep(name: 'a', execute: (_) async => 'one'),
          SagaStep(name: 'b', execute: (_) async => 'two'),
        ],
        onStepComplete: (name, idx, total) => completed.add((name, idx, total)),
      );

      await saga.run();
      expect(completed, [('a', 0, 2), ('b', 1, 2)]);
    });

    test('currentStepName returns correct name', () async {
      final saga = Saga<String>(
        steps: [
          SagaStep(name: 'first', execute: (_) async => ''),
          SagaStep(name: 'second', execute: (_) async => ''),
        ],
      );

      expect(saga.currentStepName, isNull);
      await saga.run();
      expect(saga.currentStepName, 'second');
    });

    test('dispose cleans up reactive nodes', () {
      final saga = Saga<String>(
        steps: [SagaStep(name: 'a', execute: (_) async => '')],
      );

      saga.dispose();
      // After dispose, accessing Cores shouldn't work normally
      expect(saga.managedNodes.length, 4);
    });

    test('compensation failure is swallowed', () async {
      final saga = Saga<String>(
        steps: [
          SagaStep(
            name: 'step1',
            execute: (_) async => 'one',
            compensate: (_) async => throw Exception('comp-fail!'),
          ),
          SagaStep(
            name: 'step2',
            execute: (_) async => throw Exception('step-fail!'),
          ),
        ],
      );

      // Should not throw — compensation failure is best-effort
      await saga.run();
      expect(saga.status, SagaStatus.failed);
    });

    test('totalSteps returns step count', () {
      final saga = Saga<void>(
        steps: [
          SagaStep(name: 'a', execute: (_) async {}),
          SagaStep(name: 'b', execute: (_) async {}),
          SagaStep(name: 'c', execute: (_) async {}),
        ],
      );

      expect(saga.totalSteps, 3);
    });

    test('toString shows status and step info', () {
      final saga = Saga<String>(
        steps: [SagaStep(name: 'a', execute: (_) async => '')],
      );

      expect(saga.toString(), contains('Saga'));
      expect(saga.toString(), contains('idle'));
    });

    test('Pillar saga() factory creates managed Saga', () async {
      final pillar = _SagaPillar();
      pillar.initialize();

      final result = await pillar.workflow.run();
      expect(result, 'step1_step2');

      pillar.dispose();
    });
  });
}

class _SagaPillar extends Pillar {
  late final workflow = saga<String>(
    steps: [
      SagaStep(name: 'first', execute: (_) async => 'step1'),
      SagaStep(name: 'second', execute: (prev) async => '${prev}_step2'),
    ],
  );
}
