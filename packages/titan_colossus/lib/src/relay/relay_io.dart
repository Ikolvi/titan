/// **Relay** — `dart:io` implementation for non-web platforms.
///
/// Provides a real HTTP server using `dart:io`'s [HttpServer].
/// Supports Android, iOS, macOS, Windows, and Linux.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../bindings/colossus_bindings.dart';
import '../bindings/colossus_logger.dart';
import '../integration/lens.dart';
import 'relay.dart';

/// Platform implementation of Relay using `dart:io` [HttpServer].
class RelayPlatform {
  HttpServer? _server;
  RelayConfig? _config;
  RelayHandler? _handler;
  ColossusLogger? _logger;
  DateTime? _startedAt;
  int _requestsHandled = 0;
  int _campaignsExecuted = 0;

  // Cache for blueprint data to avoid recomputing when multiple streaming
  // endpoints are called in sequence (e.g. JSON then prompt).
  Map<String, dynamic>? _blueprintCache;
  DateTime? _blueprintCacheTime;
  static const _blueprintCacheDuration = Duration(seconds: 10);

  /// Current status of the Relay server.
  RelayStatus get status => RelayStatus(
    isRunning: _server != null,
    port: _server?.port ?? _config?.port,
    host: _config?.host,
    requestsHandled: _requestsHandled,
    campaignsExecuted: _campaignsExecuted,
    startedAt: _startedAt,
  );

  /// Start the HTTP server.
  Future<void> start({
    required RelayConfig config,
    required RelayHandler handler,
  }) async {
    if (_server != null) return; // Already running

    _config = config;
    _handler = handler;

    if (config.enableLogging && ColossusBindings.isInstalled) {
      _logger = ColossusBindings.instance.createLogger('Relay');
    }

    try {
      _server = await HttpServer.bind(config.host, config.port);
      _startedAt = DateTime.now();
      _requestsHandled = 0;
      _campaignsExecuted = 0;

      _logger?.info('Relay started on ${config.host}:${config.port}');

      if (config.authToken != null) {
        _logger?.info('Auth token: ${config.authToken}');
      }

      // Process requests without blocking the caller
      unawaited(_listen());
    } on SocketException catch (e) {
      _logger?.warning('Relay failed to bind: $e');
      _server = null;
      rethrow;
    }
  }

  /// Stop the HTTP server.
  Future<void> stop() async {
    final server = _server;
    if (server == null) return;

    _logger?.info(
      'Relay stopping (handled $_requestsHandled requests, '
      '$_campaignsExecuted campaigns)',
    );

    await server.close();
    _server = null;
    _config = null;
    _handler = null;
    _logger = null;
  }

  // -----------------------------------------------------------------------
  // Request loop
  // -----------------------------------------------------------------------

  Future<void> _listen() async {
    final server = _server;
    if (server == null) return;

    await for (final request in server) {
      // Don't block the request loop — process concurrently
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _requestsHandled++;

    try {
      // CORS headers for web-based clients
      _setCorsHeaders(request.response);

      // Handle preflight
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      final path = request.uri.path;
      final method = request.method;

      // Health check — no auth required
      if (method == 'GET' && path == '/health') {
        _sendJson(request.response, {
          'status': 'ok',
          'uptime': _startedAt != null
              ? DateTime.now().difference(_startedAt!).inSeconds
              : 0,
        });
        return;
      }

      // Auth check for all other endpoints
      if (!_checkAuth(request)) {
        _sendError(
          request.response,
          HttpStatus.unauthorized,
          'Missing or invalid Authorization header. '
          'Use: Authorization: Bearer <token>',
        );
        return;
      }

      // Route dispatch
      switch ((method, path)) {
        case ('GET', '/status'):
          _sendJson(request.response, status.toJson());

        case ('GET', '/terrain'):
          await _handleGetTerrain(request);

        case ('GET', '/blueprint'):
          await _handleGetBlueprint(request);

        case ('POST', '/campaign'):
          await _handlePostCampaign(request);

        case ('POST', '/debrief'):
          await _handlePostDebrief(request);

        case ('GET', '/performance'):
          _handleGetPerformance(request);

        case ('GET', '/frames'):
          _handleGetFrames(request);

        case ('GET', '/pages'):
          _handleGetPages(request);

        case ('GET', '/memory'):
          _handleGetMemory(request);

        case ('GET', '/alerts'):
          _handleGetAlerts(request);

        case ('GET', '/sessions'):
          await _handleGetSessions(request);

        case ('GET', '/recording'):
          _handleGetRecording(request);

        case ('GET', '/errors'):
          _handleGetErrors(request);

        case ('POST', '/recording/start'):
          await _handleStartRecording(request);

        case ('POST', '/recording/stop'):
          await _handleStopRecording(request);

        case ('POST', '/blueprint/export'):
          await _handleExportBlueprint(request);

        case ('GET', '/blueprint/data'):
          _handleGetBlueprintData(request);

        case ('GET', '/blueprint/stream/json'):
          await _handleStreamBlueprintJson(request);

        case ('GET', '/blueprint/stream/prompt'):
          await _handleStreamBlueprintPrompt(request);

        case ('GET', '/debug/tree'):
          await _handleDebugTree(request);

        case ('GET', '/api/metrics'):
          _handleGetApiMetrics(request);

        case ('GET', '/api/errors'):
          _handleGetApiErrors(request);

        case ('GET', '/tremors'):
          _handleGetTremors(request);

        case ('POST', '/tremors/add'):
          await _handleAddTremor(request);

        case ('POST', '/tremors/remove'):
          await _handleRemoveTremor(request);

        case ('POST', '/tremors/reset'):
          await _handleResetTremors(request);

        case ('POST', '/reload'):
          await _handleReloadPage(request);

        case ('GET', '/widget-tree'):
          _handleGetWidgetTree(request);

        case ('GET', '/events'):
          _handleGetEvents(request);

        case ('POST', '/replay'):
          await _handleReplaySession(request);

        case ('GET', '/route-history'):
          _handleGetRouteHistory(request);

        case ('GET', '/screenshot'):
          await _handleCaptureScreenshot(request);

        case ('GET', '/accessibility'):
          _handleAuditAccessibility(request);

        case ('GET', '/di'):
          _handleInspectDi(request);

        case ('GET', '/envoy/inspect'):
          _handleInspectEnvoy(request);

        case ('POST', '/envoy/configure'):
          await _handleConfigureEnvoy(request);

        case ('GET', '/sentinel/records'):
          _handleGetSentinelRecords(request);

        case ('DELETE', '/sentinel/records'):
          _handleClearSentinelRecords(request);

        case ('POST', '/lens'):
          await _handleSetLens(request);

        default:
          _sendError(
            request.response,
            HttpStatus.notFound,
            'Unknown endpoint: $method $path',
          );
      }
    } catch (e, st) {
      _logger?.warning('Request error: $e');
      try {
        _sendError(
          request.response,
          HttpStatus.internalServerError,
          'Internal error: $e',
          stackTrace: st.toString(),
        );
      } catch (_) {
        // Response already closed — ignore
      }
    }
  }

  // -----------------------------------------------------------------------
  // Endpoint handlers
  // -----------------------------------------------------------------------

  Future<void> _handleGetTerrain(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getTerrain());
  }

  Future<void> _handleGetBlueprint(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final blueprint = await handler.getBlueprint();
    _sendJson(request.response, blueprint);
  }

  Future<void> _handlePostCampaign(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await _readJsonBody(request);
    if (body == null) {
      _sendError(
        request.response,
        HttpStatus.badRequest,
        'Invalid JSON body. Expected a Campaign JSON object.',
      );
      return;
    }

    _logger?.info(
      'Executing campaign: ${body['name'] ?? 'unnamed'} '
      '(${(body['entries'] as List?)?.length ?? 0} entries)',
    );

    final timeout = _config?.requestTimeout ?? const Duration(minutes: 10);

    try {
      final result = await handler.executeCampaign(body).timeout(timeout);

      _campaignsExecuted++;

      _logger?.info('Campaign complete');

      _sendJson(request.response, result);
    } on TimeoutException {
      _sendError(
        request.response,
        HttpStatus.gatewayTimeout,
        'Campaign execution timed out after ${timeout.inMinutes} minutes',
      );
    }
  }

  Future<void> _handlePostDebrief(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await _readJsonBody(request);
    if (body == null || body['verdicts'] is! List) {
      _sendError(
        request.response,
        HttpStatus.badRequest,
        'Invalid JSON body. Expected: {"verdicts": [...]}',
      );
      return;
    }

    final verdicts = (body['verdicts'] as List).cast<Map<String, dynamic>>();
    final report = handler.debriefVerdicts(verdicts);
    _sendJson(request.response, report);
  }

  void _handleGetPerformance(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final report = handler.getPerformanceReport();
    _sendJson(request.response, report);
  }

  void _handleGetFrames(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getFrameHistory());
  }

  void _handleGetPages(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getPageLoads());
  }

  void _handleGetMemory(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getMemorySnapshot());
  }

  void _handleGetAlerts(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getAlerts());
  }

  Future<void> _handleGetSessions(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final sessions = await handler.listSessions();
    _sendJson(request.response, sessions);
  }

  void _handleGetRecording(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getRecordingStatus());
  }

  void _handleGetErrors(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getFrameworkErrors());
  }

  Future<void> _handleStartRecording(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await _readJsonBody(request);
    final name = body?['name'] as String?;
    final description = body?['description'] as String?;

    try {
      final result = handler.startRecording(
        name: name,
        description: description,
      );
      _sendJson(request.response, result);
    } catch (e) {
      _sendError(
        request.response,
        HttpStatus.conflict,
        'Failed to start recording: $e',
      );
    }
  }

  Future<void> _handleStopRecording(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    try {
      final result = handler.stopRecording();
      _sendJson(request.response, result);
    } catch (e) {
      _sendError(
        request.response,
        HttpStatus.conflict,
        'Failed to stop recording: $e',
      );
    }
  }

  Future<void> _handleExportBlueprint(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await _readJsonBody(request);
    final directory = body?['directory'] as String?;

    try {
      final result = await handler.exportBlueprint(directory: directory);
      _sendJson(request.response, result);
    } catch (e) {
      _sendError(
        request.response,
        HttpStatus.internalServerError,
        'Blueprint export failed: $e',
      );
    }
  }

  void _handleGetBlueprintData(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    try {
      final result = _getCachedBlueprintData(handler);
      _sendJson(request.response, result);
    } catch (e) {
      _sendError(
        request.response,
        HttpStatus.internalServerError,
        'Blueprint data failed: $e',
      );
    }
  }

  /// Stream blueprint JSON in chunks. Writes the pretty-printed JSON directly
  /// to the HTTP response without buffering. Summary metadata is sent as
  /// custom headers so the client can report without parsing.
  Future<void> _handleStreamBlueprintJson(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    try {
      final data = _getCachedBlueprintData(handler);
      final blueprint = data['blueprint'] as Map<String, dynamic>?;
      if (blueprint == null) {
        _sendError(
          request.response,
          HttpStatus.notFound,
          'No blueprint data. Record a session first.',
        );
        return;
      }

      final terrain = data['terrainSummary'] as Map<String, dynamic>? ?? {};
      final response = request.response;
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..headers.set('X-Terrain-Screens', '${terrain['screens'] ?? 0}')
        ..headers.set('X-Terrain-Transitions', '${terrain['transitions'] ?? 0}')
        ..headers.set('X-Stratagem-Count', '${data['stratagemCount'] ?? 0}');

      // Serialize and write in chunks to avoid a single large allocation.
      const encoder = JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(blueprint);
      const chunkSize = 64 * 1024; // 64 KB
      for (var i = 0; i < jsonStr.length; i += chunkSize) {
        final end = i + chunkSize;
        response.write(
          jsonStr.substring(i, end > jsonStr.length ? jsonStr.length : end),
        );
      }
      await response.close();
    } catch (e) {
      _sendError(
        request.response,
        HttpStatus.internalServerError,
        'Blueprint stream failed: $e',
      );
    }
  }

  /// Stream blueprint AI prompt as plain markdown. Lightweight — just the
  /// prompt text, no JSON wrapper.
  Future<void> _handleStreamBlueprintPrompt(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    try {
      final data = _getCachedBlueprintData(handler);
      final prompt = data['prompt'] as String?;
      if (prompt == null || prompt.isEmpty) {
        _sendError(
          request.response,
          HttpStatus.notFound,
          'No prompt data. Record a session first.',
        );
        return;
      }

      final response = request.response;
      response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('text', 'plain', charset: 'utf-8');

      // Write in chunks for large prompts.
      const chunkSize = 64 * 1024; // 64 KB
      for (var i = 0; i < prompt.length; i += chunkSize) {
        final end = i + chunkSize;
        response.write(
          prompt.substring(i, end > prompt.length ? prompt.length : end),
        );
      }
      await response.close();
    } catch (e) {
      _sendError(
        request.response,
        HttpStatus.internalServerError,
        'Prompt stream failed: $e',
      );
    }
  }

  /// Return cached blueprint data, recomputing if stale or absent.
  Map<String, dynamic> _getCachedBlueprintData(RelayHandler handler) {
    final now = DateTime.now();
    if (_blueprintCache != null &&
        _blueprintCacheTime != null &&
        now.difference(_blueprintCacheTime!) < _blueprintCacheDuration) {
      return _blueprintCache!;
    }
    final data = handler.getBlueprintData();
    _blueprintCache = data;
    _blueprintCacheTime = now;
    return data;
  }

  // -----------------------------------------------------------------------
  // Auth
  // -----------------------------------------------------------------------

  bool _checkAuth(HttpRequest request) {
    final token = _config?.authToken;
    if (token == null) return true; // No auth configured

    final header = request.headers.value('authorization');
    if (header == null) return false;

    return header == 'Bearer $token';
  }

  // -----------------------------------------------------------------------
  // Response helpers
  // -----------------------------------------------------------------------

  void _setCorsHeaders(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );
    response.headers.set('Access-Control-Max-Age', '86400');
  }

  void _sendJson(HttpResponse response, Map<String, dynamic> data) {
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(const JsonEncoder.withIndent('  ').convert(data));
    response.close();
  }

  void _sendError(
    HttpResponse response,
    int statusCode,
    String message, {
    String? stackTrace,
  }) {
    final body = <String, dynamic>{'error': message, 'statusCode': statusCode};
    if (stackTrace != null) {
      body['stackTrace'] = stackTrace;
    }

    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    response.close();
  }

  Future<Map<String, dynamic>?> _readJsonBody(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      if (body.isEmpty) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Debug endpoint: walk the element tree and return stats.
  ///
  /// This is a diagnostic tool — not part of the public API.
  Future<void> _handleDebugTree(HttpRequest request) async {
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement == null) {
      _sendJson(request.response, {'error': 'No root element'});
      return;
    }

    var totalElements = 0;
    var maxDepthReached = 0;
    final typeCounts = <String, int>{};
    final depthSamples = <int, List<String>>{};

    void walk(Element element, int depth) {
      if (depth > 400) return; // Safety limit
      totalElements++;
      if (depth > maxDepthReached) maxDepthReached = depth;

      final typeName = element.widget.runtimeType.toString();
      typeCounts[typeName] = (typeCounts[typeName] ?? 0) + 1;

      // Record widget types at milestone depths
      if (depth % 20 == 0 || depth <= 5) {
        depthSamples.putIfAbsent(depth, () => []);
        if (depthSamples[depth]!.length < 5) {
          depthSamples[depth]!.add(typeName);
        }
      }

      element.visitChildren((child) => walk(child, depth + 1));
    }

    walk(rootElement, 0);

    // Find key widget types
    final hasText = typeCounts.containsKey('Text');
    final hasTextField = typeCounts.containsKey('TextField');
    final hasFilledButton = typeCounts.containsKey('FilledButton');
    final buttonTypes = typeCounts.entries
        .where((e) => e.key.contains('Button'))
        .map((e) => '${e.key}: ${e.value}')
        .toList();

    _sendJson(request.response, {
      'totalElements': totalElements,
      'maxDepthReached': maxDepthReached,
      'uniqueWidgetTypes': typeCounts.length,
      'hasText': hasText,
      'textCount': typeCounts['Text'] ?? 0,
      'hasTextField': hasTextField,
      'hasFilledButton': hasFilledButton,
      'buttonTypes': buttonTypes,
      'depthSamples': depthSamples.map((k, v) => MapEntry(k.toString(), v)),
      'top20WidgetTypes':
          (typeCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(20)
              .map((e) => '${e.key}: ${e.value}')
              .toList(),
    });
  }

  void _handleGetApiMetrics(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getApiMetrics());
  }

  void _handleGetApiErrors(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getApiErrors());
  }

  void _handleGetTremors(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getTremors());
  }

  Future<void> _handleAddTremor(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await _readJsonBody(request);
    if (body == null) {
      _sendError(
        request.response,
        HttpStatus.badRequest,
        'Missing JSON body with tremor configuration',
      );
      return;
    }

    _sendJson(request.response, handler.addTremor(body));
  }

  Future<void> _handleRemoveTremor(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await _readJsonBody(request);
    final name = body?['name'] as String?;
    if (name == null) {
      _sendError(
        request.response,
        HttpStatus.badRequest,
        'Missing "name" in request body',
      );
      return;
    }

    _sendJson(request.response, handler.removeTremor(name));
  }

  Future<void> _handleResetTremors(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await _readJsonBody(request);
    final clearHistory = body?['clearHistory'] as bool? ?? false;

    _sendJson(
      request.response,
      handler.resetTremors(clearHistory: clearHistory),
    );
  }

  Future<void> _handleReloadPage(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await _readJsonBody(request);
    final fullRebuild = body?['fullRebuild'] as bool? ?? false;

    final result = await handler.reloadPage(fullRebuild: fullRebuild);
    _sendJson(request.response, result);
  }

  void _handleGetWidgetTree(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getWidgetTree());
  }

  void _handleGetEvents(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final source = request.uri.queryParameters['source'];
    _sendJson(request.response, handler.getEvents(source: source));
  }

  Future<void> _handleReplaySession(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await _readJsonBody(request);
    final sessionId = body?['sessionId'] as String?;
    if (sessionId == null) {
      _sendError(
        request.response,
        HttpStatus.badRequest,
        'Missing "sessionId" in request body',
      );
      return;
    }

    final speed = (body?['speedMultiplier'] as num?)?.toDouble() ?? 1.0;
    final result = await handler.replaySession(
      sessionId,
      speedMultiplier: speed,
    );
    _sendJson(request.response, result);
  }

  void _handleGetRouteHistory(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.getRouteHistory());
  }

  Future<void> _handleCaptureScreenshot(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final pixelRatio =
        double.tryParse(request.uri.queryParameters['pixelRatio'] ?? '') ?? 0.5;
    final result = await handler.captureScreenshot(pixelRatio: pixelRatio);
    _sendJson(request.response, result);
  }

  void _handleAuditAccessibility(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.auditAccessibility());
  }

  void _handleInspectDi(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.inspectDi());
  }

  void _handleInspectEnvoy(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    _sendJson(request.response, handler.inspectEnvoy());
  }

  Future<void> _handleConfigureEnvoy(HttpRequest request) async {
    final handler = _handler;
    if (handler == null) {
      _sendError(
        request.response,
        HttpStatus.serviceUnavailable,
        'Colossus not available',
      );
      return;
    }

    final body = await utf8.decoder.bind(request).join();
    if (body.isEmpty) {
      _sendError(
        request.response,
        HttpStatus.badRequest,
        'Request body is required',
      );
      return;
    }

    final Map<String, dynamic> config;
    try {
      config = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      _sendError(request.response, HttpStatus.badRequest, 'Invalid JSON body');
      return;
    }

    _sendJson(request.response, handler.configureEnvoy(config));
  }

  // -----------------------------------------------------------------------
  // Lens FAB visibility
  // -----------------------------------------------------------------------

  Future<void> _handleSetLens(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final visible = body?['visible'] as bool? ?? true;
    Lens.relayConnected.value = !visible;
    _sendJson(request.response, {'visible': visible, 'fabHidden': !visible});
  }

  // -----------------------------------------------------------------------
  // Sentinel endpoints
  // -----------------------------------------------------------------------

  void _handleGetSentinelRecords(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(request.response, HttpStatus.serviceUnavailable, 'Not ready');
      return;
    }
    _sendJson(request.response, handler.getSentinelRecords());
  }

  void _handleClearSentinelRecords(HttpRequest request) {
    final handler = _handler;
    if (handler == null) {
      _sendError(request.response, HttpStatus.serviceUnavailable, 'Not ready');
      return;
    }
    _sendJson(request.response, handler.clearSentinelRecords());
  }
}
