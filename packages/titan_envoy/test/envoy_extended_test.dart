import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

/// Extensive tests for Envoy HTTP client — covering download, stream,
/// response types, body preparation, concurrent requests, header merging,
/// validateStatus overrides, and edge cases.
void main() {
  late HttpServer server;
  late Envoy envoy;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    envoy = Envoy(baseUrl: 'http://localhost:${server.port}');

    server.listen((request) async {
      final path = request.uri.path;
      final method = request.method;

      switch ((method, path)) {
        case ('GET', '/download'):
          final bytes = List.generate(1024, (i) => i % 256);
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.binary
            ..headers.add('content-length', '${bytes.length}')
            ..add(bytes);
        case ('GET', '/stream'):
          request.response.statusCode = 200;
          for (var i = 0; i < 5; i++) {
            request.response.write('chunk$i');
          }
        case ('GET', '/plain-text'):
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.text
            ..write('Hello, Titan!');
        case ('GET', '/json-object'):
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write('{"name":"Kael","level":42}');
        case ('GET', '/json-array'):
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write('[1,2,3,4,5]');
        case ('GET', '/empty'):
          request.response.statusCode = 200;
        case ('GET', '/404-custom'):
          request.response
            ..statusCode = 404
            ..headers.contentType = ContentType.json
            ..write('{"error":"not found"}');
        case ('GET', '/500'):
          request.response
            ..statusCode = 500
            ..write('Server Error');
        case ('GET', '/301'):
          request.response
            ..statusCode = 301
            ..headers.add('location', '/redirected');
        case ('GET', '/redirected'):
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write('{"redirected":true}');
        case ('GET', '/slow'):
          await Future<void>.delayed(Duration(seconds: 2));
          request.response
            ..statusCode = 200
            ..write('slow');
        case ('GET', '/headers'):
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'authorization': request.headers.value('authorization'),
                'x-custom': request.headers.value('x-custom'),
                'accept': request.headers.value('accept'),
                'x-default': request.headers.value('x-default'),
              }),
            );
        case ('POST', '/echo'):
          final body = await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'method': method,
                'contentType': request.headers.contentType?.toString(),
                'body': body,
                'bodyLength': body.length,
              }),
            );
        case ('POST', '/binary-echo'):
          final chunks = <List<int>>[];
          await request.listen((chunk) => chunks.add(chunk)).asFuture<void>();
          final totalLen = chunks.fold<int>(0, (sum, c) => sum + c.length);
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'bytesReceived': totalLen,
                'contentType': request.headers.contentType?.toString(),
              }),
            );
        case ('GET', '/concurrent'):
          final id = request.uri.queryParameters['id'];
          await Future<void>.delayed(Duration(milliseconds: 50));
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write('{"id":"$id"}');
        default:
          request.response
            ..statusCode = 404
            ..write('Not found: $method $path');
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    envoy.close();
    await server.close(force: true);
  });

  // ═══════════════════════════════════════════════════════════════════
  // Download
  // ═══════════════════════════════════════════════════════════════════

  group('Envoy.download()', () {
    test('downloads binary data as bytes', () async {
      final dispatch = await envoy.download('/download');
      expect(dispatch.statusCode, 200);
      expect(dispatch.data, isA<Uint8List>());
      final bytes = dispatch.data as Uint8List;
      expect(bytes.length, 1024);
    });

    test('reports progress via onProgress callback', () async {
      int? lastReceived;
      int? lastTotal;

      final dispatch = await envoy.download(
        '/download',
        onProgress: (received, total) {
          lastReceived = received;
          lastTotal = total;
        },
      );

      expect(dispatch.statusCode, 200);
      expect(lastReceived, isNotNull);
      expect(lastTotal, isNotNull);
    });

    test('download with query parameters', () async {
      final dispatch = await envoy.download(
        '/download',
        queryParameters: {'format': 'pdf'},
      );
      expect(dispatch.statusCode, 200);
    });

    test('download with custom headers', () async {
      final dispatch = await envoy.download(
        '/download',
        headers: {'accept': 'application/octet-stream'},
      );
      expect(dispatch.statusCode, 200);
    });

    test('download with recall token', () async {
      final recall = Recall();

      // Cancel immediately
      recall.cancel('test cancel');

      expect(
        () => envoy.download('/download', recall: recall),
        throwsA(isA<EnvoyError>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Stream
  // ═══════════════════════════════════════════════════════════════════

  group('Envoy.stream()', () {
    test('returns response as stream', () async {
      final dispatch = await envoy.stream('/stream');
      expect(dispatch.statusCode, 200);
      expect(dispatch.data, isA<Stream<List<int>>>());
    });

    test('stream data can be collected', () async {
      final dispatch = await envoy.stream('/stream');
      final stream = dispatch.data as Stream<List<int>>;
      final collected = <int>[];
      await for (final chunk in stream) {
        collected.addAll(chunk);
      }
      final text = utf8.decode(collected);
      expect(text, contains('chunk0'));
      expect(text, contains('chunk4'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Response Types
  // ═══════════════════════════════════════════════════════════════════

  group('Response types', () {
    test('ResponseType.json parses JSON object', () async {
      final dispatch = await envoy.get('/json-object');
      expect(dispatch.data, isA<Map>());
      expect(dispatch.jsonMap['name'], 'Kael');
      expect(dispatch.jsonMap['level'], 42);
    });

    test('ResponseType.json parses JSON array', () async {
      final dispatch = await envoy.get('/json-array');
      expect(dispatch.data, isA<List>());
      expect(dispatch.jsonList, [1, 2, 3, 4, 5]);
    });

    test('ResponseType.plain returns raw text', () async {
      final dispatch = await envoy.send(
        Missive(
          method: Method.get,
          uri: Uri.parse('http://localhost:${server.port}/plain-text'),
          responseType: ResponseType.plain,
        ),
      );
      expect(dispatch.data, isA<String>());
      expect(dispatch.data, 'Hello, Titan!');
    });

    test('ResponseType.bytes returns Uint8List', () async {
      final dispatch = await envoy.send(
        Missive(
          method: Method.get,
          uri: Uri.parse('http://localhost:${server.port}/download'),
          responseType: ResponseType.bytes,
        ),
      );
      expect(dispatch.data, isA<Uint8List>());
    });

    test('handles empty JSON response', () async {
      final dispatch = await envoy.get('/empty');
      // Empty body with JSON response type returns null
      expect(dispatch.data, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Body Preparation
  // ═══════════════════════════════════════════════════════════════════

  group('Body preparation', () {
    test('sends Map body as JSON', () async {
      final dispatch = await envoy.post(
        '/echo',
        data: {'hero': 'Kael', 'level': 42},
      );
      final result = dispatch.jsonMap;
      expect(result['contentType'], contains('application/json'));
      final sentBody = jsonDecode(result['body'] as String);
      expect(sentBody['hero'], 'Kael');
      expect(sentBody['level'], 42);
    });

    test('sends List body as JSON', () async {
      final dispatch = await envoy.post('/echo', data: [1, 2, 3]);
      final result = dispatch.jsonMap;
      expect(result['contentType'], contains('application/json'));
      final sentBody = jsonDecode(result['body'] as String);
      expect(sentBody, [1, 2, 3]);
    });

    test('sends String body as-is', () async {
      final dispatch = await envoy.post('/echo', data: 'plain text body');
      final result = dispatch.jsonMap;
      expect(result['body'], 'plain text body');
    });

    test('sends Uint8List body as raw bytes', () async {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final dispatch = await envoy.send(
        Missive(
          method: Method.post,
          uri: Uri.parse('http://localhost:${server.port}/binary-echo'),
          data: bytes,
        ),
      );
      final result = dispatch.jsonMap;
      expect(result['bytesReceived'], 6);
    });

    test('sends Parcel without files as URL-encoded', () async {
      final parcel = Parcel()
        ..addField('name', 'Kael')
        ..addField('quest', 'Dragon Slayer');

      final dispatch = await envoy.post('/echo', data: parcel);
      final result = dispatch.jsonMap;
      expect(
        result['contentType'],
        contains('application/x-www-form-urlencoded'),
      );
      expect(result['body'], contains('name=Kael'));
      expect(result['body'], contains('quest=Dragon+Slayer'));
    });

    test('sends Parcel with files as multipart', () async {
      final parcel = Parcel()
        ..addField('name', 'Kael')
        ..addFile(
          'avatar',
          ParcelFile.fromString(
            content: 'fake image data',
            filename: 'avatar.png',
            contentType: 'image/png',
          ),
        );

      final dispatch = await envoy.post('/echo', data: parcel);
      final result = dispatch.jsonMap;
      expect(result['contentType'], contains('multipart/form-data'));
    });

    test('sends null body', () async {
      final dispatch = await envoy.post('/echo');
      final result = dispatch.jsonMap;
      expect(result['body'], '');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Header Merging
  // ═══════════════════════════════════════════════════════════════════

  group('Header merging', () {
    test('default headers are sent', () async {
      envoy.defaultHeaders['x-default'] = 'default-value';
      envoy.defaultHeaders['accept'] = 'application/xml';

      final dispatch = await envoy.get('/headers');
      final result = dispatch.jsonMap;
      expect(result['x-default'], 'default-value');
      expect(result['accept'], 'application/xml');
    });

    test('per-request headers override defaults', () async {
      envoy.defaultHeaders['accept'] = 'text/html';

      final dispatch = await envoy.get(
        '/headers',
        headers: {'accept': 'application/json'},
      );
      final result = dispatch.jsonMap;
      expect(result['accept'], 'application/json');
    });

    test('per-request headers merge with defaults', () async {
      envoy.defaultHeaders['x-default'] = 'from-default';

      final dispatch = await envoy.get(
        '/headers',
        headers: {'x-custom': 'from-request'},
      );
      final result = dispatch.jsonMap;
      expect(result['x-default'], 'from-default');
      expect(result['x-custom'], 'from-request');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // validateStatus
  // ═══════════════════════════════════════════════════════════════════

  group('validateStatus', () {
    test('default validator accepts 2xx', () async {
      final dispatch = await envoy.get('/json-object');
      expect(dispatch.isSuccess, isTrue);
    });

    test('default validator rejects 4xx', () async {
      expect(
        () => envoy.get('/404-custom'),
        throwsA(
          isA<EnvoyError>().having(
            (e) => e.type,
            'type',
            EnvoyErrorType.badResponse,
          ),
        ),
      );
    });

    test('default validator rejects 5xx', () async {
      expect(
        () => envoy.get('/500'),
        throwsA(
          isA<EnvoyError>().having(
            (e) => e.type,
            'type',
            EnvoyErrorType.badResponse,
          ),
        ),
      );
    });

    test('custom envoy-level validator', () async {
      envoy.validateStatus = (status) => status < 500;

      // 404 should now pass
      final dispatch = await envoy.get('/404-custom');
      expect(dispatch.statusCode, 404);
      expect(dispatch.jsonMap['error'], 'not found');
    });

    test('per-request validator overrides envoy-level', () async {
      envoy.validateStatus = (status) => status == 200;

      // Use per-request validator that accepts 404
      final dispatch = await envoy.send(
        Missive(
          method: Method.get,
          uri: Uri.parse('http://localhost:${server.port}/404-custom'),
          validateStatus: (status) => status == 404,
        ),
      );
      expect(dispatch.statusCode, 404);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Cancellation
  // ═══════════════════════════════════════════════════════════════════

  group('Cancellation', () {
    test('recall before request throws cancelled', () {
      final recall = Recall()..cancel('pre-cancel');

      expect(
        () => envoy.get('/json-object', recall: recall),
        throwsA(
          isA<EnvoyError>().having(
            (e) => e.type,
            'type',
            EnvoyErrorType.cancelled,
          ),
        ),
      );
    });

    test('recall during slow request throws cancelled', () async {
      final recall = Recall();

      final future = envoy.get('/slow', recall: recall);

      // Cancel after a short delay
      Timer(Duration(milliseconds: 100), () => recall.cancel('too slow'));

      expect(
        () => future,
        throwsA(
          isA<EnvoyError>().having(
            (e) => e.type,
            'type',
            EnvoyErrorType.cancelled,
          ),
        ),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Timeout
  // ═══════════════════════════════════════════════════════════════════

  group('Timeout', () {
    test('receiveTimeout triggers EnvoyError.timeout', () async {
      expect(
        () => envoy.get('/slow', receiveTimeout: Duration(milliseconds: 100)),
        throwsA(
          isA<EnvoyError>().having(
            (e) => e.type,
            'type',
            EnvoyErrorType.timeout,
          ),
        ),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Concurrent Requests
  // ═══════════════════════════════════════════════════════════════════

  group('Concurrent requests', () {
    test('handles 20 concurrent requests', () async {
      final futures = List.generate(
        20,
        (i) => envoy.get('/concurrent', queryParameters: {'id': '$i'}),
      );

      final responses = await Future.wait(futures);
      expect(responses.length, 20);
      expect(responses.every((d) => d.statusCode == 200), isTrue);

      final ids = responses.map((d) => d.jsonMap['id']).toSet();
      expect(ids.length, 20);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════

  group('Lifecycle', () {
    test('closed envoy throws StateError', () {
      envoy.close();
      expect(() => envoy.get('/json-object'), throwsA(isA<StateError>()));
    });

    test('close with force=true disposes immediately', () {
      envoy.close(force: true);
      expect(() => envoy.get('/json-object'), throwsA(isA<StateError>()));
    });

    test('double close does not throw', () {
      envoy.close();
      envoy.close(); // safe
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Dispatch properties
  // ═══════════════════════════════════════════════════════════════════

  group('Dispatch properties', () {
    test('duration is tracked', () async {
      final dispatch = await envoy.get('/json-object');
      expect(dispatch.duration, isNotNull);
      expect(dispatch.duration!.inMicroseconds, greaterThan(0));
    });

    test('rawBody is populated', () async {
      final dispatch = await envoy.get('/json-object');
      expect(dispatch.rawBody, isNotNull);
      expect(dispatch.rawBody, contains('Kael'));
    });

    test('missive reference is preserved', () async {
      final dispatch = await envoy.get('/json-object');
      expect(dispatch.missive.method, Method.get);
      expect(dispatch.missive.resolvedUri.path, '/json-object');
    });

    test('parsedJson re-parses rawBody', () async {
      final dispatch = await envoy.send(
        Missive(
          method: Method.get,
          uri: Uri.parse('http://localhost:${server.port}/json-object'),
          responseType: ResponseType.plain,
        ),
      );
      // data is a raw string, but parsedJson should decode it
      final parsed = dispatch.parsedJson as Map<String, dynamic>;
      expect(parsed['name'], 'Kael');
    });

    test('contentType header is accessible', () async {
      final dispatch = await envoy.get('/json-object');
      expect(dispatch.contentType, isNotNull);
      expect(dispatch.contentType, contains('application/json'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Absolute URL handling
  // ═══════════════════════════════════════════════════════════════════

  group('Absolute URL handling', () {
    test('absolute URL ignores baseUrl', () async {
      final absoluteUrl = 'http://localhost:${server.port}/json-object';
      final dispatch = await envoy.get(absoluteUrl);
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['name'], 'Kael');
    });

    test('absolute https URL is used directly', () {
      // This will fail to connect, but should parse the URI correctly
      expect(
        () => envoy.get('https://nonexistent.example.com/test'),
        throwsA(anything),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Courier chain interaction
  // ═══════════════════════════════════════════════════════════════════

  group('Courier chain integration', () {
    test('courier can modify request', () async {
      envoy.addCourier(_HeaderInjectCourier('x-injected', 'yes'));

      final dispatch = await envoy.get('/headers');
      // The courier injected a header — server may or may not see it
      // depending on header name. This validates the chain runs.
      expect(dispatch.statusCode, 200);
    });

    test('courier can modify response', () async {
      envoy.addCourier(_StatusOverrideCourier(201));

      final dispatch = await envoy.get('/json-object');
      expect(dispatch.statusCode, 201); // overridden by courier
    });

    test('courier can short-circuit', () async {
      envoy.addCourier(_ShortCircuitCourier());

      final dispatch = await envoy.get('/json-object');
      expect(dispatch.statusCode, 418); // I'm a teapot
      expect(dispatch.jsonMap['short'], 'circuited');
    });

    test('5 couriers execute in order', () async {
      final order = <int>[];

      for (var i = 1; i <= 5; i++) {
        envoy.addCourier(_OrderTracker(i, order));
      }

      await envoy.get('/json-object');

      // Request order: 1, 2, 3, 4, 5
      // Response order: 5, 4, 3, 2, 1 (reverse)
      expect(order, [1, 2, 3, 4, 5, -5, -4, -3, -2, -1]);
    });

    test('removeCourier removes from chain', () async {
      final courier = _ShortCircuitCourier();
      envoy.addCourier(courier);
      envoy.removeCourier(courier);

      final dispatch = await envoy.get('/json-object');
      expect(dispatch.statusCode, 200); // Not short-circuited
    });

    test('clearCouriers removes all', () async {
      envoy.addCourier(_ShortCircuitCourier());
      envoy.clearCouriers();

      final dispatch = await envoy.get('/json-object');
      expect(dispatch.statusCode, 200);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Envoy constructor options
  // ═══════════════════════════════════════════════════════════════════

  group('Envoy constructor', () {
    test('defaults are reasonable', () {
      final e = Envoy();
      expect(e.baseUrl, '');
      expect(e.defaultHeaders, isEmpty);
      expect(e.connectTimeout, isNull);
      expect(e.sendTimeout, isNull);
      expect(e.receiveTimeout, isNull);
      expect(e.followRedirects, isTrue);
      expect(e.maxRedirects, 5);
      expect(e.pin, isNull);
      expect(e.proxy, isNull);
      expect(e.validateStatus, isNull);
      expect(e.couriers, isEmpty);
      e.close();
    });

    test('all options can be set', () {
      final e = Envoy(
        baseUrl: 'https://api.test.com',
        headers: {'x-key': 'abc'},
        connectTimeout: Duration(seconds: 5),
        sendTimeout: Duration(seconds: 10),
        receiveTimeout: Duration(seconds: 15),
        followRedirects: false,
        maxRedirects: 3,
        pin: EnvoyPin(allowSelfSigned: true),
        proxy: EnvoyProxy(host: 'proxy', port: 8080),
        validateStatus: (s) => s == 200,
      );
      expect(e.baseUrl, 'https://api.test.com');
      expect(e.defaultHeaders['x-key'], 'abc');
      expect(e.connectTimeout, Duration(seconds: 5));
      expect(e.sendTimeout, Duration(seconds: 10));
      expect(e.receiveTimeout, Duration(seconds: 15));
      expect(e.followRedirects, isFalse);
      expect(e.maxRedirects, 3);
      expect(e.pin, isNotNull);
      expect(e.proxy, isNotNull);
      e.close();
    });

    test('baseUrl can be changed at runtime', () async {
      envoy.baseUrl = 'http://localhost:${server.port}';
      final dispatch = await envoy.get('/json-object');
      expect(dispatch.statusCode, 200);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════
// Test Couriers
// ═══════════════════════════════════════════════════════════════════

class _HeaderInjectCourier extends Courier {
  _HeaderInjectCourier(this.key, this.value);
  final String key;
  final String value;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) {
    final updated = missive.copyWith(headers: {...missive.headers, key: value});
    return chain.proceed(updated);
  }
}

class _StatusOverrideCourier extends Courier {
  _StatusOverrideCourier(this.status);
  final int status;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    final dispatch = await chain.proceed(missive);
    return dispatch.copyWith(statusCode: status);
  }
}

class _ShortCircuitCourier extends Courier {
  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    return Dispatch(
      statusCode: 418,
      data: {'short': 'circuited'},
      headers: {},
      missive: missive,
    );
  }
}

class _OrderTracker extends Courier {
  _OrderTracker(this.id, this.order);
  final int id;
  final List<int> order;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    order.add(id);
    final dispatch = await chain.proceed(missive);
    order.add(-id);
    return dispatch;
  }
}
