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
/// Uses a ring buffer internally for O(1) insertion even at capacity.
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
  final int _maxHistory;
  late List<StateChangeRecord?> _buffer;
  int _head = 0; // next write position
  int _count = 0;

  /// Creates a history observer.
  ///
  /// - [maxHistory] — Maximum number of records to keep. Defaults to 1000.
  TitanHistoryObserver({int maxHistory = 1000})
    : _maxHistory = maxHistory,
      _buffer = List<StateChangeRecord?>.filled(maxHistory, null);

  /// The recorded state change history (oldest first).
  List<StateChangeRecord> get history {
    if (_count == 0) return const [];
    final result = List<StateChangeRecord>.filled(_count, _buffer[0]!);
    if (_count < _maxHistory) {
      // Buffer not yet full — entries are at 0.._count-1
      for (var i = 0; i < _count; i++) {
        result[i] = _buffer[i]!;
      }
    } else {
      // Buffer full — oldest is at _head, wrap around
      for (var i = 0; i < _count; i++) {
        result[i] = _buffer[(_head + i) % _maxHistory]!;
      }
    }
    return result;
  }

  /// The number of recorded changes.
  int get length => _count;

  /// Clears all recorded history.
  void clear() {
    _buffer = List<StateChangeRecord?>.filled(_maxHistory, null);
    _head = 0;
    _count = 0;
  }

  @override
  void onStateChanged({
    required TitanState state,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    _buffer[_head] = StateChangeRecord(
      stateName: state.name ?? state.runtimeType.toString(),
      oldValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now(),
    );
    _head = (_head + 1) % _maxHistory;
    if (_count < _maxHistory) _count++;
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
