import 'dart:async';

/// Data class representing a single SSE event.
///
/// Stub for web — same API surface as the native implementation.
class SseEvent {
  /// Creates an SSE event.
  const SseEvent({this.id, this.event, this.data = '', this.retry});

  /// Optional event ID.
  final String? id;

  /// Event type (defaults to `message` when null).
  final String? event;

  /// Event payload data.
  final String data;

  /// Suggested reconnection time in milliseconds.
  final int? retry;

  @override
  String toString() => 'SseEvent(id: $id, event: $event, data: $data)';
}

/// **EnvoySse** — Stub for web platform.
///
/// SSE support on web requires a browser-specific implementation
/// (e.g., `EventSource` API). This stub provides the same API surface
/// to avoid compilation errors, but throws [UnsupportedError] when used.
///
/// For web SSE support, use the browser's native `EventSource` API
/// directly via `dart:js_interop`.
class EnvoySse {
  /// Creates a new SSE client.
  ///
  /// On web, this creates a stub that throws when [connect] is called.
  EnvoySse(
    this.url, {
    this.headers = const {},
    this.reconnect = true,
    this.reconnectDelay = const Duration(seconds: 3),
    this.maxReconnectAttempts = 0,
  });

  /// The SSE endpoint URL.
  final Uri url;

  /// Custom headers for the HTTP request.
  final Map<String, String> headers;

  /// Whether to automatically reconnect on disconnect.
  final bool reconnect;

  /// Delay between reconnection attempts.
  final Duration reconnectDelay;

  /// Maximum reconnection attempts (0 = unlimited).
  final int maxReconnectAttempts;

  /// Whether the client is currently connected.
  bool get isConnected => false;

  /// Stream of SSE events.
  Stream<SseEvent> get events => const Stream.empty();

  /// Connects to the SSE endpoint.
  ///
  /// Throws [UnsupportedError] on web.
  Future<void> connect() => throw UnsupportedError(
    'EnvoySse is not supported on web. '
    'Use the browser EventSource API via dart:js_interop instead.',
  );

  /// Closes the SSE connection.
  Future<void> close() async {}
}
