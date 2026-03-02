import 'package:meta/meta.dart';

import '../errors/vigil.dart';
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
  T? _previousValue;
  bool _isDirty = true;
  Set<ReactiveNode> _dependencies = {};
  bool _hasEverComputed = false;

  /// Creates a computed reactive value.
  ///
  /// - [compute] — The computation function.
  /// - [name] — Optional debug name.
  /// - [equals] — Custom equality for change detection.
  TitanComputed(
    T Function() compute, {
    String? name,
    bool Function(T previous, T next)? equals,
  }) : _compute = compute,
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

  /// The previous computed value before the most recent recomputation
  /// that produced a different result.
  ///
  /// Returns `null` if the value has never changed. Useful for
  /// animations, transition effects, and "changed from X to Y" patterns.
  ///
  /// ```dart
  /// final total = derived(() => items.value.fold(0, (a, b) => a + b));
  /// // After items change triggers recomputation:
  /// print(total.previousValue); // previous total
  /// ```
  T? get previousValue => _previousValue;

  void _recompute() {
    if (_hasEverComputed) {
      // Fast path: re-evaluate without clearing dependencies.
      // Track new dependencies in a temporary set, then diff.
      final oldDeps = _dependencies;
      _dependencies = {};

      final previous = ReactiveScope.pushTracker(this);
      try {
        final newValue = _compute();
        _value = newValue;
        _isDirty = false;
      } catch (e, stackTrace) {
        _isDirty = false;
        // Restore old deps on error to avoid leaking
        _dependencies = oldDeps;
        Vigil.capture(
          e,
          stackTrace: stackTrace,
          context: ErrorContext(
            source: TitanComputed,
            action: 'recompute',
            metadata: {'name': _name ?? 'unnamed'},
          ),
        );
        rethrow;
      } finally {
        ReactiveScope.popTracker(previous);
      }

      // Remove stale dependencies only (ones in old but not in new)
      for (final dep in oldDeps) {
        if (!_dependencies.contains(dep)) {
          dep.removeDependent(this);
        }
      }
      // Add new dependencies only (ones in new but not in old)
      // Already registered via onTracked during _compute()
    } else {
      // First computation: no dependencies to diff against
      _hasEverComputed = true;
      final previous = ReactiveScope.pushTracker(this);
      try {
        final newValue = _compute();
        _value = newValue;
        _isDirty = false;
      } catch (e, stackTrace) {
        _isDirty = false;
        Vigil.capture(
          e,
          stackTrace: stackTrace,
          context: ErrorContext(
            source: TitanComputed,
            action: 'recompute',
            metadata: {'name': _name ?? 'unnamed'},
          ),
        );
        rethrow;
      } finally {
        ReactiveScope.popTracker(previous);
      }
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
      _previousValue = oldValue;
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
