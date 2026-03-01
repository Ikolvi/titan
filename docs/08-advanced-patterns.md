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

## Herald — Cross-Pillar Communication

The **Herald** is Titan's event bus — a fire-and-forget messaging system for decoupled communication between Pillars.

### Why Herald?

- **No direct references** — Pillars communicate without importing each other
- **Type-safe** — Events are dispatched and received by Dart type
- **Managed lifecycle** — Pillar subscriptions auto-cancel on dispose
- **Replay** — Late subscribers can read the last emitted event

### Define Events

Events are plain Dart classes:

```dart
class UserLoggedIn {
  final String userId;
  final String email;
  UserLoggedIn({required this.userId, required this.email});
}

class UserLoggedOut {}

class OrderPlaced {
  final List<CartItem> items;
  final double total;
  OrderPlaced({required this.items, required this.total});
}
```

### Emit & Listen in Pillars

```dart
class AuthPillar extends Pillar {
  late final user = core<User?>(null);

  Future<void> login(String email, String password) async {
    final response = await api.login(email, password);
    strike(() => user.value = response.user);

    // Broadcast to any interested Pillar
    emit(UserLoggedIn(userId: response.user.id, email: email));
  }

  void logout() {
    strike(() => user.value = null);
    emit(UserLoggedOut());
  }
}

class CartPillar extends Pillar {
  late final items = core<List<CartItem>>([]);

  @override
  void onInit() {
    // Auto-disposed when CartPillar is disposed
    listen<UserLoggedOut>((_) {
      strike(() => items.value = []);
    });
  }

  void checkout() {
    final order = items.value;
    processPayment(order);
    emit(OrderPlaced(items: order, total: calculateTotal(order)));
    strike(() => items.value = []);
  }
}

class AnalyticsPillar extends Pillar {
  @override
  void onInit() {
    listen<UserLoggedIn>((e) => track('login', {'user': e.userId}));
    listen<UserLoggedOut>((_) => track('logout'));
    listen<OrderPlaced>((e) => track('order', {'total': e.total}));
  }
}
```

### One-Shot Listeners

```dart
@override
void onInit() {
  // Only fires once, then auto-cancels
  listenOnce<AppInitialized>((_) {
    loadInitialData();
  });
}
```

### Using Herald Directly

You can also use Herald outside of Pillars:

```dart
// Subscribe
final sub = Herald.on<UserLoggedIn>((e) => print(e.userId));

// One-shot
Herald.once<AppReady>((_) => startUp());

// Get a stream for advanced composition
Herald.stream<OrderPlaced>()
    .where((e) => e.total > 100)
    .listen((e) => notifyManager(e));

// Replay last event
final lastLogin = Herald.last<UserLoggedIn>();

// Check for listeners
if (Herald.hasListeners<OrderPlaced>()) { ... }

// Cleanup (tests)
Herald.reset();
```

---

## Vigil — Centralized Error Tracking

**Vigil** is Titan's centralized error tracking system — capture, contextualize, and route errors to any number of pluggable handlers.

### Setup

```dart
void main() {
  // Add error handlers
  Vigil.addHandler(ConsoleErrorHandler());
  Vigil.addHandler(mySentryHandler);

  // Optional: only send fatal errors to Crashlytics
  Vigil.addHandler(FilteredErrorHandler(
    filter: (e) => e.severity == ErrorSeverity.fatal,
    handler: CrashlyticsHandler(),
  ));

  runApp(const MyApp());
}
```

### Auto-Capture in Pillars

`strikeAsync` automatically captures errors via Vigil with the Pillar's type as context:

```dart
class DataPillar extends Pillar {
  late final items = core<List<Item>>([]);

  Future<void> loadItems() => strikeAsync(() async {
    final data = await api.fetchItems(); // Error → auto-captured
    items.value = data;
  });
}
```

### Manual Capture

```dart
class PaymentPillar extends Pillar {
  Future<void> processPayment(Order order) async {
    try {
      await gateway.charge(order);
    } catch (e, s) {
      captureError(
        e,
        stackTrace: s,
        severity: ErrorSeverity.fatal,
        action: 'processPayment',
        metadata: {'orderId': order.id, 'amount': order.total},
      );
      rethrow;
    }
  }
}
```

### Guarded Execution

```dart
// Returns null on failure (error captured silently)
final config = Vigil.guard(() => parseConfig(rawData));

// Async version
final users = await Vigil.guardAsync(() => api.fetchUsers());

// Capture AND rethrow
try {
  await Vigil.captureAndRethrow(() => api.deleteUser(id));
} catch (e) {
  showErrorSnackbar(e.toString());
}
```

### Error History & Querying

```dart
// Get all errors
final allErrors = Vigil.history;

// Last error
final latest = Vigil.lastError;

// Filter by severity
final fatals = Vigil.bySeverity(ErrorSeverity.fatal);

// Filter by source Pillar
final authErrors = Vigil.bySource(AuthPillar);

// Real-time error stream
Vigil.errors.listen((error) {
  if (error.severity == ErrorSeverity.fatal) {
    showEmergencyDialog(error);
  }
});
```

### Custom Error Handler

```dart
class SentryHandler extends ErrorHandler {
  @override
  void handle(TitanError error) {
    Sentry.captureException(
      error.error,
      stackTrace: error.stackTrace,
      hint: Hint.withMap({
        'source': error.context?.source?.toString(),
        'action': error.context?.action,
        'severity': error.severity.name,
      }),
    );
  }
}
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

## Undo/Redo with Epoch

**Epoch** provides built-in undo/redo for any Core — no manual stack management needed:

```dart
class EditorPillar extends Pillar {
  late final text = epoch('');           // Core with history
  late final fontSize = epoch(14.0);

  void type(String content) => strike(() => text.value = content);
  void changeFontSize(double size) => strike(() => fontSize.value = size);

  void undo() => text.undo();
  void redo() => text.redo();
}
```

Use in UI:

```dart
Vestige<EditorPillar>(
  builder: (context, editor) => Column(
    children: [
      TextField(onChanged: editor.type),
      Row(
        children: [
          IconButton(
            onPressed: editor.text.canUndo ? editor.undo : null,
            icon: Icon(Icons.undo),
          ),
          IconButton(
            onPressed: editor.text.canRedo ? editor.redo : null,
            icon: Icon(Icons.redo),
          ),
        ],
      ),
    ],
  ),
)
```

Configure max history depth:

```dart
late final text = epoch('', maxHistory: 200);
```

---

## Chronicle — Structured Logging

**Chronicle** provides named loggers with pluggable sinks:

```dart
class AuthPillar extends Pillar {
  @override
  void onInit() {
    log.info('AuthPillar initialized');    // auto-named 'AuthPillar'
  }

  Future<void> login(String email) async {
    log.debug('Attempting login', {'email': email});
    try {
      final user = await api.login(email);
      log.info('Login successful', {'userId': user.id});
    } catch (e, s) {
      log.error('Login failed', e, s);
    }
  }
}
```

### Custom Sinks

```dart
class FileLogSink extends LogSink {
  final File file;
  FileLogSink(this.file);

  @override
  void write(LogEntry entry) {
    file.writeAsStringSync('${entry}\n', mode: FileMode.append);
  }
}

// Register on startup
Chronicle.addSink(FileLogSink(File('app.log')));
Chronicle.level = LogLevel.info;  // Suppress trace/debug
```

### Standalone Loggers

```dart
final log = Chronicle('MyService');
log.info('Service started');
log.warning('Low memory');
log.error('Connection failed', error, stack);
```

---

## Flux — Stream Operators

**Flux** provides debounce, throttle, and stream conversion for Cores:

### Debounced Search

```dart
class SearchPillar extends Pillar {
  late final query = core('');
  late final debouncedQuery = query.debounce(
    Duration(milliseconds: 300),
  );
  late final results = core<List<String>>([]);

  @override
  void onInit() {
    watch(() {
      final q = debouncedQuery.value;
      if (q.isNotEmpty) _performSearch(q);
    });
  }

  void updateQuery(String q) => strike(() => query.value = q);

  Future<void> _performSearch(String q) async {
    final data = await api.search(q);
    strike(() => results.value = data);
  }
}
```

### Throttled Slider

```dart
class SliderPillar extends Pillar {
  late final rawValue = core(0.0);
  late final displayValue = rawValue.throttle(
    Duration(milliseconds: 100),
  );

  void onChanged(double v) => strike(() => rawValue.value = v);
}
```

### Core to Stream

```dart
final count = TitanState(0);

// Typed stream from any Core
count.asStream().listen((value) => print('Count: $value'));

// Change signals from any ReactiveNode
count.onChange.listen((_) => print('Something changed'));
```

---

## Relic — Persistence & Hydration

**Relic** auto-saves and restores Core values across sessions:

### Setup

```dart
class SettingsPillar extends Pillar {
  late final theme = core('light');
  late final locale = core('en');
  late final fontSize = core(14.0);

  late final relic = Relic(
    adapter: prefsAdapter,  // Your RelicAdapter implementation
    entries: {
      'theme': RelicEntry(
        core: theme,
        toJson: (v) => v,
        fromJson: (v) => v as String,
      ),
      'locale': RelicEntry(
        core: locale,
        toJson: (v) => v,
        fromJson: (v) => v as String,
      ),
      'fontSize': RelicEntry(
        core: fontSize,
        toJson: (v) => v,
        fromJson: (v) => (v as num).toDouble(),
      ),
    },
  );

  @override
  void onInit() async {
    await relic.hydrate();       // Restore saved values
    relic.enableAutoSave();      // Auto-persist on changes
  }

  @override
  void onDispose() {
    relic.dispose();
  }
}
```

### Implementing a RelicAdapter

```dart
class SharedPrefsAdapter extends RelicAdapter {
  final SharedPreferences prefs;
  SharedPrefsAdapter(this.prefs);

  @override
  Future<String?> read(String key) async => prefs.getString(key);

  @override
  Future<void> write(String key, String value) async =>
      prefs.setString(key, value);

  @override
  Future<void> delete(String key) async => prefs.remove(key);
}
```

### Complex Types

```dart
'user': RelicEntry<User>(
  core: currentUser,
  toJson: (u) => {'name': u.name, 'email': u.email},
  fromJson: (json) {
    final map = json as Map<String, dynamic>;
    return User(name: map['name'], email: map['email']);
  },
),
```

---

## Atlas + Herald Integration

Use **HeraldAtlasObserver** to broadcast navigation events across your app:

### Setup

```dart
final router = Atlas(
  passages: [...],
  observers: [HeraldAtlasObserver()],
);
```

### Listen for Route Changes

```dart
class AnalyticsPillar extends Pillar {
  @override
  void onInit() {
    listen<AtlasRouteChanged>((event) {
      analytics.trackPageView(event.to.path);
      if (event.type == AtlasNavigationType.push) {
        analytics.trackNavigation(
          from: event.from?.path,
          to: event.to.path,
        );
      }
    });

    listen<AtlasRouteNotFound>((event) {
      log.warning('404: ${event.path}');
      analytics.track('page_not_found', {'path': event.path});
    });

    listen<AtlasGuardRedirect>((event) {
      log.info('Guard redirect: ${event.originalPath} → ${event.redirectPath}');
    });
  }
}
```

### Available Events

| Event | Emitted When |
|-------|-------------|
| `AtlasRouteChanged` | Any navigation (push, pop, replace, reset) |
| `AtlasGuardRedirect` | A Sentinel redirects navigation |
| `AtlasDriftRedirect` | A global Drift redirects navigation |
| `AtlasRouteNotFound` | No Passage matches the requested path |

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
