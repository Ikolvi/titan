import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

class _TestStore extends TitanStore {
  late final count = createState(0, name: 'count');
  void increment() => count.value++;
}

void main() {
  group('TitanScope', () {
    testWidgets('provides stores to descendants', (tester) async {
      await tester.pumpWidget(
        TitanScope(
          stores: (c) => c.register(() => _TestStore()),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final store = context.titan<_TestStore>();
                return Text('${store.count.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });
  });

  group('TitanBuilder', () {
    testWidgets('rebuilds when state changes', (tester) async {
      final counter = TitanState(0, name: 'counter');

      await tester.pumpWidget(
        MaterialApp(
          home: TitanBuilder(
            builder: (context) => Text('Count: ${counter.value}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      counter.value = 5;
      await tester.pump();

      expect(find.text('Count: 5'), findsOneWidget);

      counter.dispose();
    });

    testWidgets('only rebuilds when tracked state changes', (tester) async {
      final a = TitanState(0, name: 'a');
      final b = TitanState(0, name: 'b');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: TitanBuilder(
            builder: (context) {
              buildCount++;
              return Text('A: ${a.value}');
            },
          ),
        ),
      );

      expect(buildCount, 1);

      // Change b — should NOT trigger rebuild
      b.value = 10;
      await tester.pump();
      expect(buildCount, 1);

      // Change a — should trigger rebuild
      a.value = 5;
      await tester.pump();
      expect(buildCount, 2);

      a.dispose();
      b.dispose();
    });
  });

  group('TitanConsumer', () {
    testWidgets('provides typed store access and rebuilds', (tester) async {
      await tester.pumpWidget(
        TitanScope(
          stores: (c) => c.register(() => _TestStore()),
          child: MaterialApp(
            home: TitanConsumer<_TestStore>(
              builder: (context, store) {
                return Column(
                  children: [
                    Text('Count: ${store.count.value}'),
                    ElevatedButton(
                      onPressed: store.increment,
                      child: const Text('Add'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });
  });

  group('TitanSelector', () {
    testWidgets('only rebuilds when selected value changes', (tester) async {
      final state = TitanState(0, name: 'state');
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: TitanSelector<bool>(
            selector: () => state.value > 5,
            builder: (context, isAboveFive) {
              buildCount++;
              return Text('Above 5: $isAboveFive');
            },
          ),
        ),
      );

      expect(find.text('Above 5: false'), findsOneWidget);
      expect(buildCount, 1);

      // Change state but selected value stays same
      state.value = 3;
      await tester.pump();
      expect(buildCount, 1); // No rebuild

      // Change state so selected value changes
      state.value = 10;
      await tester.pump();
      expect(find.text('Above 5: true'), findsOneWidget);

      state.dispose();
    });
  });

  group('Context extensions', () {
    testWidgets('context.titan<T>() retrieves store', (tester) async {
      late _TestStore capturedStore;

      await tester.pumpWidget(
        TitanScope(
          stores: (c) => c.register(() => _TestStore()),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedStore = context.titan<_TestStore>();
                return Text('${capturedStore.count.value}');
              },
            ),
          ),
        ),
      );

      expect(capturedStore, isA<_TestStore>());
      expect(capturedStore.count.value, 0);
    });

    testWidgets('context.hasTitan<T>() checks availability', (tester) async {
      late bool hasStore;

      await tester.pumpWidget(
        TitanScope(
          stores: (c) => c.register(() => _TestStore()),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                hasStore = context.hasTitan<_TestStore>();
                return Text('Has: $hasStore');
              },
            ),
          ),
        ),
      );

      expect(hasStore, true);
    });
  });
}
