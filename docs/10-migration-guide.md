# Migration Guide

This guide helps you migrate from other state management solutions to Titan.

---

## From Provider

### ChangeNotifier → Pillar

**Before (Provider):**

```dart
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

ChangeNotifierProvider(
  create: (_) => CounterModel(),
  child: MyApp(),
)

Consumer<CounterModel>(
  builder: (_, model, __) => Text('${model.count}'),
)
```

**After (Titan):**

```dart
class CounterPillar extends Pillar {
  late final count = core(0);
  void increment() => strike(() => count.value++);
}

Beacon(
  pillars: [CounterPillar.new],
  child: MyApp(),
)

Vestige<CounterPillar>(
  builder: (_, c) => Text('${c.count.value}'),
)
```

**Key differences:**
- No `notifyListeners()` — updates are automatic
- Fine-grained reactivity — only specific Cores trigger rebuilds
- Auto-tracking — no selectors needed

### MultiProvider → Beacon

**Before:**

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthModel()),
    ChangeNotifierProvider(create: (_) => CartModel()),
    ChangeNotifierProvider(create: (_) => ThemeModel()),
  ],
  child: MyApp(),
)
```

**After:**

```dart
Beacon(
  pillars: [AuthPillar.new, CartPillar.new, ThemePillar.new],
  child: MyApp(),
)
```

### context.read/watch → context.pillar / Vestige

**Before:**

```dart
final model = context.read<CounterModel>();   // Non-reactive
final model = context.watch<CounterModel>();   // Reactive (all changes)
final count = context.select<CounterModel, int>((m) => m.count); // Selective
```

**After:**

```dart
final pillar = context.pillar<CounterPillar>();  // Non-reactive

Vestige<CounterPillar>(                          // Reactive + auto-tracked
  builder: (_, c) => Text('${c.count.value}'),
)
```

---

## From Bloc

### Bloc → Pillar

**Before (Bloc):**

```dart
// Events
abstract class CounterEvent {}
class IncrementPressed extends CounterEvent {}
class DecrementPressed extends CounterEvent {}

// State
class CounterState {
  final int count;
  const CounterState(this.count);
}

// Bloc
class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(const CounterState(0)) {
    on<IncrementPressed>((event, emit) {
      emit(CounterState(state.count + 1));
    });
    on<DecrementPressed>((event, emit) {
      emit(CounterState(state.count - 1));
    });
  }
}

BlocBuilder<CounterBloc, CounterState>(
  builder: (context, state) => Text('${state.count}'),
)
context.read<CounterBloc>().add(IncrementPressed());
```

**After (Titan):**

```dart
class CounterPillar extends Pillar {
  late final count = core(0);
  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
}

Vestige<CounterPillar>(
  builder: (_, c) => Text('${c.count.value}'),
)
context.pillar<CounterPillar>().increment();
```

**Key differences:**
- No event classes — just call methods
- No separate state classes — use Cores
- No `emit()` — assignment triggers updates
- ~70% less code for the same functionality
- Auto-tracked rebuilds (no BlocSelector needed)

### BlocProvider → Beacon

**Before:**

```dart
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => CounterBloc()),
    BlocProvider(create: (_) => AuthBloc()),
  ],
  child: MyApp(),
)
```

**After:**

```dart
Beacon(
  pillars: [CounterPillar.new, AuthPillar.new],
  child: MyApp(),
)
```

### BlocSelector → Vestige (Free)

**Before:**

```dart
BlocSelector<UserBloc, UserState, String>(
  selector: (state) => state.name,
  builder: (context, name) => Text(name),
)
```

**After:**

```dart
// Auto-tracked — only rebuilds when name changes
Vestige<UserPillar>(
  builder: (_, u) => Text(u.name.value),
)
```

---

## From Riverpod

### StateNotifier → Pillar

**Before (Riverpod):**

```dart
final counterProvider = StateNotifierProvider<CounterNotifier, int>(
  (ref) => CounterNotifier(),
);

class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);
  void increment() => state++;
}

class CounterPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}
```

**After (Titan):**

```dart
class CounterPillar extends Pillar {
  late final count = core(0);
  void increment() => strike(() => count.value++);
}

Vestige<CounterPillar>(
  builder: (_, c) => Text('${c.count.value}'),
)
```

### ref.watch/read → Vestige / context.pillar

**Before:**

```dart
final value = ref.watch(myProvider);        // Reactive
final value = ref.read(myProvider);          // Non-reactive
final name = ref.watch(userProvider.select((u) => u.name)); // Selective
```

**After:**

```dart
// Reactive + auto-tracked
Vestige<MyPillar>(builder: (_, p) => Text('${p.value.value}'));

// Non-reactive
final pillar = context.pillar<MyPillar>();

// Selective — free with auto-tracking
Vestige<UserPillar>(builder: (_, u) => Text(u.name.value));
```

### FutureProvider → Pillar + TitanAsyncState

**Before:**

```dart
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.read(repoProvider);
  return repo.getProducts();
});
```

**After:**

```dart
class ProductPillar extends Pillar {
  late final products = TitanAsyncState<List<Product>>();

  @override
  void onInit() {
    products.load(() => repo.getProducts());
  }
}
```

---

## From GetX

### GetxController → Pillar

**Before (GetX):**

```dart
class CounterController extends GetxController {
  var count = 0.obs;
  void increment() => count++;
}

Get.put(CounterController());
final controller = Get.find<CounterController>();
Obx(() => Text('${controller.count}'));
```

**After (Titan):**

```dart
class CounterPillar extends Pillar {
  late final count = core(0);
  void increment() => strike(() => count.value++);
}

Beacon(
  pillars: [CounterPillar.new],
  child: Vestige<CounterPillar>(
    builder: (_, c) => Text('${c.count.value}'),
  ),
)
```

**Key differences:**
- No `.obs` magic — explicit `core()`
- No `Get.put()`/`Get.find()` singletons — Beacon scoping or `Titan.put()`
- Testable — no global singletons polluting tests
- Scoped — state tied to widget tree with Beacon

---

## Migration Strategy

### 1. Gradual Migration

Titan can coexist with other solutions:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => OldModel()), // Keep
  ],
  child: Beacon(
    pillars: [NewPillar.new], // Add Titan
    child: MyApp(),
  ),
)
```

### 2. Bottom-Up Approach

1. Convert simple models/blocs to Pillars
2. Replace Provider/BlocProvider with Beacon
3. Replace Consumer/BlocBuilder with Vestige
4. Remove old dependencies

### 3. Test-Driven Migration

1. Write Pillar tests matching existing behavior
2. Verify tests pass
3. Update widgets to use Vestige
4. Verify UI behavior

---

[← API Reference](09-api-reference.md) · [Architecture →](11-architecture.md)
