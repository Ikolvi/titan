import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan/titan.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -----------------------------------------------------------------------
  // RelayConfig
  // -----------------------------------------------------------------------

  group('RelayConfig', () {
    test('has sensible defaults', () {
      const config = RelayConfig();
      expect(config.port, 8642);
      expect(config.host, '0.0.0.0');
      expect(config.authToken, isNull);
      expect(config.requestTimeout, const Duration(minutes: 10));
      expect(config.enableLogging, true);
    });

    test('accepts custom values', () {
      const config = RelayConfig(
        port: 9090,
        host: '127.0.0.1',
        authToken: 'secret-token',
        requestTimeout: Duration(seconds: 30),
        enableLogging: false,
      );
      expect(config.port, 9090);
      expect(config.host, '127.0.0.1');
      expect(config.authToken, 'secret-token');
      expect(config.requestTimeout, const Duration(seconds: 30));
      expect(config.enableLogging, false);
    });

    test('is const-constructible', () {
      // Compile-time constant verification
      const configs = [
        RelayConfig(),
        RelayConfig(port: 3000),
        RelayConfig(host: 'localhost'),
      ];
      expect(configs, hasLength(3));
    });
  });

  // -----------------------------------------------------------------------
  // RelayStatus
  // -----------------------------------------------------------------------

  group('RelayStatus', () {
    test('default not-running state', () {
      const status = RelayStatus(isRunning: false);
      expect(status.isRunning, false);
      expect(status.port, isNull);
      expect(status.host, isNull);
      expect(status.requestsHandled, 0);
      expect(status.campaignsExecuted, 0);
      expect(status.startedAt, isNull);
    });

    test('running state with all fields', () {
      final now = DateTime.now();
      final status = RelayStatus(
        isRunning: true,
        port: 8642,
        host: '0.0.0.0',
        requestsHandled: 42,
        campaignsExecuted: 3,
        startedAt: now,
      );
      expect(status.isRunning, true);
      expect(status.port, 8642);
      expect(status.host, '0.0.0.0');
      expect(status.requestsHandled, 42);
      expect(status.campaignsExecuted, 3);
      expect(status.startedAt, now);
    });

    test('toJson serializes all fields', () {
      final now = DateTime(2025, 6, 15, 12, 0, 0);
      final status = RelayStatus(
        isRunning: true,
        port: 8642,
        host: '0.0.0.0',
        requestsHandled: 10,
        campaignsExecuted: 2,
        startedAt: now,
      );
      final json = status.toJson();
      expect(json['isRunning'], true);
      expect(json['port'], 8642);
      expect(json['host'], '0.0.0.0');
      expect(json['requestsHandled'], 10);
      expect(json['campaignsExecuted'], 2);
      expect(json['startedAt'], now.toIso8601String());
      expect(json['version'], '1.0.0');
    });

    test('toJson handles null fields', () {
      const status = RelayStatus(isRunning: false);
      final json = status.toJson();
      expect(json['isRunning'], false);
      expect(json['port'], isNull);
      expect(json['host'], isNull);
      expect(json['startedAt'], isNull);
    });
  });

  // -----------------------------------------------------------------------
  // Relay — Lifecycle
  // -----------------------------------------------------------------------

  group('Relay lifecycle', () {
    late Relay relay;
    late _MockRelayHandler handler;

    setUp(() {
      relay = Relay();
      handler = _MockRelayHandler();
    });

    tearDown(() async {
      await relay.stop();
    });

    test('starts not running', () {
      expect(relay.isRunning, false);
      expect(relay.status.isRunning, false);
    });

    test('starts and reports running', () async {
      await relay.start(
        config: const RelayConfig(
          port: 0, // OS-assigned port
          host: '127.0.0.1',
          enableLogging: false,
        ),
        handler: handler,
      );
      expect(relay.isRunning, true);
      expect(relay.status.isRunning, true);
      expect(relay.status.requestsHandled, 0);
    });

    test('stop transitions to not running', () async {
      await relay.start(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
        handler: handler,
      );
      expect(relay.isRunning, true);

      await relay.stop();
      expect(relay.isRunning, false);
    });

    test('double start is idempotent', () async {
      await relay.start(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
        handler: handler,
      );
      // Second start should not throw
      await relay.start(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
        handler: handler,
      );
      expect(relay.isRunning, true);
    });

    test('double stop is safe', () async {
      await relay.start(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
        handler: handler,
      );
      await relay.stop();
      await relay.stop(); // Should not throw
      expect(relay.isRunning, false);
    });

    test('stop without start is safe', () async {
      await relay.stop(); // Should not throw
      expect(relay.isRunning, false);
    });
  });

  // -----------------------------------------------------------------------
  // Relay — HTTP Endpoints
  // -----------------------------------------------------------------------

  group('Relay HTTP endpoints', () {
    late Relay relay;
    late _MockRelayHandler handler;
    late HttpClient client;
    late int port;

    // Flutter's TestWidgetsFlutterBinding overrides HttpOverrides to
    // block real network requests. We need real HTTP for Relay tests.
    HttpOverrides? savedOverrides;

    Future<void> startRelay({String? authToken}) async {
      relay = Relay();
      handler = _MockRelayHandler();

      // Restore real HTTP before creating HttpClient
      savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      client = HttpClient();

      // Bind to port 0 for OS-assigned ephemeral port
      await relay.start(
        config: RelayConfig(
          port: 0,
          host: '127.0.0.1',
          authToken: authToken,
          enableLogging: false,
        ),
        handler: handler,
      );
      port = relay.status.port!;
    }

    tearDown(() async {
      client.close();
      await relay.stop();
      // Restore Flutter's HttpOverrides
      HttpOverrides.global = savedOverrides;
    });

    // -- Health check --

    test('GET /health returns 200 without auth', () async {
      await startRelay(authToken: 'secret');

      final request = await client.get('127.0.0.1', port, '/health');
      // No Authorization header
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['status'], 'ok');
      expect(body.containsKey('uptime'), true);
    });

    // -- Auth --

    test('rejects unauthenticated request when token set', () async {
      await startRelay(authToken: 'my-secret');

      final request = await client.get('127.0.0.1', port, '/status');
      final response = await request.close();

      expect(response.statusCode, 401);
    });

    test('rejects wrong token', () async {
      await startRelay(authToken: 'correct');

      final request = await client.get('127.0.0.1', port, '/status');
      request.headers.set('Authorization', 'Bearer wrong');
      final response = await request.close();

      expect(response.statusCode, 401);
    });

    test('accepts correct token', () async {
      await startRelay(authToken: 'correct');

      final request = await client.get('127.0.0.1', port, '/status');
      request.headers.set('Authorization', 'Bearer correct');
      final response = await request.close();

      expect(response.statusCode, 200);
    });

    test('allows all requests when no token configured', () async {
      await startRelay(); // No auth token

      final request = await client.get('127.0.0.1', port, '/status');
      final response = await request.close();

      expect(response.statusCode, 200);
    });

    // -- GET /status --

    test('GET /status returns relay status', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/status');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['isRunning'], true);
      expect(body['version'], '1.0.0');
    });

    // -- GET /terrain --

    test('GET /terrain returns terrain JSON from handler', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/terrain');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['outposts'], isA<Map>());
      expect(handler.getTerrainCallCount, 1);
    });

    // -- GET /blueprint --

    test('GET /blueprint returns blueprint from handler', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/blueprint');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['terrain'], isA<Map>());
      expect(handler.getBlueprintCallCount, 1);
    });

    // -- POST /campaign --

    test('POST /campaign executes campaign via handler', () async {
      await startRelay();

      final campaign = {
        '\$schema': 'titan://campaign/v1',
        'name': 'test-campaign',
        'entries': [],
      };

      final request = await client.post('127.0.0.1', port, '/campaign');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(campaign));
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['campaign'], 'mock-campaign');
      expect(body['passRate'], 1.0);
      expect(handler.executeCampaignCallCount, 1);
    });

    test('POST /campaign rejects invalid JSON', () async {
      await startRelay();

      final request = await client.post('127.0.0.1', port, '/campaign');
      request.headers.contentType = ContentType.json;
      request.write('not json');
      final response = await request.close();

      expect(response.statusCode, 400);
    });

    test('POST /campaign rejects empty body', () async {
      await startRelay();

      final request = await client.post('127.0.0.1', port, '/campaign');
      request.headers.contentType = ContentType.json;
      final response = await request.close();

      expect(response.statusCode, 400);
    });

    // -- POST /debrief --

    test('POST /debrief returns debrief from handler', () async {
      await startRelay();

      final body = {'verdicts': <Map<String, dynamic>>[]};

      final request = await client.post('127.0.0.1', port, '/debrief');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await _readBody(response);

      expect(response.statusCode, 200);
      expect(responseBody['totalVerdicts'], 0);
      expect(handler.debriefCallCount, 1);
    });

    test('POST /debrief rejects missing verdicts', () async {
      await startRelay();

      final request = await client.post('127.0.0.1', port, '/debrief');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'other': 'data'}));
      final response = await request.close();

      expect(response.statusCode, 400);
    });

    // -- GET /performance --

    test('GET /performance returns decree report', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/performance');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['health'], 'good');
      expect(body['durationSeconds'], 0);

      // Pulse section
      expect(body['pulse'], isA<Map>());
      expect(body['pulse']['totalFrames'], 0);
      expect(body['pulse']['jankFrames'], 0);
      expect(body['pulse']['jankRate'], 0.0);
      expect(body['pulse']['avgFps'], 60.0);
      expect(body['pulse']['avgBuildTimeUs'], 0);
      expect(body['pulse']['avgRasterTimeUs'], 0);

      // Stride section
      expect(body['stride'], isA<Map>());
      expect(body['stride']['totalPageLoads'], 0);
      expect(body['stride']['pageLoads'], isEmpty);

      // Vessel section
      expect(body['vessel'], isA<Map>());
      expect(body['vessel']['pillarCount'], 0);
      expect(body['vessel']['leakSuspects'], isEmpty);

      // Echo section
      expect(body['echo'], isA<Map>());
      expect(body['echo']['totalRebuilds'], 0);

      // Handler was called exactly once
      expect(handler.getPerformanceReportCallCount, 1);
    });

    test('GET /performance requires auth when token set', () async {
      await startRelay(authToken: 'secret');

      final request = await client.get('127.0.0.1', port, '/performance');
      final response = await request.close();

      expect(response.statusCode, 401);
    });

    test('GET /performance accepts valid auth token', () async {
      await startRelay(authToken: 'secret');

      final request = await client.get('127.0.0.1', port, '/performance');
      request.headers.set('Authorization', 'Bearer secret');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['health'], 'good');
    });

    // -- GET /frames --

    test('GET /frames returns frame history', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/frames');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['totalFrames'], 2);
      expect(body['maxHistory'], 300);
      expect(body['frames'], isA<List>());
      expect((body['frames'] as List).length, 2);
      expect(handler.getFrameHistoryCallCount, 1);
    });

    // -- GET /pages --

    test('GET /pages returns page loads', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/pages');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['totalPageLoads'], 1);
      expect(body['avgPageLoadMs'], 150);
      expect(body['pageLoads'], isA<List>());
      expect(handler.getPageLoadsCallCount, 1);
    });

    // -- GET /memory --

    test('GET /memory returns memory snapshot', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/memory');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['pillarCount'], 3);
      expect(body['totalInstances'], 5);
      expect(body['leakSuspects'], isA<List>());
      expect(body['exemptTypes'], isA<List>());
      expect(handler.getMemorySnapshotCallCount, 1);
    });

    // -- GET /alerts --

    test('GET /alerts returns alert history', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/alerts');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['totalAlerts'], 0);
      expect(body['maxHistory'], 200);
      expect(body['alerts'], isA<List>());
      expect(handler.getAlertsCallCount, 1);
    });

    // -- GET /sessions --

    test('GET /sessions returns session list', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/sessions');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['configured'], true);
      expect(body['totalSessions'], 0);
      expect(body['sessions'], isA<List>());
      expect(handler.listSessionsCallCount, 1);
    });

    // -- GET /recording --

    test('GET /recording returns recording status', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/recording');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['isRecording'], false);
      expect(body['isReplaying'], false);
      expect(body['currentEventCount'], 0);
      expect(body['elapsedMs'], 0);
      expect(body['isPerfRecording'], false);
      expect(body['hasLastSession'], false);
      expect(handler.getRecordingStatusCallCount, 1);
    });

    // -- GET /errors --

    test('GET /errors returns framework errors', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/errors');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['total'], 2);
      expect(body['errors'], isList);
      final errors = body['errors'] as List;
      expect(errors.length, 2);
      expect(errors[0]['category'], 'overflow');
      expect(errors[1]['category'], 'build');
      expect(body['byCategory']['overflow'], 1);
      expect(body['byCategory']['build'], 1);
      expect(handler.getFrameworkErrorsCallCount, 1);
    });

    // -- GET /api/metrics --

    test('GET /api/metrics returns API metrics', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/api/metrics');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['totalMetrics'], 2);
      expect(body['metrics'], isList);
      final metrics = body['metrics'] as List;
      expect(metrics.length, 2);
      expect(metrics[0]['method'], 'GET');
      expect(metrics[0]['success'], true);
      expect(metrics[1]['method'], 'POST');
      expect(metrics[1]['success'], false);
    });

    // -- GET /api/errors --

    test('GET /api/errors returns API errors', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/api/errors');
      final response = await request.close();
      final body = await _readBody(response);

      expect(response.statusCode, 200);
      expect(body['totalErrors'], 1);
      expect(body['errors'], isList);
      final errors = body['errors'] as List;
      expect(errors.length, 1);
      expect(errors[0]['method'], 'POST');
      expect(errors[0]['statusCode'], 500);
    });

    // -- Unknown endpoint --

    test('unknown endpoint returns 404', () async {
      await startRelay();

      final request = await client.get('127.0.0.1', port, '/unknown');
      final response = await request.close();

      expect(response.statusCode, 404);
    });

    // -- CORS --

    test('OPTIONS returns CORS headers', () async {
      await startRelay();

      final request = await client.open('OPTIONS', '127.0.0.1', port, '/');
      final response = await request.close();

      expect(response.statusCode, 204);
      expect(response.headers.value('access-control-allow-origin'), '*');
      expect(
        response.headers.value('access-control-allow-methods'),
        contains('POST'),
      );
    });

    // -- Request counting --

    test('tracks request count', () async {
      await startRelay();

      // Make 3 requests
      for (var i = 0; i < 3; i++) {
        final request = await client.get('127.0.0.1', port, '/health');
        await request.close();
      }

      // Small delay for async request processing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(relay.status.requestsHandled, 3);
    });
  });

  // -----------------------------------------------------------------------
  // Colossus — Relay Integration
  // -----------------------------------------------------------------------

  group('Colossus Relay integration', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    test('Colossus has a Relay instance', () {
      final colossus = Colossus.init(enableLensTab: false);
      expect(colossus.relay, isA<Relay>());
      expect(colossus.relay.isRunning, false);
    });

    test('startRelay starts the Relay server', () async {
      final colossus = Colossus.init(enableLensTab: false);

      await colossus.startRelay(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
      );

      expect(colossus.relay.isRunning, true);
    });

    test('shutdown stops the Relay', () async {
      final colossus = Colossus.init(enableLensTab: false);

      await colossus.startRelay(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
      );
      expect(colossus.relay.isRunning, true);

      Colossus.shutdown();

      // Relay stop is fire-and-forget in sync shutdown
      // but onDispose calls relay.stop()
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // After dispose, relay should be stopped
    });

    test('shutdownAsync awaits Relay stop', () async {
      final colossus = Colossus.init(enableLensTab: false);

      await colossus.startRelay(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
      );
      expect(colossus.relay.isRunning, true);

      await Colossus.shutdownAsync();
      expect(Colossus.isActive, false);
    });

    test('Relay serves terrain from Colossus', () async {
      final colossus = Colossus.init(enableLensTab: false);

      await colossus.startRelay(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
      );

      final port = colossus.relay.status.port!;
      final savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final client = HttpClient();
      try {
        final request = await client.get('127.0.0.1', port, '/terrain');
        final response = await request.close();
        final body = await _readBody(response);

        expect(response.statusCode, 200);
        expect(body[r'$schema'], 'titan://terrain/v1');
      } finally {
        client.close();
        HttpOverrides.global = savedOverrides;
      }
    });

    test('Relay serves health check', () async {
      final colossus = Colossus.init(enableLensTab: false);

      await colossus.startRelay(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
      );

      final port = colossus.relay.status.port!;
      final savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final client = HttpClient();
      try {
        final request = await client.get('127.0.0.1', port, '/health');
        final response = await request.close();
        final body = await _readBody(response);

        expect(response.statusCode, 200);
        expect(body['status'], 'ok');
      } finally {
        client.close();
        HttpOverrides.global = savedOverrides;
      }
    });

    test('Relay serves performance report from Colossus', () async {
      final colossus = Colossus.init(enableLensTab: false);

      await colossus.startRelay(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
      );

      final port = colossus.relay.status.port!;
      final savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final client = HttpClient();
      try {
        final request = await client.get('127.0.0.1', port, '/performance');
        final response = await request.close();
        final body = await _readBody(response);

        expect(response.statusCode, 200);
        expect(body['health'], isA<String>());
        expect(body['pulse'], isA<Map>());
        expect(body['stride'], isA<Map>());
        expect(body['vessel'], isA<Map>());
        expect(body['echo'], isA<Map>());
      } finally {
        client.close();
        HttpOverrides.global = savedOverrides;
      }
    });

    test('trackApiMetric stores and retrieves metrics via Relay', () async {
      final colossus = Colossus.init(enableLensTab: false);

      // Track some API metrics
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/quests',
        'statusCode': 200,
        'durationMs': 142,
        'success': true,
        'cached': false,
        'timestamp': '2025-01-01T00:00:00Z',
      });
      colossus.trackApiMetric({
        'method': 'POST',
        'url': 'https://api.example.com/quests',
        'statusCode': 500,
        'durationMs': 3200,
        'success': false,
        'error': 'Internal Server Error',
        'cached': false,
        'timestamp': '2025-01-01T00:01:00Z',
      });

      expect(colossus.apiMetrics.length, 2);

      await colossus.startRelay(
        config: const RelayConfig(
          port: 0,
          host: '127.0.0.1',
          enableLogging: false,
        ),
      );

      final port = colossus.relay.status.port!;
      final savedOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final client = HttpClient();
      try {
        // Fetch all metrics
        final metricsReq = await client.get('127.0.0.1', port, '/api/metrics');
        final metricsResp = await metricsReq.close();
        final metricsBody = await _readBody(metricsResp);

        expect(metricsResp.statusCode, 200);
        expect(metricsBody['totalMetrics'], 2);
        expect(metricsBody['successful'], 1);
        expect(metricsBody['failed'], 1);

        // Fetch errors only
        final errorsReq = await client.get('127.0.0.1', port, '/api/errors');
        final errorsResp = await errorsReq.close();
        final errorsBody = await _readBody(errorsResp);

        expect(errorsResp.statusCode, 200);
        expect(errorsBody['totalErrors'], 1);
        final errors = errorsBody['errors'] as List;
        expect(errors.length, 1);
        expect(errors[0]['statusCode'], 500);
      } finally {
        client.close();
        HttpOverrides.global = savedOverrides;
      }
    });
  });

  // -----------------------------------------------------------------------
  // ColossusPlugin — Relay Config
  // -----------------------------------------------------------------------

  group('ColossusPlugin Relay config', () {
    test('enableRelay defaults to false', () {
      const plugin = ColossusPlugin();
      expect(plugin.enableRelay, false);
    });

    test('relayConfig defaults to const RelayConfig()', () {
      const plugin = ColossusPlugin();
      expect(plugin.relayConfig.port, 8642);
      expect(plugin.relayConfig.host, '0.0.0.0');
    });

    test('accepts custom relay config', () {
      const plugin = ColossusPlugin(
        enableRelay: true,
        relayConfig: RelayConfig(port: 9090, authToken: 'test'),
      );
      expect(plugin.enableRelay, true);
      expect(plugin.relayConfig.port, 9090);
      expect(plugin.relayConfig.authToken, 'test');
    });

    test('toString includes enableRelay', () {
      const plugin = ColossusPlugin(enableRelay: true);
      expect(plugin.toString(), contains('enableRelay: true'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Read and parse JSON response body.
Future<Map<String, dynamic>> _readBody(HttpClientResponse response) async {
  final body = await utf8.decoder.bind(response).join();
  return jsonDecode(body) as Map<String, dynamic>;
}

// ---------------------------------------------------------------------------
// Mock RelayHandler
// ---------------------------------------------------------------------------

class _MockRelayHandler implements RelayHandler {
  int executeCampaignCallCount = 0;
  int getTerrainCallCount = 0;
  int getBlueprintCallCount = 0;
  int debriefCallCount = 0;
  int getPerformanceReportCallCount = 0;
  int getFrameHistoryCallCount = 0;
  int getPageLoadsCallCount = 0;
  int getMemorySnapshotCallCount = 0;
  int getAlertsCallCount = 0;
  int listSessionsCallCount = 0;
  int getRecordingStatusCallCount = 0;
  int getFrameworkErrorsCallCount = 0;

  @override
  Future<Map<String, dynamic>> executeCampaign(
    Map<String, dynamic> json,
  ) async {
    executeCampaignCallCount++;
    return {
      'campaign': 'mock-campaign',
      'passRate': 1.0,
      'totalExecuted': 0,
      'totalFailed': 0,
      'totalSkipped': 0,
      'report': 'All tests passed.',
      'aiDiagnostic': 'No issues found.',
      'verdicts': <Map<String, dynamic>>[],
    };
  }

  @override
  Map<String, dynamic> getTerrain() {
    getTerrainCallCount++;
    return {
      r'$schema': 'titan://terrain/v1',
      'lastUpdated': DateTime.now().toIso8601String(),
      'sessionsAnalyzed': 0,
      'outposts': <String, dynamic>{},
    };
  }

  @override
  Future<Map<String, dynamic>> getBlueprint() async {
    getBlueprintCallCount++;
    return {
      'terrain': getTerrain(),
      'campaignTemplate': 'See Campaign.templateDescription',
    };
  }

  @override
  Map<String, dynamic> debriefVerdicts(List<Map<String, dynamic>> verdicts) {
    debriefCallCount++;
    return {
      'totalVerdicts': verdicts.length,
      'passedVerdicts': 0,
      'failedVerdicts': 0,
      'insights': <Map<String, dynamic>>[],
      'suggestedNextActions': <String>[],
      'aiSummary': 'No verdicts to analyze.',
    };
  }

  @override
  Map<String, dynamic> getPerformanceReport() {
    getPerformanceReportCallCount++;
    return {
      'health': 'good',
      'durationSeconds': 0,
      'pulse': {
        'totalFrames': 0,
        'jankFrames': 0,
        'jankRate': 0.0,
        'avgFps': 60.0,
        'avgBuildTimeUs': 0,
        'avgRasterTimeUs': 0,
      },
      'stride': {
        'totalPageLoads': 0,
        'avgPageLoadMs': 0,
        'pageLoads': <Map<String, dynamic>>[],
      },
      'vessel': {
        'pillarCount': 0,
        'totalInstances': 0,
        'leakSuspects': <Map<String, dynamic>>[],
      },
      'echo': {
        'totalRebuilds': 0,
        'rebuildsPerWidget': <String, int>{},
        'topRebuilders': <String, int>{},
      },
    };
  }

  @override
  Map<String, dynamic> getFrameHistory() {
    getFrameHistoryCallCount++;
    return {
      'totalFrames': 2,
      'maxHistory': 300,
      'frames': [
        {
          'buildDurationUs': 8000,
          'rasterDurationUs': 4000,
          'totalDurationUs': 12000,
          'isJank': false,
          'isSevereJank': false,
          'timestamp': '2025-01-01T00:00:00.000Z',
        },
        {
          'buildDurationUs': 20000,
          'rasterDurationUs': 10000,
          'totalDurationUs': 30000,
          'isJank': true,
          'isSevereJank': false,
          'timestamp': '2025-01-01T00:00:01.000Z',
        },
      ],
    };
  }

  @override
  Map<String, dynamic> getPageLoads() {
    getPageLoadsCallCount++;
    return {
      'totalPageLoads': 1,
      'avgPageLoadMs': 150,
      'pageLoads': [
        {
          'path': '/quest/1',
          'pattern': '/quest/:id',
          'durationMs': 150,
          'timestamp': '2025-01-01T00:00:00.000Z',
        },
      ],
    };
  }

  @override
  Map<String, dynamic> getMemorySnapshot() {
    getMemorySnapshotCallCount++;
    return {
      'pillarCount': 3,
      'totalInstances': 5,
      'leakSuspects': <Map<String, dynamic>>[],
      'exemptTypes': <String>['TitanObserver'],
    };
  }

  @override
  Map<String, dynamic> getAlerts() {
    getAlertsCallCount++;
    return {
      'totalAlerts': 0,
      'maxHistory': 200,
      'alerts': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<Map<String, dynamic>> listSessions() async {
    listSessionsCallCount++;
    return {
      'configured': true,
      'totalSessions': 0,
      'sessions': <Map<String, dynamic>>[],
    };
  }

  @override
  Map<String, dynamic> getRecordingStatus() {
    getRecordingStatusCallCount++;
    return {
      'isRecording': false,
      'isReplaying': false,
      'currentEventCount': 0,
      'elapsedMs': 0,
      'isPerfRecording': false,
      'hasLastSession': false,
    };
  }

  @override
  Map<String, dynamic> getFrameworkErrors() {
    getFrameworkErrorsCallCount++;
    return {
      'errors': [
        {
          'category': 'overflow',
          'message': 'A RenderFlex overflowed by 42 pixels',
          'timestamp': '2025-01-01T12:00:00.000',
          'library': 'rendering library',
        },
        {
          'category': 'build',
          'message': 'Null check operator used on a null value',
          'timestamp': '2025-01-01T12:01:00.000',
          'library': 'widgets library',
        },
      ],
      'total': 2,
      'byCategory': {
        'overflow': 1,
        'build': 1,
        'layout': 0,
        'paint': 0,
        'gesture': 0,
        'other': 0,
      },
    };
  }

  @override
  Map<String, dynamic> startRecording({String? name, String? description}) {
    return {'success': true, 'name': name ?? 'session', 'isRecording': true};
  }

  @override
  Map<String, dynamic> stopRecording() {
    return {
      'success': true,
      'sessionId': 'mock_session_1',
      'name': 'mock_session',
      'eventCount': 10,
      'durationMs': 5000,
    };
  }

  @override
  Future<Map<String, dynamic>> exportBlueprint({String? directory}) async {
    return {
      'success': true,
      'jsonPath': '${directory ?? '.titan'}/blueprint.json',
      'promptPath': '${directory ?? '.titan'}/blueprint-prompt.md',
      'terrainSummary': {'screens': 3, 'transitions': 5},
      'stratagemCount': 7,
    };
  }

  @override
  Map<String, dynamic> getBlueprintData() {
    return {
      'blueprint': {'version': '1.0', 'terrain': {}, 'stratagems': []},
      'prompt': '# Test Blueprint',
      'terrainSummary': {'screens': 3, 'transitions': 5},
      'stratagemCount': 7,
    };
  }

  @override
  Map<String, dynamic> getApiMetrics() {
    return {
      'totalMetrics': 2,
      'metrics': [
        {
          'method': 'GET',
          'url': 'https://api.example.com/quests',
          'statusCode': 200,
          'durationMs': 142,
          'success': true,
          'cached': false,
          'timestamp': '2025-01-01T00:00:00.000Z',
        },
        {
          'method': 'POST',
          'url': 'https://api.example.com/quests',
          'statusCode': 500,
          'durationMs': 3200,
          'success': false,
          'error': 'Internal Server Error',
          'cached': false,
          'timestamp': '2025-01-01T00:01:00.000Z',
        },
      ],
    };
  }

  @override
  Map<String, dynamic> getApiErrors() {
    return {
      'totalErrors': 1,
      'errors': [
        {
          'method': 'POST',
          'url': 'https://api.example.com/quests',
          'statusCode': 500,
          'durationMs': 3200,
          'success': false,
          'error': 'Internal Server Error',
          'cached': false,
          'timestamp': '2025-01-01T00:01:00.000Z',
        },
      ],
    };
  }

  @override
  Map<String, dynamic> getTremors() {
    return {
      'count': 1,
      'tremors': [
        {
          'name': 'fps_low',
          'category': 'frame',
          'severity': 'warning',
          'once': false,
        },
      ],
      'alertHistoryCount': 0,
    };
  }

  @override
  Map<String, dynamic> addTremor(Map<String, dynamic> config) {
    return {
      'success': true,
      'tremor': {
        'name': 'mock_tremor',
        'category': 'custom',
        'severity': 'warning',
        'once': false,
      },
      'totalTremors': 2,
    };
  }

  @override
  Map<String, dynamic> removeTremor(String name) {
    return {'success': true, 'name': name, 'totalTremors': 0};
  }

  @override
  Map<String, dynamic> resetTremors({bool clearHistory = false}) {
    return {
      'success': true,
      'tremorsReset': 1,
      'historyCleared': clearHistory,
      'alertHistoryCount': 0,
    };
  }

  @override
  Future<Map<String, dynamic>> reloadPage({bool fullRebuild = false}) async {
    return {
      'success': true,
      'method': fullRebuild ? 'reassemble' : 'route',
      'currentRoute': '/mock-route',
    };
  }

  @override
  Map<String, dynamic> getWidgetTree() {
    return {
      'success': true,
      'totalElements': 42,
      'maxDepth': 10,
      'uniqueWidgetTypes': 8,
      'hasText': true,
      'hasTextField': false,
      'hasButton': true,
      'top20WidgetTypes': ['Text: 5', 'Container: 3'],
    };
  }

  @override
  Map<String, dynamic> getEvents({String? source}) {
    return {
      'count': 2,
      'totalEvents': 2,
      'filter': source,
      'bySource': {'atlas': 1, 'basalt': 1},
      'events': [
        {'source': 'atlas', 'type': 'navigate', 'route': '/home'},
        {'source': 'basalt', 'type': 'circuit_trip', 'name': 'api'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> replaySession(
    String sessionId, {
    double speedMultiplier = 1.0,
  }) async {
    return {
      'success': true,
      'sessionId': sessionId,
      'sessionName': 'Mock Session',
      'eventsDispatched': 10,
      'totalEvents': 10,
      'durationMs': 1500,
      'wasCancelled': false,
      'routeChanged': false,
    };
  }

  @override
  Map<String, dynamic> getRouteHistory() {
    return {
      'count': 2,
      'routes': [
        {'source': 'atlas', 'type': 'navigate', 'route': '/home'},
        {'source': 'atlas', 'type': 'navigate', 'route': '/settings'},
      ],
      'currentRoute': '/settings',
    };
  }

  @override
  Future<Map<String, dynamic>> captureScreenshot({
    double pixelRatio = 0.5,
  }) async {
    return {
      'success': true,
      'sizeBytes': 1024,
      'pixelRatio': pixelRatio,
      'base64': 'iVBORw0KGgo=',
    };
  }

  @override
  Map<String, dynamic> auditAccessibility() {
    return {
      'success': true,
      'summary': {
        'totalElements': 50,
        'interactiveElements': 5,
        'withLabels': 3,
        'withRoles': 4,
        'touchTargetViolations': 1,
        'issueCount': 2,
      },
      'issues': [
        {
          'type': 'missing_label',
          'severity': 'warning',
          'widget': 'IconButton',
          'message': 'IconButton is interactive but has no Semantics label.',
        },
      ],
    };
  }

  @override
  Map<String, dynamic> inspectDi() {
    return {
      'success': true,
      'registeredCount': 2,
      'instantiatedCount': 2,
      'lazyCount': 0,
      'pillarCount': 1,
      'entries': [
        {
          'type': 'Colossus',
          'instantiated': true,
          'lazy': false,
          'isPillar': true,
        },
      ],
    };
  }
}
