import 'computed.dart';
import 'conduit.dart';
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
  List<Conduit<T>>? _conduits;

  /// Creates a reactive state with the given initial [value].
  ///
  /// - [name] — Optional debug name for logging/devtools.
  /// - [equals] — Custom equality function. Defaults to `==`.
  /// - [conduits] — Optional list of [Conduit]s to intercept value changes.
  TitanState(
    T value, {
    String? name,
    bool Function(T previous, T next)? equals,
    List<Conduit<T>>? conduits,
  }) : _value = value,
       _name = name,
       _equals = equals,
       _conduits = conduits != null && conduits.isNotEmpty
           ? List<Conduit<T>>.of(conduits)
           : null;

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

  /// Sets the value. If Conduits are attached, the value is piped through
  /// each before being applied. If the final value differs from the current
  /// value (per the equality function), dependents and listeners are notified.
  ///
  /// Throws [ConduitRejectedException] if any Conduit rejects the change.
  set value(T newValue) {
    // Pipe through conduits
    var piped = newValue;
    final conduits = _conduits;
    if (conduits != null) {
      for (final conduit in conduits) {
        piped = conduit.pipe(_value, piped);
      }
    }

    if (_isEqual(_value, piped)) return;

    final oldValue = _value;
    _previousValue = oldValue;
    _value = piped;

    // Notify all observers
    TitanObserver.notifyStateChanged(
      state: this,
      oldValue: oldValue,
      newValue: piped,
    );

    notifyDependents();

    // Post-change callbacks
    if (conduits != null) {
      for (final conduit in conduits) {
        conduit.onPiped(oldValue, piped);
      }
    }
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

  /// Adds a [Conduit] to this Core's pipeline.
  ///
  /// Conduits are executed in the order they were added (FIFO).
  /// The new conduit will intercept all future value changes.
  ///
  /// ```dart
  /// counter.addConduit(ClampConduit(min: 0, max: 100));
  /// ```
  void addConduit(Conduit<T> conduit) {
    (_conduits ??= []).add(conduit);
  }

  /// Removes a previously added [Conduit].
  ///
  /// Returns `true` if the conduit was found and removed.
  bool removeConduit(Conduit<T> conduit) {
    return _conduits?.remove(conduit) ?? false;
  }

  /// Removes all Conduits from this Core.
  void clearConduits() {
    _conduits?.clear();
  }

  /// The list of currently attached Conduits (read-only view).
  List<Conduit<T>> get conduits => List.unmodifiable(_conduits ?? const []);

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
