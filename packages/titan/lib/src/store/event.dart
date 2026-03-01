/// Represents a state change event for middleware processing.
///
/// Contains all information about a state mutation, including
/// the state name, old and new values, and a timestamp.
class StateChangeEvent {
  /// The name of the state that changed.
  final String stateName;

  /// The previous value.
  final dynamic oldValue;

  /// The new value.
  final dynamic newValue;

  /// When the change occurred.
  final DateTime timestamp;

  /// Creates a state change event.
  const StateChangeEvent({
    required this.stateName,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
  });

  @override
  String toString() =>
      'StateChangeEvent($stateName: $oldValue → $newValue)';
}
