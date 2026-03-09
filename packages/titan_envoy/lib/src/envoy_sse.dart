import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// **EnvoySse** — Server-Sent Events (SSE) client for Titan.
///
/// Connects to an SSE endpoint and provides a stream of [SseEvent] objects.
/// Supports automatic reconnection, last-event-ID tracking, and custom
/// headers.
///
/// ```dart
/// final sse = EnvoySse(
///   Uri.parse('https://api.example.com/events'),
///   reconnect: true,
/// );
///
/// await sse.connect();
///
/// sse.events.listen((event) {
///   print('Event: ${event.event} — ${event.data}');
/// });
///
/// // Later...
/// await sse.close();
/// ```
class EnvoySse {
  /// Creates a new SSE client.
  ///
  /// - [url]: The SSE endpoint URL.
  /// - [headers]: Custom headers for the HTTP request.
  /// - [reconnect]: Whether to reconnect on disconnect (default: true).
  /// - [reconnectDelay]: Base delay between reconnection attempts.
  /// - [maxReconnectAttempts]: Maximum reconnection attempts. 0 = unlimited.
  /// - [lastEventId]: Initial last-event-ID for resuming streams.
  EnvoySse(
    this.url, {
    this.headers = const {},
    this.reconnect = true,
    this.reconnectDelay = const Duration(seconds: 3),
    this.maxReconnectAttempts = 0,
    this.lastEventId,
  });

  /// The SSE endpoint URL.
  final Uri url;

  /// Custom request headers.
  final Map<String, String> headers;

  /// Whether to automatically reconnect on disconnect.
  final bool reconnect;

  /// Delay between reconnection attempts.
  final Duration reconnectDelay;

  /// Maximum reconnection attempts. 0 means unlimited.
  final int maxReconnectAttempts;

  /// The last event ID received, sent as `Last-Event-ID` on reconnect.
  String? lastEventId;

  HttpClient? _client;
  final StreamController<SseEvent> _eventController =
      StreamController.broadcast();
  bool _closed = false;
  int _reconnectAttempts = 0;
  StreamSubscription<String>? _subscription;
  Timer? _reconnectTimer;

  /// Stream of SSE events.
  Stream<SseEvent> get events => _eventController.stream;

  /// Whether the client is currently connected.
  bool get isConnected => _subscription != null && !_closed;

  /// Connects to the SSE endpoint and begins streaming events.
  Future<void> connect() async {
    if (_closed) throw StateError('EnvoySse has been closed');

    _client ??= HttpClient();

    try {
      final request = await _client!.getUrl(url);

      // Set SSE-specific headers
      request.headers.set('Accept', 'text/event-stream');
      request.headers.set('Cache-Control', 'no-cache');

      // Custom headers
      headers.forEach(request.headers.set);

      // Resume from last event
      if (lastEventId != null) {
        request.headers.set('Last-Event-ID', lastEventId!);
      }

      final response = await request.close();

      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        throw HttpException(
          'SSE connection failed: ${response.statusCode} $body',
          uri: url,
        );
      }

      _reconnectAttempts = 0;

      // Parse the SSE stream
      _subscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_processLine, onDone: _onDone, onError: _onError);
    } catch (e) {
      if (reconnect && !_closed) {
        _scheduleReconnect();
      } else {
        rethrow;
      }
    }
  }

  /// Closes the SSE connection and releases resources.
  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
  }

  /// Disposes the SSE client permanently.
  void dispose() {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _eventController.close();
  }

  // SSE parsing state
  String _currentEvent = '';
  final StringBuffer _currentData = StringBuffer();
  String? _currentId;

  void _processLine(String line) {
    if (line.isEmpty) {
      // Empty line = dispatch event
      if (_currentData.isNotEmpty) {
        final data = _currentData.toString();
        // Remove trailing newline added during accumulation
        final trimmed = data.endsWith('\n')
            ? data.substring(0, data.length - 1)
            : data;

        if (_currentId != null) {
          lastEventId = _currentId;
        }

        _eventController.add(
          SseEvent(
            event: _currentEvent.isEmpty ? 'message' : _currentEvent,
            data: trimmed,
            id: _currentId,
          ),
        );
      }

      // Reset for next event
      _currentEvent = '';
      _currentData.clear();
      _currentId = null;
      return;
    }

    if (line.startsWith(':')) {
      // Comment line — ignore (used for keep-alive)
      return;
    }

    String field;
    String value;

    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) {
      field = line;
      value = '';
    } else {
      field = line.substring(0, colonIndex);
      value = line.substring(colonIndex + 1);
      if (value.startsWith(' ')) {
        value = value.substring(1); // Strip leading space
      }
    }

    switch (field) {
      case 'event':
        _currentEvent = value;
      case 'data':
        _currentData
          ..write(value)
          ..write('\n');
      case 'id':
        _currentId = value;
      case 'retry':
        // Server-suggested retry interval — not implemented as Duration change
        break;
    }
  }

  void _onDone() {
    _subscription = null;
    if (!_closed && reconnect) {
      _scheduleReconnect();
    }
  }

  void _onError(Object error) {
    _eventController.addError(error);
    if (!_closed && reconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (maxReconnectAttempts > 0 &&
        _reconnectAttempts >= maxReconnectAttempts) {
      return;
    }

    _reconnectAttempts++;

    _reconnectTimer = Timer(reconnectDelay, () async {
      if (_closed) return;
      try {
        await connect();
      } catch (_) {
        // connect() handles scheduling the next reconnect
      }
    });
  }
}

/// An event received from a Server-Sent Events stream.
///
/// ```dart
/// sse.events.listen((event) {
///   if (event.event == 'quest_update') {
///     final quest = jsonDecode(event.data);
///     updateQuest(quest);
///   }
/// });
/// ```
@pragma('vm:prefer-inline')
class SseEvent {
  /// Creates a new SSE event.
  const SseEvent({this.event = 'message', required this.data, this.id});

  /// The event type (defaults to 'message').
  final String event;

  /// The event data payload.
  final String data;

  /// The event ID (used for Last-Event-ID on reconnect).
  final String? id;

  /// Parses [data] as JSON.
  Object? get jsonData => jsonDecode(data);

  @override
  String toString() => 'SseEvent($event: $data${id != null ? ', id=$id' : ''})';
}
