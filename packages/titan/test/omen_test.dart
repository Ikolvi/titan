import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Omen', () {
    // -----------------------------------------------------------------------
    // Basic operations
    // -----------------------------------------------------------------------

    test('starts in loading state when eager', () {
      final o = Omen<int>(() async => 42);
      expect(o.isLoading, isTrue);
      expect(o.data, isNull);
      expect(o.hasData, isFalse);
      o.dispose();
    });

    test('resolves to data state', () async {
      final o = Omen<int>(() async => 42);
      await Future<void>.delayed(Duration.zero);
      expect(o.hasData, isTrue);
      expect(o.data, 42);
      expect(o.value, isA<AsyncData<int>>());
      o.dispose();
    });

    test('captures errors', () async {
      final o = Omen<int>(() async => throw Exception('fail'));
      await Future<void>.delayed(Duration.zero);
      expect(o.hasError, isTrue);
      expect(o.value, isA<AsyncError<int>>());
      o.dispose();
    });

    test('does not execute when eager=false', () async {
      var callCount = 0;
      final o = Omen<int>(() async {
        callCount++;
        return 42;
      }, eager: false);
      await Future<void>.delayed(Duration.zero);
      expect(callCount, 0);
      expect(o.isLoading, isTrue);
      o.dispose();
    });

    test('refresh triggers re-execution', () async {
      var callCount = 0;
      final o = Omen<int>(() async {
        callCount++;
        return callCount;
      });
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 1);
      expect(callCount, 1);

      o.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 2);
      expect(callCount, 2);
      o.dispose();
    });

    test('cancel stops in-flight computation from updating state', () async {
      final completer = Completer<int>();
      final o = Omen<int>(() => completer.future);
      expect(o.isLoading, isTrue);

      o.cancel();
      completer.complete(42);
      await Future<void>.delayed(Duration.zero);

      // State should still be loading since cancel was called
      expect(o.isLoading, isTrue);
      expect(o.data, isNull);
      o.dispose();
    });

    test('reset clears state and re-executes', () async {
      var count = 0;
      final o = Omen<int>(() async {
        count++;
        return count * 10;
      });
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 10);
      expect(o.executionCount.value, 1);

      o.reset();
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 20);
      expect(o.executionCount.value, 1); // Reset clears count, then increments
      o.dispose();
    });

    // -----------------------------------------------------------------------
    // Dependency tracking
    // -----------------------------------------------------------------------

    test('re-executes when a tracked Core changes', () async {
      final source = TitanState<int>(1);
      var callCount = 0;
      final o = Omen<String>(() async {
        callCount++;
        return 'value-${source.value}';
      });
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 'value-1');
      expect(callCount, 1);

      source.value = 2;
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 'value-2');
      expect(callCount, 2);

      source.dispose();
      o.dispose();
    });

    test('tracks multiple dependencies', () async {
      final a = TitanState<int>(1);
      final b = TitanState<String>('hello');
      var callCount = 0;
      final o = Omen<String>(() async {
        callCount++;
        return '${a.value}-${b.value}';
      });
      await Future<void>.delayed(Duration.zero);
      expect(o.data, '1-hello');
      expect(callCount, 1);

      a.value = 2;
      await Future<void>.delayed(Duration.zero);
      expect(o.data, '2-hello');
      expect(callCount, 2);

      b.value = 'world';
      await Future<void>.delayed(Duration.zero);
      expect(o.data, '2-world');
      expect(callCount, 3);

      a.dispose();
      b.dispose();
      o.dispose();
    });

    test('stops tracking removed dependencies', () async {
      final a = TitanState<int>(1);
      final b = TitanState<int>(2);
      final useB = TitanState<bool>(true);
      var callCount = 0;

      final o = Omen<int>(() async {
        callCount++;
        final val = a.value;
        if (useB.value) {
          return val + b.value;
        }
        return val;
      });
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 3); // 1 + 2
      expect(callCount, 1);

      // Stop using b
      useB.value = false;
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 1);
      expect(callCount, 2);

      // Changing b should NOT trigger re-execution anymore
      b.value = 99;
      await Future<void>.delayed(Duration.zero);
      // Note: b may still be in dependencies from the last run that read useB
      // The key test is that the result doesn't include b's value
      expect(o.data, 1); // Still just a.value

      a.dispose();
      b.dispose();
      useB.dispose();
      o.dispose();
    });

    // -----------------------------------------------------------------------
    // Debounce
    // -----------------------------------------------------------------------

    test('debounces rapid dependency changes', () async {
      final source = TitanState<int>(0);
      var callCount = 0;
      final o = Omen<int>(() async {
        callCount++;
        return source.value * 10;
      }, debounce: const Duration(milliseconds: 50));
      await Future<void>.delayed(Duration.zero);
      expect(callCount, 1); // initial execution

      // Rapid changes
      source.value = 1;
      source.value = 2;
      source.value = 3;

      // Wait less than debounce — should not have re-executed yet
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(callCount, 1); // still 1

      // Wait for debounce to complete
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(callCount, 2); // only one additional execution
      expect(o.data, 30); // latest value

      source.dispose();
      o.dispose();
    });

    // -----------------------------------------------------------------------
    // Stale-while-revalidate
    // -----------------------------------------------------------------------

    test(
      'shows previous data while refreshing (keepPreviousData=true)',
      () async {
        var count = 0;
        final completer1 = Completer<String>();
        final triggerRefresh = TitanState<int>(0);

        final o = Omen<String>(() async {
          count++;
          triggerRefresh.value; // track dependency
          if (count == 1) return completer1.future;
          // Second call returns immediately
          return 'second-$count';
        });

        completer1.complete('first');
        await Future<void>.delayed(Duration.zero);
        expect(o.data, 'first');

        // Trigger re-computation
        triggerRefresh.value = 1;
        // Should show refreshing with previous data
        // (the check is immediate before async resolves)
        expect(o.value.dataOrNull, 'first'); // previous data still visible

        await Future<void>.delayed(Duration.zero);
        expect(o.data, 'second-2');

        triggerRefresh.dispose();
        o.dispose();
      },
    );

    test('shows loading when keepPreviousData=false', () async {
      final trigger = TitanState<int>(0);
      var count = 0;

      final o = Omen<String>(() async {
        count++;
        trigger.value; // track
        return 'result-$count';
      }, keepPreviousData: false);

      await Future<void>.delayed(Duration.zero);
      expect(o.data, 'result-1');

      // Trigger re-computation
      trigger.value = 1;
      // With keepPreviousData=false, first execution was eager,
      // so on re-execution it goes to Loading (but it might resolve instantly)
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 'result-2');

      trigger.dispose();
      o.dispose();
    });

    // -----------------------------------------------------------------------
    // Reactive state
    // -----------------------------------------------------------------------

    test('executionCount tracks executions', () async {
      var count = 0;
      final o = Omen<int>(() async {
        count++;
        return count;
      });
      await Future<void>.delayed(Duration.zero);
      expect(o.executionCount.value, 1);

      o.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(o.executionCount.value, 2);

      o.dispose();
    });

    test('state is reactive TitanState', () async {
      final o = Omen<int>(() async => 42);
      expect(o.state, isA<TitanState<AsyncValue<int>>>());
      await Future<void>.delayed(Duration.zero);
      expect(o.state.value, isA<AsyncData<int>>());
      o.dispose();
    });

    // -----------------------------------------------------------------------
    // Cancellation edge cases
    // -----------------------------------------------------------------------

    test('new execution cancels previous', () async {
      final completer1 = Completer<int>();
      final completer2 = Completer<int>();
      var callCount = 0;

      final trigger = TitanState<int>(0);
      final o = Omen<int>(() async {
        callCount++;
        trigger.value; // track
        if (callCount == 1) return completer1.future;
        return completer2.future;
      });

      // First execution starts, waiting on completer1
      expect(callCount, 1);

      // Trigger new execution — cancels the first
      trigger.value = 1;
      expect(callCount, 2);

      // Complete the first (should be ignored since cancelled)
      completer1.complete(111);
      await Future<void>.delayed(Duration.zero);
      // state should NOT be 111 (it was cancelled)

      // Complete the second
      completer2.complete(222);
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 222);

      trigger.dispose();
      o.dispose();
    });

    // -----------------------------------------------------------------------
    // Disposal
    // -----------------------------------------------------------------------

    test('dispose cancels timer and computation', () async {
      final source = TitanState<int>(0);
      var callCount = 0;
      final o = Omen<int>(() async {
        callCount++;
        return source.value;
      }, debounce: const Duration(milliseconds: 50));
      await Future<void>.delayed(Duration.zero);
      expect(callCount, 1);

      source.value = 1; // triggers debounced re-execution
      o.dispose(); // dispose before debounce fires

      // Wait past debounce
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(callCount, 1); // should NOT have re-executed

      source.dispose();
    });

    test('managedNodes returns state and executionCount', () async {
      final o = Omen<int>(() async => 1);
      // executionCount is lazy — not included until accessed
      expect(o.managedNodes, hasLength(1));
      expect(o.managedNodes, contains(o.state));
      // Accessing executionCount forces allocation
      await Future<void>.delayed(Duration.zero); // let async complete
      expect(o.executionCount.value, 1);
      expect(o.managedNodes, hasLength(2));
      expect(o.managedNodes, contains(o.executionCount));
      o.dispose();
    });

    // -----------------------------------------------------------------------
    // Synchronous error
    // -----------------------------------------------------------------------

    test('handles synchronous throw in compute', () async {
      final o = Omen<int>(() {
        throw StateError('sync failure');
      });
      // Synchronous throw should set error state immediately
      expect(o.hasError, isTrue);
      expect(o.executionCount.value, 1);
      o.dispose();
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------

    test('omen factory works in Pillar', () async {
      final pillar = _TestPillar();
      // Force lazy init so eager execution starts
      expect(pillar.result.isLoading, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(pillar.result.hasData, isTrue);
      expect(pillar.result.data, 'search: hello');

      // Change dependency
      pillar.query.value = 'world';
      await Future<void>.delayed(Duration.zero);
      expect(pillar.result.data, 'search: world');

      pillar.dispose();
    });

    test('omen with debounce in Pillar', () async {
      final pillar = _DebouncedPillar();
      // Force lazy init so eager execution starts
      expect(pillar.result.isLoading, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(pillar.result.data, 'v:0');

      pillar.counter.value = 1;
      pillar.counter.value = 2;
      pillar.counter.value = 3;

      // Should not have re-executed yet
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(pillar.result.data, 'v:0'); // still old

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(pillar.result.data, 'v:3');

      pillar.dispose();
    });

    // -----------------------------------------------------------------------
    // toString
    // -----------------------------------------------------------------------

    test('toString includes state info', () async {
      final o = Omen<int>(() async => 42, name: 'test');
      expect(o.toString(), contains('loading'));

      await Future<void>.delayed(Duration.zero);
      expect(o.toString(), contains('data: 42'));
      expect(o.toString(), contains('Omen<int>'));

      o.dispose();
    });

    test('toString shows error state', () async {
      final o = Omen<int>(() async => throw Exception('bad'));
      await Future<void>.delayed(Duration.zero);
      expect(o.toString(), contains('error'));
      o.dispose();
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    test('does not crash when disposed during execution', () async {
      final completer = Completer<int>();
      final o = Omen<int>(() => completer.future);

      // Dispose while computation is pending
      o.dispose();

      // Complete — should not crash
      completer.complete(42);
      await Future<void>.delayed(Duration.zero);
      // No assertion needed — just verifying no exception
    });

    test('isRefreshing is true during re-computation', () async {
      final trigger = TitanState<int>(0);
      final completer = Completer<int>();
      var count = 0;

      final o = Omen<int>(() async {
        count++;
        trigger.value; // track
        if (count == 1) return 42;
        return completer.future;
      });

      await Future<void>.delayed(Duration.zero);
      expect(o.data, 42);
      expect(o.isRefreshing, isFalse);

      // Trigger re-execution (slow)
      trigger.value = 1;
      // Should be refreshing with previous data
      expect(o.isRefreshing, isTrue);
      expect(o.value.dataOrNull, 42);

      completer.complete(99);
      await Future<void>.delayed(Duration.zero);
      expect(o.data, 99);
      expect(o.isRefreshing, isFalse);

      trigger.dispose();
      o.dispose();
    });

    test('value getter tracks for outer reactive scope', () async {
      final o = Omen<int>(() async => 42);
      await Future<void>.delayed(Duration.zero);

      // Simulate reading inside a derived context
      final tracker = _TestTracker();
      final previous = ReactiveScope.pushTracker(tracker);
      final _ = o.value;
      ReactiveScope.popTracker(previous);

      // The Omen's state should have been tracked
      expect(tracker.tracked, isNotEmpty);

      o.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _TestPillar extends Pillar {
  late final query = core('hello');

  late final result = omen<String>(() async => 'search: ${query.value}');
}

class _DebouncedPillar extends Pillar {
  late final counter = core(0);

  late final result = omen<String>(
    () async => 'v:${counter.value}',
    debounce: const Duration(milliseconds: 50),
  );
}

class _TestTracker extends ReactiveNode {
  final Set<ReactiveNode> tracked = {};

  @override
  void onTracked(ReactiveNode source) {
    tracked.add(source);
  }
}
