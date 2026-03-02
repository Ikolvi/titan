# Core Concepts

Titan's reactive system is built on four primitives: **Core**, **Derived**, **Effect**, and **Batch** (aka **Strike**). Understanding these is all you need to use Titan effectively.

## Core (TitanState)

`Core<T>` (alias for `TitanState<T>`) is a reactive container for a single mutable value. When its value changes, all dependents are automatically notified.

### Creating Cores

Inside a Pillar (managed — auto-disposed):

```dart
class MyPillar extends Pillar {
  late final name = core('Alice');
  late final age = core(25);
  late final scores = core<List<int>>([90, 85, 92]);
  late final user = core<User?>(null);
}
```

Standalone (manual lifecycle):

```dart
final name = Core('Alice');
final age = Core(25);
final counter = Core(0, name: 'counter'); // Named for debugging
```

### Reading & Writing

```dart
print(name.value); // 'Alice' — tracks the access
name.value = 'Bob'; // Notifies all dependents
```

State only notifies when the value actually changes:

```dart
name.value = 'Alice'; // Sets to 'Alice'
name.value = 'Alice'; // No notification (same value)
```

### Peek (Read Without Tracking)

```dart
print(name.peek()); // 'Alice' — no dependency tracking
```

### Update (Transform Current Value)

```dart
counter.update((current) => current + 1);
scores.update((list) => [...list, 100]);
```

### Silent Update (No Notification)

```dart
counter.silent(42); // Updates value without notifying dependents
```

### Custom Equality

```dart
final list = Core<List<int>>(
  [1, 2, 3],
  equals: (a, b) => listEquals(a, b),
);
```

### Listening to Changes

```dart
final unsubscribe = counter.listen((value) {
  print('Counter is now: $value');
});

// Later: clean up
unsubscribe();
```

### Disposal

```dart
counter.dispose(); // Remove all listeners and dependents
```

> Inside a Pillar, all Cores are auto-disposed when the Pillar is disposed.

---

## Derived (TitanComputed)

`Derived<T>` (alias for `TitanComputed<T>`) is a reactive value that automatically tracks its dependencies and recomputes when they change.

### Creating Derived Values

Inside a Pillar:

```dart
class UserPillar extends Pillar {
  late final firstName = core('John');
  late final lastName = core('Doe');
  late final fullName = derived(
    () => '${firstName.value} ${lastName.value}',
  );
}
```

Standalone:

```dart
final firstName = Core('John');
final lastName = Core('Doe');
final fullName = Derived(() => '${firstName.value} ${lastName.value}');
```

### Key Properties

1. **Auto-tracking** — Dependencies detected by reading `.value`
2. **Lazy evaluation** — Not computed until first accessed
3. **Caching** — Only recomputes when dependencies change
4. **Propagation control** — Only notifies if the result actually changed

### How It Works

```dart
final a = Core(2);
final b = Core(3);
final sum = Derived(() => a.value + b.value);

print(sum.value); // 5 — computed and cached
a.value = 10;
print(sum.value); // 13 — recomputed
print(sum.value); // 13 — cached (no recomputation)
```

### Chained Derivations

```dart
final price = Core(100.0);
final taxRate = Core(0.2);
final tax = Derived(() => price.value * taxRate.value);
final total = Derived(() => price.value + tax.value);

print(total.value); // 120.0
price.value = 200.0;
print(total.value); // 240.0
```

---

## Effect (TitanEffect)

`TitanEffect` runs a side-effect function whenever its tracked dependencies change.

### Creating Effects

Inside a Pillar (managed):

```dart
class MyPillar extends Pillar {
  late final count = core(0);

  @override
  void onInit() {
    watch(() {
      print('Count changed to: ${count.value}');
    });
  }
}
```

Standalone:

```dart
final counter = Core(0);
final effect = TitanEffect(() {
  print('Counter changed to: ${counter.value}');
});
```

By default, effects run immediately upon creation (`fireImmediately: true`).

### Cleanup Functions

Return a cleanup function from the effect to run before each re-execution:

```dart
final effect = TitanEffect(() {
  final subscription = stream.listen((data) { /* ... */ });
  return () => subscription.cancel();
});
```

### Delayed Effects

```dart
final effect = TitanEffect(
  () => print('Counter: ${counter.value}'),
  fireImmediately: false,
);
effect.run(); // Manually trigger
```

### Disposal

```dart
effect.dispose(); // Stops tracking, runs final cleanup
```

> Inside a Pillar, `watch()` creates managed effects that are auto-disposed.

---

## Strike / Batch

Batching groups multiple state changes into a single notification cycle, preventing intermediate rebuilds.

### Inside a Pillar — Strike

```dart
class CheckoutPillar extends Pillar {
  late final cart = core<List<Item>>([]);
  late final status = core(OrderStatus.idle);
  late final lastOrder = core<DateTime?>(null);

  void checkout() {
    // Single notification for all three changes
    strike(() {
      cart.value = [];
      status.value = OrderStatus.processing;
      lastOrder.value = DateTime.now();
    });
  }

  Future<void> asyncCheckout() async {
    await strikeAsync(() async {
      final result = await api.placeOrder(cart.value);
      cart.value = [];
      status.value = result.status;
    });
  }
}
```

### Standalone — titanBatch

```dart
final a = Core(0);
final b = Core(0);

titanBatch(() {
  a.value = 1; // No notification yet
  b.value = 2; // No notification yet
}); // Single notification for both

await titanBatchAsync(() async {
  a.value = await fetchA();
  b.value = await fetchB();
});
```

### Why Batching Matters

Without batching:

```dart
a.value = 1; // Rebuild 1
b.value = 2; // Rebuild 2
c.value = 3; // Rebuild 3
```

With batching:

```dart
strike(() {
  a.value = 1;
  b.value = 2;
  c.value = 3;
}); // Only 1 rebuild
```

---

## Observer

Titan's observer system provides global visibility into state changes.

### TitanLoggingObserver

```dart
TitanObserver.instance = TitanLoggingObserver();
// Output: [Titan] counter: 0 → 1
```

### TitanHistoryObserver (Time-Travel Debugging)

```dart
final observer = TitanHistoryObserver(maxHistory: 100);
TitanObserver.instance = observer;

// After some state changes...
print(observer.history); // List<StateChangeRecord>
observer.clear();
```

### Custom Observer

```dart
class AnalyticsObserver extends TitanObserver {
  @override
  void onStateChanged<T>(String name, T oldValue, T newValue) {
    analytics.track('state_changed', {
      'name': name,
      'old': oldValue.toString(),
      'new': newValue.toString(),
    });
  }
}
```

---

## Lifecycle

All reactive nodes support disposal:

```dart
final state = Core(0);
final computed = Derived(() => state.value * 2);
final effect = TitanEffect(() => print(state.value));

state.dispose();
computed.dispose();
effect.dispose();
```

When using Pillars, disposal is automatic:

```dart
class MyPillar extends Pillar {
  late final count = core(0);       // Auto-disposed
  late final doubled = derived(     // Auto-disposed
    () => count.value * 2,
  );

  @override
  void onInit() {
    watch(() => print(count.value)); // Auto-disposed
  }

  @override
  void onDispose() {
    // Optional: custom cleanup
  }
}
```

---

## Summary

| Concept | Titan Name | In Pillar | Standalone |
|---------|------------|-----------|------------|
| Mutable state | **Core** | `core(0)` | `Core(0)` |
| Derived value | **Derived** | `derived(() => ...)` | `Derived(() => ...)` |
| Side effect | **Watch** | `watch(() => ...)` | `TitanEffect(() => ...)` |
| Batch updates | **Strike** | `strike(() => ...)` | `titanBatch(() => ...)` |
| Global monitoring | **Observer** | — | `TitanObserver.instance = ...` |

---

[← Getting Started](02-getting-started.md) · [Pillars →](04-pillars.md)
