import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('TitanEffect', () {
    test('fires immediately by default', () {
      int runs = 0;
      final effect = TitanEffect(() => runs++);

      expect(runs, 1);
      effect.dispose();
    });

    test('does not fire immediately when configured', () {
      int runs = 0;
      final effect = TitanEffect(() => runs++, fireImmediately: false);

      expect(runs, 0);
      effect.dispose();
    });

    test('re-runs when dependencies change', () {
      final state = TitanState(0);
      final values = <int>[];

      final effect = TitanEffect(() {
        values.add(state.value);
      });

      expect(values, [0]); // Initial run

      state.value = 1;
      expect(values, [0, 1]);

      state.value = 2;
      expect(values, [0, 1, 2]);

      effect.dispose();
    });

    test('tracks dynamic dependencies', () {
      final useA = TitanState(true);
      final a = TitanState('A');
      final b = TitanState('B');
      final values = <String>[];

      final effect = TitanEffect(() {
        values.add(useA.value ? a.value : b.value);
      });

      expect(values, ['A']);

      // Change a — effect should re-run
      a.value = 'A2';
      expect(values, ['A', 'A2']);

      // Switch to b
      useA.value = false;
      expect(values, ['A', 'A2', 'B']);

      // Change a — effect should NOT re-run (not tracking a anymore)
      a.value = 'A3';
      expect(values, ['A', 'A2', 'B']);

      // Change b — effect should re-run
      b.value = 'B2';
      expect(values, ['A', 'A2', 'B', 'B2']);

      effect.dispose();
    });

    test('calls cleanup function', () {
      int cleanupCalls = 0;
      final state = TitanState(0);

      final effect = TitanEffect(() {
        state.value; // Track dependency
        return () => cleanupCalls++;
      });

      expect(cleanupCalls, 0);

      state.value = 1; // Re-run triggers cleanup
      expect(cleanupCalls, 1);

      effect.dispose(); // Dispose triggers cleanup
      expect(cleanupCalls, 2);
    });

    test('can be manually run', () {
      int runs = 0;
      final effect = TitanEffect(() => runs++, fireImmediately: false);

      expect(runs, 0);
      effect.run();
      expect(runs, 1);

      effect.dispose();
    });

    test('uses onNotify callback when provided', () {
      final state = TitanState(0);
      int notifyCalls = 0;

      final effect = TitanEffect(
        () => state.value,
        onNotify: () => notifyCalls++,
      );

      state.value = 1;
      expect(notifyCalls, 1);

      effect.dispose();
    });

    test('disposes cleanly', () {
      final state = TitanState(0);
      final values = <int>[];

      final effect = TitanEffect(() {
        values.add(state.value);
      });

      effect.dispose();

      state.value = 1;
      expect(values, [0]); // No more runs after dispose
    });

    test('dependency diff removes stale deps', () {
      final useA = TitanState(true);
      final a = TitanState('A');
      final b = TitanState('B');
      final values = <String>[];

      final effect = TitanEffect(() {
        values.add(useA.value ? a.value : b.value);
      });

      expect(values, ['A']);

      // Switch to b
      useA.value = false;
      expect(values, ['A', 'B']);

      // Changing a should NOT re-run (stale dep removed by diffing)
      a.value = 'A2';
      expect(values, ['A', 'B']); // Still only 2 entries

      // Changing b should re-run
      b.value = 'B2';
      expect(values, ['A', 'B', 'B2']);

      effect.dispose();
      useA.dispose();
      a.dispose();
      b.dispose();
    });

    test('does not recursively re-execute', () {
      final state = TitanState(0);
      int runs = 0;

      final effect = TitanEffect(() {
        runs++;
        if (runs < 5) {
          // This would cause infinite recursion without the guard
          state.value = state.peek() + 1;
        }
      });

      // Initial run (runs=1), triggers state change,
      // but _isRunning prevents re-entry
      expect(runs, 1);

      effect.dispose();
      state.dispose();
    });

    test('execute is no-op after dispose', () {
      int runs = 0;
      final effect = TitanEffect(() => runs++, fireImmediately: false);

      effect.dispose();
      effect.run(); // Should be ignored
      expect(runs, 0);
    });

    test('onDependencyChanged is no-op when disposed', () {
      final state = TitanState(0);
      int runs = 0;

      final effect = TitanEffect(() {
        state.value;
        runs++;
      });

      expect(runs, 1);
      effect.dispose();

      // State change after disposal should not re-run effect
      state.value = 1;
      expect(runs, 1);

      state.dispose();
    });

    test('has name and toString', () {
      final effect = TitanEffect(() {}, name: 'myEffect');
      expect(effect.name, 'myEffect');
      expect(effect.toString(), contains('myEffect'));
      effect.dispose();
    });
  });
}
