import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('TitanComputed', () {
    test('computes initial value lazily', () {
      int computeCount = 0;
      final a = TitanState(2);
      final computed = TitanComputed(() {
        computeCount++;
        return a.value * 3;
      });

      expect(computeCount, 0); // Not computed yet
      expect(computed.value, 6);
      expect(computeCount, 1);
    });

    test('caches value and recomputes on dependency change', () {
      int computeCount = 0;
      final a = TitanState(1);
      final computed = TitanComputed(() {
        computeCount++;
        return a.value * 10;
      });

      expect(computed.value, 10);
      expect(computeCount, 1);

      // Same access should use cache
      expect(computed.value, 10);
      expect(computeCount, 1);

      // Change dependency
      a.value = 2;
      expect(computed.value, 20);
      expect(computeCount, 2);
    });

    test('tracks multiple dependencies', () {
      final a = TitanState(1);
      final b = TitanState(2);
      final sum = TitanComputed(() => a.value + b.value);

      expect(sum.value, 3);

      a.value = 10;
      expect(sum.value, 12);

      b.value = 20;
      expect(sum.value, 30);
    });

    test('chains computeds', () {
      final base = TitanState(5);
      final doubled = TitanComputed(() => base.value * 2);
      final quadrupled = TitanComputed(() => doubled.value * 2);

      expect(quadrupled.value, 20);

      base.value = 10;
      expect(doubled.value, 20);
      expect(quadrupled.value, 40);
    });

    test('only propagates when value actually changes', () {
      final a = TitanState(3);
      final isPositive = TitanComputed(() => a.value > 0);

      int changes = 0;
      isPositive.addListener(() => changes++);

      // Force initial evaluation
      isPositive.value;

      // Change a but isPositive stays true
      a.value = 5;
      expect(isPositive.value, true);
      expect(changes, 0);

      // Change a to negative — isPositive changes to false
      a.value = -1;
      expect(isPositive.value, false);
      expect(changes, 1);
    });

    test('peek returns value without tracking', () {
      final a = TitanState(10);
      final computed = TitanComputed(() => a.value * 2);

      expect(computed.peek(), 20);
    });

    test('disposes cleanly', () {
      final a = TitanState(1);
      final computed = TitanComputed(() => a.value * 2);

      expect(computed.value, 2);
      computed.dispose();
      expect(computed.isDisposed, true);
    });

    test('has name for debugging', () {
      final computed = TitanComputed(() => 42, name: 'answer');
      expect(computed.name, 'answer');
      expect(computed.toString(), contains('answer'));
    });

    test('dependency diff removes stale deps after recompute', () {
      final useA = TitanState(true);
      final a = TitanState(10);
      final b = TitanState(20);

      final computed = TitanComputed(() {
        return useA.value ? a.value : b.value;
      });

      expect(computed.value, 10); // Depends on useA, a

      // Switch to b
      useA.value = false;
      expect(computed.value, 20); // Now depends on useA, b

      // Changing a should NOT trigger recompute (stale dep removed)
      int changes = 0;
      computed.addListener(() => changes++);
      a.value = 99;
      expect(changes, 0);
      expect(computed.value, 20); // Still 20

      // Changing b should trigger recompute
      b.value = 30;
      expect(computed.value, 30);

      computed.dispose();
      useA.dispose();
      a.dispose();
      b.dispose();
    });

    test('dependency diff adds new deps when computation changes', () {
      final flag = TitanState(false);
      final extra = TitanState(100);

      final computed = TitanComputed(() {
        if (flag.value) {
          return extra.value;
        }
        return 0;
      });

      expect(computed.value, 0); // Only depends on flag

      // extra shouldn't trigger recompute yet
      int changes = 0;
      computed.addListener(() => changes++);
      extra.value = 200;
      expect(changes, 0);

      // Now switch — extra becomes a dependency
      flag.value = true;
      expect(computed.value, 200);

      // extra should now trigger recompute
      extra.value = 300;
      expect(computed.value, 300);

      computed.dispose();
      flag.dispose();
      extra.dispose();
    });

    test('diamond dependency only recomputes once per batch', () {
      final source = TitanState(1);
      final left = TitanComputed(() => source.value * 2);
      final right = TitanComputed(() => source.value * 3);
      final bottom = TitanComputed(() => left.value + right.value);

      expect(bottom.value, 5); // 2 + 3

      int recomputeCount = 0;
      bottom.addListener(() => recomputeCount++);

      titanBatch(() {
        source.value = 10;
      });

      expect(bottom.value, 50); // 20 + 30
      // Notified once per parent (left & right) — no glitch-free diamond resolution
      expect(recomputeCount, 2);

      bottom.dispose();
      right.dispose();
      left.dispose();
      source.dispose();
    });

    test('deeply chained Derived values propagate correctly', () {
      final source = TitanState(1);
      var chain = <TitanComputed<int>>[];

      chain.add(TitanComputed(() => source.value + 1));
      for (var i = 1; i < 10; i++) {
        final prev = chain[i - 1];
        chain.add(TitanComputed(() => prev.value + 1));
      }

      expect(chain.last.value, 11); // 1 + 10

      source.value = 100;
      expect(chain.last.value, 110);

      for (final c in chain.reversed) {
        c.dispose();
      }
      source.dispose();
    });

    test('error during recompute is captured via Vigil', () {
      Vigil.reset();
      final captured = <Object>[];
      Vigil.addHandler(_TestErrorHandler(captured));

      final state = TitanState(0);
      final computed = TitanComputed(() {
        if (state.value > 0) throw StateError('boom');
        return state.value;
      });

      expect(computed.value, 0);

      // Setting state.value triggers recompute via onDependencyChanged,
      // which catches the error, captures to Vigil, and rethrows
      expect(() => state.value = 1, throwsStateError);
      // The error was captured to Vigil
      expect(captured, hasLength(1));
      expect(captured[0], isA<StateError>());

      computed.dispose();
      state.dispose();
      Vigil.reset();
    });

    test('custom equals prevents unnecessary propagation', () {
      final state = TitanState(0);
      final computed = TitanComputed(
        () => state.value ~/ 10, // integer division
        equals: (a, b) => a == b,
      );

      int changes = 0;
      computed.addListener(() => changes++);
      computed.value; // force initial

      state.value = 1; // 1 ~/ 10 = 0, same as before
      expect(computed.value, 0);
      expect(changes, 0);

      state.value = 10; // 10 ~/ 10 = 1, different
      expect(computed.value, 1);
      expect(changes, 1);

      computed.dispose();
      state.dispose();
    });
  });
}

class _TestErrorHandler extends ErrorHandler {
  final List<Object> captured;
  _TestErrorHandler(this.captured);

  @override
  void handle(TitanError error) {
    captured.add(error.error);
  }
}
