# Middleware & Observability

Titan provides two complementary systems for cross-cutting concerns:
- **Middleware** — Per-store interception of state changes (used with legacy TitanStore)
- **Observer** — Global state change monitoring (works with all reactive nodes)

## Observer (Recommended)

The `TitanObserver` provides global visibility into ALL state changes across the entire application. This works with Pillars and standalone Cores alike.

### Setting Up

```dart
void main() {
  TitanObserver.instance = TitanLoggingObserver();
  runApp(MyApp());
}
```

### Built-in Observers

#### TitanLoggingObserver

Prints all state changes to the console:

```dart
TitanObserver.instance = TitanLoggingObserver();

// Output:
// [Titan] counter: 0 → 1
// [Titan] username: '' → 'Alice'
```

#### TitanHistoryObserver

Records state changes for time-travel debugging:

```dart
final observer = TitanHistoryObserver(maxHistory: 200);
TitanObserver.instance = observer;

// After some state changes...
for (final record in observer.history) {
  print('${record.name}: ${record.oldValue} → ${record.newValue} '
      'at ${record.timestamp}');
}

observer.clear();
```

### Custom Observer

```dart
class CrashlyticsObserver extends TitanObserver {
  @override
  void onStateChanged<T>(String name, T oldValue, T newValue) {
    FirebaseCrashlytics.instance.log(
      'State [$name]: $oldValue → $newValue',
    );
  }
}
```

### Combining Multiple Observers

```dart
class CompositeObserver extends TitanObserver {
  final List<TitanObserver> observers;

  CompositeObserver(this.observers);

  @override
  void onStateChanged<T>(String name, T oldValue, T newValue) {
    for (final observer in observers) {
      observer.onStateChanged(name, oldValue, newValue);
    }
  }
}

TitanObserver.instance = CompositeObserver([
  TitanLoggingObserver(),
  TitanHistoryObserver(),
  CrashlyticsObserver(),
]);
```

---

## Middleware (Legacy — TitanStore)

Middleware intercepts state changes within a `TitanStore`. For new code using Pillars, prefer the Observer pattern above.

### Creating Middleware

```dart
abstract class TitanMiddleware {
  void onStateChange<T>(StateChangeEvent<T> event);
  void onError(Object error, StackTrace stackTrace);
}
```

### StateChangeEvent

```dart
class StateChangeEvent<T> {
  final String storeName;
  final String stateName;
  final T oldValue;
  final T newValue;
  final DateTime timestamp;
}
```

### Example: Logging Middleware

```dart
class LoggingMiddleware extends TitanMiddleware {
  @override
  void onStateChange<T>(StateChangeEvent<T> event) {
    print('[${event.timestamp}] ${event.storeName}.${event.stateName}: '
        '${event.oldValue} → ${event.newValue}');
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    print('[ERROR] $error\n$stackTrace');
  }
}
```

### Example: Persistence Middleware

```dart
class PersistenceMiddleware extends TitanMiddleware {
  final SharedPreferences prefs;

  PersistenceMiddleware(this.prefs);

  @override
  void onStateChange<T>(StateChangeEvent<T> event) {
    final key = '${event.storeName}.${event.stateName}';
    if (event.newValue is int) {
      prefs.setInt(key, event.newValue as int);
    } else if (event.newValue is String) {
      prefs.setString(key, event.newValue as String);
    } else if (event.newValue is bool) {
      prefs.setBool(key, event.newValue as bool);
    }
  }

  @override
  void onError(Object error, StackTrace stackTrace) {}
}
```

### Registering Middleware

```dart
class UserStore extends TitanStore {
  UserStore() {
    addMiddleware(LoggingMiddleware());
    addMiddleware(PersistenceMiddleware(prefs));
  }
}
```

---

## Observer vs Middleware

| Aspect | Observer | Middleware |
|--------|----------|-----------|
| Scope | Global (all state) | Per-store |
| Works with | Pillars + Cores + Stores | TitanStore only |
| Registration | `TitanObserver.instance = ...` | `store.addMiddleware(...)` |
| Use case | Debugging, analytics, monitoring | Validation, persistence |
| Recommended | ✅ Yes | Legacy pattern |

---

## Debug Mode

```dart
void main() {
  TitanConfig.debugMode = true;
  TitanConfig.enableLogging();
  runApp(MyApp());
}
```

In debug mode:
- State changes are logged to the console
- Performance warnings are shown

---

[← Flutter Integration](05-flutter-integration.md) · [Testing →](07-testing.md)
