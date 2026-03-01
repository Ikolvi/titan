import '../core/observer.dart';

/// Global configuration for Titan.
///
/// Provides a centralized place to configure logging, debugging,
/// and other global behaviors.
class TitanConfig {
  TitanConfig._();

  /// Whether debug mode is enabled.
  ///
  /// When enabled, additional assertions and logging are active.
  static bool debugMode = false;

  /// Enables logging of all state changes.
  ///
  /// Shorthand for setting [TitanObserver.instance] to a
  /// [TitanLoggingObserver].
  static void enableLogging({void Function(String)? logger}) {
    TitanObserver.instance = TitanLoggingObserver(logger: logger);
  }

  /// Disables the global observer.
  static void disableLogging() {
    TitanObserver.instance = null;
  }

  /// Resets all global configuration to defaults.
  static void reset() {
    debugMode = false;
    TitanObserver.instance = null;
  }
}
