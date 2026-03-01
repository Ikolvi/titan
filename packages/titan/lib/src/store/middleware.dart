import 'event.dart';

/// Base class for middleware that intercepts state changes in a [TitanStore].
///
/// Middleware allows you to add cross-cutting concerns like logging,
/// analytics, persistence, and validation without modifying store logic.
///
/// ## Usage
///
/// ```dart
/// class LoggingMiddleware extends TitanMiddleware {
///   @override
///   void onAction(TitanAction action) {
///     print('Action: ${action.name}');
///   }
///
///   @override
///   void onStateChange(StateChangeEvent event) {
///     print('${event.stateName}: ${event.oldValue} -> ${event.newValue}');
///   }
///
///   @override
///   void onError(Object error, StackTrace stackTrace) {
///     print('Error: $error');
///   }
/// }
/// ```
abstract class TitanMiddleware {
  /// Called when a state change occurs.
  void onStateChange(StateChangeEvent event) {}

  /// Called when an error occurs during state processing.
  void onError(Object error, StackTrace stackTrace) {}
}
