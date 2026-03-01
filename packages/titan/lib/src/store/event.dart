/// Represents a state change event for middleware processing.
///
/// **Deprecated**: Part of the unused [TitanMiddleware] system.
/// Use [TitanObserver] (Oracle) for state-change observation instead.
///
/// Will be removed in a future major release.
@Deprecated('Part of unused TitanMiddleware system. '
    'Use TitanObserver (Oracle) instead.')
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
