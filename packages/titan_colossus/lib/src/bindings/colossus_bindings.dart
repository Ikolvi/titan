import 'colossus_error_reporter.dart';
import 'colossus_event_bus.dart';
import 'colossus_logger.dart';
import 'colossus_reactive_value.dart';
import 'colossus_service_locator.dart';

// ---------------------------------------------------------------------------
// ColossusBindings — Central Configuration
// ---------------------------------------------------------------------------

/// **ColossusBindings** — wires Colossus to a state management framework.
///
/// Colossus uses these bindings for logging, events, error reporting,
/// dependency lookup, and reactive values. By default, `TitanBindings`
/// is installed (using Chronicle, Herald, Vigil, Titan DI, and Core).
///
/// For standalone usage without Titan, call `installDefaults()` to use
/// lightweight implementations backed by `dart:developer`,
/// `StreamController`, and `ChangeNotifier`.
///
/// ## Usage
///
/// ```dart
/// // Option A: Auto-installed by Colossus.init() (uses TitanBindings)
/// Colossus.init();
///
/// // Option B: Explicit standalone bindings
/// ColossusBindings.installDefaults();
/// Colossus.init();
///
/// // Option C: Custom bindings (e.g. for Bloc, Riverpod)
/// ColossusBindings.install(MyCustomBindings());
/// Colossus.init();
/// ```
class ColossusBindings {
  /// Factory that creates named loggers.
  final ColossusLoggerFactory createLogger;

  /// Cross-domain event bus for broadcasting alerts and events.
  final ColossusEventBus eventBus;

  /// Error reporter for capturing performance issues and failures.
  final ColossusErrorReporter errorReporter;

  /// Service locator for dependency lookup (used by Vessel, Lens).
  final ColossusServiceLocator serviceLocator;

  /// Factory that creates reactive values (used by Shade).
  final ColossusReactiveValue<T> Function<T>(T initial) createReactiveValue;

  /// Optional log sink for capturing entries (used by Lens).
  final ColossusLogSink? logSink;

  /// Creates a bindings configuration.
  const ColossusBindings({
    required this.createLogger,
    required this.eventBus,
    required this.errorReporter,
    required this.serviceLocator,
    required this.createReactiveValue,
    this.logSink,
  });

  // -----------------------------------------------------------------------
  // Singleton management
  // -----------------------------------------------------------------------

  static ColossusBindings? _instance;

  /// The currently installed bindings.
  ///
  /// Throws [StateError] if no bindings are installed.
  static ColossusBindings get instance {
    if (_instance == null) {
      throw StateError(
        'ColossusBindings not installed. Call ColossusBindings.install() '
        'or use Colossus.init() which auto-installs TitanBindings.',
      );
    }
    return _instance!;
  }

  /// Install a [ColossusBindings] configuration.
  ///
  /// Call this before `Colossus.init()` to use custom bindings.
  /// If not called, `Colossus.init()` auto-installs `TitanBindings`.
  static void install(ColossusBindings bindings) => _instance = bindings;

  /// Whether bindings have been installed.
  static bool get isInstalled => _instance != null;

  /// Reset bindings (primarily for testing).
  static void reset() => _instance = null;

  /// Install default lightweight bindings (no external dependencies).
  ///
  /// Uses `dart:developer` for logging, `StreamController` for events,
  /// in-memory list for errors, `Map` for DI, and `ChangeNotifier` for
  /// reactive values.
  ///
  /// ```dart
  /// ColossusBindings.installDefaults();
  /// Colossus.init(); // Works without Titan
  /// ```
  static void installDefaults() {
    install(
      ColossusBindings(
        createLogger: DefaultLogger.new,
        eventBus: DefaultEventBus(),
        errorReporter: DefaultErrorReporter(),
        serviceLocator: DefaultServiceLocator(),
        createReactiveValue: <T>(T initial) => DefaultReactiveValue<T>(initial),
      ),
    );
  }
}
