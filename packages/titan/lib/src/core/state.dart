import 'computed.dart';
import 'observer.dart';
import 'reactive.dart';

/// A mutable reactive state container.
///
/// [TitanState] holds a single value of type [T] and notifies dependents
/// and listeners when the value changes. It is the fundamental building
/// block of Titan's reactive system.
///
/// ## Usage
///
/// ```dart
/// final counter = TitanState(0);
///
/// // Read the value (auto-tracked in reactive scopes)
/// print(counter.value); // 0
///
/// // Update the value (triggers notifications)
/// counter.value = 1;
///
/// // Update with a function
/// counter.update((current) => current + 1);
/// ```
///
/// ## Equality
///
/// By default, notifications are skipped when the new value equals the old
/// value (using `==`). Provide a custom [equals] function for custom
/// comparison logic.
class TitanState<T> extends ReactiveNode {
  T _value;
  T? _previousValue;
  final bool Function(T previous, T next)? _equals;
  final String? _name;

  /// Creates a reactive state with the given initial [value].
  ///
  /// - [name] — Optional debug name for logging/devtools.
  /// - [equals] — Custom equality function. Defaults to `==`.
  TitanState(T value, {String? name, bool Function(T previous, T next)? equals})
    : _value = value,
      _name = name,
      _equals = equals;

  /// The debug name of this state, if provided.
  String? get name => _name;

  /// The current value.
  ///
  /// Reading this inside a [TitanComputed] or [TitanEffect] automatically
  /// registers a dependency.
  T get value {
    track();
    return _value;
  }

  /// The previous value before the most recent change.
  ///
  /// Returns `null` if the value has never been changed. Useful for
  /// animations, transition effects, and "changed from X to Y" UI patterns.
  ///
  /// ```dart
  /// final name = TitanState('Alice');
  /// name.value = 'Bob';
  /// print(name.previousValue); // 'Alice'
  /// ```
  T? get previousValue => _previousValue;

  /// Sets the value. If the new value differs from the current value
  /// (per the equality function), dependents and listeners are notified.
  set value(T newValue) {
    if (_isEqual(_value, newValue)) return;

    final oldValue = _value;
    _previousValue = oldValue;
    _value = newValue;

    // Notify all observers
    TitanObserver.notifyStateChanged(
      state: this,
      oldValue: oldValue,
      newValue: newValue,
    );

    notifyDependents();
  }

  /// Returns the current value without tracking it as a dependency.
  ///
  /// Useful when you need to read the value without triggering
  /// a rebuild on change.
  T peek() => _value;

  /// Updates the value using a transformation function.
  ///
  /// ```dart
  /// counter.update((current) => current + 1);
  /// ```
  void update(T Function(T current) updater) {
    value = updater(_value);
  }

  /// Silently sets the value without notifying dependents.
  ///
  /// Use with caution — this bypasses the reactive system.
  /// Primarily used by [Relic] for hydration (restoring persisted values
  /// without triggering reactive updates).
  void silent(T newValue) {
    _value = newValue;
  }

  /// Listens for value changes with a typed callback.
  ///
  /// Returns a function that removes the listener when called.
  ///
  /// ```dart
  /// final unsub = counter.listen((value) => print(value));
  /// counter.value = 5; // Prints: 5
  /// unsub(); // Stops listening
  /// ```
  void Function() listen(void Function(T value) callback) {
    void listener() => callback(_value);
    addListener(listener);
    return () => removeListener(listener);
  }

  /// Creates a [TitanComputed] that selects a sub-value from this state.
  ///
  /// Only triggers downstream updates when the selected value actually
  /// changes — enabling fine-grained reactivity for complex state objects.
  ///
  /// ```dart
  /// final user = core(User(name: 'Alice', age: 30));
  ///
  /// // Only rebuilds when the name changes, not when age changes
  /// final userName = user.select((u) => u.name);
  /// ```
  TitanComputed<R> select<R>(R Function(T value) selector) {
    return TitanComputed<R>(() => selector(value));
  }

  bool _isEqual(T a, T b) {
    if (_equals != null) return _equals(a, b);
    return a == b;
  }

  @override
  String toString() {
    final label = _name != null ? '($_name)' : '';
    return 'TitanState$label<$T>: $_value';
  }
}
