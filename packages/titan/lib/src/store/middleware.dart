import 'event.dart';

/// Base class for middleware that intercepts state changes in a [TitanStore].
///
/// **Deprecated**: This class was never wired into the reactive engine and
/// its hooks (`onStateChange`, `onError`) are never invoked.
/// Use [TitanObserver] (Oracle) for global state-change observation, or
/// [Pillar.watch] / [Vigil] for per-Pillar side effects and error handling.
///
/// Will be removed in a future major release.
@Deprecated('Use TitanObserver (Oracle) instead. '
    'TitanMiddleware hooks were never invoked by the reactive engine.')
abstract class TitanMiddleware {
  /// Called when a state change occurs.
  ///
  /// **Note**: This method is never called by the framework.
  void onStateChange(StateChangeEvent event) {}

  /// Called when an error occurs during state processing.
  ///
  /// **Note**: This method is never called by the framework.
  void onError(Object error, StackTrace stackTrace) {}
}
