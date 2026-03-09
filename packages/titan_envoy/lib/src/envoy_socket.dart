import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// **EnvoySocket** — Titan's WebSocket client.
///
/// Provides a managed WebSocket connection with automatic reconnection,
/// JSON serialization, heartbeat/ping support, and connection lifecycle
/// management.
///
/// ```dart
/// final socket = EnvoySocket(
///   Uri.parse('wss://api.example.com/ws'),
///   reconnect: true,
///   reconnectDelay: Duration(seconds: 2),
/// );
///
/// await socket.connect();
///
/// // Listen for messages
/// socket.messages.listen((data) {
///   print('Received: $data');
/// });
///
/// // Send data
/// socket.send({'action': 'subscribe', 'channel': 'quests'});
///
/// // Close when done
/// await socket.close();
/// ```
class EnvoySocket {
  /// Creates a new [EnvoySocket] connection.
  ///
  /// - [url]: The WebSocket server URL (ws:// or wss://).
  /// - [headers]: Custom headers for the handshake.
  /// - [protocols]: WebSocket sub-protocols to negotiate.
  /// - [reconnect]: Whether to reconnect automatically on disconnect.
  /// - [reconnectDelay]: Base delay between reconnection attempts.
  /// - [maxReconnectDelay]: Maximum delay between reconnection attempts
  ///   (delay doubles each attempt until this cap).
  /// - [maxReconnectAttempts]: Maximum reconnection attempts. 0 = unlimited.
  /// - [pingInterval]: Interval for WebSocket ping/pong frames.
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

  /// Whether to reconnect automatically on disconnect.
  final bool reconnect;

  /// Base delay between reconnection attempts.
  final Duration reconnectDelay;

  /// Maximum delay between reconnection attempts (exponential backoff cap).
  final Duration maxReconnectDelay;

  /// Maximum reconnection attempts. 0 means unlimited.
  final int maxReconnectAttempts;

  /// Interval for WebSocket ping/pong keep-alive frames.
  final Duration? pingInterval;

  WebSocket? _socket;
  final StreamController<dynamic> _messageController =
      StreamController.broadcast();
  final StreamController<SocketStatus> _statusController =
      StreamController.broadcast();
  SocketStatus _status = SocketStatus.disconnected;
  int _reconnectAttempts = 0;
  bool _intentionalClose = false;
  Timer? _reconnectTimer;

  /// Stream of incoming messages (decoded JSON or raw strings).
  Stream<dynamic> get messages => _messageController.stream;

  /// Stream of connection status changes.
  Stream<SocketStatus> get statusChanges => _statusController.stream;

  /// Current connection status.
  SocketStatus get status => _status;

  /// Whether the socket is currently connected.
  bool get isConnected => _status == SocketStatus.connected;

  /// The close code from the last disconnection, if available.
  int? get closeCode => _socket?.closeCode;

  /// The close reason from the last disconnection, if available.
  String? get closeReason => _socket?.closeReason;

  /// Connects to the WebSocket server.
  ///
  /// Throws [SocketException] or [WebSocketException] on failure.
  Future<void> connect() async {
    if (_status == SocketStatus.connected) return;

    _intentionalClose = false;
    _setStatus(SocketStatus.connecting);

    try {
      _socket = await WebSocket.connect(
        url.toString(),
        headers: headers.isEmpty ? null : headers,
        protocols: protocols.isEmpty ? null : protocols,
      );

      if (pingInterval != null) {
        _socket!.pingInterval = pingInterval;
      }

      _reconnectAttempts = 0;
      _setStatus(SocketStatus.connected);

      _socket!.listen(_onData, onError: _onError, onDone: _onDone);
    } catch (e) {
      _setStatus(SocketStatus.disconnected);
      if (reconnect && !_intentionalClose) {
        _scheduleReconnect();
      } else {
        rethrow;
      }
    }
  }

  /// Sends data through the WebSocket.
  ///
  /// - [Map] / [List] are JSON-encoded automatically.
  /// - [String] is sent as-is.
  /// - Other types are converted via [toString].
  void send(Object data) {
    if (_socket == null || _status != SocketStatus.connected) {
      throw StateError('EnvoySocket is not connected');
    }

    if (data is Map || data is List) {
      _socket!.add(jsonEncode(data));
    } else {
      _socket!.add(data.toString());
    }
  }

  /// Sends raw bytes through the WebSocket.
  void sendBytes(List<int> bytes) {
    if (_socket == null || _status != SocketStatus.connected) {
      throw StateError('EnvoySocket is not connected');
    }
    _socket!.add(bytes);
  }

  /// Closes the WebSocket connection.
  ///
  /// - [code]: WebSocket close code (default: 1000 = normal closure).
  /// - [reason]: Human-readable close reason.
  Future<void> close([int? code, String? reason]) async {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_socket != null) {
      await _socket!.close(code ?? 1000, reason);
      _socket = null;
    }

    _setStatus(SocketStatus.disconnected);
  }

  /// Releases all resources. Call this when the socket will no longer be used.
  void dispose() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.close();
    _socket = null;
    _status = SocketStatus.disconnected;
    _messageController.close();
    _statusController.close();
  }

  void _onData(dynamic data) {
    // Try to parse JSON, fall back to raw value
    if (data is String) {
      try {
        _messageController.add(jsonDecode(data));
      } catch (_) {
        _messageController.add(data);
      }
    } else {
      _messageController.add(data);
    }
  }

  void _onError(Object error) {
    _messageController.addError(error);
  }

  void _onDone() {
    _setStatus(SocketStatus.disconnected);
    if (!_intentionalClose && reconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (maxReconnectAttempts > 0 &&
        _reconnectAttempts >= maxReconnectAttempts) {
      _setStatus(SocketStatus.disconnected);
      return;
    }

    _setStatus(SocketStatus.reconnecting);
    _reconnectAttempts++;

    // Exponential backoff with cap
    final delay = Duration(
      milliseconds:
          (reconnectDelay.inMilliseconds *
                  (1 << (_reconnectAttempts - 1).clamp(0, 10)))
              .clamp(0, maxReconnectDelay.inMilliseconds),
    );

    _reconnectTimer = Timer(delay, () async {
      if (_intentionalClose) return;
      try {
        await connect();
      } catch (_) {
        // connect() handles scheduling the next reconnect on failure
      }
    });
  }

  void _setStatus(SocketStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (!_statusController.isClosed) {
        _statusController.add(newStatus);
      }
    }
  }
}

/// Connection status of an [EnvoySocket].
enum SocketStatus {
  /// Not connected.
  disconnected,

  /// Attempting to connect.
  connecting,

  /// Connected and ready to send/receive.
  connected,

  /// Disconnected and attempting to reconnect.
  reconnecting,
}
