/// **Relay** — Web platform implementation using WebSocket client.
///
/// On web, browsers cannot host HTTP servers. Instead, Relay connects
/// to the MCP server's `/relay` WebSocket endpoint as a **client**.
/// The MCP server sends commands (GET/POST requests) over the
/// WebSocket, and this implementation routes them to the
/// [RelayHandler] and sends responses back.
///
/// ## Protocol
///
/// Request (MCP Server → Web App):
/// ```json
/// {"id": "uuid", "method": "GET", "path": "/terrain"}
/// {"id": "uuid", "method": "POST", "path": "/campaign", "body": {...}}
/// ```
///
/// Response (Web App → MCP Server):
/// ```json
/// {"id": "uuid", "status": 200, "body": {...}}
/// {"id": "uuid", "status": 500, "error": "..."}
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../bindings/colossus_bindings.dart';
import '../bindings/colossus_logger.dart';
import '../integration/lens.dart';
import 'relay.dart';

/// Web implementation of Relay using a WebSocket client.
///
/// Connects to the MCP server's `/relay` WebSocket endpoint and
/// processes incoming commands by routing them through the
/// [RelayHandler] interface.
class RelayPlatform {
  web.WebSocket? _ws;
  RelayConfig? _config;
  RelayHandler? _handler;
  ColossusLogger? _logger;
  DateTime? _startedAt;
  int _requestsHandled = 0;
  int _campaignsExecuted = 0;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _stopping = false;

  /// Maximum reconnect delay (exponential backoff cap).
  static const _maxReconnectDelay = Duration(seconds: 30);

  /// Current status of the Relay WebSocket connection.
  RelayStatus get status => RelayStatus(
    isRunning: _ws?.readyState == web.WebSocket.OPEN,
    port: null,
    host: _config?.targetUrl,
    requestsHandled: _requestsHandled,
    campaignsExecuted: _campaignsExecuted,
    startedAt: _startedAt,
  );

  /// Connect to the MCP server's WebSocket relay endpoint.
  ///
  /// If [config.targetUrl] is null, Relay is silently disabled
  /// (same behavior as the old stub).
  Future<void> start({
    required RelayConfig config,
    required RelayHandler handler,
  }) async {
    if (_ws != null) return; // Already connected

    _config = config;
    _handler = handler;
    _stopping = false;

    if (config.enableLogging && ColossusBindings.isInstalled) {
      _logger = ColossusBindings.instance.createLogger('Relay');
    }

    final url = config.targetUrl;
    if (url == null || url.isEmpty) {
      _logger?.info(
        'Relay disabled on web — no targetUrl configured. '
        'Set RelayConfig(targetUrl: "ws://localhost:8643/relay") '
        'to enable.',
      );
      return;
    }

    await _connect(url);
  }

  /// Disconnect from the MCP server.
  Future<void> stop() async {
    _stopping = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final ws = _ws;
    if (ws != null) {
      _logger?.info(
        'Relay stopping (handled $_requestsHandled requests, '
        '$_campaignsExecuted campaigns)',
      );
      ws.close(1000, 'Relay stopping');
      _ws = null;
    }

    _config = null;
    _handler = null;
    _logger = null;
  }

  // -----------------------------------------------------------------------
  // WebSocket connection management
  // -----------------------------------------------------------------------

  Future<void> _connect(String url) async {
    // Append auth token as query parameter if configured.
    var connectUrl = url;
    final token = _config?.authToken;
    if (token != null && token.isNotEmpty) {
      final separator = url.contains('?') ? '&' : '?';
      connectUrl = '$url${separator}token=$token';
    }

    _logger?.info('Relay connecting to $url');

    try {
      final ws = web.WebSocket(connectUrl);
      _ws = ws;

      final openCompleter = Completer<void>();

      ws.onopen = ((JSAny? event) {
        _startedAt = DateTime.now();
        _reconnectAttempts = 0;
        _logger?.info('Relay connected to $url');

        if (!openCompleter.isCompleted) {
          openCompleter.complete();
        }
      }).toJS;

      ws.onmessage = ((web.MessageEvent event) {
        _onMessage(event);
      }).toJS;

      ws.onclose = ((web.CloseEvent event) {
        _logger?.info('Relay WebSocket closed: ${event.code} ${event.reason}');
        _ws = null;

        if (!_stopping) {
          _scheduleReconnect();
        }

        if (!openCompleter.isCompleted) {
          openCompleter.complete(); // Don't block caller forever
        }
      }).toJS;

      ws.onerror = ((JSAny? event) {
        _logger?.warning('Relay WebSocket error');

        if (!openCompleter.isCompleted) {
          openCompleter.complete(); // Don't block caller forever
        }
      }).toJS;

      // Wait for connection to open (or fail).
      await openCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger?.warning('Relay connection timeout');
        },
      );
    } catch (e) {
      _logger?.warning('Relay connection failed: $e');
      _ws = null;

      if (!_stopping) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_stopping || _config == null) return;

    _reconnectAttempts++;
    final baseDelay = _config!.reconnectDelay;
    final delay = Duration(
      milliseconds:
          (baseDelay.inMilliseconds *
                  (1 << (_reconnectAttempts - 1).clamp(0, 10)))
              .clamp(0, _maxReconnectDelay.inMilliseconds),
    );

    _logger?.info(
      'Relay reconnecting in ${delay.inSeconds}s '
      '(attempt $_reconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      final url = _config?.targetUrl;
      if (url != null && !_stopping) {
        _connect(url);
      }
    });
  }

  // -----------------------------------------------------------------------
  // Message handling
  // -----------------------------------------------------------------------

  void _onMessage(web.MessageEvent event) {
    final data = event.data;
    if (data == null) return;
    final dataStr = (data as JSString).toDart;
    if (dataStr.isEmpty) return;

    try {
      final message = jsonDecode(dataStr) as Map<String, dynamic>;
      final id = message['id'] as String?;
      final method = message['method'] as String? ?? 'GET';
      final rawPath = message['path'] as String? ?? '/';
      final body = message['body'] as Map<String, dynamic>?;

      // Strip query parameters — route matching uses path only.
      // Query params are parsed separately when needed.
      final uri = Uri.tryParse(rawPath);
      final path = uri?.path ?? rawPath;
      final queryParams = uri?.queryParameters ?? const {};

      if (id == null) {
        _logger?.warning('Relay received message without id');
        return;
      }

      _requestsHandled++;

      // Route the command asynchronously.
      unawaited(_handleCommand(id, method, path, body, queryParams));
    } catch (e) {
      _logger?.warning('Relay message parse error: $e');
    }
  }

  Future<void> _handleCommand(
    String id,
    String method,
    String path,
    Map<String, dynamic>? body,
    Map<String, String> queryParams,
  ) async {
    final handler = _handler;
    if (handler == null) {
      _sendResponse(id, 503, error: 'Colossus not available');
      return;
    }

    try {
      final result = await _routeCommand(
        handler,
        method,
        path,
        body,
        queryParams,
      );
      _sendResponse(id, 200, body: result);
    } catch (e, st) {
      _logger?.warning('Relay command error ($method $path): $e');
      _sendResponse(id, 500, error: '$e', stackTrace: st.toString());
    }
  }

  /// Route a command to the appropriate [RelayHandler] method.
  ///
  /// Mirrors the route table in `relay_io.dart` exactly.
  Future<Map<String, dynamic>> _routeCommand(
    RelayHandler handler,
    String method,
    String path,
    Map<String, dynamic>? body,
    Map<String, String> queryParams,
  ) async {
    switch ((method, path)) {
      case ('GET', '/health'):
        return {
          'status': 'ok',
          'uptime': _startedAt != null
              ? DateTime.now().difference(_startedAt!).inSeconds
              : 0,
        };

      case ('GET', '/status'):
        return status.toJson();

      case ('GET', '/terrain'):
        return handler.getTerrain();

      case ('GET', '/blueprint'):
        return await handler.getBlueprint();

      case ('POST', '/campaign'):
        if (body == null) {
          return {'error': 'Missing campaign body'};
        }
        _campaignsExecuted++;
        final timeout = _config?.requestTimeout ?? const Duration(minutes: 10);
        return await handler.executeCampaign(body).timeout(timeout);

      case ('POST', '/debrief'):
        if (body == null || body['verdicts'] is! List) {
          return {'error': 'Missing verdicts array'};
        }
        final verdicts = (body['verdicts'] as List)
            .cast<Map<String, dynamic>>();
        return handler.debriefVerdicts(verdicts);

      case ('GET', '/performance'):
        return handler.getPerformanceReport();

      case ('GET', '/frames'):
        return handler.getFrameHistory();

      case ('GET', '/pages'):
        return handler.getPageLoads();

      case ('GET', '/memory'):
        return handler.getMemorySnapshot();

      case ('GET', '/alerts'):
        return handler.getAlerts();

      case ('GET', '/sessions'):
        return await handler.listSessions();

      case ('GET', '/recording'):
        return handler.getRecordingStatus();

      case ('GET', '/errors'):
        return handler.getFrameworkErrors();

      case ('POST', '/recording/start'):
        return handler.startRecording(
          name: body?['name'] as String?,
          description: body?['description'] as String?,
        );

      case ('POST', '/recording/stop'):
        return handler.stopRecording();

      case ('POST', '/blueprint/export'):
        return await handler.exportBlueprint(
          directory: body?['directory'] as String?,
        );

      case ('GET', '/blueprint/data'):
        return handler.getBlueprintData();

      case ('GET', '/api/metrics'):
        return handler.getApiMetrics();

      case ('GET', '/api/errors'):
        return handler.getApiErrors();

      case ('GET', '/tremors'):
        return handler.getTremors();

      case ('POST', '/tremors/add'):
        if (body == null) return {'error': 'Missing tremor config'};
        return handler.addTremor(body);

      case ('POST', '/tremors/remove'):
        final name = body?['name'] as String?;
        if (name == null) return {'error': 'Missing tremor name'};
        return handler.removeTremor(name);

      case ('POST', '/tremors/reset'):
        return handler.resetTremors(
          clearHistory: body?['clearHistory'] as bool? ?? false,
        );

      case ('POST', '/reload'):
        return await handler.reloadPage(
          fullRebuild: body?['fullRebuild'] as bool? ?? false,
        );

      case ('GET', '/widget-tree'):
        return handler.getWidgetTree();

      case ('GET', '/events'):
        return handler.getEvents(source: body?['source'] as String?);

      case ('POST', '/replay'):
        final sessionId = body?['sessionId'] as String?;
        if (sessionId == null) return {'error': 'Missing sessionId'};
        return await handler.replaySession(
          sessionId,
          speedMultiplier:
              (body?['speedMultiplier'] as num?)?.toDouble() ?? 1.0,
        );

      case ('GET', '/route-history'):
        return handler.getRouteHistory();

      case ('GET', '/screenshot'):
        final pixelRatio =
            (body?['pixelRatio'] as num?)?.toDouble() ??
            double.tryParse(queryParams['pixelRatio'] ?? '') ??
            0.5;
        return await handler.captureScreenshot(pixelRatio: pixelRatio);

      case ('GET', '/accessibility'):
        return handler.auditAccessibility();

      case ('GET', '/di'):
        return handler.inspectDi();

      case ('GET', '/envoy/inspect'):
        return handler.inspectEnvoy();

      case ('POST', '/envoy/configure'):
        if (body == null) return {'error': 'Missing config'};
        return handler.configureEnvoy(body);

      case ('GET', '/sentinel/records'):
        return handler.getSentinelRecords();

      case ('DELETE', '/sentinel/records'):
        return handler.clearSentinelRecords();

      case ('POST', '/lens'):
        final visible = body?['visible'] as bool? ?? true;
        Lens.relayConnected.value = !visible;
        return {'visible': visible, 'fabHidden': !visible};

      default:
        return {'error': 'Unknown endpoint: $method $path'};
    }
  }

  void _sendResponse(
    String id,
    int statusCode, {
    Map<String, dynamic>? body,
    String? error,
    String? stackTrace,
  }) {
    final ws = _ws;
    if (ws == null || ws.readyState != web.WebSocket.OPEN) return;

    final response = <String, dynamic>{'id': id, 'status': statusCode};

    if (body != null) {
      response['body'] = body;
    }
    if (error != null) {
      response['error'] = error;
    }
    if (stackTrace != null) {
      response['stackTrace'] = stackTrace;
    }

    try {
      ws.send(jsonEncode(response).toJS);
    } catch (e) {
      _logger?.warning('Relay send error: $e');
    }
  }
}
