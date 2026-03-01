import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('TitanState', () {
    test('holds initial value', () {
      final state = TitanState(0);
      expect(state.value, 0);
    });

    test('updates value and notifies listeners', () {
      final state = TitanState(0);
      int notified = 0;
      state.addListener(() => notified++);

      state.value = 1;
      expect(state.value, 1);
      expect(notified, 1);
    });

    test('does not notify when value is the same', () {
      final state = TitanState(42);
      int notified = 0;
      state.addListener(() => notified++);

      state.value = 42;
      expect(notified, 0);
    });

    test('supports custom equality', () {
      final state = TitanState<List<int>>(
        [1, 2, 3],
        equals: (a, b) => a.length == b.length,
      );
      int notified = 0;
      state.addListener(() => notified++);

      // Same length, different values — treated as equal
      state.value = [4, 5, 6];
      expect(notified, 0);

      // Different length — treated as not equal
      state.value = [1, 2];
      expect(notified, 1);
    });

    test('peek returns value without tracking', () {
      final state = TitanState(10);
      final computed = TitanComputed(() => state.peek());

      // Force initial evaluation
      expect(computed.value, 10);

      // Since we used peek(), computed should NOT re-evaluate on change
      state.value = 20;
      // Computed still returns cached 10 since it wasn't notified
      expect(computed.value, 10);
    });

    test('update applies transformation', () {
      final state = TitanState(5);
      state.update((v) => v * 2);
      expect(state.value, 10);
    });

    test('silent sets value without notification', () {
      final state = TitanState(0);
      int notified = 0;
      state.addListener(() => notified++);

      state.silent(99);
      expect(state.peek(), 99);
      expect(notified, 0);
    });

    test('has name for debugging', () {
      final state = TitanState(0, name: 'counter');
      expect(state.name, 'counter');
      expect(state.toString(), contains('counter'));
    });

    test('removeListener stops notifications', () {
      final state = TitanState(0);
      int notified = 0;
      void listener() => notified++;

      state.addListener(listener);
      state.value = 1;
      expect(notified, 1);

      state.removeListener(listener);
      state.value = 2;
      expect(notified, 1); // No more notifications
    });

    test('dispose clears all listeners', () {
      final state = TitanState(0);
      int notified = 0;
      state.addListener(() => notified++);

      state.dispose();
      expect(state.isDisposed, true);
    });
  });
}
