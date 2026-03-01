# Testing

Titan is designed for testability. The core is pure Dart, so you can test Pillar logic without Flutter. Widgets can be tested with standard `flutter_test`.

## Testing Pillars

### Basic Pillar Tests

```dart
import 'package:test/test.dart';

void main() {
  late CounterPillar pillar;

  setUp(() {
    pillar = CounterPillar();
  });

  tearDown(() {
    pillar.dispose();
  });

  test('initial state', () {
    expect(pillar.count.value, 0);
    expect(pillar.doubled.value, 0);
    expect(pillar.isEven.value, true);
  });

  test('increment updates count and derived state', () {
    pillar.increment();

    expect(pillar.count.value, 1);
    expect(pillar.doubled.value, 2);
    expect(pillar.isEven.value, false);
  });

  test('reset returns to initial state', () {
    pillar.increment();
    pillar.increment();
    pillar.reset();

    expect(pillar.count.value, 0);
  });
}
```

### Testing Async Operations

```dart
test('loads products successfully', () async {
  final pillar = ProductPillar(MockProductRepo());
  await pillar.loadProducts();

  pillar.products.value.when(
    data: (products) => expect(products, hasLength(3)),
    loading: () => fail('Should not be loading'),
    error: (e, _) => fail('Should not have error'),
  );

  pillar.dispose();
});
```

### Testing Pillar Communication

```dart
test('cart total uses product prices', () {
  final products = ProductPillar(MockProductRepo());
  final cart = CartPillar(products);

  products.products.value = [
    Product(id: '1', name: 'Widget', price: 9.99),
  ];

  cart.addToCart('1');
  expect(cart.total.value, 9.99);

  products.dispose();
  cart.dispose();
});
```

## Testing Reactive Primitives

### Core (TitanState)

```dart
test('notifies listeners on change', () {
  final state = Core(0);
  final values = <int>[];

  state.listen((v) => values.add(v));
  state.value = 1;
  state.value = 2;
  state.value = 3;

  expect(values, [1, 2, 3]);
  state.dispose();
});

test('does not notify when value is same', () {
  final state = Core(0);
  int notifyCount = 0;

  state.listen((_) => notifyCount++);
  state.value = 0;
  state.value = 0;

  expect(notifyCount, 0);
  state.dispose();
});
```

### Derived (TitanComputed)

```dart
test('recomputes when dependency changes', () {
  final a = Core(2);
  final b = Core(3);
  final sum = Derived(() => a.value + b.value);

  expect(sum.value, 5);
  a.value = 10;
  expect(sum.value, 13);

  a.dispose();
  b.dispose();
  sum.dispose();
});

test('caches computed result', () {
  int computeCount = 0;
  final state = Core(1);
  final computed = Derived(() {
    computeCount++;
    return state.value * 2;
  });

  computed.value; // First computation
  computed.value; // Cached
  computed.value; // Cached

  expect(computeCount, 1);
  state.dispose();
  computed.dispose();
});
```

### Effect (TitanEffect)

```dart
test('runs when dependency changes', () {
  final state = Core(0);
  final values = <int>[];

  final effect = TitanEffect(() {
    values.add(state.value);
  });

  expect(values, [0]); // Runs immediately

  state.value = 1;
  expect(values, [0, 1]);

  effect.dispose();
  state.dispose();
});

test('cleanup runs before re-execution', () {
  final state = Core(0);
  final cleanups = <int>[];

  final effect = TitanEffect(() {
    final current = state.value;
    return () => cleanups.add(current);
  });

  state.value = 1;
  expect(cleanups, [0]);

  state.value = 2;
  expect(cleanups, [0, 1]);

  effect.dispose();
  state.dispose();
});
```

### Batching / Strike

```dart
test('batches multiple updates', () {
  final a = Core(0);
  final b = Core(0);
  int effectCount = 0;

  TitanEffect(() {
    a.value;
    b.value;
    effectCount++;
  });

  expect(effectCount, 1);

  strike(() {
    a.value = 1;
    b.value = 2;
  });

  expect(effectCount, 2); // Only one re-run
});
```

## Testing Flutter Widgets

### Vestige

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

testWidgets('Vestige rebuilds on Core change', (tester) async {
  await tester.pumpWidget(
    Beacon(
      pillars: [CounterPillar.new],
      child: MaterialApp(
        home: Vestige<CounterPillar>(
          builder: (context, c) => Text('${c.count.value}'),
        ),
      ),
    ),
  );

  expect(find.text('0'), findsOneWidget);

  // Get the pillar and mutate
  final pillar = tester.element(find.byType(Vestige<CounterPillar>))
      .findAncestorWidgetOfExactType<Beacon>()!;
  // Or use Titan.put for easier test access:
});

testWidgets('Vestige with Titan global registry', (tester) async {
  final counter = CounterPillar();
  Titan.put(counter);

  await tester.pumpWidget(
    MaterialApp(
      home: Vestige<CounterPillar>(
        builder: (context, c) => Text('${c.count.value}'),
      ),
    ),
  );

  expect(find.text('0'), findsOneWidget);

  counter.increment();
  await tester.pump();

  expect(find.text('1'), findsOneWidget);

  Titan.reset();
});
```

### Beacon

```dart
testWidgets('Beacon creates and provides Pillars', (tester) async {
  await tester.pumpWidget(
    Beacon(
      pillars: [CounterPillar.new],
      child: MaterialApp(
        home: Builder(builder: (context) {
          final counter = context.pillar<CounterPillar>();
          return Column(
            children: [
              Text('${counter.count.value}'),
              ElevatedButton(
                onPressed: counter.increment,
                child: const Text('Add'),
              ),
            ],
          );
        }),
      ),
    ),
  );

  expect(find.text('0'), findsOneWidget);

  await tester.tap(find.text('Add'));
  await tester.pump();

  // Note: context.pillar is non-reactive, so you'd use Vestige for rebuilds
});
```

### VestigeRaw

```dart
testWidgets('VestigeRaw rebuilds on standalone Core', (tester) async {
  final counter = Core(0);

  await tester.pumpWidget(
    MaterialApp(
      home: VestigeRaw(
        builder: (context) => Text('${counter.value}'),
      ),
    ),
  );

  expect(find.text('0'), findsOneWidget);

  counter.value = 42;
  await tester.pump();

  expect(find.text('42'), findsOneWidget);

  counter.dispose();
});
```

## Testing DI Container

```dart
test('container registers and retrieves', () {
  final container = TitanContainer();
  container.register(() => CounterPillar());
  final pillar = container.get<CounterPillar>();
  expect(pillar, isA<CounterPillar>());
  container.dispose();
});

test('child container inherits parent', () {
  final parent = TitanContainer();
  parent.register(() => AuthPillar());

  final child = parent.createChild();
  child.register(() => FeaturePillar());

  expect(child.get<AuthPillar>(), isA<AuthPillar>());
  expect(child.get<FeaturePillar>(), isA<FeaturePillar>());

  child.dispose();
  parent.dispose();
});
```

## Testing Tips

### 1. Always Dispose

```dart
late CounterPillar pillar;
setUp(() => pillar = CounterPillar());
tearDown(() => pillar.dispose());
```

### 2. Test Derived Values Synchronously

```dart
pillar.increment();
expect(pillar.doubled.value, 2); // Immediately available
```

### 3. Test Batched Updates (Strike)

```dart
pillar.checkout(); // Uses strike() internally
expect(pillar.cart.value, isEmpty);
expect(pillar.status.value, OrderStatus.processing);
```

### 4. Mock Pillars for Widget Tests

```dart
class MockCounterPillar extends CounterPillar {
  MockCounterPillar() {
    count.value = 42; // Pre-set test data
  }
}

testWidgets('widget shows mock data', (tester) async {
  Titan.put<CounterPillar>(MockCounterPillar());

  await tester.pumpWidget(
    MaterialApp(
      home: Vestige<CounterPillar>(
        builder: (_, c) => Text('${c.count.value}'),
      ),
    ),
  );

  expect(find.text('42'), findsOneWidget);
  Titan.reset();
});
```

### 5. Verify No Unnecessary Rebuilds

```dart
int buildCount = 0;

await tester.pumpWidget(
  Beacon(
    pillars: [CounterPillar.new],
    child: MaterialApp(
      home: Vestige<CounterPillar>(
        builder: (_, c) {
          buildCount++;
          return Text('${c.count.value}');
        },
      ),
    ),
  ),
);

// Same value — no rebuild
final counter = tester.element(find.byType(Text)).findAncestorWidgetOfExactType<Beacon>();
// counter.count.value = counter.count.value; // Same value
// await tester.pump();
// expect(buildCount, 1);
```

---

[← Oracle & Observation](06-middleware.md) · [Advanced Patterns →](08-advanced-patterns.md)
