import '../pillar/pillar.dart';
import 'effect.dart';
import 'state.dart';

/// Global observer for all Titan state changes and lifecycle events.
///
/// [TitanObserver] provides a comprehensive monitoring point for all state
/// mutations, Pillar lifecycle events, batch operations, and effect execution
/// across the application. Useful for logging, analytics, time-travel
/// debugging, and devtools integration.
///
/// ## Multi-Observer Support
///
/// Multiple observers can be registered simultaneously using [addObserver]
/// and [removeObserver]. This enables composing logging, analytics, and
/// devtools observers independently.
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
/// // Register globally (single observer — legacy)
/// TitanObserver.instance = AppObserver();
///
/// // Or register multiple observers (recommended)
/// TitanObserver.addObserver(AppObserver());
/// TitanObserver.addObserver(AnalyticsObserver());
/// ```
abstract class TitanObserver {
  /// The primary global observer instance (legacy single-observer API).
  ///
  /// Set this to receive notifications for all state changes.
  /// For multiple observers, use [addObserver] instead.
  static TitanObserver? instance;

  /// All registered observers (both [instance] and added observers).
  static final List<TitanObserver> _observers = [];

  /// Registers an additional observer.
  ///
  /// Multiple observers can be registered simultaneously. Each receives
  /// all lifecycle callbacks independently.
  ///
  /// ```dart
  /// TitanObserver.addObserver(LoggingObserver());
  /// TitanObserver.addObserver(AnalyticsObserver());
  /// ```
  static void addObserver(TitanObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  /// Removes a previously registered observer.
  static void removeObserver(TitanObserver observer) {
    _observers.remove(observer);
  }

  /// Returns an unmodifiable view of all registered observers.
  static List<TitanObserver> get observers =>
      List.unmodifiable(_observers);

  /// Removes all registered observers and clears [instance].
  static void clearObservers() {
    _observers.clear();
    instance = null;
  }

  /// Notifies all observers of a state change.
  ///
  /// Called internally by [TitanState] when a value changes.
  static void notifyStateChanged({
    required TitanState state,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    instance?.onStateChanged(
      state: state,
      oldValue: oldValue,
      newValue: newValue,
    );
    for (final observer in _observers) {
      observer.onStateChanged(
        state: state,
        oldValue: oldValue,
        newValue: newValue,
      );
    }
  }

  /// Notifies all observers of a Pillar initialization.
  static void notifyPillarInit(Pillar pillar) {
    instance?.onPillarInit(pillar);
    for (final observer in _observers) {
      observer.onPillarInit(pillar);
    }
  }

  /// Notifies all observers of a Pillar disposal.
  static void notifyPillarDispose(Pillar pillar) {
    instance?.onPillarDispose(pillar);
    for (final observer in _observers) {
      observer.onPillarDispose(pillar);
    }
  }

  /// Notifies all observers that a batch has started.
  static void notifyBatchStart() {
    instance?.onBatchStart();
    for (final observer in _observers) {
      observer.onBatchStart();
    }
  }

  /// Notifies all observers that a batch has ended.
  static void notifyBatchEnd() {
    instance?.onBatchEnd();
    for (final observer in _observers) {
      observer.onBatchEnd();
    }
  }

  /// Notifies all observers that an effect ran.
  static void notifyEffectRun(TitanEffect effect) {
    instance?.onEffectRun(effect);
    for (final observer in _observers) {
      observer.onEffectRun(effect);
    }
  }

  /// Notifies all observers that an effect errored.
  static void notifyEffectError(
    TitanEffect effect,
    Object error,
    StackTrace stackTrace,
  ) {
    instance?.onEffectError(effect, error, stackTrace);
    for (final observer in _observers) {
      observer.onEffectError(effect, error, stackTrace);
    }
  }

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

  /// Called when a [Pillar] is initialized.
  ///
  /// Override to track Pillar creation for devtools or analytics.
  void onPillarInit(Pillar pillar) {}

  /// Called when a [Pillar] is disposed.
  ///
  /// Override to track Pillar disposal for devtools or analytics.
  void onPillarDispose(Pillar pillar) {}

  /// Called when a batch mutation starts.
  void onBatchStart() {}

  /// Called when a batch mutation ends and notifications are flushed.
  void onBatchEnd() {}

  /// Called when a [TitanEffect] executes.
  void onEffectRun(TitanEffect effect) {}

  /// Called when a [TitanEffect] throws an error during execution.
  void onEffectError(
    TitanEffect effect,
    Object error,
    StackTrace stackTrace,
  ) {}
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
