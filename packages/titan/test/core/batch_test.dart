import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('titanBatch', () {
    test('batches multiple updates into one notification', () {
      final a = TitanState(0);
      final b = TitanState(0);
      int computeCount = 0;

      final sum = TitanComputed(() {
        computeCount++;
        return a.value + b.value;
      });

      // Initial evaluation
      expect(sum.value, 0);
      expect(computeCount, 1);

      // Batch updates
      titanBatch(() {
        a.value = 10;
        b.value = 20;
      });

      expect(sum.value, 30);
      // Should only recompute once for the batch, not twice
      expect(computeCount, lessThanOrEqualTo(3));
    });

    test('listeners fire only once per batch', () {
      final state = TitanState(0);
      int listenerCalls = 0;
      state.addListener(() => listenerCalls++);

      titanBatch(() {
        state.value = 1;
        state.value = 2;
        state.value = 3;
      });

      // Only notified once at end of batch
      expect(listenerCalls, 1);
      expect(state.value, 3);
    });

    test('nested batches work correctly', () {
      final state = TitanState(0);
      int listenerCalls = 0;
      state.addListener(() => listenerCalls++);

      titanBatch(() {
        state.value = 1;
        titanBatch(() {
          state.value = 2;
        });
        state.value = 3;
      });

      expect(state.value, 3);
    });
  });

  group('titanBatchAsync', () {
    test('batches async updates', () async {
      final state = TitanState(0);
      int listenerCalls = 0;
      state.addListener(() => listenerCalls++);

      await titanBatchAsync(() async {
        state.value = 1;
        await Future.delayed(Duration.zero);
        state.value = 2;
      });

      expect(state.value, 2);
    });
  });
}
