# Oracle — State Observation & Monitoring

Titan's **Oracle** system (`TitanObserver`) provides global visibility into ALL state changes across the entire application. It works with Pillars, standalone Cores, and legacy TitanStores alike.

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