import 'package:titan/titan.dart';

import 'colossus_bindings.dart';
import 'colossus_error_reporter.dart';
import 'colossus_event_bus.dart';
import 'colossus_logger.dart';
import 'colossus_reactive_value.dart';
import 'colossus_service_locator.dart';

// ---------------------------------------------------------------------------
// TitanBindings — Maps Colossus Abstractions to Titan APIs
// ---------------------------------------------------------------------------

/// **TitanBindings** — wires Colossus to the Titan ecosystem.
///
/// Maps each Colossus abstraction to its Titan equivalent:
///
/// | Abstraction | Titan API |
/// |-------------|-----------|
/// | `ColossusLogger` | `Chronicle` |
/// | `ColossusEventBus` | `Herald` |
/// | `ColossusErrorReporter` | `Vigil` |
/// | `ColossusServiceLocator` | `Titan` (DI) |
/// | `ColossusReactiveValue` | `Core<T>` |
///
/// This is auto-installed by `Colossus.init()` when no bindings have
/// been explicitly installed.
///
/// ```dart
/// // Explicit installation (usually not needed):
/// ColossusBindings.install(TitanBindings());
/// Colossus.init();
/// ```
class TitanBindings extends ColossusBindings {
  /// Creates Titan-backed bindings.
  ///
  /// Optionally accepts a [logSink] for capturing log entries
  /// (e.g. for Lens display).
  TitanBindings({super.logSink})
    : super(
        createLogger: (name) => _ChronicleLogger(name),
        eventBus: _HeraldEventBus(),
        errorReporter: _VigilReporter(),
        serviceLocator: _TitanServiceLocator(),
        createReactiveValue: <T>(T initial) => _CoreReactive<T>(initial),
      );
}

// ---------------------------------------------------------------------------
// Chronicle Logger
// ---------------------------------------------------------------------------

class _ChronicleLogger implements ColossusLogger {
  final Chronicle _chronicle;
  _ChronicleLogger(String name) : _chronicle = Chronicle(name);

  @override
  void info(String message, [Map<String, dynamic>? data]) =>
      _chronicle.info(message, data);

  @override
  void warning(String message, [Map<String, dynamic>? data]) =>
      _chronicle.warning(message, data);

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _chronicle.error(message, error, stackTrace);
}

// ---------------------------------------------------------------------------
// Herald Event Bus
// ---------------------------------------------------------------------------

class _HeraldEventBus implements ColossusEventBus {
  @override
  void emit(Object event) => Herald.emit(event);

  @override
  Stream<Object> get allEvents => Herald.allEvents.map((e) => e.payload);

  @override
  void dispose() {
    // Herald is global — don't dispose it.
  }
}

// ---------------------------------------------------------------------------
// Vigil Error Reporter
// ---------------------------------------------------------------------------

class _VigilReporter implements ColossusErrorReporter {
  @override
  void capture(
    String message, {
    ColossusErrorSeverity severity = ColossusErrorSeverity.error,
  }) {
    Vigil.capture(message, severity: _mapSeverity(severity));
  }

  @override
  Stream<Object> get errors => Vigil.errors;

  @override
  List<Object> get history => Vigil.history;

  @override
  void clearHistory() => Vigil.clearHistory();

  static ErrorSeverity _mapSeverity(ColossusErrorSeverity severity) {
    return switch (severity) {
      ColossusErrorSeverity.info => ErrorSeverity.info,
      ColossusErrorSeverity.warning => ErrorSeverity.warning,
      ColossusErrorSeverity.error => ErrorSeverity.error,
      ColossusErrorSeverity.fatal => ErrorSeverity.error,
    };
  }
}

// ---------------------------------------------------------------------------
// Titan Service Locator
// ---------------------------------------------------------------------------

class _TitanServiceLocator implements ColossusServiceLocator {
  @override
  void register<T extends Object>(T instance) => Titan.put(instance);

  @override
  T resolve<T extends Object>() => Titan.get<T>();

  @override
  T? tryResolve<T extends Object>() => Titan.find<T>();

  @override
  void unregister<T extends Object>() => Titan.remove<T>();

  @override
  bool has<T extends Object>() => Titan.has<T>();

  @override
  Map<Type, dynamic> get instances => Titan.instances;

  @override
  Set<Type> get registeredTypes => Titan.registeredTypes;
}

// ---------------------------------------------------------------------------
// Core Reactive Value
// ---------------------------------------------------------------------------

class _CoreReactive<T> implements ColossusReactiveValue<T> {
  final Core<T> _core;
  _CoreReactive(T initial) : _core = Core<T>(initial);

  @override
  T get value => _core.value;

  @override
  set value(T v) => _core.value = v;

  @override
  T peek() => _core.peek();

  @override
  void addListener(void Function() l) => _core.addListener(l);

  @override
  void removeListener(void Function() l) => _core.removeListener(l);

  @override
  void dispose() => _core.dispose();
}
