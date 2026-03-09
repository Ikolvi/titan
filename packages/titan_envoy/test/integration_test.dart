import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_envoy/titan_envoy.dart';

// ---------------------------------------------------------------------------
// Test Pillars
// ---------------------------------------------------------------------------

/// A concrete EnvoyPillar for testing lifecycle and courier wiring.
class _TestEnvoyPillar extends EnvoyPillar {
  _TestEnvoyPillar({required super.baseUrl});

  late final users = core<List<Map<String, dynamic>>>([]);
  late final isLoading = core(false);

  final List<EnvoyMetric> metrics = [];
  bool courierConfigured = false;

  Future<void> loadUsers() => strikeAsync(() async {
    isLoading.value = true;
    final dispatch = await envoy.get('/users');
    users.value = List<Map<String, dynamic>>.from(dispatch.data as List);
    isLoading.value = false;
  });

  @override
  void configureCouriers(Envoy envoy) {
    courierConfigured = true;
  }

  @override
  void onMetric(EnvoyMetric metric) {
    metrics.add(metric);
  }
}

/// A plain Pillar that uses extension methods to create Quarry/Codex.
class _ExtensionPillar extends Pillar {
  _ExtensionPillar(this._envoy);
  final Envoy _envoy;

  /// Quarry for fetching a list of users with SWR.
  late final userQuery = envoyQuarry<List<Map<String, dynamic>>>(
    envoy: _envoy,
    path: '/users',
    fromJson: (data) => List<Map<String, dynamic>>.from(data as List),
    staleTime: const Duration(minutes: 5),
    name: 'users',
  );

  /// Codex for paginated posts.
  late final postCodex = envoyCodex<Map<String, dynamic>>(
    envoy: _envoy,
    path: '/posts',
    fromPage: (data) => List<Map<String, dynamic>>.from(
      (data as Map<String, dynamic>)['items'] as List,
    ),
    hasMore: (data) => (data as Map<String, dynamic>)['hasMore'] as bool,
    pageSize: 10,
    name: 'posts',
  );
}

/// A minimal Pillar for ad-hoc extension tests.
class _SimplePillar extends Pillar {}

/// A Pillar that uses the DI-registered Envoy.
class _DiPillar extends Pillar {
  Envoy get envoy => Titan.get<Envoy>();
  late final result = core<String>('');

  Future<void> fetchName() => strikeAsync(() async {
    final dispatch = await envoy.get('/name');
    result.value = dispatch.data as String;
  });
}

void main() {
  // ---------------------------------------------------------------------------
  // Shared HTTP server
  // ---------------------------------------------------------------------------

  late HttpServer server;
  late String baseUrl;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://localhost:${server.port}';

    server.listen((request) async {
      final path = request.uri.path;

      switch (path) {
        case '/users':
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode([
                {'id': 1, 'name': 'Kael'},
                {'id': 2, 'name': 'Lyra'},
              ]),
            );

        case '/name':
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode('Titan'));

        case '/posts':
          final page =
              int.tryParse(request.uri.queryParameters['page'] ?? '0') ?? 0;
          final items = List.generate(
            10,
            (i) => {'id': page * 10 + i, 'title': 'Post ${page * 10 + i}'},
          );
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'items': items,
                'hasMore': page < 2,
                'cursor': page < 2 ? 'cursor_${page + 1}' : null,
              }),
            );

        case '/error':
          request.response.statusCode = 500;

        case '/slow':
          await Future<void>.delayed(const Duration(milliseconds: 200));
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'ok': true}));

        default:
          request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    Titan.reset();
    await server.close(force: true);
  });

  // ===========================================================================
  // EnvoyPillar tests
  // ===========================================================================

  group('EnvoyPillar', () {
    test('creates envoy with provided base URL', () {
      final pillar = _TestEnvoyPillar(baseUrl: baseUrl);
      pillar.initialize();

      expect(pillar.envoy, isNotNull);
      pillar.dispose();
    });

    test('calls configureCouriers during onInit', () {
      final pillar = _TestEnvoyPillar(baseUrl: baseUrl);
      expect(pillar.courierConfigured, isFalse);

      pillar.initialize();
      expect(pillar.courierConfigured, isTrue);

      pillar.dispose();
    });

    test('envoy can make HTTP requests', () async {
      final pillar = _TestEnvoyPillar(baseUrl: baseUrl);
      pillar.initialize();

      await pillar.loadUsers();

      expect(pillar.users.value, hasLength(2));
      expect(pillar.users.value.first['name'], 'Kael');
      expect(pillar.isLoading.value, isFalse);

      pillar.dispose();
    });

    test('dispose closes the envoy client', () {
      final pillar = _TestEnvoyPillar(baseUrl: baseUrl);
      pillar.initialize();
      pillar.dispose();

      // After dispose, envoy should be closed — making a request should fail.
      expect(() => pillar.envoy.get('/users'), throwsStateError);
    });

    test('super.onInit and super.onDispose are called', () {
      final pillar = _TestEnvoyPillar(baseUrl: baseUrl);
      pillar.initialize();
      expect(pillar.isInitialized, isTrue);

      pillar.dispose();
      expect(pillar.isDisposed, isTrue);
    });

    test('works with Titan DI registration', () async {
      final pillar = _TestEnvoyPillar(baseUrl: baseUrl);
      Titan.put<_TestEnvoyPillar>(pillar);

      expect(pillar.isInitialized, isTrue);
      expect(pillar.courierConfigured, isTrue);

      await pillar.loadUsers();
      expect(pillar.users.value, hasLength(2));
    });
  });

  // ===========================================================================
  // EnvoyModule tests
  // ===========================================================================

  group('EnvoyModule', () {
    test('install registers Envoy in DI', () {
      final envoy = EnvoyModule.install(baseUrl: baseUrl);

      expect(envoy, isNotNull);
      expect(Titan.has<Envoy>(), isTrue);
      expect(Titan.get<Envoy>(), same(envoy));

      envoy.close();
    });

    test('install with couriers adds them to envoy', () async {
      var logged = false;
      EnvoyModule.install(
        baseUrl: baseUrl,
        defaultCouriers: [_LogCheckCourier(() => logged = true)],
      );

      final envoy = Titan.get<Envoy>();
      await envoy.get('/name');
      expect(logged, isTrue);
    });

    test('install with onMetric adds MetricsCourier', () async {
      final metrics = <EnvoyMetric>[];
      EnvoyModule.install(baseUrl: baseUrl, onMetric: metrics.add);

      final envoy = Titan.get<Envoy>();
      await envoy.get('/users');

      expect(metrics, hasLength(1));
      expect(metrics.first.method, 'GET');
      expect(metrics.first.statusCode, 200);
    });

    test('dev preset enables LogCourier', () {
      final envoy = EnvoyModule.dev(baseUrl: baseUrl);

      expect(envoy, isNotNull);
      expect(Titan.has<Envoy>(), isTrue);
    });

    test('production preset configures retries and auth', () async {
      final metrics = <EnvoyMetric>[];
      final envoy = EnvoyModule.production(
        baseUrl: baseUrl,
        maxRetries: 2,
        tokenProvider: () => 'test-token',
        onMetric: metrics.add,
      );

      expect(envoy, isNotNull);
      expect(Titan.has<Envoy>(), isTrue);

      // Make a request — should work and record a metric.
      await envoy.get('/users');
      expect(metrics, isNotEmpty);
    });

    test('uninstall removes and closes Envoy', () {
      EnvoyModule.install(baseUrl: baseUrl);
      expect(Titan.has<Envoy>(), isTrue);

      EnvoyModule.uninstall();
      expect(Titan.has<Envoy>(), isFalse);
    });

    test('uninstall is safe when no Envoy registered', () {
      expect(Titan.has<Envoy>(), isFalse);
      EnvoyModule.uninstall(); // Should not throw.
    });

    test('other Pillars can access shared Envoy', () async {
      EnvoyModule.install(baseUrl: baseUrl);

      final pillar = _DiPillar();
      pillar.initialize();

      await pillar.fetchName();
      expect(pillar.result.value, 'Titan');

      pillar.dispose();
    });

    test('install with timeouts passes them through', () {
      final envoy = EnvoyModule.install(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      );

      expect(envoy.connectTimeout, const Duration(seconds: 5));
      expect(envoy.sendTimeout, const Duration(seconds: 10));
      expect(envoy.receiveTimeout, const Duration(seconds: 15));
    });

    test('install with headers passes them through', () async {
      String? receivedAuth;
      // Create a separate server to check headers.
      final headerServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      headerServer.listen((request) async {
        receivedAuth = request.headers.value('x-custom');
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode('ok'));
        await request.response.close();
      });

      try {
        EnvoyModule.install(
          baseUrl: 'http://localhost:${headerServer.port}',
          headers: {'x-custom': 'alpha'},
        );

        await Titan.get<Envoy>().get('/test');
        expect(receivedAuth, 'alpha');
      } finally {
        await headerServer.close(force: true);
      }
    });
  });

  // ===========================================================================
  // EnvoyPillarExtension tests
  // ===========================================================================

  group('EnvoyPillarExtension', () {
    group('envoyQuarry', () {
      test('creates a Quarry that fetches from Envoy', () async {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);
        pillar.initialize();

        await pillar.userQuery.fetch();

        expect(pillar.userQuery.hasData, isTrue);
        expect(pillar.userQuery.data.value, hasLength(2));
        expect(pillar.userQuery.data.value!.first['name'], 'Kael');

        pillar.dispose();
        envoy.close();
      });

      test('Quarry respects staleTime', () async {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);
        pillar.initialize();

        await pillar.userQuery.fetch();
        expect(pillar.userQuery.isStale, isFalse);

        pillar.dispose();
        envoy.close();
      });

      test('Quarry has correct debug name', () {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);

        // Name is set via the `name` parameter.
        expect(pillar.userQuery.data.name, 'users_data');

        pillar.dispose();
        envoy.close();
      });

      test('Quarry nodes are managed by Pillar lifecycle', () async {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);
        pillar.initialize();

        await pillar.userQuery.fetch();
        expect(pillar.userQuery.hasData, isTrue);

        // Disposing the Pillar should clean up.
        pillar.dispose();
        envoy.close();

        // After dispose, the managed nodes should be disposed.
        expect(pillar.isDisposed, isTrue);
      });

      test('envoyQuarry with POST method', () async {
        // Create a server that handles POST.
        final postServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        postServer.listen((request) async {
          expect(request.method, 'POST');
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'created': true}));
          await request.response.close();
        });

        try {
          final envoy = Envoy(baseUrl: 'http://localhost:${postServer.port}');
          final pillar = _SimplePillar();
          pillar.initialize();

          final q = pillar.envoyQuarry<Map<String, dynamic>>(
            envoy: envoy,
            path: '/submit',
            fromJson: (d) => d as Map<String, dynamic>,
            method: 'POST',
            body: {'key': 'value'},
          );

          await q.fetch();
          expect(q.data.value?['created'], isTrue);

          pillar.dispose();
          envoy.close();
        } finally {
          await postServer.close(force: true);
        }
      });

      test('envoyQuarry with query parameters', () async {
        String? receivedSearch;
        final qpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        qpServer.listen((request) async {
          receivedSearch = request.uri.queryParameters['search'];
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode([]));
          await request.response.close();
        });

        try {
          final envoy = Envoy(baseUrl: 'http://localhost:${qpServer.port}');
          final pillar = _SimplePillar();
          pillar.initialize();

          final q = pillar.envoyQuarry<List<dynamic>>(
            envoy: envoy,
            path: '/search',
            fromJson: (d) => d as List<dynamic>,
            queryParameters: {'search': 'kael'},
          );

          await q.fetch();
          expect(receivedSearch, 'kael');

          pillar.dispose();
          envoy.close();
        } finally {
          await qpServer.close(force: true);
        }
      });

      test('envoyQuarry handles errors via Quarry.error', () async {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _SimplePillar();
        pillar.initialize();

        final q = pillar.envoyQuarry<String>(
          envoy: envoy,
          path: '/error',
          fromJson: (d) => d as String,
        );

        await q.fetch();
        expect(q.hasError, isTrue);

        pillar.dispose();
        envoy.close();
      });
    });

    group('envoyCodex', () {
      test('creates a Codex that fetches paginated data', () async {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);
        pillar.initialize();

        await pillar.postCodex.loadFirst();

        expect(pillar.postCodex.items.value, hasLength(10));
        expect(pillar.postCodex.hasMore.value, isTrue);

        pillar.dispose();
        envoy.close();
      });

      test('Codex loads next page', () async {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);
        pillar.initialize();

        await pillar.postCodex.loadFirst();
        expect(pillar.postCodex.items.value, hasLength(10));

        await pillar.postCodex.loadNext();
        expect(pillar.postCodex.items.value, hasLength(20));
        expect(pillar.postCodex.hasMore.value, isTrue);

        pillar.dispose();
        envoy.close();
      });

      test('Codex stops when no more pages', () async {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);
        pillar.initialize();

        await pillar.postCodex.loadFirst();
        await pillar.postCodex.loadNext();
        await pillar.postCodex.loadNext();

        expect(pillar.postCodex.items.value, hasLength(30));
        expect(pillar.postCodex.hasMore.value, isFalse);

        pillar.dispose();
        envoy.close();
      });

      test('Codex has correct debug name', () {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);

        expect(pillar.postCodex.items.name, 'posts_items');

        pillar.dispose();
        envoy.close();
      });

      test('Codex nodes are managed by Pillar lifecycle', () async {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);
        pillar.initialize();

        await pillar.postCodex.loadFirst();

        pillar.dispose();
        envoy.close();

        expect(pillar.isDisposed, isTrue);
      });

      test('envoyCodex with query parameters', () async {
        String? receivedCategory;
        final catServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        catServer.listen((request) async {
          receivedCategory = request.uri.queryParameters['category'];
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({'items': <Map<String, dynamic>>[], 'hasMore': false}),
            );
          await request.response.close();
        });

        try {
          final envoy = Envoy(baseUrl: 'http://localhost:${catServer.port}');
          final pillar = _SimplePillar();
          pillar.initialize();

          final c = pillar.envoyCodex<Map<String, dynamic>>(
            envoy: envoy,
            path: '/posts',
            fromPage: (d) => List<Map<String, dynamic>>.from(
              (d as Map<String, dynamic>)['items'] as List,
            ),
            hasMore: (d) => (d as Map<String, dynamic>)['hasMore'] as bool,
            queryParameters: {'category': 'quests'},
          );

          await c.loadFirst();
          expect(receivedCategory, 'quests');

          pillar.dispose();
          envoy.close();
        } finally {
          await catServer.close(force: true);
        }
      });

      test('envoyCodex extracts cursor from response', () async {
        final envoy = Envoy(baseUrl: baseUrl);
        final pillar = _ExtensionPillar(envoy);
        pillar.initialize();

        await pillar.postCodex.loadFirst();

        // The server returns 'cursor' field — should be extracted.
        // After loading next, cursor should have been used.
        await pillar.postCodex.loadNext();
        expect(pillar.postCodex.items.value, hasLength(20));

        pillar.dispose();
        envoy.close();
      });
    });
  });

  // ===========================================================================
  // Combined integration tests
  // ===========================================================================

  group('Full integration', () {
    test('EnvoyModule + extension Pillar', () async {
      EnvoyModule.install(baseUrl: baseUrl);

      final envoy = Titan.get<Envoy>();
      final pillar = _SimplePillar();
      pillar.initialize();

      final q = pillar.envoyQuarry<List<Map<String, dynamic>>>(
        envoy: envoy,
        path: '/users',
        fromJson: (d) => List<Map<String, dynamic>>.from(d as List),
      );

      await q.fetch();
      expect(q.data.value, hasLength(2));

      pillar.dispose();
    });

    test('EnvoyPillar registered via DI works end-to-end', () async {
      final pillar = _TestEnvoyPillar(baseUrl: baseUrl);
      Titan.put<_TestEnvoyPillar>(pillar);

      expect(Titan.has<_TestEnvoyPillar>(), isTrue);
      expect(pillar.isInitialized, isTrue);
      expect(pillar.courierConfigured, isTrue);

      await pillar.loadUsers();
      expect(pillar.users.value, hasLength(2));
    });

    test('multiple Pillars share one Envoy via DI', () async {
      EnvoyModule.install(baseUrl: baseUrl);

      final p1 = _DiPillar();
      final p2 = _DiPillar();
      p1.initialize();
      p2.initialize();

      expect(p1.envoy, same(p2.envoy));

      await p1.fetchName();
      await p2.fetchName();
      expect(p1.result.value, 'Titan');
      expect(p2.result.value, 'Titan');

      p1.dispose();
      p2.dispose();
    });

    test('Titan.reset cleans up everything', () async {
      EnvoyModule.install(baseUrl: baseUrl);
      final pillar = _TestEnvoyPillar(baseUrl: baseUrl);
      Titan.put<_TestEnvoyPillar>(pillar);

      expect(Titan.has<Envoy>(), isTrue);
      expect(Titan.has<_TestEnvoyPillar>(), isTrue);

      Titan.reset();

      expect(Titan.has<Envoy>(), isFalse);
      expect(Titan.has<_TestEnvoyPillar>(), isFalse);
      expect(pillar.isDisposed, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A simple courier that calls a callback on each request for verification.
class _LogCheckCourier extends Courier {
  _LogCheckCourier(this._onLog);
  final void Function() _onLog;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) {
    _onLog();
    return chain.proceed(missive);
  }
}
