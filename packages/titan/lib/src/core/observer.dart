import 'state.dart';

/// Global observer for all Titan state changes.
///
/// [TitanObserver] provides a single point for monitoring all state
/// mutations across the application. Useful for logging, analytics,
/// time-travel debugging, and devtools integration.
///
/// ## Usage
///
/// ```dart
/// class AppObserver extends TitanObserver {
///   @override
///   void onStateChanged({
///     required TitanState state,
///     required dynamic oldValue,
///     required dynamic newValue,
///   }) {
///     print('${state.name}: $oldValue -> $newValue');
///   }
/// }
///
/// // Register globally
/// TitanObserver.instance = AppObserver();
/// ```
abstract class TitanObserver {
  /// The global observer instance.
  ///
  /// Set this to receive notifications for all state changes.
  static TitanObserver? instance;

  /// Called whenever a [TitanState] value changes.
  ///
  /// - [state] — The state that changed.
  /// - [oldValue] — The previous value.
  /// - [newValue] — The new value.
  void onStateChanged({
    required TitanState state,
    required dynamic oldValue,
    required dynamic newValue,
  });
}

/// A simple logging observer that prints state changes.
///
/// ```dart
/// TitanObserver.instance = TitanLoggingObserver();
/// ```
class TitanLoggingObserver extends TitanObserver {
  /// Optional custom log function. Defaults to [print].
  final void Function(String message)? logger;

  /// Creates a logging observer.
  TitanLoggingObserver({this.logger});

  @override
  void onStateChanged({
    required TitanState state,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    final name = state.name ?? state.runtimeType.toString();
    final message = '[Titan] $name: $oldValue → $newValue';
    (logger ?? print)(message);
  }
}

/// An observer that records state change history for time-travel debugging.
///
/// ```dart
/// final observer = TitanHistoryObserver();
/// TitanObserver.instance = observer;
///
/// // Later: inspect history
/// for (final entry in observer.history) {
///   print('${entry.stateName}: ${entry.oldValue} -> ${entry.newValue}');
/// }
/// ```
class TitanHistoryObserver extends TitanObserver {
  final List<StateChangeRecord> _history = [];
  final int _maxHistory;

  /// Creates a history observer.
  ///
  /// - [maxHistory] — Maximum number of records to keep. Defaults to 1000.
  TitanHistoryObserver({int maxHistory = 1000}) : _maxHistory = maxHistory;

  /// The recorded state change history (oldest first).
  List<StateChangeRecord> get history => List.unmodifiable(_history);

  /// The number of recorded changes.
  int get length => _history.length;

  /// Clears all recorded history.
  void clear() => _history.clear();

  @override
  void onStateChanged({
    required TitanState state,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    if (_history.length >= _maxHistory) {
      _history.removeAt(0);
    }
    _history.add(StateChangeRecord(
      stateName: state.name ?? state.runtimeType.toString(),
      oldValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now(),
    ));
  }
}

/// A record of a single state change.
class StateChangeRecord {
  /// The name of the state that changed.
  final String stateName;

  /// The old value.
  final dynamic oldValue;

  /// The new value.
  final dynamic newValue;

  /// When the change occurred.
  final DateTime timestamp;

  /// Creates a state change record.
  const StateChangeRecord({
    required this.stateName,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
  });

  @override
  String toString() =>
      'StateChangeRecord($stateName: $oldValue → $newValue @ $timestamp)';
}
