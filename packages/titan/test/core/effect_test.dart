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
      final effect = TitanEffect(
        () => runs++,
        fireImmediately: false,
      );

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
  });
}
