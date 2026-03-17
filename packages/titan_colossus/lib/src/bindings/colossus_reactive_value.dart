import 'package:flutter/foundation.dart' show ChangeNotifier;

// ---------------------------------------------------------------------------
// ColossusReactiveValue — Observable Value Abstraction
// ---------------------------------------------------------------------------

/// **ColossusReactiveValue** — framework-agnostic observable value interface.
///
/// Replaces `Core<T>` usage inside Colossus (e.g. `Shade.isRecordingCore`).
/// When used with `TitanBindings`, backed by `Core<T>`. With
/// `DefaultBindings`, backed by `ChangeNotifier`.
///
/// ```dart
/// final reactive = ColossusBindings.instance.createReactiveValue(false);
/// reactive.addListener(() => print('Changed: ${reactive.value}'));
/// reactive.value = true; // Triggers listener
/// print(reactive.peek()); // Read without tracking
/// ```
abstract class ColossusReactiveValue<T> {
  /// The current value (may trigger dependency tracking in some impls).
  T get value;

  /// Set a new value, notifying listeners if it changed.
  set value(T newValue);

  /// Read the current value without triggering dependency tracking.
  T peek();

  /// Add a listener that is called when the value changes.
  void addListener(void Function() listener);

  /// Remove a previously added listener.
  void removeListener(void Function() listener);

  /// Release resources.
  void dispose();
}

// ---------------------------------------------------------------------------
// DefaultReactiveValue — ChangeNotifier-backed implementation
// ---------------------------------------------------------------------------

/// Lightweight reactive value backed by Flutter's `ChangeNotifier`.
///
/// Used by `ColossusBindings.installDefaults()` when no framework
/// adapter is installed.
class DefaultReactiveValue<T> extends ChangeNotifier
    implements ColossusReactiveValue<T> {
  T _value;

  /// Creates a reactive value with the given [initial] value.
  DefaultReactiveValue(T initial) : _value = initial;

  @override
  T get value => _value;

  @override
  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      notifyListeners();
    }
  }

  @override
  T peek() => _value;
}
