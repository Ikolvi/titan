# Pillars

Pillars organize related state, computed values, effects, and actions into cohesive units with lifecycle management. They are the recommended pattern for anything beyond trivial state.

## Creating a Pillar

Extend `Pillar` and use `core()`, `derived()`, and `watch()` to define reactive nodes:

```dart
class CounterPillar extends Pillar {
  late final count = core(0);
  late final doubled = derived(() => count.value * 2);

  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
  void reset() => strike(() => count.value = 0);
}
```

### Why `late final`?

Using `late final` ensures:
1. The field is initialized lazily (on first access)
2. It's initialized only once
3. `core()`/`derived()` register the node with the Pillar for automatic disposal

## Pillar Lifecycle

### Initialization

Override `onInit()` for setup logic that runs once:

```dart
class AuthPillar extends Pillar {
  late final user = core<User?>(null);
  late final isAuthenticated = derived(() => user.value != null);

  @override
  void onInit() {
    _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    final saved = await UserStorage.load();
    user.value = saved;
  }
}
```

### Disposal

Override `onDispose()` for cleanup:

```dart
class StreamPillar extends Pillar {
  StreamSubscription? _subscription;

  @override
  void onInit() {
    _subscription = someStream.listen((data) { /* ... */ });
  }

  @override
  void onDispose() {
    _subscription?.cancel();
  }
}
```

All Cores, Derived values, and Effects created with `core()`, `derived()`, and `watch()` are automatically disposed when the Pillar is disposed.

## Pillar Patterns

### Domain Pillar

One Pillar per business domain:

```dart
class UserPillar extends Pillar {
  late final users = core<List<User>>([]);
  late final selectedUser = core<User?>(null);
  late final userCount = derived(() => users.value.length);

  void addUser(User user) {
    strike(() => users.update((list) => [...list, user]));
  }

  void selectUser(User user) {
    selectedUser.value = user;
  }

  void removeUser(String id) {
    strike(() {
      users.update((list) => list.where((u) => u.id != id).toList());
      if (selectedUser.value?.id == id) {
        selectedUser.value = null;
      }
    });
  }
}
```

### Feature Pillar

One Pillar per feature/page:

```dart
class TodoPillar extends Pillar {
  late final todos = core<List<Todo>>([]);
  late final filter = core(TodoFilter.all);
  late final searchQuery = core('');

  late final filteredTodos = derived(() {
    var result = todos.value;

    switch (filter.value) {
      case TodoFilter.active:
        result = result.where((t) => !t.completed).toList();
      case TodoFilter.completed:
        result = result.where((t) => t.completed).toList();
      case TodoFilter.all:
        break;
    }

    if (searchQuery.value.isNotEmpty) {
      result = result
          .where((t) => t.title.toLowerCase()
              .contains(searchQuery.value.toLowerCase()))
          .toList();
    }

    return result;
  });

  late final remainingCount = derived(
    () => todos.value.where((t) => !t.completed).length,
  );

  void addTodo(String title) {
    todos.update((list) => [...list, Todo(title: title)]);
  }

  void toggleTodo(String id) {
    todos.update((list) => list.map((t) {
      if (t.id == id) return t.copyWith(completed: !t.completed);
      return t;
    }).toList());
  }
}
```

### Watchers (Reactive Side Effects)

Use `watch()` inside `onInit()` for managed reactive effects:

```dart
class AnalyticsPillar extends Pillar {
  late final currentPage = core('/');
  late final userId = core<String?>(null);

  @override
  void onInit() {
    watch(() {
      if (userId.value != null) {
        analytics.trackPageView(currentPage.value, userId.value!);
      }
    });
  }
}
```

## Providing Pillars

### Via Beacon (Scoped)

```dart
Beacon(
  pillars: [
    CounterPillar.new,
    AuthPillar.new,
    TodoPillar.new,
  ],
  child: MyApp(),
)
```

Pillars are auto-initialized on mount and auto-disposed on unmount.

### Via Titan (Global)

```dart
void main() {
  Titan.put(AuthPillar());       // Auto-initialized
  Titan.put(SettingsPillar());
  runApp(const MyApp());
}

// Access anywhere
final auth = Titan.get<AuthPillar>();
```

### Scoped State (Feature-Level)

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => Beacon(
    pillars: [CheckoutPillar.new],
    child: CheckoutScreen(),
  ),
));
// CheckoutPillar is disposed when navigating back
```

## Pillar Communication

Pillars can reference each other by accepting dependencies via constructor:

```dart
class CartPillar extends Pillar {
  final ProductPillar _products;

  CartPillar(this._products);

  late final items = core<List<CartItem>>([]);

  late final total = derived(() {
    return items.value.fold(0.0, (sum, item) {
      final product = _products.getProduct(item.productId);
      return sum + (product?.price ?? 0) * item.quantity;
    });
  });

  void addToCart(String productId) {
    items.update((list) => [...list, CartItem(productId: productId)]);
  }
}

// Wire up via Beacon
Beacon(
  pillars: [
    ProductPillar.new,
    () => CartPillar(Titan.get<ProductPillar>()),
  ],
  child: MyApp(),
)
```

## Best Practices

### 1. Keep Pillars Focused

```dart
// ✅ Good — one domain per Pillar
class AuthPillar extends Pillar { /* auth state */ }
class CartPillar extends Pillar { /* cart state */ }
class SettingsPillar extends Pillar { /* settings */ }

// ❌ Bad — one Pillar does everything
class AppPillar extends Pillar { /* auth + cart + settings + ... */ }
```

### 2. Use Derived for Computed State

```dart
// ✅ Good — derived from source of truth
late final total = derived(() =>
  items.value.fold(0.0, (s, i) => s + i.price));

// ❌ Bad — manually synced duplicate state
late final total = core(0.0);
void addItem(Item item) {
  items.update((l) => [...l, item]);
  total.value = items.value.fold(0.0, (s, i) => s + i.price); // manual sync
}
```

### 3. Use Strike for Related Mutations

```dart
void checkout() {
  strike(() {
    cart.value = [];
    orderStatus.value = OrderStatus.processing;
    lastOrderDate.value = DateTime.now();
  }); // Single rebuild
}
```

### 4. Always Dispose in Tests

```dart
late CounterPillar pillar;
setUp(() => pillar = CounterPillar());
tearDown(() => pillar.dispose());
```

---

[← Core Concepts](03-core-concepts.md) · [Flutter Integration →](05-flutter-integration.md)
