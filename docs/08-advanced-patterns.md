# Advanced Patterns

This guide covers advanced patterns for building complex, production-grade applications with Titan.

## Dependency Injection

### Titan Global Registry

The simplest DI pattern — register Pillars globally:

```dart
void main() {
  Titan.put(AuthPillar());
  Titan.put(CartPillar());
  Titan.lazy<AnalyticsPillar>(() => AnalyticsPillar());
  runApp(const MyApp());
}

// Access anywhere
final auth = Titan.get<AuthPillar>();
```

### TitanContainer

For hierarchical DI with scoped registration:

```dart
final container = TitanContainer();

container.register(() => ApiClient());
container.register(() => AuthPillar());

final api = container.get<ApiClient>();
final auth = container.get<AuthPillar>();
```

### Scoped Registration

Child containers inherit parent registrations:

```dart
final root = TitanContainer();
root.register(() => ApiClient());
root.register(() => AuthPillar());

final feature = root.createChild();
feature.register(() => FeaturePillar());

// feature can access ApiClient, AuthPillar, AND FeaturePillar
// root cannot access FeaturePillar
```

### Modules

Group related registrations:

```dart
class AuthModule extends TitanModule {
  @override
  void register(TitanContainer container) {
    container.register(() => AuthService());
    container.register(() => AuthPillar());
    container.register(() => TokenManager());
  }
}

class ApiModule extends TitanModule {
  @override
  void register(TitanContainer container) {
    container.register(() => ApiClient(baseUrl: 'https://api.example.com'));
  }
}
```

### Simple Modules

```dart
final networkModule = TitanSimpleModule((container) {
  container.register(() => HttpClient());
  container.register(() => WebSocketClient());
  container.register(() => ApiClient(http: container.get<HttpClient>()));
});
```

---

## Async State Management

### AsyncValue

The `AsyncValue<T>` sealed class models asynchronous data:

```dart
sealed class AsyncValue<T> {
  const factory AsyncValue.data(T value) = AsyncData;
  const factory AsyncValue.loading() = AsyncLoading;
  const factory AsyncValue.error(Object error, [StackTrace?]) = AsyncError;
}
```

### Pattern Matching

```dart
final result = asyncValue.when(
  data: (value) => 'Got: $value',
  loading: () => 'Loading...',
  error: (e, _) => 'Error: $e',
);
```

### TitanAsyncState

Reactive async state wrapper:

```dart
class ProductPillar extends Pillar {
  late final products = TitanAsyncState<List<Product>>();

  Future<void> loadProducts() async {
    await products.load(() async {
      return await api.getProducts();
    });
  }

  Future<void> refreshProducts() async {
    await products.refresh(() async {
      return await api.getProducts();
    });
  }
}
```

### Async in Widgets

```dart
TitanAsyncBuilder<List<Product>>(
  state: () => pillar.products.value,
  loading: (context) => const CircularProgressIndicator(),
  data: (context, products) => ListView.builder(
    itemCount: products.length,
    itemBuilder: (_, i) => ProductTile(products[i]),
  ),
  error: (context, error, _) => ErrorMessage(
    error: error,
    onRetry: pillar.loadProducts,
  ),
)
```

---

## Form Handling

```dart
class LoginFormPillar extends Pillar {
  late final email = core('');
  late final password = core('');
  late final showPassword = core(false);
  late final isSubmitting = core(false);

  late final emailError = derived(() {
    final value = email.value;
    if (value.isEmpty) return null;
    if (!value.contains('@')) return 'Invalid email';
    return null;
  });

  late final passwordError = derived(() {
    final value = password.value;
    if (value.isEmpty) return null;
    if (value.length < 8) return 'Must be at least 8 characters';
    return null;
  });

  late final isValid = derived(
    () => email.value.isNotEmpty
        && password.value.isNotEmpty
        && emailError.value == null
        && passwordError.value == null,
  );

  Future<void> submit() async {
    if (!isValid.value || isSubmitting.value) return;

    isSubmitting.value = true;
    try {
      await authService.login(email.value, password.value);
    } finally {
      isSubmitting.value = false;
    }
  }
}
```

---

## Pagination

```dart
class PaginatedListPillar extends Pillar {
  late final items = core<List<Item>>([]);
  late final currentPage = core(0);
  late final hasMore = core(true);
  late final isLoading = core(false);

  Future<void> loadNextPage() async {
    if (isLoading.value || !hasMore.value) return;

    isLoading.value = true;
    try {
      final nextPage = currentPage.value + 1;
      final newItems = await api.getItems(page: nextPage);

      strike(() {
        items.update((list) => [...list, ...newItems]);
        currentPage.value = nextPage;
        hasMore.value = newItems.isNotEmpty;
      });
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refresh() async {
    strike(() {
      items.value = [];
      currentPage.value = 0;
      hasMore.value = true;
    });
    await loadNextPage();
  }
}
```

---

## Search with Debounce

```dart
class SearchPillar extends Pillar {
  late final query = core('');
  late final results = TitanAsyncState<List<SearchResult>>();

  Timer? _debouncer;

  void setQuery(String value) {
    query.value = value;
    _debouncer?.cancel();
    _debouncer = Timer(const Duration(milliseconds: 300), _performSearch);
  }

  Future<void> _performSearch() async {
    if (query.value.isEmpty) {
      results.setValue([]);
      return;
    }
    await results.load(() => api.search(query.value));
  }

  @override
  void onDispose() {
    _debouncer?.cancel();
  }
}
```

---

## Multi-Pillar Coordination

### Derived Across Pillars

```dart
class DashboardPillar extends Pillar {
  final AuthPillar auth;
  final CartPillar cart;
  final NotificationPillar notifications;

  DashboardPillar({
    required this.auth,
    required this.cart,
    required this.notifications,
  });

  late final summary = derived(() => DashboardSummary(
    username: auth.user.value?.name ?? 'Guest',
    cartCount: cart.items.value.length,
    unreadNotifications: notifications.unread.value,
  ));
}

// Wire up
Beacon(
  pillars: [
    AuthPillar.new,
    CartPillar.new,
    NotificationPillar.new,
    () => DashboardPillar(
      auth: Titan.get<AuthPillar>(),
      cart: Titan.get<CartPillar>(),
      notifications: Titan.get<NotificationPillar>(),
    ),
  ],
  child: App(),
)
```

---

## Feature Scoping

Use nested Beacons for feature-level state:

```dart
// App-level Beacon
Beacon(
  pillars: [AuthPillar.new, ThemePillar.new],
  child: MaterialApp(
    routes: {
      '/checkout': (_) => Beacon(
        // Feature-level — disposed when navigating away
        pillars: [CheckoutPillar.new],
        child: CheckoutPage(),
      ),
    },
  ),
)
```

---

## Undo/Redo Pattern

```dart
class UndoablePillar extends Pillar {
  late final value = core(0);
  final List<int> _undoStack = [];
  final List<int> _redoStack = [];

  late final canUndo = derived(() => _undoStack.isNotEmpty);
  late final canRedo = derived(() => _redoStack.isNotEmpty);

  void setValue(int newValue) {
    _undoStack.add(value.value);
    _redoStack.clear();
    value.value = newValue;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(value.value);
    value.value = _undoStack.removeLast();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(value.value);
    value.value = _redoStack.removeLast();
  }
}
```

---

## Theme Switching

```dart
class ThemePillar extends Pillar {
  late final themeMode = core(ThemeMode.system);
  late final seedColor = core(Colors.blue);

  late final isDark = derived(() {
    switch (themeMode.value) {
      case ThemeMode.dark: return true;
      case ThemeMode.light: return false;
      case ThemeMode.system: return _platformBrightness == Brightness.dark;
    }
  });

  void toggleTheme() {
    themeMode.value = isDark.value ? ThemeMode.light : ThemeMode.dark;
  }
}

// In app root
Vestige<ThemePillar>(
  builder: (context, theme) => MaterialApp(
    themeMode: theme.themeMode.value,
    theme: ThemeData(
      colorSchemeSeed: theme.seedColor.value,
      brightness: Brightness.light,
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: theme.seedColor.value,
      brightness: Brightness.dark,
    ),
    home: HomePage(),
  ),
)
```

---

[← Testing](07-testing.md) · [API Reference →](09-api-reference.md)
