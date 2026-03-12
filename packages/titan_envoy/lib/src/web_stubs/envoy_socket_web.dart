import 'dart:async';

/// Stub [SocketStatus] enum for web platform.
///
/// The full [EnvoySocket] implementation uses `dart:io` WebSocket
/// and is only available on native platforms.
enum SocketStatus {
  /// Not yet connected.
  disconnected,

  /// Connection in progress.
  connecting,

  /// Connected and ready.
  connected,

  /// Connection is closing.
  closing,
}

/// **EnvoySocket** — Stub for web platform.
///
/// WebSocket support on web requires a browser-specific implementation.
/// This stub provides the same API surface to avoid compilation errors,
/// but throws [UnsupportedError] when used.
///
/// For web WebSocket support, use the browser's native WebSocket API
/// directly via `dart:js_interop`.
class EnvoySocket {
  /// Creates a new [EnvoySocket].
  ///
  /// On web, this creates a stub that throws when [connect] is called.
  EnvoySocket(
    this.url, {
    this.headers = const {},
    this.protocols = const [],
    this.reconnect = false,
    this.reconnectDelay = const Duration(seconds: 1),
    this.maxReconnectDelay = const Duration(seconds: 30),
    this.maxReconnectAttempts = 0,
    this.pingInterval,
  });

  /// The WebSocket server URL.
  final Uri url;

  /// Custom headers for the handshake request.
  final Map<String, String> headers;

  /// Sub-protocols to negotiate during handshake.
  final List<String> protocols;

  /// Whether to automatically reconnect on disconnect.
  final bool reconnect;

  /// Base delay between reconnection attempts.
  final Duration reconnectDelay;

  /// Maximum delay between reconnection attempts.
  final Duration maxReconnectDelay;

  /// Maximum reconnection attempts (0 = unlimited).
  final int maxReconnectAttempts;

  /// Interval for ping/pong keep-alive frames.
  final Duration? pingInterval;

  /// Current connection status.
  SocketStatus get status => SocketStatus.disconnected;

  /// Stream of incoming messages (decoded JSON or raw strings).
  Stream<Object?> get messages => const Stream.empty();

  /// Stream of connection status changes.
  Stream<SocketStatus> get statusStream => const Stream.empty();

  /// Number of reconnection attempts since last successful connection.
  int get reconnectAttempts => 0;

  /// Connects to the WebSocket server.
  ///
  /// Throws [UnsupportedError] on web.
  Future<void> connect() => throw UnsupportedError(
    'EnvoySocket is not supported on web. '
    'Use the browser WebSocket API via dart:js_interop instead.',
  );

  /// Sends data through the WebSocket connection.
  void send(Object? data) =>
      throw UnsupportedError('EnvoySocket is not supported on web.');

  /// Sends raw string data.
  void sendRaw(String data) =>
      throw UnsupportedError('EnvoySocket is not supported on web.');

  /// Closes the WebSocket connection.
  Future<void> close([int? code, String? reason]) async {}
}
