import 'package:meta/meta.dart';

import 'reactive.dart';

/// A derived reactive value that automatically tracks its dependencies.
///
/// [TitanComputed] evaluates a computation function and caches the result.
/// It automatically detects which [TitanState] or other [TitanComputed]
/// values are read during computation, and re-evaluates only when those
/// dependencies change.
///
/// ## Usage
///
/// ```dart
/// final firstName = TitanState('John');
/// final lastName = TitanState('Doe');
///
/// final fullName = TitanComputed(
///   () => '${firstName.value} ${lastName.value}',
/// );
///
/// print(fullName.value); // "John Doe"
///
/// firstName.value = 'Jane';
/// print(fullName.value); // "Jane Doe"
/// ```
///
/// ## Lazy Evaluation
///
/// Computed values use lazy evaluation — the computation only runs when
/// the value is actually read and a dependency has changed.
class TitanComputed<T> extends ReactiveNode {
  final T Function() _compute;
  final bool Function(T previous, T next)? _equals;
  final String? _name;

  late T _value;
  bool _isDirty = true;
  final Set<ReactiveNode> _dependencies = {};

  /// Creates a computed reactive value.
  ///
  /// - [compute] — The computation function.
  /// - [name] — Optional debug name.
  /// - [equals] — Custom equality for change detection.
  TitanComputed(
    T Function() compute, {
    String? name,
    bool Function(T previous, T next)? equals,
  })  : _compute = compute,
        _name = name,
        _equals = equals;

  /// The debug name, if provided.
  String? get name => _name;

  /// The current computed value.
  ///
  /// On first access or when dependencies have changed, the computation
  /// runs. The result is cached until the next dependency change.
  T get value {
    track();
    if (_isDirty) {
      _recompute();
    }
    return _value;
  }

  /// Returns the cached value without tracking or recomputation.
  T peek() {
    if (_isDirty) {
      _recompute();
    }
    return _value;
  }

  void _recompute() {
    // Clear old dependency registrations
    _clearDependencies();

    // Push this node as the current tracker
    final previous = ReactiveScope.pushTracker(this);

    try {
      final newValue = _compute();
      _value = newValue;
      _isDirty = false;
    } catch (e) {
      _isDirty = false;
      rethrow;
    } finally {
      ReactiveScope.popTracker(previous);
    }
  }

  void _clearDependencies() {
    for (final dep in _dependencies) {
      dep.removeDependent(this);
    }
    _dependencies.clear();
  }

  @override
  @protected
  void onTracked(ReactiveNode source) {
    _dependencies.add(source);
  }

  @override
  @protected
  void track() {
    // When read inside another computed/effect, register with current tracker
    final tracker = ReactiveScope.currentTracker;
    if (tracker != null && tracker != this) {
      // This computed is being read by another reactive node.
      // We need to both track this as a dependency of the reading node,
      // AND ensure our own value is up-to-date.
      if (_isDirty) {
        _recompute();
      }
    }
    super.track();
  }

  @override
  void onDependencyChanged(ReactiveNode dependency) {
    if (_isDirty) return; // Already marked dirty

    final oldValue = _value;
    _isDirty = true;

    // Eagerly recompute to check if our value actually changed
    _recompute();

    if (!_isEqual(oldValue, _value)) {
      // Value changed — propagate to our dependents
      notifyDependents();
    }
  }

  bool _isEqual(T a, T b) {
    if (_equals != null) return _equals(a, b);
    return a == b;
  }

  @override
  void dispose() {
    _clearDependencies();
    super.dispose();
  }

  @override
  String toString() {
    final label = _name != null ? '($_name)' : '';
    return 'TitanComputed$label<$T>: ${_isDirty ? "(dirty)" : _value}';
  }
}
