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
  });
}
