import 'dart:async';

// ---------------------------------------------------------------------------
// ColossusEventBus — Cross-Domain Event Abstraction
// ---------------------------------------------------------------------------

/// **ColossusEventBus** — framework-agnostic event broadcasting interface.
///
/// Replaces direct `Herald.emit()` usage inside Colossus. When used with
/// `TitanBindings`, events flow through Herald. With `DefaultBindings`,
/// events are broadcast via a `StreamController`.
///
/// ```dart
/// final bus = ColossusBindings.instance.eventBus;
/// bus.emit(ColossusTremor(tremor: t, message: 'FPS low'));
///
/// bus.allEvents.listen((event) {
///   print('Event: $event');
/// });
/// ```
abstract class ColossusEventBus {
  /// Emit an event to all listeners.
  void emit(Object event);

  /// Stream of all events emitted through this bus.
  Stream<Object> get allEvents;

  /// Clean up resources.
  void dispose();
}

// ---------------------------------------------------------------------------
// DefaultEventBus — StreamController-backed implementation
// ---------------------------------------------------------------------------

/// Lightweight event bus backed by a broadcast `StreamController`.
///
/// Used by `ColossusBindings.installDefaults()` when no framework
/// adapter is installed.
class DefaultEventBus implements ColossusEventBus {
  final StreamController<Object> _controller =
      StreamController<Object>.broadcast();

  @override
  void emit(Object event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  @override
  Stream<Object> get allEvents => _controller.stream;

  @override
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
