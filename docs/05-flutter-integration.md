# Flutter Integration

Titan provides Flutter widgets and extensions that connect the reactive engine to the widget tree. Primary widgets are **Vestige** and **Beacon**. All available from `package:titan_bastion/titan_bastion.dart`.

## Vestige — The Primary Consumer

`Vestige<P>` is the primary widget for consuming Pillar state. It automatically finds the typed Pillar from the nearest Beacon (or global Titan registry) and rebuilds **only** when the specific Cores accessed during build change.

### Basic Usage

```dart
Vestige<CounterPillar>(
  builder: (context, counter) => Text('${counter.count.value}'),
)
```

### Auto-Tracking

Vestige tracks which Cores and Derived values you read during build. No selectors needed — you get surgical rebuilds for free:

```dart
// Only rebuilds when count changes — NOT when name changes
Vestige<CounterPillar>(
  builder: (context, c) => Text('${c.count.value}'),
)

// Only rebuilds when name changes — NOT when count changes
Vestige<CounterPillar>(
  builder: (context, c) => Text(c.name.value),
)
```

### Multiple Vestiges

Multiple Vestiges can consume the same Pillar independently:

```dart
Column(
  children: [
    // Rebuilds only when count changes
    Vestige<CounterPillar>(
      builder: (context, c) => Text('Count: ${c.count.value}'),
    ),
    // Rebuilds only when doubled changes
    Vestige<CounterPillar>(
      builder: (context, c) => Text('Double: ${c.doubled.value}'),
    ),
  ],
)
```

### Resolution Order

Vestige finds the Pillar in this order:
1. **Nearest Beacon** in the widget tree
2. **Global Titan registry** fallback

### Performance

Place Vestige as deep in the tree as possible for maximum efficiency:

```dart
// ✅ Good — only Text rebuilds
Scaffold(
  body: Column(
    children: [
      const HeaderWidget(),
      Vestige<CounterPillar>(
        builder: (_, c) => Text('${c.count.value}'),
      ),
      const FooterWidget(),
    ],
  ),
)

// ❌ Bad — entire Column rebuilds
Vestige<CounterPillar>(
  builder: (_, c) => Scaffold(
    body: Column(
      children: [
        const HeaderWidget(),
        Text('${c.count.value}'),
        const FooterWidget(),
      ],
    ),
  ),
)
```

---

## Beacon — The Scoped Provider

`Beacon` creates Pillar instances and makes them available to the widget subtree via Vestige.

### Basic Usage

```dart
Beacon(
  pillars: [
    CounterPillar.new,
    AuthPillar.new,
    CartPillar.new,
  ],
  child: MyApp(),
)
```

### With Constructor Arguments

```dart
Beacon(
  pillars: [
    () => AuthPillar(api: ApiService()),
    () => CartPillar(userId: currentUser.id),
  ],
  child: MyApp(),
)
```

### Scoped Lifecycle

Beacons own their Pillars. When a Beacon unmounts, all its Pillars are automatically disposed:

```dart
// Feature-level Beacon — Pillar lives while screen is mounted
Navigator.push(context, MaterialPageRoute(
  builder: (_) => Beacon(
    pillars: [CheckoutPillar.new],
    child: CheckoutScreen(),
  ),
));
```

### Nested Beacons

Child Beacons inherit parent Pillar access:

```dart
Beacon(
  pillars: [AuthPillar.new],
  child: Beacon(
    pillars: [DashboardPillar.new],
    child: DashboardScreen(),
    // Can access both AuthPillar & DashboardPillar
  ),
)
```

### Vs BlocProvider

```dart
// Bloc — one provider per bloc
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => CounterBloc()),
    BlocProvider(create: (_) => AuthBloc()),
  ],
  child: MyApp(),
)

// Titan — one Beacon, all Pillars
Beacon(
  pillars: [CounterPillar.new, AuthPillar.new],
  child: MyApp(),
)
```

---

## Context Extensions

### `context.pillar<P>()`

Retrieves a Pillar from the nearest Beacon:

```dart
final counter = context.pillar<CounterPillar>();
counter.increment();
```

> **Note:** This does NOT set up reactive tracking. Use `Vestige` for reactive rebuilds.

### `context.hasPillar<P>()`

Checks if a Pillar is available:

```dart
if (context.hasPillar<AuthPillar>()) {
  final auth = context.pillar<AuthPillar>();
  // ...
}
```

---

## VestigeRaw — Standalone Consumer

For standalone Cores (not inside a Pillar), use `VestigeRaw`:

```dart
final count = Core(0);

VestigeRaw(
  builder: (context) => Text('${count.value}'),
)
```

VestigeRaw auto-tracks just like Vestige, but without the Pillar type parameter.

---

## Legacy / Advanced Widgets

These widgets are still available for advanced use cases or gradual migration:

### TitanBuilder

Auto-tracking builder for standalone reactive values:

```dart
TitanBuilder(
  builder: (context) => Text('${someState.value}'),
)
```

### TitanScope

InheritedWidget-based scope for `TitanContainer` DI:

```dart
TitanScope(
  stores: (container) {
    container.register(() => SomeService());
  },
  child: MyApp(),
)
```

### TitanConsumer\<T\>

Typed store consumer (for TitanStore classes):

```dart
TitanConsumer<CounterStore>(
  builder: (context, store) => Text('${store.count.value}'),
)
```

### TitanSelector\<T\>

Fine-grained selector for specific derived values:

```dart
TitanSelector<bool>(
  selector: () => counter.value > 100,
  builder: (context, isHigh) => Icon(isHigh ? Icons.warning : Icons.check),
)
```

### TitanAsyncBuilder\<T\>

Pattern-matched builder for `AsyncValue` states:

```dart
TitanAsyncBuilder<List<Product>>(
  state: () => store.products.value,
  loading: (context) => const CircularProgressIndicator(),
  data: (context, products) => ProductList(products: products),
  error: (context, error, _) => ErrorWidget(error),
)
```

### TitanStateMixin

Mixin for StatefulWidgets that need reactive tracking:

```dart
class MyWidgetState extends State<MyWidget> with TitanStateMixin {
  @override
  void initState() {
    super.initState();
    final counter = context.pillar<CounterPillar>();
    watch(counter.count);
    titanEffect(() => print('Count: ${counter.count.value}'));
  }

  @override
  Widget build(BuildContext context) {
    return Text('${context.pillar<CounterPillar>().count.value}');
  }
}
```

---

## Widget Selection Guide

```
Need reactive Pillar access?
├── Yes → Vestige<P>
│
Need standalone Core reactivity?
├── Yes → VestigeRaw
│
Need one-time Pillar access (action)?
├── Yes → context.pillar<P>()
│
Need async data rendering?
├── Yes → TitanAsyncBuilder<T>
│
Need StatefulWidget reactivity?
├── Yes → TitanStateMixin
│
Need legacy TitanStore access?
├── Yes → TitanConsumer<T> or TitanBuilder
```

---

[← Pillars](04-stores.md) · [Middleware →](06-middleware.md)
