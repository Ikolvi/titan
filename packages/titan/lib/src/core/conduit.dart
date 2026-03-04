/// Conduit — A pipeline that intercepts individual Core state changes.
///
/// While [StrikeMiddleware] intercepts batched mutations at the Pillar level,
/// **Conduit** operates on individual [Core] value assignments — enabling
/// per-field transformation, validation, clamping, and logging.
///
/// ## How It Works
///
/// When a [Core]'s value is set, each attached Conduit's [pipe] method is
/// called in order (FIFO). Each Conduit receives the old value and the
/// (possibly already-transformed) new value, and returns the value to pass
/// to the next Conduit (or to apply). After all Conduits pipe the value,
/// [onPiped] callbacks fire in order.
///
/// ## Usage
///
/// ```dart
/// class ClampToHundred extends Conduit<int> {
///   @override
///   int pipe(int oldValue, int newValue) => newValue.clamp(0, 100);
/// }
///
/// final health = Core<int>(100, conduits: [ClampToHundred()]);
/// health.value = 200; // Clamped to 100
/// health.value = -5;  // Clamped to 0
/// ```
///
/// ## Rejecting Changes
///
/// Throw [ConduitRejectedException] from [pipe] to prevent the change:
///
/// ```dart
/// class PositiveOnly extends Conduit<int> {
///   @override
///   int pipe(int oldValue, int newValue) {
///     if (newValue < 0) throw ConduitRejectedException(
///       message: 'Value must be positive',
///       rejectedValue: newValue,
///     );
///     return newValue;
///   }
/// }
/// ```
library;

// ---------------------------------------------------------------------------
// Conduit — Core-level middleware
// ---------------------------------------------------------------------------

/// A pipeline stage that intercepts individual [Core] state changes.
///
/// Conduits are composable: multiple Conduits can be attached to a single
/// Core, and each transforms the value in sequence before it is applied.
///
/// ## Creating a Conduit
///
/// ```dart
/// class LogConduit<T> extends Conduit<T> {
///   final String label;
///   LogConduit(this.label);
///
///   @override
///   T pipe(T oldValue, T newValue) {
///     print('$label: $oldValue → $newValue');
///     return newValue; // Pass through unchanged
///   }
/// }
/// ```
///
/// ## Using with Core
///
/// ```dart
/// final count = Core<int>(0, conduits: [
///   ClampConduit(min: 0, max: 99),
///   LogConduit('count'),
/// ]);
/// ```
///
/// ## Using with Pillar
///
/// ```dart
/// class GamePillar extends Pillar {
///   late final health = core(100, conduits: [
///     ClampConduit(min: 0, max: 100),
///   ]);
/// }
/// ```
abstract class Conduit<T> {
  /// Transforms or validates the new value before it is applied.
  ///
  /// Receives [oldValue] (current state) and [newValue] (proposed value,
  /// possibly already transformed by an earlier Conduit in the chain).
  ///
  /// Return the value to pass to the next Conduit (or to apply if this
  /// is the last one). The returned value may differ from [newValue].
  ///
  /// Throw [ConduitRejectedException] to prevent the change entirely.
  /// The Core's value will remain unchanged.
  T pipe(T oldValue, T newValue);

  /// Called after the value change has been successfully applied.
  ///
  /// Override this for side effects that should happen post-change,
  /// such as logging, analytics, or triggering external systems.
  ///
  /// This is **not** called if [pipe] threw or if the equality check
  /// suppressed the change.
  void onPiped(T oldValue, T newValue) {}
}

// ---------------------------------------------------------------------------
// ConduitRejectedException
// ---------------------------------------------------------------------------

/// Thrown by a [Conduit.pipe] to reject a state change.
///
/// When thrown, the Core's value remains unchanged and no notifications
/// are sent. Callers can catch this to handle rejected updates.
///
/// ```dart
/// try {
///   health.value = -10;
/// } on ConduitRejectedException catch (e) {
///   print('Rejected: ${e.message}');
/// }
/// ```
class ConduitRejectedException implements Exception {
  /// A human-readable description of why the change was rejected.
  final String? message;

  /// The value that was rejected.
  final Object? rejectedValue;

  /// Creates a rejection exception.
  const ConduitRejectedException({this.message, this.rejectedValue});

  @override
  String toString() {
    final parts = <String>['ConduitRejectedException'];
    if (message != null) parts.add(message!);
    if (rejectedValue != null) parts.add('(rejected: $rejectedValue)');
    return parts.join(': ');
  }
}

// ---------------------------------------------------------------------------
// Built-in Conduits
// ---------------------------------------------------------------------------

/// A [Conduit] that clamps numeric values to a [min]–[max] range.
///
/// Works with any [num] type (`int`, `double`).
///
/// ```dart
/// final volume = Core<int>(50, conduits: [
///   ClampConduit(min: 0, max: 100),
/// ]);
/// volume.value = 150; // Clamped to 100
/// volume.value = -10; // Clamped to 0
/// ```
class ClampConduit<T extends num> extends Conduit<T> {
  /// The minimum allowed value (inclusive).
  final T min;

  /// The maximum allowed value (inclusive).
  final T max;

  /// Creates a clamping conduit with the given range.
  ClampConduit({required this.min, required this.max}) {
    if (min > max) {
      throw ArgumentError('min ($min) must be <= max ($max)');
    }
  }

  @override
  T pipe(T oldValue, T newValue) => newValue.clamp(min, max) as T;
}

/// A [Conduit] that applies a transformation function to new values.
///
/// ```dart
/// final name = Core<String>('', conduits: [
///   TransformConduit((old, value) => value.trim().toLowerCase()),
/// ]);
/// name.value = '  HELLO  '; // Stored as 'hello'
/// ```
class TransformConduit<T> extends Conduit<T> {
  final T Function(T oldValue, T newValue) _transform;

  /// Creates a transform conduit with the given function.
  TransformConduit(this._transform);

  @override
  T pipe(T oldValue, T newValue) => _transform(oldValue, newValue);
}

/// A [Conduit] that validates new values and rejects invalid ones.
///
/// The [validator] function returns `null` if the value is valid,
/// or an error message string if invalid.
///
/// ```dart
/// final email = Core<String>('', conduits: [
///   ValidateConduit((old, value) =>
///     value.contains('@') ? null : 'Invalid email',
///   ),
/// ]);
///
/// try {
///   email.value = 'not-an-email';
/// } on ConduitRejectedException catch (e) {
///   print(e.message); // 'Invalid email'
/// }
/// ```
class ValidateConduit<T> extends Conduit<T> {
  final String? Function(T oldValue, T newValue) _validator;

  /// Creates a validation conduit with the given validator function.
  ValidateConduit(this._validator);

  @override
  T pipe(T oldValue, T newValue) {
    final error = _validator(oldValue, newValue);
    if (error != null) {
      throw ConduitRejectedException(message: error, rejectedValue: newValue);
    }
    return newValue;
  }
}

/// A [Conduit] that prevents state changes once a condition is met.
///
/// Once [freezeWhen] returns `true`, all subsequent changes are rejected
/// until the conduit is removed or replaced.
///
/// ```dart
/// final score = Core<int>(0, conduits: [
///   FreezeConduit((oldValue, newValue) => oldValue >= 100),
/// ]);
/// score.value = 100; // Applied
/// score.value = 50;  // Rejected — score is frozen at 100
/// ```
class FreezeConduit<T> extends Conduit<T> {
  final bool Function(T oldValue, T newValue) _freezeWhen;

  /// Creates a freeze conduit with the given freeze predicate.
  FreezeConduit(this._freezeWhen);

  @override
  T pipe(T oldValue, T newValue) {
    if (_freezeWhen(oldValue, newValue)) {
      throw ConduitRejectedException(
        message: 'State is frozen',
        rejectedValue: newValue,
      );
    }
    return newValue;
  }
}

/// A [Conduit] that debounces rapid value changes, keeping only the last.
///
/// **Note**: Unlike other Conduits, this does not block synchronously.
/// It always allows the value through but tracks change frequency.
/// For true async debouncing, use Flux operators (`core.debounce()`).
class ThrottleConduit<T> extends Conduit<T> {
  final Duration _minInterval;
  DateTime _lastChange = DateTime.fromMillisecondsSinceEpoch(0);

  /// Creates a throttle conduit that rejects changes faster than
  /// [minInterval].
  ThrottleConduit(this._minInterval);

  @override
  T pipe(T oldValue, T newValue) {
    final now = DateTime.now();
    if (now.difference(_lastChange) < _minInterval) {
      throw ConduitRejectedException(
        message: 'Throttled: change too fast',
        rejectedValue: newValue,
      );
    }
    _lastChange = now;
    return newValue;
  }
}
