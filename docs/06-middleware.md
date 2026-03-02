# Oracle & Conduit — Observation & Middleware

Titan provides two complementary middleware systems:

- **Oracle** (`TitanObserver`) — global observation of ALL state changes
- **Conduit** — per-Core value interceptors that transform, validate, or constrain values

---

## Oracle — Global State Observation

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

## Conduit — Core-Level Middleware

**Conduits** intercept value changes at the `Core` level before the value is stored. Use them to clamp ranges, validate input, transform values, or freeze state.

### Built-in Conduits

#### ClampConduit

Constrains numeric values to a range:

```dart
late final health = core(100, conduits: [
  ClampConduit(min: 0, max: 100),
]);

health.value = 150; // stored as 100
health.value = -10; // stored as 0
```

#### ValidateConduit

Rejects values that fail validation (value remains unchanged):

```dart
late final age = core(0, conduits: [
  ValidateConduit((v) => v >= 0 && v <= 150, 'Invalid age'),
]);

age.value = -1;  // rejected, stays 0
age.value = 25;  // accepted
```

#### FreezeConduit

Prevents any further changes once activated:

```dart
late final finalScore = core(0, conduits: [
  FreezeConduit(),
]);

finalScore.value = 42; // accepted
// FreezeConduit now blocks further changes
```

#### ThrottleConduit

Rate-limits value changes:

```dart
late final position = core(0.0, conduits: [
  ThrottleConduit(const Duration(milliseconds: 16)),
]);
```

### Custom Conduits

Write your own by extending `Conduit<T>`:

```dart
class RoundConduit extends Conduit<double> {
  final int decimals;
  RoundConduit(this.decimals);

  @override
  double intercept(double oldValue, double newValue) {
    final factor = pow(10, decimals);
    return (newValue * factor).roundToDouble() / factor;
  }
}

late final price = core(0.0, conduits: [
  RoundConduit(2),
  ClampConduit(min: 0, max: 9999.99),
]);
```

### Conduit Chain

Multiple conduits run in order. Each conduit receives the output of the previous one:

```dart
late final volume = core(50, conduits: [
  ValidateConduit((v) => v is int, 'Must be int'), // runs first
  ClampConduit(min: 0, max: 100),                   // runs second
]);
```

### TransformConduit

Apply arbitrary transformations:

```dart
late final name = core('', conduits: [
  TransformConduit((old, val) => val.trim().toLowerCase()),
]);
```

---

[← Flutter Integration](05-flutter-integration.md) · [Testing →](07-testing.md)