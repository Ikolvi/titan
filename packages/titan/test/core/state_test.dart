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
      final state = TitanState<List<int>>([
        1,
        2,
        3,
      ], equals: (a, b) => a.length == b.length);
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

    test('listen returns unsubscribe function', () {
      final state = TitanState(0);
      final values = <int>[];

      final cancel = state.listen((v) => values.add(v));
      state.value = 1;
      state.value = 2;
      expect(values, [1, 2]);

      cancel();
      state.value = 3;
      expect(values, [1, 2]); // No more notifications

      state.dispose();
    });

    test('setting value after dispose does not notify', () {
      final state = TitanState(0);
      int notified = 0;
      state.addListener(() => notified++);

      state.dispose();
      // Setting value on disposed state - should be safe
      state.value = 99;
      expect(notified, 0);
    });

    test('addListener during notification is safe (copy-on-write)', () {
      final state = TitanState(0);
      int secondListenerCalls = 0;

      state.addListener(() {
        // Add a new listener while notifying
        state.addListener(() => secondListenerCalls++);
      });

      state.value = 1; // First listener fires, adds second
      expect(secondListenerCalls, 0); // Second not called during this cycle

      state.value = 2; // Now both fire
      expect(secondListenerCalls, 1);

      state.dispose();
    });

    test('removeListener during notification is safe (copy-on-write)', () {
      final state = TitanState(0);
      int calls = 0;
      late void Function() listener2;

      state.addListener(() {
        calls++;
        state.removeListener(listener2);
      });
      listener2 = () => calls++;
      state.addListener(listener2);

      state.value = 1;
      // Both listeners fire during this notification (snapshot taken before removal)
      expect(calls, 2);

      // Now listener2 is removed
      state.value = 2;
      expect(calls, 3); // Only first listener fires

      state.dispose();
    });

    test('notifies TitanObserver on value change', () {
      final changes = <(dynamic, dynamic)>[];
      TitanObserver.instance = _TestObserver(
        onChanged: (_, oldVal, newVal) => changes.add((oldVal, newVal)),
      );

      final state = TitanState(0);
      state.value = 1;
      state.value = 2;

      expect(changes, [(0, 1), (1, 2)]);

      state.dispose();
      TitanObserver.instance = null;
    });

    test('toString without name shows type and value', () {
      final state = TitanState(42);
      expect(state.toString(), contains('42'));
      state.dispose();
    });

    test('select creates a computed that tracks sub-value', () {
      final state = TitanState<Map<String, int>>({'a': 1, 'b': 2});
      final selected = state.select((m) => m['a']!);

      expect(selected.value, 1);

      // Change the selected value
      state.value = {'a': 10, 'b': 2};
      expect(selected.value, 10);

      state.dispose();
      selected.dispose();
    });

    test('select only triggers when selected sub-value changes', () {
      final state = TitanState<Map<String, int>>({'a': 1, 'b': 2});
      final selected = state.select((m) => m['a']!);

      // Access value first to establish dependency tracking
      expect(selected.value, 1);

      int notifications = 0;
      selected.addListener(() => notifications++);

      // Change only 'b' — 'a' stays the same, but computed re-evaluates
      // and sees same result, so no notification
      state.value = {'a': 1, 'b': 99};
      expect(notifications, 0);

      // Change 'a' — should notify
      state.value = {'a': 5, 'b': 99};
      expect(notifications, 1);
      expect(selected.value, 5);

      state.dispose();
      selected.dispose();
    });
  });
}

class _TestObserver extends TitanObserver {
  final void Function(TitanState state, dynamic oldValue, dynamic newValue)
  onChanged;

  _TestObserver({required this.onChanged});

  @override
  void onStateChanged({
    required TitanState state,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    onChanged(state, oldValue, newValue);
  }
}
