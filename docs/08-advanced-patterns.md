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

## Scroll — Form Management

**Scroll** is Titan's form field primitive — a Core enhanced with validation, dirty tracking, touch state, and reset. **ScrollGroup** aggregates multiple Scrolls into a form.

### Basic Form

```dart
class ProfilePillar extends Pillar {
  late final name = scroll('',
    validator: (v) => v.isEmpty ? 'Name is required' : null,
  );

  late final email = scroll('',
    validator: (v) => v.contains('@') ? null : 'Invalid email',
  );

  late final form = ScrollGroup([name, email]);

  void submit() {
    if (!form.validateAll()) return;
    // All fields valid — process
    api.updateProfile(name: name.value, email: email.value);
  }
}
```

### Reactive Validation in UI

Because `error`, `isDirty`, and `isTouched` are reactive, Vestige auto-tracks them:

```dart
Vestige<ProfilePillar>(
  builder: (context, pillar) => Column(
    children: [
      TextField(
        onChanged: (v) => pillar.name.value = v,
        onEditingComplete: () => pillar.name.touch(),
        decoration: InputDecoration(
          errorText: pillar.name.isTouched ? pillar.name.error : null,
        ),
      ),
      ElevatedButton(
        onPressed: pillar.form.isValid ? pillar.submit : null,
        child: Text('Save'),
      ),
    ],
  ),
)
```

### Server-Side Validation

```dart
Future<void> submit() async {
  if (!form.validateAll()) return;

  try {
    await api.updateProfile(name: name.value, email: email.value);
  } on ValidationException catch (e) {
    // Apply server errors to individual fields
    if (e.errors.containsKey('email')) {
      email.setError(e.errors['email']!);
    }
  }
}
```

---

## Codex — Paginated Data

**Codex** manages paginated data fetching — loading pages incrementally, tracking loading/error/empty states, and appending results. Supports both offset and cursor-based pagination.

### Offset Pagination

```dart
class QuestListPillar extends Pillar {
  late final quests = codex<Quest>(
    (request) async {
      final result = await api.getQuests(
        page: request.page,
        limit: request.pageSize,
      );
      return CodexPage(
        items: result.items,
        hasMore: result.hasMore,
      );
    },
    pageSize: 20,
  );

  @override
  void onInit() => quests.loadFirst();
}
```

### Cursor-Based Pagination

```dart
late final feed = codex<Post>(
  (request) async {
    final result = await api.getFeed(
      cursor: request.cursor,
      limit: request.pageSize,
    );
    return CodexPage(
      items: result.posts,
      hasMore: result.hasMore,
      nextCursor: result.nextCursor,
    );
  },
  pageSize: 10,
);
```

### Infinite Scroll UI

```dart
Vestige<QuestListPillar>(
  builder: (context, pillar) {
    final items = pillar.quests.items.value;
    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200) {
          pillar.quests.loadNext();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: items.length + (pillar.quests.hasMore.value ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= items.length) return const CircularProgressIndicator();
          return QuestTile(items[i]);
        },
      ),
    );
  },
)
```

---

## Quarry — Data Fetching & Caching

**Quarry** manages a single async data resource with stale-while-revalidate caching, automatic deduplication, retry with exponential backoff, and optimistic updates.

### Basic Query

```dart
class UserPillar extends Pillar {
  late final userQuery = quarry<User>(
    fetcher: () => api.getUser(),
    staleTime: Duration(minutes: 5),
  );

  @override
  void onInit() => userQuery.fetch();
}
```

### Stale-While-Revalidate

When data is stale, Quarry returns cached data immediately while refetching in the background:

```dart
late final profile = quarry<Profile>(
  fetcher: () => api.getProfile(),
  staleTime: Duration(minutes: 10),
);

// First call — fetches and caches
await profile.fetch();

// Later — shows cached data, refetches in background
await profile.fetch();
```

### Retry with Backoff

```dart
late final data = quarry<Config>(
  fetcher: () => api.getConfig(),
  retry: QuarryRetry(
    maxAttempts: 3,
    baseDelay: Duration(seconds: 1), // 1s, 2s, 4s (exponential)
  ),
);
```

### Optimistic Updates

```dart
void toggleFavorite(String questId) {
  final current = questQuery.data.value!;
  // Optimistic update — UI reflects immediately
  questQuery.setData(current.copyWith(isFavorite: !current.isFavorite));
  // Sync with server, refetch on failure
  api.toggleFavorite(questId).catchError((_) => questQuery.refetch());
}
```

### Quarry in UI

```dart
Vestige<UserPillar>(
  builder: (context, pillar) {
    if (pillar.userQuery.isLoading.value) {
      return const CircularProgressIndicator();
    }
    if (pillar.userQuery.hasError) {
      return ErrorWidget(pillar.userQuery.error.value!);
    }
    final user = pillar.userQuery.data.value!;
    return Text(user.name);
  },
)
```

---

## Confluence — Multi-Pillar Widgets

**Confluence** combines multiple typed Pillars in a single auto-tracking builder — eliminating nested Vestiges.

### Two Pillars

```dart
Confluence2<AuthPillar, CartPillar>(
  builder: (context, auth, cart) => Text(
    '${auth.user.value?.name}: ${cart.itemCount.value} items',
  ),
)
```

### Three Pillars

```dart
Confluence3<AuthPillar, CartPillar, ThemePillar>(
  builder: (context, auth, cart, theme) => Container(
    color: theme.backgroundColor.value,
    child: Text('${auth.user.value?.name} — ${cart.itemCount.value} items'),
  ),
)
```

### Four Pillars

```dart
Confluence4<AuthPillar, CartPillar, ThemePillar, NavPillar>(
  builder: (context, auth, cart, theme, nav) => Scaffold(
    appBar: AppBar(
      title: Text(nav.currentTitle.value),
      backgroundColor: theme.primaryColor.value,
    ),
    body: Text('${auth.user.value?.name} — ${cart.itemCount.value} items'),
  ),
)
```

### When to Use Confluence vs. Vestige

| Scenario | Widget |
|----------|--------|
| Single Pillar | `Vestige<P>` |
| 2–4 Pillars in one builder | `Confluence2/3/4` |
| Cross-Pillar derived state | Create a `DashboardPillar` with injected deps |

---

## Lens — Debug Overlay

**Lens** wraps your app with a toggleable floating debug panel that displays real-time Pillars, Herald events, Vigil errors, and Chronicle logs.

### Setup

```dart
import 'package:flutter/foundation.dart';

void main() {
  runApp(
    Lens(
      enabled: kDebugMode,
      child: MaterialApp(
        home: MyHomePage(),
      ),
    ),
  );
}
```

When `enabled` is `false`, Lens renders only the child with zero overhead.

### Programmatic Control

```dart
// Open from a debug button or shortcut
Lens.show();

// Close programmatically
Lens.hide();

// Toggle on shake or keyboard shortcut
Lens.toggle();
```

### What Lens Shows

| Tab | Content |
|-----|--------|
| **Pillars** | All registered Pillars (from `Titan.instances`) and their types |
| **Herald** | Recent cross-domain events (last 200) |
| **Vigil** | Captured errors with severity, context, and stack traces |
| **Chronicle** | Structured log output from all Chronicle sinks |

### Using LensLogSink Standalone

```dart
final sink = LensLogSink(maxEntries: 500);
Chronicle.addSink(sink);

// Read captured entries
for (final entry in sink.entries) {
  print('${entry.level}: ${entry.message}');
}

// Clear buffer
sink.clear();
```

---

## Enterprise Features

### Core Extensions

Type-safe convenience methods on `Core<T>` for common mutations:

```dart
final isActive = core(false);
isActive.toggle(); // flips to true

final count = core(0);
count.increment(); // 1
count.decrement(); // 0
count.increment(5); // 5

final items = core(<String>['a', 'b']);
items.add('c'); // ['a', 'b', 'c']
items.removeWhere((s) => s == 'a'); // ['b', 'c']
items.updateWhere((s) => s == 'b', (s) => s.toUpperCase()); // ['B', 'c']

final map = core(<String, int>{'x': 1});
map.putEntry('y', 2); // {'x': 1, 'y': 2}
map.removeKey('x'); // {'y': 2}

final text = core('hello');
text.transform((s) => s.toUpperCase()); // 'HELLO'
```

### Core.select — Granular Subscriptions

Subscribe to a projection of a Core's value — only fires when the selected part changes:

```dart
final user = core(User(name: 'Kael', level: 5));

// Only rebuild when name changes, ignore level changes
user.select((u) => u.name).listen((name) {
  print('Name changed: $name');
});
```

### Debounced & Throttled Strikes

```dart
class SearchPillar extends Pillar {
  late final query = core('');

  // Only executes after 300ms of no input
  late final debouncedSearch = strikeDebounced(
    const Duration(milliseconds: 300),
    (String q) {
      query.value = q;
      _performSearch();
    },
  );

  // At most once per 500ms
  late final throttledRefresh = strikeThrottled(
    const Duration(milliseconds: 500),
    () => _refresh(),
  );
}
```

### Guarded Watch

Watch with an error handler — prevents one failing watcher from crashing the app:

```dart
@override
void onInit() {
  guardedWatch(
    () => expensiveComputation(data.value),
    onError: (error, stack) => log.error('Watch failed: $error'),
  );
}
```

### Pillar Auto-Dispose

Automatically dispose a Pillar when all consuming widgets unmount:

```dart
Titan.put(ChatPillar()..enableAutoDispose());

// ChatPillar will dispose when the last Vestige<ChatPillar> unmounts
```

### onInitAsync — Async Initialization

```dart
class DataPillar extends Pillar {
  late final items = core(<Item>[]);

  @override
  Future<void> onInitAsync() async {
    items.value = await api.fetchAll();
  }
}

// In UI — wait for readiness
Vestige<DataPillar>(
  builder: (context, pillar) {
    if (!pillar.isReady.value) return const CircularProgressIndicator();
    return ItemList(items: pillar.items.value);
  },
)
```

### Aegis — Retry with Backoff

```dart
final result = await Aegis.run(
  () => api.fetchData(),
  maxAttempts: 3,
  baseDelay: const Duration(seconds: 1),
  strategy: BackoffStrategy.exponential,
  retryIf: (error) => error is SocketException,
  onRetry: (attempt, error, nextDelay) {
    log.warning('Retry $attempt: $error (next in $nextDelay)');
  },
);
```

### Sigil — Feature Flags

```dart
// Register flags
Sigil.register('dark_mode', true);
Sigil.register('new_checkout', false);
Sigil.loadAll({'beta_feature': true, 'legacy_ui': false});

// Check
if (Sigil.isEnabled('dark_mode')) { /* ... */ }
if (Sigil.isDisabled('new_checkout')) { /* ... */ }

// Mutate
Sigil.enable('new_checkout');
Sigil.toggle('dark_mode');

// Test overrides
Sigil.override('dark_mode', false);
Sigil.clearOverrides();
```

---

## Loom — Finite State Machines

The Loom enforces controlled state transitions with a transition table:

```dart
enum QuestState { idle, claiming, active, completed }
enum QuestEvent { claim, start, complete, reset }

class QuestPillar extends Pillar {
  late final questFlow = loom<QuestState, QuestEvent>(
    initial: QuestState.idle,
    transitions: {
      (QuestState.idle, QuestEvent.claim): QuestState.claiming,
      (QuestState.claiming, QuestEvent.start): QuestState.active,
      (QuestState.active, QuestEvent.complete): QuestState.completed,
      (QuestState.completed, QuestEvent.reset): QuestState.idle,
    },
    onEnter: {
      QuestState.active: () => log.info('Quest started'),
    },
    onTransition: (from, event, to) {
      log.debug('$from --[$event]--> $to');
    },
  );
}

// Usage
questFlow.send(QuestEvent.claim); // returns true
questFlow.canSend(QuestEvent.complete); // false — not in active state
questFlow.current; // QuestState.claiming
questFlow.allowedEvents; // {QuestEvent.start}
questFlow.history; // [LoomTransition(idle, claim, claiming)]
```

---

## Bulwark — Circuit Breaker

Prevents cascading failures by tracking consecutive errors and short-circuiting when a threshold is reached:

```dart
class ApiPillar extends Pillar {
  late final breaker = bulwark<List<Item>>(
    failureThreshold: 3,
    resetTimeout: const Duration(seconds: 30),
    onOpen: (error) => log.error('Circuit opened: $error'),
    onClose: () => log.info('Circuit recovered'),
  );

  Future<void> fetch() async {
    try {
      final items = await breaker.call(() => api.getItems());
      data.value = items;
    } on BulwarkOpenException catch (e) {
      log.warning('API unavailable (${e.failureCount} failures)');
    }
  }
}

// Manual controls
breaker.trip(); // Force open
breaker.reset(); // Force closed
breaker.state; // BulwarkState.closed/open/halfOpen
```

---

## Saga — Multi-Step Workflows

Sequential async operations with automatic compensation (rollback) on failure:

```dart
class OrderPillar extends Pillar {
  late final checkout = saga<String>(
    steps: [
      SagaStep(
        name: 'reserve-inventory',
        execute: (prev) async {
          await api.reserveItems(cartItems);
          return orderId;
        },
        compensate: (id) async => await api.releaseItems(id!),
      ),
      SagaStep(
        name: 'charge-payment',
        execute: (prev) async {
          await api.chargePayment(prev!, total);
          return prev;
        },
        compensate: (id) async => await api.refundPayment(id!),
      ),
      SagaStep(
        name: 'send-confirmation',
        execute: (prev) async {
          await api.sendEmail(prev!);
          return prev;
        },
      ),
    ],
    onComplete: (result) => log.info('Order $result confirmed'),
    onError: (error, step) => log.error('Order failed at $step'),
    onStepComplete: (name, i, total) => log.info('$name ($i/$total)'),
  );
}

// Execute
final orderId = await pillar.checkout.run();

// Monitor reactively
pillar.checkout.status; // SagaStatus.running
pillar.checkout.progress; // 0.33, 0.66, 1.0
pillar.checkout.currentStepName; // 'charge-payment'
```

---

## Volley — Batch Async Operations

Parallel async tasks with concurrency limits and partial-failure handling:

```dart
class UploadPillar extends Pillar {
  late final uploader = volley<String>(concurrency: 3);

  Future<void> uploadAll(List<File> files) async {
    final tasks = files.map((f) => VolleyTask(
      name: f.name,
      execute: () => api.upload(f),
    )).toList();

    final results = await uploader.execute(tasks);

    final successes = results.where((r) => r.isSuccess).length;
    final failures = results.where((r) => r.isFailure).length;
    log.info('Uploaded $successes, failed $failures');
  }
}

// Progress & cancellation
uploader.progress; // 0.0 to 1.0
uploader.completedCount; // reactive
uploader.cancel(); // stop starting new tasks
```

---

## Annals — Audit Trail

Immutable, append-only record of state mutations for compliance:

```dart
// Enable globally
Annals.enable(maxEntries: 10000);

// Record mutations
Annals.record(AnnalEntry(
  coreName: 'status',
  pillarType: 'OrderPillar',
  oldValue: 'pending',
  newValue: 'shipped',
  action: 'shipOrder',
  userId: 'admin-42',
));

// Query
final changes = Annals.query(
  pillarType: 'OrderPillar',
  action: 'shipOrder',
  after: DateTime.now().subtract(const Duration(hours: 24)),
);

// Export for compliance
final report = Annals.export(after: DateTime(2025, 1, 1));

// Stream real-time
Annals.stream.listen((entry) => sendToSIEM(entry));
```

---

## Tether — Request-Response Channels

Typed, bidirectional async communication between Pillars:

```dart
// Register a handler
Tether.register<String, User?>(
  'getUserById',
  (id) async => await userApi.fetch(id),
  timeout: const Duration(seconds: 5),
);

// Call from another Pillar
final user = await Tether.call<String, User?>('getUserById', 'user-42');

// Safe call (returns null if not registered)
final maybeUser = await Tether.tryCall<String, User?>('getUserById', 'user-42');

// Check availability
Tether.has('getUserById'); // true
Tether.names; // {'getUserById', ...}

// Cleanup
Tether.unregister('getUserById');
```

---

## Crucible — Testing Harness

Structured testing helpers for Pillars:

```dart
late Crucible<MyPillar> crucible;

setUp(() => crucible = Crucible(() => MyPillar()));
tearDown(() => crucible.dispose());

test('tracks changes', () async {
  crucible.track(crucible.pillar.count);

  await crucible.expectStrike(
    () => crucible.pillar.increment(),
    before: () => crucible.expectCore(crucible.pillar.count, 0),
    after: () => crucible.expectCore(crucible.pillar.count, 1),
  );

  expect(crucible.valuesFor(crucible.pillar.count), [1]);
});
```

---

## Snapshot — State Capture & Restore

Capture and compare Pillar state:

```dart
final before = pillar.snapshot(label: 'before');
pillar.updateTitle('New Title');
final after = pillar.snapshot(label: 'after');

// Compare
final diff = Snapshot.diff(before, after);
// {'title': ('Old Title', 'New Title')}

// Restore
pillar.restore(before, notify: true);
```

---

## PillarScope — Scoped Overrides

Override Pillar instances for a widget subtree (testing, previews):

```dart
PillarScope(
  overrides: [mockPillar, testPillar],
  child: const MyScreen(),
)
```

---

## Conduit — Core-Level Middleware

Conduits intercept individual Core value changes — transforming, validating, or rejecting values before they're applied.

### Clamping Values

```dart
class HeroPillar extends Pillar {
  late final health = core(100, conduits: [
    ClampConduit(min: 0, max: 100),
  ]);

  void takeDamage(int amount) => strike(() {
    health.value -= amount; // Clamped to 0 minimum
  });
}
```

### Chaining Conduits

Multiple Conduits execute in FIFO order:

```dart
late final name = core('', conduits: [
  TransformConduit((_, v) => v.trim()),
  TransformConduit((_, v) => v.toLowerCase()),
  ValidateConduit((_, v) => v.isEmpty ? 'Required' : null),
]);
```

### Rejecting Changes

Throw `ConduitRejectedException` to block a value change:

```dart
late final reward = core(100, conduits: [
  ValidateConduit((_, v) => v < 0 ? 'Cannot be negative' : null),
]);

try {
  reward.value = -10;
} on ConduitRejectedException catch (e) {
  print(e.message); // 'Cannot be negative'
}
```

### Freezing State

```dart
late final score = core(0, conduits: [
  FreezeConduit((oldValue, _) => oldValue >= 100),
]);
```

### Dynamic Conduits

```dart
final clamp = ClampConduit<int>(min: 0, max: 100);
health.addConduit(clamp);    // Add at runtime
health.removeConduit(clamp); // Remove later
health.clearConduits();      // Remove all
```

### Custom Conduits

```dart
class AuditConduit<T> extends Conduit<T> {
  final String coreName;
  AuditConduit(this.coreName);

  @override
  T pipe(T oldValue, T newValue) => newValue; // Pass through

  @override
  void onPiped(T oldValue, T newValue) {
    Annals.record(AnnalEntry(
      coreName: coreName,
      pillarType: 'auto',
      oldValue: oldValue,
      newValue: newValue,
      action: 'conduit_change',
    ));
  }
}
```

### Built-in Conduits

| Conduit | Purpose |
|---------|---------|
| `ClampConduit<num>` | Clamps numeric values to min-max range |
| `TransformConduit<T>` | Applies a transformation function |
| `ValidateConduit<T>` | Rejects values that fail validation |
| `FreezeConduit<T>` | Blocks changes once a condition is met |
| `ThrottleConduit<T>` | Rejects changes faster than a minimum interval |

---

## Prism — Fine-Grained State Projections

A Prism creates a read-only, memoized projection from one or more source Cores. Unlike `Derived` (which auto-tracks any reactive read), Prism provides explicit source declarations, multi-source combining with full type safety, and built-in structural equality helpers.

### Single-Source Projection

```dart
class HeroPillar extends Pillar {
  late final hero = core(Hero(name: 'Kael', level: 10, health: 100));

  // Only notifies when name changes — not level or health
  late final heroName = prism(hero, (h) => h.name);
  late final heroLevel = prism(hero, (h) => h.level);
}
```

### Multi-Source Combining

```dart
final heroTitle = Prism.combine2(
  heroName, heroLevel,
  (name, level) => '$name (Lv$level)',
);

// Up to 4 sources
final summary = Prism.combine4(
  name, level, health, mana,
  (n, l, h, m) => '$n Lv$l HP:$h MP:$m',
);
```

### Structural Equality

When projecting collections, use `PrismEquals` for content-based comparison:

```dart
late final achievements = prism(
  hero,
  (h) => h.achievements.toList(),
  equals: PrismEquals.list,
);

// Also available: PrismEquals.set, PrismEquals.map
```

### Composing from Derived

```dart
late final weapons = derived(
  () => items.value.where((i) => i.type == ItemType.weapon).toList(),
);

late final bestWeapon = Prism.fromDerived(
  weapons,
  (list) => list.isEmpty ? 'None' : list.first.name,
);
```

### Extension Method

```dart
final user = Core(User(name: 'Alice', age: 30));
final userName = user.prism((u) => u.name);
```

### Prism vs. Derived

| Aspect | Derived | Prism |
|--------|---------|-------|
| Dependency tracking | Auto (reads inside compute) | Explicit (declared sources) |
| Multi-source | Implicit via reads | Type-safe combine factories |
| Collection equality | Manual `equals` param | `PrismEquals.list/set/map` |
| Use case | Compute new values | Focus on sub-values |

---

## Additional Widgets

### VestigeWhen

Rebuild only when a condition is met:

```dart
VestigeWhen<MyPillar>(
  condition: (pillar) => pillar.isVisible.value,
  builder: (context, pillar) => Text(pillar.message.value),
)
```

### AnimatedVestige

Animate between state changes:

```dart
AnimatedVestige<MyPillar>(
  duration: const Duration(milliseconds: 300),
  builder: (context, pillar, animation) {
    return FadeTransition(
      opacity: animation,
      child: Text(pillar.status.value),
    );
  },
)
```

### VestigeSelector

Rebuild only when a selected value changes:

```dart
VestigeSelector<MyPillar, String>(
  selector: (pillar) => pillar.name.value,
  builder: (context, pillar, name) => Text(name),
)
```

### VestigeListener

Listen for side effects without rebuilding:

```dart
VestigeListener<MyPillar>(
  listener: (context, pillar) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pillar.message.value)),
    );
  },
  child: const MyWidget(),
)
```

### VestigeConsumer

Combines builder + listener:

```dart
VestigeConsumer<MyPillar>(
  listener: (context, pillar) => showDialog(/* ... */),
  builder: (context, pillar) => Text(pillar.data.value),
)
```

---

## Nexus — Reactive Collections

Nexus provides in-place reactive collections (`NexusList`, `NexusMap`, `NexusSet`) that avoid copy-on-write overhead and emit granular change records.

### NexusList

```dart
class TodoPillar extends Pillar {
  late final items = nexusList<String>([], 'items');
  late final count = derived(() => items.length);

  void addItem(String item) => items.add(item);
  void removeAt(int index) => items.removeAt(index);
  void reorder(int from, int to) => items.move(from, to);
}
```

**Key methods**: `add`, `addAll`, `insert`, `[]=`, `remove`, `removeAt`, `removeWhere`, `retainWhere`, `sort`, `replaceRange`, `clear`, `swap`, `move`.

### NexusMap

```dart
late final scores = nexusMap<String, int>({}, 'scores');

// Smart updates
scores['Alice'] = 100;
scores.putIfChanged('Alice', 100); // false — no notification
scores.putIfAbsent('Bob', () => 50);
```

**Key methods**: `[]=`, `putIfChanged`, `putIfAbsent`, `addAll`, `remove`, `removeWhere`, `updateAll`, `clear`.

### NexusSet

```dart
late final tags = nexusSet<String>({'all'}, 'tags');

tags.toggle('featured'); // Add if absent, remove if present
tags.intersection({'all', 'featured', 'new'}); // Read-only
```

**Key methods**: `add`, `addAll`, `remove`, `toggle`, `removeWhere`, `retainWhere`, `clear`, `intersection`, `union`, `difference`.

### Change Records

Every mutation sets `lastChange` for pattern-matching inspection:

```dart
switch (items.lastChange) {
  case NexusInsert(:final index, :final element):
    print('Inserted $element at $index');
  case NexusRemove(:final index, :final element):
    print('Removed $element from $index');
  case NexusUpdate(:final index, :final oldValue, :final newValue):
    print('Updated [$index]: $oldValue → $newValue');
  case NexusClear(:final previousLength):
    print('Cleared $previousLength items');
  case NexusBatch(:final operation, :final count):
    print('$operation affected $count items');
  default: break;
}
```

### Nexus vs Core<List> Performance

| Approach | Cost per Add |
|----------|-------------|
| `Core<List<T>>` + spread | O(n) — copies entire list |
| `NexusList<T>.add()` | O(1) amortized — in-place |

All Nexus types are compatible with `titanBatch()`, `strike()`, `Derived`, and `watch()`.

---

## Spark — Hooks-Style Widgets

Spark eliminates `StatefulWidget` boilerplate with position-based hooks that auto-manage lifecycle, disposal, and reactive rebuilds.

### Basic Spark

```dart
class CounterWidget extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final count = useCore(0);
    final controller = useTextController();

    return Column(children: [
      TextField(controller: controller),
      Text('Count: ${count.value}'),
      ElevatedButton(
        onPressed: () => count.value++,
        child: Text('Increment'),
      ),
    ]);
  }
}
```

### Reactive Hooks

```dart
// useCore — reactive mutable state, auto-rebuilds
final name = useCore('Kael');

// useDerived — auto-tracked computed value
final greeting = useDerived(() => 'Hello, ${name.value}!');
```

### Lifecycle Hooks

```dart
// useEffect with [] — runs once (like initState)
useEffect(() {
  final sub = stream.listen((data) => items.value = data);
  return sub.cancel; // Cleanup
}, []);

// useMemo — memoized expensive computation
final sorted = useMemo(() => List.from(items.value)..sort(), [items.value.length]);

// useRef — mutable reference that doesn't trigger rebuild
final clickCount = useRef(0);
```

### Controller Hooks (Auto-Disposed)

```dart
final textCtrl = useTextController(text: 'initial');
final anim = useAnimationController(duration: Duration(milliseconds: 300));
final focus = useFocusNode();
final scroll = useScrollController();
final tabs = useTabController(length: 3);
final page = usePageController(initialPage: 0);
```

### Pillar Integration

```dart
class HeroCard extends Spark {
  @override
  Widget ignite(BuildContext context) {
    final hero = usePillar<HeroPillar>(context);
    return Text('${hero.name.value} — Level ${hero.level.value}');
  }
}
```

### Hook Rules

1. Always call hooks in the **same order** — no hooks inside conditionals or loops
2. Only call hooks inside `ignite()` — not in callbacks or async code
3. Hooks are identified by call position, just like React hooks

---

[← Testing](07-testing.md) · [API Reference →](09-api-reference.md)
