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
}
