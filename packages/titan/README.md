<p align="center">
  <div style="width:100%; height:220px; overflow:hidden;">
    <img 
      src="https://raw.githubusercontent.com/Ikolvi/titan/main/assets/titan_banner.webp" 
      alt="Titan Banner" 
      style="width:100%; height:100%; object-fit:cover; object-position:center;"
    />
  </div>
</p>

# Titan

**Total Integrated Transfer Architecture Network**

A signal-based reactive state management engine for Dart & Flutter — fine-grained reactivity, zero boilerplate, surgical rebuilds.

[![pub package](https://img.shields.io/pub/v/titan.svg)](https://pub.dev/packages/titan)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/Ikolvi/titan/blob/main/LICENSE)
[![Dart](https://img.shields.io/badge/Dart-%5E3.10-blue)](https://dart.dev)

---

## The Titan Lexicon

| Standard Term | Titan Name | Description |
|---------------|------------|-------------|
| Store / Bloc | **Pillar** | Structured state module with lifecycle |
| State | **Core** | Reactive mutable state |
| Computed | **Derived** | Auto-computed from Cores, cached, lazy |
| Dispatch / Add | **Strike** | Batched, tracked mutations |
| Side Effect | **Watch** | Reactive side effect — re-runs on change |
| Global DI | **Titan** | Global Pillar registry |
| Observer | **Oracle** | All-seeing state monitor |
| DI Container | **Vault** | Hierarchical dependency container |
| Module | **Forge** | Dependency assembly unit |
| Config | **Edict** | Global Titan configuration |
| Event Bus | **Herald** | Cross-domain Pillar messaging |
| Error Tracking | **Vigil** | Centralized error capture & handlers |
| Logger | **Chronicle** | Structured logging with pluggable sinks |
| Undo/Redo | **Epoch** | Core with time-travel history |
| Stream Operators | **Flux** | Debounce, throttle, asStream |
| Persistence | **Relic** | Auto-save & hydrate Cores |
| Async Data | **Ether** | Loading / error / data wrapper |
| Form Field | **Scroll** | Reactive form field with validation |
| Form Group | **ScrollGroup** | Aggregate form state |
| Pagination | **Codex** | Paginated data with reactive state |
| Data Query | **Quarry** | Cached data fetching (SWR) |
| Middleware | **Conduit** | Core-level pipeline — transform, validate, reject |
| State Selector | **Prism** | Fine-grained, memoized state projections |
| Reactive Collection | **Nexus** | In-place reactive List, Map, Set with change records |

---

## Quick Start

```bash
dart pub add titan
# or for Flutter projects:
# flutter pub add titan
```

Or see the latest version on [pub.dev](https://pub.dev/packages/titan/install).

### Define a Pillar

```dart
import 'package:titan/titan.dart';

class CounterPillar extends Pillar {
  late final count = core(0);
  late final doubled = derived(() => count.value * 2);
  late final isEven = derived(() => count.value % 2 == 0);

  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
  void reset() => strike(() => count.value = 0);
}
```

### Use It (Pure Dart)

```dart
final counter = CounterPillar();

print(counter.count.value);    // 0
print(counter.doubled.value);  // 0

counter.increment();
print(counter.count.value);    // 1
print(counter.doubled.value);  // 2
print(counter.isEven.value);   // false

counter.dispose();
```

### Standalone Signals

```dart
final count = Core(0);
final doubled = Derived(() => count.value * 2);

count.value = 5;
print(doubled.value); // 10
```

---

## Key Features

### Fine-Grained Reactivity

Each `Core` is an independent reactive node. Reading `.value` inside a `Derived` auto-registers the dependency. Only dependents of changed Cores recompute — nothing else.

### Strike — Batched Mutations

```dart
// Inside a Pillar:
void updateProfile() => strike(() {
  name.value = 'Alice';
  age.value = 30;
  role.value = 'Admin';
});
// Dependents recompute ONCE, not three times

// Standalone (outside a Pillar):
titanBatch(() {
  name.value = 'Alice';
  age.value = 30;
});
```

### Watch — Reactive Side Effects

```dart
class AuthPillar extends Pillar {
  late final user = core<User?>(null);
  late final isLoggedIn = derived(() => user.value != null);

  @override
  void onInit() {
    watch(() {
      if (isLoggedIn.value) {
        analytics.track('logged_in');
      }
    });
  }
}
```

### Lifecycle

```dart
class DataPillar extends Pillar {
  @override
  void onInit() {
    // Called once after construction
  }

  @override
  void onDispose() {
    // Called on dispose — cleanup resources
  }
}
```

### Herald — Cross-Pillar Events

```dart
// Define events (plain Dart classes)
class UserLoggedIn {
  final String userId;
  UserLoggedIn(this.userId);
}

// In AuthPillar — emit events
void login() {
  // ... authenticate ...
  emit(UserLoggedIn(user.id));
}

// In CartPillar — listen for events (auto-disposed)
@override
void onInit() {
  listen<UserLoggedIn>((event) {
    strike(() => loadCartForUser(event.userId));
  });
}

// Or use Herald directly
Herald.emit(UserLoggedIn('abc'));
Herald.on<UserLoggedIn>((e) => print(e.userId));
Herald.once<AppReady>((_) => startUp());
final last = Herald.last<UserLoggedIn>(); // Replay
```

### Global DI

```dart
Titan.put(AuthPillar());
final auth = Titan.get<AuthPillar>();
Titan.remove<AuthPillar>();
Titan.reset(); // Remove all
```

### AsyncValue (Ether)

```dart
late final users = core(AsyncValue<List<User>>.loading());

Future<void> loadUsers() async {
  users.value = AsyncValue.loading();
  try {
    final data = await api.fetchUsers();
    users.value = AsyncValue.data(data);
  } catch (e) {
    users.value = AsyncValue.error(e);
  }
}

// Pattern match
users.value.when(
  data: (list) => print('Got ${list.length} users'),
  loading: () => print('Loading...'),
  error: (e) => print('Error: $e'),
);
```

### Vigil — Centralized Error Tracking

```dart
// Add handlers (console, Crashlytics, Sentry, etc.)
Vigil.addHandler(ConsoleErrorHandler());
Vigil.addHandler(myCrashlyticsHandler);

// Errors in strikeAsync are auto-captured with Pillar context
Future<void> loadData() => strikeAsync(() async {
  final data = await api.fetchData(); // If this throws → auto-captured
  items.value = data;
});

// Manual capture with context
try {
  await riskyOperation();
} catch (e, s) {
  captureError(e, stackTrace: s, action: 'riskyOperation');
}

// Query error history
final fatals = Vigil.bySeverity(ErrorSeverity.fatal);
final authErrors = Vigil.bySource(AuthPillar);
final lastError = Vigil.lastError;

// Guarded execution (captures error, returns null on failure)
final result = Vigil.guard(() => parseConfig(raw));
final users = await Vigil.guardAsync(() => api.fetchUsers());
```

### Oracle — Global Observer

```dart
class LoggingOracle extends TitanObserver {
  @override
  void onStateChange(String name, dynamic prev, dynamic next) {
    print('$name: $prev → $next');
  }
}

TitanConfig.observer = LoggingOracle();
```

### Chronicle — Structured Logging

```dart
class AuthPillar extends Pillar {
  @override
  void onInit() {
    log.info('AuthPillar initialized');  // auto-named 'AuthPillar'
  }

  Future<void> login(String email) async {
    log.debug('Attempting login', {'email': email});
    try {
      final user = await api.login(email);
      log.info('Login successful');
    } catch (e, s) {
      log.error('Login failed', e, s);
    }
  }
}

// Configure globally
Chronicle.level = LogLevel.info;     // Suppress trace/debug
Chronicle.addSink(MyFileSink());     // Custom output
```

### Epoch — Undo/Redo History

```dart
class EditorPillar extends Pillar {
  late final text = epoch('');            // Core with history!
  late final fontSize = epoch(14.0);

  void type(String s) => strike(() => text.value = s);
  void undo() => text.undo();
  void redo() => text.redo();
  // text.canUndo, text.canRedo, text.history
}
```

### Flux — Stream Operators

```dart
class SearchPillar extends Pillar {
  late final query = core('');
  late final debouncedQuery = query.debounce(Duration(milliseconds: 300));

  // Also: query.throttle(), query.asStream(), query.onChange
}
```

### Relic — Persistence & Hydration

```dart
class SettingsPillar extends Pillar {
  late final theme = core('light');
  late final relic = Relic(
    adapter: sharedPrefsAdapter,
    entries: {
      'theme': RelicEntry(core: theme, toJson: (v) => v, fromJson: (v) => v as String),
    },
  );

  @override
  void onInit() async {
    await relic.hydrate();        // Restore from storage
    relic.enableAutoSave();       // Auto-persist on changes
  }
}
```

### Scroll — Form Management

```dart
class LoginPillar extends Pillar {
  late final email = scroll<String>('',
    validator: (v) => v.contains('@') ? null : 'Invalid email',
  );
  late final password = scroll<String>('',
    validator: (v) => v.length >= 8 ? null : 'Min 8 characters',
  );
  late final form = ScrollGroup([email, password]);

  void submit() {
    if (form.validateAll()) { /* submit */ }
  }
}
```

### Codex — Pagination

```dart
class ItemListPillar extends Pillar {
  late final items = codex<Item>(
    (req) async {
      final result = await api.getItems(page: req.page, limit: req.pageSize);
      return CodexPage(items: result.items, hasMore: result.hasMore);
    },
    pageSize: 20,
  );

  @override
  void onInit() => items.loadFirst();
}
```

### Quarry — Data Fetching

```dart
class ProfilePillar extends Pillar {
  late final profile = quarry<User>(
    fetcher: () => api.getProfile(),
    staleTime: Duration(minutes: 5),
    retry: QuarryRetry(maxAttempts: 3),
  );

  @override
  void onInit() => profile.fetch();
}
```

### Nexus — Reactive Collections

```dart
class InventoryPillar extends Pillar {
  late final items = nexusList<String>(['sword', 'shield']);
  late final tags = nexusSet<String>({'equipped'});
  late final stats = nexusMap<String, int>({'hp': 100});

  late final itemCount = derived(() => items.length);

  void addItem(String item) => items.add(item); // In-place O(1)
  void toggleTag(String tag) => tags.toggle(tag);
}
```

In-place mutations, no copy-on-write. Granular `NexusChange` records for pattern matching.

---

## Why Titan?

| Feature | Provider | Bloc | Riverpod | GetX | **Titan** |
|---------|----------|------|----------|------|-----------|
| Fine-grained reactivity | ❌ | ❌ | ⚠️ | ⚠️ | ✅ |
| Zero boilerplate | ✅ | ❌ | ⚠️ | ✅ | ✅ |
| Auto-tracking rebuilds | ❌ | ❌ | ❌ | ❌ | ✅ |
| Structured scalability | ⚠️ | ✅ | ✅ | ❌ | ✅ |
| Lifecycle management | ❌ | ✅ | ✅ | ⚠️ | ✅ |
| Scoped + Global DI | ❌ | ⚠️ | ✅ | ❌ | ✅ |
| Pure Dart core | ❌ | ✅ | ✅ | ❌ | ✅ |
| Undo/Redo built-in | ❌ | ❌ | ❌ | ❌ | ✅ |
| Persistence layer | ❌ | ⚠️ | ❌ | ❌ | ✅ |
| Structured logging | ❌ | ❌ | ❌ | ❌ | ✅ |
| Form management | ❌ | ❌ | ❌ | ❌ | ✅ |
| Pagination | ❌ | ❌ | ❌ | ❌ | ✅ |
| SWR data fetching | ❌ | ❌ | ❌ | ❌ | ✅ |
| State middleware | ❌ | ❌ | ❌ | ❌ | ✅ |
| Reactive collections | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## Testing — Pure Dart

```dart
test('counter pillar works', () {
  final counter = CounterPillar();
  expect(counter.count.value, 0);

  counter.increment();
  expect(counter.count.value, 1);
  expect(counter.doubled.value, 2);

  counter.dispose();
});
```

---

## Packages

| Package | Description |
|---------|-------------|
| **`titan`** | Core reactive engine — pure Dart (this package) |
| [`titan_bastion`](https://pub.dev/packages/titan_bastion) | Flutter widgets (Vestige, Beacon) |
| [`titan_atlas`](https://pub.dev/packages/titan_atlas) | Routing & navigation (Atlas) |

## Documentation

| Guide | Link |
|-------|------|
| Introduction | [01-introduction.md](https://github.com/Ikolvi/titan/blob/main/docs/01-introduction.md) |
| Getting Started | [02-getting-started.md](https://github.com/Ikolvi/titan/blob/main/docs/02-getting-started.md) |
| Core Concepts | [03-core-concepts.md](https://github.com/Ikolvi/titan/blob/main/docs/03-core-concepts.md) |
| Pillars | [04-stores.md](https://github.com/Ikolvi/titan/blob/main/docs/04-stores.md) |
| Flutter Integration | [05-flutter-integration.md](https://github.com/Ikolvi/titan/blob/main/docs/05-flutter-integration.md) |
| Oracle & Observation | [06-middleware.md](https://github.com/Ikolvi/titan/blob/main/docs/06-middleware.md) |
| Testing | [07-testing.md](https://github.com/Ikolvi/titan/blob/main/docs/07-testing.md) |
| Advanced Patterns | [08-advanced-patterns.md](https://github.com/Ikolvi/titan/blob/main/docs/08-advanced-patterns.md) |
| API Reference | [09-api-reference.md](https://github.com/Ikolvi/titan/blob/main/docs/09-api-reference.md) |
| Migration Guide | [10-migration-guide.md](https://github.com/Ikolvi/titan/blob/main/docs/10-migration-guide.md) |
| Architecture | [11-architecture.md](https://github.com/Ikolvi/titan/blob/main/docs/11-architecture.md) |
| Atlas Routing | [12-atlas-routing.md](https://github.com/Ikolvi/titan/blob/main/docs/12-atlas-routing.md) |
| **Chronicles of Titan** | **[Story-driven tutorial](https://github.com/Ikolvi/titan/blob/main/docs/story/README.md)** |

## License

MIT — [Ikolvi](https://ikolvi.com)
